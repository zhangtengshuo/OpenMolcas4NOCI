#!/usr/bin/env bash
set -euo pipefail

source_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
workspace_root=${OPENMOLCAS4NOCI_WORKSPACE_ROOT:-$(dirname "$source_root")}
version_root=${OPENMOLCAS4NOCI_VERSION_ROOT:-$workspace_root/build/v26.06.1}
environment_prefix=${OPENMOLCAS4NOCI_ENV_PREFIX:-$version_root/env}
build_root=${OPENMOLCAS4NOCI_BUILD_ROOT:-$version_root/cmake}
install_root=${OPENMOLCAS4NOCI_INSTALL_ROOT:-$version_root/install}

export PATH="$environment_prefix/bin:/usr/bin:/bin"
export LD_LIBRARY_PATH="$environment_prefix/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export CC="$environment_prefix/bin/x86_64-conda-linux-gnu-cc"
export CXX="$environment_prefix/bin/x86_64-conda-linux-gnu-c++"
export FC="$environment_prefix/bin/x86_64-conda-linux-gnu-gfortran"
export MKLROOT="$environment_prefix"
export GAROOT="$environment_prefix"
export HDF5_ROOT="$environment_prefix"
export CMAKE_PREFIX_PATH="$environment_prefix"

cmake -S "$source_root" -B "$build_root" -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="$install_root" \
  -DMPI=ON \
  -DGA=ON \
  -DGA_BUILD=OFF \
  -DOPENMP=ON \
  -DHDF5=ON \
  -DLINALG=MKL \
  -DEXTERNAL_LIBXC="$environment_prefix" \
  -DBUILD_SHARED_LIBS=ON \
  -DBUILD_STATIC_LIBS=OFF \
  -DBUILD_TESTING=OFF \
  -DINSTALL_TESTS=OFF \
  -DTOOLS=OFF \
  -DPython_EXECUTABLE="$environment_prefix/bin/python"

cmake --build "$build_root" --parallel "${OPENMOLCAS4NOCI_BUILD_JOBS:-8}"
cmake --install "$build_root"

printf '%s\n' "Installed OpenMolcas4NOCI at $install_root"
