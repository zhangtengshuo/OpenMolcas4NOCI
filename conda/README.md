# Conda release build

The recipe builds the Linux x86-64 `openmolcas4noci` package from a clean checkout of the project and the separately checksummed libwignernj v0.6.0 archive.

The OpenMolcas tree is installed below `$PREFIX/libexec/openmolcas4noci`, and the public executable is `$PREFIX/bin/pymolcas4noci`; this avoids replacing an unrelated general-purpose OpenMolcas command.

Check out the exact source commit with a clean worktree, then run the build with an isolated `conda-build` and `boa` installation while recording that commit in the release manifest:

```bash
OPENMOLCAS4NOCI_SOURCE_COMMIT="$(git rev-parse HEAD)" CONDA_CHANNEL_PRIORITY=flexible conda mambabuild conda/recipe --override-channels -c conda-forge --no-lock --no-include-recipe --no-anaconda-upload
```

The rendered recipe is retained as a separate release artifact instead of being copied into the package, because conda-build otherwise records the operator's local recipe path in generated package metadata.

The package test runs real H2/STO-3G serial and two-rank MPI SEWARD calculations with `CHH5`, validates the portable manifest and uncompressed factors, checks fixed numerical references, and requires bitwise-identical serial/MPI factors.

The recipe supports Conda's deliberately long build and test prefixes, rewrites runtime RPATH entries relative to the installed tree, normalizes recorded compiler paths, and rejects payloads that retain host, source, or build paths.

## Separate program and runtime dependencies

The release's `runtime-dependencies-linux-64.explicit.txt` contains only the runtime dependencies and pins every package by its conda-forge URL and SHA-256.

`runtime-dependencies-linux-64.json` contains the corresponding package identities and SHA-256 values for installer bookkeeping.

```bash
micromamba create -y -p "$DEPENDENCY_PREFIX" -f runtime-dependencies-linux-64.explicit.txt
micromamba create -y --offline --no-deps -p "$PROGRAM_PREFIX" ./openmolcas4noci-26.06.1-openmpi_hdf5_mkl_0.tar.bz2
ln -s "$(realpath --relative-to="$PROGRAM_PREFIX" "$DEPENDENCY_PREFIX/lib")" "$PROGRAM_PREFIX/lib"
micromamba run -p "$DEPENDENCY_PREFIX" "$PROGRAM_PREFIX/bin/pymolcas4noci" --help
```

Choose new prefixes owned by the installer and refuse an existing program `lib` directory instead of replacing it.

The relative `lib` link satisfies the package's relative ELF RPATH and shares dependency libraries without copying them into every program version.

Run calculations inside the dependency environment so the launcher can discover its Python and MPI commands.

The program and dependency directories can be relocated together while preserving their relative layout; Conda dependency environments themselves must be installed at their final prefixes.

Program versions may share an accepted dependency lock only after their serial, MPI and NOCI.jl integration tests pass against that lock.

Do not install the program package into the dependency-only environment or upgrade dependencies implicitly when switching program versions.

## Julia shared-library compatibility

The release recipe uses GCC 14, MKL 2025.3, OpenMPI 5.0.10 and NumPy 2.3-compatible packages, with the GCC runtime constrained below version 15.

Julia 1.12.6 bundles a C++ runtime exposing `GLIBCXX_3.4.33`; the dependency lock must satisfy CondaPkg's `libstdcxx = "<=julia"` constraint before loading `libmolcas.so` into Julia.

MKL 2026.1 requires GCC 15 or newer runtime packages and is therefore unsuitable for this release's shared-library integration contract.

Standalone local builds described under `build-support/` have a separate environment lock and do not define the Conda release dependency lock.
