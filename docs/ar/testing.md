<!-- rtl -->
<div dir="rtl">

# الاختبار

<div dir="ltr">

```bash
bash tests/run-all.sh              # everything
bash tests/run-all.sh stacks       # one suite: core | stacks | installer | portability | adoption | demo | parity | context | static
```

</div>

## المجموعات

| المجموعة | الملف | ما تفحصه |
|---|---|---|
| core | `skills/engineering-rules/scripts/selftest.sh` | حجم الطلب، وفحص الوثائق، وبوابات السياسة، وانتهاء الأعلام، وقفل SHA-256، وحدث CI بدون اتصال: كل منها ينجح مع المدخل الجيد ويفشل مع المعطوب |
| stacks | `tests/test-stacks.sh` و`tests/test-quality.py` و`tests/test-proof-quality.py` | مشاريع المحركات، والنتائج المطلوبة، والاستبدالات، والمستودعات المتعددة، والمسارات، ونقل فشل التدقيق، ودلالة الإثبات الجزئي؛ محاكاة الأوامر لا تستبدل اختبار SDK حقيقيًا |
| installer | `tests/test-installer.sh` | التثبيت في مستودعات، وعدم الكتابة فوق الملفات، والخيارات، و`doctor.sh`، وإثبات محلي كامل في مستودع مُتبنٍّ |
| demo | `tests/test-demo.sh` | العرض «قبل وبعد» يُفشل خمس بوابات للأسباب المذكورة، ثم ينجح في كلها |
| portability | `tests/test-portability.sh` | فروق macOS (إصدار bash 3.2، وأداة sed الخاصة بـ BSD، وغياب `timeout`) وفروق Git Bash، مُحاكاة بأدوات بديلة؛ ومسارات فيها مسافات |
| adoption | `tests/test-adoption.sh` | المستودعات القديمة (وثائق قديمة، وأسرار قديمة في التاريخ، وفرع `master`) وخرج `--json` و`--quiet` |
| context | `tests/test-context.sh` | ميزانية السياق، وكل قاعدة ملزمة مذكورة في `AGENTS.md` الذي يُحمَّل دائمًا |
| parity | `tests/test-parity.sh` | للنسخة العربية الملفات نفسها وسكربتات متطابقة بايت ببايت، والأقسام والجداول وكتل الكود نفسها كما في الإنجليزية |
| static | `tests/test-static.sh` | `shellcheck` و`bash -n` و`node --check` وJSON وYAML و`actionlint` و`markdownlint` والروابط الداخلية وخلو المستودع من النصوص التي تشبه الأسرار وملفات المفاتيح |

## أي أدوات تعمل فعليًا

«حقيقي» تعني أن المترجم الفعلي ومدير الحزم وأدوات الفحص عملت في بيئة الاختبار. و«محاكاة» تعني أن برنامجًا بديلًا سجّل الأوامر التي أصدرها المحرك (الترتيب والمعاملات ومعالجة الفشل)؛ لكن الأداة الحقيقية لم تُشغَّل هناك.

| التقنية | مشروع الاختبار | النتيجة في بيئة اختبار المؤلف |
|---|---|---|
| `Go` | `go/good` و`go/bad` | حقيقي |
| `Rust` | `rust/good` و`rust/bad` | `cargo` حقيقي؛ و`rustfmt` و`clippy` عند تثبيتهما، وإلا تُبلَّغ هذه البوابات بأنها لم تُشغَّل (NOT RUN) |
| `Python` | `python/good` و`bad` و`unpinned` | حقيقي (`pip` و`pytest` و`ruff`) |
| `Ruby` | `ruby/good` و`ruby/bad` | حقيقي (`Bundler`)؛ و`RuboCop` و`Rails` غير مثبّتين |
| `.NET` | `dotnet/good` و`dotnet/bad` | حزمة SDK 10 حقيقية (`net10.0`)؛ استعادة من مصدر محلي لأن `NuGet` لم يكن متاحًا |
| `PHP` و`Laravel` | `php/good` و`php/bad` و`laravel/good` | `PHP` و`Composer` حقيقيان؛ و`Pint` و`PHPStan` و`artisan` محاكاة |
| `Node` | `node/good` و`bad` و`nolock` | حقيقي |
| `React` (مع Vite) | `react/good` | تثبيت وبناء حقيقيان |
| `Next.js` | `nextjs/good` | تثبيت وبناء حقيقيان؛ وبوابة التدقيق أبلغت عن ثغرات حقيقية |
| `React Native` و`Expo` | `expo/good` و`expo/bad` | محرك Node وفحص الملفات السرية حقيقيان؛ وأداة Expo محاكاة |
| `C` و`C++` (CMake) | `cpp/good` و`cpp/bad` | حقيقي (`cmake` و`g++` و`cppcheck` و`clang-format`) |
| `Terraform` و`OpenTofu` | `terraform/good` و`terraform/bad` | حقيقي (OpenTofu) |
| `Docker` | `docker/good` و`docker/bad` | حقيقي (`hadolint`)؛ ولم يُشغَّل `docker build` |
| `Swift` | `swift/good` | أدوات Swift محاكاة |
| `Flutter` | `flutter/good` | حزمة SDK محاكاة |
| `Java` (Maven وGradle) | `java-maven/good` و`java-gradle/good` | أغلفة محاكاة |
| `Rails` | `rails/good` | `Bundler` و`bin/rails` محاكاة |

والـ CI الخاص بالمستودع (`.github/workflows/ci.yml`) يشغّل المجموعات نفسها على أجهزة GitHub، حيث معظم الأدوات مثبّتة مسبقًا، ويضيف وظيفتين تشغّلان `Flutter` و`Java` بأدواتهما الحقيقية. هاتان الوظيفتان موسومتان تجريبيتين إلى أن تنجحا على GitHub لفترة.

## إضافة مشروع اختبار

مشروع جيد ينجح وآخر معطوب يفشل، تحت `tests/fixtures/<stack>/`، مع حالة في `tests/test-stacks.sh`. أبقِ المشاريع صغيرة وبلا اعتمادات قدر الإمكان ليبقى الاختبار سريعًا. ولا تضع أسرارًا أو ملفات مفاتيح أو ملفات `.env` في مشاريع الاختبار: المجموعة الثابتة تفشل البناء.

</div>
