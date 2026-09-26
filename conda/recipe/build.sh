#!/usr/bin/env bash
set -euo pipefail

install_root="$PREFIX/libexec/openmolcas4noci"
build_root="$SRC_DIR/build-openmolcas4noci"
source_revision=
if command -v git >/dev/null 2>&1; then
    source_revision=$(git -C "$SRC_DIR" rev-parse HEAD 2>/dev/null || true)
fi
source_revision=${source_revision:-${OPENMOLCAS4NOCI_SOURCE_COMMIT:-unknown}}

export CC="${CC}"
export CXX="${CXX}"
export FC="${FC}"
export MKLROOT="$PREFIX"
export GAROOT="$PREFIX"
export HDF5_ROOT="$PREFIX"
export CMAKE_PREFIX_PATH="$PREFIX"
prefix_map_flags="-ffile-prefix-map=$SRC_DIR=/usr/local/src/conda/openmolcas4noci-${PKG_VERSION} -ffile-prefix-map=$BUILD_PREFIX=/usr/local/src/conda-build"
export CFLAGS="${CFLAGS:-} $prefix_map_flags"
export CXXFLAGS="${CXXFLAGS:-} $prefix_map_flags"
export FFLAGS="${FFLAGS:-} $prefix_map_flags -P"

cmake -S "$SRC_DIR" -B "$build_root" -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="$install_root" \
    -DCMAKE_INSTALL_RPATH='$ORIGIN/../lib;$ORIGIN/../../../lib' \
    -DCMAKE_INSTALL_RPATH_USE_LINK_PATH=FALSE \
    -DOPENMOLCAS_RELEASE_VERSION="openmolcas4noci-v${PKG_VERSION}" \
    -DMPI=ON \
    -DMPI_LAUNCHER='mpiexec -n $MOLCAS_NPROCS' \
    -DGA=ON \
    -DGA_BUILD=OFF \
    -DOPENMP=ON \
    -DHDF5=ON \
    -DGEN1INT=OFF \
    -DLINALG=MKL \
    -DEXTERNAL_LIBXC="$PREFIX" \
    -DWIGNERNJ_SOURCE_DIR="$SRC_DIR/wignernj-source" \
    -DBUILD_SHARED_LIBS=ON \
    -DBUILD_STATIC_LIBS=OFF \
    -DBUILD_TESTING=OFF \
    -DINSTALL_TESTS=OFF \
    -DTOOLS=OFF \
    -DPython_EXECUTABLE="$PREFIX/bin/python"

cmake --build "$build_root" --parallel "${CPU_COUNT:-2}"
cmake --install "$build_root"

portable_rpath='$ORIGIN:$ORIGIN/../lib:$ORIGIN/../../../lib'
while IFS= read -r -d '' installed_file; do
    if patchelf --print-rpath "$installed_file" >/dev/null 2>&1; then
        patchelf --set-rpath "$portable_rpath" "$installed_file"
    fi
done < <(find "$install_root/bin" "$install_root/lib" -type f -print0)

sed -i \
    -e "s|$PREFIX|<PREFIX>|g" \
    -e "s|$BUILD_PREFIX|<BUILD_PREFIX>|g" \
    -e "s|$SRC_DIR|<SOURCE_DIR>|g" \
    "$install_root/data/info.txt"

install -d "$PREFIX/bin" "$PREFIX/share/licenses/openmolcas4noci" "$PREFIX/share/openmolcas4noci"
install -m 0755 "$RECIPE_DIR/pymolcas4noci" "$PREFIX/bin/pymolcas4noci"
install -m 0644 "$SRC_DIR/LICENSE" "$PREFIX/share/licenses/openmolcas4noci/OpenMolcas-LICENSE"
install -m 0644 "$SRC_DIR/wignernj-source/LICENSE" "$PREFIX/share/licenses/openmolcas4noci/libwignernj-LICENSE"

printf '%s\n' \
    '{' \
    "  \"package\": \"openmolcas4noci\"," \
    "  \"version\": \"${PKG_VERSION}\"," \
    "  \"build_number\": ${PKG_BUILDNUM}," \
    '  "upstream_commit": "4e52760a9bec07a7d253ee2fc5ac29fc5203bf27",' \
    "  \"source_revision\": \"${source_revision}\"," \
    '  "mpi": "openmpi",' \
    '  "blas_lapack": "mkl",' \
    '  "gen1int": false' \
    '}' > "$PREFIX/share/openmolcas4noci/release-manifest.json"

if rg -a --hidden --fixed-strings "$BUILD_PREFIX" "$install_root"; then
    echo "build prefix remains in the installed OpenMolcas tree" >&2
    exit 1
fi
if rg -a --hidden --fixed-strings "$SRC_DIR" "$install_root"; then
    echo "source prefix remains in the installed OpenMolcas tree" >&2
    exit 1
fi
if rg -a --hidden --fixed-strings "$PREFIX" "$install_root"; then
    echo "host prefix remains in the installed OpenMolcas tree" >&2
    exit 1
fi
