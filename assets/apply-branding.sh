#!/bin/bash
# Apply NVIDIA branding - runs as root during Docker build
set -e

echo "Applying NVIDIA branding..."

# Find the most likely static directory
if [ -d "/opt/conda/share/jupyter/lab/static" ]; then
    LAB_STATIC_DIR="/opt/conda/share/jupyter/lab/static"
else
    LAB_STATIC_DIR=$(find /opt/conda -path "*/jupyter/lab/static" -type d | head -1)
fi

ASSETS_DIR="/opt/nvidia-assets"
INDEX_HTML="${LAB_STATIC_DIR}/index.html"

if [ -z "$LAB_STATIC_DIR" ] || [ ! -f "$INDEX_HTML" ]; then
    echo "ERROR: JupyterLab static directory or index.html not found."
    exit 1
fi
echo "Found JupyterLab static directory: $LAB_STATIC_DIR"

# 1. Replace favicons
echo "Updating favicon..."
find /opt/conda -name "favicon*.ico" -type f -exec cp -f "${ASSETS_DIR}/favicon.ico" {} \; 2>/dev/null || true
# Ensure it exists in the main static directory as well for good measure
cp -f "${ASSETS_DIR}/favicon.ico" "${LAB_STATIC_DIR}/favicon.ico" 2>/dev/null || true

# 2. Inject NVIDIA branding CSS into index.html
echo "Injecting NVIDIA styles..."

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

echo "NVIDIA branding applied successfully!"