#!/bin/bash
# Test script to verify tour configuration in running container

echo "=== Testing NVIDIA JupyterLab Tour Configuration ==="
echo

echo "1. Checking if default tour extensions are disabled:"
jupyter labextension list | grep -E "jupyterlab-tour:(notebook|default)-tours" | grep -E "enabled|OK" && echo "ERROR: Default tours still enabled!" || echo "✓ Default tours disabled"
echo

echo "2. Checking if user-tours extension is enabled:"
jupyter labextension list | grep "jupyterlab-tour:user-tours" | grep -E "enabled|OK" && echo "✓ User tours enabled" || echo "ERROR: User tours disabled!"
echo

echo "3. Checking tour configuration file:"
TOUR_CONFIG="/home/jovyan/.jupyter/lab/user-settings/jupyterlab-tour/user-tours.jupyterlab-settings"
if [ -f "$TOUR_CONFIG" ]; then
    echo "✓ Tour configuration file exists"
    echo "Tour file contains $(jq -r '.tours | length' "$TOUR_CONFIG" 2>/dev/null || echo "JSON_ERROR") tours"
    echo "Auto-start enabled: $(jq -r '.autoStart' "$TOUR_CONFIG" 2>/dev/null || echo "JSON_ERROR")"
    echo "Start tour ID: $(jq -r '.startTour' "$TOUR_CONFIG" 2>/dev/null || echo "JSON_ERROR")"
else
    echo "✗ Tour configuration file missing at $TOUR_CONFIG"
fi
echo

echo "4. Checking page config for disabled extensions:"
PAGE_CONFIG="/etc/jupyter/labconfig/page_config.json"
if [ -f "$PAGE_CONFIG" ]; then
    echo "✓ Page config exists"
    echo "Disabled extensions:"
    jq -r '.disabledExtensions | keys[]' "$PAGE_CONFIG" 2>/dev/null || echo "JSON_ERROR"
else
    echo "✗ Page config missing at $PAGE_CONFIG"
fi
echo

echo "5. Checking server config for disabled extensions:"
SERVER_CONFIG="/etc/jupyter/jupyter_server_config.py"
if [ -f "$SERVER_CONFIG" ]; then
    echo "✓ Server config exists"
    grep -A 5 "disabledExtensions" "$SERVER_CONFIG" || echo "No disabledExtensions found"
else
    echo "✗ Server config missing"
fi
echo

echo "=== Tour Configuration Test Complete ==="
