#!/bin/bash
# Purpose: Build slim CPU-only image locally for testing
# Inputs: None
# Outputs: Tagged Docker image for slim variant
# Usage: ./build-slim.sh
# Notes: Uses multi-stage build with python:3.12-slim

set -e

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

log_info "Building slim CPU-only JupyterLab image (Python 3.12)"
log_info "Repository: ${REPO}"
echo

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    log_error "Docker is not running. Please start Docker and try again."
    exit 1
fi

IMAGE_TAG="${IMAGE_NAME}:slim"
FULL_TAG="${REGISTRY}/${REPO}/${IMAGE_TAG}"

log_info "Building ${IMAGE_TAG} (multi-stage, Python 3.12-slim)..."

if docker build \
    --file Dockerfile.slim \
    --tag "${IMAGE_TAG}" \
    --tag "${FULL_TAG}" \
    --tag "${IMAGE_NAME}:slim-latest" \
    .; then
    log_info "✓ Successfully built ${IMAGE_TAG}"
else
    log_error "✗ Failed to build ${IMAGE_TAG}"
    exit 1
fi

echo
log_info "Build complete! Image created:"
docker images | grep "${IMAGE_NAME}.*slim"

echo
log_info "Image size comparison:"
docker images | grep "${IMAGE_NAME}" | grep -E "(slim|cpu|latest)" | awk '{print $1":"$2, $7$8}'

echo
log_info "To test the slim image locally:"
echo "  docker run --rm -p 8888:8888 ${IMAGE_NAME}:slim"
echo
log_info "To push to registry:"
echo "  docker login ${REGISTRY}"
echo "  docker push ${REGISTRY}/${REPO}/${IMAGE_NAME}:slim"
echo
