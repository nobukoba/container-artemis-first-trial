# Repository instructions for AI agents

This file is the persistent hand-off note for ChatGPT, Codex, and other coding agents working on this repository. Always inspect the repository itself before editing; `Dockerfile`, workflow files, helper scripts, and `README.md` are authoritative for the current implementation.

## Purpose and build flow

This repository provides the ARTEMIS analysis environment as both a Docker image and an Apptainer/Singularity SIF image.

The intended distribution flow is:

```text
Dockerfile -> Docker image -> GHCR -> Apptainer SIF
```

Expected image and SIF names:

```text
ghcr.io/nobukoba/container-artemis-first-trial
container-artemis-first-trial.sif
```

Docker and SIF should contain the same software stack. Do not maintain separate dependency recipes unless there is a compelling technical reason.

## Non-negotiable build requirements

- Use **AlmaLinux 9** as the preferred base OS for the foreseeable future. Stability and compatibility with ARTEMIS/ROOT are more important than moving to AlmaLinux 10 merely because it is newer.
- Distributed Docker binaries must not require AVX or AVX2. Preserve:

```text
-mno-avx -mno-avx2
```

- Current baseline CPU flags are:

```text
-O2 -march=x86-64 -mtune=generic -mno-avx -mno-avx2
```

Apply the AVX policy both to global `CFLAGS` / `CXXFLAGS` and explicit ROOT release flags.
- Do not use `-march=native` for distributed images.
- Keep ROOT pinned to **6.32.06** (`v6-32-06`) unless a different ROOT release is explicitly investigated and tested with ARTEMIS.
- ROOT 6.32.06 must not be configured with obsolete switches such as `-Dminuit2=ON`.
- ARTEMIS normally uses `artemis-dev/artemis` branch `develop` and C++17.
- Preserve the ARTEMIS configuration unless explicitly changed:

```text
BUILD_GET=OFF
BUILD_WITH_ZMQ=ON
BUILD_WITH_REDIS=ON
```

- Prefer small targeted compatibility fixes over broad compiler, ROOT, dependency, or OS upgrades.

## Current pinned supporting libraries

```text
yaml-cpp          0.8.0
libzmq            v4.3.5
hiredis           v1.1.0
redis-plus-plus   1.3.6
```

ARTEMIS Redis support needs both hiredis and redis-plus-plus to be discoverable. The Dockerfile currently installs hiredis under `/opt/artemis/lib`. redis-plus-plus currently receives a targeted `<cstdint>` compatibility patch; do not remove it without confirming it is unnecessary.

## Filesystem layout

Image-provided software belongs under:

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

Writable user/development files belong under:

```text
/work/
  src/
  build/
  local/
  scripts/
```

Docker and Apptainer helpers should bind the host working directory to `/work`.

Expected core environment:

```bash
ARTEMIS_ROOT=/opt/artemis
ROOTSYS=/opt/artemis/root
PATH=/opt/artemis/bin:/opt/artemis/root/bin:$PATH
CMAKE_PREFIX_PATH=/opt/artemis:/opt/artemis/root
PKG_CONFIG_PATH=/opt/artemis/lib/pkgconfig:/opt/artemis/lib64/pkgconfig
```

ARTEMIS and ROOT libraries must be available through `LD_LIBRARY_PATH` and/or `ldconfig`. Source `/opt/artemis/bin/thisartemis.sh` automatically for login shells when it exists.

## CI / distribution expectations

GitHub Actions should build and publish:

```text
ghcr.io/nobukoba/container-artemis-first-trial:latest
ghcr.io/nobukoba/container-artemis-first-trial:YYYYMMDD-HHMMutc
```

The workflow then builds the SIF from the exact timestamped Docker image and publishes:

```text
container-artemis-first-trial.sif
container-artemis-first-trial-YYYYMMDD-HHMMutc.sif
```

Keep permissions sufficient for GHCR and release publishing (`packages: write`, `contents: write`).

Current GitHub-hosted runners provide four CPUs, so `NPROC=4` matches the available runner cores. Local builds may override `NPROC`.

## Smoke tests

Both Docker and SIF must pass:

```bash
/opt/artemis/scripts/check-container.sh
```

The check should verify at least ROOT, ARTEMIS, `thisartemis.sh`, yaml-cpp, libzmq, hiredis, redis-plus-plus, and ARTEMIS CMake installation metadata.

Container-side shell scripts copied into `/opt/artemis/scripts` must be executable. The Dockerfile currently fixes permissions with:

```bash
chmod -R a+rX /opt/artemis/scripts
find /opt/artemis/scripts -type f -name '*.sh' -exec chmod a+x {} +
```

Do not regress this: `chmod -R a+rX` by itself does **not** make a non-executable regular file executable because capital `X` only sets execute for directories or files that already had an execute bit.

## Build troubleshooting history / current state

This section records important completed troubleshooting so future agents do not repeat it.

### 2026-09-02: ROOT / ARTEMIS build reached a successful Docker image

The build on commit `499897affc079eddb4d46c9dc446bc5caadd819f` successfully completed all Docker build stages, including ROOT 6.32.06, yaml-cpp, libzmq, hiredis, redis-plus-plus, and ARTEMIS. The resulting image was pushed successfully to GHCR.

That is an important milestone: the current AlmaLinux 9 + ROOT 6.32.06 + ARTEMIS `develop` dependency recipe is capable of producing a complete Docker image. Do not undo those compatibility fixes unless a specific reason is found.

### 2026-09-02: smoke test failure was permissions-only

GitHub Actions run `33541798740`, attempt 2, failed **after** the Docker image had built and been pushed. The first concrete error was:

```text
bash: line 1: /opt/artemis/scripts/check-container.sh: Permission denied
Process completed with exit code 126
```

This was not a ROOT, ARTEMIS, Redis, ZeroMQ, compiler, or linker failure. The cause was that the Dockerfile used:

```bash
chmod -R a+rX /opt/artemis/scripts
```

but `scripts/check-container.sh` had no execute bit in the copied source. Capital `X` therefore did not add execute permission to that regular file.

Commit `91c5ff44ec21fb6ae9507b8644d249d3139dbfa8` fixes this by explicitly making copied `*.sh` files executable using `find ... -exec chmod a+x`.

A new CI run (`33580189516`) was automatically started from that fix. At the time this hand-off entry was written, that run was still in progress. The next agent should inspect that run before making further changes.

### Earlier compatibility decisions to preserve

- AlmaLinux 9 was selected instead of AlmaLinux 10 for the current ARTEMIS stack.
- ROOT was pinned to `v6-32-06`.
- Obsolete ROOT CMake switch `-Dminuit2=ON` was removed.
- CPU compatibility flags were changed to an x86-64 baseline with explicit `-mno-avx -mno-avx2`.
- hiredis installation was aligned with `/opt/artemis/lib` so ARTEMIS/redis-plus-plus can discover it.
- redis-plus-plus receives a narrow `<cstdint>` compatibility patch.

## Diagnosing future failures

When CI fails, inspect the exact workflow/job log rather than the final `exit code` summary. Classify the first real failure as one of:

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

Use the first concrete compiler/CMake/shell error as the starting point. A successful Docker build does not imply the runtime smoke test or SIF build has succeeded.

## User-facing helper scripts

Keep these easy to discover and synchronized with README/CI:

```text
build-docker-image.sh
run-docker-container.sh
login-docker-container.sh
build-apptainer-image.sh
run-apptainer-container.sh
```

On macOS, ROOT/ARTEMIS X11 usage normally relies on an X server such as XQuartz and `DISPLAY=host.docker.internal:0`. On Linux, forward `DISPLAY` and `/tmp/.X11-unix` where available.

## Rules for AI agents

Before modifying this repository:

- inspect the latest repository state and latest relevant GitHub Actions run;
- identify the specific failure before making broad changes;
- preserve unrelated working behavior;
- keep Dockerfile, CI, helper scripts, README, image names, filesystem paths, and CPU target synchronized;
- preserve AlmaLinux 9, ROOT 6.32.06, and `-mno-avx -mno-avx2` unless the user explicitly changes those requirements;
- preserve ZeroMQ and Redis support unless explicitly changed;
- test Docker and SIF separately;
- after editing, report exactly what changed and what remains to verify;
- never claim something was built, tested, or inspected unless it actually was.

`CHATGPT_REBUILD_PROMPT.md` is intentionally not used. The repository and this `AGENTS.md` are the persistent authoritative hand-off for development.
