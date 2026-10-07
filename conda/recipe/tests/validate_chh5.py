#!/usr/bin/env python3
import pathlib
import sys

import h5py
import numpy as np


EXPECTED_GRAM = np.array(
    [
        [0.7746059442114877, 0.44459112429456915, 0.5699948829139262],
        [0.44459112429456915, 0.29759055150774666, 0.44459112429456915],
        [0.5699948829139262, 0.44459112429456915, 0.7746059442114877],
    ]
)


# Independent RICD reference: v26.06.1 temporary SEWARD vectors, H2/STO-3G,
# 0.74 angstrom, C1, GATEWAY RICD/CDThreshold=1e-8, no SEWARD Cholesky.
# The atomic auxiliary basis does not reproduce the conventional-CD
# off-diagonal-pair self integral exactly; do not reuse EXPECTED_GRAM.
EXPECTED_RICD_GRAM = np.array(
    [
        [0.7746059442114877, 0.4445911242945691, 0.5699948829139262],
        [0.4445911242945691, 0.2940073571486398, 0.4445911242945691],
        [0.5699948829139262, 0.4445911242945691, 0.7746059442114873],
    ]
)


def text(value: object) -> str:
    if isinstance(value, bytes):
        return value.decode().rstrip("\x00")
    return str(value).rstrip("\x00")


def load_export(directory: pathlib.Path, expected_ranks: int, origin: str) -> tuple[np.ndarray, np.ndarray]:
    manifest_path = directory / "manifest.h5"
    assert manifest_path.is_file()
    with h5py.File(manifest_path, "r") as manifest:
        assert text(manifest.attrs["FORMAT_NAME"]) == "OpenMolcas NOCI SEWARD portable data"
        assert int(manifest.attrs["FORMAT_MAJOR"]) == 1
        assert int(manifest["system/n_symmetry"][()]) == 1
        assert int(manifest["system/n_mpi_ranks"][()]) == expected_ranks
        assert int(manifest.attrs["FORMAT_MINOR"]) == 1
        assert text(manifest["provenance/factor_origin"][()]) == origin
        assert float(manifest["system/factor_generation_threshold"][()]) > 0.0
        if origin == "ricd":
            assert int(manifest["provenance/ri_type"][()]) == 4
            assert text(manifest["provenance/auxiliary_basis_kind"][()]) in ("acd", "accd")
            assert text(manifest["provenance/threshold_kind"][()]) == "atomic_auxiliary_basis_cd"
            assert "system/cholesky_threshold" not in manifest
        else:
            assert text(manifest["provenance/threshold_kind"][()]) == "molecular_eri_cd"
            assert int(manifest["provenance/ri_type"][()]) == 0
        n_reduced = int(manifest["system/n_reduced_pairs"][()])
        n_auxiliary = int(manifest["system/n_auxiliary_global"][()])
        overlap = manifest["one_electron/overlap"][...]
        core = manifest["one_electron/core_hamiltonian"][...]
        np.testing.assert_allclose(manifest["system/nuclear_charges"][...], [1.0, 1.0], rtol=0.0, atol=0.0)
        np.testing.assert_allclose(manifest["system/effective_nuclear_charges"][...], [1.0, 1.0], rtol=0.0, atol=0.0)
        names = [text(value).strip() for value in manifest["shards/filenames"][...]]

    factors = np.empty((n_reduced, n_auxiliary), dtype=np.float64)
    assigned = np.zeros(n_auxiliary, dtype=bool)
    for name in names:
        with h5py.File(directory / name, "r") as shard:
            dataset = shard["cholesky/factors"]
            assert dataset.compression is None
            ids = shard["cholesky/global_auxiliary_indices"][...].astype(np.int64)
            values = dataset[...].T
            assert values.shape == (n_reduced, ids.size)
            for local_index, global_id in enumerate(ids):
                assert 1 <= global_id <= n_auxiliary
                assert not assigned[global_id - 1]
                factors[:, global_id - 1] = values[:, local_index]
                assigned[global_id - 1] = True
    assert assigned.all()
    np.testing.assert_allclose(overlap, [[1.0, 0.6598731211014597], [0.6598731211014597, 1.0]], rtol=0.0, atol=1.0e-9)
    np.testing.assert_allclose(core, [[-1.1209594575132389, -0.9593757705058865], [-0.9593757705058865, -1.1209594575132389]], rtol=0.0, atol=1.0e-8)
    np.testing.assert_allclose(factors @ factors.T, EXPECTED_RICD_GRAM if origin == "ricd" else EXPECTED_GRAM, rtol=0.0, atol=2.0e-9)
    return factors, overlap


def main() -> None:
    assert len(sys.argv) in (3, 4)
    origin = sys.argv[3] if len(sys.argv) == 4 else "conventional_cd"
    serial, serial_overlap = load_export(pathlib.Path(sys.argv[1]), 1, origin)
    parallel, parallel_overlap = load_export(pathlib.Path(sys.argv[2]), 2, origin)
    np.testing.assert_array_equal(parallel, serial)
    np.testing.assert_array_equal(parallel_overlap, serial_overlap)


if __name__ == "__main__":
    main()
