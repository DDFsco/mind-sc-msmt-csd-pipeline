#!/usr/bin/env bash
set -euo pipefail

if [[ "$#" -lt 1 || "$#" -gt 3 ]]; then
  echo "Usage: preflight.sh <bids_dir> [subject_id] [session_id]" >&2
  exit 1
fi

BIDS_DIR=$1
SUBJECT_ID="${2:-sub-mindb107}"
SESSION_ID="${3:-ses-placebo}"
IMAGE="${SC_MSMT_CSD_IMAGE:-martah/sc-construction-using-msmt-csd}"

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

if command -v docker >/dev/null 2>&1; then
  echo "OK: docker executable found"
  if docker image inspect "$IMAGE" >/dev/null 2>&1; then
    echo "OK: Docker image present: $IMAGE"
  else
    echo "WARN: Docker image not present locally. Run: docker pull $IMAGE"
  fi
else
  echo "MISSING: docker executable not found."
  fail=1
fi

if [[ "$fail" -ne 0 ]]; then
  echo "Preflight failed."
  exit 1
fi

echo "Preflight passed."
