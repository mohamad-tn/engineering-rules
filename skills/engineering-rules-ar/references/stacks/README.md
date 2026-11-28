<!-- rtl -->
<div dir="rtl">

# بوابات التقنيات

أمر واحد يشغّل الفحوص المناسبة لما يحتويه مستودعك:

<div dir="ltr">

```bash
bash .github/scripts/stack-gates.sh          # every stack it finds
bash .github/scripts/stack-gates.sh --list   # just show what it detects
```

</div>

يكتشف التقنيات، ويشغّل البوابات القياسية لكل منها، ويطبع صفًا لكل بوابة. ويدعم المستودعات المتعددة المشاريع (Monorepo): مجلد `web/` (Next.js) ومجلد `api/` (Go) ومجلد `mobile/` (Expo) في مستودع واحد، لكل منها تشغيله الخاص.

## البوابات

| البوابة | السؤال الذي تجيب عنه |
|---|---|
| `deps` | هل يعمل التثبيت النظيف المقفل؟ (ملف القفل مرفوع، والتثبيت مجمّد) |
| `format` | هل الكود منسّق؟ |
| `lint` | هل ينجح فاحص الكود أو المحلل؟ |
| `types` | هل ينجح فحص الأنواع أو التحليل الساكن؟ |
| `test` | هل تنجح الاختبارات؟ |
| `build` | هل ينجح بناء الإنتاج؟ |
| `audit` | هل توجد ثغرات معروفة في الاعتمادات؟ |
| إضافية | خاصة بالتقنية: `bundle-scan` و`secrets-files` و`migrations` و`mod-tidy` و`syntax` و`pinned` |

## النتائج

| النتيجة | المعنى |
|---|---|
| `PASS` | عملت ونجحت |
| `FAIL` | عملت وفشلت (تُطبع آخر أسطر السجل) |
| `SKIP` | لا شيء لتشغيله (لا سكربت ولا إعداد) |
| `NOT RUN` | تنطبق لكن الأداة أو خدمة الشبكة غير متاحة أو محددة المعدل |
| `N/A` | لا تنطبق على هذه التقنية (لغة PHP بلا خطوة بناء) |
| `WARN` | نصيحة فقط |

**البوابات المطلوبة.** المتغير `STACK_REQUIRE` (الافتراضي `deps,test,build`) يسرد البوابات التي يجب أن تنجح. وللبوابات المطلوبة يُحسب `SKIP` و`NOT RUN` فشلًا: «لم يعمل شيء» لا تبدو أبدًا خضراء. المشروع بلا اختبارات يفشل في `test` إلى أن تكون له اختبارات. والأنماط (Profiles) تغيّر القائمة: النمط `lite` يطلب `deps,test`، والنمط `strict` يضيف `format,lint,types,audit`.

في البوابات التي تعتمد على الشبكة، تُسجّل ردود HTTP 429 وتحديد المعدل التي يتعرف عليها الفاحص كـ`NOT RUN` بدلًا من فشل الأمر. وتظل `NOT RUN` فشلًا إذا كانت البوابة مطلوبة.

## الضبط

ضع القيم في `.github/engineering-rules.env` (المثبّت يكتبه من النمط):

| المتغير | الأثر |
|---|---|
| `STACK_REQUIRE` | البوابات التي يجب أن تنجح |
| `STACK_STRICT=1` | يطلب أيضًا format وlint وtypes وaudit |
| `STACK_CMD_<GATE>` | يستبدل أمر بوابة: `STACK_CMD_TEST="make test"` |
| `STACK_SKIP_GATES` | يعطّل بوابات عن قصد (وتخرج من قائمة المطلوب) |
| `STACK_EXCLUDE` | بادئات مسارات تُتجاهل، مثل `examples/ docs/site` |
| `STACK_FAST=1` | يتخطى `build` و`audit` و`e2e` (حلقة سريعة أثناء الكتابة) |
| `AUDIT_LEVEL` | أدنى خطورة تُفشل التدقيق |

قائمة مشاريع صريحة في `.github/engineering-rules.stacks` (مثل `node:web` و`go:api`) تحل محل الاكتشاف التلقائي.

## التقنيات المدعومة ومدى اختبار كل منها

| التقنية | الأطر | المرجع | اختُبرت بـ |
|---|---|---|---|
| `node` | Node.js وReact وVue وAngular وSvelte وNestJS وExpress وVite | [node.md](node.md) | npm حقيقي ومشروع React/Vite حقيقي |
| `nextjs` | Next.js | [nextjs.md](nextjs.md) | بناء Next.js حقيقي؛ وبوابة التدقيق اكتشفت ثغرات حقيقية |
| `react-native` | React Native وExpo | [react-native.md](react-native.md) | محرك Node وفحص الملفات السرية حقيقيان؛ وأداة Expo محاكاة |
| `dotnet` | ASP.NET Core وبرامج الطرفية والمكتبات | [dotnet.md](dotnet.md) | حزمة SDK حقيقية (الاستعادة من مصدر محلي) |
| `php` | Laravel وSymfony وحزم Composer | [laravel.md](laravel.md) | PHP وComposer حقيقيان؛ وأدوات Pint وPHPStan و`artisan` محاكاة |
| `flutter` | Flutter وDart | [flutter.md](flutter.md) | اختبارات على مستوى الأوامر بحزمة محاكاة؛ والتشغيل الحقيقي في مصفوفة CI للمستودع |
| `python` | Django وFastAPI وFlask والمكتبات | [python.md](python.md) | pip وpytest وruff حقيقية |
| `java` | Spring Boot وMaven وGradle وKotlin | [java.md](java.md) | اختبارات على مستوى الأوامر بأدوات بناء محاكاة |
| `go` | وحدات Go | [go.md](go.md) | أدوات Go حقيقية |
| `rust` | Cargo | [rust.md](rust.md) | cargo وrustfmt وclippy حقيقية |
| `ruby` | Rails والحزم (gems) | [ruby.md](ruby.md) | Ruby وBundler حقيقيان؛ وRails وRuboCop محاكاة |
| `cpp` | C وC++ (CMake) | [cpp.md](cpp.md) | `cmake` و`g++` و`cppcheck` و`clang-format` حقيقية |
| `terraform` | Terraform وOpenTofu | [terraform.md](terraform.md) | OpenTofu حقيقي |
| `docker` | ملفات Dockerfile | [docker.md](docker.md) | `hadolint` حقيقي |
| `swift` | مدير حزم Swift (SwiftPM) | [swift.md](swift.md) | اختبارات على مستوى الأوامر بأدوات محاكاة |

«محاكاة» تعني أن أوامر المحرك وترتيبها ومعالجته للفشل تم التحقق منها، لكن الأداة الحقيقية لم تُشغَّل في بيئة الاختبار. المصفوفة الدقيقة في `docs/ar/testing.md` في المستودع.

## إضافة تقنية

انظر `CONTRIBUTING.md` في المستودع: المحرك ملف واحد في `scripts/stacks/<name>.sh`، وworkflow واحد في `templates/stacks/<name>/ci.yml`، ومرجع واحد هنا، ومشروع اختبار جيد وآخر معطوب في `tests/`.

</div>
