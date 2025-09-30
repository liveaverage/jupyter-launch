#!/bin/bash
/// Purpose: Quick test script to verify CUDA images work correctly
/// Usage: ./test-cuda.sh [cuda_version]
/// Example: ./test-cuda.sh 12.1

set -e

CUDA_VERSION="${1:-12.1}"
IMAGE_NAME="pyrrhus-jupyter:cuda-${CUDA_VERSION}"
PORT="${PORT:-8889}"

# Color output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

echo "================================"
echo "CUDA Image Test Suite"
echo "================================"
echo

# Check if image exists
if ! docker image inspect "${IMAGE_NAME}" >/dev/null 2>&1; then
    log_error "Image ${IMAGE_NAME} not found. Build it first:"
    echo "  ./build-cuda.sh ${CUDA_VERSION}"
    exit 1
fi

log_info "Testing image: ${IMAGE_NAME}"
echo

# Test 1: Verify CUDA libraries present
log_info "Test 1: Checking CUDA libraries..."
if docker run --rm "${IMAGE_NAME}" bash -c "ldconfig -p | grep -q cuda"; then
    log_info "✓ CUDA libraries found"
else
    log_error "✗ CUDA libraries missing"
    exit 1
fi

# Test 2: Check NVIDIA runtime (if available)
log_info "Test 2: Checking NVIDIA runtime..."
if docker run --rm --gpus all "${IMAGE_NAME}" nvidia-smi 2>/dev/null; then
    log_info "✓ NVIDIA runtime working (GPU detected)"
else
    log_warn "⚠ NVIDIA runtime not available (no GPUs or nvidia-docker not installed)"
    log_warn "  This is OK for CPU-only testing"
fi

# Test 3: Verify JupyterLab installed
log_info "Test 3: Checking JupyterLab..."
JUPYTER_VERSION=$(docker run --rm "${IMAGE_NAME}" jupyter --version 2>&1 | grep -i "jupyterlab" | awk '{print $NF}')
if [ -n "${JUPYTER_VERSION}" ]; then
    log_info "✓ JupyterLab ${JUPYTER_VERSION} installed"
else
    log_error "✗ JupyterLab not found"
    exit 1
fi

# Test 4: Check NVIDIA extensions
log_info "Test 4: Checking NVIDIA extensions..."
if docker run --rm "${IMAGE_NAME}" pip list | grep -q "jupyterlab-nvdashboard"; then
    log_info "✓ jupyterlab-nvdashboard installed"
else
    log_error "✗ jupyterlab-nvdashboard missing"
    exit 1
fi

if docker run --rm "${IMAGE_NAME}" pip list | grep -q "nvidia-ml-py"; then
    log_info "✓ nvidia-ml-py3 installed"
else
    log_error "✗ nvidia-ml-py3 missing"
    exit 1
fi

# Test 5: Verify branding assets
log_info "Test 5: Checking NVIDIA branding..."
if docker run --rm "${IMAGE_NAME}" test -f /opt/nvidia-assets/favicon.ico; then
    log_info "✓ Branding assets present"
else
    log_error "✗ Branding assets missing"
    exit 1
fi

# Test 6: Check entrypoint
log_info "Test 6: Verifying entrypoint..."
if docker run --rm "${IMAGE_NAME}" bash -c "test -x /usr/local/bin/entrypoint.sh"; then
    log_info "✓ Entrypoint script executable"
else
    log_error "✗ Entrypoint script missing or not executable"
    exit 1
fi

# Test 7: Start container and check it runs
log_info "Test 7: Starting container (port ${PORT})..."
CONTAINER_ID=$(docker run -d \
    -p "${PORT}:8888" \
    -e JUPYTER_TOKEN="" \
    "${IMAGE_NAME}")

# Wait for JupyterLab to start
log_info "Waiting for JupyterLab to start..."
sleep 5

# Check if container is still running
if docker ps | grep -q "${CONTAINER_ID}"; then
    log_info "✓ Container running"
    
    # Check if port is responding
    if curl -s "http://localhost:${PORT}/lab" >/dev/null 2>&1; then
        log_info "✓ JupyterLab responding on port ${PORT}"
        log_info "  URL: http://localhost:${PORT}/lab"
    else
        log_warn "⚠ Container running but JupyterLab not responding yet"
        log_warn "  Try: http://localhost:${PORT}/lab"
    fi
    
    # Show logs
    echo
    log_info "Container logs (last 10 lines):"
    docker logs --tail 10 "${CONTAINER_ID}"
    
    echo
    log_info "Container is running. To stop it:"
    echo "  docker stop ${CONTAINER_ID}"
    echo
    log_info "To view full logs:"
    echo "  docker logs -f ${CONTAINER_ID}"
else
    log_error "✗ Container stopped unexpectedly"
    log_error "Logs:"
    docker logs "${CONTAINER_ID}"
    docker rm -f "${CONTAINER_ID}" 2>/dev/null
    exit 1
fi

echo
echo "================================"
log_info "All tests passed! ✓"
echo "================================"
echo
echo "Image: ${IMAGE_NAME}"
echo "Container: ${CONTAINER_ID}"
echo "URL: http://localhost:${PORT}/lab"
echo
echo "To stop: docker stop ${CONTAINER_ID}"

