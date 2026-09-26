# OpenMolcas4NOCI v26.06.1 build support

## Source baseline

This development line is based on upstream OpenMolcas commit `4e52760a9bec07a7d253ee2fc5ac29fc5203bf27` and is maintained as the derived release `OpenMolcas4NOCI-v26.06.1`.

The derived source includes the SEWARD/RI direct-accumulation performance correction, the MOTRA MPI frozen-core one-electron correction, the EXPBAS `GUGAORDER` option, and the portable SEWARD HDF5 export described below.

## Reproducible local environment

Run the following commands from a normal shell after installing Micromamba:

```bash
./build-support/create_environment.sh
./build-support/build_local.sh
```

The scripts place the environment, build tree, and installation below the versioned outer-workspace directory `build/v26.06.1/`.

Set `MAMBA_ROOT_PREFIX` when reusing an existing Micromamba package cache; otherwise `create_environment.sh` uses `build/shared/micromamba-root/` below the outer workspace.

`environment.yml` is the readable package specification, while the default `environment-linux-64.lock` records exact package URLs and checksums for deterministic environment recreation on Linux x86-64.

Set `OPENMOLCAS4NOCI_ENV_SPEC` to the readable YAML only when intentionally resolving a fresh environment for another platform.

All compiler, MPI, HDF5, Global Arrays, MKL, LibXC, Python, and build-tool dependencies come from the one micromamba prefix.

Conda-forge does not currently provide `libwignernj`; OpenMolcas therefore builds its upstream-pinned v0.6.0 fallback as a static component inside the build tree.

## Portable SEWARD HDF5 export

Add `CHH5` to a conventional C1 Cholesky SEWARD input:

```text
&SEWARD
  CHOLESKY
  CHH5
```

Format version 1 deliberately rejects symmetry above C1 and RI/DF input so that every exported index and convention remains explicit.

The result is written under `MOLCAS_OUTPUT` as `$Project.NOCI_SEWARD_H5`.

SEWARD first writes `$Project.NOCI_SEWARD_H5.partial`, each MPI rank writes one uncompressed `rank_NNNN.h5` factor shard, rank zero verifies exact global auxiliary-index coverage and writes `manifest.h5`, and only then is the complete directory atomically renamed to its final name.

`manifest.h5` contains system and basis metadata, actual and effective nuclear charges, explicit reduced AO-pair indices, overlap, kinetic, nuclear-attraction, core-Hamiltonian, dipole, and quadrupole operators, nuclear repulsion, Cholesky threshold, shard filenames and counts, and producer provenance.

Each shard contains its global auxiliary indices and an uncompressed FP64 factor dataset with disk-axis order `auxiliary,reduced_pair`; factors are streamed in bounded batches without an HDF5 flush after every batch.
