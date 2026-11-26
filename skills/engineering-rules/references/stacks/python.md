# Python: Django, FastAPI, Flask, libraries

Engine: `scripts/stacks/python.sh`. Managers: uv (`uv.lock`), Poetry (`poetry.lock`), pip (`requirements.txt`).

| Gate | Runs |
|---|---|
| pinned | pip only: every requirement must be pinned with `==` |
| deps | `uv sync --frozen`, `poetry install`, or a fresh virtualenv with `pip install -r` |
| format / lint | `ruff format --check` and `ruff check` when Ruff is configured, else Black / flake8 |
| types | mypy or pyright when configured |
| test | pytest, or `manage.py test` for Django, or `unittest` |
| audit | `pip-audit` (NOT RUN if it is not installed) |
| django-check, migrations | Django only: `manage.py check` and `makemigrations --check --dry-run` (a model change without a migration fails) |

## Recommended setup

- Lock your dependencies (uv or Poetry), or pin every line of `requirements.txt`.
- Opt-in configs: `templates/stacks/python/configs/` (`ruff.toml`, `mypy.ini`).
- Install `pip-audit` at a pinned version in CI.

## CI

`templates/stacks/python/ci.yml` (setup-python).
