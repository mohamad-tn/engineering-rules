# Python: Django, FastAPI, Flask, libraries

Engine: `scripts/stacks/python.sh`. Managers: uv (`uv.lock`), Poetry (`poetry.lock`), pip (`requirements.txt`).

| Gate | Runs |
|---|---|
| pinned | pip only: every requirement in `requirements.txt`, `requirements-dev.txt` (when present), and recursively included `-r` / `-c` files must be pinned with `==` |
| deps | `uv sync --locked` (rejects a stale lock), `poetry install`, or a fresh virtualenv with `pip install -r` |
| format / lint | `ruff format --check` and `ruff check` when Ruff is configured, else Black / flake8 |
| types | mypy or pyright when configured |
| test | pytest, or `manage.py test` for Django, or `unittest` |
| audit | `pip-audit` (NOT RUN if it is not installed) |
| django-check, migrations | Django only: `manage.py check` and `makemigrations --check --dry-run` (a model change without a migration fails) |

## Recommended setup

- Lock your dependencies (uv or Poetry), or pin every line of `requirements.txt`.
- In pip mode, `requirements-dev.txt` is installed alongside the main requirements; nested `-r` and `-c` files are also inspected for unpinned entries.
- The `pinned` gate requires one exact `==` version per package; editable and direct URL/VCS requirements are rejected by this gate.
- Opt-in configs: `templates/stacks/python/configs/` (`ruff.toml`, `mypy.ini`).
- Install `pip-audit` at a pinned version in CI.

## CI

`templates/stacks/python/ci.yml` (setup-python).
