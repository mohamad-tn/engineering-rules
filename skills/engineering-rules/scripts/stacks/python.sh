#!/usr/bin/env bash
# shellcheck shell=bash
# Python engine: Django, FastAPI, Flask, libraries, data / ML projects.
# Managers: uv (uv.lock), Poetry (poetry.lock), pip (pinned requirements.txt).

run_python() {
  local mgr="" venv="" py="python3" fw="python"
  if [[ -f uv.lock ]]; then mgr=uv
  elif [[ -f poetry.lock ]]; then mgr=poetry
  elif [[ -f requirements.txt ]]; then mgr=pip
  fi
  if [[ -f manage.py ]]; then fw=django
  elif grep -qsiE '^\s*fastapi|"fastapi' requirements.txt pyproject.toml; then fw=fastapi
  elif grep -qsiE '^\s*flask|"flask' requirements.txt pyproject.toml; then fw=flask
  fi
  echo "  framework: ${fw}${mgr:+, manager: ${mgr}}"

  have python3 || { notrun deps "python3 is not installed"; return 0; }

  case "$mgr" in
    "")
      fail deps "no lock: commit uv.lock, poetry.lock, or a pinned requirements.txt"
      return 0
      ;;
    uv)
      have uv || { notrun deps "uv is not installed"; return 0; }
      gate_net deps -- uv sync --frozen
      venv=".venv"
      ;;
    poetry)
      have poetry || { notrun deps "poetry is not installed"; return 0; }
      gate_net deps -- bash -c "poetry check --lock && poetry install --no-interaction"
      venv="$(poetry env info --path 2>/dev/null || true)"
      ;;
    pip)
      # every requirement must be pinned with ==
      local unpinned
      unpinned="$(grep -vE '^\s*(#|-|$)' requirements.txt | grep -vE '==|@|^git\+|^https?://' || true)"
      if [[ -n "$unpinned" ]]; then
        fail pinned "unpinned requirements: $(echo "$unpinned" | head -n 3 | tr '\n' ' ')"
      else
        pass pinned "all requirements use =="
      fi
      venv="${STACK_PY_VENV:-$(mktemp -d)/venv}"
      local reqs=(-r requirements.txt)
      [[ -f requirements-dev.txt ]] && reqs+=(-r requirements-dev.txt)
      gate_net deps -- bash -c "python3 -m venv '${venv}' && '${venv}/bin/pip' install --disable-pip-version-check -q ${reqs[*]}"
      ;;
  esac
  [[ -n "$venv" && -d "$venv/bin" ]] && { export PATH="${venv}/bin:${PATH}"; py="${venv}/bin/python"; }
  [[ -x "$py" ]] || py="python3"

  # format and lint
  if { have ruff && { [[ -f ruff.toml || -f .ruff.toml ]] || grep -qs '^\[tool.ruff' pyproject.toml; }; }; then
    gate format -- ruff format --check .
    gate lint -- ruff check .
  elif have black && grep -qs '^\[tool.black' pyproject.toml; then
    gate format -- black --check .
    if have flake8; then gate lint -- flake8; else skip lint "no linter configured"; fi
  else
    skip format "no ruff/black configuration"
    if have flake8 && any_file ".flake8" "setup.cfg" "tox.ini"; then gate lint -- flake8; else skip lint "no ruff/flake8 configuration"; fi
  fi

  # types
  if have mypy && { [[ -f mypy.ini ]] || grep -qs '^\[tool.mypy' pyproject.toml || grep -qs '^\[mypy' setup.cfg; }; then
    # a project that names its own files (files = ...) must be checked the way it configured
    if grep -qsE '^[[:space:]]*files[[:space:]]*=' mypy.ini pyproject.toml setup.cfg; then gate types -- mypy; else gate types -- mypy .; fi
  elif have pyright && [[ -f pyrightconfig.json ]]; then
    gate types -- pyright
  else
    skip types "no mypy/pyright configuration"
  fi

  # tests
  if [[ -f manage.py ]] && ! { have pytest && grep -qsE 'pytest-django|pytest_django' requirements*.txt pyproject.toml; }; then
    gate test -- "$py" manage.py test
  elif have pytest || "$py" -c 'import pytest' >/dev/null 2>&1; then
    if [[ -d tests || -d test || -f pytest.ini ]] || grep -qs '^\[tool.pytest' pyproject.toml; then
      gate test -- "$py" -m pytest -q
    else
      skip test "no tests/ directory or pytest configuration"
    fi
  elif [[ -d tests ]]; then
    gate test -- "$py" -m unittest discover -s tests
  else
    skip test "no tests found"
  fi

  # Django extras
  if [[ "$fw" == "django" ]]; then
    gate django-check -- "$py" manage.py check
    gate migrations -- "$py" manage.py makemigrations --check --dry-run
  fi

  na build "no build step (use STACK_CMD_BUILD for a package build)"

  # audit
  if have pip-audit; then
    if [[ "$mgr" == "pip" ]]; then gate_net audit -- pip-audit -r requirements.txt --disable-pip; else gate_net audit -- pip-audit; fi
  else
    notrun audit "pip-audit is not installed (pipx install pip-audit)"
  fi
}
