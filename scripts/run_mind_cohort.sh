#!/usr/bin/env bash
set -euo pipefail

if [[ "$#" -ne 2 ]]; then
  echo "Usage: run_mind_cohort.sh <bids_dir> <work_dir>" >&2
  echo "Subjects are read from stdin, one subject id per line." >&2
  echo "Example: cut -f1 subjects.tsv | tail -n +2 | ./scripts/run_mind_cohort.sh /data/ds007857 /scratch/mind-sc" >&2
  exit 1
fi

BIDS_DIR=$1
WORK_DIR=$2
SESSION_ID="${SESSION_ID:-ses-placebo}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

while IFS= read -r SUBJECT_ID; do
  [[ -z "$SUBJECT_ID" || "$SUBJECT_ID" == subject* ]] && continue
  echo "=== Running ${SUBJECT_ID} ${SESSION_ID} ==="
  "${SCRIPT_DIR}/run_mind_subject.sh" "$BIDS_DIR" "$SUBJECT_ID" "$SESSION_ID" "$WORK_DIR"
done
