#!/usr/bin/env bash
set -euo pipefail

SIF="${SIF:-container-artemis-first-trial.sif}"
WORK_DIR="${WORK_DIR:-$PWD/work}"

mkdir -p "${WORK_DIR}"

args=(shell --bind "${WORK_DIR}:/work")

if [[ -n "${DISPLAY:-}" ]]; then
  args+=(--env "DISPLAY=${DISPLAY}")
fi
if [[ -d /tmp/.X11-unix ]]; then
  args+=(--bind /tmp/.X11-unix:/tmp/.X11-unix)
fi

apptainer "${args[@]}" "${SIF}"
