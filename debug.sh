#!/bin/bash
# Debug script to test in running container

echo "=== Testing NVIDIA JupyterLab Setup ==="
echo

echo "1. Checking static files:"
ls -la /opt/conda/share/jupyter/lab/static/ | grep -E "nvidia|favicon" || echo "Files not found!"
echo

echo "2. Checking if CSS was injected:"
grep "NVIDIA Branding" /opt/conda/share/jupyter/lab/static/index.html | head -1 || echo "CSS not injected!"
echo

echo "3. Checking notebook path with AUTO_NOTEBOOK=$AUTO_NOTEBOOK:"
if [ -n "${AUTO_NOTEBOOK}" ]; then
    if [ -n "${GITHUB_REPO}" ]; then
        EXPECTED_PATH="/home/jovyan/work/repo/${AUTO_NOTEBOOK}"
        echo "   Expected path: ${EXPECTED_PATH}"
        if [ -f "${EXPECTED_PATH}" ]; then
            echo "   ✓ Notebook exists!"
        else
            echo "   ✗ Notebook NOT found!"
            echo "   Contents of /home/jovyan/work/repo:"
            ls -la /home/jovyan/work/repo/ 2>/dev/null | head -10
        fi
    fi
fi
echo

echo "4. Testing logo URL resolution:"
echo "   Logo should be at: {{base_url}}static/nvidia-logo.svg"
echo "   When base_url is /lab/, full path is: /lab/static/nvidia-logo.svg"
echo

echo "5. Starting JupyterLab with debug output..."
echo "   Args would be: --ServerApp.ip=0.0.0.0 --ServerApp.token='' --ServerApp.default_url=/lab/tree/repo/${AUTO_NOTEBOOK}"
