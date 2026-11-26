<!-- rtl -->
<div dir="rtl">

# Python: Django وFastAPI وFlask والمكتبات

المحرك: `scripts/stacks/python.sh`. المديرون: `uv` (ملف `uv.lock`) و`Poetry` (ملف `poetry.lock`) و`pip` (ملف `requirements.txt`).

| البوابة | ما تشغّله |
|---|---|
| `pinned` | مع `pip` فقط: كل متطلب يجب أن يكون مثبّتًا بـ `==` |
| `deps` | `uv sync --frozen` أو `poetry install` أو بيئة افتراضية جديدة مع `pip install -r` |
| `format` و`lint` | `ruff format --check` و`ruff check` عند ضبط Ruff، وإلا `Black` و`flake8` |
| `types` | `mypy` أو `pyright` عند ضبطهما |
| `test` | `pytest`، أو `manage.py test` في Django، أو `unittest` |
| `audit` | `pip-audit` (`NOT RUN` إن لم يكن مثبّتًا) |
| `django-check` و`migrations` | لـ Django فقط: `manage.py check` و`makemigrations --check --dry-run` (تغيير نموذج بلا ترحيل يفشل) |

## الإعداد الموصى به

- اقفل اعتماداتك (`uv` أو `Poetry`)، أو ثبّت كل سطر في `requirements.txt`.
- إعدادات اختيارية: `templates/stacks/python/configs/` (الملفان `ruff.toml` و`mypy.ini`).
- ثبّت `pip-audit` بإصدار محدد في الـ CI.

## التكامل المستمر (CI)

الملف `templates/stacks/python/ci.yml` (`setup-python`).

</div>
