#!/usr/bin/env bash
set -euo pipefail

echo "=== ROOT ==="
test "${ROOTSYS:-}" = "/opt/root"
test -r /opt/root/bin/thisroot.sh
command -v root-config
root-config --version

echo "=== ARTEMIS ==="
test "${ARTEMIS_ROOT:-}" = "/opt/artemis"
command -v artemis
test -x /opt/artemis/bin/artemis
test -r /opt/artemis/bin/thisartemis.sh

echo "=== login shell environment ==="
bash -lc 'test "$ROOTSYS" = /opt/root'
bash -lc 'test "$ARTEMIS_ROOT" = /opt/artemis'
bash -lc 'command -v root-config >/dev/null'
bash -lc 'command -v artemis >/dev/null'

echo "=== libraries ==="
pkg-config --modversion yaml-cpp
pkg-config --modversion libzmq
pkg-config --modversion hiredis
pkg-config --modversion redis++

echo "=== CMake package ==="
test -r /opt/artemis/lib/cmake/artemis/artemis-config.cmake

echo "Container check passed."
