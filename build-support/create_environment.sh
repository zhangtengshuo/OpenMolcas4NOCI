#!/usr/bin/env bash
set -euo pipefail

source_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
workspace_root=${OPENMOLCAS4NOCI_WORKSPACE_ROOT:-$(dirname "$source_root")}
version_root=${OPENMOLCAS4NOCI_VERSION_ROOT:-$workspace_root/build/v26.06.2}
environment_prefix=${OPENMOLCAS4NOCI_ENV_PREFIX:-$version_root/env}
micromamba_root=${MAMBA_ROOT_PREFIX:-$workspace_root/build/shared/micromamba-root}
environment_spec=${OPENMOLCAS4NOCI_ENV_SPEC:-$source_root/build-support/environment-linux-64.lock}

export MAMBA_ROOT_PREFIX="$micromamba_root"
micromamba create --yes --prefix "$environment_prefix" --file "$environment_spec"

printf '%s\n' "Created OpenMolcas4NOCI environment at $environment_prefix"
