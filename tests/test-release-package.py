#!/usr/bin/env python3
"""Exercise release packaging in an isolated, clean Git worktree."""
import hashlib
import json
import subprocess
import tempfile
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
VERSION = (ROOT / "skills/engineering-rules/VERSION").read_text(encoding="utf-8").strip()


def run(*args, cwd=None, success=True):
    result = subprocess.run(args, cwd=cwd, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    if (result.returncode == 0) != success:
        raise AssertionError(f"command had unexpected status {result.returncode}: {args}\n{result.stdout}")
    return result.stdout


def main():
    with tempfile.TemporaryDirectory(prefix="er-release-test-") as temp:
        worktree = Path(temp) / "checkout"
        run("git", "-C", str(ROOT), "worktree", "add", "--detach", str(worktree), "HEAD")
        try:
            tool = worktree / "tools/build-release.sh"
            run("bash", str(tool), VERSION, cwd=worktree)
            run("bash", str(tool), VERSION, "--check", cwd=worktree)
            dist = worktree / "dist"
            for skill in ("engineering-rules", "engineering-rules-ar"):
                archive_path = dist / f"{skill}-{VERSION}.zip"
                with zipfile.ZipFile(archive_path) as archive:
                    names = set(archive.namelist())
                    assert f"{skill}/LICENSE" in names
                    manifest = json.loads(archive.read(f"{skill}/RELEASE.json"))
                    assert manifest["skill"] == skill and manifest["version"] == VERSION
                    assert manifest["commit"] == run("git", "-C", str(worktree), "rev-parse", "HEAD").strip()
                    assert f"{skill}/templates/CODEOWNERS" in names
                    assert f"{skill}/templates/agents/cursor-rule.mdc" in names
            checksums = (dist / "SHA256SUMS").read_text(encoding="utf-8").splitlines()
            assert len(checksums) == 2
            for row in checksums:
                expected, name = row.split("  ", 1)
                assert hashlib.sha256((dist / name).read_bytes()).hexdigest() == expected

            (dist / "surprise.txt").write_text("not part of this release\n", encoding="utf-8")
            run("bash", str(tool), VERSION, "--check", cwd=worktree, success=False)
            (dist / "surprise.txt").unlink()

            (worktree / "skills/engineering-rules/.release-test-untracked").write_text("x", encoding="utf-8")
            run("bash", str(tool), VERSION, "--check", cwd=worktree, success=False)
            (worktree / "skills/engineering-rules/.release-test-untracked").unlink()
            run("bash", str(tool), "01.1.0", cwd=worktree, success=False)
        finally:
            run("git", "-C", str(ROOT), "worktree", "remove", "--force", str(worktree))
    print("release package build, contents, checksums, extra-file rejection, dirty-input rejection and SemVer checks passed")


if __name__ == "__main__":
    main()
