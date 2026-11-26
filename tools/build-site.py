#!/usr/bin/env python3
"""Builds the static GitHub Pages site (English and Arabic) into site/.
    python3 tools/build-site.py           write the files
    python3 tools/build-site.py --check   exit 1 if the committed site is out of date
One self-contained HTML page per language: no external fonts, scripts or trackers.
Includes language-specific metadata, Open Graph / Twitter tags, hreflang, canonical URLs,
a sitemap and truthful JSON-LD (SoftwareSourceCode and visible FAQPage content).
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
AUTHOR = _cfg.get("author", "")
BASE = f"https://{OWNER}.github.io/{REPO_NAME}"
REPO = f"https://github.com/{OWNER}/{REPO_NAME}"

STACKS = ["Node.js", "Next.js", "React", "React Native", "Vue", "Angular", "Svelte", "NestJS", ".NET", "Laravel", "Symfony", "Flutter",
          "Python", "Django", "FastAPI", "Java", "Spring Boot", "Go", "Rust", "Ruby", "Rails", "Swift", "C / C++", "Terraform", "Docker"]

T = {
 "en": dict(
  lang="en", dir="ltr", path="/", other="/ar/", other_label="العربية",
  title="Engineering rules for AI coding agents and CI | engineering-rules",
  desc="Open-source engineering guardrails for AI coding agents and human teams: secret scanning, pull-request checks, documentation rules and stack-specific test/build workflows. Run locally or in CI.",
  h1="Practical engineering guardrails for AI-assisted and human-written code.",
  lead="Add a compact AGENTS.md and reusable checks to an existing Git repository. Run them locally or wire the same scripts into CI; results depend on the selected profile, stack, repository configuration and installed tools.",
  cta="View the source on GitHub", cta2="Read the adoption guide", install_label="Quick start for an existing Git repository",
  problem_h="The problem", problem_p="Writing code has never been faster. Reviewing it has not. These failures slip through:",
  problems=[("Committed secrets", "A .env file or key in git history turns rotation into an incident."),
            ("Configuration in code", "Currency, time zones and hosts typed into code need a release for every new market."),
            ("Giant pull requests", "1,300 changed lines are not reviewed; bugs ride along."),
            ("Docs that lie", "Code changes, documentation and changelog do not."),
            ("Unreproducible builds", "No lockfile, beta dependencies, builds that differ between machines."),
            ("Green that means nothing", "Skipped tests and gates that quietly did not run.")],
  how_h="How it works", how=[("Install", "Detects your stack and never overwrites a file.", "bash engineering-rules/skills/engineering-rules/scripts/install.sh --target ./my-project"),
            ("Work in small tasks", "About one pull request per task, around 400 changed lines.", None),
            ("Prove it", "Runs configured checks and prints a proof block; missing or skipped checks are reported, not counted as passes.", "bash .github/scripts/local-proof.sh"),
            ("A human merges", "Assistants never merge. A gate that did not run is never a pass.", None)],
  demo_h="See it work", demo_p="The same feature, first as a fast pull request, then done to the rules. This is the real output of the included demo.",
  before_alt="Five gates fail on the first version", after_alt="All gates pass after the rewrite",
  stacks_h="Supported stack adapters", stacks_p="Available checks vary by stack, project scripts, configuration and installed tools. Skipped, unavailable and not-applicable gates remain distinct; see the support matrix before adoption.",
  agents_h="Built for AI-assisted development", agents_p="The repository provides AGENTS.md and bridge files for Claude Code, Cursor, Codex, GitHub Copilot, Gemini and Windsurf. Agent behavior still depends on each tool and its configuration.",
  faq_h="Questions",
  faq=[("What is engineering-rules?", "An open-source Agent Skill, installer and set of reusable engineering checks. Core checks can be added to an existing Git repository; stack automation is provided for listed engines and varies by project configuration."),
       ("Do I need paid CI?", "You can run the scripts locally without a paid CI service. For team enforcement, configure your CI provider and branch protections; local output is a report, not a server-enforced status."),
       ("Does it work with AI coding assistants?", "Yes. Claude Code, Cursor, Codex, Copilot, Gemini and Windsurf read AGENTS.md or its bridge files. An agent can adopt it with one command and read machine-readable results with --json."),
       ("Which languages and frameworks are supported?", "Node.js, Next.js, React, React Native and Expo, Vue, Angular, Svelte, NestJS, .NET, Laravel and PHP, Flutter, Python and Django, Java and Spring, Go, Rust, Ruby and Rails, Swift, C and C++ with CMake, Terraform and OpenTofu, and Docker."),
       ("Can I adopt it in an existing repository?", "Yes. Start with the lite profile and review each finding. Scanning only from an adoption commit narrows historical coverage and should be used only after exposed credentials are rotated and the exception is documented. Disabled gates leave the required list and are not enforced."),
       ("Is there an Arabic edition?", "Yes. A full Arabic edition of the skill, the README and the guides ships in the same repository.")],
  foot="MIT licensed. Created and maintained by Mohamad Tonbary. Plain bash and Node; no hosted service or tracking.",
  resources_h="Explore the documentation",
  resources=[("Adoption guide", "docs/adoption-guide.md"), ("Supported stacks", "skills/engineering-rules/references/stacks/README.md"), ("CI provider examples", "docs/ci-providers.md"), ("Security policy", "SECURITY.md")],
 ),
 "ar": dict(
  lang="ar", dir="rtl", path="/ar/", other="/", other_label="English",
  title="قواعد هندسية لوكلاء البرمجة وCI | engineering-rules",
  desc="حواجز هندسية مفتوحة المصدر لوكلاء البرمجة وفرق التطوير: فحص الأسرار، وضوابط طلبات الدمج، والوثائق، وفحوص الاختبار والبناء بحسب التقنية. شغّلها محليًا أو اربطها بـ CI.",
  h1="حواجز هندسية عملية للكود المدعوم بالذكاء الاصطناعي والكود البشري.",
  lead="أضف ملف AGENTS.md مختصرًا وفحوصًا قابلة لإعادة الاستخدام إلى مستودع Git قائم. شغّلها محليًا أو اربط السكربتات نفسها بـ CI؛ وتعتمد النتائج على النمط والتقنية وإعدادات المستودع والأدوات المثبّتة.",
  cta="استعرض المصدر على GitHub", cta2="اقرأ دليل التبنّي", install_label="بدء سريع لمستودع Git قائم",
  problem_h="المشكلة", problem_p="كتابة الكود لم تكن يومًا أسرع، لكن مراجعته لم تتسارع. وهذه الأخطاء تمر:",
  problems=[("أسرار مرفوعة", "ملف .env أو مفتاح في تاريخ Git يحوّل تغيير المفتاح إلى حادثة."),
            ("إعدادات داخل الكود", "العملة والمناطق الزمنية والمضيفات المكتوبة في الكود تحتاج إصدارًا لكل سوق جديد."),
            ("طلبات دمج ضخمة", "1300 سطر معدّل لا يراجعها أحد جيدًا، فتمر الأخطاء معها."),
            ("وثائق كاذبة", "يتغير الكود ولا تتغير الوثائق ولا سجل التغييرات."),
            ("بناء لا يمكن إعادة إنتاجه", "لا ملف قفل، واعتمادات تجريبية، وبنيات تختلف بين الأجهزة."),
            ("أخضر بلا معنى", "اختبارات متخطاة وبوابات لم تعمل بصمت.")],
  how_h="كيف يعمل", how=[("ثبّت", "يكتشف تقنيتك ولا يكتب فوق أي ملف.", "bash engineering-rules/skills/engineering-rules-ar/scripts/install.sh --target ./my-project"),
            ("اعمل بمهام صغيرة", "طلب دمج واحد تقريبًا لكل مهمة، بحدود 400 سطر معدّل.", None),
            ("أثبت", "يشغّل الفحوص المهيأة ويطبع كتلة نتائج؛ ويعرض الفحوص التي لم تعمل بدل احتسابها نجاحًا.", "bash .github/scripts/local-proof.sh"),
            ("الإنسان يدمج", "المساعدون لا يدمجون أبدًا. والبوابة التي لم تعمل ليست نجاحًا.", None)],
  demo_h="شاهده يعمل", demo_p="الميزة نفسها، أولًا كطلب دمج سريع، ثم مكتوبة وفق القواعد. هذه المخرجات الحقيقية للعرض المرفق.",
  before_alt="خمس بوابات تفشل في النسخة الأولى", after_alt="كل البوابات تنجح بعد إعادة الكتابة",
  stacks_h="محركات التقنيات المدعومة", stacks_p="تختلف الفحوص المتاحة حسب التقنية وسكربتات المشروع وإعداداته والأدوات المثبّتة. تظل حالات التخطي وعدم التوفر وعدم الانطباق متميزة؛ راجع مصفوفة الدعم قبل التبنّي.",
  agents_h="مصمم للتطوير بمساعدة الذكاء الاصطناعي", agents_p="يوفر المستودع ملف AGENTS.md وملفات ربط لـ Claude Code وCursor وCodex وGitHub Copilot وGemini وWindsurf. ويظل سلوك الوكيل معتمدًا على الأداة وإعداداتها.",
  faq_h="أسئلة",
  faq=[("ما هو engineering-rules؟", "مهارة وكيل ومثبّت ومجموعة فحوص هندسية مفتوحة المصدر. يمكن إضافة الفحوص الأساسية إلى مستودع Git قائم؛ أما أتمتة التقنيات فتتوفر للمحركات المدرجة وتختلف حسب إعداد المشروع."),
       ("هل أحتاج CI مدفوعًا؟", "يمكنك تشغيل السكربتات محليًا دون خدمة CI مدفوعة. وللإنفاذ على مستوى الفريق، أعدّ CI وحماية الفروع؛ فالنتيجة المحلية تقرير وليست حالة يفرضها الخادم."),
       ("هل يعمل مع مساعدي البرمجة بالذكاء الاصطناعي؟", "نعم. Claude Code وCursor وCodex وCopilot وGemini وWindsurf تقرأ AGENTS.md أو ملفات الربط. ويستطيع الوكيل تبنّيه بأمر واحد وقراءة النتائج الآلية بالخيار --json."),
       ("ما اللغات والأطر المدعومة؟", "Node.js وNext.js وReact وReact Native وExpo وVue وAngular وSvelte وNestJS و.NET وLaravel وPHP وFlutter وPython وDjango وJava وSpring وGo وRust وRuby وRails وSwift وC وC++ مع CMake وTerraform وOpenTofu وDocker."),
       ("هل أستطيع تبنّيه في مستودع قائم؟", "نعم. ابدأ بالنمط lite وراجع كل نتيجة. حصر فحص الأسرار من commit التبنّي يقلّص تغطية التاريخ، ولا يُستخدم إلا بعد تدوير الأسرار المكشوفة وتوثيق الاستثناء. البوابة المعطّلة تخرج من قائمة المطلوب ولا تكون مفروضة."),
       ("هل توجد نسخة عربية؟", "نعم. نسخة عربية كاملة من المهارة وملف README والأدلة في المستودع نفسه.")],
  foot="رخصة MIT. أنشأه ويديره Mohamad Tonbary. سكربتات bash وNode، بلا خدمة مستضافة أو تتبّع.",
  resources_h="استكشف الوثائق",
  resources=[("دليل التبنّي", "docs/ar/adoption-guide.md"), ("التقنيات المدعومة", "skills/engineering-rules-ar/references/stacks/README.md"), ("أمثلة مزوّدي CI", "docs/ar/ci-providers.md"), ("سياسة الأمان", "SECURITY.md")],
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
    <title>, <style>, <script> and attributes are left alone."""
    import re
    parts = re.split(r"(<title>.*?</title>|<style>.*?</style>|<script.*?</script>)", doc, flags=re.S)
    def fix(m):
        text = re.sub(r"([A-Za-z0-9][A-Za-z0-9_./:\-]*|\.[A-Za-z][A-Za-z0-9_.\-]*)", r'<bdi dir="ltr">\1</bdi>', m.group(1))
        return ">" + text + "<"
    return "".join(x if x.startswith(("<title>", "<style>", "<script")) else re.sub(r">([^<>]+)<", fix, x) for x in parts)


def page(lang):
    t = T[lang]
    url = BASE + t["path"]
    other = BASE + t["other"]
    faq_ld = {"@type": "FAQPage", "mainEntity": [{"@type": "Question", "name": q, "acceptedAnswer": {"@type": "Answer", "text": a}} for q, a in t["faq"]]}
    sw_ld = {"@type": "SoftwareSourceCode", "@id": REPO + "#software", "name": "engineering-rules", "description": t["desc"], "codeRepository": REPO, "license": "https://opensource.org/licenses/MIT",
             "programmingLanguage": ["Shell", "JavaScript"], "url": url, "inLanguage": lang,
             "keywords": ["engineering rules", "AI coding agents", "pull request checks", "CI quality gates", "secret scanning"]}
    if AUTHOR:
        sw_ld["author"] = {"@type": "Person", "name": AUTHOR, "url": f"https://github.com/{OWNER}"}
    ld = json.dumps({"@context": "https://schema.org", "@graph": [sw_ld, faq_ld]}, ensure_ascii=False)
    e = html.escape
    problems = "".join(f'<div class="card"><h3>{e(a)}</h3><p>{e(b)}</p></div>' for a, b in t["problems"])
    how = "".join(
        f'<div class="card"><h3><span class="n">{i}</span>{e(a)}</h3><p>{e(b)}</p>'
        + (f'<pre><code>{e(c)}</code></pre>' if c else "") + "</div>"
        for i, (a, b, c) in enumerate(t["how"], 1))
    stacks = "".join(f"<li>{e(s)}</li>" for s in STACKS)
    faq = "".join(f"<details><summary>{e(q)}</summary><p>{e(a)}</p></details>" for q, a in t["faq"])
    resources = "".join(f'<li><a href="{REPO}/blob/main/{e(path)}">{e(label)}</a></li>' for label, path in t["resources"])
    asset = "../assets/" if lang == "ar" else "assets/"
    install = "bash engineering-rules/skills/engineering-rules" + ("-ar" if lang == "ar" else "") + "/scripts/install.sh --target ./my-project"
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
<meta property="og:site_name" content="engineering-rules">
<meta property="og:locale" content="{'ar_AR' if lang == 'ar' else 'en_US'}">
<meta property="og:locale:alternate" content="{'en_US' if lang == 'ar' else 'ar_AR'}">
<meta property="og:title" content="{e(t['title'])}">
<meta property="og:description" content="{e(t['desc'])}">
<meta property="og:url" content="{url}">
<meta property="og:image" content="{BASE}/assets/social-preview.png">
<meta name="twitter:card" content="summary_large_image">
<meta name="twitter:title" content="{e(t['title'])}">
<meta name="twitter:description" content="{e(t['desc'])}">
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
<pre><code>git clone {REPO}.git engineering-rules
# Run from a parent directory with an existing Git checkout named my-project.
{e(install)}
cd my-project
bash .github/scripts/doctor.sh
# After committing the adoption and fetching the base branch:
bash .github/scripts/local-proof.sh</code></pre>
<h2>{e(t['problem_h'])}</h2><p>{e(t['problem_p'])}</p><div class="grid">{problems}</div>
<h2>{e(t['how_h'])}</h2><div class="grid">{how}</div>
<h2>{e(t['demo_h'])}</h2><p>{e(t['demo_p'])}</p>
<img src="{asset}demo-before.svg" alt="{e(t['before_alt'])}" width="1000" height="360" loading="lazy">
<img src="{asset}demo-after.svg" alt="{e(t['after_alt'])}" width="1000" height="330" loading="lazy">
<h2>{e(t['stacks_h'])}</h2><p>{e(t['stacks_p'])}</p><ul class="chips">{stacks}</ul>
<h2>{e(t['agents_h'])}</h2><p>{e(t['agents_p'])}</p>
<h2>{e(t['faq_h'])}</h2>{faq}
<h2>{e(t['resources_h'])}</h2><ul>{resources}</ul>
</main>
<footer>{e(t['foot'])} · <a href="https://github.com/{OWNER}">{e(AUTHOR or OWNER)}</a></footer>
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
    asset_names = ("banner.svg", "demo-before.svg", "demo-after.svg", "social-preview.png")
    if "--check" in sys.argv:
        bad = [n for n, c in files.items() if not (SITE / n).exists() or (SITE / n).read_text(encoding="utf-8") != c]
        for name in asset_names:
            src, dst = ROOT / "assets" / name, SITE / "assets" / name
            if not dst.exists() or dst.read_bytes() != src.read_bytes():
                bad.append(f"assets/{name}")
        if not (SITE / ".nojekyll").exists():
            bad.append(".nojekyll")
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
    for a in asset_names:
        shutil.copyfile(ROOT / "assets" / a, SITE / "assets" / a)
    (SITE / ".nojekyll").write_text("", encoding="utf-8")
    print("wrote", len(files), "pages and 4 assets to site/")


if __name__ == "__main__":
    main()
