# container-artemis-first-trial

ARTEMIS analysis environment packaged as both a Docker image and an Apptainer SIF image.

This repository builds the nuclear-physics ARTEMIS framework from the upstream `artemis-dev/artemis` `develop` branch.

## Quick start: Docker

Pull the pre-built image from GHCR:

```bash
docker pull --platform linux/amd64 ghcr.io/nobukoba/container-artemis-first-trial:latest
```

Run it with the helper script:

```bash
IMAGE=ghcr.io/nobukoba/container-artemis-first-trial:latest ./run-docker-container.sh
```

A host-side `./work` directory is mounted at `/work` inside the container.

For an interactive container that remains running, use the same helper and, from another terminal, enter it with:

```bash
CONTAINER=container-artemis-first-trial ./login-docker-container.sh
```

## Quick start: Apptainer

Download `container-artemis-first-trial.sif` from the repository's `latest` GitHub Release, then run:

```bash
SIF=container-artemis-first-trial.sif ./run-apptainer-container.sh
```

The helper binds the host `./work` directory to `/work` in the container.

You can also build the SIF directly from the GHCR Docker image:

```bash
apptainer build container-artemis-first-trial.sif \
  docker://ghcr.io/nobukoba/container-artemis-first-trial:latest
```

or use:

```bash
./build-apptainer-image.sh
```

## Container layout

Software installed in the image is kept under:

```text
/opt/artemis/
  root/       ROOT installation
  src/        source trees
  bin/        ARTEMIS and dependency binaries
  include/    headers
  lib/        libraries
  lib64/      libraries when used by a package
  scripts/    container helper/check scripts
```

The writable user area is:

```text
/work/
  src/
  build/
  local/
  scripts/
```

The image itself should be treated as immutable. Analysis files, user code, output files, and local builds should normally live below `/work`.

## Included software

The intended base environment is **AlmaLinux 9**.

AlmaLinux 9 is intentionally preferred for the foreseeable future. This container combines ARTEMIS, ROOT, and several supporting C/C++ libraries, and for this environment build stability and compatibility are more important than adopting the newest major OS release. Moving to AlmaLinux 10 also changes the compiler and system-library environment and can expose additional build or source-compatibility problems in ROOT, ARTEMIS, or their dependencies. Therefore, AlmaLinux 10 should not be adopted simply because it is newer; a future migration should be made only after the complete software stack has been tested successfully and there is a concrete benefit to the change.

The image builds and installs:

- AlmaLinux 9 base environment
- ROOT **6.32.06** (`v6-32-06`)
- ARTEMIS (`artemis-dev/artemis`, `develop` branch by default)
- yaml-cpp
- ZeroMQ / libzmq
- hiredis
- redis-plus-plus
- OpenMPI development environment

ROOT is intentionally pinned rather than tracking the newest ROOT release automatically. ARTEMIS compatibility is more important than using the newest ROOT version. Any ROOT-version change should be treated as a compatibility change and tested explicitly with ARTEMIS.

ARTEMIS is configured with:

```text
BUILD_GET=OFF
BUILD_WITH_ZMQ=ON
BUILD_WITH_REDIS=ON
```

This keeps the container suitable for future NestDAQ/online integration work using ZeroMQ and Redis.

## Environment

The container sets:

```bash
ARTEMIS_ROOT=/opt/artemis
ROOTSYS=/opt/artemis/root
CMAKE_PREFIX_PATH=/opt/artemis:/opt/artemis/root
```

and adds the ARTEMIS and ROOT binaries and libraries to the standard search paths.

When `/opt/artemis/bin/thisartemis.sh` exists, it is sourced automatically by the login-shell environment.

To verify the installation:

```bash
/opt/artemis/scripts/check-container.sh
```

## Build Docker locally

```bash
./build-docker-image.sh
```

The helper builds for:

```text
linux/amd64
```

and creates both timestamped and `latest` tags.

The distributed binaries use the baseline CPU target:

```text
-O2 -march=x86-64 -mtune=generic -mno-avx -mno-avx2
```

`-mno-avx -mno-avx2` are intentionally mandatory for Docker-distributed binaries in this repository.

The default parallelism is four jobs. Override it when necessary:

```bash
NPROC=8 ./build-docker-image.sh
```

## Apple Silicon Mac

The distributed image intentionally targets `linux/amd64`, including on an Apple Silicon Mac. Docker Desktop therefore runs it through its amd64 compatibility/emulation path.

The Dockerfile explicitly disables AVX and AVX2 code generation so that an image produced by GitHub Actions remains usable on the intended x86-64 hosts.

Run it in the same way:

```bash
IMAGE=ghcr.io/nobukoba/container-artemis-first-trial:latest ./run-docker-container.sh
```

For ROOT/ARTEMIS X11 windows on macOS, an X server such as XQuartz must be running. The helper sets:

```text
DISPLAY=host.docker.internal:0
```

## Linux X11

On Linux, `run-docker-container.sh` forwards the current `DISPLAY` and mounts `/tmp/.X11-unix` when available.

For Apptainer, `run-apptainer-container.sh` similarly forwards `DISPLAY` and the X11 socket directory.

## GitHub Actions

`.github/workflows/docker.yml` builds the Docker image and pushes:

```text
ghcr.io/nobukoba/container-artemis-first-trial:latest
ghcr.io/nobukoba/container-artemis-first-trial:<UTC timestamp>
```

The workflow then builds the Apptainer SIF from the exact timestamped GHCR Docker image. This ensures that the Docker and SIF artifacts contain the same software stack.

The workflow publishes:

```text
container-artemis-first-trial.sif
container-artemis-first-trial-<UTC timestamp>.sif
```

as GitHub Actions artifacts and as assets of the rolling `latest` GitHub Release.

Both Docker and SIF images are smoke-tested with:

```bash
/opt/artemis/scripts/check-container.sh
```

## For Developers

For development and maintenance of this container, please use **ChatGPT, Codex, or another AI assistant/coding agent** together with the instructions in [`AGENTS.md`](./AGENTS.md).

Before modifying the container, ask the AI agent to read `AGENTS.md` and inspect the current repository files. `AGENTS.md` contains the repository-specific build requirements, ROOT compatibility policy, directory layout, Docker/Apptainer workflow, CI behavior, and maintenance guidelines.

`CHATGPT_REBUILD_PROMPT.md` is not used in this repository. The repository itself and `AGENTS.md` are the authoritative sources for development and maintenance.
