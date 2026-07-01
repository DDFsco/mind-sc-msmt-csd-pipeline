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
    echo "No supported container runtime found. Install Docker, Apptainer, or Singularity." >&2
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
  esac
}
