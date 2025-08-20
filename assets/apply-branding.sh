#!/bin/bash
# Apply NVIDIA branding after JupyterLab is built
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

# 2. Find and replace ALL favicon references in index.html
echo "Updating favicon references..."
if [ -f "${STATIC_DIR}/index.html" ]; then
    # Replace any existing favicon references
    sed -i 's|href="[^"]*favicon[^"]*"|href="/static/favicon.ico"|g' ${STATIC_DIR}/index.html
    
    # If no favicon link exists, add one
    if ! grep -q 'rel="icon"' ${STATIC_DIR}/index.html; then
        sed -i 's|</head>|<link rel="icon" type="image/x-icon" href="/static/favicon.ico"></head>|' ${STATIC_DIR}/index.html
    fi
fi

# 3. Inject comprehensive CSS for branding
echo "Injecting NVIDIA styles..."
STYLE_INJECT='<style>
/* NVIDIA Branding */
:root {
  --jp-brand-color0: #76B900 !important;
  --jp-brand-color1: #76B900 !important;
  --jp-brand-color2: #5A8C00 !important;
  --jp-brand-color3: #4E7A00 !important;
}
/* Hide all default logos */
.jp-LabLogo svg, #jp-MainLogo svg, .jp-JupyterLogo svg {
  display: none !important;
}
/* Show NVIDIA logo */
.jp-LabLogo {
  background-image: url("/static/nvidia-logo.svg");
  background-size: 50px auto;
  background-repeat: no-repeat;
  background-position: center;
  width: 60px;
  height: 40px;
  margin: 0 8px;
}
/* Selected items */
.jp-mod-selected, .jp-DirListing-item.jp-mod-selected {
  background-color: rgba(118, 185, 0, 0.15) !important;
}
/* Tabs */
.lm-TabBar-tab.lm-mod-current {
  border-top: 3px solid #76B900 !important;
}
/* Buttons */
.jp-Button.jp-mod-accept {
  background: #76B900 !important;
}
.jp-Button.jp-mod-accept:hover {
  background: #5A8C00 !important;
}
</style>'

# Remove any existing style injection and add new one
if [ -f "${STATIC_DIR}/index.html" ]; then
    # Remove old style blocks
    sed -i '/<style>.*NVIDIA Branding.*<\/style>/d' ${STATIC_DIR}/index.html
    # Add new style block
    echo "$STYLE_INJECT" > /tmp/style-inject.txt
    sed -i '/<\/head>/r /tmp/style-inject.txt' ${STATIC_DIR}/index.html
fi

echo "NVIDIA branding applied successfully!"
