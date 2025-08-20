# jupyter-launch

## NVIDIA-branded JupyterLab with GPU dashboards and remote kernel support

### Features
- NVIDIA-themed dark mode with green accent colors (#76B900)
- Automatic notebook opening from cloned repositories
- GPU monitoring dashboards (when GPUs available)
- Interactive guided tours
- Remote kernel gateway support
- Disabled update/news notifications

Environment variables:

- `GITHUB_REPO`: Optional Git repo to clone into `/home/jovyan/work/repo`.
- `AUTO_NOTEBOOK`: Optional path (relative to repo root or absolute) of a notebook to auto-open.
- `AUTO_NOTEBOOK_GLOB`: Optional glob (e.g., `*.ipynb`) to pick the first matching notebook.
- `JUPYTER_TOKEN`: If empty, token auth is disabled. If set, will be used as login token.
- `KERNEL_GATEWAY`: If set to `1`, start `jupyter kernelgateway` (headless kernel mode) instead of JupyterLab.
- `KERNEL_GATEWAY_PORT`: Port for kernel gateway (default `9999`).

Branding:

- Dark theme is default with NVIDIA accent (`#76B900`).
- Favicon shows NVIDIA logo.
- Top-left logo replaced with "NVIDIA" text.
- Green accent colors throughout UI.

GPU dashboards:

- `jupyterlab-nvdashboard` is installed. Access via the "GPU Dashboards" menu in JupyterLab.
- **Note**: GPU dashboards only appear when NVIDIA GPUs are detected. Use `--gpus all` flag with Docker.
- If no GPUs are available, the extension loads but the menu won't appear.

Interactive tour:

- JupyterLab Tour extension is installed and auto-starts on first launch.
- Two guided tours available:
  - **Welcome to NVIDIA JupyterLab**: Overview of features and navigation
  - **GPU Features Tour**: How to access GPU dashboards and monitoring
- Access tours anytime from Help menu > Tours

Remote kernel usage from a lightweight client:

- Start the container with `-e KERNEL_GATEWAY=1 -p 9999:9999`.
- From a local JupyterLab client, install `jupyter_server_gateway` and configure a Gateway Server at `http://<host>:9999`.

Usage examples:

```bash
docker build -t nv-jlab -f lp-pyrrhus-jupyter-launch/Dockerfile.jupyterlab .

# Launch with repo clone and auto-open first notebook
docker run --gpus all -p 8888:8888 -e GITHUB_REPO=https://github.com/brevdev/notebooks.git nv-jlab

# Launch with explicit notebook
docker run -p 8888:8888 -e GITHUB_REPO=https://github.com/brevdev/notebooks.git -e AUTO_NOTEBOOK=nemo-reranker.ipynb nv-jlab

# Headless kernel mode (remote kernel)
docker run --gpus all -p 9999:9999 -e KERNEL_GATEWAY=1 nv-jlab
```

