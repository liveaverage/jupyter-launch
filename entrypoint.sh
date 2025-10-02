#!/bin/bash
set -e

echo "--- Pyrrhus JupyterLab Entrypoint ---"
echo "Running as UID: $(id -u), GID: $(id -g), Groups: $(id -G)"

# Determine writable work root
# Strategy: Try each location and use the first that works
# Priority 1: /home/jovyan/work (K8s volume mount or build-time created)
# Priority 2: /tmp/work (always writable fallback)

WORK_ROOT=""

# Try /home/jovyan/work first - don't check parent, just try to use it
if cd /home/jovyan/work 2>/dev/null; then
    WORK_ROOT="/home/jovyan/work"
    echo "Using work directory: ${WORK_ROOT}"
    # Test if writable
    if ! touch "${WORK_ROOT}/.write_test" 2>/dev/null; then
        echo "WARNING: ${WORK_ROOT} not writable, falling back"
        WORK_ROOT=""
    else
        rm -f "${WORK_ROOT}/.write_test" 2>/dev/null
    fi
fi

# Fall back to /tmp/work if needed
if [ -z "$WORK_ROOT" ]; then
    WORK_ROOT="/tmp/work"
    mkdir -p "${WORK_ROOT}"
    cd "${WORK_ROOT}"
    echo "Using fallback work directory: ${WORK_ROOT}"
fi

echo "Working directory: $(pwd)"
echo "WORK_ROOT: ${WORK_ROOT}"

# Clone repo if specified
if [ -n "${GITHUB_REPO}" ]; then
    echo "Target repository: ${GITHUB_REPO} -> ${WORK_ROOT}/repo"
    if [ -d repo/.git ]; then
        echo "Git repository already exists in ${WORK_ROOT}/repo."
    else
        echo "Cloning repository: ${GITHUB_REPO} into ${WORK_ROOT}/repo"
        if ! git clone "${GITHUB_REPO}" repo; then
            echo "ERROR: failed to clone ${GITHUB_REPO} into ${WORK_ROOT}/repo" >&2
        fi
    fi
    if [ -f repo/setup.sh ]; then
        (cd repo && chmod +x setup.sh && ./setup.sh)
    fi
fi

# Download notebook from URL if specified and not already present
# Pattern: initContainer (K8s) handles download first, this is fallback for standalone Docker
if [ -n "${NOTEBOOK_URL}" ] && [ -n "${AUTO_NOTEBOOK}" ]; then
    # Determine target path
    if [[ "${AUTO_NOTEBOOK}" = /* ]]; then
        TARGET_PATH="${AUTO_NOTEBOOK}"
    else
        TARGET_PATH="${WORK_ROOT}/${AUTO_NOTEBOOK}"
    fi
    
    # Only download if file doesn't already exist (initContainer may have downloaded it)
    if [ ! -f "${TARGET_PATH}" ]; then
        echo "Downloading notebook from URL: ${NOTEBOOK_URL} -> ${TARGET_PATH}"
        DOWNLOAD_SUCCESS=false
        
        if command -v curl &> /dev/null; then
            if curl -fsSL -o "${TARGET_PATH}" "${NOTEBOOK_URL}"; then
                echo "Successfully downloaded notebook to ${TARGET_PATH}"
                DOWNLOAD_SUCCESS=true
            fi
        elif command -v wget &> /dev/null; then
            if wget -q -O "${TARGET_PATH}" "${NOTEBOOK_URL}"; then
                echo "Successfully downloaded notebook to ${TARGET_PATH}"
                DOWNLOAD_SUCCESS=true
            fi
        fi
        
        if [ "$DOWNLOAD_SUCCESS" = false ]; then
            echo "ERROR: Failed to download notebook from ${NOTEBOOK_URL}" >&2
            echo "Neither curl nor wget succeeded or are available" >&2
        fi
    else
        echo "Notebook already exists at ${TARGET_PATH} (likely from initContainer)"
    fi
fi

# Build args
ARGS="--ServerApp.ip=0.0.0.0 --ServerApp.root_dir=${WORK_ROOT}"
if [ -z "${JUPYTER_TOKEN}" ]; then
    ARGS="${ARGS} --IdentityProvider.token=''"
    echo "JUPYTER_TOKEN is unset. Disabling token authentication."
else
    echo "JUPYTER_TOKEN is set."
fi

# Auto-open notebook and set default URL
TARGET_NOTEBOOK_PATH=""
DEFAULT_URL="/lab"

# Determine base path for repo/notebooks
BASE_PATH="${WORK_ROOT}"
[ -n "${GITHUB_REPO}" ] && BASE_PATH="${WORK_ROOT}/repo"

echo "Searching for notebook in base path: ${BASE_PATH}"
if [ -n "${AUTO_NOTEBOOK}" ]; then
    echo "AUTO_NOTEBOOK is set to: ${AUTO_NOTEBOOK}"
    if [[ "${AUTO_NOTEBOOK}" = /* ]]; then
        CANDIDATE_PATH="${AUTO_NOTEBOOK}"
    else
        CANDIDATE_PATH="${BASE_PATH}/${AUTO_NOTEBOOK}"
    fi
elif [ -n "${AUTO_NOTEBOOK_GLOB}" ]; then
    echo "AUTO_NOTEBOOK_GLOB is set to: ${AUTO_NOTEBOOK_GLOB}"
    # Find first match by filename under BASE_PATH
    CANDIDATE_PATH=$(find "${BASE_PATH}" -type f -name "${AUTO_NOTEBOOK_GLOB}" 2>/dev/null | head -n 1 || true)
fi

if [ -n "${CANDIDATE_PATH}" ] && [ -f "${CANDIDATE_PATH}" ]; then
    TARGET_NOTEBOOK_PATH="${CANDIDATE_PATH}"
    # Compute path relative to WORK_ROOT for default_url
    REL_PATH="${TARGET_NOTEBOOK_PATH#${WORK_ROOT}/}"
    echo "SUCCESS: Found notebook to open at ${TARGET_NOTEBOOK_PATH}"
    DEFAULT_URL="/lab/tree/${REL_PATH}?reset"
else
    # Fall back to opening the repo tree if present
    if [ -d "${WORK_ROOT}/repo" ]; then
        DEFAULT_URL="/lab/tree/repo"
        echo "INFO: No specific notebook found to open, defaulting to repo root."
    fi
    if [ -n "${CANDIDATE_PATH}" ]; then
        echo "WARNING: Notebook specified by AUTO_NOTEBOOK or AUTO_NOTEBOOK_GLOB not found at expected path: ${CANDIDATE_PATH}"
    fi
fi

# Always pass a default URL for predictable startup
ARGS="${ARGS} --LabServerApp.default_url=${DEFAULT_URL}"

# Debug output
echo "-------------------------------------"
echo "Final JupyterLab command:"
echo "exec start-notebook.sh ${ARGS}"
echo "Working directory: $(pwd)"
echo "-------------------------------------"

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