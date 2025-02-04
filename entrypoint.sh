#!/bin/bash
set -e

# Check if a GitHub repository URL was provided.
if [ -n "${GITHUB_REPO}" ]; then
    echo "Cloning repository: ${GITHUB_REPO}"
    
    # Define the target directory for the repository clone.
    TARGET_DIR="/home/jovyan/work/repo"
    
    # Ensure the work directory exists.
    mkdir -p /home/jovyan/work
    cd /home/jovyan/work
    
    # Clone the repository into the 'repo' directory.
    git clone "${GITHUB_REPO}" repo

    # If the repository includes a setup.sh script, execute it.
    if [ -f "${TARGET_DIR}/setup.sh" ]; then
        echo "Executing setup.sh from the repository..."
        chmod +x "${TARGET_DIR}/setup.sh"
        (cd "${TARGET_DIR}" && ./setup.sh)
    fi

    # Change directory to the cloned repository so that JupyterLab starts in that context.
    cd "${TARGET_DIR}"
fi

# Execute the CMD passed to the container.
exec "$@"
