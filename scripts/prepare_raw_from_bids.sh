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

UNIT_BVEC="${RAW_OUT_DIR}/dwi_unit.bvec"
# GE/dcm2niix exports can contain non-unit bvecs. MRtrix otherwise scales
# b-values by |g|^2, which turns nominal shells into non-shelled b-values.
awk '
  NR == 1 { for (i = 1; i <= NF; i++) x[i] = $i; n = NF }
  NR == 2 { for (i = 1; i <= NF; i++) y[i] = $i }
  NR == 3 { for (i = 1; i <= NF; i++) z[i] = $i }
  END {
    if (NR != 3) {
      print "Expected FSL bvec file with exactly 3 rows" > "/dev/stderr"
      exit 1
    }
    for (i = 1; i <= n; i++) {
      norm = sqrt(x[i] * x[i] + y[i] * y[i] + z[i] * z[i])
      if (norm > 0) {
        x[i] /= norm
        y[i] /= norm
        z[i] /= norm
      }
    }
    for (i = 1; i <= n; i++) printf "%s%.10g", (i == 1 ? "" : " "), x[i]
    printf "\n"
    for (i = 1; i <= n; i++) printf "%s%.10g", (i == 1 ? "" : " "), y[i]
    printf "\n"
    for (i = 1; i <= n; i++) printf "%s%.10g", (i == 1 ? "" : " "), z[i]
    printf "\n"
  }
' "${DWI_BASE}.bvec" > "$UNIT_BVEC"
echo "Prepared unit-normalized bvecs: $UNIT_BVEC"

json_args=()
if [[ -f "${DWI_BASE}.json" ]]; then
  if [[ "$(container_runtime)" == native ]]; then
    json_args=(-json_import "${DWI_BASE}.json")
  else
    json_args=(-json_import "/bids/${SUBJECT_ID}/${SESSION_ID}/dwi/${SUBJECT_ID}_${SESSION_ID}_dwi.json")
  fi
else
  echo "WARN: ${DWI_BASE}.json is missing; converting DWI with bvec/bval only." >&2
fi

if [[ "$(container_runtime)" == native ]]; then
  mrconvert "${DWI_BASE}.nii.gz" "${RAW_OUT_DIR}/dwi.mif" \
    -fslgrad "$UNIT_BVEC" "${DWI_BASE}.bval" \
    -bvalue_scaling false \
    "${json_args[@]}" -force

  mrconvert "${T1_BASE}.nii.gz" "${RAW_OUT_DIR}/T1w.mif" -force
else
  container_exec \
    "$(cd "$BIDS_DIR" && pwd):/bids:ro" \
    "$(cd "$RAW_OUT_DIR" && pwd):/raw" \
    -- \
    mrconvert "/bids/${SUBJECT_ID}/${SESSION_ID}/dwi/${SUBJECT_ID}_${SESSION_ID}_dwi.nii.gz" /raw/dwi.mif \
      -fslgrad /raw/dwi_unit.bvec \
               "/bids/${SUBJECT_ID}/${SESSION_ID}/dwi/${SUBJECT_ID}_${SESSION_ID}_dwi.bval" \
      -bvalue_scaling false \
      "${json_args[@]}" -force

  container_exec \
    "$(cd "$BIDS_DIR" && pwd):/bids:ro" \
    "$(cd "$RAW_OUT_DIR" && pwd):/raw" \
    -- \
    mrconvert "/bids/${SUBJECT_ID}/${SESSION_ID}/anat/${SUBJECT_ID}_${SESSION_ID}_T1w.nii.gz" /raw/T1w.mif -force
fi

echo "Prepared MRtrix inputs:"
echo "  ${RAW_OUT_DIR}/dwi.mif"
echo "  ${RAW_OUT_DIR}/T1w.mif"
