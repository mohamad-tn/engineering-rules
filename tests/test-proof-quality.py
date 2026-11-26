#!/usr/bin/env python3
"""Partial-proof aggregation regressions, with explicitly stubbed gate commands."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "skills/engineering-rules/scripts"
failed = 0
passed = 0
with tempfile.TemporaryDirectory(prefix="er-proof-quality-") as temporary:
    root = Path(temporary)
    home = root / "home"
    home.mkdir()
    repo = root / "repo"
    repo.mkdir()
    env = {key: os.environ[key] for key in ("PATH", "SYSTEMROOT", "WINDIR", "COMSPEC", "PATHEXT") if key in os.environ}
    env.update(HOME=str(home), LANG="C.UTF-8", GIT_CONFIG_NOSYSTEM="1", GIT_CONFIG_GLOBAL=os.devnull)

    def run(args):
        return subprocess.run(args, cwd=repo, env=env, text=True, stdout=subprocess.PIPE,
                              stderr=subprocess.PIPE, timeout=30)

    def check(name, condition, result):
        global failed, passed
        if condition:
            passed += 1
            print("  PASS  " + name)
        else:
            failed += 1
            print("  FAIL  " + name + "\n" + result.stdout + "\n" + result.stderr)

    scripts = repo / ".github/scripts"
    scripts.mkdir(parents=True)
    for name in ("local-proof.sh", "load-env.sh"):
        shutil.copyfile(SOURCE / name, scripts / name)
    # These fixtures deliberately exercise only aggregation, never secret or SDK detection.
    for name in ("gitleaks-scan.sh", "docs-check.sh", "pr-size-check.sh"):
        (scripts / name).write_text("#!/usr/bin/env bash\nexit 0\n")
    (scripts / "ensure-tool.sh").write_text("#!/usr/bin/env bash\nprintf 'fixture-tool\\n'\n")
    for name in ("policy-gates.mjs", "feature-flag-expiry.mjs"):
        (scripts / name).write_text("// Explicit passing aggregation fixture.\n")
    (scripts / "stack-gates.sh").write_text("#!/usr/bin/env bash\nfor arg in \"$@\"; do [[ \"$arg\" == --fast ]] && exit 0; done\nexit 1\n")
    for args in (["git", "init", "-q", "-b", "main"], ["git", "add", "."],
                 ["git", "-c", "user.name=Quality", "-c", "user.email=quality@example.invalid", "commit", "-q", "-m", "test: proof"]):
        result = run(args)
        if result.returncode:
            raise RuntimeError(result.stderr)
    sha = run(["git", "rev-parse", "HEAD"]).stdout.strip()
    command = ["bash", str(scripts / "local-proof.sh"), "--base", sha, "--json"]
    result = run(command)
    data = json.loads(result.stdout)
    check("full proof fails when the stack fails", result.returncode == 1 and not data["ok"] and not data["execution_ok"], result)
    result = run(command + ["--fast"])
    data = json.loads(result.stdout)
    check("fast success is incomplete, not passing proof", result.returncode == 0 and data["execution_ok"] and not data["ok"] and not data["proof_complete"] and data["stack_mode"] == "fast", result)
    result = run(command + ["--no-stack"])
    data = json.loads(result.stdout)
    check("no-stack is incomplete and fails by default", result.returncode == 1 and not data["ok"] and data["stack_mode"] == "skipped", result)
    result = run(command + ["--no-stack", "--allow-missing"])
    data = json.loads(result.stdout)
    check("allow-missing relaxes exit only, not proof", result.returncode == 0 and not data["ok"] and not data["proof_complete"], result)
print(f"proof regressions: passed {passed}, failed {failed}; gate commands explicitly stubbed")
raise SystemExit(1 if failed else 0)
