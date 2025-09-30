c = get_config()
c.ServerApp.extra_static_paths = ["/opt/nvidia-assets", "/opt/conda/share/jupyter/lab/static"]

# Set page config for title and favicon via Lab server app to avoid warnings on ServerApp
c.LabServerApp.page_config_data = {
    "appName": "NVIDIA Labs",
    "faviconUrl": "static/favicon.ico",
    # Disable default JupyterLab Tour bundles so only our custom tours run
    "disabledExtensions": {
        "jupyterlab-tour:notebook-tours": True,
        "jupyterlab-tour:default-tours": True
    }
}

# Disable language server autodetect to avoid scanning unwritable workspace
c.LanguageServerManager.autodetect = False

