#!/usr/bin/env bash
set -euo pipefail

if [[ "$#" -ne 4 ]]; then
  echo "Usage: prepare_raw_from_bids.sh <bids_dir> <subject_id> <session_id> <raw_out_dir>" >&2
  echo "Example: prepare_raw_from_bids.sh /data/ds007857 sub-mindb107 ses-placebo raw/sub-mindb107" >&2
  exit 1
fi

BIDS_DIR=$1
SUBJECT_ID=$2
SESSION_ID=$3
RAW_OUT_DIR=$4
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/container_runtime.sh"

SUB_SES_DIR="${BIDS_DIR}/${SUBJECT_ID}/${SESSION_ID}"
DWI_BASE="${SUB_SES_DIR}/dwi/${SUBJECT_ID}_${SESSION_ID}_dwi"
T1_BASE="${SUB_SES_DIR}/anat/${SUBJECT_ID}_${SESSION_ID}_T1w"

require_file() {
  if [[ ! -f "$1" ]]; then
    echo "Missing required file: $1" >&2
    exit 1
  fi
}

require_file "${DWI_BASE}.nii.gz"
require_file "${DWI_BASE}.bvec"
require_file "${DWI_BASE}.bval"
require_file "${T1_BASE}.nii.gz"

mkdir -p "$RAW_OUT_DIR"

json_args=()
if [[ -f "${DWI_BASE}.json" ]]; then
  json_args=(-json_import "/bids/${SUBJECT_ID}/${SESSION_ID}/dwi/${SUBJECT_ID}_${SESSION_ID}_dwi.json")
else
  echo "WARN: ${DWI_BASE}.json is missing; converting DWI with bvec/bval only." >&2
fi

container_exec \
  "$(cd "$BIDS_DIR" && pwd):/bids:ro" \
  "$(cd "$RAW_OUT_DIR" && pwd):/raw" \
  -- \
  mrconvert "/bids/${SUBJECT_ID}/${SESSION_ID}/dwi/${SUBJECT_ID}_${SESSION_ID}_dwi.nii.gz" /raw/dwi.mif \
    -fslgrad "/bids/${SUBJECT_ID}/${SESSION_ID}/dwi/${SUBJECT_ID}_${SESSION_ID}_dwi.bvec" \
             "/bids/${SUBJECT_ID}/${SESSION_ID}/dwi/${SUBJECT_ID}_${SESSION_ID}_dwi.bval" \
    "${json_args[@]}" -force

container_exec \
  "$(cd "$BIDS_DIR" && pwd):/bids:ro" \
  "$(cd "$RAW_OUT_DIR" && pwd):/raw" \
  -- \
  mrconvert "/bids/${SUBJECT_ID}/${SESSION_ID}/anat/${SUBJECT_ID}_${SESSION_ID}_T1w.nii.gz" /raw/T1w.mif -force

echo "Prepared MRtrix inputs:"
echo "  ${RAW_OUT_DIR}/dwi.mif"
echo "  ${RAW_OUT_DIR}/T1w.mif"
