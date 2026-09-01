#!/usr/bin/env bash
set -euo pipefail
CONTAINER="${CONTAINER:-container-artemis-first-trial}"
docker exec -it "${CONTAINER}" bash -l
