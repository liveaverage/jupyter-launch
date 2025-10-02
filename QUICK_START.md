# Quick Start Guide

## TL;DR

```bash
# Pull and run (replace [your-org] with your GitHub org)
docker run --rm --gpus all -p 8888:8888 \
  ghcr.io/[your-org]/pyrrhus-jupyter:cuda-12.1

# Or build locally
./build-cuda.sh 12.1
docker run --rm --gpus all -p 8888:8888 pyrrhus-jupyter:cuda-12.1
```

Access JupyterLab at: http://localhost:8888/lab

## CUDA Version Selection Guide

| Your GPU | Recommended CUDA | Image Tag |
|----------|------------------|-----------|
| V100, T4, RTX 20xx | 11.8 | `cuda-11.8` |
| A100, RTX 30xx | 12.1 | `cuda-12.1` |
| H100, L4, RTX 40xx | 12.4 | `cuda-12.4` |

## Common Commands

### Pull from GHCR

```bash
# Latest version
docker pull ghcr.io/[your-org]/pyrrhus-jupyter:latest

# Specific CUDA
docker pull ghcr.io/[your-org]/pyrrhus-jupyter:cuda-12.1
```

### Build Locally

```bash
# All CUDA versions
./build-cuda.sh

# Specific version
./build-cuda.sh 12.1

# Manual Docker build
docker build -f Dockerfile.cuda \
  --build-arg CUDA_VERSION=12.1 \
  --build-arg UBUNTU_VERSION=22.04 \
  -t my-jupyter:cuda-12.1 .
```

### Run Container

```bash
# Basic (no GPU)
docker run --rm -p 8888:8888 pyrrhus-jupyter:cuda-12.1

# With GPU
docker run --rm --gpus all -p 8888:8888 pyrrhus-jupyter:cuda-12.1

# With auto-loaded notebook from repo
docker run --rm --gpus all -p 8888:8888 \
  -e GITHUB_REPO=https://github.com/user/repo.git \
  -e AUTO_NOTEBOOK=my-notebook.ipynb \
  pyrrhus-jupyter:cuda-12.1

# With notebook from URL
docker run --rm --gpus all -p 8888:8888 \
  -e NOTEBOOK_URL=https://raw.githubusercontent.com/brevdev/launchables/main/biomistral.ipynb \
  -e AUTO_NOTEBOOK=biomistral.ipynb \
  pyrrhus-jupyter:cuda-12.1

# With volume-mounted notebook
docker run --rm --gpus all -p 8888:8888 \
  -v $(pwd)/my-notebook.ipynb:/home/jovyan/work/notebook.ipynb \
  -e AUTO_NOTEBOOK=/home/jovyan/work/notebook.ipynb \
  pyrrhus-jupyter:cuda-12.1

# With persistent storage
docker run --rm --gpus all -p 8888:8888 \
  -v $(pwd)/notebooks:/home/jovyan/work \
  pyrrhus-jupyter:cuda-12.1
```

### Test Image

```bash
./test-cuda.sh 12.1
```

### Verify GPU

```bash
# Check GPU visible in container
docker run --rm --gpus all pyrrhus-jupyter:cuda-12.1 nvidia-smi

# Check in JupyterLab
# Run in notebook cell:
import torch
print(f"CUDA available: {torch.cuda.is_available()}")
print(f"GPU count: {torch.cuda.device_count()}")
```

## Environment Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `GITHUB_REPO` | Git repository to clone | `https://github.com/user/repo.git` |
| `NOTEBOOK_URL` | URL to download notebook from | `https://example.com/notebook.ipynb` |
| `AUTO_NOTEBOOK` | Notebook to auto-open (path or filename) | `examples/demo.ipynb` or `demo.ipynb` |
| `AUTO_NOTEBOOK_GLOB` | Glob pattern for notebook | `*.ipynb` |
| `JUPYTER_TOKEN` | Auth token (empty = disabled) | `` (empty) or `mysecret123` |
| `KERNEL_GATEWAY` | Enable kernel gateway mode | `1` |
| `KERNEL_GATEWAY_PORT` | Gateway port | `9999` |

## Troubleshooting

### GPU Not Detected

```bash
# 1. Check NVIDIA driver on host
nvidia-smi

# 2. Check Docker has GPU support
docker run --rm --gpus all nvidia/cuda:12.1.0-base nvidia-smi

# 3. Install nvidia-docker if missing
# See: https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html
```

### Port Already in Use

```bash
# Use different port
docker run --rm --gpus all -p 8889:8888 pyrrhus-jupyter:cuda-12.1
# Access at: http://localhost:8889/lab
```

### Permission Denied

```bash
# Match host UID
docker run --rm --gpus all -p 8888:8888 \
  -e NB_UID=$(id -u) \
  -e NB_GID=$(id -g) \
  pyrrhus-jupyter:cuda-12.1
```

## GitHub Actions Setup

### Initial Setup

1. Fork or push code to GitHub
2. Navigate to: Repository Settings > Actions > General
3. Enable "Read and write permissions" for workflows
4. (Optional) Generate personal access token for private registries

### Triggering Builds

```bash
# Push to main (auto-builds all CUDA versions)
git push origin main

# Create release tag (builds versioned images)
git tag v1.0.0
git push origin v1.0.0

# Manual trigger
# Go to: Actions > Build and Push CUDA Images > Run workflow
```

### Viewing Images

- GHCR: `https://github.com/orgs/[your-org]/packages`
- Or: Your profile > Packages

## Advanced Usage

### Remote Kernel Gateway

```bash
# Start kernel gateway
docker run --rm --gpus all -p 9999:9999 \
  -e KERNEL_GATEWAY=1 \
  pyrrhus-jupyter:cuda-12.1

# Connect from local JupyterLab
jupyter labextension install jupyter-server-gateway
# Configure gateway URL: http://localhost:9999
```

### Multi-GPU

```bash
# Use specific GPUs
docker run --rm --gpus '"device=0,1"' -p 8888:8888 \
  pyrrhus-jupyter:cuda-12.1

# All GPUs (default)
docker run --rm --gpus all -p 8888:8888 \
  pyrrhus-jupyter:cuda-12.1
```

### Custom Memory Limit

```bash
docker run --rm --gpus all -p 8888:8888 \
  --memory=8g \
  --memory-swap=16g \
  pyrrhus-jupyter:cuda-12.1
```

## Need Help?

- Full docs: See `README.md`
- Technical details: See `CUDA_BUILD.md`
- Test suite: Run `./test-cuda.sh`

