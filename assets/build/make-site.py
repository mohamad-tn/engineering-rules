#!/usr/bin/env python3
"""Generates the GitHub Pages site (site/) in English and Arabic: one fast, dependency-free
HTML page per language with SEO metadata (title, description, canonical, hreflang, Open Graph,
Twitter card, JSON-LD for the software and the FAQ), plus robots.txt and sitemap.xml.
Run:  python3 assets/build/make-site.py
Placeholders mohamad-tn and engineering-rules are filled by tools/publish-prep.sh.
"""
import html, json, pathlib, shutil

ROOT = pathlib.Path(__file__).resolve().parent.parent.parent
SITE = ROOT / "site"
BASE = "https://mohamad-tn.github.io/engineering-rules/"
REPO = "https://github.com/mohamad-tn/engineering-rules"

STACKS = ["Node.js", "Next.js", "React", "React Native", "Vue", "Angular", ".NET", "Laravel", "Flutter", "Python", "Django",
          "Java", "Spring", "Go", "Rust", "Ruby", "Rails", "C/C++", "Swift", "Terraform", "Docker"]

T = {
    "en": dict(
        lang="en", dir="ltr", path="", alt="ar/",
        title="engineering-rules: guardrails for fast and AI-written code",
        desc="One command adds small engineering rules and real gates (secrets, docs, PR size, tests, build, audit) to any repository. Node, Next.js, React, Laravel, Flutter, .NET, Python, Go, Rust, Java, Ruby, Terraform, Docker. No paid CI needed.",
        h1="Guardrails for fast code, and for code written by AI",
        lead="One command adds a short rules file and real, automated checks to any repository. Every pull request carries proof that the checks passed, on GitHub Actions or on your laptop.",
        cta1="View on GitHub", cta2="Run the demo",
        problem_h="The problem",
        problem_p="Writing code has never been faster. Reviewing it has not. A rushed Friday, or a coding assistant, produces a 1,300-line pull request that works on my machine, and the usual failures slip through:",
        problems=[("A .env file or key is committed", "The secret stays in git history; rotating it becomes an incident."),
                  ("Currency, time zone and hosts typed into code", "Every new market or environment needs a code change and a release."),
                  ("One pull request changes 1,300 lines", "Nobody reviews it properly; bugs ride along."),
                  ("Code changes, docs and changelog do not", "The docs lie within a month."),
                  ("A beta dependency, or no lockfile", "Builds differ between machines; bugs are not reproducible."),
                  ("An assistant says it finished and works", "Nothing proves it.")],
        demo_h="See it work in 60 seconds",
        demo_p="The same checkout feature, written twice. These are the real outputs of the demo in the repository.",
        before_alt="Five gates fail on the first version of the pull request", after_alt="All gates pass on the rewritten version",
        how_h="How you use it",
        steps=[("Install", "bash skills/engineering-rules/scripts/install.sh --target ./my-project"),
               ("Check the setup", "bash .github/scripts/doctor.sh"),
               ("Prove the gates", "bash .github/scripts/local-proof.sh")],
        how_p="It detects your stack, sets up the gates, and never overwrites a file you already have. Paste the proof into the pull request.",
        stacks_h="Supported stacks", stacks_p="Detected automatically. Monorepos run every project they contain.",
        why_h="Why it is different",
        why=[("Scripts, not a service", "Plain bash and Node. No account, no server; it runs in any CI and on your machine."),
             ("Nothing ran is never green", "Gates end as PASS, FAIL, SKIP, NOT RUN or N/A. The ones you require fail when they did not actually run."),
             ("Honest status", "Every rule is Enforced, Review, Ops or Planned. Planned never reads as enforced."),
             ("Works without paid CI", "Run the same scripts locally and paste the proof; there is a four-level fallback plan."),
             ("Built for AI agents", "A short AGENTS.md, an Agent Skill, JSON output and a guide to fixing every failure.")],
        faq_h="FAQ",
        faq=[("Do I need an AI assistant to use it?", "No. It is useful for any team. The assistant files and the Agent Skill are extras."),
             ("Which languages and frameworks are supported?", "Node.js, Next.js, React, React Native, Vue, Angular, .NET, Laravel and PHP, Flutter, Python and Django, Java and Spring, Go, Rust, Ruby and Rails, C and C++, Swift, Terraform and Docker, including monorepos."),
             ("Does it work without paid CI?", "Yes. Every gate is a script. Run local-proof.sh and paste its output into the pull request."),
             ("Can I use it on an existing, messy repository?", "Yes. Start with the lite profile; old markdown is not linted and old secrets can be handled explicitly with an ADR."),
             ("Does any data leave my machine?", "No service is involved. Pinned tools are downloaded from their official release pages and verified by checksum.")],
        foot="MIT licensed.", lang_link="العربية",
    ),
    "ar": dict(
        lang="ar", dir="rtl", path="ar/", alt="",
        title="قواعد الهندسة (engineering-rules): حواجز أمان للكود السريع والكود المكتوب بالذكاء الاصطناعي",
        desc="أمر واحد يضيف إلى أي مستودع قواعد هندسة صغيرة وبوابات فحص حقيقية: الأسرار والوثائق وحجم طلب الدمج والاختبارات والبناء والتدقيق. يدعم Node وNext.js وReact وLaravel وFlutter و.NET وPython وGo وRust وJava وRuby وTerraform وDocker. بدون CI مدفوع.",
        h1="حواجز أمان للكود السريع، وللكود الذي يكتبه الذكاء الاصطناعي",
        lead="أمر واحد يضيف ملف قواعد قصيرًا وفحوصًا آلية حقيقية إلى أي مستودع. وكل طلب دمج يحمل إثباتًا أن الفحوص نجحت، على GitHub Actions أو على جهازك.",
        cta1="افتح على GitHub", cta2="شغّل العرض",
        problem_h="المشكلة",
        problem_p="كتابة الكود لم تكن يومًا أسرع، لكن مراجعته لم تتسارع. يوم جمعة مستعجل أو مساعد برمجة ينتج طلب دمج من 1300 سطر يعمل عندي، وتمر أخطاء مألوفة:",
        problems=[("رفع ملف .env أو مفتاح", "السر يبقى في تاريخ Git، وتغييره يصبح حادثة."),
                  ("العملة والمنطقة الزمنية والمضيفات مكتوبة في الكود", "كل سوق أو بيئة جديدة تحتاج تعديل كود وإصدارًا جديدًا."),
                  ("طلب دمج واحد يغيّر 1300 سطر", "لا أحد يراجعه جيدًا فتمر الأخطاء معه."),
                  ("يتغير الكود ولا تتغير الوثائق وسجل التغييرات", "الوثائق تصبح كاذبة خلال شهر."),
                  ("اعتماد تجريبي، أو غياب ملف القفل", "تختلف البنيات بين الأجهزة ولا يمكن إعادة إنتاج الأخطاء."),
                  ("مساعد ذكاء اصطناعي يقول إنه أنهى وإنه يعمل", "لا شيء يثبت ذلك.")],
        demo_h="شاهده يعمل في 60 ثانية",
        demo_p="ميزة الدفع نفسها مكتوبة مرتين. هذه المخرجات الحقيقية للعرض الموجود في المستودع.",
        before_alt="خمس بوابات تفشل في النسخة الأولى من الطلب", after_alt="كل البوابات تنجح في النسخة المعاد كتابتها",
        how_h="كيف تستخدمه",
        steps=[("التثبيت", "bash skills/engineering-rules-ar/scripts/install.sh --target ./my-project"),
               ("فحص الإعداد", "bash .github/scripts/doctor.sh"),
               ("إثبات البوابات", "bash .github/scripts/local-proof.sh")],
        how_p="يكتشف تقنيتك ويجهّز البوابات ولا يكتب فوق أي ملف موجود. الصق الإثبات في طلب الدمج.",
        stacks_h="التقنيات المدعومة", stacks_p="تُكتشف تلقائيًا. والمستودعات الكبيرة تشغّل كل مشروع فيها.",
        why_h="ما الذي يميزه",
        why=[("سكربتات وليست خدمة", "bash وNode عاديان. لا حساب ولا خادم؛ يعمل في أي CI وعلى جهازك."),
             ("لم يعمل شيء لا يعني نجاحًا", "تنتهي البوابات بنجاح أو فشل أو تخطٍ أو لم تعمل أو لا تنطبق. والمطلوب منها يفشل إذا لم يعمل فعليًا."),
             ("حالة صادقة", "كل قاعدة مفروضة أو مراجَعة أو تشغيلية أو مخططة. والمخططة لا تُقرأ أبدًا كأنها مفروضة."),
             ("يعمل بدون CI مدفوع", "شغّل السكربتات نفسها محليًا والصق الإثبات؛ وهناك خطة بدائل بأربعة مستويات."),
             ("مصمم لوكلاء الذكاء الاصطناعي", "ملف AGENTS.md قصير ومهارة وكيل وإخراج JSON ودليل لإصلاح كل إخفاق.")],
        faq_h="أسئلة شائعة",
        faq=[("هل أحتاج مساعد ذكاء اصطناعي لاستخدامه؟", "لا. هو مفيد لأي فريق، وملفات المساعدين والمهارة إضافات."),
             ("ما اللغات والأطر المدعومة؟", "Node.js وNext.js وReact وReact Native وVue وAngular و.NET وLaravel وPHP وFlutter وPython وDjango وJava وSpring وGo وRust وRuby وRails وC وC++ وSwift وTerraform وDocker، بما فيها المستودعات الكبيرة."),
             ("هل يعمل بدون CI مدفوع؟", "نعم. كل بوابة سكربت. شغّل local-proof.sh والصق مخرجاته في طلب الدمج."),
             ("هل أستطيع استخدامه في مستودع قائم وفوضوي؟", "نعم. ابدأ بالنمط lite؛ لا يُفحص تنسيق الوثائق القديمة، وتُعالج الأسرار القديمة صراحة بسجل قرار."),
             ("هل تغادر أي بيانات جهازي؟", "لا توجد خدمة. تُنزَّل الأدوات المثبّتة من صفحات إصداراتها الرسمية وتُتحقق بمجموع تحقق.")],
        foot="ترخيص MIT.", lang_link="English",
    ),
}

CSS = """
:root{color-scheme:light dark;--bg:#0d1117;--fg:#e6edf3;--dim:#8b949e;--card:#161b22;--line:#30363d;--a:#3fb950;--b:#79c0ff}
@media (prefers-color-scheme:light){:root{--bg:#fff;--fg:#1f2328;--dim:#59636e;--card:#f6f8fa;--line:#d1d9e0;--a:#1a7f37;--b:#0969da}}
*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--fg);font:16px/1.6 -apple-system,Segoe UI,Helvetica,Arial,sans-serif}
main{max-width:980px;margin:0 auto;padding:0 20px 60px}header{padding:56px 0 24px}
h1{font-size:clamp(28px,5vw,46px);line-height:1.15;margin:0 0 14px;background:linear-gradient(90deg,var(--a),var(--b));-webkit-background-clip:text;background-clip:text;color:transparent}
h2{margin:44px 0 12px;font-size:26px}p.lead{font-size:19px;color:var(--dim);max-width:760px}
.cta a{display:inline-block;margin:6px 8px 0 0;padding:11px 20px;border-radius:8px;text-decoration:none;font-weight:600;border:1px solid var(--line);color:var(--fg)}
.cta a.p{background:var(--a);border-color:var(--a);color:#fff}
.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(280px,1fr));gap:12px}
.card{background:var(--card);border:1px solid var(--line);border-radius:10px;padding:14px 16px}.card b{display:block;margin-bottom:4px}.card span{color:var(--dim)}
img{max-width:100%;height:auto;border-radius:10px;margin:8px 0}pre{background:var(--card);border:1px solid var(--line);border-radius:8px;padding:12px 14px;overflow:auto;direction:ltr;text-align:left}
code{font-family:ui-monospace,SFMono-Regular,Menlo,Consolas,monospace;font-size:14px}.chips{display:flex;flex-wrap:wrap;gap:8px}
.chips li{list-style:none;background:var(--card);border:1px solid var(--line);border-radius:999px;padding:4px 14px}ul.chips{padding:0}
details{background:var(--card);border:1px solid var(--line);border-radius:8px;padding:10px 14px;margin:8px 0}summary{cursor:pointer;font-weight:600}
footer{border-top:1px solid var(--line);padding:22px 0;color:var(--dim);display:flex;gap:18px;flex-wrap:wrap}a{color:var(--b)}
"""


def page(c):
    url = BASE + c["path"]
    other = BASE + c["alt"]
    faq_ld = {"@context": "https://schema.org", "@type": "FAQPage",
              "mainEntity": [{"@type": "Question", "name": q, "acceptedAnswer": {"@type": "Answer", "text": a}} for q, a in c["faq"]]}
    sw_ld = {"@context": "https://schema.org", "@type": "SoftwareSourceCode", "name": "engineering-rules",
             "description": c["desc"], "codeRepository": REPO, "license": "https://opensource.org/licenses/MIT",
             "programmingLanguage": ["Shell", "JavaScript"], "inLanguage": c["lang"], "url": url}
    e = html.escape
    parts = [f'<!doctype html>\n<html lang="{c["lang"]}" dir="{c["dir"]}">\n<head>\n<meta charset="utf-8">\n<meta name="viewport" content="width=device-width,initial-scale=1">',
             f'<title>{e(c["title"])}</title>', f'<meta name="description" content="{e(c["desc"])}">',
             f'<link rel="canonical" href="{url}">',
             f'<link rel="alternate" hreflang="en" href="{BASE}">', f'<link rel="alternate" hreflang="ar" href="{BASE}ar/">', f'<link rel="alternate" hreflang="x-default" href="{BASE}">',
             f'<meta property="og:type" content="website"><meta property="og:title" content="{e(c["title"])}"><meta property="og:description" content="{e(c["desc"])}">',
             f'<meta property="og:url" content="{url}"><meta property="og:image" content="{BASE}assets/social-preview.png">',
             f'<meta name="twitter:card" content="summary_large_image"><meta name="twitter:title" content="{e(c["title"])}"><meta name="twitter:image" content="{BASE}assets/social-preview.png">',
             '<meta name="color-scheme" content="dark light">',
             f'<script type="application/ld+json">{json.dumps(sw_ld, ensure_ascii=False)}</script>',
             f'<script type="application/ld+json">{json.dumps(faq_ld, ensure_ascii=False)}</script>',
             f'<style>{CSS}</style>\n</head>\n<body>\n<main>']
    rel = "../" if c["lang"] == "ar" else ""
    parts.append(f'<header><h1>{e(c["h1"])}</h1><p class="lead">{e(c["lead"])}</p><p class="cta"><a class="p" href="{REPO}">{e(c["cta1"])}</a><a href="{REPO}/blob/main/examples/shop-api/run-demo.sh">{e(c["cta2"])}</a><a href="{other}">{e(c["lang_link"])}</a></p></header>')
    parts.append(f'<section><h2>{e(c["problem_h"])}</h2><p>{e(c["problem_p"])}</p><div class="grid">' + "".join(f'<div class="card"><b>{e(a)}</b><span>{e(b)}</span></div>' for a, b in c["problems"]) + '</div></section>')
    parts.append(f'<section><h2>{e(c["demo_h"])}</h2><p>{e(c["demo_p"])}</p><img src="{rel}assets/demo-before.svg" alt="{e(c["before_alt"])}" loading="lazy"><img src="{rel}assets/demo-after.svg" alt="{e(c["after_alt"])}" loading="lazy"></section>')
    parts.append(f'<section><h2>{e(c["how_h"])}</h2>' + "".join(f'<p><b>{i}. {e(n)}</b></p><pre><code>{e(cmd)}</code></pre>' for i, (n, cmd) in enumerate(c["steps"], 1)) + f'<p>{e(c["how_p"])}</p></section>')
    parts.append(f'<section><h2>{e(c["stacks_h"])}</h2><p>{e(c["stacks_p"])}</p><ul class="chips">' + "".join(f'<li>{e(s)}</li>' for s in STACKS) + '</ul></section>')
    parts.append(f'<section><h2>{e(c["why_h"])}</h2><div class="grid">' + "".join(f'<div class="card"><b>{e(a)}</b><span>{e(b)}</span></div>' for a, b in c["why"]) + '</div></section>')
    parts.append(f'<section><h2>{e(c["faq_h"])}</h2>' + "".join(f'<details><summary>{e(q)}</summary><p>{e(a)}</p></details>' for q, a in c["faq"]) + '</section>')
    parts.append(f'<footer><span>{e(c["foot"])}</span><a href="{REPO}">GitHub</a><a href="{REPO}/blob/main/README{".ar" if c["lang"]=="ar" else ""}.md">README</a><a href="{REPO}/blob/main/skills/engineering-rules{"-ar" if c["lang"]=="ar" else ""}/SKILL.md">SKILL.md</a></footer>\n</main>\n</body>\n</html>\n')
    return "\n".join(parts)


(SITE / "ar").mkdir(parents=True, exist_ok=True)
(SITE / "assets").mkdir(exist_ok=True)
(SITE / "index.html").write_text(page(T["en"]), encoding="utf-8")
(SITE / "ar" / "index.html").write_text(page(T["ar"]), encoding="utf-8")
(SITE / "robots.txt").write_text(f"User-agent: *\nAllow: /\n\nSitemap: {BASE}sitemap.xml\n", encoding="utf-8")
(SITE / "sitemap.xml").write_text(
    '<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9" xmlns:xhtml="http://www.w3.org/1999/xhtml">\n'
    + "".join(f'  <url><loc>{BASE}{p}</loc><xhtml:link rel="alternate" hreflang="en" href="{BASE}"/><xhtml:link rel="alternate" hreflang="ar" href="{BASE}ar/"/></url>\n' for p in ("", "ar/"))
    + "</urlset>\n", encoding="utf-8")
(SITE / ".nojekyll").write_text("", encoding="utf-8")
for name in ("banner.svg", "demo-before.svg", "demo-after.svg", "social-preview.png"):
    src = ROOT / "assets" / name
    if src.exists():
        shutil.copyfile(src, SITE / "assets" / name)
print("site written to", SITE)
