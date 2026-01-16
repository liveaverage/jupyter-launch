# jupyter-launch

## NVIDIA-branded JupyterLab with GPU dashboards and remote kernel support


### Image Variants

**Slim (ultra-lightweight, ~1.5-2GB):**
- Base: `python:3.12-slim`
- Multi-stage build for minimal footprint
- Python 3.12
- No CUDA, extensions load dynamically
- Tags: `latest`, `slim`, `slim-latest`
- Use case: Minimal resource environments, fast deployment
- **Size optimization**: Multi-stage build copies only runtime artifacts, aggressive cleanup. `unstructured` without `[pdf]` extra (saves ~500MB).

**CPU-only (lightweight, ~2.5-3GB):**
- Base: `jupyter/base-notebook:latest`
- No CUDA, no JupyterLab build step
- Extensions load dynamically
- Tags: `cpu`, `cpu-latest`
- Use case: Development, testing, CPU workloads when compatibility with jupyter/base-notebook is desired
- **Size optimization**: `unstructured` installed without `[pdf]` extra (saves ~500MB). For PDF parsing, manually install: `apt-get install poppler-utils tesseract-ocr` in derived image.

**CUDA 12.1 (GPU-enabled, ~6GB):**
- Base: `nvidia/cuda:12.1.0-runtime-ubuntu22.04`
- Includes Node.js 20.x and built extensions
- Full GPU support with dashboards
- Tags: `cuda-12.1`, `cuda-12.1-latest`, `cuda-latest`
- Use case: GPU workloads, ML/AI development

### Features
- NVIDIA-themed dark mode with green accent colors (#76B900)
- Automatic notebook opening from cloned repositories
- GPU monitoring dashboards (when GPUs available)
- Interactive guided tours
- Remote kernel gateway support
- Disabled update/news notifications
- **Multi-CUDA support**: Pre-built images for CUDA 12.1
- **Slim option**: Ultra-lightweight (~1.5-2GB) multi-stage image with Python 3.12 for resource-constrained environments
- **CPU-only option**: Lightweight (~2.5-3GB) image for non-GPU workloads
- **NeMo Data Designer**: Includes tools for data curation (datasets, langchain, unstructured, nemo-microservices)
- **OpenShift compatible**: Works with arbitrary UIDs (uses aggressive 777 permissions for guaranteed compatibility)

### Quick Start

**Slim (smallest, default):**
```bash
docker run --rm -p 8888:8888 ghcr.io/[owner]/pyrrhus-jupyter:latest
```

**CPU-only (jupyter/base-notebook):**
```bash
docker run --rm -p 8888:8888 ghcr.io/[owner]/pyrrhus-jupyter:cpu
```

**With GPU support (CUDA 12.1):**
```bash
docker run --rm --gpus all -p 8888:8888 ghcr.io/[owner]/pyrrhus-jupyter:cuda-latest
```

**With auto-cloned repository:**
```bash
docker run --rm -p 8888:8888 \
  -e GITHUB_REPO=https://github.com/user/repo \
  -e AUTO_NOTEBOOK_GLOB="*.ipynb" \
  ghcr.io/[owner]/pyrrhus-jupyter:latest
```

### Environment Variables

- `GITHUB_REPO`: Optional Git repo to clone into `/home/jovyan/work/repo`.
- `REPO_SUBDIR`: Optional subdirectory within cloned repo to use as working directory (e.g., `notebooks` or `examples/quickstart`). Affects both the default landing page and `AUTO_NOTEBOOK_GLOB` search scope.
- `AUTO_NOTEBOOK`: Optional path (relative to repo root or absolute) of a notebook to auto-open.
- `AUTO_NOTEBOOK_GLOB`: Optional glob (e.g., `*.ipynb`) to pick the first matching notebook. When `REPO_SUBDIR` is set, searches within that subdirectory.
- `JUPYTER_TOKEN`: If empty, token auth is disabled. If set, will be used as login token.
- `KERNEL_GATEWAY`: If set to `1`, start `jupyter kernelgateway` (headless kernel mode) instead of JupyterLab.
- `KERNEL_GATEWAY_PORT`: Port for kernel gateway (default `9999`).
- `NOTEBOOK_URL`: Optional URL to download notebook from. Supports hybrid pattern: Kubernetes orchestrator uses initContainer (preferred), standalone Docker downloads directly (fallback).

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

## CUDA Support

This project supports multiple CUDA versions via separate base images:

- **CUDA 11.8**: For older GPUs and legacy compatibility (V100, T4, RTX 20xx/30xx)
- **CUDA 12.1**: Latest stable for modern GPUs (A100, H100, L4, RTX 40xx)

### Pre-built Images (GitHub Container Registry)

Pull pre-built images from GHCR:

```bash
# Latest CUDA 12.1
docker pull ghcr.io/[your-org]/pyrrhus-jupyter:latest

# Specific CUDA versions
docker pull ghcr.io/[your-org]/pyrrhus-jupyter:cuda-11.8
docker pull ghcr.io/[your-org]/pyrrhus-jupyter:cuda-12.1
```

### Building Locally

Build the slim variant (recommended):

```bash
cd lp-pyrrhus-jupyter-launch
./build-slim.sh
```

Build CPU variant:

```bash
docker build -f Dockerfile -t pyrrhus-jupyter:cpu .
```

Build all CUDA variants:

```bash
cd lp-pyrrhus-jupyter-launch
./build-cuda.sh
```

Build a specific CUDA version:

```bash
./build-cuda.sh 12.1
```

Or manually with Docker:

```bash
docker build -f Dockerfile.cuda \
  --build-arg CUDA_VERSION=12.1 \
  --build-arg UBUNTU_VERSION=22.04 \
  -t pyrrhus-jupyter:cuda-12.1 .
```

### Usage Examples

Using pre-built CUDA images:

```bash
# Launch with repo clone and auto-open first notebook
docker run --gpus all -p 8888:8888 \
  -e GITHUB_REPO=https://github.com/brevdev/notebooks.git \
  ghcr.io/[your-org]/pyrrhus-jupyter:cuda-12.1

# Launch with explicit notebook
docker run --gpus all -p 8888:8888 \
  -e GITHUB_REPO=https://github.com/brevdev/notebooks.git \
  -e AUTO_NOTEBOOK=nemo-reranker.ipynb \
  ghcr.io/[your-org]/pyrrhus-jupyter:cuda-12.1

# Launch into a subdirectory of the cloned repo
docker run --gpus all -p 8888:8888 \
  -e GITHUB_REPO=https://github.com/org/repo.git \
  -e REPO_SUBDIR=notebooks/getting-started \
  ghcr.io/[your-org]/pyrrhus-jupyter:cuda-12.1

# Launch with notebook from URL (standalone Docker pattern)
docker run --gpus all -p 8888:8888 \
  -e NOTEBOOK_URL=https://raw.githubusercontent.com/brevdev/launchables/main/biomistral.ipynb \
  -e AUTO_NOTEBOOK=biomistral.ipynb \
  ghcr.io/[your-org]/pyrrhus-jupyter:cuda-12.1

# Launch with pre-mounted notebook (volume mount pattern)
docker run --gpus all -p 8888:8888 \
  -v $(pwd)/my-notebook.ipynb:/home/jovyan/work/my-notebook.ipynb \
  -e AUTO_NOTEBOOK=/home/jovyan/work/my-notebook.ipynb \
  ghcr.io/[your-org]/pyrrhus-jupyter:cuda-12.1

# Headless kernel mode (remote kernel)
docker run --gpus all -p 9999:9999 \
  -e KERNEL_GATEWAY=1 \
  ghcr.io/[your-org]/pyrrhus-jupyter:cuda-12.1
```

Using locally built images:

```bash
# Standard build (non-CUDA)
docker build -t nv-jlab -f Dockerfile .

# Launch with repo clone
docker run --gpus all -p 8888:8888 \
  -e GITHUB_REPO=https://github.com/brevdev/notebooks.git \
  nv-jlab
```

### CI/CD

GitHub Actions automatically builds and pushes images to GHCR on:
- Push to `main` branch
- Git tags (e.g., `v1.0.0`)
- Manual workflow dispatch

Images are tagged with:
- `cuda-{version}` - Specific CUDA version
- `cuda-{version}-latest` - Latest build of that CUDA version
- `cuda-{version}-{git-sha}` - Specific commit
- `latest` - Latest CUDA version (12.1)

### Troubleshooting

**PDF parsing not working in slim/CPU images:**

Both the slim and CPU images omit `unstructured[pdf]` dependencies to save ~500MB. If you need PDF processing:

```dockerfile
FROM ghcr.io/[owner]/pyrrhus-jupyter:slim  # or :cpu
USER root
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        poppler-utils tesseract-ocr && \
    apt-get clean && rm -rf /var/lib/apt/lists/*
USER ${NB_USER}
```

Or install at runtime:
```bash
docker exec -u root <container-id> apt-get update && apt-get install -y poppler-utils tesseract-ocr
```
