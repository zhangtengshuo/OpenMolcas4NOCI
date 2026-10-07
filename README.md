# OpenMolcas4NOCI

OpenMolcas4NOCI is a controlled derivative of OpenMolcas 26.06 for the integral-preparation workflow used by NOCI.jl; it is not a replacement for the general OpenMolcas distribution.

This release line is based on upstream OpenMolcas commit `4e52760a9bec07a7d253ee2fc5ac29fc5203bf27` and adds the NOCI-oriented SEWARD `CHH5` portable HDF5 export, EXPBAS `GUGAORDER`, selected integral-accumulation corrections, long installation-path support, a relocatable launcher, and a pinned Linux x86-64 Conda recipe.

## Conda installation

The v26.06.2 Linux x86-64 package is a release candidate intended for the NOCI.jl automatic installer; publication is pending validation and review.

Download the package, the complete runtime dependency specification and the checksums from that release, verify the checksums, then install the dependencies before the local program package:

```bash
curl -fLO https://github.com/zhangtengshuo/OpenMolcas4NOCI/releases/download/v26.06.2/openmolcas4noci-26.06.2-openmpi_hdf5_mkl_0.tar.bz2
curl -fLO https://github.com/zhangtengshuo/OpenMolcas4NOCI/releases/download/v26.06.2/runtime-dependencies-linux-64.explicit.txt
curl -fLO https://github.com/zhangtengshuo/OpenMolcas4NOCI/releases/download/v26.06.2/SHA256SUMS
sha256sum --ignore-missing -c SHA256SUMS
micromamba create -y -n openmolcas4noci -f runtime-dependencies-linux-64.explicit.txt
micromamba install -y --offline --no-deps -n openmolcas4noci ./openmolcas4noci-26.06.2-openmpi_hdf5_mkl_0.tar.bz2
micromamba run -n openmolcas4noci pymolcas4noci --help
```

A local package archive is treated as an explicit package installation by Micromamba, so passing that archive alone does not resolve its dependencies.

GitHub hosts the native Conda package; it is not a Conda channel and must not be passed as a channel URL.

The package installs its runtime at `libexec/openmolcas4noci` and exposes `bin/pymolcas4noci`, preserving separately installed OpenMolcas commands.

This build requires glibc 2.28 or newer and uses OpenMPI, parallel HDF5, Global Arrays, MKL and Libxc on Linux x86-64; macOS, Windows and ARM packages are not provided by this release.

The release also provides a complete runtime dependency lock, an explicit Conda specification and a machine-readable release manifest with source revision, package identity and SHA-256.

See [conda/README.md](conda/README.md) for reproducible builds and separate program/dependency prefixes.

## NOCI.jl integration

NOCI.jl can download the release package, verify its SHA-256 and record its version, build, source revision and installed path.

For shared dependencies, install the locked runtime dependencies into one Conda environment and install only the OpenMolcas4NOCI package into a separate versioned program prefix.

NOCI.jl activates the dependency environment and sets `NOCI_OPENMOLCAS4NOCI` to the program's `bin/pymolcas4noci` and `NOCI_OPENMOLCAS_ROOT` to its `libexec/openmolcas4noci` directory.

Compatible program upgrades can reuse that dependency environment after validation; a changed dependency lock requires a separate environment.

## Upstream OpenMolcas

The remainder of this document is the upstream OpenMolcas overview retained for license, citation, build, and documentation context.

OpenMolcas
==========

**Home page**: https://molcas.gitlab.io

OpenMolcas is a quantum chemistry software package developed by scientists and intended to be used by scientists. It includes programs to apply many different electronic structure methods to chemical systems, but its key feature is the multiconfigurational approach, with methods like CASSCF and CASPT2.

OpenMolcas is not a fork or reimplementation of [Molcas](http://www.molcas.org), it *is* a large part of the Molcas codebase that has been released as free and open-source software (FOSS) under the Lesser General Public License (LGPL) version 2.1. Some parts of Molcas remain under a different license by decision of their authors (or impossibility to reach them), and are therefore not included in OpenMolcas.

**Latest references**:

* "OpenMolcas: From Source Code to Insight."
  *J. Chem. Theory Comput.* **15** (2019) 5925-5964.
  [doi:10.1021/acs.jctc.9b00532](https://doi.org/10.1021/acs.jctc.9b00532)

* "Modern quantum chemistry with [Open]Molcas."
  *J. Chem. Phys.* **152** (2020) 214117.
  [doi:10.1063/5.0004835](https://doi.org/10.1063/5.0004835)

* "The OpenMolcas *Web*: A Community-Driven Approach to Advancing Computational Chemistry."
  *J. Chem. Theory Comput.* **19** (2023) 6933-6991.
  [doi:10.1021/acs.jctc.3c00182](https://doi.org/10.1021/acs.jctc.3c00182)

Installation
------------

For more detailed information, please refer to the [wiki pages](https://gitlab.com/Molcas/OpenMolcas/-/wikis/home).

OpenMolcas is configured with [CMake](https://cmake.org). A quick way to get it up and running is the following:

1.  Clone the repository:

    ```
    git clone https://gitlab.com/Molcas/OpenMolcas.git
    ```

2.  Get the `lapack` submodule (only needed if you don't use another linear algebra library like MKL or OpenBLAS):

    ```
    cd OpenMolcas
    git submodule update --init External/lapack
    cd ..
    ```

3.  Create a new directory and run `cmake` from it:

    ```
    mkdir build
    cd build
    cmake ../OpenMolcas
    ```

4.  Compile with `make`:

    ```
    make
    ```

5.  Run the verification suite (failures in "grayzone" tests are expected):

    ```
    ./pymolcas verify
    ```

For running other calculations you should define the `MOLCAS` environment variable to point to the `build` directory. Run `./pymolcas --help` to see the available options of the script. In particular it is recommended to run:
```
./pymolcas -setup
```
for your first installation.

Documentation
-------------

The documentation can be found in the [`doc`](https://gitlab.com/Molcas/OpenMolcas/tree/master/doc) directory, you can read it in [HTML format](https://molcas.gitlab.io/OpenMolcas/sphinx/) or [PDF format](https://molcas.gitlab.io/OpenMolcas/Manual.pdf). Note that most of it precedes the creation of OpenMolcas and it is probably outdated in several points. It may also mention features not available in OpenMolcas.

Help
----

OpenMolcas is a community-supported software and as such it doesn't have an official technical support. If you have any problems or questions, you can use the [Issues](/../issues) page or the [Molcas forum](https://molcasforum.univie.ac.at), and hopefully some other user or developer will be able to help you.

If you need technical support, you can acquire a [Molcas license](http://www.molcas.org/order.html).

Contributing
------------

Since OpenMolcas is FOSS, you can download it, modify it and distribute it freely (according to the terms of the LGPL). If you would like your contributions to be included in the main repository, please contact one of the developers, write a message in the [forum](https://molcasforum.univie.ac.at) or submit a [merge request](https://docs.gitlab.com/user/project/merge_requests). Everyone is welcome to send patches, suggestions and bug reports, but please let us know if you would like to be a "developer" member of the `Molcas` group.

## Portable ERI factors (CHH5)

CHH5 exports C1 AO ERI factors and one-electron operators independently of temporary SEWARD files.
Choose one factor-generation method: conventional molecular CD in SEWARD, or RICD in GATEWAY with only CHH5 in SEWARD.
Combining GATEWAY RI/RICD with SEWARD Cholesky and CHH5 is rejected because the latter overrides the RI calculation.

```text
&GATEWAY
... coordinates, basis, and Group=NoSym ...
RICD
CDThreshold
1.0d-4
&SEWARD
CHH5
```

RICD factors have the auxiliary Coulomb metric absorbed and obey the same Gram convention as CD factors: `(pq|rs)=sum_L L[pq,L]*L[rs,L]`.
The RICD CDThreshold controls atomic auxiliary-basis construction; it is not a molecular ERI CD error tolerance.
Format 1.1 retains the version-1 `cholesky` storage-group name for both methods and adds explicit `provenance/factor_origin`, `ri_type`, `auxiliary_basis_kind`, `threshold_kind`, and `system/factor_generation_threshold` metadata.
`system/cholesky_threshold` is present only for conventional CD; RICD consumers must read its atomic-basis threshold and origin instead.
Other RI modes and non-C1 symmetry are outside this export contract.
