c = get_config()
c.ServerApp.extra_static_paths = ["/opt/nvidia-assets", "/opt/conda/share/jupyter/lab/static"]

# Set page config for title and favicon (preferred, non-invasive way)
c.ServerApp.page_config_data = {
    "appName": "NVIDIA Labs",
    "faviconUrl": "static/favicon.ico"
}

# Back-compat: keep app_name for older LabApp handlers (harmless on JL4)
c.LabApp.app_name = "NVIDIA Labs"

