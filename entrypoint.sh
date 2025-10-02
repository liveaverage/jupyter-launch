#!/bin/bash
set -e

echo "--- Pyrrhus JupyterLab Entrypoint ---"
echo "Running as UID: $(id -u), GID: $(id -g), Groups: $(id -G)"

# STRATEGY: Stage resources to BOTH locations, then use whichever works
# This ensures notebooks/repos are available regardless of permission issues
PRIMARY_DIR="/home/jovyan/work"
FALLBACK_DIR="/tmp/work"
WORK_ROOT=""

# Ensure both directories exist
mkdir -p "${FALLBACK_DIR}" 2>/dev/null || true
mkdir -p "${PRIMARY_DIR}" 2>/dev/null || true

echo "Staging directories: PRIMARY=${PRIMARY_DIR}, FALLBACK=${FALLBACK_DIR}"

# Clone repo if specified - clone to BOTH locations
if [ -n "${GITHUB_REPO}" ]; then
    echo "Cloning repository to both staging locations: ${GITHUB_REPO}"
    
    # Try PRIMARY first
    if cd "${PRIMARY_DIR}" 2>/dev/null && [ -w "${PRIMARY_DIR}" ]; then
        if [ ! -d "${PRIMARY_DIR}/repo/.git" ]; then
            echo "Cloning to PRIMARY: ${PRIMARY_DIR}/repo"
            git clone "${GITHUB_REPO}" "${PRIMARY_DIR}/repo" 2>/dev/null || echo "Clone to PRIMARY failed"
        fi
    fi
    
    # Always clone to FALLBACK too
    if [ ! -d "${FALLBACK_DIR}/repo/.git" ]; then
        echo "Cloning to FALLBACK: ${FALLBACK_DIR}/repo"
        git clone "${GITHUB_REPO}" "${FALLBACK_DIR}/repo" 2>/dev/null || echo "Clone to FALLBACK failed"
    fi
    
    echo "Repository cloned to available locations"
fi

# Download notebook from URL if specified - copy to BOTH locations
# Pattern: initContainer (K8s) downloads to PRIMARY, we ensure it's in FALLBACK too
if [ -n "${NOTEBOOK_URL}" ] && [ -n "${AUTO_NOTEBOOK}" ]; then
    echo "Staging notebook from ${NOTEBOOK_URL}"
    
    # Extract just the filename
    NOTEBOOK_FILENAME=$(basename "${AUTO_NOTEBOOK}")
    
    # Check if already exists in PRIMARY (from initContainer)
    if [ -f "${PRIMARY_DIR}/${NOTEBOOK_FILENAME}" ]; then
        echo "Notebook exists in PRIMARY (from initContainer), copying to FALLBACK"
        cp "${PRIMARY_DIR}/${NOTEBOOK_FILENAME}" "${FALLBACK_DIR}/${NOTEBOOK_FILENAME}" 2>/dev/null || true
    else
        # Download to both locations
        echo "Downloading notebook to both locations"
        
        if command -v curl &> /dev/null; then
            curl -fsSL -o "${PRIMARY_DIR}/${NOTEBOOK_FILENAME}" "${NOTEBOOK_URL}" 2>/dev/null || true
            curl -fsSL -o "${FALLBACK_DIR}/${NOTEBOOK_FILENAME}" "${NOTEBOOK_URL}" 2>/dev/null || true
        elif command -v wget &> /dev/null; then
            wget -q -O "${PRIMARY_DIR}/${NOTEBOOK_FILENAME}" "${NOTEBOOK_URL}" 2>/dev/null || true
            wget -q -O "${FALLBACK_DIR}/${NOTEBOOK_FILENAME}" "${NOTEBOOK_URL}" 2>/dev/null || true
        fi
    fi
    
    echo "Notebook staged to available locations"
fi

# NOW determine which directory to actually use for WORK_ROOT
# Try PRIMARY first, fall back to FALLBACK
if cd "${PRIMARY_DIR}" 2>/dev/null && [ -w "${PRIMARY_DIR}" ]; then
    WORK_ROOT="${PRIMARY_DIR}"
    echo "Using PRIMARY work directory: ${WORK_ROOT}"
else
    WORK_ROOT="${FALLBACK_DIR}"
    cd "${WORK_ROOT}"
    echo "Using FALLBACK work directory: ${WORK_ROOT}"
fi

echo "Final working directory: $(pwd)"
ls -la "${WORK_ROOT}" 2>/dev/null || echo "Cannot list work directory"

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

# Determine base path for repo/notebooks (relative to WORK_ROOT)
BASE_PATH="${WORK_ROOT}"
[ -n "${GITHUB_REPO}" ] && BASE_PATH="${WORK_ROOT}/repo"

echo "Searching for notebook in: ${BASE_PATH}"

if [ -n "${AUTO_NOTEBOOK}" ]; then
    echo "AUTO_NOTEBOOK is set to: ${AUTO_NOTEBOOK}"
    
    # Extract just filename if it's a path
    NOTEBOOK_FILENAME=$(basename "${AUTO_NOTEBOOK}")
    
    # Look in WORK_ROOT for the file
    if [ -f "${WORK_ROOT}/${NOTEBOOK_FILENAME}" ]; then
        TARGET_NOTEBOOK_PATH="${WORK_ROOT}/${NOTEBOOK_FILENAME}"
        echo "SUCCESS: Found notebook at ${TARGET_NOTEBOOK_PATH}"
    elif [ -f "${WORK_ROOT}/repo/${NOTEBOOK_FILENAME}" ]; then
        TARGET_NOTEBOOK_PATH="${WORK_ROOT}/repo/${NOTEBOOK_FILENAME}"
        echo "SUCCESS: Found notebook in repo at ${TARGET_NOTEBOOK_PATH}"
    else
        echo "WARNING: Notebook ${NOTEBOOK_FILENAME} not found in ${WORK_ROOT}"
    fi
elif [ -n "${AUTO_NOTEBOOK_GLOB}" ]; then
    echo "AUTO_NOTEBOOK_GLOB is set to: ${AUTO_NOTEBOOK_GLOB}"
    # Find first match by filename under BASE_PATH
    TARGET_NOTEBOOK_PATH=$(find "${BASE_PATH}" -type f -name "${AUTO_NOTEBOOK_GLOB}" 2>/dev/null | head -n 1 || true)
    [ -n "${TARGET_NOTEBOOK_PATH}" ] && echo "SUCCESS: Found notebook at ${TARGET_NOTEBOOK_PATH}"
fi

# Set default URL based on what we found
if [ -n "${TARGET_NOTEBOOK_PATH}" ] && [ -f "${TARGET_NOTEBOOK_PATH}" ]; then
    # Compute path relative to WORK_ROOT for default_url
    REL_PATH="${TARGET_NOTEBOOK_PATH#${WORK_ROOT}/}"
    DEFAULT_URL="/lab/tree/${REL_PATH}?reset"
    echo "Will open notebook: ${REL_PATH}"
elif [ -d "${WORK_ROOT}/repo" ]; then
    DEFAULT_URL="/lab/tree/repo"
    echo "Will open repo directory"
else
    echo "Will open default lab view"
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
fi