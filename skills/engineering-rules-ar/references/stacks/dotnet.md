<!-- rtl -->
<div dir="rtl">

# .NET

المحرك: `scripts/stacks/dotnet.sh`. يعمل على حل (`.sln` أو `.slnx`) أو على مشروع.

| البوابة | ما تشغّله |
|---|---|
| `sdk-pin` | وجود `global.json` (تحذير إن غاب) |
| `deps` | `dotnet restore --locked-mode` عند وجود `packages.lock.json` |
| `format` | `dotnet format --verify-no-changes` |
| `build` | `dotnet build -c Release -warnaserror` |
| `test` | `dotnet test` عند وجود مشروع اختبار (`Microsoft.NET.Test.Sdk`) |
| `audit` | `dotnet list package --vulnerable --include-transitive`؛ ولا ينجح إلا إذا قالت الأداة «لا حزم معرّضة» |

## الإعداد الموصى به

- الملف `Directory.Build.props`: تفعيل `Nullable`، والتحذيرات أخطاء، والمحللات، و`RestorePackagesWithLockFile`.
- الملف `global.json` مع `rollForward: disable`.
- إعدادات اختيارية: `templates/stacks/dotnet/configs/`.
- ترحيلات قاعدة البيانات (EF Core): ارفع SQL الآمن التكرار، وافحصه، وطبّقه على قاعدة فارغة في الـ CI، ولا ترحّل أبدًا عند بدء التطبيق. أضفها كوظائف إضافية فهي تعتمد على قاعدة بياناتك.

## التكامل المستمر (CI)

الملف `templates/stacks/dotnet/ci.yml` (`setup-dotnet` من `global.json`).

## ملاحظات

يجب أن يكون `NuGet` متاحًا لبوابة `deps`. وعندما لا يكون كذلك تُبلِّغ البوابة `NOT RUN` وليس `PASS`.

</div>
