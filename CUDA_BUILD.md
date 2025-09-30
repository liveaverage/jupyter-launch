# CUDA Build Technical Guide

## Overview

This document provides technical details about the multi-CUDA build system for Pyrrhus JupyterLab containers.

## Architecture

### Base Images

We use official NVIDIA CUDA runtime images as the foundation:

```
nvidia/cuda:{CUDA_VERSION}.0-cudnn8-runtime-ubuntu{UBUNTU_VERSION}
```

### CUDA to Ubuntu Mapping

| CUDA Version | Ubuntu Version | Notes |
|--------------|----------------|-------|
| 11.8 | 20.04 | Legacy support, older GPUs (V100, T4) |
| 12.1 | 22.04 | Recommended for A100, RTX 3090/4090 |
| 12.4 | 22.04 | Latest, H100, L4, Ada Lovelace |

### Container Stack

```
nvidia/cuda:{version}-cudnn8-runtime
  ↓
Miniconda (Python 3.10+)
  ↓
JupyterLab 4.0+ with extensions
  ↓
NVIDIA monitoring tools
  ↓
Custom branding and configuration
```

## Build Arguments

### Required Arguments

- `CUDA_VERSION`: CUDA major.minor version (e.g., `12.1`)
- `UBUNTU_VERSION`: Ubuntu version (e.g., `22.04`)

### Optional Arguments

- `NB_USER`: Jupyter user name (default: `jovyan`)
- `NB_UID`: User ID (default: `1000`)
- `NB_GID`: Group ID (default: `100`)

### Example

```bash
docker build -f Dockerfile.cuda \
  --build-arg CUDA_VERSION=12.1 \
  --build-arg UBUNTU_VERSION=22.04 \
  --build-arg NB_UID=1001 \
  -t my-jupyter:cuda-12.1 .
```

## Image Tags

### Tag Format

Images are tagged with multiple formats for flexibility:

- `cuda-{version}` - Primary tag for specific CUDA version
- `cuda-{version}-latest` - Latest build of that CUDA version
- `cuda-{version}-{git-sha}` - Pinned to specific commit
- `{semver}-cuda-{version}` - Semantic version with CUDA version
- `latest` - Latest CUDA version (currently 12.4)

### Examples

```bash
# Stable production use
ghcr.io/org/pyrrhus-jupyter:cuda-12.1

# Always get latest build
ghcr.io/org/pyrrhus-jupyter:cuda-12.1-latest

# Pin to specific commit
ghcr.io/org/pyrrhus-jupyter:cuda-12.1-a1b2c3d

# Semantic versioning
ghcr.io/org/pyrrhus-jupyter:v1.2.3-cuda-12.1
```

## Local Development

### Build Single Version

```bash
./build-cuda.sh 12.1
```

### Build All Versions

```bash
./build-cuda.sh
```

### Test Image

```bash
# Test without GPU
docker run --rm -p 8888:8888 pyrrhus-jupyter:cuda-12.1

# Test with GPU
docker run --rm --gpus all -p 8888:8888 pyrrhus-jupyter:cuda-12.1

# Verify CUDA in container
docker run --rm --gpus all pyrrhus-jupyter:cuda-12.1 nvidia-smi
```

## GitHub Actions Workflow

### Trigger Events

1. **Push to main**: Builds all CUDA versions
2. **Git tags** (e.g., `v1.0.0`): Creates versioned releases
3. **Manual dispatch**: Custom CUDA version selection

### Matrix Strategy

The workflow uses a build matrix to parallelize builds:

```yaml
strategy:
  matrix:
    cuda_version: ['11.8', '12.1', '12.4']
```

Each CUDA version builds independently, reducing total CI time.

### Caching

GitHub Actions cache is scoped per CUDA version:

```yaml
cache-from: type=gha,scope=cuda-${{ matrix.cuda_version }}
cache-to: type=gha,mode=max,scope=cuda-${{ matrix.cuda_version }}
```

This dramatically speeds up subsequent builds.

## Performance Considerations

### Build Times

Approximate build times on GitHub Actions (ubuntu-latest):

- **First build**: ~15-20 minutes per CUDA version
- **Cached build**: ~5-8 minutes per CUDA version
- **Total (3 versions, cached)**: ~15-25 minutes

### Image Sizes

Approximate compressed image sizes:

- **Base layer (CUDA runtime)**: ~2-3 GB
- **Miniconda + JupyterLab**: ~1.5 GB
- **Total**: ~3.5-4.5 GB per image

### Optimization Tips

1. **Use cache**: Always use `--cache-from` for faster builds
2. **Multi-stage builds**: Consider splitting build/runtime stages
3. **Minimize layers**: Combine RUN commands where possible
4. **Clean apt cache**: Always `rm -rf /var/lib/apt/lists/*`

## Security

### Base Image Updates

NVIDIA CUDA images are regularly updated with security patches. To get latest patches:

```bash
docker pull nvidia/cuda:12.1.0-cudnn8-runtime-ubuntu22.04
./build-cuda.sh 12.1
```

### Scanning

Scan images for vulnerabilities:

```bash
# Using Trivy
trivy image pyrrhus-jupyter:cuda-12.1

# Using Docker Scout
docker scout cves pyrrhus-jupyter:cuda-12.1
```

### Non-root User

Images run as non-root user `jovyan` (UID 1000) by default for security.

## Troubleshooting

### CUDA Not Found

**Symptom**: `nvidia-smi` not found or CUDA libraries missing

**Solution**: Ensure using `--gpus all` flag:
```bash
docker run --gpus all ...
```

### Permission Denied

**Symptom**: Cannot write to `/home/jovyan`

**Solution**: Check UID/GID mapping:
```bash
docker run -e NB_UID=$(id -u) -e NB_GID=$(id -g) ...
```

### Out of Memory During Build

**Symptom**: Build fails with OOM error

**Solution**: Increase Docker memory limit:
```bash
# Docker Desktop: Settings > Resources > Memory > 8GB+
# Or use --memory flag
docker build --memory=8g ...
```

### CUDA Version Mismatch

**Symptom**: Application expects different CUDA version

**Solution**: Use correct image tag matching your requirements:
```bash
# Check PyTorch CUDA version
python -c "import torch; print(torch.version.cuda)"

# Use matching image
docker run ghcr.io/org/pyrrhus-jupyter:cuda-11.8  # if torch shows 11.8
```

## Adding New CUDA Versions

To add support for a new CUDA version (e.g., 12.6):

1. **Verify base image exists**:
   ```bash
   docker pull nvidia/cuda:12.6.0-cudnn8-runtime-ubuntu22.04
   ```

2. **Update build script**:
   ```bash
   # In build-cuda.sh, add to CUDA_VERSIONS array
   CUDA_VERSIONS=("11.8" "12.1" "12.4" "12.6")
   ```

3. **Update GitHub Actions**:
   ```yaml
   # In .github/workflows/build-cuda-images.yml
   matrix:
     cuda_version: ['11.8', '12.1', '12.4', '12.6']
     include:
       - cuda_version: '12.6'
         ubuntu_version: '22.04'
   ```

4. **Test locally**:
   ```bash
   ./build-cuda.sh 12.6
   docker run --rm --gpus all pyrrhus-jupyter:cuda-12.6 nvidia-smi
   ```

5. **Update documentation**: Add to README.md and this file.

## References

- [NVIDIA CUDA Container Images](https://hub.docker.com/r/nvidia/cuda)
- [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html)
- [JupyterLab Documentation](https://jupyterlab.readthedocs.io/)
- [GitHub Container Registry](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry)

