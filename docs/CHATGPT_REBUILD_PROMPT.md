# ChatGPT rebuild guide for `container-artemis-first-trial`

This document is the self-contained specification for recreating, maintaining, or repairing this repository with ChatGPT. It intentionally summarizes the useful design knowledge that was learned from the earlier reference container project so that the reference repository does not need to be consulted again.

When changing this repository, inspect the current files first and treat working repository behavior as authoritative. Prefer small, targeted changes over broad dependency updates.

## Goal

Build one ARTEMIS software environment and distribute it in two equivalent forms:

1. a Docker image published to GitHub Container Registry (GHCR), and
2. an Apptainer/Singularity SIF image generated from that exact Docker image.

The Docker image and SIF must therefore contain the same software stack. Do not maintain independent Docker and Apptainer dependency recipes unless there is a compelling technical reason.

The expected image name is:

```text
ghcr.io/nobukoba/container-artemis-first-trial
```

The expected SIF name is:

```text
container-artemis-first-trial.sif
```

## Base operating system and CPU compatibility

Use AlmaLinux 10 as the base operating system.

The distributed container must target:

```text
linux/amd64/v2
```

This is deliberate. The same image should be usable on ordinary x86-64 Linux systems and under Docker Desktop's amd64 compatibility/emulation path on Apple Silicon Macs.

Do not compile distributed binaries with host-native optimization such as `-march=native`. Avoid creating dependencies on AVX or AVX2 that would make the image unusable on older x86-64 machines.

The current compiler policy is effectively:

```text
-O2 -march=x86-64-v2 -mtune=generic -mno-avx -mno-avx2
```

Keep the Docker build platform, helper scripts, and GitHub Actions platform settings consistent with this policy.

## Filesystem layout

Software provided by the image is installed under:

```text
/opt/artemis
```

The main layout is:

```text
/opt/artemis/
  root/       ROOT installation
  src/        source trees used during the image build
  bin/        ARTEMIS/dependency executables
  include/    headers
  lib/        libraries
  lib64/      libraries when required by a package
  scripts/    container check/helper scripts
```

Use `/work` as the writable user and development area:

```text
/work/
  src/
  build/
  local/
  scripts/
```

The image itself should be treated as immutable. Analysis data, user code, locally built software, temporary development files, and output files should normally live in a host directory bound to `/work`.

Both Docker and Apptainer runtime helpers must preserve this convention.

## ROOT compatibility policy

Do **not** automatically update ROOT to the newest stable release.

ARTEMIS compatibility is the primary requirement. A newer ROOT release is not automatically preferable and can introduce source or runtime incompatibilities with ARTEMIS.

The current baseline is:

```text
ROOT 6.32.06
Git tag: v6-32-06
```

The Dockerfile should therefore currently contain:

```dockerfile
ARG ROOT_VERSION=v6-32-06
```

ROOT 6.32 is an LTS series, but the important maintenance rule here is compatibility, not simply LTS status. Keep `v6-32-06` pinned until a different ROOT release has been explicitly tested with this ARTEMIS build.

### ROOT 6.32 CMake-option compatibility

Do not blindly reuse CMake feature switches from older ROOT releases.

With ROOT 6.32.06, passing this option is a **fatal configuration error**:

```text
-Dminuit2=ON
```

ROOT reports:

```text
Option 'minuit2' is no longer supported in ROOT 6.32.06.
```

Therefore the ROOT 6.32.06 build in this repository must **not** pass `-Dminuit2=ON`. Minuit2 is still needed by ARTEMIS as a ROOT component, but for this ROOT release it must not be enabled using that obsolete CMake option.

Similarly, avoid carrying forward undocumented or obsolete ROOT CMake switches simply because they existed in an older recipe. When a ROOT configure step fails, inspect ROOT's exact CMake error and remove or replace only the option that ROOT says is unsupported.

If ROOT is changed, verify at minimum:

```text
1. ROOT itself configures and builds successfully.
2. root-config reports the intended version.
3. ARTEMIS configures against that ROOT installation.
4. ARTEMIS compiles and installs successfully.
5. ARTEMIS starts successfully in the built container.
6. ROOT/ARTEMIS GUI functionality needed by users still works.
```

Do not silently replace ROOT 6.32.06 with the latest ROOT tag while fixing an unrelated build problem.

ARTEMIS requires ROOT components including RIO, Net, Physics, Geom, Minuit, Minuit2, and Gui. Preserve those capabilities when changing ROOT, while using CMake switches appropriate for the selected ROOT version.

## ARTEMIS source and build

The ARTEMIS project is:

```text
https://github.com/artemis-dev/artemis
```

Use the `develop` branch by default because this repository is intended for the ROOT6/CMake ARTEMIS build, unless the Dockerfile later deliberately pins a tested revision or tag.

ARTEMIS uses C++17.

The fundamental upstream-style build is conceptually:

```bash
git clone -b develop https://github.com/artemis-dev/artemis.git
cmake -S artemis -B artemis/build ...
cmake --build artemis/build
cmake --install artemis/build
```

Install ARTEMIS into `/opt/artemis`.

The current build configuration must include:

```text
BUILD_GET=OFF
BUILD_WITH_ZMQ=ON
BUILD_WITH_REDIS=ON
```

`BUILD_WITH_ZMQ=ON` and `BUILD_WITH_REDIS=ON` are intentional because this container is expected to remain suitable for ARTEMIS/NestDAQ online or streaming-data integration work.

## Required supporting libraries

The image currently builds and installs the following software needed by ARTEMIS or the intended online integration:

```text
yaml-cpp
ZeroMQ / libzmq
hiredis
redis-plus-plus
```

The current versions are encoded as Docker build arguments and should normally stay pinned so that the image is reproducible.

Current values are:

```text
yaml-cpp          0.8.0
libzmq            v4.3.5
hiredis           v1.1.0
redis-plus-plus   1.3.6
```

ARTEMIS's Redis build path expects both redis-plus-plus and hiredis to be discoverable. Keep `CMAKE_PREFIX_PATH`, `PKG_CONFIG_PATH`, library search paths, and installation prefixes synchronized if these dependencies are reorganized.

There is currently a small source patch applied to redis-plus-plus during the container build to ensure the required `<cstdint>` include is present. Do not remove such a targeted compatibility fix merely for cosmetic reasons; remove it only after verifying the newer source no longer needs it.

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

If this file exists:

```text
/opt/artemis/bin/thisartemis.sh
```

source it automatically for login shells.

## Docker build and runtime behavior

The local Docker build helper should:

```text
- default to image name container-artemis-first-trial
- target linux/amd64/v2
- use a timestamped tag
- also create/update a latest tag
- allow NPROC to be overridden
```

A normal local build command is:

```bash
./build-docker-image.sh
```

The Docker runtime helper should mount a host work directory at `/work` and preserve GUI support where practical.

On macOS, Docker Desktop commonly requires:

```text
DISPLAY=host.docker.internal:0
```

with XQuartz or another X server running for ROOT/ARTEMIS X11 windows.

On Linux, forward the current `DISPLAY` and bind `/tmp/.X11-unix` when available.

Keep the helper scripts and README commands synchronized whenever image names or paths change.

## Apptainer/Singularity policy

The preferred SIF build path is:

```text
Dockerfile -> Docker image -> GHCR -> Apptainer SIF
```

Do not rebuild the complete software stack independently inside an unrelated Apptainer definition if it can be avoided. Building the SIF from the already-built Docker image makes Docker and Apptainer distributions much easier to keep identical.

For example:

```bash
apptainer build container-artemis-first-trial.sif \
  docker://ghcr.io/nobukoba/container-artemis-first-trial:latest
```

The runtime helper should bind a host work directory to `/work` and forward X11 information when available.

## GitHub Actions design

The workflow is responsible for building and publishing both container forms.

It should run on an Ubuntu GitHub-hosted runner and use Docker Buildx.

The Docker image should be published to:

```text
ghcr.io/nobukoba/container-artemis-first-trial:<UTC timestamp>
ghcr.io/nobukoba/container-artemis-first-trial:latest
```

Build using:

```text
linux/amd64/v2
```

Keep the timestamp tag because it identifies an immutable Docker image that can be used as the source for the corresponding SIF.

After pushing the Docker image, pull or otherwise reference the exact timestamped image and build the SIF from it. Do not build the SIF from a potentially moving `latest` tag when the exact image is already known.

Publish SIF outputs as GitHub Actions artifacts, and maintain a rolling GitHub Release tagged `latest` containing the current SIF assets.

Expected names are conceptually:

```text
container-artemis-first-trial.sif
container-artemis-first-trial-<UTC timestamp>.sif
```

Keep GitHub Actions permissions sufficient for GHCR publishing and release creation (`packages: write` and `contents: write` as required by the workflow).

## Smoke tests

Both the Docker image and generated SIF must be smoke-tested.

The repository provides:

```bash
/opt/artemis/scripts/check-container.sh
```

The check should verify important installation facts such as:

```text
- ROOT is available and root-config works
- ARTEMIS executable is installed
- thisartemis.sh exists when expected
- yaml-cpp is discoverable
- libzmq is discoverable
- hiredis is discoverable
- redis-plus-plus is discoverable
- ARTEMIS CMake package/configuration files are installed
```

Where useful, also print `root-config --version` so that CI makes an accidental ROOT-version change obvious.

A successful Docker build alone is not sufficient. The SIF created from it must also pass the container check.

## Diagnosing CI failures

The final Buildx summary often contains only a wrapper message such as:

```text
process "..." did not complete successfully: exit code: 1
```

That line usually identifies the Docker `RUN` instruction that failed, but it does **not** identify the real compiler or CMake error.

For CI repair:

1. inspect the failed GitHub Actions job log or Buildx `.dockerbuild` record;
2. locate the first concrete `CMake Error`, `error:`, `fatal error:`, or failed command inside the affected build stage;
3. patch that exact cause rather than changing several dependency versions at once;
4. rerun CI and continue from the next concrete failure, if any.

For example, the ROOT 6.32.06 failure encountered in this repository was diagnosed from the Buildx record as:

```text
CMake Error at cmake/modules/RootBuildOptions.cmake:402 (message):
  >>> Option 'minuit2' is no longer supported in ROOT 6.32.06.
```

The correct targeted repair was to remove `-Dminuit2=ON`, not to replace ROOT with the newest release.

## Maintenance rules for ChatGPT

When asked to modify or repair this repository:

1. Inspect the current repository files before editing them.
2. Inspect the exact failing GitHub Actions log or Buildx build record when CI has failed; do not infer the root cause from the final Buildx wrapper line alone.
3. Preserve AlmaLinux 10 unless the user explicitly changes that requirement.
4. Preserve `linux/amd64/v2` portability and avoid host-native CPU optimization.
5. Preserve `/opt/artemis` for installed image software and `/work` for writable user files.
6. Keep ROOT pinned to `v6-32-06` unless compatibility with another version has actually been investigated and the user wants the change.
7. Treat ROOT version changes as ARTEMIS compatibility changes, not routine upgrades.
8. Keep ARTEMIS's required ROOT capabilities available, but use ROOT-version-appropriate CMake switches; specifically, do not pass obsolete `-Dminuit2=ON` to ROOT 6.32.06.
9. Preserve the intended `BUILD_WITH_ZMQ=ON` and `BUILD_WITH_REDIS=ON` configuration unless the user deliberately changes the online-integration goal.
10. Keep yaml-cpp, libzmq, hiredis, and redis-plus-plus discoverable by ARTEMIS.
11. Keep Docker, Apptainer, README, scripts, image names, CPU target, paths, and CI configuration synchronized.
12. Build the SIF from the exact Docker image produced by CI whenever possible.
13. Smoke-test both Docker and SIF.
14. Prefer a small targeted compatibility patch over an unrelated broad version upgrade.
15. After each change, clearly report what was changed and what still needs to be verified experimentally or by CI.

## Important files to inspect before changing the repository

At minimum inspect:

```text
Dockerfile
README.md
.github/workflows/docker.yml
build-docker-image.sh
run-docker-container.sh
login-docker-container.sh
build-apptainer-image.sh
run-apptainer-container.sh
scripts/check-container.sh
docs/CHATGPT_REBUILD_PROMPT.md
```

Also inspect upstream ARTEMIS's current CMake requirements before making a major dependency or compiler change.

## Recommended prompt to give ChatGPT later

```text
Read docs/CHATGPT_REBUILD_PROMPT.md in this repository first and treat it as the
maintenance specification. Then inspect the current repository and the relevant
upstream ARTEMIS files. Preserve the documented architecture and compatibility
choices unless I explicitly ask to change them. If CI is failing, inspect the
exact workflow/job log or Buildx build record and make the smallest justified
fix. Report exactly what you changed and what still needs testing.
```
