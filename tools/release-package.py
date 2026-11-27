#!/usr/bin/env python3
"""Build/verify two skill-only ZIPs from allowlisted regular Git blobs.

No working-tree content is packaged. LICENSE and RELEASE.json are added to each
skill. The manifest records the source commit; SHA256SUMS is integrity, not a
signature. Local inputs must nevertheless be clean to avoid misleading builds.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import stat
import subprocess
import sys
import tempfile
import zipfile

SKILLS = ("engineering-rules", "engineering-rules-ar")
METADATA = ("LICENSE", ".claude-plugin/plugin.json", ".claude-plugin/marketplace.json", "CITATION.cff")
# Deliberate source inventory: new directories/file types require review here.
ROOT_FILES = {"SKILL.md", "VERSION", "AGENTS.md", "CLAUDE.md", "GEMINI.md", "CODEX.md", ".cursorrules", ".windsurfrules"}
SOURCE_DIRS = {"scripts", "references", "templates", "assets"}
SOURCE_SUFFIXES = {".md", ".sh", ".mjs", ".cjs", ".json", ".jsonc", ".yml", ".yaml", ".toml", ".env", ".txt", ".png", ".svg", ".mdc", ".props", ".example", ".dist", ".ini"}
SOURCE_NAMES = {"CODEOWNERS", ".npmrc", ".golangci.yml", ".jscpd.json", ".rubocop.yml"}
TRANSLATED_NON_MARKDOWN = {"templates/agents/cursor-rule.mdc"}
SEMVER = re.compile(r"(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(?:-([0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*))?(?:\+([0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*))?", re.ASCII)


def frontmatter(data):
    if not data.startswith(b"---\n"):
        return None
    end = data.find(b"\n---\n", 4)
    return None if end < 0 else data[:end + 5]


def version_value(value):
    value = value[1:] if value.startswith("v") else value
    match = SEMVER.fullmatch(value)
    if not match or (match[4] and any(p.isdigit() and len(p) > 1 and p[0] == "0" for p in match[4].split("."))):
        raise ValueError("version must be strict SemVer (optional single v prefix)")
    return value


def git(root, *args):
    return subprocess.check_output(["git", "-C", str(root), *args], stderr=subprocess.PIPE)


def allow_skill_path(path):
    parts = PurePosixPath(path).parts
    if len(parts) < 3 or parts[0] != "skills" or parts[1] not in SKILLS:
        return False
    rel = parts[2:]
    if any(p in {".", ".."} or "\\" in p or any(ord(c) < 32 for c in p) for p in rel):
        return False
    if len(rel) == 1:
        return rel[0] in ROOT_FILES
    hidden_names = {".github", ".npmrc", ".golangci.yml", ".jscpd.json", ".rubocop.yml"}
    return rel[0] in SOURCE_DIRS and (PurePosixPath(path).suffix in SOURCE_SUFFIXES or rel[-1] in SOURCE_NAMES) and not any(
        p.startswith(".") and p not in hidden_names for p in rel
    )


def regular_local(root, path):
    current = root
    parts = PurePosixPath(path).parts
    for index, part in enumerate(parts):
        current = current / part
        mode = current.lstat().st_mode
        if index == len(parts) - 1:
            if not stat.S_ISREG(mode):
                raise ValueError(f"input is not a regular file: {path}")
        elif not stat.S_ISDIR(mode):
            raise ValueError(f"input parent is not a real directory: {path}")


def snapshot(root, commit, version):
    head = git(root, "rev-parse", "HEAD").decode().strip()
    if not re.fullmatch(r"[0-9a-f]{40}", commit) or commit != head:
        raise ValueError("--commit must be the full current HEAD commit SHA")
    if git(root, "status", "--porcelain=v1", "--untracked-files=no"):
        raise ValueError("tracked working tree/index is dirty")
    untracked = git(root, "ls-files", "--others", "--exclude-standard", "-z")
    if untracked:
        raise ValueError("untracked files are not release inputs")
    ignored = git(root, "ls-files", "--others", "--ignored", "--exclude-standard", "-z", "--", "skills", *METADATA)
    if ignored:
        raise ValueError("ignored local files exist in release inputs")
    blobs = {}
    for record in git(root, "ls-tree", "-r", "-z", commit).split(b"\0"):
        if not record:
            continue
        header, name = record.split(b"\t", 1)
        path = name.decode("utf-8")
        if path not in METADATA and not any(path.startswith(f"skills/{skill}/") for skill in SKILLS):
            continue
        mode, kind, oid = header.decode().split()
        if mode not in {"100644", "100755"} or kind != "blob":
            raise ValueError(f"non-regular Git entry rejected: {path}")
        if path not in METADATA and not allow_skill_path(path):
            raise ValueError(f"path is outside the release allowlist: {path}")
        regular_local(root, path)
        blobs[path] = (int(mode, 8), git(root, "cat-file", "blob", oid))
    for path in METADATA + tuple(f"skills/{s}/{f}" for s in SKILLS for f in ("VERSION", "SKILL.md")):
        if path not in blobs:
            raise ValueError(f"required release input missing: {path}")
    plugin = json.loads(blobs[".claude-plugin/plugin.json"][1])
    market = json.loads(blobs[".claude-plugin/marketplace.json"][1])
    entries = [p for p in market["plugins"] if p.get("name") == "engineering-rules"]
    if len(entries) != 1 or plugin.get("name") != "engineering-rules" or entries[0].get("source") != "./":
        raise ValueError("plugin identity/source mismatch")
    citation = re.findall(r"^version: *([^\r\n]+)$", blobs["CITATION.cff"][1].decode(), re.MULTILINE)
    versions = [plugin.get("version"), entries[0].get("version"), *(citation or [None])]
    versions += [blobs[f"skills/{s}/VERSION"][1].decode().strip() for s in SKILLS]
    if len(citation) != 1 or any(v != version for v in versions):
        raise ValueError("tag/version disagrees with plugin, marketplace, CITATION or skill VERSION")
    for v in versions:
        version_value(v)
    # Non-Markdown mirrors remain a required gate, except this explicitly
    # localized Cursor rule. Its machine-readable frontmatter must still match.
    en = {p.split("/", 2)[2]: data for p, (_, data) in blobs.items() if p.startswith("skills/engineering-rules/") and not p.endswith(".md") and p.split("/", 2)[2] not in TRANSLATED_NON_MARKDOWN}
    ar = {p.split("/", 2)[2]: data for p, (_, data) in blobs.items() if p.startswith("skills/engineering-rules-ar/") and not p.endswith(".md") and p.split("/", 2)[2] not in TRANSLATED_NON_MARKDOWN}
    if en != ar:
        raise ValueError("non-Markdown English/Arabic release inputs differ")
    for rel in TRANSLATED_NON_MARKDOWN:
        en_path, ar_path = f"skills/engineering-rules/{rel}", f"skills/engineering-rules-ar/{rel}"
        en_frontmatter = frontmatter(blobs[en_path][1]) if en_path in blobs else None
        ar_frontmatter = frontmatter(blobs[ar_path][1]) if ar_path in blobs else None
        if en_frontmatter is None or ar_frontmatter is None or en_frontmatter != ar_frontmatter:
            raise ValueError(f"translated asset is missing or has different frontmatter: {rel}")
    return blobs


def expected_members(blobs, skill, commit, version):
    prefix = f"skills/{skill}/"
    members = {p[len("skills/"):]: item for p, item in blobs.items() if p.startswith(prefix)}
    members[f"{skill}/LICENSE"] = blobs["LICENSE"]
    manifest = {"schema": 1, "kind": "skill", "skill": skill, "version": version, "commit": commit}
    members[f"{skill}/RELEASE.json"] = (0o100644, (json.dumps(manifest, sort_keys=True, indent=2) + "\n").encode())
    return members


def artifact_names(version):
    return {f"{s}-{version}.zip" for s in SKILLS} | {"SHA256SUMS"}


def validate_artifacts(dist, blobs, commit, version):
    if not stat.S_ISDIR(dist.lstat().st_mode):
        raise ValueError("dist must be a real directory")
    if {p.name for p in dist.iterdir()} != artifact_names(version):
        raise ValueError("unexpected/missing release artifacts")
    sums = []
    for skill in SKILLS:
        name = f"{skill}-{version}.zip"
        path = dist / name
        if not stat.S_ISREG(path.lstat().st_mode):
            raise ValueError("artifact is not a regular file")
        expected = expected_members(blobs, skill, commit, version)
        with zipfile.ZipFile(path) as archive:
            infos = archive.infolist()
            if len(infos) != len(expected) or {i.filename for i in infos} != set(expected):
                raise ValueError("archive inventory mismatch")
            for info in infos:
                mode, data = expected[info.filename]
                if info.file_size != len(data) or info.create_system != 3 or info.external_attr >> 16 != mode or archive.read(info) != data:
                    raise ValueError(f"archive content/mode mismatch: {info.filename}")
        sums.append(f"{hashlib.sha256(path.read_bytes()).hexdigest()}  {name}\n")
    checksum = dist / "SHA256SUMS"
    if not stat.S_ISREG(checksum.lstat().st_mode) or checksum.read_text() != "".join(sums):
        raise ValueError("SHA256SUMS mismatch")


def build(root, blobs, commit, version):
    dist = root / "dist"
    # Never remove/follow an arbitrary existing output directory.
    if os.path.lexists(dist):
        raise ValueError("dist already exists; inspect/remove it explicitly before building")
    with tempfile.TemporaryDirectory(prefix="er-release-", dir=root) as temporary:
        staged = Path(temporary) / "dist"
        staged.mkdir()
        sums = []
        for skill in SKILLS:
            name = f"{skill}-{version}.zip"
            with zipfile.ZipFile(staged / name, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
                for path, (mode, data) in sorted(expected_members(blobs, skill, commit, version).items()):
                    info = zipfile.ZipInfo(path, (1980, 1, 1, 0, 0, 0))
                    info.create_system = 3
                    info.external_attr = mode << 16
                    info.compress_type = zipfile.ZIP_DEFLATED
                    archive.writestr(info, data)
            sums.append(f"{hashlib.sha256((staged / name).read_bytes()).hexdigest()}  {name}\n")
        (staged / "SHA256SUMS").write_text("".join(sums))
        validate_artifacts(staged, blobs, commit, version)
        staged.rename(dist)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("version")
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--commit")
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    try:
        version = version_value(args.version)
        root = args.root.resolve()
        commit = args.commit or git(root, "rev-parse", "HEAD").decode().strip()
        blobs = snapshot(root, commit, version)
        if args.check:
            validate_artifacts(root / "dist", blobs, commit, version)
        else:
            build(root, blobs, commit, version)
        print(f"release artifacts {'verified' if args.check else 'built'}: {version} @ {commit}")
    except (ValueError, OSError, subprocess.CalledProcessError, KeyError, TypeError, zipfile.BadZipFile) as error:
        print(f"release refused: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
