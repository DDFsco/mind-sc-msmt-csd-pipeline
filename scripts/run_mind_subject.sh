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

PE_DIR="${PE_DIR:-AP}"
TCK_SELECT="${TCK_SELECT:-100k}"
FS_OPENMP="${FS_OPENMP:-4}"
BIAS_BACKEND="${BIAS_BACKEND:-ants}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/container_runtime.sh"

if [[ "${CONTAINER_RUNTIME:-}" == native && -f "${SCRIPT_DIR}/setup_env.sh" ]]; then
  MIND_SETUP_QUIET=1 source "${SCRIPT_DIR}/setup_env.sh"
fi

if [[ -z "${FS_LICENSE:-}" ]]; then
  for candidate in \
    "${FREESURFER_HOME:+${FREESURFER_HOME}/license.txt}" \
    /usr/local/freesurfer-6.0.0/license.txt \
    /usr/local/freesurfer/license.txt \
    /opt/freesurfer/license.txt \
    "$HOME/license.txt"; do
    if [[ -n "$candidate" && -f "$candidate" ]]; then
      export FS_LICENSE="$candidate"
      break
    fi
  done
fi

if [[ -z "${FS_LICENSE:-}" || ! -f "${FS_LICENSE}" ]]; then
  echo "FS_LICENSE must point to a valid FreeSurfer license file." >&2
  exit 1
fi

RAW_DIR="${WORK_DIR}/raw/${SUBJECT_ID}_${SESSION_ID}"
DERIV_DIR="${WORK_DIR}/derivatives/${SUBJECT_ID}_${SESSION_ID}"
mkdir -p "$RAW_DIR" "$DERIV_DIR"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] [1/14] Convert BIDS to MRtrix"
"${SCRIPT_DIR}/prepare_raw_from_bids.sh" "$BIDS_DIR" "$SUBJECT_ID" "$SESSION_ID" "$RAW_DIR"

export PE_DIR TCK_SELECT FS_OPENMP BIAS_BACKEND

if [[ "$(container_runtime)" == native ]]; then
  "${SCRIPT_DIR}/run_protocol_no_reverse_pe.sh" "$RAW_DIR" "$DERIV_DIR" "${SUBJECT_ID}_${SESSION_ID}"
else
  container_exec \
    "$(cd "$RAW_DIR" && pwd):/raw:ro" \
    "$(cd "$DERIV_DIR" && pwd):/derivatives" \
    "${SCRIPT_DIR}/run_protocol_no_reverse_pe.sh:/run_protocol_no_reverse_pe.sh:ro" \
    "${FS_LICENSE}:/opt/freesurfer/license.txt:ro" \
    -- \
    /run_protocol_no_reverse_pe.sh /raw /derivatives "${SUBJECT_ID}_${SESSION_ID}"
fi

echo "Subject complete:"
echo "  raw: ${RAW_DIR}"
echo "  derivatives: ${DERIV_DIR}"
