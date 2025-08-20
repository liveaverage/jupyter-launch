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

# 3. Inject NVIDIA branding CSS with correct base URL
echo "Injecting NVIDIA styles..."
if [ -f "${STATIC_DIR}/index.html" ]; then
    # Remove any existing NVIDIA branding
    sed -i '/<style>.*NVIDIA Branding.*<\/style>/d' ${STATIC_DIR}/index.html
    
    # Inject new styles with proper URL handling
    sed -i 's|</head>|<style>\
/* NVIDIA Branding */\
:root {\
  --jp-brand-color0: #76B900 !important;\
  --jp-brand-color1: #76B900 !important;\
  --jp-brand-color2: #5A8C00 !important;\
  --jp-brand-color3: #4E7A00 !important;\
}\
/* Hide ALL default logos */\
.jp-LabLogo svg,\
#jp-MainLogo svg,\
.jp-JupyterLogo svg,\
.jp-LabLogo img {\
  display: none !important;\
  visibility: hidden !important;\
}\
/* Show NVIDIA logo using base URL */\
.jp-LabLogo {\
  background-image: url("static/nvidia-logo.svg");\
  background-size: contain;\
  background-repeat: no-repeat;\
  background-position: center;\
  width: 60px !important;\
  height: 40px !important;\
  margin: 0 8px;\
  display: block !important;\
}\
/* Ensure logo container is visible */\
#jp-top-panel .jp-LabLogo {\
  visibility: visible !important;\
  opacity: 1 !important;\
}\
/* Selected items */\
.jp-mod-selected,\
.jp-DirListing-item.jp-mod-selected {\
  background-color: rgba(118, 185, 0, 0.15) !important;\
}\
/* Active tabs */\
.lm-TabBar-tab.lm-mod-current {\
  border-top: 3px solid #76B900 !important;\
}\
/* Buttons */\
.jp-Button.jp-mod-accept {\
  background: #76B900 !important;\
}\
.jp-Button.jp-mod-accept:hover {\
  background: #5A8C00 !important;\
}\
</style></head>|' ${STATIC_DIR}/index.html
fi

echo "NVIDIA branding applied successfully!"