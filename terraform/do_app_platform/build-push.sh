#!/bin/bash
# Build and push the openclaw-telegram image to DO Container Registry.
# Run this after `terraform apply` to deploy a new image version.
#
# Usage: ./build-push.sh
# Requires: docker, doctl (https://docs.digitalocean.com/reference/doctl/)

set -e

REGISTRY=$(terraform output -raw registry_endpoint 2>/dev/null | cut -d/ -f1-2)
IMAGE_TAG="${REGISTRY}/openclaw-telegram:latest"
DOCKERFILE_DIR="../../docker/do_app_platform"

echo "Authenticating with DO Container Registry..."
doctl registry login

echo "Building image: ${IMAGE_TAG}"
docker build --platform linux/amd64 -t "${IMAGE_TAG}" "${DOCKERFILE_DIR}"

echo "Pushing image..."
docker push "${IMAGE_TAG}"

echo "Done. App Platform will auto-deploy the new image."
