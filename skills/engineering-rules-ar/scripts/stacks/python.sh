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
      local unpinned="" pin_rc=0 req_file
      local reqs=(-r requirements.txt) req_files=(requirements.txt)
      if [[ -f requirements-dev.txt ]]; then reqs+=(-r requirements-dev.txt); req_files+=(requirements-dev.txt); fi
      unpinned="$(python3 - "${req_files[@]}" <<'PY'
import pathlib, re, shlex, sys

problems = []
seen = set()
cwd = pathlib.Path.cwd()

def display(path):
    try:
        return str(path.relative_to(cwd))
    except ValueError:
        return str(path)

def scan(filename, chain=()):
    path = pathlib.Path(filename)
    if not path.is_absolute():
        path = cwd / path
    path = path.resolve()
    if path in chain:
        problems.append(f"{display(path)}: recursive requirements include")
        return
    if path in seen:
        return
    seen.add(path)
    try:
        lines = path.read_text(encoding="utf-8").splitlines()
    except OSError as exc:
        problems.append(f"{display(path)}: cannot read included requirements file ({exc})")
        return

    pending = ""
    for number, raw in enumerate(lines, 1):
        if not pending and raw.lstrip().startswith("#"):
            continue
        line = pending + raw.strip()
        if line.endswith("\\"):
            pending = line[:-1] + " "
            continue
        pending = ""
        line = re.split(r"\s+#", line, maxsplit=1)[0].strip()
        if not line:
            continue
        try:
            tokens = shlex.split(line)
        except ValueError as exc:
            problems.append(f"{display(path)}:{number}: invalid requirement syntax ({exc})")
            continue
        if not tokens:
            continue
        option, target = tokens[0], None
        if option in ("-r", "--requirement", "-c", "--constraint"):
            target = tokens[1] if len(tokens) > 1 else None
        elif option.startswith(("--requirement=", "--constraint=")):
            target = option.split("=", 1)[1]
        elif len(option) > 2 and option[:2] in ("-r", "-c"):
            target = option[2:]
        if option in ("-r", "--requirement", "-c", "--constraint") or option.startswith(("--requirement=", "--constraint=")) or (len(option) > 2 and option[:2] in ("-r", "-c")):
            if not target:
                problems.append(f"{display(path)}:{number}: missing requirements include path")
            else:
                included = pathlib.Path(target)
                if not included.is_absolute():
                    included = path.parent / included
                scan(included, chain + (path,))
            continue
        if option in ("-e", "--editable") or option.startswith("--editable=") or (option.startswith("-e") and len(option) > 2):
            problems.append(f"{display(path)}:{number}: editable requirements are not allowed; pin a released version with ==")
            continue
        if line.startswith("-"):
            allowed = {"-f", "-i", "--find-links", "--index-url", "--extra-index-url", "--trusted-host", "--no-index", "--pre", "--require-hashes", "--no-binary", "--only-binary", "--prefer-binary", "--use-pep517", "--no-use-pep517", "--no-build-isolation", "--check-build-dependencies", "--config-settings", "--global-option", "--install-option", "--hash", "--no-deps"}
            if option in allowed or option.split("=", 1)[0] in allowed:
                continue
            problems.append(f"{display(path)}:{number}: unsupported requirements directive {option}")
            continue

        quote = None
        depth = 0
        marker_at = None
        for index, char in enumerate(line):
            if quote:
                if char == quote and (index == 0 or line[index - 1] != "\\"):
                    quote = None
            elif char in "'\"":
                quote = char
            elif char in "([":
                depth += 1
            elif char in ")]":
                depth = max(0, depth - 1)
            elif char == ";" and depth == 0:
                marker_at = index
                break
        requirement = line[:marker_at] if marker_at is not None else line
        requirement = re.sub(r"\s+--hash(?:=|\s+)[^\s]+", "", requirement).strip()
        match = re.fullmatch(r"([A-Za-z0-9][A-Za-z0-9._-]*)(?:\[[A-Za-z0-9._,-]+\])?(.*)", requirement)
        specifier = match.group(2).strip() if match else ""
        if not match or not re.fullmatch(r"==\s*[A-Za-z0-9][A-Za-z0-9.!+_-]*", specifier) or "*" in specifier:
            problems.append(f"{display(path)}:{number}: requirement must use one exact == version pin: {line}")

    if pending:
        problems.append(f"{display(path)}:{len(lines)}: incomplete line continuation")

for root in sys.argv[1:]:
    scan(root)
if problems:
    print("; ".join(problems[:8]))
    sys.exit(1)
PY
)" || pin_rc=$?
      if [[ "$pin_rc" != 0 ]]; then
        fail pinned "unpinned or unreadable requirements: $(echo "$unpinned" | head -n 3 | tr '\n' ' ')"
      else
        pass pinned "all direct and included requirements use =="
      fi
      venv="${STACK_PY_VENV:-$(mktemp -d)/venv}"
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
