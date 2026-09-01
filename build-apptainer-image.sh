#!/usr/bin/env bash
set -euo pipefail

IMAGE="${IMAGE:-ghcr.io/nobukoba/container-artemis-first-trial:latest}"
SIF="${SIF:-container-artemis-first-trial.sif}"

apptainer build "${SIF}" "docker://${IMAGE}"
echo "Built ${SIF}"
ls -lh "${SIF}"
