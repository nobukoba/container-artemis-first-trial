# container-artemis-first-trial

ARTEMIS analysis environment packaged as both a Docker image and an Apptainer SIF image.

This repository builds the nuclear-physics ARTEMIS framework from the upstream `artemis-dev/artemis` `develop` branch.

## Quick start: Docker

No repository clone or helper script is required to use the pre-built Docker image.

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

The container starts `/bin/bash -l`, so it opens a **login shell**. ROOT and ARTEMIS are initialized automatically and are ready to use immediately.

The current host directory is mounted at `/work` inside the container.

To verify the installation:

```bash
/opt/artemis/scripts/check-container.sh
```

## Quick start: Apptainer

Download the rolling latest SIF directly:

```bash
curl -L -o container-artemis-first-trial.sif \
  https://github.com/nobukoba/container-artemis-first-trial/releases/download/latest/container-artemis-first-trial.sif
```

Start a login shell and bind the current directory to `/work`:

```bash
apptainer exec --bind "$PWD:/work" \
  container-artemis-first-trial.sif \
  /bin/bash -l
```

Using `/bin/bash -l` is intentional: the login-shell startup files initialize ROOT and ARTEMIS automatically.

You can alternatively build the SIF directly from the GHCR Docker image:

```bash
apptainer build container-artemis-first-trial.sif \
  docker://ghcr.io/nobukoba/container-artemis-first-trial:latest
```

## Installation and directory layout

CERN ROOT and ARTEMIS use separate installation prefixes.

```text
/opt/
├── root/                 CERN ROOT installation
│   ├── bin/
│   │   └── thisroot.sh
│   ├── include/
│   ├── lib/
│   └── ...
│
├── artemis/              ARTEMIS installation and its supporting libraries
│   ├── bin/
│   │   ├── artemis
│   │   └── thisartemis.sh
│   ├── include/
│   ├── lib/
│   ├── lib64/
│   └── scripts/
│       └── check-container.sh
│
└── src/                  source trees used to build the image
    ├── root/
    ├── root-build/
    ├── artemis/
    ├── yaml-cpp/
    ├── libzmq/
    ├── hiredis/
    └── redis-plus-plus/

/work/                    writable user area
├── src/
├── build/
├── local/
└── scripts/
```

The important distinction is:

```text
CERN ROOT  -> /opt/root
ARTEMIS    -> /opt/artemis
user files -> /work
```

`/opt/root` and `/opt/artemis` are image-provided software and should normally be treated as immutable. Analysis files, user code, output files, and local builds should live under `/work`.

## Login shell initialization

The container is configured so a Bash **login shell** automatically initializes both CERN ROOT and ARTEMIS.

The Docker image contains:

```text
/etc/profile.d/artemis-container.sh
```

A Bash login shell reads `/etc/profile`, which in turn reads the scripts under `/etc/profile.d/`. `artemis-container.sh` initializes the environment in this order:

```bash
source /opt/root/bin/thisroot.sh
source /opt/artemis/bin/thisartemis.sh
```

The order is intentional: ROOT is initialized first, then ARTEMIS.

The same profile script also establishes the container-specific installation prefixes:

```bash
ROOTSYS=/opt/root
ARTEMIS_ROOT=/opt/artemis
CMAKE_PREFIX_PATH=/opt/artemis:/opt/root
PKG_CONFIG_PATH=/opt/artemis/lib/pkgconfig:/opt/artemis/lib64/pkgconfig
```

The standard Docker command works automatically because the Dockerfile uses:

```text
CMD ["/bin/bash", "-l"]
```

When entering an already-running Docker container, also use a login shell:

```bash
docker exec -it container-artemis-first-trial /bin/bash -l
```

For Apptainer, use:

```bash
apptainer exec container-artemis-first-trial.sif /bin/bash -l
```

instead of relying on a non-login interactive shell if you want the automatic ROOT/ARTEMIS initialization.

## Optional helper scripts

The repository contains helper scripts for repeated local use and development. These are available after cloning the repository:

```bash
git clone https://github.com/nobukoba/container-artemis-first-trial.git
cd container-artemis-first-trial
```

Docker:

```bash
IMAGE=ghcr.io/nobukoba/container-artemis-first-trial:latest ./run-docker-container.sh
```

The Docker helper mounts host `./work` at `/work` and starts the container's login shell.

To enter an already-running helper container:

```bash
./login-docker-container.sh
```

`login-docker-container.sh` uses `bash -l`, so ROOT and ARTEMIS are initialized again for that shell.

Apptainer:

```bash
SIF=container-artemis-first-trial.sif ./run-apptainer-container.sh
```

The Apptainer helper also starts `/bin/bash -l` and mounts host `./work` at `/work`.

## Included software

The intended base environment is **AlmaLinux 9**.

AlmaLinux 9 is intentionally preferred for the foreseeable future. Build stability and compatibility with the ARTEMIS/ROOT stack are more important than moving to a newer major OS release simply because it is newer.

The image builds and installs:

- AlmaLinux 9 base environment
- CERN ROOT **6.32.06** (`v6-32-06`) under `/opt/root`
- ARTEMIS (`artemis-dev/artemis`, `develop`) under `/opt/artemis`
- yaml-cpp
- ZeroMQ / libzmq
- hiredis
- redis-plus-plus
- OpenMPI development environment

ROOT is intentionally pinned. Any ROOT-version change should be treated as a compatibility change and tested explicitly with ARTEMIS.

ARTEMIS is configured with:

```text
BUILD_GET=OFF
BUILD_WITH_ZMQ=ON
BUILD_WITH_REDIS=ON
```

## Build Docker locally

The following is for users who cloned this repository and want to build or maintain the image themselves.

```bash
./build-docker-image.sh
```

The helper builds for `linux/amd64` and creates timestamped and `latest` tags.

The distributed binaries use:

```text
-O2 -march=x86-64 -mtune=generic -mno-avx -mno-avx2
```

`-mno-avx -mno-avx2` are intentionally mandatory for distributed binaries in this repository.

The default parallelism is four jobs. Override it when necessary:

```bash
NPROC=8 ./build-docker-image.sh
```

## Apple Silicon Mac

The distributed image intentionally targets `linux/amd64`, including on Apple Silicon. Docker Desktop therefore runs it through its amd64 compatibility/emulation path.

For ROOT/ARTEMIS X11 windows on macOS, an X server such as XQuartz must be running. The optional Docker helper configures:

```text
DISPLAY=host.docker.internal:0
```

## Linux X11

The basic Quick Start command is intended for terminal use. For X11 applications, additional display/socket forwarding is required.

After cloning the repository, `run-docker-container.sh` forwards the current `DISPLAY` and mounts `/tmp/.X11-unix` when available. `run-apptainer-container.sh` similarly forwards `DISPLAY` and the X11 socket directory.

## GitHub Actions

`.github/workflows/docker.yml` builds and pushes:

```text
ghcr.io/nobukoba/container-artemis-first-trial:latest
ghcr.io/nobukoba/container-artemis-first-trial:<UTC timestamp>
```

The workflow then builds the Apptainer SIF from the exact timestamped GHCR Docker image, so Docker and SIF contain the same software stack.

It publishes:

```text
container-artemis-first-trial.sif
container-artemis-first-trial-<UTC timestamp>.sif
```

Both Docker and SIF are smoke-tested with:

```bash
/opt/artemis/scripts/check-container.sh
```

A successful smoke test also verifies the `/opt/root` and `/opt/artemis` prefixes and that a Bash login shell can find both `root-config` and `artemis`.

## For Developers

This repository is intended to be maintainable with **ChatGPT, Codex, or another AI coding agent**. The authoritative maintenance instructions are in [`AGENTS.md`](./AGENTS.md).

### Start here

```bash
git clone https://github.com/nobukoba/container-artemis-first-trial.git
cd container-artemis-first-trial
```

Before making changes, ask the coding agent to read `AGENTS.md` and inspect the current repository and CI state. For example:

```text
Read AGENTS.md first. Inspect the current repository and GitHub Actions status before making changes. Preserve all repository requirements in AGENTS.md. Make the necessary fix, update AGENTS.md with important troubleshooting information, commit the change, and check the resulting CI run.
```

### Important compatibility and layout requirements

Do not casually change these settings:

- AlmaLinux 9
- ROOT 6.32.06 (`v6-32-06`)
- `linux/amd64`
- `-mno-avx -mno-avx2`
- ARTEMIS ZeroMQ and Redis support
- CERN ROOT installation prefix: `/opt/root`
- ARTEMIS installation prefix: `/opt/artemis`
- writable user area: `/work`
- login-shell initialization through `/etc/profile.d/artemis-container.sh`
- initialization order: `thisroot.sh` first, `thisartemis.sh` second

### Development workflow

A normal maintenance cycle is:

1. Read `AGENTS.md` and inspect the current `Dockerfile`, helper scripts, README, and workflow.
2. Make the smallest targeted change needed.
3. Build/test locally when practical.
4. Commit and push.
5. Inspect the GitHub Actions **Build Docker and SIF** run.
6. On failure, identify the first concrete error in the job log.
7. Repeat until Docker build, Docker smoke test, SIF build, and SIF smoke test all succeed.
8. Record durable compatibility discoveries and troubleshooting information in `AGENTS.md`.
9. Keep README commands, install prefixes, login-shell behavior, helper scripts, and CI synchronized.

A container change is fully verified only after:

```text
Docker image build
  -> push to GHCR
  -> Docker smoke test
  -> build Apptainer SIF from that Docker image
  -> SIF smoke test
  -> upload/publish SIF
```

### Maintaining `AGENTS.md`

Update `AGENTS.md` when future maintainers should not have to rediscover a compatibility constraint, dependency decision, build failure root cause, verified fix, directory-layout assumption, or CI/publication behavior.

Keep this README focused on user/developer operation. Put detailed maintenance history and AI-agent hand-off information in `AGENTS.md`.

`CHATGPT_REBUILD_PROMPT.md` is not used. The repository, current CI state, and `AGENTS.md` are the authoritative sources for development and maintenance.
