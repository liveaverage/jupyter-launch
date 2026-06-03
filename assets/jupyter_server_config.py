import os

c = get_config()

static_paths = ["/opt/nvidia-assets"]
for path in [
    "/opt/conda/share/jupyter/lab/static",
    "/opt/venv/share/jupyter/lab/static",
    "/usr/local/share/jupyter/lab/static",
    "/usr/share/jupyter/lab/static",
]:
    if os.path.isdir(path):
        static_paths.append(path)

c.ServerApp.extra_static_paths = static_paths

# Disable language server autodetect to avoid scanning unwritable workspace
c.LanguageServerManager.autodetect = False
