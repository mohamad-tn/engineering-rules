#!/usr/bin/env python3
"""Regression tests for publish preparation and Arabic file synchronization."""
import json
from pathlib import Path
import shutil
import subprocess
import tempfile

SOURCE = Path(__file__).resolve().parents[1]


def invoke(*args, success=True):
    result = subprocess.run(args, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    if (result.returncode == 0) != success:
        raise AssertionError(f"unexpected status {result.returncode}: {args}\n{result.stdout}")
    return result.stdout


def publish_prep(base):
    root = base / "publish"
    tools = root / "tools"
    tools.mkdir(parents=True)
    script = tools / "publish-prep.sh"
    shutil.copy2(SOURCE / "tools/publish-prep.sh", script)
    license_file = root / "LICENSE"
    readme = root / "README.md"
    license_file.write_text("Copyright (c) __YEAR__ __AUTHOR__\n", encoding="utf-8")
    readme.write_text("https://github.com/__GH_OWNER__/__GH_REPO__\n", encoding="utf-8")
    author = 'R&D "Ops" \\ Team'
    invoke("bash", str(script), "--owner", "octo-example", "--repo", "demo-rules", "--author", author, "--year", "2026")
    assert license_file.read_text(encoding="utf-8") == f"Copyright (c) 2026 {author}\n"
    assert readme.read_text(encoding="utf-8") == "https://github.com/octo-example/demo-rules\n"
    metadata = json.loads((tools / "publish.json").read_text(encoding="utf-8"))
    assert metadata == {"owner": "octo-example", "repo": "demo-rules", "author": author}

    # A prepared checkout still accepts new metadata rather than returning early.
    invoke("bash", str(script), "--owner", "new-owner", "--repo", "new-repo", "--author", "New Name", "--year", "2027")
    assert json.loads((tools / "publish.json").read_text(encoding="utf-8")) == {
        "owner": "new-owner", "repo": "new-repo", "author": "New Name"
    }
    before = license_file.read_bytes(), readme.read_bytes(), (tools / "publish.json").read_bytes()
    invoke("bash", str(script), "--owner", "new-owner", "--year", "20x6", success=False)
    assert before == (license_file.read_bytes(), readme.read_bytes(), (tools / "publish.json").read_bytes())


def sync_ar(base):
    root = base / "sync"
    tools = root / "tools"
    tools.mkdir(parents=True)
    script = tools / "sync-ar.sh"
    shutil.copy2(SOURCE / "tools/sync-ar.sh", script)
    en = root / "skills/engineering-rules"
    ar = root / "skills/engineering-rules-ar"
    (en / "scripts").mkdir(parents=True)
    (ar / "scripts").mkdir(parents=True)
    (en / "SKILL.md").write_text("English rules\n", encoding="utf-8")
    (ar / "SKILL.md").write_text("قواعد عربية\n", encoding="utf-8")
    (en / "scripts/config.json").write_text('{"source": true}\n', encoding="utf-8")
    (ar / "scripts/stale.sh").write_text("stale sentinel\n", encoding="utf-8")
    (ar / "README.md").write_text("translated document\n", encoding="utf-8")

    invoke("bash", str(script), "--check", success=False)
    assert (ar / "scripts/stale.sh").exists(), "check mode must not delete files"
    invoke("bash", str(script))
    assert (ar / "scripts/config.json").read_text(encoding="utf-8") == '{"source": true}\n'
    assert not (ar / "scripts/stale.sh").exists()
    assert (ar / "README.md").read_text(encoding="utf-8") == "translated document\n"
    invoke("bash", str(script), "--check")

    # Missing required English entry must fail before touching Arabic content.
    (ar / "sentinel.json").write_text("keep\n", encoding="utf-8")
    (en / "SKILL.md").unlink()
    invoke("bash", str(script), success=False)
    assert (ar / "sentinel.json").read_text(encoding="utf-8") == "keep\n"

    # Symlink inputs are rejected and likewise leave the target untouched.
    (en / "SKILL.md").write_text("English rules\n", encoding="utf-8")
    try:
        (en / "scripts/link.json").symlink_to(en / "scripts/config.json")
    except OSError:
        return
    invoke("bash", str(script), success=False)
    assert (ar / "sentinel.json").read_text(encoding="utf-8") == "keep\n"


def main():
    with tempfile.TemporaryDirectory(prefix="er-maintenance-test-") as tmp:
        base = Path(tmp)
        publish_prep(base)
        sync_ar(base)
    print("publish-prep quoting/JSON/metadata validation and sync-ar staged safety checks passed")


if __name__ == "__main__":
    main()
