#!/usr/bin/env bash
set -euo pipefail

if [[ "$#" -lt 1 || "$#" -gt 3 ]]; then
  echo "Usage: preflight.sh <bids_dir> [subject_id] [session_id]" >&2
  exit 1
fi

BIDS_DIR=$1
SUBJECT_ID="${2:-sub-mindb107}"
SESSION_ID="${3:-ses-placebo}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/container_runtime.sh"

fail=0
check_file() {
  if [[ -f "$1" ]]; then
    echo "OK: $1"
  else
    echo "MISSING: $1"
    fail=1
  fi
}

BASE="${BIDS_DIR}/${SUBJECT_ID}/${SESSION_ID}"
PREFIX="${SUBJECT_ID}_${SESSION_ID}"

check_file "${BASE}/dwi/${PREFIX}_dwi.nii.gz"
check_file "${BASE}/dwi/${PREFIX}_dwi.bvec"
check_file "${BASE}/dwi/${PREFIX}_dwi.bval"
check_file "${BASE}/anat/${PREFIX}_T1w.nii.gz"

if [[ -f "${BASE}/dwi/${PREFIX}_dwi.json" ]]; then
  echo "OK: ${BASE}/dwi/${PREFIX}_dwi.json"
else
  echo "WARN: DWI JSON missing; conversion can proceed with bvec/bval, but metadata are incomplete."
fi

if [[ -n "${FS_LICENSE:-}" && -f "$FS_LICENSE" ]]; then
  echo "OK: FS_LICENSE=$FS_LICENSE"
else
  echo "MISSING: FS_LICENSE must point to a valid FreeSurfer license file."
  fail=1
fi

RUNTIME="$(container_runtime)"
IMAGE="$(container_image)"
if [[ "$RUNTIME" == docker ]]; then
  echo "OK: docker executable found"
  if docker image inspect "$IMAGE" >/dev/null 2>&1; then
    echo "OK: Docker image present: $IMAGE"
  else
    echo "WARN: Docker image not present locally. Run: docker pull $IMAGE"
  fi
elif [[ "$RUNTIME" == apptainer || "$RUNTIME" == singularity ]]; then
  echo "OK: $RUNTIME executable found"
  if [[ -f "$IMAGE" ]]; then
    echo "OK: Apptainer/Singularity image present: $IMAGE"
  else
    echo "MISSING: Apptainer/Singularity image not found: $IMAGE"
    echo "Build it with: ./scripts/build_apptainer_image.sh $IMAGE"
    fail=1
  fi
elif [[ "$RUNTIME" == native ]]; then
  echo "OK: native runtime selected"
  if native_dependency_check; then
    echo "OK: native neuroimaging dependencies found"
  else
    fail=1
  fi
else
  echo "MISSING: no supported runtime found."
  echo "Install Docker/Apptainer/Singularity, or install native MRtrix/FSL/FreeSurfer/ANTs dependencies."
  fail=1
fi

if [[ "$fail" -ne 0 ]]; then
  echo "Preflight failed."
  exit 1
fi

echo "Preflight passed."
