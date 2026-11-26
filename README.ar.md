<!-- rtl -->
<div dir="rtl">

<div align="center">

<img src="assets/banner.svg" alt="engineering-rules" width="100%">

[![CI](https://github.com/mohamad-tn/engineering-rules/actions/workflows/ci.yml/badge.svg)](https://github.com/mohamad-tn/engineering-rules/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Stacks](https://img.shields.io/badge/stacks-Node%20%7C%20Next.js%20%7C%20React%20%7C%20React%20Native%20%7C%20.NET%20%7C%20Laravel%20%7C%20Flutter%20%7C%20Python%20%7C%20Java%20%7C%20Go%20%7C%20Rust%20%7C%20Ruby-3fb950.svg)](skills/engineering-rules-ar/references/stacks/README.md)
[![No paid CI needed](https://img.shields.io/badge/paid%20CI-not%20required-79c0ff.svg)](docs/ar/ci-providers.md)

[English](README.md) · **العربية** · [الموقع](https://mohamad-tn.github.io/engineering-rules/ar/)

</div>

# قواعد الهندسة (engineering-rules)

**حواجز هندسية عملية للكود الذي يكتبه البشر أو بمساعدة الذكاء الاصطناعي.** أضف ملف `AGENTS.md` مختصرًا وفحوصًا قابلة لإعادة الاستخدام وقوالب CI بحسب التقنية إلى مستودع Git قائم. شغّل الفحوص محليًا أو اربط السكربتات نفسها بـ CI؛ ويمكن توليد كتلة نتائج للتغييرات المحفوظة في commit. يتضمن المستودع تكاملات لـ `Claude Code` و`Cursor` و`Codex` و`GitHub Copilot` و`Gemini` و`Windsurf`. يعتمد نطاق الفحوص على النمط والتقنية وإعدادات المشروع والأدوات المثبّتة.

<div dir="ltr">

```bash
bash skills/engineering-rules-ar/scripts/install.sh --target ./my-project
```

</div>

يكتشف التقنيات المدعومة (`Node.js` و`Next.js` و`React` و`React Native` و`Vue` و`Angular` و`.NET` و`Laravel` و`Flutter` و`Python` و`Java` و`Go` و`Rust` و`Ruby` و`Swift` و`C/C++` و`Terraform` و`Docker`) ويضيف مجموعة أولية من الفحوص دون الكتابة فوق الملفات الموجودة افتراضيًا. الفحوص الأساسية مستقلة عن التقنية؛ أما بوابات كل تقنية فتختلف حسب المحرك وإعدادات المشروع. ولا يُعرض غياب محرك تقنية مدعوم على أنه نجاح.

> **اصطلاح الكتابة في هذه النسخة:** الأوامر وأسماء الملفات والأدوات والأطر تُكتب بخط الكود وتبقى بالإنجليزية. والمصطلحات الإنجليزية داخل الجمل توضع بين أقواس بعد المقابل العربي. ملفات المساهمة والأمان (`CONTRIBUTING.md` و`SECURITY.md`) بالإنجليزية.

---

## المشكلة

كتابة الكود لم تكن يومًا أسرع، لكن مراجعته لم تتسارع. مساعد برمجة (أو يوم جمعة مستعجل) ينتج طلب دمج من 1300 سطر «يعمل عندي»، وتمر أخطاء مألوفة:

| ما الذي يسوء | لماذا يؤلم |
|---|---|
| رفع ملف `.env` أو مفتاح إلى المستودع | السر يبقى في تاريخ Git للأبد، وتغييره يصبح حادثة |
| كتابة العملة والمنطقة الزمنية والمضيفات ونسب الضريبة داخل الكود | كل سوق أو بيئة جديدة تحتاج تعديل كود وإصدارًا جديدًا |
| طلب دمج واحد يغيّر 1300 سطر | لا أحد يراجعه جيدًا، فتمر الأخطاء معه |
| يتغير الكود ولا تتغير الوثائق وسجل التغييرات | الوثائق تصبح كاذبة خلال شهر |
| اعتماد تجريبي (beta) يتسلل، أو لا يوجد ملف قفل (lockfile) | تختلف البنيات بين الأجهزة ولا تستطيع إعادة إنتاج خطأ |
| تخطّي الاختبارات «هذه المرة فقط» | اللون الأخضر يفقد معناه |
| أعلام الميزات لا تُحذف أبدًا | تتراكم مسارات الكود الميتة |
| انتهت دقائق الـ CI أو تعطل | يتوقف العمل أو يدمج الناس بلا فحوص |
| مساعد ذكاء اصطناعي «ينهي» المهمة ويقول إنها تعمل | لا شيء يثبت ذلك |

يحوّل المشروع عددًا من مخاطر التسليم المتكررة إلى فحوص آلية وممارسات مراجعة موثقة. إنه خط أساس قابل للتهيئة، وليس بديلًا عن مراجعة الكود أو الاستجابة للحوادث أو اختبارات الأمان الخاصة بالتطبيق أو حماية الفرع.

## ما هو

- **ملف قواعد قصير** (`AGENTS.md`) يتبعه البشر ومساعدو الذكاء الاصطناعي بالطريقة نفسها.
- **بوابات**: سكربتات تُفشل طلب الدمج بسبب المشاكل أعلاه. هي سكربتات `shell` و`Node` عادية، فتعمل في أي CI وعلى جهازك.
- **محركات التقنية** لـ `Node` و`React` و`Vue` و`Angular` و`Next.js` و`React Native` و`.NET` و`Laravel` و`Flutter` و`Python` و`Java` و`Go` و`Rust` و`Ruby` و`Swift` و`C/C++` و`Terraform` و`Docker`. تختلف البوابات المتاحة حسب التقنية وسكربتات المشروع والأدوات والنمط؛ ولكل من `SKIP` و`NOT RUN` و`N/A` معنى مختلف.
- **نتائج محلية**: يشغّل `local-proof.sh` الفحوص المهيأة ويطبع كتلة لتغيير محفوظ في commit. ويظهر البوابة التي لم تعمل؛ الخياران `--allow-missing` و`--no-stack` لا يعنيان إثبات نجاح. استخدام CI المستضاف وحماية الفرع قرار للفريق.
- **مهارة وكيل** (Agent Skill) في `SKILL.md` ليعرف مساعد الذكاء الاصطناعي كيف يتبنّى كل هذا ويلتزم به.

<div dir="ltr">

```mermaid
flowchart LR
    A[مطور أو مساعد ذكاء اصطناعي] -->|مهمة صغيرة| B[فرع]
    B --> C{البوابات}
    C -->|فحص الأسرار| G[كتلة الإثبات]
    C -->|فحص الوثائق| G
    C -->|السياسة والأعلام| G
    C -->|حجم الطلب| G
    C -->|بوابات التقنية| G
    G -->|ملصقة في الطلب أو CI أخضر| H[مراجعة بشرية]
    H -->|الإنسان فقط يدمج| I[main]
```

</div>

## شاهده يعمل في 60 ثانية

ميزة الدفع نفسها مكتوبة مرتين. أولًا كطلب دمج سريع معتاد:

<img src="assets/demo-before.svg" alt="خمس بوابات تفشل في النسخة الأولى من الطلب" width="100%">

ثم بعد إعادة كتابتها وفق القواعد:

<img src="assets/demo-after.svg" alt="كل البوابات تنجح في النسخة المعاد كتابتها" width="100%">

هذه ليست صورة مصممة؛ هي المخرجات الحقيقية لـ [`examples/shop-api/run-demo.sh`](examples/shop-api/run-demo.sh) (محفوظة في [`output-before.txt`](examples/shop-api/output-before.txt) و[`output-after.txt`](examples/shop-api/output-after.txt)). شغّلها بنفسك:

<div dir="ltr">

```bash
bash examples/shop-api/run-demo.sh
```

</div>

## قبل وبعد: كودك

كل ما يلي من العرض التوضيحي. «قبل» هو ما تبدو عليه المسودة الأولى السريعة غالبًا.

### 1. إعدادات مكتوبة داخل الكود

<div dir="ltr">

```diff
- const CURRENCY = "USD";
- const TIMEZONE = "Europe/Berlin";
- const TAX_RATE = 0.19;
+ const { loadConfig } = require("./config");   // reads the environment; a missing value is an error
```

</div>

بوابة **السياسة** تُفشل النسخة الأولى: «العملة `USD` مكتوبة داخل الكود» و«المنطقة الزمنية `Europe/Berlin` مكتوبة داخل الكود». وبهذا يصبح دخول سوق جديد تغيير إعدادات وليس إصدارًا جديدًا.

### 2. اتصال شبكي قد يعلق، وسر داخل الكود

<div dir="ltr">

```diff
- const response = await fetch("https://api.example.com/charge", {
-   headers: { Authorization: "Bearer live_..." },
-   body: JSON.stringify({ total, currency: CURRENCY }),
- });
+ const response = await fetch("https://api.example.com/charge", {
+   headers: { Authorization: `Bearer ${config.apiKey}` },
+   body: JSON.stringify({ total: orderTotal(items, config.taxRate), currency: config.currency }),
+   signal: AbortSignal.timeout(config.timeoutMs),   // cannot hang
+ });
```

</div>

ملف القواعد يقول: لكل اتصال شبكي مهلة، ولا تُعاد محاولة العمليات غير الآمنة التكرار. المراجعون والمساعدون يتحققون من هذا؛ أما جزء **السر** فيلتقطه فحص الأسرار (التالي).

### 3. ملف `.env` مرفوع

<div dir="ltr">

```diff
- DATABASE_URL=postgres://admin:...@db.internal.example/shop     # .env, tracked in git
- PAYMENT_API_KEY=...
+ DATABASE_URL=                                                  # .env.example: names, never values
+ PAYMENT_API_KEY=
```

</div>

**فحص الأسرار** يقرأ كل تاريخ Git ويفشل مع اسم القاعدة والملف. الإصلاح: غيّر المفتاح **و**أعد كتابة الفرع قبل مشاركته؛ فتعديل «حذف» لاحق لا يكفي.

### 4. طلب دمج ضخم واحد

<div dir="ltr">

```text
This pull request changes 1331 lines, above 800.
Split it, or add the label pr-size-reason with a written reason.
```

</div>

ملفات القفل واللقطات والكود المولَّد لا تُحسب. هنا كانت المشكلة لصق 1300 سطر من البيانات، وهي لا تنتمي للتغيير أصلًا.

### 5. كود بلا وثائق

<div dir="ltr">

```text
docs-check: code changed under "src/**" without a change in: docs/features/**, CHANGELOG.md
docs-check: CHANGELOG.md has no entry and the pull-request title type "feat" is not one of chore/ci/test
```

</div>

### 6. وصف طلب الدمج

| قبل | بعد |
|---|---|
| «feat: checkout. يعمل عندي.» | [القالب](skills/engineering-rules-ar/templates/PULL_REQUEST_TEMPLATE.md): ملخص، وتعريف الإنجاز، والمخاطر والتراجع، و**كتلة إثبات** فيها الـ commit والتاريخ ونتيجة كل بوابة |

### ما الذي تلتقطه بوابات التقنية

| التقنية | مثال على ما يفشل |
|---|---|
| `Node` و`React` و`Vue` و`Angular` | غياب ملف القفل؛ فشل `test`؛ `npm audit` يجد ثغرة عالية الخطورة |
| `Next.js` | الحزمة المبنية للعميل تحتوي مضيف واجهتك الخاصة |
| `React Native` و`Expo` و`Flutter` | ملف مفاتيح توقيع مرفوع أو `key.properties`؛ رابط `http://` بدون تشفير؛ انجراف في `pubspec.lock` |
| `.NET` | تحذير (التحذيرات أخطاء)؛ حزمة `NuGet` معرّضة للثغرات |
| `Laravel` و`PHP` | خطأ صياغة؛ ملاحظات `Pint` أو `PHPStan`؛ ثغرات `composer audit` |
| `Python` و`Django` | متطلبات غير مثبّتة؛ تغيير نموذج بلا ترحيل (migration) |
| `Java` و`Spring` | فشل `verify`؛ غياب غلاف Maven أو Gradle (تحذير) |
| `Go` | ملف `go.mod` غير مرتب؛ كود غير منسّق؛ ملاحظات `go vet` |
| `Rust` | تحذير `clippy`؛ برنامج تنفيذي بدون `Cargo.lock` |
| `Ruby` و`Rails` | ملاحظات `RuboCop` و`Brakeman`؛ ثغرات `bundler-audit` |

في مشروع `Next.js` التجريبي داخل هذا المستودع، بوابة التدقيق تُبلِّغ فعلًا عن ثغرات عالية الخطورة في إصداره القديم عمدًا.

## البدء السريع

### الخيار أ: أمر واحد (أي مستودع)

<div dir="ltr">

```bash
git clone https://github.com/mohamad-tn/engineering-rules.git
# Run this from a parent directory where ./my-project is an existing Git checkout.
bash engineering-rules/skills/engineering-rules-ar/scripts/install.sh --target ./my-project \
     --profile standard --org my-org --project my-project --owner my-handle
cd my-project
bash .github/scripts/doctor.sh        # checks the setup, tells you what is left
git add -A && git commit -m "chore: adopt engineering rules"
bash .github/scripts/local-proof.sh   # runs configured gates; disclose any NOT RUN or SKIPPED result
```

</div>

الخيارات: `--profile lite|standard|strict` و`--stack auto|none|node,go,...` و`--layout single|member` و`--agents all|none|claude,cursor,...` و`--stack-configs` و`--dry-run` و`--force`. لا يُكتب فوق أي ملف إلا إذا مرّرت `--force`.

### الخيار ب: كمهارة وكيل (Agent Skill)

انسخ المجلد [`skills/engineering-rules-ar`](skills/engineering-rules-ar) إلى مجلد المهارات في مساعدك (في `Claude Code`: المجلد `.claude/skills/engineering-rules-ar/` داخل المشروع، أو `~/.claude/skills/` لكل المشاريع)، ثم اطلب: «تبنَّ قواعد الهندسة في هذا المستودع». يقرأ المساعد [`SKILL.md`](skills/engineering-rules-ar/SKILL.md) ويشغّل المثبّت ويملأ الأماكن المحجوزة ويشغّل الإثبات. وللأدوات التي تقرأ `AGENTS.md` (مثل `Cursor` و`Codex` و`Copilot` و`Gemini`) يكتب المثبّت أيضًا ملفات ربط صغيرة.
والمستودع نفسه متجر مكوّنات لـ `Claude Code`، ويمكن تثبيت مجلد `skills/` بأداة `skills` المفتوحة:

<div dir="ltr">

```bash
# Claude Code plugin marketplace
/plugin marketplace add mohamad-tn/engineering-rules
/plugin install engineering-rules@engineering-rules

# or, with the open "skills" CLI
npx skills add mohamad-tn/engineering-rules --skill engineering-rules
```

</div>

### الخيار ج: انسخ ما تحتاجه فقط

كل ملف مستقل بذاته. خذ فقط `gitleaks.toml`، أو سكربت حجم الطلب، أو `AGENTS.md`.

## الاستخدام اليومي

| أنت | تفعل |
|---|---|
| **مطوّر** | اعمل في مهام صغيرة. قبل طلب المراجعة: `bash .github/scripts/local-proof.sh` والصق المخرجات. حلقة سريعة أثناء الكتابة: `bash .github/scripts/stack-gates.sh --fast`. |
| **مساعد ذكاء اصطناعي** | اقرأ `AGENTS.md`. لا تدمج أبدًا. شغّل الإثبات. إذا غاب متطلب فاكتب سؤالًا مفتوحًا بدل التخمين. |
| **مراجع** | تأكد أن الـ commit في الإثبات هو رأس الطلب وأن كل الصفوف ناجحة (بلا `NOT RUN`). اقبل الاستثناءات المكتوبة أو ارفضها. |
| **مسؤول المشروع** | أبقِ `AGENTS.md` و`docs/rules-compliance.md` صادقين: كل قاعدة «مفروضة» أو «مراجَعة» أو «تشغيلية» أو **«مخططة»**. |

الـ CI يشغّل السكربتات نفسها: [`project-gates.yml`](skills/engineering-rules-ar/templates/project-gates.yml) للبوابات الأساسية، وworkflow صغير لكل تقنية في [`templates/stacks/`](skills/engineering-rules-ar/templates/stacks).

## ماذا بالداخل

**البوابات الأساسية** (كل مشروع): فحص الأسرار (كل التاريخ، مخرجات مخفية القيم، بلا ملف تجاهل) · فحص الوثائق (الوثائق المطلوبة، خريطة الكود إلى الوثائق، سجل التغييرات، تنسيق Markdown، الروابط الداخلية) · إعداد أداة تحديث الاعتمادات · بوابات السياسة (الإصدارات التجريبية، القيم المكتوبة للبيئة) · انتهاء أعلام الميزات · حجم الطلب.

**بوابات التقنية** (لكل تقنية): `deps` · `format` · `lint` · `types` · `test` · `build` · `audit` · وإضافية مثل `bundle-scan` و`secrets-files` و`migrations` و`mod-tidy`.

**الأنماط (Profiles)**: `lite` (العمل الفردي والنماذج الأولية: الأسرار والاعتمادات والاختبارات) · `standard` (الافتراضي) · `strict` (الفرق والمكتبات العامة: كل البوابات وحدود حجم أقل).

**وأيضًا**: قالب ملف القواعد، وقالب طلب الدمج، وCODEOWNERS، وخطاف pre-commit، وإعداد Renovate مشترك، وقوالب سجلات القرارات (ADR) والأدلة التشغيلية، وقائمة بوابة المرحلة، وخطة استمرارية التسليم (ماذا تفعل عند تعطل الـ CI)، وملفات ربط لمساعدي الذكاء الاصطناعي، و[ملحق مجال](skills/engineering-rules-ar/references/domain-optional.md) اختياري لمنتجات الموقع الجغرافي والعمل في أكثر من دولة والأسواق.

## يعمل مع أي فكرة، وليس مع نوع واحد من المنتجات

النواة تخص كيف يُسلَّم البرنامج وليس ماذا يفعل. وهي تناسب أي مشروع برمجي، بأي لغة: البوابات الأساسية تعمل دائمًا، وبوابات التثبيت وفحص الكود والاختبارات والبناء الخاصة بالتقنية تعمل عند وجود محرك مطابق. وهي مصممة لتناسب:

| المشروع | ملاحظات |
|---|---|
| تطبيقات SaaS والويب | كل البوابات؛ `Next.js` و`React` و`Laravel` و`Django` و`Rails` و`.NET` |
| تطبيقات الموبايل | `React Native` و`Expo` و`Flutter`؛ فحص مفاتيح التوقيع والروابط غير المشفّرة |
| الواجهات الخلفية (APIs) | `.NET` و`Node` و`Go` و`Java` و`Python` و`Rust` و`PHP` |
| المكتبات والحزم | اختر النمط وفق الحاجة؛ المكتبة العامة المنشورة بلا ملف قفل تحصل على تحذير بدل فشل التطبيق |
| الأدوات الداخلية والسكربتات وأدوات الطرفية | النمط `lite` |
| مواقع المحتوى والتسويق | فحص الوثائق، فحص الأسرار، بوابة الحجم |
| المستودعات الكبيرة المتعددة المشاريع (Monorepo) | كل مشروع يُكتشف ويعمل بتقنيته |
| المواقع الجغرافية، وأكثر من دولة، وأسواق الخدمات عند الطلب | أضف وحدة المجال الاختيارية؛ ولا يتغير شيء آخر |

المزيد في [`docs/ar/project-types.md`](docs/ar/project-types.md).

## كيف يعمل، ولماذا بُني هكذا

- **نواة صغيرة وملحقات اختيارية.** القواعد العامة تتسع في صفحة واحدة. والتقنيات ووحدة المجال ملفات منفصلة لا تحمّلها إلا عند الحاجة.
- **سكربتات وليست خدمة.** كل شيء `shell` و`Node`. لا حساب ولا خادم، ولا تغادر بياناتك جهازك. والأدوات التي ينزّلها مثبّتة ومتحقَّق منها بمجموع تحقق (checksum).
- **«لم يعمل شيء» لا تعني نجاحًا.** نتائج البوابات: `PASS` أو `FAIL` أو `SKIP` أو `NOT RUN` أو `N/A`. والبوابات المطلوبة تفشل عندما لا تعمل فعليًا.
- **حالة صادقة.** كل قاعدة موسومة «مفروضة» أو «مراجَعة» أو «تشغيلية» أو **«مخططة»** ([فهرس القواعد](skills/engineering-rules-ar/references/rules-index.md)).
- **يعمل بدون CI مدفوع.** إذا توقف الـ CI المستضاف فشغّل السكربتات نفسها محليًا والصق الإثبات؛ وهناك خطة بدائل بأربعة مستويات ([الاستمرارية](skills/engineering-rules-ar/references/continuity.md)).
- **الإنسان يدمج.** المساعدون لا يدمجون أبدًا.

المزيد: [`docs/ar/how-it-works.md`](docs/ar/how-it-works.md).

## مصمم لوكلاء الذكاء الاصطناعي

المهارة صغيرة عن قصد، فيصل الوكيلَ **كل** قاعدة دون أن تمتلئ نافذة سياقه.

| ما هو | الحجم (تقديري) | متى يُحمَّل |
|---|---|---|
| اسم المهارة ووصفها | حوالي 250 رمزًا (tokens) | دائمًا |
| `SKILL.md` | حوالي 1.6 ألف رمز، 80 سطرًا | عندما تُفعَّل المهارة |
| `AGENTS.md` (القواعد الملزمة كاملة) | حوالي 1.5 ألف رمز، 90 سطرًا | في كل جلسة داخل مستودع تبنّى القواعد |
| ملف مرجعي واحد | 2.6 ألف رمز كحد أقصى | فقط عندما تحتاجه المهمة |
| كل الأساسيات في ملف واحد | حوالي 7.7 ألف رمز ([`llms-full.txt`](llms-full.txt)) | للأدوات التي تجلب رابطًا واحدًا |

اختبار (`tests/test-context.sh`) يفرض هذه الميزانيات ويفشل إذا غابت قاعدة ملزمة عن ملف `AGENTS.md` الذي يُحمَّل دائمًا. والنتائج مقروءة للآلة أيضًا: `local-proof.sh --json` و`stack-gates.sh --json`، والملف [`fixing-failures.md`](skills/engineering-rules-ar/references/fixing-failures.md) يعلّم الوكيل كيف يصلح كل فشل دون تخفيف بوابة. وأعداد الرموز تقديرية؛ والعربية تستهلك تقريبًا ضعف الرموز لكل كلمة.

## الترقية

صدرت نسخة جديدة من المهارة؟ حدّث السكربتات وملفات الـ workflow دون أن تخسر تعديلاتك:

<div dir="ltr">

```bash
bash skills/engineering-rules/scripts/install.sh --target ./my-project --update
```

</div>

الملفات التي غيّرتها تبقى كما هي، وتُكتب النسخة الجديدة بجانبها بامتداد `.new`. أما `AGENTS.md` والوثائق والإعدادات فلا تُمَسّ أبدًا.

## كيف يقارن بغيره

| الأداة | ما تتقنه | ما يضيفه هذا المشروع |
|---|---|---|
| `pre-commit` و`Husky` | تشغيل الفحوص على جهاز واحد قبل الحفظ (commit) | الفحوص نفسها في الـ CI وكإثبات ملصق، مع قواعد لوكلاء الذكاء الاصطناعي |
| `MegaLinter` و`Super-Linter` | فحص كود عدة لغات في الـ CI | قواعد التسليم (تاريخ الأسرار، والوثائق مع الكود، وحجم الطلب، وانتهاء الأعلام)، وسياسة البوابات المطلوبة، وإثبات بلا CI |
| `Danger` و`reviewdog` | التعليق على طلبات الدمج | فحوص تُفشل الطلب وتعمل محليًا أيضًا وفي أي CI |
| `SonarQube` و`Snyk` و`Dependabot` | تحليل عميق لجودة الكود والثغرات | حد أدنى صغير يشغّل تدقيق نظامك البيئي؛ استخدمها معًا |
| ملف قواعد وحده (`AGENTS.md` و`CLAUDE.md`) | يخبر الوكيل ماذا يفعل | بوابات تتأكد أن الوكيل فعل ذلك فعلًا |

## مُختبَر، وليس مكتوبًا فقط

<div dir="ltr">

```bash
bash tests/run-all.sh
```

</div>

| المجموعة | ما الذي تثبته |
|---|---|
| core (الأساسية) | كل بوابة تنجح مع المدخل الصحيح وتفشل مع المدخل الخاطئ |
| stacks (التقنيات) | 46 حالة: مشاريع حقيقية جيدة ومعطوبة بـ Go وRust وPython وRuby و.NET وPHP وNode وReact (Vite) وNext.js وC++ وTerraform وDocker؛ واختبارات على مستوى الأوامر لـ Flutter وSwift وMaven وGradle وأدوات Laravel وExpo وRails |
| installer (المثبّت) | 42 حالة: التثبيت، وعدم الكتابة فوق الملفات، والخيارات، والفاحص، وإثبات محلي كامل في مستودع مُتبنٍّ (بالنسختين)، والتحديث الآمن |
| demo (العرض) | العرض «قبل وبعد» يبقى صادقًا |
| parity (التطابق) | النسخة العربية تطابق الإنجليزية: الملفات نفسها، والسكربتات متطابقة بايت ببايت، والأقسام والجداول وكتل الكود نفسها |
| portability (التوافق) | فروق macOS (إصدار bash 3.2، وأداة sed الخاصة بـ BSD، وغياب `timeout`) وفروق Git Bash، مُحاكاة؛ ومسارات فيها مسافات |
| adoption (التبنّي) | المستودعات القديمة (وثائق قديمة، وأسرار قديمة، وفرع `master`) وخرج `--json` للوكلاء |
| context (السياق) | ميزانية السياق، وكل قاعدة ملزمة مذكورة في `AGENTS.md` الذي يُحمَّل دائمًا |
| static (الفحص الثابت) | `shellcheck` وفحص الـ workflows وملفات JSON وYAML وتنسيق Markdown والروابط وخلو المستودع من أي شيء يشبه الأسرار |

بعض أدوات التشغيل لا تعمل في كل مكان؛ والمصفوفة الدقيقة، وأي جزء يعمل فعليًا، في [`docs/ar/testing.md`](docs/ar/testing.md). والـ CI الخاص بالمستودع يشغّل المجموعات على GitHub.

## أسئلة شائعة

**هل أحتاج مساعد ذكاء اصطناعي لاستخدامه؟** لا. هو مفيد لأي فريق؛ وملفات المساعدين والمهارة إضافات.

**هل سيبطئني؟** الحلقة: مهمة صغيرة، أمر واحد، لصق الإثبات. البوابات هي ما كنت ستكتشفه أصلًا في المراجعة أو في الإنتاج. استخدم `--fast` أثناء الكتابة والنمط `lite` للنماذج الأولية.

**مستودعي فوضى. من أين أبدأ؟** ابدأ بالنمط `lite`، وأصلح ما يفشل، ثم انتقل إلى `standard`. انظر [`docs/ar/adoption-guide.md`](docs/ar/adoption-guide.md).

**هل أستطيع استخدام GitLab أو Bitbucket أو Jenkins؟** نعم. البوابات سكربتات؛ استدعها من أي خط أنابيب ([`docs/ar/ci-providers.md`](docs/ar/ci-providers.md)).

**ويندوز؟** استخدم `WSL` أو `Git Bash`. السكربتات بـ `bash`.

**هل هو متشدد؟** في العملية نعم: طلبات صغيرة، وأسرار خارج Git، ووثائق مع الكود، وحالة صادقة. وكل حد وبوابة قابلان للضبط، والاستثناء وسم مع سبب مكتوب.

أسئلة أخرى: [`docs/ar/faq.md`](docs/ar/faq.md).

## خارطة الطريق وحدود صادقة

- محركات أخرى (`Kotlin Multiplatform` و`Elixir` و`Scala` و`Deno` و`Bazel`) مرحّب بها: انظر [CONTRIBUTING](CONTRIBUTING.md#add-a-stack).
- اختبارات المعمارية وفحص الترحيلات وإثباتات بناء الحاويات ومصفوفات المناطق الزمنية **مخططة**: الدليل يصفها لكنها تعتمد على كودك وقاعدة بياناتك، فليست بوابات جاهزة.
- بوابات `Flutter` و`Java` مُتحقَّق منها على مستوى الأوامر هنا، ومصفوفة CI للمستودع فيها وظائف تشغّلها بأدواتها الحقيقية. هذه الوظائف موسومة تجريبية إلى أن تبقى خضراء على GitHub.
- إذا كانت أداة اختيارية غير مثبتة (مثل `rustfmt` أو `clippy`)، يُبلَّغ عن البوابة بأنها لم تُشغَّل (NOT RUN)، وليس بأنها فشلت. والبوابات المطلوبة التي لم تُشغَّل ما تزال تُفشل البناء.
- السكربتات `bash` و`Node`؛ ولا تُدعم أصداف ويندوز الأصلية. على ويندوز استخدم WSL أو Git Bash.

## المساهمة

الأفكار وتقارير الأخطاء ومحركات التقنيات الجديدة مرحّب بها. اقرأ [CONTRIBUTING](CONTRIBUTING.md).
الأسئلة والأفكار تُطرح في [المناقشات](https://github.com/mohamad-tn/engineering-rules/discussions).
وتقارير الأخطاء وطلبات الدمج عبر [المسائل](https://github.com/mohamad-tn/engineering-rules/issues).
التزم بـ[مدونة السلوك](CODE_OF_CONDUCT.md). وللأمان: [SECURITY](SECURITY.md).

## القائمون على المشروع

[Mohamad Tonbary](https://github.com/mohamad-tn)

## الترخيص

[MIT](LICENSE). إذا وفّر عليك هذا المشروع يوم جمعة سيئًا، فنجمة تساعد غيرك على إيجاده.

</div>
