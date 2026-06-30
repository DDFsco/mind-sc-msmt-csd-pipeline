#!/usr/bin/env bash
set -euo pipefail

if [[ "$#" -ne 4 ]]; then
  echo "Usage: run_mind_subject.sh <bids_dir> <subject_id> <session_id> <work_dir>" >&2
  echo "Example: run_mind_subject.sh /data/ds007857 sub-mindb107 ses-placebo /scratch/mind-sc" >&2
  exit 1
fi

BIDS_DIR=$1
SUBJECT_ID=$2
SESSION_ID=$3
WORK_DIR=$4

IMAGE="${SC_MSMT_CSD_IMAGE:-martah/sc-construction-using-msmt-csd}"
PE_DIR="${PE_DIR:-AP}"
TCK_SELECT="${TCK_SELECT:-100k}"
FS_OPENMP="${FS_OPENMP:-4}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ -z "${FS_LICENSE:-}" || ! -f "${FS_LICENSE}" ]]; then
  echo "FS_LICENSE must point to a valid FreeSurfer license file." >&2
  exit 1
fi

RAW_DIR="${WORK_DIR}/raw/${SUBJECT_ID}_${SESSION_ID}"
DERIV_DIR="${WORK_DIR}/derivatives/${SUBJECT_ID}_${SESSION_ID}"
mkdir -p "$RAW_DIR" "$DERIV_DIR"

"${SCRIPT_DIR}/prepare_raw_from_bids.sh" "$BIDS_DIR" "$SUBJECT_ID" "$SESSION_ID" "$RAW_DIR"

docker run --rm \
  -v "$(cd "$RAW_DIR" && pwd)":/raw:ro \
  -v "$(cd "$DERIV_DIR" && pwd)":/derivatives \
  -v "${SCRIPT_DIR}/run_protocol_no_reverse_pe.sh":/run_protocol_no_reverse_pe.sh:ro \
  -v "${FS_LICENSE}":/opt/freesurfer/license.txt:ro \
  -e PE_DIR="$PE_DIR" \
  -e TCK_SELECT="$TCK_SELECT" \
  -e FS_OPENMP="$FS_OPENMP" \
  "$IMAGE" \
  /run_protocol_no_reverse_pe.sh /raw /derivatives "${SUBJECT_ID}_${SESSION_ID}"

echo "Subject complete:"
echo "  raw: ${RAW_DIR}"
echo "  derivatives: ${DERIV_DIR}"
