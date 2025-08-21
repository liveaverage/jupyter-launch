c = get_config()
c.ServerApp.extra_static_paths = ["/opt/nvidia-assets", "/opt/conda/share/jupyter/lab/static"]

# Set page config for title and favicon via Lab server app to avoid warnings on ServerApp
c.LabServerApp.page_config_data = {
    "appName": "NVIDIA Labs",
    "faviconUrl": "static/favicon.ico",
    "disabledExtensions": [
        "jupyterlab-tour:default-tours"
    ]
}

# Disable language server autodetect to avoid scanning unwritable workspace
c.LanguageServerManager.autodetect = False

