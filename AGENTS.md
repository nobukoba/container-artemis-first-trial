# Repository instructions for AI agents

This file contains the instructions and design constraints that AI assistants and coding agents should read before rebuilding or modifying this repository.

The repository itself is the authoritative source for the current package versions, scripts, build options, and runtime configuration. Before making changes, inspect the current repository, especially:

- `Dockerfile`
- `README.md`
- `.github/workflows/docker.yml`
- `build-docker-image.sh`
- `run-docker-container.sh`
- `login-docker-container.sh`
- `build-apptainer-image.sh`
- `run-apptainer-container.sh`
- `scripts/check-container.sh`

Do not recreate the environment only from this document. Preserve the current repository behavior unless a change is necessary.

## Purpose

This repository provides an ARTEMIS analysis environment as both:

- a Docker image published to GitHub Container Registry (GHCR), and
- an Apptainer/Singularity SIF image generated from that exact Docker image.

The Docker and SIF images should contain the same software stack. Avoid maintaining separate dependency recipes for Docker and Apptainer unless there is a compelling technical reason.

The expected image name is:

```text
ghcr.io/nobukoba/container-artemis-first-trial
```

The expected SIF name is:

```text
container-artemis-first-trial.sif
```

## Important build requirements

1. **Use AlmaLinux 9 as the preferred base operating system for the foreseeable future.** Stability and compatibility with the existing ARTEMIS/ROOT software stack are more important than moving to AlmaLinux 10. Do not migrate this repository to AlmaLinux 10 merely because it is newer. Reconsider a newer major AlmaLinux release only after the complete ROOT + ARTEMIS + dependency stack has been explicitly tested and there is a concrete reason to migrate.

2. Use the Docker platform recorded in the current workflow/build helper. If the platform is changed from `linux/amd64/v2` to `linux/amd64`, update all related files consistently.

3. **AVX and AVX2 must be disabled for Docker-distributed binaries. This is a mandatory runtime compatibility requirement, not an optional optimization preference.** Do not compile distributed binaries with `-march=native`, and do not remove either of these flags:

```text
-mno-avx -mno-avx2
```

If the Docker platform is `linux/amd64`, use a baseline CPU target such as:

```text
-O2 -march=x86-64 -mtune=generic -mno-avx -mno-avx2
```

If another CPU baseline is deliberately selected, `-mno-avx -mno-avx2` must still be preserved unless the user explicitly changes this requirement.

Apply this policy consistently to global `CFLAGS` / `CXXFLAGS` and to explicit ROOT CMake release flags such as `CMAKE_C_FLAGS_RELEASE` / `CMAKE_CXX_FLAGS_RELEASE`.

4. Install image-provided software under `/opt/artemis` and use `/work` as the persistent writable user/development area.

5. Keep ROOT pinned to the ARTEMIS-compatible version currently recorded in the Dockerfile. Do not automatically update ROOT to the latest stable release.

6. ROOT is currently pinned to:

```text
ROOT 6.32.06
Git tag: v6-32-06
```

7. ROOT 6.32.06 must not be configured with the obsolete CMake option `-Dminuit2=ON`. In this ROOT release the Minuit2 component is provided without that old build switch. Likewise, do not add old ROOT CMake switches unless they are known to exist for the pinned ROOT version.

8. ARTEMIS uses the `artemis-dev/artemis` `develop` branch by default and is built with C++17.

9. Preserve the intended ARTEMIS configuration unless explicitly changed:

```text
BUILD_GET=OFF
BUILD_WITH_ZMQ=ON
BUILD_WITH_REDIS=ON
```

10. Keep yaml-cpp, libzmq, hiredis, and redis-plus-plus discoverable by ARTEMIS.

11. Prefer small targeted compatibility fixes over broad compiler, ROOT, or dependency upgrades.

## ROOT compatibility policy

ARTEMIS compatibility is more important than using the newest ROOT release. A newer ROOT version can introduce source, CMake, ABI, or runtime incompatibilities.

Keep this baseline pinned until a different version has been explicitly tested:

```dockerfile
ARG ROOT_VERSION=v6-32-06
```

If ROOT is changed, verify at minimum:

```text
1. ROOT configures and builds successfully.
2. root-config reports the intended version.
3. ARTEMIS configures against that ROOT installation.
4. ARTEMIS compiles and installs successfully.
5. ARTEMIS starts successfully in the built container.
6. Required ROOT/ARTEMIS GUI functionality still works.
```

ARTEMIS requires ROOT components including RIO, Net, Physics, Geom, Minuit, Minuit2, and Gui. Preserve those capabilities, but do not assume that each component corresponds to a current ROOT CMake on/off option.

## ARTEMIS source and build

The ARTEMIS project is:

```text
https://github.com/artemis-dev/artemis
```

Use the `develop` branch by default unless the repository deliberately pins another tested revision.

The build is conceptually:

```bash
git clone -b develop https://github.com/artemis-dev/artemis.git
cmake -S artemis -B artemis/build ...
cmake --build artemis/build
cmake --install artemis/build
```

Install ARTEMIS into `/opt/artemis`.

## Required supporting libraries

The image currently builds and installs:

```text
yaml-cpp          0.8.0
libzmq            v4.3.5
hiredis           v1.1.0
redis-plus-plus   1.3.6
```

These versions are currently pinned in the Dockerfile for reproducibility.

ARTEMIS's Redis build path expects both redis-plus-plus and hiredis. Keep `CMAKE_PREFIX_PATH`, `PKG_CONFIG_PATH`, library search paths, and installation prefixes synchronized.

There is currently a small compatibility patch applied to redis-plus-plus to add the required `<cstdint>` include. Do not remove targeted compatibility fixes without first verifying they are no longer needed.

## Container layout

Use `/opt/artemis` as the image-provided software area:

```text
/opt/artemis/
  root/
  src/
  bin/
  include/
  lib/
  lib64/
  scripts/
```

Use `/work` as the writable user and development area:

```text
/work/
  src/
  build/
  local/
  scripts/
```

The Docker and Apptainer runtime helpers should bind a host work directory to `/work`.

## Environment inside the container

The expected core environment is:

```bash
ARTEMIS_ROOT=/opt/artemis
ROOTSYS=/opt/artemis/root
PATH=/opt/artemis/bin:/opt/artemis/root/bin:$PATH
CMAKE_PREFIX_PATH=/opt/artemis:/opt/artemis/root
PKG_CONFIG_PATH=/opt/artemis/lib/pkgconfig:/opt/artemis/lib64/pkgconfig
```

The ARTEMIS and ROOT library directories must be available through `LD_LIBRARY_PATH` and/or `ldconfig`.

If `/opt/artemis/bin/thisartemis.sh` exists, source it automatically for login shells.

## Docker and Apptainer policy

The preferred distribution flow is:

```text
Dockerfile -> Docker image -> GHCR -> Apptainer SIF
```

The local Docker build helper should:

- default to image name `container-artemis-first-trial`;
- use the same Docker platform as CI;
- create a UTC timestamped tag;
- also create/update `latest`;
- allow `NPROC` to be overridden;
- preserve `-mno-avx -mno-avx2` in all distributed builds.

The Docker runtime helper should mount a host work directory at `/work` and preserve X11 support where practical.

On macOS, Docker Desktop commonly uses:

```text
DISPLAY=host.docker.internal:0
```

with XQuartz or another X server for ROOT/ARTEMIS X11 windows.

On Linux, forward `DISPLAY` and bind `/tmp/.X11-unix` when available.

Build the SIF from the already-built Docker image, preferably from the exact immutable timestamped tag used by CI.

## GitHub Actions and images

GitHub Actions should build and publish:

```text
ghcr.io/nobukoba/container-artemis-first-trial:latest
ghcr.io/nobukoba/container-artemis-first-trial:YYYYMMDD-HHMMutc
```

Generate the timestamp in UTC using:

```bash
date -u +%Y%m%d-%H%Mutc
```

The workflow should then create:

```text
container-artemis-first-trial.sif
container-artemis-first-trial-YYYYMMDD-HHMMutc.sif
```

from the exact timestamped Docker image.

Publish the SIF files as workflow artifacts and in the rolling `latest` GitHub release.

Keep GitHub Actions permissions sufficient for GHCR publishing and release creation, including `packages: write` and `contents: write` where needed.

## Smoke tests

Both Docker and SIF images must be smoke-tested with:

```bash
/opt/artemis/scripts/check-container.sh
```

The check should verify important installation facts such as:

- `root-config` is available and reports the expected ROOT version;
- the ARTEMIS executable is installed;
- `thisartemis.sh` exists when expected;
- yaml-cpp is discoverable;
- libzmq is discoverable;
- hiredis is discoverable;
- redis-plus-plus is discoverable;
- ARTEMIS CMake package/configuration files are installed.

A successful Docker build alone is not sufficient. The generated SIF should also pass the container check.

## Diagnosing failed builds

When GitHub Actions fails, inspect the exact workflow/job log or Docker Buildx `.dockerbuild` build record rather than relying only on the final `exit code: 1` summary.

Determine whether the failure occurred during:

```text
CMake configure
compilation
installation
dependency discovery
runtime smoke test
```

Use the first concrete compiler or CMake error as the starting point.

For example, ROOT 6.32.06 rejects the obsolete `-Dminuit2=ON` CMake option. The correct fix is to remove that option, not to change ROOT versions broadly.

## Repository-level helper scripts

Keep the main user-facing helper scripts easy to discover:

```text
build-docker-image.sh
run-docker-container.sh
login-docker-container.sh
build-apptainer-image.sh
run-apptainer-container.sh
```

Internal implementation helpers may live under `scripts/` when appropriate.

## How AI agents should work on this repository

When working on this repository:

- inspect the current GitHub/repository state before editing;
- inspect upstream ARTEMIS and ROOT build configuration when dependency behavior matters;
- identify the specific cause of a build/runtime problem before making broad changes;
- prefer targeted fixes over global compiler or dependency changes;
- preserve working behavior unrelated to the requested change;
- **prefer AlmaLinux 9 for the foreseeable future; do not migrate to AlmaLinux 10 just because it is newer;**
- preserve the Docker platform recorded in the current repository unless explicitly changed;
- **always preserve `-mno-avx -mno-avx2` for Docker-distributed binaries unless the user explicitly changes this requirement;**
- preserve `/opt/artemis` for installed software and `/work` for writable files;
- keep ROOT pinned to `v6-32-06` unless a version change is explicitly investigated and requested;
- preserve the intended ZeroMQ and Redis ARTEMIS configuration unless explicitly changed;
- keep Docker, Apptainer, README, scripts, paths, image names, CPU target, and CI configuration synchronized;
- show concrete shell commands for testing;
- after changing the repository, report exactly which files changed and what should be tested;
- never claim to have inspected, built, tested, or modified something that was not actually accessible or executed.

When asked to rebuild or reproduce the image, first inspect the current repository and summarize the build flow and runtime flow before changing anything.

## AI assistants

These instructions are intended for ChatGPT, Codex, and other AI assistants/coding agents. They are not specific to one AI product.

`CHATGPT_REBUILD_PROMPT.md` is intentionally not used in this repository. The repository itself and this `AGENTS.md` file are the authoritative sources for development and maintenance.
