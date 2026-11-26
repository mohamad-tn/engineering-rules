#!/usr/bin/env python3
"""Builds the static GitHub Pages site (English and Arabic) into site/.
    python3 tools/build-site.py           write the files
    python3 tools/build-site.py --check   exit 1 if the committed site is out of date
One self-contained HTML page per language: no external fonts, scripts or trackers.
Includes meta description, Open Graph / Twitter tags, hreflang, canonical URL and
JSON-LD (SoftwareSourceCode and FAQPage) so search engines and answer engines can read it.
Placeholders mohamad-tn and engineering-rules are filled by tools/publish-prep.sh.
"""
import html, json, pathlib, shutil, sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
SITE = ROOT / "site"
_cfg = {}
_cfg_path = ROOT / "tools" / "publish.json"
if _cfg_path.exists():
    _cfg = json.loads(_cfg_path.read_text(encoding="utf-8"))
OWNER = _cfg.get("owner", "mohamad-tn")
REPO_NAME = _cfg.get("repo", "engineering-rules")
BASE = f"https://{OWNER}.github.io/{REPO_NAME}"
REPO = f"https://github.com/{OWNER}/{REPO_NAME}"

STACKS = ["Node.js", "Next.js", "React", "React Native", "Vue", "Angular", "Svelte", "NestJS", ".NET", "Laravel", "Symfony", "Flutter",
          "Python", "Django", "FastAPI", "Java", "Spring Boot", "Go", "Rust", "Ruby", "Rails", "Swift", "C / C++", "Terraform", "Docker"]

T = {
 "en": dict(
  lang="en", dir="ltr", path="/", other="/ar/", other_label="العربية",
  title="engineering-rules: guardrails and real gates for fast and AI-written code",
  desc="One command adds small engineering rules and real gates (secret scan, docs, PR size, tests, build, audit) to any repo. Node, Next.js, Laravel, Flutter, .NET, Python, Go, Rust and more. No paid CI needed.",
  h1="Guardrails for fast code, and for code written by AI.",
  lead="One command adds a short rules file and real, automated gates to any repository. Every pull request carries proof that the checks passed, on GitHub Actions or on your laptop.",
  cta="View on GitHub", cta2="Read the guide", install_label="Install in 60 seconds",
  problem_h="The problem", problem_p="Writing code has never been faster. Reviewing it has not. These failures slip through:",
  problems=[("Committed secrets", "A .env file or key in git history turns rotation into an incident."),
            ("Configuration in code", "Currency, time zones and hosts typed into code need a release for every new market."),
            ("Giant pull requests", "1,300 changed lines are not reviewed; bugs ride along."),
            ("Docs that lie", "Code changes, documentation and changelog do not."),
            ("Unreproducible builds", "No lockfile, beta dependencies, builds that differ between machines."),
            ("Green that means nothing", "Skipped tests and gates that quietly did not run.")],
  how_h="How it works", how=[("Install", "Detects your stack and never overwrites a file.", "bash skills/engineering-rules/scripts/install.sh --target ./my-project"),
            ("Work in small tasks", "About one pull request per task, around 400 changed lines.", None),
            ("Prove it", "Runs every gate and prints a block you paste into the pull request.", "bash .github/scripts/local-proof.sh"),
            ("A human merges", "Assistants never merge. A gate that did not run is never a pass.", None)],
  demo_h="See it work", demo_p="The same feature, first as a fast pull request, then done to the rules. This is the real output of the included demo.",
  before_alt="Five gates fail on the first version", after_alt="All gates pass after the rewrite",
  stacks_h="Every stack, auto-detected", stacks_p="Install, format, lint, types, tests, build and audit for each stack, monorepos included.",
  agents_h="Works with any AI agent", agents_p="Claude Code, Cursor, Codex, GitHub Copilot, Gemini, Windsurf, or a human reviewer. The rules live in AGENTS.md; the installer adds small bridge files for each tool.",
  faq_h="Questions",
  faq=[("What is engineering-rules?", "A short rules file and a set of real, automated pull-request gates, packaged as an Agent Skill and a one-command installer. It works for any repository and stack."),
       ("Do I need paid CI?", "No. Every gate is a plain bash or Node script. Run local-proof.sh and paste its output into the pull request, or call the same scripts from GitHub Actions, GitLab, Bitbucket or Jenkins."),
       ("Does it work with AI coding assistants?", "Yes. Claude Code, Cursor, Codex, Copilot, Gemini and Windsurf read AGENTS.md or its bridge files. An agent can adopt it with one command and read machine-readable results with --json."),
       ("Which languages and frameworks are supported?", "Node.js, Next.js, React, React Native and Expo, Vue, Angular, Svelte, NestJS, .NET, Laravel and PHP, Flutter, Python and Django, Java and Spring, Go, Rust, Ruby and Rails, Swift, C and C++ with CMake, Terraform and OpenTofu, and Docker."),
       ("Can I adopt it in an existing, messy repository?", "Yes. Start with the lite profile: old markdown is not linted, old history can be scanned from the adoption commit, and a gate you switch off on purpose leaves the required list."),
       ("Is there an Arabic edition?", "Yes. A full Arabic edition of the skill, the README and the guides ships in the same repository.")],
  foot="MIT licensed. Plain bash and Node, no service, no tracking.",
 ),
 "ar": dict(
  lang="ar", dir="rtl", path="/ar/", other="/", other_label="English",
  title="قواعد الهندسة (engineering-rules): حواجز أمان وبوابات حقيقية للكود السريع وكود الذكاء الاصطناعي",
  desc="أمر واحد يضيف قواعد هندسة صغيرة وبوابات حقيقية (فحص الأسرار والوثائق وحجم الطلب والاختبارات والبناء والتدقيق) لأي مستودع. Node وNext.js وLaravel وFlutter و.NET وPython وGo وRust وغيرها. بلا CI مدفوع.",
  h1="حواجز أمان للكود السريع، وللكود الذي يكتبه الذكاء الاصطناعي.",
  lead="أمر واحد يضيف إلى أي مستودع ملف قواعد قصيرًا وبوابات آلية حقيقية. وكل طلب دمج يحمل إثباتًا أن الفحوص نجحت، على GitHub Actions أو على جهازك.",
  cta="افتح على GitHub", cta2="اقرأ الدليل", install_label="التثبيت في 60 ثانية",
  problem_h="المشكلة", problem_p="كتابة الكود لم تكن يومًا أسرع، لكن مراجعته لم تتسارع. وهذه الأخطاء تمر:",
  problems=[("أسرار مرفوعة", "ملف .env أو مفتاح في تاريخ Git يحوّل تغيير المفتاح إلى حادثة."),
            ("إعدادات داخل الكود", "العملة والمناطق الزمنية والمضيفات المكتوبة في الكود تحتاج إصدارًا لكل سوق جديد."),
            ("طلبات دمج ضخمة", "1300 سطر معدّل لا يراجعها أحد جيدًا، فتمر الأخطاء معها."),
            ("وثائق كاذبة", "يتغير الكود ولا تتغير الوثائق ولا سجل التغييرات."),
            ("بناء لا يمكن إعادة إنتاجه", "لا ملف قفل، واعتمادات تجريبية، وبنيات تختلف بين الأجهزة."),
            ("أخضر بلا معنى", "اختبارات متخطاة وبوابات لم تعمل بصمت.")],
  how_h="كيف يعمل", how=[("ثبّت", "يكتشف تقنيتك ولا يكتب فوق أي ملف.", "bash skills/engineering-rules-ar/scripts/install.sh --target ./my-project"),
            ("اعمل بمهام صغيرة", "طلب دمج واحد تقريبًا لكل مهمة، بحدود 400 سطر معدّل.", None),
            ("أثبت", "يشغّل كل بوابة ويطبع كتلة تلصقها في طلب الدمج.", "bash .github/scripts/local-proof.sh"),
            ("الإنسان يدمج", "المساعدون لا يدمجون أبدًا. والبوابة التي لم تعمل ليست نجاحًا.", None)],
  demo_h="شاهده يعمل", demo_p="الميزة نفسها، أولًا كطلب دمج سريع، ثم مكتوبة وفق القواعد. هذه المخرجات الحقيقية للعرض المرفق.",
  before_alt="خمس بوابات تفشل في النسخة الأولى", after_alt="كل البوابات تنجح بعد إعادة الكتابة",
  stacks_h="كل تقنية، تُكتشف تلقائيًا", stacks_p="التثبيت والتنسيق وفحص الكود والأنواع والاختبارات والبناء والتدقيق لكل تقنية، حتى المستودعات الكبيرة المتعددة المشاريع.",
  agents_h="يعمل مع أي وكيل ذكاء اصطناعي", agents_p="Claude Code وCursor وCodex وGitHub Copilot وGemini وWindsurf، أو مراجع بشري. القواعد في AGENTS.md، والمثبّت يضيف ملفات ربط صغيرة لكل أداة.",
  faq_h="أسئلة",
  faq=[("ما هو engineering-rules؟", "ملف قواعد قصير ومجموعة بوابات آلية حقيقية لطلبات الدمج، مغلّفة كمهارة وكيل (Agent Skill) ومثبّت بأمر واحد. تعمل مع أي مستودع وأي تقنية."),
       ("هل أحتاج CI مدفوعًا؟", "لا. كل بوابة سكربت bash أو Node عادي. شغّل local-proof.sh والصق مخرجاته في طلب الدمج، أو استدعِ السكربتات نفسها من GitHub Actions أو GitLab أو Bitbucket أو Jenkins."),
       ("هل يعمل مع مساعدي البرمجة بالذكاء الاصطناعي؟", "نعم. Claude Code وCursor وCodex وCopilot وGemini وWindsurf تقرأ AGENTS.md أو ملفات الربط. ويستطيع الوكيل تبنّيه بأمر واحد وقراءة النتائج الآلية بالخيار --json."),
       ("ما اللغات والأطر المدعومة؟", "Node.js وNext.js وReact وReact Native وExpo وVue وAngular وSvelte وNestJS و.NET وLaravel وPHP وFlutter وPython وDjango وJava وSpring وGo وRust وRuby وRails وSwift وC وC++ مع CMake وTerraform وOpenTofu وDocker."),
       ("هل أستطيع تبنّيه في مستودع قائم فوضوي؟", "نعم. ابدأ بالنمط lite: لا يُفحص Markdown القديم، ويمكن فحص التاريخ من commit التبنّي، والبوابة التي تعطّلها عن قصد تخرج من قائمة المطلوب."),
       ("هل توجد نسخة عربية؟", "نعم. نسخة عربية كاملة من المهارة وملف README والأدلة في المستودع نفسه.")],
  foot="رخصة MIT. سكربتات bash وNode بسيطة، بلا خدمة ولا تتبّع.",
 ),
}

CSS = """
:root{--bg:#ffffff;--fg:#1f2328;--muted:#59636e;--card:#f6f8fa;--line:#d1d9e0;--accent:#1a7f37;--accent2:#0969da}
@media (prefers-color-scheme:dark){:root{--bg:#0d1117;--fg:#e6edf3;--muted:#9198a1;--card:#161b22;--line:#30363d;--accent:#3fb950;--accent2:#79c0ff}}
*{box-sizing:border-box}html{scroll-behavior:smooth}
body{margin:0;background:var(--bg);color:var(--fg);font:16px/1.6 -apple-system,Segoe UI,Helvetica,Arial,"Noto Naskh Arabic","Noto Sans Arabic",sans-serif}
a{color:var(--accent2)}main,header,footer{max-width:1040px;margin:0 auto;padding:0 20px}
nav{display:flex;justify-content:space-between;align-items:center;padding:16px 0;font-weight:600}
h1{font-size:clamp(28px,5vw,48px);line-height:1.15;margin:32px 0 12px}
h2{font-size:28px;margin:56px 0 12px}
.lead{font-size:20px;color:var(--muted);max-width:760px}
.btn{display:inline-block;padding:10px 18px;border-radius:8px;font-weight:600;text-decoration:none;margin:8px 8px 8px 0;border:1px solid var(--line)}
[dir=rtl] .btn{margin:8px 0 8px 8px}.btn.primary{background:var(--accent);color:#fff;border-color:var(--accent)}
pre{background:var(--card);border:1px solid var(--line);border-radius:8px;padding:14px;overflow:auto;direction:ltr;text-align:left}
code{font-family:ui-monospace,SFMono-Regular,Menlo,Consolas,monospace;font-size:14px}
.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(260px,1fr));gap:14px}
.card{background:var(--card);border:1px solid var(--line);border-radius:10px;padding:16px}
.card h3{margin:0 0 6px;font-size:17px}.n{display:inline-block;width:26px;height:26px;line-height:26px;text-align:center;border-radius:50%;background:var(--accent);color:#fff;font-size:14px;margin-inline-end:8px}
.card pre{margin:10px 0 0;font-size:12px}.card p{margin:0;color:var(--muted)}
.chips{display:flex;flex-wrap:wrap;gap:8px;padding:0;list-style:none}
.chips li{background:var(--card);border:1px solid var(--line);border-radius:999px;padding:4px 14px;font-size:14px}
img{max-width:100%;height:auto;border-radius:10px;display:block;margin:12px 0}
details{background:var(--card);border:1px solid var(--line);border-radius:10px;padding:12px 16px;margin:10px 0}
summary{cursor:pointer;font-weight:600}footer{padding:40px 20px;color:var(--muted)}
"""


def isolate_latin(doc):
    """In Arabic pages wrap every Latin run in <bdi> so file names such as .env or
    AGENTS.md keep their direction inside right-to-left sentences. Text nodes only:
    <style>, <script> and attributes are left alone."""
    import re
    parts = re.split(r"(<style>.*?</style>|<script.*?</script>)", doc, flags=re.S)
    def fix(m):
        text = re.sub(r"([A-Za-z0-9][A-Za-z0-9_./:\-]*|\.[A-Za-z][A-Za-z0-9_.\-]*)", r'<bdi dir="ltr">\1</bdi>', m.group(1))
        return ">" + text + "<"
    return "".join(x if x.startswith(("<style>", "<script")) else re.sub(r">([^<>]+)<", fix, x) for x in parts)


def page(lang):
    t = T[lang]
    url = BASE + t["path"]
    other = BASE + t["other"]
    faq_ld = {"@type": "FAQPage", "mainEntity": [{"@type": "Question", "name": q, "acceptedAnswer": {"@type": "Answer", "text": a}} for q, a in t["faq"]]}
    sw_ld = {"@type": "SoftwareSourceCode", "name": "engineering-rules", "description": t["desc"], "codeRepository": REPO, "license": "https://opensource.org/licenses/MIT",
             "programmingLanguage": ["Shell", "JavaScript"], "url": url, "inLanguage": lang}
    ld = json.dumps({"@context": "https://schema.org", "@graph": [sw_ld, faq_ld]}, ensure_ascii=False)
    e = html.escape
    problems = "".join(f'<div class="card"><h3>{e(a)}</h3><p>{e(b)}</p></div>' for a, b in t["problems"])
    how = "".join(
        f'<div class="card"><h3><span class="n">{i}</span>{e(a)}</h3><p>{e(b)}</p>'
        + (f'<pre><code>{e(c)}</code></pre>' if c else "") + "</div>"
        for i, (a, b, c) in enumerate(t["how"], 1))
    stacks = "".join(f"<li>{e(s)}</li>" for s in STACKS)
    faq = "".join(f"<details><summary>{e(q)}</summary><p>{e(a)}</p></details>" for q, a in t["faq"])
    asset = "../assets/" if lang == "ar" else "assets/"
    install = "bash skills/engineering-rules" + ("-ar" if lang == "ar" else "") + "/scripts/install.sh --target ./my-project"
    doc = f"""<!doctype html>
<html lang="{t['lang']}" dir="{t['dir']}">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{e(t['title'])}</title>
<meta name="description" content="{e(t['desc'])}">
<link rel="canonical" href="{url}">
<link rel="alternate" hreflang="en" href="{BASE}/">
<link rel="alternate" hreflang="ar" href="{BASE}/ar/">
<link rel="alternate" hreflang="x-default" href="{BASE}/">
<meta property="og:type" content="website">
<meta property="og:title" content="{e(t['title'])}">
<meta property="og:description" content="{e(t['desc'])}">
<meta property="og:url" content="{url}">
<meta property="og:image" content="{BASE}/assets/social-preview.png">
<meta name="twitter:card" content="summary_large_image">
<meta name="twitter:image" content="{BASE}/assets/social-preview.png">
<script type="application/ld+json">{ld}</script>
<style>{CSS}</style>
</head>
<body>
<header><nav><span>engineering-rules</span><span><a href="{'ar/' if lang == 'en' else '../'}">{e(t['other_label'])}</a> · <a href="{REPO}">GitHub</a></span></nav></header>
<main>
<h1>{e(t['h1'])}</h1>
<p class="lead">{e(t['lead'])}</p>
<p><a class="btn primary" href="{REPO}">{e(t['cta'])}</a><a class="btn" href="{REPO}/blob/main/{'README.ar.md' if lang == 'ar' else 'README.md'}">{e(t['cta2'])}</a></p>
<h2>{e(t['install_label'])}</h2>
<pre><code>git clone {REPO}.git
{e(install)}
bash .github/scripts/doctor.sh
bash .github/scripts/local-proof.sh</code></pre>
<h2>{e(t['problem_h'])}</h2><p>{e(t['problem_p'])}</p><div class="grid">{problems}</div>
<h2>{e(t['how_h'])}</h2><div class="grid">{how}</div>
<h2>{e(t['demo_h'])}</h2><p>{e(t['demo_p'])}</p>
<img src="{asset}demo-before.svg" alt="{e(t['before_alt'])}" width="1000" height="360" loading="lazy">
<img src="{asset}demo-after.svg" alt="{e(t['after_alt'])}" width="1000" height="330" loading="lazy">
<h2>{e(t['stacks_h'])}</h2><p>{e(t['stacks_p'])}</p><ul class="chips">{stacks}</ul>
<h2>{e(t['agents_h'])}</h2><p>{e(t['agents_p'])}</p>
<h2>{e(t['faq_h'])}</h2>{faq}
</main>
<footer>{e(t['foot'])}</footer>
</body>
</html>
"""
    return isolate_latin(doc) if lang == "ar" else doc


def build():
    out = {}
    out["index.html"] = page("en")
    out["ar/index.html"] = page("ar")
    out["robots.txt"] = f"User-agent: *\nAllow: /\nSitemap: {BASE}/sitemap.xml\n"
    out["sitemap.xml"] = ('<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n'
                          f'  <url><loc>{BASE}/</loc></url>\n  <url><loc>{BASE}/ar/</loc></url>\n</urlset>\n')
    return out


def main():
    files = build()
    if "--check" in sys.argv:
        bad = [n for n, c in files.items() if not (SITE / n).exists() or (SITE / n).read_text(encoding="utf-8") != c]
        if bad:
            print("site is out of date:", bad, "- run python3 tools/build-site.py")
            sys.exit(1)
        print("site is current")
        return
    for name, content in files.items():
        p = SITE / name
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(content, encoding="utf-8")
    (SITE / "assets").mkdir(exist_ok=True)
    for a in ("banner.svg", "demo-before.svg", "demo-after.svg", "social-preview.png"):
        shutil.copyfile(ROOT / "assets" / a, SITE / "assets" / a)
    (SITE / ".nojekyll").write_text("", encoding="utf-8")
    print("wrote", len(files), "pages and 4 assets to site/")


if __name__ == "__main__":
    main()
