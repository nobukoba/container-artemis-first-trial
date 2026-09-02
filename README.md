# container-artemis-first-trial

ARTEMIS analysis environment packaged as both a Docker image and an Apptainer SIF image.

This repository builds the nuclear-physics ARTEMIS framework from the upstream `artemis-dev/artemis` `develop` branch.

## Quick start: Docker

No repository clone or helper script is required to use the pre-built Docker image.

Pull the image from GHCR:

```bash
docker pull --platform linux/amd64 \
  ghcr.io/nobukoba/container-artemis-first-trial:latest
```

Run it from the directory containing your analysis files:

```bash
docker run --rm -it \
  --platform linux/amd64 \
  -v "$PWD:/work" \
  ghcr.io/nobukoba/container-artemis-first-trial:latest
```

The current host directory is mounted at `/work` inside the container. ARTEMIS and ROOT are already installed under `/opt/artemis`.

To verify the installation inside the container:

```bash
/opt/artemis/scripts/check-container.sh
```

## Quick start: Apptainer

No repository clone is required. Download the rolling latest SIF directly:

```bash
curl -L -o container-artemis-first-trial.sif \
  https://github.com/nobukoba/container-artemis-first-trial/releases/download/latest/container-artemis-first-trial.sif
```

Run it from the directory containing your analysis files:

```bash
apptainer shell --bind "$PWD:/work" container-artemis-first-trial.sif
```

The current host directory is available at `/work` inside the container.

You can alternatively build the SIF directly from the GHCR Docker image:

```bash
apptainer build container-artemis-first-trial.sif \
  docker://ghcr.io/nobukoba/container-artemis-first-trial:latest
```

## Optional helper scripts

The repository also contains helper scripts for repeated local use and development. These scripts are available only after cloning the repository:

```bash
git clone https://github.com/nobukoba/container-artemis-first-trial.git
cd container-artemis-first-trial
```

Docker:

```bash
IMAGE=ghcr.io/nobukoba/container-artemis-first-trial:latest ./run-docker-container.sh
```

The Docker helper uses a host-side `./work` directory and mounts it at `/work`. It also configures X11 forwarding where applicable.

Apptainer:

```bash
SIF=container-artemis-first-trial.sif ./run-apptainer-container.sh
```

The Apptainer helper similarly mounts host `./work` at `/work`.

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

The image itself should be treated as immutable. Analysis files, user code, output files, and local builds should normally be placed in the host directory mounted at `/work`.

When the optional helper scripts are used, the repository's host-side `./work` directory is mounted at `/work`; its suggested organization is:

```text
work/
  src/
  build/
  local/
  scripts/
```

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

## Build Docker locally

The following sections are for users who cloned this repository and want to build or maintain the image themselves.

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

The same Quick Start `docker run` command above can be used on Apple Silicon.

For ROOT/ARTEMIS X11 windows on macOS, an X server such as XQuartz must be running. The optional Docker helper configures:

```text
DISPLAY=host.docker.internal:0
```

## Linux X11

The basic Quick Start command is intended for terminal use. For X11 applications, additional display/socket forwarding is required.

After cloning the repository, `run-docker-container.sh` forwards the current `DISPLAY` and mounts `/tmp/.X11-unix` when available. `run-apptainer-container.sh` similarly forwards `DISPLAY` and the X11 socket directory.

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

This repository is intended to be maintainable with **ChatGPT, Codex, or another AI coding agent**. The authoritative maintenance instructions are in [`AGENTS.md`](./AGENTS.md).

### Start here

Clone the repository and enter it:

```bash
git clone https://github.com/nobukoba/container-artemis-first-trial.git
cd container-artemis-first-trial
```

Before making changes, ask the coding agent to read `AGENTS.md` and inspect the current repository state. For example:

```text
Read AGENTS.md first. Inspect the current repository and GitHub Actions status before making changes. Preserve all repository requirements in AGENTS.md. Make the necessary fix, update AGENTS.md with important troubleshooting information, commit the change, and check the resulting CI run.
```

`AGENTS.md` records both the design requirements and troubleshooting history so that work can be continued in a new ChatGPT/Codex session without reconstructing earlier decisions from scratch.

### Important compatibility requirements

Do not casually change the following settings. See `AGENTS.md` for the rationale and current details.

- Keep **AlmaLinux 9** as the base OS for the foreseeable future.
- Keep ROOT pinned to **6.32.06** (`v6-32-06`) unless a complete compatibility test justifies changing it.
- Keep the distributed target at **`linux/amd64`**.
- Preserve **`-mno-avx -mno-avx2`** for distributed binaries.
- Preserve the repository's ARTEMIS build configuration, including ZeroMQ and Redis support.
- Treat `/opt/artemis` as image-provided software and `/work` as the writable user/development area.
- Keep Docker and SIF based on the same software stack; the CI-generated SIF should come from the exact Docker image built by that workflow run.

### Development workflow

A normal maintenance cycle is:

1. Read `AGENTS.md` and inspect the current `Dockerfile`, helper scripts, and workflow.
2. Make the smallest targeted change needed.
3. Build/test locally when practical.
4. Commit and push the change.
5. Inspect the GitHub Actions **Build Docker and SIF** run.
6. If CI fails, identify the **first concrete error** in the job log rather than guessing from the final exit code.
7. Make a targeted fix and repeat until Docker build, Docker smoke test, SIF build, and SIF smoke test all succeed.
8. Record important compatibility discoveries, failed approaches, and durable decisions in `AGENTS.md`.
9. Update this README when user-facing commands, supported behavior, or installation/use instructions change.

### CI success criteria

A container change is not considered fully verified merely because the Docker build succeeds. The GitHub Actions workflow should complete all of the following:

```text
Docker image build
  -> push to GHCR
  -> Docker smoke test
  -> build Apptainer SIF from that Docker image
  -> SIF smoke test
  -> upload/publish SIF
```

The common smoke test is:

```bash
/opt/artemis/scripts/check-container.sh
```

### Local development commands

Build the Docker image:

```bash
./build-docker-image.sh
```

Increase parallel build jobs when appropriate:

```bash
NPROC=8 ./build-docker-image.sh
```

Run the helper-based development container:

```bash
IMAGE=container-artemis-first-trial:latest ./run-docker-container.sh
```

Build a local SIF:

```bash
./build-apptainer-image.sh
```

Developers should inspect the helper scripts themselves before changing their assumptions about image names, mounts, networking, X11 forwarding, or platform settings.

### Maintaining `AGENTS.md`

Update `AGENTS.md` when a change reveals information that a future maintainer or AI agent should not have to rediscover. In particular, record:

- compatibility constraints and why they exist,
- dependency/version decisions,
- build failures and their actual root causes,
- fixes that were verified by CI,
- approaches that were tried and should not be repeated,
- changes to the Docker-to-SIF publication workflow,
- important directory-layout or runtime assumptions.

Do not fill `AGENTS.md` with transient noise from every CI run. Keep information that is useful for future diagnosis and maintenance.

### README vs. `AGENTS.md`

Keep this README focused on what users and developers need to operate the repository. Put detailed maintenance history, compatibility rationale, debugging records, and AI-agent hand-off information in `AGENTS.md`.

`CHATGPT_REBUILD_PROMPT.md` is not used in this repository. The repository itself, current CI state, and `AGENTS.md` are the authoritative sources for development and maintenance.
