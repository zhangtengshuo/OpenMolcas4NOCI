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
