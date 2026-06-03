#!/usr/bin/env bash
# Bootstrap Pyrrhus JupyterLab for Brev Launchables or other Docker hosts.

set -Eeuo pipefail

DEFAULT_IMAGE="ghcr.io/liveaverage/pyrrhus-jupyter:slim"
DEFAULT_NOTEBOOK_URL="https://raw.githubusercontent.com/liveaverage/jupyter-launch/main/notebooks/sample-launch.ipynb"

JUPYTER_IMAGE="${JUPYTER_IMAGE:-${DEFAULT_IMAGE}}"
NOTEBOOK_URL="${NOTEBOOK_URL:-${DEFAULT_NOTEBOOK_URL}}"
AUTO_NOTEBOOK="${AUTO_NOTEBOOK:-$(basename "${NOTEBOOK_URL%%\?*}")}"
JUPYTER_PORT="${JUPYTER_PORT:-8888}"
JUPYTER_CONTAINER_NAME="${JUPYTER_CONTAINER_NAME:-jupyter-launch}"
JUPYTER_TOKEN="${JUPYTER_TOKEN:-}"
REPLACE_EXISTING="${REPLACE_EXISTING:-1}"
ENABLE_GPU="${ENABLE_GPU:-0}"
EXTRA_DOCKER_ARGS="${EXTRA_DOCKER_ARGS:-}"
STAGE_NOTEBOOK="${STAGE_NOTEBOOK:-1}"
NOTEBOOK_STAGING_DIR="${NOTEBOOK_STAGING_DIR:-/tmp/${JUPYTER_CONTAINER_NAME}}"
SKIP_IMAGE_PULL="${SKIP_IMAGE_PULL:-0}"
DRY_RUN="${DRY_RUN:-0}"

log() {
  printf '[jupyter-launch] %s\n' "$*" >&2
}

require_docker() {
  if ! command -v docker >/dev/null 2>&1; then
    log "ERROR: docker is not installed or is not on PATH."
    exit 1
  fi
}

download_notebook() {
  notebook_filename="$(basename "${AUTO_NOTEBOOK}")"
  staged_notebook="${NOTEBOOK_STAGING_DIR}/${notebook_filename}"

  if [ "${DRY_RUN}" = "1" ]; then
    log "+ mkdir -p ${NOTEBOOK_STAGING_DIR}"
    log "+ download ${NOTEBOOK_URL} -> ${staged_notebook}"
    printf '%s\n' "${staged_notebook}"
    return 0
  fi

  mkdir -p "${NOTEBOOK_STAGING_DIR}"

  if command -v curl >/dev/null 2>&1; then
    curl -fsSL -o "${staged_notebook}" "${NOTEBOOK_URL}"
  elif command -v wget >/dev/null 2>&1; then
    wget -q -O "${staged_notebook}" "${NOTEBOOK_URL}"
  else
    log "ERROR: install curl or wget, or set STAGE_NOTEBOOK=0 to let the container fetch NOTEBOOK_URL."
    exit 1
  fi

  printf '%s\n' "${staged_notebook}"
}

run() {
  log "+ $*"
  if [ "${DRY_RUN}" != "1" ]; then
    "$@"
  fi
}

main() {
  if [ "${DRY_RUN}" != "1" ]; then
    require_docker
  fi

  log "Container image: ${JUPYTER_IMAGE}"
  log "Notebook URL: ${NOTEBOOK_URL}"
  log "Notebook target: ${AUTO_NOTEBOOK}"
  log "Host port: ${JUPYTER_PORT}"

  staged_notebook=""
  if [ "${STAGE_NOTEBOOK}" = "1" ]; then
    staged_notebook="$(download_notebook)"
    log "Staged notebook: ${staged_notebook}"
  fi

  if [ "${DRY_RUN}" != "1" ] && docker ps -a --format '{{.Names}}' | grep -qx "${JUPYTER_CONTAINER_NAME}"; then
    if [ "${REPLACE_EXISTING}" = "1" ]; then
      run docker rm -f "${JUPYTER_CONTAINER_NAME}"
    else
      log "Container ${JUPYTER_CONTAINER_NAME} already exists. Set REPLACE_EXISTING=1 to recreate it."
      exit 0
    fi
  fi

  if [ "${SKIP_IMAGE_PULL}" = "1" ]; then
    log "Skipping image pull for ${JUPYTER_IMAGE}"
  else
    run docker pull "${JUPYTER_IMAGE}"
  fi

  docker_args=(
    run
    -d
    --name "${JUPYTER_CONTAINER_NAME}"
    -p "${JUPYTER_PORT}:8888"
    -e "NOTEBOOK_URL=${NOTEBOOK_URL}"
    -e "AUTO_NOTEBOOK=${AUTO_NOTEBOOK}"
    -e "JUPYTER_TOKEN=${JUPYTER_TOKEN}"
  )

  if [ -n "${staged_notebook}" ]; then
    notebook_filename="$(basename "${AUTO_NOTEBOOK}")"
    docker_args+=(-v "${staged_notebook}:/home/jovyan/work/${notebook_filename}:ro")
  fi

  if [ "${ENABLE_GPU}" = "1" ]; then
    docker_args+=(--gpus all)
  fi

  if [ -n "${EXTRA_DOCKER_ARGS}" ]; then
    # Intentional word splitting lets Launchable users pass simple Docker flags.
    # shellcheck disable=SC2206
    extra_args=(${EXTRA_DOCKER_ARGS})
    docker_args+=("${extra_args[@]}")
  fi

  docker_args+=("${JUPYTER_IMAGE}")

  run docker "${docker_args[@]}"

  log "JupyterLab is starting at http://localhost:${JUPYTER_PORT}/lab"
  log "Container: ${JUPYTER_CONTAINER_NAME}"
}

main "$@"
