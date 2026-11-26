#!/usr/bin/env bash
# shellcheck shell=bash
# Docker engine: lints Dockerfiles with hadolint; builds images only when asked.

run_docker() {
  local files=() f
  while IFS= read -r f; do files+=("${f#./}"); done < <(find . -maxdepth 1 -type f \( -name 'Dockerfile' -o -name 'Dockerfile.*' -o -name '*.Dockerfile' \) | sort)
  ((${#files[@]})) || { skip lint "no Dockerfile in this directory"; return 0; }
  echo "  dockerfiles: ${files[*]}"

  na deps "Dockerfile lint has no dependency installation step"
  na test "no built-in image tests; set STACK_CMD_TEST to run image tests"

  if have hadolint; then
    gate lint -- hadolint "${files[@]}"
  else
    notrun lint "hadolint is not installed (https://github.com/hadolint/hadolint)"
  fi

  if [[ "${STACK_DOCKER_BUILD:-0}" == "1" ]]; then
    if have docker; then
      # shellcheck disable=SC2016
      gate build -- bash -c 'for f in "$@"; do docker build --pull=false -f "$f" . || exit 1; done' _ "${files[@]}"
    else
      notrun build "docker is not installed"
    fi
  else
    na build "images are not built by default; set STACK_DOCKER_BUILD=1 (needs a Docker daemon)"
  fi
}
