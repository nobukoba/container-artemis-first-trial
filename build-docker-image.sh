#!/usr/bin/env bash
set -euo pipefail

IMAGE_NAME="${IMAGE_NAME:-container-artemis-first-trial}"
NPROC="${NPROC:-4}"
STAMP="${STAMP:-$(date -u +%Y%m%d-%H%Mutc)}"

docker build \
  --platform linux/amd64/v2 \
  --progress=plain \
  --build-arg NPROC="${NPROC}" \
  -t "${IMAGE_NAME}:${STAMP}" \
  -t "${IMAGE_NAME}:latest" \
  .

echo "Built ${IMAGE_NAME}:${STAMP}"
echo "Built ${IMAGE_NAME}:latest"
docker image ls "${IMAGE_NAME}:${STAMP}"
