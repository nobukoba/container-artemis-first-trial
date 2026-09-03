# container-artemis-first-trial

ARTEMIS analysis environment packaged as both a Docker image and an Apptainer SIF image. The image uses AlmaLinux 9, CERN ROOT 6.32.06, and ARTEMIS from `artemis-dev/artemis` (`develop`).

## Quick start: Docker

No repository clone or helper script is required.

```bash
docker pull --platform linux/amd64 \
  ghcr.io/nobukoba/container-artemis-first-trial:latest

docker run --rm -it \
  --platform linux/amd64 \
  -v "$PWD:/workspace" \
  ghcr.io/nobukoba/container-artemis-first-trial:latest
```

The current host directory is mounted directly at `/workspace`. The container starts `/bin/bash -l`, so ROOT and ARTEMIS are initialized automatically and are ready to use immediately.

Verify the installation with:

```bash
/opt/artemis/scripts/check-container.sh
```

## Quick start: Apptainer

```bash
curl -L -o container-artemis-first-trial.sif \
  https://github.com/nobukoba/container-artemis-first-trial/releases/download/latest/container-artemis-first-trial.sif

apptainer exec --cleanenv --bind "$PWD:/workspace" \
  container-artemis-first-trial.sif \
  /bin/bash -l
```

The current directory is mounted at `/workspace`. `--cleanenv` is intentional: it prevents host-side software environment variables such as `LD_LIBRARY_PATH` from leaking into the container and accidentally overriding `/opt/root` or `/opt/artemis`. Using `/bin/bash -l` is also intentional so the login-shell startup files initialize ROOT and ARTEMIS.

The SIF can also be built directly from GHCR:

```bash
apptainer build container-artemis-first-trial.sif \
  docker://ghcr.io/nobukoba/container-artemis-first-trial:latest
```

## Installation and directory layout

CERN ROOT and ARTEMIS use separate installation prefixes. `/workspace` is the writable user area and the default working directory.

```text
/opt/
├── root/                 CERN ROOT installation
│   ├── bin/
│   │   └── thisroot.sh
│   ├── include/
│   └── lib/
│
├── artemis/              ARTEMIS installation and supporting libraries
│   ├── bin/
│   │   ├── artemis
│   │   └── thisartemis.sh
│   ├── include/
│   ├── lib/
│   ├── lib64/
│   └── scripts/
│       └── check-container.sh
│
└── src/                  source/build trees used to build the image
    ├── root/
    ├── root-build/
    ├── artemis/
    ├── yaml-cpp/
    ├── libzmq/
    ├── hiredis/
    └── redis-plus-plus/

/workspace/               writable user workspace; Docker WORKDIR
```

The important distinction is:

```text
CERN ROOT  -> /opt/root
ARTEMIS    -> /opt/artemis
user files -> /workspace
```

`/opt/root` and `/opt/artemis` are image-provided software and should normally be treated as immutable. Analysis files, user code, output files, and local builds belong in `/workspace`.

## Login shell initialization

The container is configured so a Bash login shell automatically initializes CERN ROOT and ARTEMIS. The image contains:

```text
/etc/profile.d/artemis-container.sh
```

A Bash login shell reads `/etc/profile`, which reads scripts under `/etc/profile.d/`. The container profile initializes the software in this order:

```bash
source /opt/root/bin/thisroot.sh
source /opt/artemis/bin/thisartemis.sh
```

ROOT is initialized first because ARTEMIS depends on ROOT. The profile also establishes:

```bash
ROOTSYS=/opt/root
ARTEMIS_ROOT=/opt/artemis
CMAKE_PREFIX_PATH=/opt/artemis:/opt/root
PKG_CONFIG_PATH=/opt/artemis/lib/pkgconfig:/opt/artemis/lib64/pkgconfig
```

Docker starts a login shell by default:

```text
CMD ["/bin/bash", "-l"]
```

and the Docker working directory is:

```text
WORKDIR /workspace
```

To enter an already-running container with the same initialization:

```bash
docker exec -it container-artemis-first-trial /bin/bash -l
```

For Apptainer, use `--cleanenv` together with `/bin/bash -l` when automatic initialization is expected. This keeps the runtime environment container-local while still allowing the requested bind mounts and explicitly forwarded variables such as `DISPLAY`.

## Optional helper scripts

Clone the repository first:

```bash
git clone https://github.com/nobukoba/container-artemis-first-trial.git
cd container-artemis-first-trial
```

Docker:

```bash
IMAGE=ghcr.io/nobukoba/container-artemis-first-trial:latest ./run-docker-container.sh
```

By default the helper mounts the current host directory at `/workspace`. Override the host directory with `WORK_DIR` when needed.

Enter an already-running helper container with:

```bash
./login-docker-container.sh
```

Apptainer:

```bash
SIF=container-artemis-first-trial.sif ./run-apptainer-container.sh
```

The Apptainer helper mounts the current host directory at `/workspace`, uses `--cleanenv`, explicitly forwards `DISPLAY` when present, and starts `/bin/bash -l`.

## Included software

- AlmaLinux 9
- CERN ROOT **6.32.06** (`v6-32-06`) under `/opt/root`
- ARTEMIS (`artemis-dev/artemis`, `develop`) under `/opt/artemis`
- yaml-cpp
- ZeroMQ / libzmq
- hiredis
- redis-plus-plus
- OpenMPI development environment

ARTEMIS is configured with:

```text
BUILD_GET=OFF
BUILD_WITH_ZMQ=ON
BUILD_WITH_REDIS=ON
```

The distributed binaries use:

```text
-O2 -march=x86-64 -mtune=generic -mno-avx -mno-avx2
```

AlmaLinux 9, ROOT 6.32.06, and the no-AVX/AVX2 baseline are intentional compatibility choices.

## Build Docker locally

```bash
./build-docker-image.sh
```

The helper targets `linux/amd64` and creates timestamped and `latest` tags. Default build parallelism is four jobs; override when appropriate:

```bash
NPROC=8 ./build-docker-image.sh
```

## Apple Silicon Mac and X11

The distributed image intentionally targets `linux/amd64`, including on Apple Silicon. Docker Desktop runs it through its amd64 compatibility/emulation path.

For ROOT/ARTEMIS X11 windows on macOS, use an X server such as XQuartz. The optional Docker helper configures `DISPLAY=host.docker.internal:0`. On Linux the helper forwards `DISPLAY` and `/tmp/.X11-unix` when available.

## GitHub Actions

`.github/workflows/docker.yml` builds and pushes:

```text
ghcr.io/nobukoba/container-artemis-first-trial:latest
ghcr.io/nobukoba/container-artemis-first-trial:<UTC timestamp>
```

The workflow builds the Apptainer SIF from the exact timestamped Docker image and publishes rolling and timestamped SIF files. Both Docker and SIF are smoke-tested with:

```bash
/opt/artemis/scripts/check-container.sh
```

## For Developers

The authoritative maintenance instructions are in [`AGENTS.md`](./AGENTS.md). Before editing, read it and inspect the current repository and GitHub Actions state.

Important requirements include:

- AlmaLinux 9
- ROOT 6.32.06 (`v6-32-06`)
- `linux/amd64`
- `-mno-avx -mno-avx2`
- ZeroMQ and Redis support
- ROOT prefix `/opt/root`
- ARTEMIS prefix `/opt/artemis`
- build sources `/opt/src`
- writable/default user workspace `/workspace`
- host current directory normally mounted with `-v "$PWD:/workspace"`
- Apptainer normally launched with `--cleanenv` so host `LD_LIBRARY_PATH` and similar software paths are not inherited
- login initialization through `/etc/profile.d/artemis-container.sh`
- source order: `thisroot.sh` then `thisartemis.sh`

A normal maintenance cycle is: read `AGENTS.md`; inspect Dockerfile/helpers/workflow; make the smallest targeted change; test; commit/push; inspect the **Build Docker and SIF** run; diagnose the first concrete failure; repeat until Docker build, Docker smoke test, SIF build, and SIF smoke test succeed; then record durable findings in `AGENTS.md` and user-facing behavior here.

The CI success path is:

```text
Docker image build
  -> push to GHCR
  -> Docker smoke test
  -> build Apptainer SIF from that Docker image
  -> SIF smoke test
  -> upload/publish SIF
```

`CHATGPT_REBUILD_PROMPT.md` is not used. The repository, current CI state, and `AGENTS.md` are the authoritative sources for development and maintenance.
