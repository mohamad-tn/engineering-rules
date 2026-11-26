# Docker

Engine: `scripts/stacks/docker.sh`. Detects `Dockerfile`, `Dockerfile.*` and `*.Dockerfile` in a directory.

| Gate | Runs |
|---|---|
| lint | `hadolint` on every Dockerfile (NOT RUN if it is not installed) |
| build | only when `STACK_DOCKER_BUILD=1` and Docker is available: `docker build -f <file> .` |

Without `STACK_DOCKER_BUILD=1` the build gate is N/A: building images needs a daemon and takes time.

## Recommended setup

- Pin base images by tag (better, by digest), avoid `latest`, run as a non-root numeric user.
- Pin package versions where your distribution allows (`apk add pkg=1.2.3-r0`).
- One `.dockerignore` so secrets and `node_modules` never enter the build context.
- Install `hadolint` at a pinned version in CI (the workflow template shows a checksum-verified install).

## CI

`templates/stacks/docker/ci.yml`.
