#!/usr/bin/env bash

# Source this file before running the pipeline on a native Linux install:
#   source scripts/setup_env.sh

_mind_source_relaxed() {
  local script_path=$1
  local had_e=0
  local had_u=0
  local had_pipefail=0

  case "$-" in
    *e*) had_e=1 ;;
  esac
  case "$-" in
    *u*) had_u=1 ;;
  esac
  if set -o | grep -q '^pipefail[[:space:]]*on'; then
    had_pipefail=1
  fi

  set +e
  set +u
  set +o pipefail 2>/dev/null || true

  # Some older FreeSurfer/FSL setup scripts use unset variables and grep
  # pipelines that are harmless interactively but fail under set -euo pipefail.
  # shellcheck disable=SC1090
  source "$script_path"
  local status=$?

  if [[ "$had_pipefail" -eq 1 ]]; then
    set -o pipefail
  fi
  if [[ "$had_u" -eq 1 ]]; then
    set -u
  fi
  if [[ "$had_e" -eq 1 ]]; then
    set -e
  fi

  return "$status"
}

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

if [[ -z "${FREESURFER_HOME:-}" ]]; then
  for candidate in \
    /usr/local/freesurfer-6.0.0 \
    /usr/local/freesurfer \
    /opt/freesurfer; do
    if [[ -d "$candidate" ]]; then
      export FREESURFER_HOME="$candidate"
      break
    fi
  done
fi

if [[ -n "${FREESURFER_HOME:-}" && -f "${FREESURFER_HOME}/SetUpFreeSurfer.sh" ]]; then
  export FS_FREESURFERENV_NO_OUTPUT=1
  if ! _mind_source_relaxed "${FREESURFER_HOME}/SetUpFreeSurfer.sh"; then
    echo "WARN: FreeSurfer setup returned a non-zero status; continuing with detected paths." >&2
  fi
fi

if [[ -n "${FSLDIR:-}" && -f "${FSLDIR}/etc/fslconf/fsl.sh" ]]; then
  if ! _mind_source_relaxed "${FSLDIR}/etc/fslconf/fsl.sh"; then
    echo "WARN: FSL setup returned a non-zero status; continuing with detected paths." >&2
  fi
elif [[ -d /usr/local/fsl ]]; then
  export FSLDIR=/usr/local/fsl
  if ! _mind_source_relaxed "${FSLDIR}/etc/fslconf/fsl.sh"; then
    echo "WARN: FSL setup returned a non-zero status; continuing with detected paths." >&2
  fi
elif [[ -d /opt/fsl ]]; then
  export FSLDIR=/opt/fsl
  if ! _mind_source_relaxed "${FSLDIR}/etc/fslconf/fsl.sh"; then
    echo "WARN: FSL setup returned a non-zero status; continuing with detected paths." >&2
  fi
fi

for ants_dir in \
  "${ANTSPATH:-}" \
  /usr/local/ants/bin \
  /opt/ants/bin; do
  if [[ -n "$ants_dir" && -d "$ants_dir" ]]; then
    case ":$PATH:" in
      *":$ants_dir:"*) ;;
      *) export PATH="${ants_dir}:$PATH" ;;
    esac
  fi
done

export PE_DIR="${PE_DIR:-AP}"
export TCK_SELECT="${TCK_SELECT:-100k}"
export FS_OPENMP="${FS_OPENMP:-4}"
export BIAS_BACKEND="${BIAS_BACKEND:-ants}"

if [[ "$BIAS_BACKEND" == ants ]] && ! command -v N4BiasFieldCorrection >/dev/null 2>&1 && command -v fast >/dev/null 2>&1; then
  export BIAS_BACKEND=fsl
  echo "WARN: N4BiasFieldCorrection not found -> using BIAS_BACKEND=fsl" >&2
fi

if [[ "${MIND_SETUP_QUIET:-0}" != 1 ]]; then
  echo "FS_LICENSE=${FS_LICENSE:-missing}"
  echo "FREESURFER_HOME=${FREESURFER_HOME:-missing}"
  echo "FSLDIR=${FSLDIR:-missing}"
  echo "BIAS_BACKEND=${BIAS_BACKEND}"
fi
