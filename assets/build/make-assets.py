#!/usr/bin/env python3
"""Builds the README images (SVG, plus a PNG social preview) with no dependencies.
Run:  python3 assets/build/make-assets.py   (PNG needs rsvg-convert on PATH)

The two terminal images show the REAL output of `examples/shop-api/run-demo.sh`
(saved in examples/shop-api/output-*.txt); the reasons below are copied from it.
"""
import html, json, pathlib, shutil, subprocess

OUT = pathlib.Path(__file__).resolve().parent.parent
FONT = "ui-monospace,SFMono-Regular,Menlo,Consolas,'Liberation Mono',monospace"
SANS = "-apple-system,Segoe UI,Helvetica,Arial,sans-serif"
BG, FG, DIM, RED, GREEN, YELLOW, BLUE = "#0d1117", "#e6edf3", "#8b949e", "#ff7b72", "#3fb950", "#d29922", "#79c0ff"


def esc(s):
    return html.escape(s, quote=False)


def terminal(name, title, lines, width=1000):
    line_h, pad_top = 24, 64
    height = pad_top + line_h * len(lines) + 28
    parts = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}" role="img" aria-label="{esc(title)}">',
             f'<rect width="{width}" height="{height}" rx="12" fill="{BG}" stroke="#30363d"/>',
             '<circle cx="24" cy="24" r="6" fill="#ff5f56"/><circle cx="44" cy="24" r="6" fill="#ffbd2e"/><circle cx="64" cy="24" r="6" fill="#27c93f"/>',
             f'<text x="{width/2}" y="29" fill="{DIM}" font-family="{SANS}" font-size="13" text-anchor="middle">{esc(title)}</text>']
    y = pad_top
    for segs in lines:
        x = 24
        parts.append(f'<text y="{y}" font-family="{FONT}" font-size="14" xml:space="preserve">')
        for text, color in segs:
            parts.append(f'<tspan x="{x}" fill="{color}">{esc(text)}</tspan>')
            x += 8.45 * len(text)
        parts.append("</text>")
        y += line_h
    parts.append("</svg>")
    (OUT / name).write_text("\n".join(parts), encoding="utf-8")


def row(gate, status, detail=""):
    color = {"PASS": GREEN, "FAIL": RED}.get(status, YELLOW)
    return [(f"{gate:<17}", FG), (f"{status:<6}", color), (detail, DIM)]


prompt = [("$ ", GREEN), ('bash .github/scripts/local-proof.sh --title "feat: checkout"', FG)]
before = [prompt, [("", FG)],
          row("Secret scan", "FAIL", "tracked .env file (rule: project-dotenv-file)"),
          row("docs-check", "FAIL", "src/ changed with no docs or CHANGELOG entry"),
          row("Policy gates", "FAIL", 'hard-coded currency "USD" and time zone "Europe/Berlin"'),
          row("Flag expiry", "PASS"),
          row("PR size", "FAIL", "1331 changed lines, limit is 800"),
          row("Stack gates", "FAIL", "test failed (tax rate)"),
          row("Renovate config", "PASS"), [("", FG)],
          [("5 gates failed. ", RED), ("Nothing merged. The secret never reached main.", DIM)]]
after = [prompt, [("", FG)],
         row("Secret scan", "PASS"), row("docs-check", "PASS"), row("Policy gates", "PASS"),
         row("Flag expiry", "PASS"), row("PR size", "PASS"), row("Stack gates", "PASS"),
         row("Renovate config", "PASS"), [("", FG)],
         [("All gates passed. ", GREEN), ("Paste this proof into the pull request.", DIM)]]
terminal("demo-before.svg", "BEFORE: a typical fast pull request", before)
terminal("demo-after.svg", "AFTER: the same feature, done to the rules", after)

def cast():
    """Writes assets/demo.cast (asciicast v2) from the saved real output of the demo, with typing delays."""
    ex = OUT.parent / "examples" / "shop-api"
    events, t = [], 0.4
    def out(text, dt):
        nonlocal t
        t += dt
        events.append([round(t, 3), "o", text])
    for title, name in (("BEFORE: a typical fast pull request", "output-before.txt"), ("AFTER: the same feature, done to the rules", "output-after.txt")):
        out(f"\x1b[1m# {title}\x1b[0m\r\n", 0.6)
        for ch in "bash .github/scripts/local-proof.sh --title 'feat: checkout'":
            out(ch, 0.035)
        out("\r\n", 0.5)
        lines = [l for l in (ex / name).read_text().splitlines() if l.startswith("|") and "---" not in l and "Gate" not in l]
        for l in lines:
            cells = [c.strip() for c in l.strip("|").split("|")]
            status = cells[2].replace("**", "")
            color = "\x1b[32m" if status.startswith("PASS") else "\x1b[31m"
            out(f"{cells[0]:<17}{color}{status}\x1b[0m\r\n", 0.45)
        out("\r\n", 1.6)
    header = {"version": 2, "width": 100, "height": 24, "timestamp": 1760000000, "title": "engineering-rules: before and after", "env": {"SHELL": "/bin/bash", "TERM": "xterm-256color"}}
    (OUT / "demo.cast").write_text(json.dumps(header) + "\n" + "\n".join(json.dumps(e) for e in events) + "\n", encoding="utf-8")


CHIPS = ["Node", "Next.js", "React", "React Native", "Vue", "Angular", ".NET", "Laravel", "Flutter", "Python", "Java", "Go", "Rust", "Ruby"]


def banner(name, w, h, big):
    t1, t2, t3 = (64, 40, 22) if big else (46, 28, 17)
    s = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}" role="img" aria-label="engineering-rules: guardrails for fast and AI-written code">',
         '<defs><linearGradient id="g" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#0d1117"/><stop offset="1" stop-color="#161b22"/></linearGradient>'
         '<linearGradient id="a" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#3fb950"/><stop offset="1" stop-color="#79c0ff"/></linearGradient></defs>',
         f'<rect width="{w}" height="{h}" fill="url(#g)"/>',
         f'<rect x="0" y="0" width="{w}" height="6" fill="url(#a)"/>']
    x0 = 64 if big else 48
    y = h * (0.30 if big else 0.34)
    s.append(f'<text x="{x0}" y="{y}" font-family="{SANS}" font-size="{t1}" font-weight="700" fill="{FG}">engineering-rules</text>')
    s.append(f'<text x="{x0}" y="{y + t2*1.5}" font-family="{SANS}" font-size="{t2}" fill="url(#a)" font-weight="600">Guardrails for fast (and AI-written) code.</text>')
    s.append(f'<text x="{x0}" y="{y + t2*1.5 + t3*2.1}" font-family="{SANS}" font-size="{t3}" fill="{DIM}">One command. Any stack. Proof in every pull request, with or without paid CI.</text>')
    cx, cy = x0, h - (118 if big else 70)
    cw = (w - 2 * x0)
    line = 0
    x = cx
    for chip in CHIPS:
        tw = len(chip) * (t3 * 0.62) + 28
        if x + tw > cx + cw:
            line += 1
            x = cx
        yy = cy + line * (t3 * 2.0)
        s.append(f'<rect x="{x}" y="{yy}" width="{tw}" height="{t3*1.7}" rx="{t3*0.85}" fill="#21262d" stroke="#30363d"/>')
        s.append(f'<text x="{x + tw/2}" y="{yy + t3*1.18}" font-family="{SANS}" font-size="{t3*0.8}" fill="{FG}" text-anchor="middle">{esc(chip)}</text>')
        x += tw + 10
    s.append("</svg>")
    (OUT / name).write_text("\n".join(s), encoding="utf-8")


cast()
banner("banner.svg", 1280, 340, False)
banner("social-preview.svg", 1280, 640, True)
if shutil.which("rsvg-convert"):
    subprocess.run(["rsvg-convert", "-w", "1280", "-h", "640", str(OUT / "social-preview.svg"), "-o", str(OUT / "social-preview.png")], check=True)
    print("wrote social-preview.png")
print("assets written to", OUT)
