#!/bin/bash
# Apply NVIDIA branding - runs as root during Docker build
set -e

echo "Applying NVIDIA branding..."

# Paths
LAB_DIR="/opt/conda/share/jupyter/lab"
STATIC_DIR="${LAB_DIR}/static"
ASSETS_DIR="/opt/nvidia-assets"

# 1. Ensure static files are in place
echo "Copying static assets..."
cp -f ${ASSETS_DIR}/nvidia-logo.svg ${STATIC_DIR}/nvidia-logo.svg
cp -f ${ASSETS_DIR}/favicon.ico ${STATIC_DIR}/favicon.ico

# 2. Fix favicon in index.html
echo "Updating favicon..."
if [ -f "${STATIC_DIR}/index.html" ]; then
    sed -i 's|href="[^"]*favicon[^"]*"|href="/static/favicon.ico"|g' ${STATIC_DIR}/index.html
    if ! grep -q 'rel="icon"' ${STATIC_DIR}/index.html; then
        sed -i 's|</head>|<link rel="icon" type="image/x-icon" href="/static/favicon.ico"></head>|' ${STATIC_DIR}/index.html
    fi
fi

# 3. Inject NVIDIA branding CSS directly (no temp file needed)
echo "Injecting NVIDIA styles..."
if [ -f "${STATIC_DIR}/index.html" ]; then
    # Remove any existing NVIDIA branding
    sed -i '/<style>.*NVIDIA Branding.*<\/style>/d' ${STATIC_DIR}/index.html
    
    # Inject new styles directly using sed
    sed -i 's|</head>|<style>\
/* NVIDIA Branding */\
:root {\
  --jp-brand-color0: #76B900 !important;\
  --jp-brand-color1: #76B900 !important;\
  --jp-brand-color2: #5A8C00 !important;\
  --jp-brand-color3: #4E7A00 !important;\
}\
.jp-LabLogo svg, #jp-MainLogo svg, .jp-JupyterLogo svg {\
  display: none !important;\
}\
.jp-LabLogo {\
  background-image: url("/static/nvidia-logo.svg");\
  background-size: 50px auto;\
  background-repeat: no-repeat;\
  background-position: center;\
  width: 60px;\
  height: 40px;\
  margin: 0 8px;\
}\
.jp-mod-selected, .jp-DirListing-item.jp-mod-selected {\
  background-color: rgba(118, 185, 0, 0.15) !important;\
}\
.lm-TabBar-tab.lm-mod-current {\
  border-top: 3px solid #76B900 !important;\
}\
.jp-Button.jp-mod-accept {\
  background: #76B900 !important;\
}\
.jp-Button.jp-mod-accept:hover {\
  background: #5A8C00 !important;\
}\
</style></head>|' ${STATIC_DIR}/index.html
fi

echo "NVIDIA branding applied successfully!"