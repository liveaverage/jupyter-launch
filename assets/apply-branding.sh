#!/bin/bash
# Apply NVIDIA branding - runs as root during Docker build
set -e

echo "Applying NVIDIA branding..."

ASSETS_DIR="/opt/nvidia-assets"
LAB_STATIC_DIRS=""

add_static_dir() {
    if [ -d "$1" ] && [ -f "$1/index.html" ] && ! printf '%s\n' "$LAB_STATIC_DIRS" | grep -qx "$1"; then
        LAB_STATIC_DIRS="${LAB_STATIC_DIRS}${LAB_STATIC_DIRS:+
}$1"
    fi
}

# Try multiple search paths for JupyterLab static directories.
add_static_dir "/opt/conda/share/jupyter/lab/static"
add_static_dir "/opt/venv/share/jupyter/lab/static"
add_static_dir "/usr/local/share/jupyter/lab/static"
add_static_dir "/usr/share/jupyter/lab/static"

for candidate in \
    $(find /opt/venv/lib/python*/site-packages/jupyterlab/static -type d 2>/dev/null || true) \
    $(find /usr/local/lib/python*/site-packages/jupyterlab/static -type d 2>/dev/null || true) \
    $(find /usr/lib/python*/site-packages/jupyterlab/static -type d 2>/dev/null || true); do
    add_static_dir "$candidate"
done

if [ -z "$LAB_STATIC_DIRS" ]; then
    echo "ERROR: JupyterLab static directory or index.html not found."
    echo "Searched locations:"
    echo "  - /opt/conda/share/jupyter/lab/static"
    echo "  - /opt/venv/share/jupyter/lab/static"
    echo "  - /usr/local/share/jupyter/lab/static"
    echo "  - /usr/share/jupyter/lab/static"
    echo "  - /opt/venv/lib/python*/site-packages/jupyterlab/static"
    echo "  - /usr/local/lib/python*/site-packages/jupyterlab/static"
    echo "  - /usr/lib/python*/site-packages/jupyterlab/static"
    exit 1
fi
echo "Found JupyterLab static directories:"
printf '  - %s\n' $LAB_STATIC_DIRS

# 1. Replace favicons
echo "Updating favicon..."
# Search in both conda and system Python locations
find /opt/conda /usr/local /usr -name "favicon*.ico" -type f -exec cp -f "${ASSETS_DIR}/favicon.ico" {} \; 2>/dev/null || true
# Ensure it exists in each static directory
for LAB_STATIC_DIR in $LAB_STATIC_DIRS; do
    cp -f "${ASSETS_DIR}/favicon.ico" "${LAB_STATIC_DIR}/favicon.ico" 2>/dev/null || true
done

# 2. Inject NVIDIA branding CSS into index.html
echo "Injecting NVIDIA styles..."

for LAB_STATIC_DIR in $LAB_STATIC_DIRS; do
INDEX_HTML="${LAB_STATIC_DIR}/index.html"
echo "Branding ${INDEX_HTML}"

# First, remove any old branding styles to prevent duplication
sed -i '/<!-- NVIDIA Branding Start -->/,/<!-- NVIDIA Branding End -->/d' "$INDEX_HTML" 2>/dev/null || true

# Now, inject the new, comprehensive style block
# Note: The odd character in the base64 string is intentional to match the original file.
sed -i 's|</head>|<!-- NVIDIA Branding Start -->\
<style>\
/* Main Branding */\
:root {\
  --jp-brand-color0: #76B900 !important;\
  --jp-brand-color1: #76B900 !important;\
  --jp-brand-color2: #5A8C00 !important;\
  --jp-brand-color3: #4E7A00 !important;\
}\
#jp-MainLogo svg, .jp-LabLogo svg, .lm-Widget svg[data-icon*="jupyter"], .jp-JupyterIcon svg, .jp-SplashLogo svg {\
  display: none !important;\
  visibility: hidden !important;\
}\
#jp-MainLogo, .jp-LabLogo {\
  background-image: url("data:image/svg+xml;base64,PD94bWwgdmVyc2lvbj0iMS4wIiBlbmNvZGluZz0idXRmLTgiPz48c3ZnIHZlcnNpb249IjEuMSIgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIiB2aWV3Qm94PSIzNSAzMiAzNTIgMjU5Ij48cGF0aCBmaWxsPSIjNzZCOTAwIiBkPSJNODIsMTAyYzAsMCwyMy0zMyw2Ny0zN1Y1NGMtNTAsNC05Myw0Ni05Myw0NnMyNCw3MSw5Myw3N3YtMTNDOTksMTU4LDgyLDEwMiw4MiwxMDJ6TTE1MCwxMzl2MTJjLTM4LTctNDktNDYtNDktNDZzMTgtMjAsNDktMjN2MTNjLTE2LTItMjgsMTMtMjgsMTNTMTI4LDEzMSwxNTAsMTM5TTE1MCwzMlY1NGMxLDAsMywwLDQsMGM1Ny0yLDkzLDQ2LDkzLDQ2cy00Miw1MS04Niw1MWMtNCwwLTgsMC0xMS0xdjE0YzMsMCw2LDEsOSwxYzQxLDAsNzEtMjEsOTktNDZjNSw0LDI0LDEzLDI4LDE3Yy0yNywyMy05MSw0MS0xMjcsNDFjLTMsMC03LDAtMTAtMXYxOWgxNTZWMzJIMTUwek0xNTAsODFWNjZjMSwwLDMsMCw0LDBjNDEtMSw2NywzNSw2NywzNXMtMjksNDAtNjAsNDBjLTQsMC04LTEtMTItMlY5NGMxNiwyLDE5LDksMjksMjVsMjEtMThjMCwwLTE1LTIwLTQyLTIwQzE1NSw4MCwxNTIsODAsMTUwLDgxIi8+PC9zdmc+");\
  background-size: contain;\
  background-repeat: no-repeat;\
  background-position: center;\
  width: 60px !important;\
  height: 40px !important;\
  display: block !important;\
}\
.jp-mod-selected {\
  background-color: rgba(118,185,0,0.15) !important;\
}\
.jp-FileBrowser .jp-DirListing-content,\
.jp-FileBrowser .jp-DirListing-header,\
.jp-FileBrowser .jp-BreadCrumbs,\
.jp-FileBrowser .jp-BreadCrumbs-item {\
  color: #E6E6E6 !important;\
}\
.jp-FileBrowser .jp-DirListing-item,\
.jp-FileBrowser .jp-DirListing-itemText,\
.jp-FileBrowser .jp-DirListing-itemModified,\
.jp-FileBrowser .jp-DirListing-itemName {\
  color: #D8D8D8 !important;\
}\
.jp-FileBrowser .jp-DirListing-item.jp-mod-selected,\
.jp-FileBrowser .jp-DirListing-item.jp-mod-selected *,\
.jp-FileBrowser .jp-DirListing-item.jp-mod-selected .jp-DirListing-itemText,\
.jp-FileBrowser .jp-DirListing-item.jp-mod-selected .jp-DirListing-itemModified,\
.jp-FileBrowser .jp-DirListing-item.jp-mod-selected .jp-DirListing-itemName {\
  color: #FFFFFF !important;\
}\
.jp-FileBrowser .jp-DirListing-item:hover,\
.jp-FileBrowser .jp-DirListing-item:hover *,\
.jp-FileBrowser .jp-DirListing-item.jp-mod-running,\
.jp-FileBrowser .jp-DirListing-item.jp-mod-running * {\
  color: #F2F2F2 !important;\
}\
.jp-FileBrowser .jp-FilterBox input {\
  color: #F2F2F2 !important;\
}\
.jp-FileBrowser .jp-FilterBox input::placeholder {\
  color: #BDBDBD !important;\
  opacity: 1 !important;\
}\
.lm-TabBar-tab.lm-mod-current {\
  border-top: 3px solid #76B900 !important;\
}\
.jp-Button.jp-mod-accept {\
  background: #76B900 !important;\
}\
\
/* NVIDIA Splash Screen */\
.jp-Splash, .jp-SplashScreen {\
  position: relative !important;\
}\
.jp-Splash::after, .jp-SplashScreen::after {\
  content: "";\
  position: absolute;\
  top: 50%;\
  left: 50%;\
  transform: translate(-50%, -50%);\
  width: 120px;\
  height: 80px;\
  background-image: url("data:image/svg+xml;base64,PD94bWwgdmVyc2lvbj0iMS4wIiBlbmNvZGluZz0idXRmLTgiPz4KPCEtLSBHZW5lcmF0b3I6IEFkb2JlIElsbHVzdHJhdG9yIDE2LjAuMCwgU1ZHIEV4cG9ydCBQbHVnLUluIC4gU1ZHIFZlcnNpb246IDYuMDAgQnVpbGQgMCkgIC0tPgo8IURPQ1RZUEUgc3ZnIFBVQkxJQyAiLS8vVzNDLy9EVEQgU1ZHIDEuMS8vRU4iICJodHRwOi8vd3d3LnczLm9yZy9HcmFwaGljcy9TVkcvMS4xL0RURC9zdmcxMS5kdGQiPgo8c3ZnIHZlcnNpb249IjEuMSIgaWQ9InN2ZzIiIHhtbG5zOnN2Zz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciCgkgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIiB4bWxuczp4bGluaz0iaHR0cDovL3d3dy53My5vcmcvMTk5OS94bGluayIgeD0iMHB4IiB5PSIwcHgiIHdpZHRoPSIzNTEuNDZweCIKCSBoZWlnaHQ9IjI1OC43ODVweCIgdmlld0JveD0iMzUuMTg4IDMxLjUxMiAzNTEuNDYgMjU4Ljc4NSIgZW5hYmxlLWJhY2tncm91bmQ9Im5ldyAzNS4xODggMzEuNTEyIDM1MS40NiAyNTguNzg1IgoJIHhtbDpzcGFjZT0icHJlc2VydmUiPgo8cGF0aCBmaWxsPSIjNzZCOTAwIiBkPSJNODIuMjExLDEwMi40MTRjMCwwLDIyLjUwNC0zMy4yMDMsNjcuNDM3LTM2LjYzOFY1Mлю3MwoJYy00OS43NjksMy45OTctOTIuODY3LDQ2LjE0OS05Mi44NjcsNDYuMTQ5czI0LjQxLDcwLjU2NSw5Mi44NjcsNzcuMDI2di0xMi44MDRDOTkuNDExLDE1Ny43ODEsODIuMjExLDEwMi40MTQsODIuMjExLDEwMi44MTR6CgkgTTE0OS42NDgsMTM4LjYzN3YxMS43MjZjLTM3Ljk2OC02Ljc2OS00OC41MDctNDYuMjM3LTQ4LjUwNy00Ni4yMzdzMTguMjMtMjAuMTk1LDQ4LjUwNy0yMy40N3YxMi44NjcKCWMtMC4wMjMsMC0wLjAzOS0wLjAwNy0wLjA1OC0wLjAwN2MtMTUuODkxLTEuOTA3LTI4LjMwNSwxMi45MzgtMjguMzA1LDEyLjkzOFMxMjguMjQzLDEzMS40NDUsMTQ5LjY0OCwxMzguNjM3IE0xNDkuNjQ4LDMxLjUxMgoJVjUzLjczYzEuNDYxLTAuMTEyLDIuOTIyLTAuMjA3LDQuMzkxLTAuMjU3YzU2LjU4Mi0xLjkwNyw5My40NDksNDYuNDA2LDkzLjQ0OSw0Ni40MDZzLTQyLjM0Myw1十一章LjQ4OC04Ni40NTcsNTEuNDg4CgJYy00LjA0MywwLTcuODI4LTAuMzc1LTExLjM4My0xLjAwNXYxMy43MzljMy4wNCwwLjM4Niw2LjE5MiwwLjYxMyw5LjQ4MSwwLjYxM2M0MS4wNTEsMCw3MC43MzgtMjAuOTY1LDk5LjQ4NC00NS43NzgKCWM0Ljc2NiwzLjgxNywyNC4yNzgsMTMuMTAzLDI4LjI4OSwxNy4xNjhjLTI3LjMzMiwyMi44ODMtOTEuMDMxLDQxLjMyOS0xMjcuMTQ0LDQxLjMyOWMtMy40ODEsMC02LjgyNC0wLjIxMS0xMC4xMS0wLjUyOHYxOS4zMDYKCWgxNTYuMDMyVjMxLjUxMkgxNDkuNjQ4eiBNMTQ5LjY0OCw4MC42NTZWNJA1Ljc3N2MxLjQ0Ni0wLjEwMSwyLjkwMy0wLjE3OSw0LjM5MS0wLjIyNmM0MC42ODgtMS4yNzgsNjcuMzgyLDM0Ljk2NSw2Ny4zODIsMzQuOTY1CglzLTI4LjgzMiw0MC4wNDMtNTkuNzQ2LDQwLjA0M2MtNC40NDksMC04LjQzOC0wLjcxNS0xMi4wMjgtMS45MjJWOTMuNTIzYzE1Ljg0LDEuOTE0LDE5LjAyOCw4LjkxMSwyOC41NTEsMjQuNzg2bDIxLjE4LTE3Ljg1OQoJYzAsMC0xNS40NjEtMjAuMjc3LTQxLjUyNC0yMC4yNzdDMTU1LjAyMSw4MC4xNzIsMTUyLjMxLDgwLjM3MSwxNDkuNjQ4LDgwLjY1NiIvPgo8L3N2Zz4=");\
  background-size: contain;\
  background-repeat: no-repeat;\
  opacity: 0.95;\
}\
.jp-Splash .jp-Spinner, .jp-Splash .jp-Splash-content {\
  opacity: 0.2 !important;\
}\
</style>\
<!-- NVIDIA Branding End -->\
</head>|' "$INDEX_HTML"
done

echo "NVIDIA branding applied successfully!"
