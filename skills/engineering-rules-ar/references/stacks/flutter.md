<!-- rtl -->
<div dir="rtl">

# Flutter وDart

المحرك: `scripts/stacks/flutter.sh`. يستخدم `flutter` للتطبيقات و`dart` للحزم البحتة.

| البوابة | ما تشغّله |
|---|---|
| `deps` | `pub get` ثم يفشل إذا تغيّر `pubspec.lock` |
| `format` | `dart format --output=none --set-exit-if-changed .` |
| `lint` | `flutter analyze` (أو `dart analyze --fatal-infos`) |
| `test` | `flutter test` عند وجود `test/*_test.dart` |
| `build` | فقط عند ضبط `STACK_FLUTTER_BUILD`، مثل `apk --debug` |
| `secrets-files` | ملفات مفاتيح وبيانات اعتماد مرفوعة تحت `android/` و`ios/` |

المثبّت يضبط `STACK_REQUIRE=deps,test` لمشاريع Flutter لأن البناء يحتاج حزم المنصات. أضف `build` إلى `STACK_REQUIRE` عندما يبني الـ CI لديك.

## الإعداد الموصى به

- ارفع `pubspec.lock` للتطبيقات.
- الملف `analysis_options.yaml` مع `flutter_lints` وتحليل صارم (`templates/stacks/flutter/configs/`).
- أبقِ مفاتيح التوقيع و`key.properties` خارج Git.
- لا توجد أداة تدقيق رسمية لـ `pub`؛ اعتمد على أداة تحديث الاعتمادات.

## التكامل المستمر (CI)

الملف `templates/stacks/flutter/ci.yml` (`flutter-action` مع التخزين المؤقت).

</div>
