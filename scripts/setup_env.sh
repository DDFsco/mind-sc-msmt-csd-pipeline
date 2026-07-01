#!/usr/bin/env bash

# Source this file before running the pipeline on a native Linux install:
#   source scripts/setup_env.sh

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
  # shellcheck disable=SC1091
  source "${FREESURFER_HOME}/SetUpFreeSurfer.sh"
fi

if [[ -n "${FSLDIR:-}" && -f "${FSLDIR}/etc/fslconf/fsl.sh" ]]; then
  # shellcheck disable=SC1091
  source "${FSLDIR}/etc/fslconf/fsl.sh"
elif [[ -d /usr/local/fsl ]]; then
  export FSLDIR=/usr/local/fsl
  # shellcheck disable=SC1091
  source "${FSLDIR}/etc/fslconf/fsl.sh"
elif [[ -d /opt/fsl ]]; then
  export FSLDIR=/opt/fsl
  # shellcheck disable=SC1091
  source "${FSLDIR}/etc/fslconf/fsl.sh"
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

if [[ "${MIND_SETUP_QUIET:-0}" != 1 ]]; then
  echo "FS_LICENSE=${FS_LICENSE:-missing}"
  echo "FREESURFER_HOME=${FREESURFER_HOME:-missing}"
  echo "FSLDIR=${FSLDIR:-missing}"
  echo "BIAS_BACKEND=${BIAS_BACKEND}"
fi
