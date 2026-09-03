# Repository instructions for AI agents

This is the persistent hand-off note for ChatGPT, Codex, and other coding agents. Inspect the repository and latest relevant CI state before editing.

## Purpose and build flow

```text
Dockerfile -> Docker image -> GHCR -> Apptainer SIF
```

Expected artifacts:

```text
ghcr.io/nobukoba/container-artemis-first-trial
container-artemis-first-trial.sif
```

Docker and SIF must contain the same software stack.

## Non-negotiable build requirements

- Use **AlmaLinux 9** for the foreseeable future.
- Keep ROOT pinned to **6.32.06** (`v6-32-06`) unless a new release is explicitly tested with ARTEMIS.
- Distributed binaries must preserve:

```text
-O2 -march=x86-64 -mtune=generic -mno-avx -mno-avx2
```

Apply the AVX policy to global `CFLAGS` / `CXXFLAGS` and explicit ROOT release flags. Never use `-march=native` for distributed images.
- Do not reintroduce obsolete ROOT CMake switches such as `-Dminuit2=ON`.
- ARTEMIS normally uses `artemis-dev/artemis`, branch `develop`, C++17.
- Preserve:

```text
BUILD_GET=OFF
BUILD_WITH_ZMQ=ON
BUILD_WITH_REDIS=ON
```

- Prefer targeted compatibility fixes over broad OS/compiler/ROOT/dependency upgrades.

## Pinned supporting libraries

```text
yaml-cpp          0.8.0
libzmq            v4.3.5
hiredis           v1.1.0
redis-plus-plus   1.3.6
```

Supporting libraries are installed under `/opt/artemis`. Preserve the targeted redis-plus-plus `<cstdint>` compatibility patch unless verified unnecessary.

## Filesystem layout

CERN ROOT and ARTEMIS use separate installation prefixes. `/workspace` is the canonical writable user/development area and default working directory.

```text
/opt/root/                 CERN ROOT
  bin/thisroot.sh
  include/
  lib/

/opt/artemis/              ARTEMIS and supporting libraries
  bin/artemis
  bin/thisartemis.sh
  include/
  lib/
  lib64/
  scripts/check-container.sh

/opt/src/                  build source trees
  root/
  root-build/
  artemis/
  yaml-cpp/
  libzmq/
  hiredis/
  redis-plus-plus/

/workspace/                writable user/development workspace
```

Required distinction:

```text
CERN ROOT  -> /opt/root
ARTEMIS    -> /opt/artemis
build src  -> /opt/src
user files -> /workspace
```

Do not put ROOT back under `/opt/artemis/root`. Do not revert the user workspace to `/work` unless the user explicitly requests it.

Docker and Apptainer usage should normally mount the current host directory directly to `/workspace`:

```bash
-v "$PWD:/workspace"
--bind "$PWD:/workspace"
```

Helper scripts should default their host-side `WORK_DIR` to `$PWD` and mount it at `/workspace`. The Dockerfile must use:

```text
WORKDIR /workspace
```

Expected core environment:

```bash
ROOTSYS=/opt/root
ARTEMIS_ROOT=/opt/artemis
CMAKE_PREFIX_PATH=/opt/artemis:/opt/root
PKG_CONFIG_PATH=/opt/artemis/lib/pkgconfig:/opt/artemis/lib64/pkgconfig
```

## Login-shell initialization

A Bash login shell must make ROOT and ARTEMIS immediately usable. The image provides `/etc/profile.d/artemis-container.sh`, which must source in this order:

```bash
source /opt/root/bin/thisroot.sh
source /opt/artemis/bin/thisartemis.sh
```

ROOT is initialized first because ARTEMIS depends on ROOT. Docker must default to:

```text
CMD ["/bin/bash", "-l"]
```

`login-docker-container.sh` and the Apptainer helper must also use `/bin/bash -l`.

README must explicitly document `/opt/root`, `/opt/artemis`, `/opt/src`, `/workspace`, the Docker `WORKDIR`, login-shell behavior, `/etc/profile.d/artemis-container.sh`, both initialization scripts, their source order, and the `$PWD:/workspace` mount convention.

## CI / distribution

GitHub Actions publishes:

```text
ghcr.io/nobukoba/container-artemis-first-trial:latest
ghcr.io/nobukoba/container-artemis-first-trial:YYYYMMDD-HHMMutc
container-artemis-first-trial.sif
container-artemis-first-trial-YYYYMMDD-HHMMutc.sif
```

The SIF must be built from the exact timestamped Docker image. Keep `packages: write` and `contents: write`. Current GitHub-hosted runners provide four CPUs, so `NPROC=4` is the default.

## Smoke tests

Both Docker and SIF must pass:

```bash
/opt/artemis/scripts/check-container.sh
```

Verify at least ROOT and ARTEMIS prefixes/init scripts/binaries, login-shell discovery, yaml-cpp, libzmq, hiredis, redis-plus-plus, and ARTEMIS CMake metadata. Container-side scripts copied to `/opt/artemis/scripts` must be executable; preserve the explicit `find ... -exec chmod a+x` fix.

## Troubleshooting history

### 2026-09-02: complete Docker build established

Commit `499897affc079eddb4d46c9dc446bc5caadd819f` successfully built ROOT 6.32.06, dependencies, and ARTEMIS and pushed the image to GHCR.

### 2026-09-02: smoke-test permission failure

Run `33541798740`, attempt 2, failed because `/opt/artemis/scripts/check-container.sh` was not executable. Commit `91c5ff44ec21fb6ae9507b8644d249d3139dbfa8` fixed this with explicit execute permission; run `33580189516` then completed Docker and SIF successfully.

### 2026-09-03: installation layout changed

ROOT moved from `/opt/artemis/root` to `/opt/root`; ARTEMIS remains `/opt/artemis`; build sources moved to `/opt/src`. `/etc/profile.d/artemis-container.sh` sources `/opt/root/bin/thisroot.sh` then `/opt/artemis/bin/thisartemis.sh`. Apptainer uses `/bin/bash -l` for the same initialization path.

### 2026-09-03: user workspace renamed

The canonical user/development mount point changed from `/work` to `/workspace`. Direct Docker usage is `-v "$PWD:/workspace"`; direct Apptainer usage is `--bind "$PWD:/workspace"`; helper scripts default to mounting the current host directory at `/workspace`; Docker `WORKDIR` is `/workspace`. Keep README, helpers, and Dockerfile synchronized with this convention.

## Diagnosing failures

Use the first concrete error in the exact job log, not the final exit code. Classify failures as CMake configure, compilation, installation, dependency discovery, container startup, runtime smoke test, SIF conversion, or release publishing. A successful Docker build does not imply later smoke/SIF stages succeeded.

## User-facing helper scripts

Keep synchronized with README and CI:

```text
build-docker-image.sh
run-docker-container.sh
login-docker-container.sh
build-apptainer-image.sh
run-apptainer-container.sh
```

On macOS, X11 normally uses XQuartz and `DISPLAY=host.docker.internal:0`. On Linux forward `DISPLAY` and `/tmp/.X11-unix` where available.

## Rules for AI agents

Before modifying this repository:

- inspect `AGENTS.md`, current files, and latest relevant CI run;
- identify the specific failure before broad changes;
- preserve unrelated working behavior;
- keep Dockerfile, CI, helper scripts, README, image names, paths, and CPU target synchronized;
- preserve `/opt/root`, `/opt/artemis`, `/opt/src`, and `/workspace` roles;
- preserve login-shell automatic initialization and source order;
- preserve AlmaLinux 9, ROOT 6.32.06, `-mno-avx -mno-avx2`, ZeroMQ, and Redis unless explicitly changed;
- test Docker and SIF separately;
- report exactly what changed and what remains to verify;
- never claim something was built, tested, or inspected unless it actually was.

`CHATGPT_REBUILD_PROMPT.md` is intentionally not used. The repository and this `AGENTS.md` are the persistent authoritative hand-off.
