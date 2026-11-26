#!/usr/bin/env python3
"""Command-level quality regressions; these do not replace real SDK tests."""
import json
import os
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = ROOT / "skills/engineering-rules/scripts"
passed = 0
failed = 0


def check(name, condition, detail=""):
    global passed, failed
    if condition:
        passed += 1
        print("  PASS  " + name)
    else:
        failed += 1
        print("  FAIL  " + name + (": " + detail if detail else ""))


with tempfile.TemporaryDirectory(prefix="er-quality-") as temporary:
    work = Path(temporary)
    home = work / "home"
    home.mkdir()
    env = {key: os.environ[key] for key in ("PATH", "SYSTEMROOT", "WINDIR", "COMSPEC", "PATHEXT") if key in os.environ}
    env.update(HOME=str(home), LANG="C.UTF-8", GIT_CONFIG_NOSYSTEM="1", GIT_CONFIG_GLOBAL=os.devnull)
    binaries = work / "bin"
    binaries.mkdir()

    def run(args, directory, values=None):
        current = dict(env)
        current.update(values or {})
        return subprocess.run(args, cwd=directory, env=current, text=True,
                              stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=90)

    def fake(name, body):
        path = binaries / name
        path.write_text("#!/usr/bin/env bash\n" + body + "\n", encoding="utf-8")
        path.chmod(0o755)
        return {"PATH": str(binaries) + os.pathsep + env["PATH"]}

    def repo(name):
        directory = work / name
        directory.mkdir()
        result = run(["git", "init", "-q", "-b", "main"], directory)
        if result.returncode:
            raise RuntimeError(result.stdout)
        return directory

    go = work / "go-check"
    go.mkdir()
    (go / "go.mod").write_text("module example.invalid/quality\n\ngo 1.22\n")
    original = (go / "go.mod").read_bytes()
    values = fake("go", "exit 7")
    result = run(["bash", str(SCRIPTS / "stacks/tools/go-tidy-check.sh")], go, values)
    check("Go tidy failure is not a pass", result.returncode == 7, result.stdout)
    check("Go tidy failure preserves go.mod", (go / "go.mod").read_bytes() == original)
    values = fake("go", "printf '# changed\\n' >>go.mod; exit 0")
    result = run(["bash", str(SCRIPTS / "stacks/tools/go-tidy-check.sh")], go, values)
    check("Go tidy change fails and is restored", result.returncode == 1 and (go / "go.mod").read_bytes() == original, result.stdout)
    values = fake("go", "exit 0")
    result = run(["bash", str(SCRIPTS / "stacks/tools/go-tidy-check.sh")], go, values)
    check("Go tidy unchanged success passes", result.returncode == 0, result.stdout)

    for name, body, expected in [
        ("partial failure", "echo 'Project A has no vulnerable packages'; echo 'error: missing assets for B'; exit 1", 1),
        ("clean success", "echo 'Project A has no vulnerable packages'; exit 0", 0),
        ("vulnerable success code", "echo 'has the following vulnerable packages'; exit 0", 1),
        ("undetermined output", "echo 'unknown output'; exit 0", 1),
        ("network plus success sentence", "echo 'Project A has no vulnerable packages'; echo 'Unable to load the service index'; exit 0", 1),
    ]:
        values = fake("dotnet", body)
        result = run(["bash", str(SCRIPTS / "stacks/tools/dotnet-vuln-check.sh"), "Demo.sln"], work, values)
        check(".NET audit " + name, result.returncode == expected, result.stdout)

    for script in ("stack-gates.sh", "doctor.sh"):
        result = run(["bash", str(SCRIPTS / script)] + (["--root", str(work / "missing"), "--list"] if script == "stack-gates.sh" else [str(work / "missing")]), work)
        check(script + " rejects inaccessible roots", result.returncode == 2, result.stdout)

    mapped = repo("mapped")
    result = run(["bash", str(SCRIPTS / "stack-gates.sh"), "--root", str(mapped), "--dirs", "unknown:.", "--list"], work)
    check("unknown mapped engine is rejected", result.returncode == 2, result.stdout)
    result = run(["bash", str(SCRIPTS / "stack-gates.sh"), "--root", str(mapped), "--dirs", "node:..", "--list"], work)
    check("mapped directory outside root is rejected", result.returncode == 2, result.stdout)

    node = repo("client's app")
    manifest = {"name": "quality", "version": "1.0.0", "private": True}
    (node / "package.json").write_text(json.dumps(manifest))
    (node / "package-lock.json").write_text(json.dumps({"name": "quality", "version": "1.0.0", "lockfileVersion": 3, "requires": True, "packages": {"": manifest}}))
    result = run(["bash", str(SCRIPTS / "stack-gates.sh"), "--root", str(node), "--only", "deps"], work)
    check("Node install supports apostrophes and spaces", result.returncode == 0, result.stdout)
    result = run(["bash", str(SCRIPTS / "stack-gates.sh"), "--root", str(node), "--only", "not-a-real-gate"], work)
    check("required gate without any result fails", result.returncode == 1 and "no gate result recorded" in result.stdout, result.stdout)
    (node / "pnpm-lock.yaml").write_text("lockfileVersion: '9.0'\n")
    result = run(["bash", str(SCRIPTS / "stack-gates.sh"), "--root", str(node), "--only", "deps"], work)
    check("same-project competing lockfiles fail", result.returncode == 1 and "multiple lockfiles" in result.stdout, result.stdout)
    (node / "pnpm-lock.yaml").unlink()

    parent = repo("independent-projects")
    (parent / "pnpm-lock.yaml").write_text("lockfileVersion: '9.0'\n")
    child = parent / "child"
    child.mkdir()
    (child / "package.json").write_bytes((node / "package.json").read_bytes())
    (child / "package-lock.json").write_bytes((node / "package-lock.json").read_bytes())
    result = run(["bash", str(SCRIPTS / "stack-gates.sh"), "--root", str(parent), "--only", "deps"], work)
    check("independent child does not inherit parent's lock conflict", result.returncode == 0, result.stdout)

    library = repo("library")
    (library / "package.json").write_text(json.dumps({"name": "quality-library", "version": "1.0.0", "main": "index.js"}))
    result = run(["bash", str(SCRIPTS / "stack-gates.sh"), "--root", str(library), "--only", "deps"], work)
    check("lockless library installs in its own directory", result.returncode == 0, result.stdout)

    proof = repo("proof")
    (proof / "README.md").write_text("# Quality\n")
    run(["git", "add", "README.md"], proof)
    result = run(["git", "-c", "user.name=Quality", "-c", "user.email=quality@example.invalid", "commit", "-q", "-m", "test: quality"], proof)
    if result.returncode:
        raise RuntimeError(result.stdout)
    head = run(["git", "rev-parse", "HEAD"], proof).stdout.strip()
    (proof / "untracked.js").write_text("export const value = 1;\n")
    result = run(["bash", str(SCRIPTS / "local-proof.sh"), "--base", head], proof)
    check("local proof rejects untracked source before gates", result.returncode == 2 and "untracked changes" in result.stdout, result.stdout)

    check("CTest command rejects an empty test set", "--no-tests=error" in (SCRIPTS / "stacks/cpp.sh").read_text())
    check("uv checks lock consistency", "uv sync --locked" in (SCRIPTS / "stacks/python.sh").read_text())

print(f"quality regressions: passed {passed}, failed {failed}; command-level tests, not full SDK coverage")
raise SystemExit(1 if failed else 0)
