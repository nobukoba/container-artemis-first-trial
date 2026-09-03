# Repository instructions for AI agents

This file is the persistent hand-off note for ChatGPT, Codex, and other coding agents working on this repository. Always inspect the repository itself before editing; `Dockerfile`, workflow files, helper scripts, and `README.md` are authoritative for the current implementation.

## Purpose and build flow

This repository provides the ARTEMIS analysis environment as both a Docker image and an Apptainer/Singularity SIF image.

```text
Dockerfile -> Docker image -> GHCR -> Apptainer SIF
```

Expected names:

```text
ghcr.io/nobukoba/container-artemis-first-trial
container-artemis-first-trial.sif
```

Docker and SIF must contain the same software stack.

## Non-negotiable build requirements

- Use **AlmaLinux 9** for the foreseeable future.
- Distributed binaries must preserve `-mno-avx -mno-avx2`.
- Current baseline CPU flags are:

```text
-O2 -march=x86-64 -mtune=generic -mno-avx -mno-avx2
```

Apply these to global `CFLAGS` / `CXXFLAGS` and explicit ROOT release flags.
- Do not use `-march=native` for distributed images.
- Keep ROOT pinned to **6.32.06** (`v6-32-06`) unless a new release is explicitly tested with ARTEMIS.
- Do not reintroduce obsolete ROOT 6.32.06 CMake switches such as `-Dminuit2=ON`.
- ARTEMIS normally uses `artemis-dev/artemis`, branch `develop`, C++17.
- Preserve:

```text
BUILD_GET=OFF
BUILD_WITH_ZMQ=ON
BUILD_WITH_REDIS=ON
```

- Prefer targeted compatibility fixes over broad OS/compiler/ROOT/dependency upgrades.

## Current pinned supporting libraries

```text
yaml-cpp          0.8.0
libzmq            v4.3.5
hiredis           v1.1.0
redis-plus-plus   1.3.6
```

ARTEMIS Redis support needs both hiredis and redis-plus-plus. Supporting libraries are currently installed under `/opt/artemis`. redis-plus-plus receives a targeted `<cstdint>` compatibility patch; preserve it unless verified unnecessary.

## Filesystem layout

CERN ROOT and ARTEMIS must use separate installation prefixes.

```text
/opt/root/                 CERN ROOT installation
  bin/thisroot.sh
  bin/
  include/
  lib/

/opt/artemis/              ARTEMIS installation and supporting libraries
  bin/artemis
  bin/thisartemis.sh
  bin/
  include/
  lib/
  lib64/
  scripts/check-container.sh

/opt/src/                  source/build trees used while building the image
  root/
  root-build/
  artemis/
  yaml-cpp/
  libzmq/
  hiredis/
  redis-plus-plus/

/work/                     writable user/development area
  src/
  build/
  local/
  scripts/
```

The required installation-prefix distinction is:

```text
CERN ROOT  -> /opt/root
ARTEMIS    -> /opt/artemis
user files -> /work
```

Do not put CERN ROOT back under `/opt/artemis/root`.

Expected core environment:

```bash
ROOTSYS=/opt/root
ARTEMIS_ROOT=/opt/artemis
CMAKE_PREFIX_PATH=/opt/artemis:/opt/root
PKG_CONFIG_PATH=/opt/artemis/lib/pkgconfig:/opt/artemis/lib64/pkgconfig
```

ROOT and ARTEMIS binaries/libraries must be available through their initialization scripts plus normal linker configuration.

## Login-shell initialization

A Bash login shell must make ROOT and ARTEMIS immediately usable without manual `source` commands.

The Docker image provides:

```text
/etc/profile.d/artemis-container.sh
```

That file must source, in this order:

```bash
source /opt/root/bin/thisroot.sh
source /opt/artemis/bin/thisartemis.sh
```

ROOT is initialized first because ARTEMIS depends on ROOT.

The default Docker command must remain a Bash login shell:

```text
CMD ["/bin/bash", "-l"]
```

`login-docker-container.sh` must use `bash -l`.

The Apptainer helper must also launch `/bin/bash -l`; using plain `apptainer shell` alone is not sufficient to guarantee `/etc/profile.d/artemis-container.sh` is processed as a login shell.

README must explicitly document:

- the `/opt/root`, `/opt/artemis`, `/opt/src`, and `/work` directory structure;
- that the Docker default shell is `/bin/bash -l`;
- `/etc/profile.d/artemis-container.sh`;
- `/opt/root/bin/thisroot.sh` and `/opt/artemis/bin/thisartemis.sh`;
- the source order (`thisroot.sh` then `thisartemis.sh`);
- use of `/bin/bash -l` for Apptainer when automatic initialization is expected.

## CI / distribution expectations

GitHub Actions should build and publish:

```text
ghcr.io/nobukoba/container-artemis-first-trial:latest
ghcr.io/nobukoba/container-artemis-first-trial:YYYYMMDD-HHMMutc
```

The workflow builds the SIF from the exact timestamped Docker image and publishes:

```text
container-artemis-first-trial.sif
container-artemis-first-trial-YYYYMMDD-HHMMutc.sif
```

Keep permissions sufficient for GHCR and release publishing (`packages: write`, `contents: write`). Current GitHub-hosted runners provide four CPUs, so `NPROC=4` matches the runner. Local builds may override it.

## Smoke tests

Both Docker and SIF must pass:

```bash
/opt/artemis/scripts/check-container.sh
```

The check should verify at least:

- `ROOTSYS=/opt/root`;
- `/opt/root/bin/thisroot.sh`;
- `root-config`;
- `ARTEMIS_ROOT=/opt/artemis`;
- `/opt/artemis/bin/artemis`;
- `/opt/artemis/bin/thisartemis.sh`;
- a nested `bash -lc` can find both ROOT and ARTEMIS;
- yaml-cpp, libzmq, hiredis, redis-plus-plus;
- ARTEMIS CMake installation metadata.

Container-side shell scripts copied into `/opt/artemis/scripts` must be executable. Preserve the explicit `find ... -exec chmod a+x` fix; `chmod -R a+rX` alone does not make a non-executable regular file executable.

## Build troubleshooting history

### 2026-09-02: complete Docker build established

Commit `499897affc079eddb4d46c9dc446bc5caadd819f` successfully completed ROOT 6.32.06, yaml-cpp, libzmq, hiredis, redis-plus-plus, and ARTEMIS build/install and pushed the image to GHCR.

### 2026-09-02: smoke-test permission failure

Run `33541798740`, attempt 2, failed only because `/opt/artemis/scripts/check-container.sh` was not executable:

```text
bash: line 1: /opt/artemis/scripts/check-container.sh: Permission denied
Process completed with exit code 126
```

Commit `91c5ff44ec21fb6ae9507b8644d249d3139dbfa8` fixed this by explicitly adding execute permission to copied `*.sh` files. Run `33580189516` subsequently completed the Docker and SIF workflow successfully.

### 2026-09-03: installation layout changed

The required layout was changed from ROOT under `/opt/artemis/root` to separate prefixes:

```text
ROOT    /opt/root
ARTEMIS /opt/artemis
```

Build sources moved to `/opt/src`. Login-shell initialization was also made explicit: `/etc/profile.d/artemis-container.sh` sources `/opt/root/bin/thisroot.sh` first and `/opt/artemis/bin/thisartemis.sh` second. Apptainer helper behavior was changed to execute `/bin/bash -l` so the same initialization path is used.

Do not revert these layout/login-shell decisions unless the user explicitly requests a different design.

### Earlier compatibility decisions to preserve

- AlmaLinux 9 instead of AlmaLinux 10.
- ROOT pinned to `v6-32-06`.
- Obsolete ROOT CMake switches removed.
- x86-64 baseline with explicit `-mno-avx -mno-avx2`.
- hiredis installed under `/opt/artemis/lib` for discovery.
- narrow redis-plus-plus `<cstdint>` compatibility patch.

## Diagnosing future failures

When CI fails, inspect the exact job log and use the first real error rather than the final exit code. Classify it as one of:

```text
CMake configure
compilation
installation
dependency discovery
container startup
runtime smoke test
Apptainer/SIF conversion
release publishing
```

A successful Docker build does not imply the Docker smoke test, SIF build, or SIF smoke test succeeded.

## User-facing helper scripts

Keep these synchronized with README and CI:

```text
build-docker-image.sh
run-docker-container.sh
login-docker-container.sh
build-apptainer-image.sh
run-apptainer-container.sh
```

On macOS, ROOT/ARTEMIS X11 usage normally relies on XQuartz and `DISPLAY=host.docker.internal:0`. On Linux, forward `DISPLAY` and `/tmp/.X11-unix` where available.

## Rules for AI agents

Before modifying this repository:

- inspect `AGENTS.md`, repository files, and the latest relevant CI run;
- identify the specific failure before broad changes;
- preserve unrelated working behavior;
- keep Dockerfile, CI, helper scripts, README, image names, filesystem paths, and CPU target synchronized;
- preserve `/opt/root` for CERN ROOT and `/opt/artemis` for ARTEMIS;
- preserve login-shell automatic initialization and source order;
- preserve AlmaLinux 9, ROOT 6.32.06, and `-mno-avx -mno-avx2` unless explicitly changed;
- preserve ZeroMQ and Redis support unless explicitly changed;
- test Docker and SIF separately;
- after editing, report exactly what changed and what remains to verify;
- never claim something was built, tested, or inspected unless it actually was.

`CHATGPT_REBUILD_PROMPT.md` is intentionally not used. The repository and this `AGENTS.md` are the persistent authoritative hand-off for development.
