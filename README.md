# OpenMolcas4NOCI

OpenMolcas4NOCI is a controlled derivative of OpenMolcas 26.06 for the integral-preparation workflow used by NOCI.jl; it is not a replacement for the general OpenMolcas distribution.

This release line is based on upstream OpenMolcas commit `4e52760a9bec07a7d253ee2fc5ac29fc5203bf27` and adds the NOCI-oriented SEWARD `CHH5` portable HDF5 export, EXPBAS `GUGAORDER`, selected integral-accumulation corrections, long installation-path support, a relocatable launcher, and a pinned Linux x86-64 Conda recipe.

## Conda installation

The package is not published yet. A locally indexed candidate can be installed together with its conda-forge runtime dependencies as follows:

```bash
conda create -n openmolcas4noci --override-channels -c ./local-channel -c conda-forge openmolcas4noci=26.06.1
conda activate openmolcas4noci
pymolcas4noci --help
```

After publication, replace the local channel path with the announced public channel.

The package installs the dedicated runtime below the Conda prefix at `libexec/openmolcas4noci` and exposes `pymolcas4noci` as its public command, so it does not replace a separately installed `pymolcas` command.

See `conda/README.md` for reproducible build instructions.

## NOCI.jl integration

NOCI.jl uses the package to locate `pymolcas4noci`, `libmolcas.so`, MPI, HDF5, and the `CHH5` export format without requiring users to configure site-specific OpenMolcas paths.

Managed installation in NOCI.jl remains unavailable until this package is published and NOCI.jl points its CondaPkg channel configuration at the public channel.

## Upstream OpenMolcas

The remainder of this document is the upstream OpenMolcas overview retained for license, citation, build, and documentation context.

OpenMolcas
==========

**Home page**: https://molcas.gitlab.io

OpenMolcas is a quantum chemistry software package developed by scientists
and intended to be used by scientists. It includes programs to apply many
different electronic structure methods to chemical systems, but its key
feature is the multiconfigurational approach, with methods like CASSCF and
CASPT2.

OpenMolcas is not a fork or reimplementation of
[Molcas](http://www.molcas.org), it *is* a large part of the Molcas codebase
that has been released as free and open-source software (FOSS) under the Lesser
General Public License (LGPL) version 2.1. Some parts of Molcas remain under a different
license by decision of their authors (or impossibility to reach them), and are
therefore not included in OpenMolcas.

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

For more detailed information, please refer to the [wiki
pages](https://gitlab.com/Molcas/OpenMolcas/-/wikis/home).

OpenMolcas is configured with [CMake](https://cmake.org). A quick way to get it
up and running is the following:

1.  Clone the repository:

    ```
    git clone https://gitlab.com/Molcas/OpenMolcas.git
    ```

2.  Get the `lapack` submodule (only needed if you don't use another linear
    algebra library like MKL or OpenBLAS):

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

For running other calculations you should define the `MOLCAS` environment
variable to point to the `build` directory. Run `./pymolcas --help` to see the
available options of the script. In particular it is recommended to run:
```
./pymolcas -setup
```
for your first installation.

Documentation
-------------

The documentation can be found in the
[`doc`](https://gitlab.com/Molcas/OpenMolcas/tree/master/doc) directory, you
can read it in [HTML format](https://molcas.gitlab.io/OpenMolcas/sphinx/) or
[PDF format](https://molcas.gitlab.io/OpenMolcas/Manual.pdf). Note that most
of it precedes the creation of OpenMolcas and it is probably outdated in
several points. It may also mention features not available in OpenMolcas.

Help
----

OpenMolcas is a community-supported software and as such it doesn't have an
official technical support. If you have any problems or questions, you can use
the [Issues](/../issues) page or the [Molcas
forum](https://molcasforum.univie.ac.at), and hopefully
some other user or developer will be able to help you.

If you need technical support, you can acquire a [Molcas
license](http://www.molcas.org/order.html).

Contributing
------------

Since OpenMolcas is FOSS, you can download it, modify it and distribute it
freely (according to the terms of the LGPL). If you would like your
contributions to be included in the main repository, please contact one of the
developers, write a message in the [forum](https://molcasforum.univie.ac.at) or
submit a [merge request](https://docs.gitlab.com/user/project/merge_requests).
Everyone is welcome to send patches, suggestions and bug reports, but please
let us know if you would like to be a "developer" member of the `Molcas` group.
