#!/bin/bash
set -e

# Clone repo if specified
if [ -n "${GITHUB_REPO}" ]; then
    echo "Cloning repository: ${GITHUB_REPO}"
    git clone "${GITHUB_REPO}" repo 2>/dev/null || echo "Repo already exists"
    if [ -f repo/setup.sh ]; then
        cd repo && chmod +x setup.sh && ./setup.sh && cd ..
    fi
fi

# Build args
ARGS="--ServerApp.ip=0.0.0.0"
[ -z "${JUPYTER_TOKEN}" ] && ARGS="${ARGS} --ServerApp.token=''"

# Auto-open notebook
if [ -n "${AUTO_NOTEBOOK}" ] && [ -n "${GITHUB_REPO}" ]; then
    # Check if notebook exists
    if [ -f "repo/${AUTO_NOTEBOOK}" ]; then
        echo "Opening notebook: repo/${AUTO_NOTEBOOK}"
        # Use the correct format for default URL
        ARGS="${ARGS} --LabApp.default_url=/lab/tree/repo/${AUTO_NOTEBOOK}"
    else
        echo "Warning: Notebook ${AUTO_NOTEBOOK} not found in repo"
        ls -la repo/ | head -10
    fi
fi

# Debug output
echo "Starting JupyterLab with args: $ARGS"
echo "Working directory: $(pwd)"

# Start JupyterLab
exec start-notebook.sh $ARGS