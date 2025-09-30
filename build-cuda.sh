#!/bin/bash
/// Purpose: Build multi-CUDA variant images locally for testing
/// Inputs: Optional CUDA version argument (defaults to all: 11.8, 12.1, 12.4)
/// Outputs: Tagged Docker images for each CUDA version
/// Usage: ./build-cuda.sh [cuda_version]
/// Example: ./build-cuda.sh 12.1  # build only CUDA 12.1

set -e

# Default CUDA versions to build
CUDA_VERSIONS=("11.8" "12.1" "12.4")
IMAGE_NAME="${IMAGE_NAME:-pyrrhus-jupyter}"
REGISTRY="${REGISTRY:-ghcr.io}"
REPO="${REPO:-$(git config --get remote.origin.url | sed -e 's/.*://g' -e 's/.git$//g' | tr '[:upper:]' '[:lower:]')}"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# If argument provided, build only that version
if [ $# -gt 0 ]; then
    CUDA_VERSIONS=("$1")
fi

log_info "Building CUDA-enabled JupyterLab images"
log_info "Repository: ${REPO}"
log_info "CUDA versions: ${CUDA_VERSIONS[*]}"
echo

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    log_error "Docker is not running. Please start Docker and try again."
    exit 1
fi

# Build each CUDA version
for CUDA_VERSION in "${CUDA_VERSIONS[@]}"; do
    # Determine Ubuntu version based on CUDA version
    # CUDA 11.8 typically uses Ubuntu 20.04, CUDA 12.x uses 22.04
    if [[ "${CUDA_VERSION}" == 11.* ]]; then
        UBUNTU_VERSION="20.04"
    else
        UBUNTU_VERSION="22.04"
    fi
    
    IMAGE_TAG="${IMAGE_NAME}:cuda-${CUDA_VERSION}"
    FULL_TAG="${REGISTRY}/${REPO}/${IMAGE_TAG}"
    
    log_info "Building ${IMAGE_TAG} (CUDA ${CUDA_VERSION}, Ubuntu ${UBUNTU_VERSION})..."
    
    if docker build \
        --file Dockerfile.cuda \
        --build-arg CUDA_VERSION="${CUDA_VERSION}" \
        --build-arg UBUNTU_VERSION="${UBUNTU_VERSION}" \
        --tag "${IMAGE_TAG}" \
        --tag "${FULL_TAG}" \
        --tag "${IMAGE_NAME}:cuda-${CUDA_VERSION}-latest" \
        .; then
        log_info "✓ Successfully built ${IMAGE_TAG}"
    else
        log_error "✗ Failed to build ${IMAGE_TAG}"
        exit 1
    fi
    echo
done

# Also tag the latest CUDA version as 'latest'
LATEST_CUDA="${CUDA_VERSIONS[-1]}"
log_info "Tagging cuda-${LATEST_CUDA} as 'latest'"
docker tag "${IMAGE_NAME}:cuda-${LATEST_CUDA}" "${IMAGE_NAME}:latest"
docker tag "${IMAGE_NAME}:cuda-${LATEST_CUDA}" "${REGISTRY}/${REPO}/${IMAGE_NAME}:latest"

echo
log_info "Build complete! Images created:"
docker images | grep "${IMAGE_NAME}" | head -n 10

echo
log_info "To test an image locally with GPU:"
echo "  docker run --rm --gpus all -p 8888:8888 ${IMAGE_NAME}:cuda-${LATEST_CUDA}"
echo
log_info "To push to registry:"
echo "  docker login ${REGISTRY}"
echo "  docker push ${REGISTRY}/${REPO}/${IMAGE_NAME}:cuda-${LATEST_CUDA}"

