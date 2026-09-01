# ChatGPT prompt for rebuilding this ARTEMIS container image

Use this prompt when asking ChatGPT to recreate or maintain this repository.

```text
I want to recreate and maintain the ARTEMIS Docker/Apptainer container in this
GitHub repository.

Inspect the current repository first, especially:

- Dockerfile
- README.md
- .github/workflows/docker.yml
- build-docker-image.sh
- run-docker-container.sh
- build-apptainer-image.sh
- run-apptainer-container.sh
- scripts/

Treat the repository files as authoritative and preserve current working
behavior unless a change is necessary.

Important design requirements:

1. Base the image on AlmaLinux 10.
2. Target linux/amd64/v2 so it can run with x86_64 emulation on Apple Silicon.
3. Avoid host-native AVX/AVX2 compiler optimization in distributed binaries.
4. Install image-provided software under /opt/artemis.
5. Use /work as the persistent writable user/development area.
6. Build a ROOT 6 environment with the components ARTEMIS needs, including
   RIO, Net, Physics, Geom, Minuit, Minuit2, and Gui.
7. Build ARTEMIS from the upstream develop branch unless the Dockerfile pins a
   different current revision.
8. Include yaml-cpp.
9. Build ARTEMIS with BUILD_WITH_ZMQ=ON and BUILD_WITH_REDIS=ON so that
   NestDAQ-related interfacing is available.
10. Include ZeroMQ, hiredis, and redis-plus-plus.
11. Keep Docker and Apptainer runtime helpers synchronized.
12. Docker and Apptainer must both bind a host work directory to /work.
13. GitHub Actions must publish the Docker image to
    ghcr.io/nobukoba/container-artemis-first-trial with both latest and timestamped tags.
14. GitHub Actions must create a SIF from that exact Docker image and publish
    the SIF as an Actions artifact and latest GitHub Release asset.
15. Keep README commands, image names, paths, CPU target, GUI/X11 notes, and
    helper scripts synchronized with the implementation.
16. Run smoke tests for both Docker and SIF.
17. Prefer targeted fixes and explain concrete build/runtime causes before
    making broad dependency changes.

First inspect the current GitHub repository and upstream ARTEMIS requirements.
Then make only the changes actually required, and report exactly which files
changed and what should be tested.
```
