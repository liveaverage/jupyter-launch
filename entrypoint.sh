#!/bin/bash
set -e

# Only clone repo if specified - minimal work at startup
if [ -n "${GITHUB_REPO}" ]; then
    git clone "${GITHUB_REPO}" repo 2>/dev/null || echo "Repo already exists"
    cd repo
    [ -f setup.sh ] && chmod +x setup.sh && ./setup.sh
fi

# Build args
ARGS="--ServerApp.ip=0.0.0.0"
[ -z "${JUPYTER_TOKEN}" ] && ARGS="${ARGS} --ServerApp.token=''"

# Auto-open notebook if specified - simple path construction
if [ -n "${AUTO_NOTEBOOK}" ]; then
    if [ -n "${GITHUB_REPO}" ]; then
        # We're in /home/jovyan/work, repo is in ./repo
        ARGS="${ARGS} --ServerApp.default_url=/lab/tree/repo/${AUTO_NOTEBOOK}"
    else
        ARGS="${ARGS} --ServerApp.default_url=/lab/tree/${AUTO_NOTEBOOK}"
    fi
fi

# Start JupyterLab immediately
exec start-notebook.sh $ARGS