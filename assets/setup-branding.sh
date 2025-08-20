#!/bin/bash
# Post-build script to properly brand JupyterLab with NVIDIA theme

set -e

echo "Setting up NVIDIA branding for JupyterLab..."

# Find the JupyterLab static directory
LAB_STATIC_DIR="/opt/conda/share/jupyter/lab/static"
LAB_STAGING_DIR="/opt/conda/share/jupyter/lab/staging"

# 1. Replace ALL favicon files with the NVIDIA favicon
echo "Replacing favicons..."
find /opt/conda -name "favicon.ico" -type f 2>/dev/null | while read -r favicon; do
    cp /opt/nvidia-assets/favicon.ico "$favicon" 2>/dev/null || true
done

# Also copy to key locations
cp /opt/nvidia-assets/favicon.ico "${LAB_STATIC_DIR}/favicon.ico" 2>/dev/null || true
cp /opt/nvidia-assets/favicon.ico "${LAB_STATIC_DIR}/favicons/favicon.ico" 2>/dev/null || true
mkdir -p "${LAB_STATIC_DIR}/favicons" 2>/dev/null || true
cp /opt/nvidia-assets/favicon.ico "${LAB_STATIC_DIR}/favicons/favicon.ico" 2>/dev/null || true

# 2. Inject comprehensive CSS that actually works
echo "Injecting NVIDIA CSS..."
cat > /tmp/nvidia-inject.css << 'EOF'
<style>
/* NVIDIA Branding */
:root {
  --jp-brand-color0: #76B900 !important;
  --jp-brand-color1: #76B900 !important;
  --jp-brand-color2: #5A8C00 !important;
  --jp-brand-color3: #4E7A00 !important;
}

/* Hide ALL Jupyter logos */
.jp-LabLogo svg,
.jp-JupyterLogo svg,
#jp-MainLogo svg,
.jp-SplashLogo svg {
  display: none !important;
  visibility: hidden !important;
  width: 0 !important;
  height: 0 !important;
}

/* Add NVIDIA text logo */
.jp-LabLogo::after {
  content: "NVIDIA" !important;
  color: #76B900 !important;
  font-weight: bold !important;
  font-size: 18px !important;
  font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Helvetica, Arial, sans-serif !important;
  line-height: 32px !important;
  display: inline-block !important;
  margin-left: 12px !important;
}

/* Selected items */
.jp-mod-selected,
.jp-DirListing-item.jp-mod-selected {
  background-color: rgba(118, 185, 0, 0.15) !important;
}

/* Active tabs */
.jp-DockPanel-tabBar .lm-TabBar-tab.lm-mod-current {
  border-top: 3px solid #76B900 !important;
}

/* Buttons */
.jp-Button.jp-mod-styled.jp-mod-accept {
  background: #76B900 !important;
}

.jp-Button.jp-mod-styled.jp-mod-accept:hover {
  background: #5A8C00 !important;
}

/* Notebook cells */
.jp-Notebook .jp-Cell.jp-mod-active .jp-InputPrompt,
.jp-Notebook .jp-Cell.jp-mod-active .jp-OutputPrompt {
  color: #76B900 !important;
}
</style>
EOF

# Inject into index.html
if [ -f "${LAB_STATIC_DIR}/index.html" ]; then
    # Remove any existing style injection to avoid duplicates
    sed -i '/<style>.*NVIDIA Branding.*<\/style>/d' "${LAB_STATIC_DIR}/index.html" 2>/dev/null || true
    # Inject new styles before </head>
    sed -i "/<\/head>/r /tmp/nvidia-inject.css" "${LAB_STATIC_DIR}/index.html"
fi

# 3. Fix auto-notebook opening by updating the entrypoint
echo "Fixing auto-notebook opening..."
cat > /usr/local/bin/nvidia-entrypoint.sh << 'EOF'
#!/bin/bash
set -e

# Clone GitHub repository if specified
if [ -n "${GITHUB_REPO}" ]; then
    echo "Cloning repository: ${GITHUB_REPO}"
    mkdir -p /home/jovyan/work
    cd /home/jovyan/work
    git clone "${GITHUB_REPO}" repo
    cd repo
    
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
    # Build the correct path
    if [ -n "${GITHUB_REPO}" ]; then
        # We're in /home/jovyan/work/repo
        NOTEBOOK_PATH="${AUTO_NOTEBOOK}"
        # Use LabApp.default_url to open directly
        ARGS="${ARGS} --LabApp.default_url=/lab/tree/${NOTEBOOK_PATH}"
        echo "Will auto-open notebook: ${NOTEBOOK_PATH}"
    fi
fi

# Start JupyterLab
exec start-notebook.sh $ARGS
EOF

chmod +x /usr/local/bin/nvidia-entrypoint.sh

# 4. Create a proper favicon.ico if the SVG one doesn't work
echo "Creating proper favicon..."
# If we have ImageMagick or similar, convert SVG to ICO
if command -v convert &> /dev/null; then
    convert /opt/nvidia-assets/nvidia-logo.svg -resize 32x32 /opt/nvidia-assets/favicon.ico 2>/dev/null || true
fi

echo "NVIDIA branding setup complete!"

