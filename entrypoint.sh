#!/bin/bash
set -e

# Choose a writable work root (OpenShift-safe)
WORK_ROOT="/home/jovyan/work"
if [ ! -w "/home/jovyan" ] || [ ! -w "${WORK_ROOT}" ]; then
    WORK_ROOT="/tmp/work"
fi
mkdir -p "${WORK_ROOT}" || true
cd "${WORK_ROOT}"

# Clone repo if specified
if [ -n "${GITHUB_REPO}" ]; then
    echo "Cloning repository: ${GITHUB_REPO} into ${WORK_ROOT}/repo"
    if [ -d repo/.git ]; then
        echo "Repo already exists"
    else
        if ! git clone "${GITHUB_REPO}" repo; then
            echo "ERROR: failed to clone ${GITHUB_REPO} into ${WORK_ROOT}/repo" >&2
        fi
    fi
    if [ -f repo/setup.sh ]; then
        (cd repo && chmod +x setup.sh && ./setup.sh)
    fi
fi

# Build args
ARGS="--ServerApp.ip=0.0.0.0 --ServerApp.root_dir=${WORK_ROOT}"
[ -z "${JUPYTER_TOKEN}" ] && ARGS="${ARGS} --IdentityProvider.token=''"

# Auto-open notebook and set default URL
TARGET_NOTEBOOK_PATH=""
DEFAULT_URL="/lab"

# Determine base path for repo/notebooks
BASE_PATH="${WORK_ROOT}"
[ -n "${GITHUB_REPO}" ] && BASE_PATH="${WORK_ROOT}/repo"

if [ -n "${AUTO_NOTEBOOK}" ]; then
    if [[ "${AUTO_NOTEBOOK}" = /* ]]; then
        CANDIDATE_PATH="${AUTO_NOTEBOOK}"
    else
        CANDIDATE_PATH="${BASE_PATH}/${AUTO_NOTEBOOK}"
    fi
elif [ -n "${AUTO_NOTEBOOK_GLOB}" ]; then
    # Find first match by filename under BASE_PATH
    CANDIDATE_PATH=$(find "${BASE_PATH}" -type f -name "${AUTO_NOTEBOOK_GLOB}" 2>/dev/null | head -n 1 || true)
fi

if [ -n "${CANDIDATE_PATH}" ] && [ -f "${CANDIDATE_PATH}" ]; then
    TARGET_NOTEBOOK_PATH="${CANDIDATE_PATH}"
    # Compute path relative to WORK_ROOT for default_url
    REL_PATH="${TARGET_NOTEBOOK_PATH#${WORK_ROOT}/}"
    echo "Requesting notebook open on launch: ${REL_PATH}"
    DEFAULT_URL="/lab/tree/${REL_PATH}?reset"
else
    # Fall back to opening the repo tree if present
    if [ -d "${WORK_ROOT}/repo" ]; then
        DEFAULT_URL="/lab/tree/repo"
    fi
    if [ -n "${CANDIDATE_PATH}" ] && [ ! -f "${CANDIDATE_PATH}" ]; then
        echo "Warning: Notebook not found at ${CANDIDATE_PATH}"
    fi
fi

# Always pass a default URL for predictable startup
ARGS="${ARGS} --LabServerApp.default_url=${DEFAULT_URL}"

# Debug output
echo "Starting JupyterLab with args: $ARGS"
echo "Working directory: $(pwd)"

# Ensure a writable runtime directory (fixes OpenShift arbitrary UID perms)
if [ -z "${JUPYTER_RUNTIME_DIR}" ]; then
    HOME_DIR=${HOME:-/home/jovyan}
    if [ -w "${HOME_DIR}" ]; then
        export JUPYTER_RUNTIME_DIR="${HOME_DIR}/.local/share/jupyter/runtime"
    else
        export JUPYTER_RUNTIME_DIR="/tmp/jupyter/runtime"
    fi
fi
mkdir -p "${JUPYTER_RUNTIME_DIR}" || {
    echo "ERROR: Cannot create Jupyter runtime dir at ${JUPYTER_RUNTIME_DIR}" >&2
    exit 1
}
chmod 700 "${JUPYTER_RUNTIME_DIR}" 2>/dev/null || true
export XDG_RUNTIME_DIR="${JUPYTER_RUNTIME_DIR}"

# If HOME is not writable, redirect Jupyter config/data dirs to /tmp
HOME_DIR=${HOME:-/home/jovyan}
if [ ! -w "${HOME_DIR}" ]; then
    export JUPYTER_CONFIG_DIR="/tmp/jupyter/config"
    export JUPYTER_DATA_DIR="/tmp/jupyter/data"
    export IPYTHONDIR="/tmp/ipython"
    mkdir -p "${JUPYTER_CONFIG_DIR}" "${JUPYTER_DATA_DIR}" "${IPYTHONDIR}" || true
    chmod 700 "${JUPYTER_CONFIG_DIR}" "${JUPYTER_DATA_DIR}" "${IPYTHONDIR}" 2>/dev/null || true
fi

# Ensure .jupyter directory is writable at runtime
mkdir -p "${HOME_DIR}/.jupyter" || true
chmod -R 777 "${HOME_DIR}/.jupyter" 2>/dev/null || true

export JUPYTERLAB_WORKSPACES_DIR="/tmp/jupyter/lab/workspaces"
mkdir -p "${JUPYTERLAB_WORKSPACES_DIR}" || true
chmod 700 "${JUPYTERLAB_WORKSPACES_DIR}" 2>/dev/null || true

# Avoid permission denied scans of workspace node_modules by LSP
ARGS="${ARGS} --LanguageServerManager.autodetect=False"

# Ensure JupyterLab uses our fresh, writable workspaces directory
ARGS="${ARGS} --LabServerApp.workspaces_dir=${JUPYTERLAB_WORKSPACES_DIR}"

# Do not touch workspaces under /home/jovyan when it may be read-only

# Start JupyterLab
if [ -n "${TARGET_NOTEBOOK_PATH}" ]; then
    exec start-notebook.sh $ARGS "${TARGET_NOTEBOOK_PATH}"
else
    exec start-notebook.sh $ARGS
fi