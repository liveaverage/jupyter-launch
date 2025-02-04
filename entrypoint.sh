#!/bin/bash
set -e

# Clone GitHub repository if specified.
if [ -n "${GITHUB_REPO}" ]; then
    echo "Cloning repository: ${GITHUB_REPO}"
    
    # Define the target directory for the clone.
    TARGET_DIR="/home/jovyan/work/repo"
    
    # Ensure the work directory exists.
    mkdir -p /home/jovyan/work
    cd /home/jovyan/work
    
    # Clone the repository into 'repo'.
    git clone "${GITHUB_REPO}" repo

    # If a setup.sh script is present, run it.
    if [ -f "${TARGET_DIR}/setup.sh" ]; then
        echo "Executing setup.sh from the repository..."
        chmod +x "${TARGET_DIR}/setup.sh"
        (cd "${TARGET_DIR}" && ./setup.sh)
    fi

    # Change directory so JupyterLab starts in the repo context.
    cd "${TARGET_DIR}"
fi

# Build extra arguments for start-notebook.sh.
EXTRA_ARGS="--NotebookApp.ip=0.0.0.0"

# If JUPYTER_TOKEN is empty, disable token authentication.
if [ -z "${JUPYTER_TOKEN}" ]; then
    EXTRA_ARGS="${EXTRA_ARGS} --NotebookApp.token=''"
fi

# Execute the notebook server with the extra arguments.
exec start-notebook.sh $EXTRA_ARGS
