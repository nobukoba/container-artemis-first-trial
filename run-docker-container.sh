#!/usr/bin/env bash
set -euo pipefail

IMAGE="${IMAGE:-container-artemis-first-trial:latest}"
WORK_DIR="${WORK_DIR:-$PWD/work}"

mkdir -p "${WORK_DIR}"

docker_args=(
  --rm -it
  --name container-artemis-first-trial
  --platform linux/amd64/v2
  --network host
  -v "${WORK_DIR}:/work"
)

case "$(uname -s)" in
  Darwin)
    docker_args+=(-e DISPLAY=host.docker.internal:0)
    ;;
  Linux)
    docker_args+=(-e DISPLAY="${DISPLAY:-:0}")
    if [[ -d /tmp/.X11-unix ]]; then
      docker_args+=(-v /tmp/.X11-unix:/tmp/.X11-unix:rw)
    fi
    ;;
esac

docker run "${docker_args[@]}" "${IMAGE}"
