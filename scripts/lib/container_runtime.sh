#!/usr/bin/env bash

container_runtime() {
  if [[ -n "${CONTAINER_RUNTIME:-}" ]]; then
    echo "$CONTAINER_RUNTIME"
  elif command -v docker >/dev/null 2>&1; then
    echo docker
  elif command -v apptainer >/dev/null 2>&1; then
    echo apptainer
  elif command -v singularity >/dev/null 2>&1; then
    echo singularity
  elif command -v mrconvert >/dev/null 2>&1; then
    echo native
  else
    echo none
  fi
}

container_image() {
  local runtime
  runtime="$(container_runtime)"
  case "$runtime" in
    docker)
      echo "${SC_MSMT_CSD_IMAGE:-martah/sc-construction-using-msmt-csd}"
      ;;
    apptainer|singularity)
      echo "${SC_MSMT_CSD_SIF:-${APPTAINER_IMAGE:-sc-construction-using-msmt-csd.sif}}"
      ;;
    native)
      echo native
      ;;
    *)
      echo ""
      ;;
  esac
}

container_exec() {
  local runtime image
  runtime="$(container_runtime)"
  image="$(container_image)"

  if [[ "$runtime" == none ]]; then
    echo "No supported runtime found. Install Docker, Apptainer, Singularity, or native MRtrix/FSL/FreeSurfer/ANTs dependencies." >&2
    return 1
  fi

  if [[ -z "$image" ]]; then
    echo "Container image is not configured." >&2
    return 1
  fi

  local binds=()
  while [[ "$#" -gt 0 && "$1" != "--" ]]; do
    binds+=("$1")
    shift
  done
  if [[ "$#" -eq 0 ]]; then
    echo "container_exec missing -- separator" >&2
    return 1
  fi
  shift

  case "$runtime" in
    docker)
      local docker_args=()
      for bind in "${binds[@]}"; do
        docker_args+=(-v "$bind")
      done
      docker run --rm "${docker_args[@]}" "$image" "$@"
      ;;
    apptainer)
      local apptainer_args=()
      for bind in "${binds[@]}"; do
        apptainer_args+=(--bind "$bind")
      done
      apptainer exec "${apptainer_args[@]}" "$image" "$@"
      ;;
    singularity)
      local singularity_args=()
      for bind in "${binds[@]}"; do
        singularity_args+=(--bind "$bind")
      done
      singularity exec "${singularity_args[@]}" "$image" "$@"
      ;;
    native)
      local source_path target_path mode
      for bind in "${binds[@]}"; do
        IFS=: read -r source_path target_path mode <<< "$bind"
        if [[ -z "${source_path:-}" || -z "${target_path:-}" ]]; then
          echo "Invalid native bind: $bind" >&2
          return 1
        fi
        if [[ -e "$target_path" && "$target_path" != "$source_path" ]]; then
          echo "Native runtime target already exists and is not a symlink: $target_path" >&2
          return 1
        fi
        mkdir -p "$(dirname "$target_path")"
        ln -sfn "$source_path" "$target_path"
      done
      "$@"
      ;;
  esac
}

find_mrtrix_fs_default() {
  local candidate
  for candidate in \
    "${MRTRIX_FS_DEFAULT:-}" \
    /opt/mrtrix3/share/mrtrix3/labelconvert/fs_default.txt \
    /usr/local/mrtrix3/share/mrtrix3/labelconvert/fs_default.txt \
    /usr/share/mrtrix3/labelconvert/fs_default.txt; do
    if [[ -n "$candidate" && -f "$candidate" ]]; then
      echo "$candidate"
      return 0
    fi
  done

  if command -v labelconvert >/dev/null 2>&1; then
    local prefix
    prefix="$(cd "$(dirname "$(command -v labelconvert)")/.." && pwd)"
    candidate="${prefix}/share/mrtrix3/labelconvert/fs_default.txt"
    if [[ -f "$candidate" ]]; then
      echo "$candidate"
      return 0
    fi
  fi

  return 1
}

native_dependency_check() {
  local missing=0
  local commands=(
    mrconvert
    dwidenoise
    mrdegibbs
    dwifslpreproc
    dwibiascorrect
    dwiextract
    mrmath
    flirt
    transformconvert
    mrtransform
    dwi2mask
    dwi2response
    dwi2fod
    mtnormalise
    5ttgen
    tckgen
    tcksift2
    labelconvert
    tck2connectome
    recon-all
  )
  if [[ "${BIAS_BACKEND:-ants}" == ants ]]; then
    commands+=(N4BiasFieldCorrection)
  elif [[ "${BIAS_BACKEND:-ants}" == fsl ]]; then
    commands+=(fast)
  fi
  for cmd in "${commands[@]}"; do
    if command -v "$cmd" >/dev/null 2>&1; then
      echo "OK: $cmd"
    else
      echo "MISSING: $cmd"
      missing=1
    fi
  done
  return "$missing"
}
