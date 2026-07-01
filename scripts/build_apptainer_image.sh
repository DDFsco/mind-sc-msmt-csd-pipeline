#!/usr/bin/env bash
set -euo pipefail

SIF_OUT="${1:-sc-construction-using-msmt-csd.sif}"
DOCKER_IMAGE="${SC_MSMT_CSD_IMAGE:-martah/sc-construction-using-msmt-csd}"

if command -v apptainer >/dev/null 2>&1; then
  apptainer build "$SIF_OUT" "docker://${DOCKER_IMAGE}"
elif command -v singularity >/dev/null 2>&1; then
  singularity build "$SIF_OUT" "docker://${DOCKER_IMAGE}"
else
  echo "Neither apptainer nor singularity was found." >&2
  exit 1
fi

echo "Built container image: $SIF_OUT"
