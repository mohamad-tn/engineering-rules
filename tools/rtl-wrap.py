#!/usr/bin/env python3
"""Makes Arabic Markdown files render right-to-left on GitHub.

    python3 tools/rtl-wrap.py <file-or-dir> [...]

For each .md file (not .mdc, and not files that start with a tool-facing
frontmatter that must stay first) it:
  * keeps a leading YAML frontmatter block untouched,
  * wraps the body in <div dir="rtl"> ... </div>,
  * wraps every fenced code block in <div dir="ltr"> ... </div> so commands and
    code stay left-to-right and readable.
It is idempotent: a file that already carries the marker is skipped. After editing a wrapped
file run it with --rewrap (python3 tools/rtl-wrap.py --rewrap <paths>) to wrap it again.
Files listed in SKIP_NAMES are AI-facing bridge files and are left unwrapped.
"""
import pathlib
import sys

MARK = "<!-- rtl -->"
SKIP_NAMES = {"CLAUDE.md", "GEMINI.md", "copilot-instructions.md", "windsurf-rule.md"}


def wrap(text: str) -> str:
    if MARK in text:
        return text
    lines = text.split("\n")
    head, body = [], lines
    if lines and lines[0].strip() == "---":
        for i in range(1, len(lines)):
            if lines[i].strip() == "---":
                head, body = lines[: i + 1], lines[i + 1 :]
                break
    out, in_fence = [], False
    for line in body:
        if line.lstrip().startswith("```"):
            if not in_fence:
                out += ['<div dir="ltr">', "", line]
                in_fence = True
            else:
                out += [line, "", "</div>"]
                in_fence = False
        else:
            out.append(line)
    while out and out[0] == "":
        out.pop(0)
    while out and out[-1] == "":
        out.pop()
    result = head + ([""] if head else []) + [MARK, '<div dir="rtl">', ""] + out + ["", "</div>", ""]
    return "\n".join(result)


def unwrap(text: str) -> str:
    """Inverse of wrap(): used by --rewrap after you edit an already wrapped file."""
    if MARK not in text:
        return text
    text = text.replace('<div dir="ltr">\n\n```', "```").replace("```\n\n</div>", "```")
    text = text.replace(MARK + '\n<div dir="rtl">\n\n', "")
    text = text.rstrip("\n")
    if text.endswith("\n\n</div>"):
        text = text[: -len("\n\n</div>")]
    return text + "\n"


def main(paths):
    rewrap = "--rewrap" in paths
    paths = [p for p in paths if p != "--rewrap"]
    changed = 0
    for p in map(pathlib.Path, paths):
        files = [p] if p.is_file() else sorted(p.rglob("*.md"))
        for f in files:
            if f.suffix != ".md" or f.name in SKIP_NAMES:
                continue
            old = f.read_text(encoding="utf-8")
            new = wrap(unwrap(old) if rewrap else old)
            if new != old:
                f.write_text(new, encoding="utf-8")
                changed += 1
    print(f"wrapped {changed} file(s)")


if __name__ == "__main__":
    main(sys.argv[1:] or ["."])
