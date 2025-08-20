#!/bin/bash
set -e

# Apply branding on first run
if [ ! -f /home/jovyan/.nvidia-branded ]; then
    /opt/nvidia-assets/apply-branding.sh
    touch /home/jovyan/.nvidia-branded
fi

# Clone GitHub repository if specified
if [ -n "${GITHUB_REPO}" ]; then
    echo "Cloning repository: ${GITHUB_REPO}"
    mkdir -p /home/jovyan/work
    cd /home/jovyan/work
    
    # Remove existing repo if present
    rm -rf repo
    git clone "${GITHUB_REPO}" repo
    
    # Change to repo directory
    cd /home/jovyan/work/repo
    
    # Run setup.sh if present
    if [ -f setup.sh ]; then
        echo "Running setup.sh..."
        chmod +x setup.sh
        ./setup.sh
    fi
fi

# Build startup arguments
ARGS="--ServerApp.ip=0.0.0.0"

# Disable token if not set
if [ -z "${JUPYTER_TOKEN}" ]; then
    ARGS="${ARGS} --ServerApp.token=''"
fi

# Auto-open notebook if specified
if [ -n "${AUTO_NOTEBOOK}" ]; then
    echo "Will auto-open notebook: ${AUTO_NOTEBOOK}"
    # The notebook path needs to be relative to /home/jovyan
    if [ -n "${GITHUB_REPO}" ]; then
        # Check if notebook exists
        if [ -f "/home/jovyan/work/repo/${AUTO_NOTEBOOK}" ]; then
            # Open the notebook directly
            ARGS="${ARGS} --ServerApp.default_url=/lab/tree/work/repo/${AUTO_NOTEBOOK}"
        else
            echo "Warning: Notebook ${AUTO_NOTEBOOK} not found in cloned repo"
            # Just open the repo directory
            ARGS="${ARGS} --ServerApp.default_url=/lab/tree/work/repo"
        fi
    else
        ARGS="${ARGS} --ServerApp.default_url=/lab/tree/${AUTO_NOTEBOOK}"
    fi
fi

# Start from home directory
cd /home/jovyan

# Start JupyterLab
echo "Starting JupyterLab with args: $ARGS"
exec start-notebook.sh $ARGS