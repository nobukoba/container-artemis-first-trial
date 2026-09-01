#!/usr/bin/env bash
set -euo pipefail

echo "=== ROOT ==="
root-config --version

echo "=== ARTEMIS ==="
command -v artemis
test -x /opt/artemis/bin/artemis
test -r /opt/artemis/bin/thisartemis.sh

echo "=== libraries ==="
pkg-config --modversion yaml-cpp
pkg-config --modversion libzmq
pkg-config --modversion hiredis
pkg-config --modversion redis++

echo "=== CMake package ==="
test -r /opt/artemis/lib/cmake/artemis/artemis-config.cmake

echo "Container check passed."
