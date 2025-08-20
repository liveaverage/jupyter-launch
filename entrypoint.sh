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

# Auto-open notebook: pass the file path as a positional arg to 'jupyter lab'
TARGET_NOTEBOOK_PATH=""
if [ -n "${AUTO_NOTEBOOK}" ]; then
    if [ -n "${GITHUB_REPO}" ]; then
        CANDIDATE_PATH="repo/${AUTO_NOTEBOOK}"
    else
        CANDIDATE_PATH="${AUTO_NOTEBOOK}"
    fi
    if [ -f "${CANDIDATE_PATH}" ]; then
        TARGET_NOTEBOOK_PATH="${CANDIDATE_PATH}"
        echo "Requesting notebook open on launch: ${TARGET_NOTEBOOK_PATH}"
        # Fallback default URL in case positional arg is ignored by a restored workspace
        ARGS="${ARGS} --ServerApp.default_url=/lab/tree/${TARGET_NOTEBOOK_PATH}?reset"
    else
        echo "Warning: Notebook ${CANDIDATE_PATH} not found"
    fi
fi

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