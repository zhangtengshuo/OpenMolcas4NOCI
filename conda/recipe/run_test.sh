#!/usr/bin/env bash
set -euo pipefail

test_root=$(mktemp -d "${TMPDIR:-/tmp}/openmolcas4noci-conda-test.XXXXXX")
trap 'rm -rf -- "$test_root"' EXIT
test_data_root="$SRC_DIR/conda/recipe/tests"

python - <<'PYTEST'
import ctypes
import os
from pathlib import Path
library = Path(os.environ["PREFIX"]) / "libexec/openmolcas4noci/lib/libmolcas.so"
ctypes.CDLL(str(library), mode=os.RTLD_NOW | os.RTLD_LOCAL)
PYTEST

cp "$test_data_root/h2_chh5.input" "$test_root/h2_serial.input"
cp "$test_data_root/h2_chh5.input" "$test_root/h2_mpi.input"
mkdir -p "$test_root/serial-work" "$test_root/mpi-work"

(
    cd "$test_root"
    MOLCAS_NPROCS=1 MOLCAS_OUTPUT="$test_root" MOLCAS_WORKDIR="$test_root/serial-work" OMP_NUM_THREADS=1 \
        pymolcas4noci h2_serial.input > h2_serial.out
)

(
    cd "$test_root"
    export OMPI_ALLOW_RUN_AS_ROOT=1
    export OMPI_ALLOW_RUN_AS_ROOT_CONFIRM=1
    MOLCAS_NPROCS=2 MOLCAS_OUTPUT="$test_root" MOLCAS_WORKDIR="$test_root/mpi-work" OMP_NUM_THREADS=1 \
        pymolcas4noci h2_mpi.input > h2_mpi.out
)

python "$test_data_root/validate_chh5.py" \
    "$test_root/h2_serial.NOCI_SEWARD_H5" \
    "$test_root/h2_mpi.NOCI_SEWARD_H5"
