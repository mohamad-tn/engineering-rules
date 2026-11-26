<!-- rtl -->
<div dir="rtl">

# C وC++ (CMake)

المحرك: `scripts/stacks/cpp.sh`. يكتشف ملف `CMakeLists.txt`؛ ومشاريع CMake المتداخلة تتبع المشروع الذي فوقها.

| البوابة | ما تشغّله |
|---|---|
| `deps` | `cmake -S . -B <مجلد مؤقت>` (التهيئة؛ ويبقى مستودعك نظيفًا) |
| `format` | `clang-format --dry-run --Werror` عند وجود ملف `.clang-format` |
| `lint` | `cppcheck` (التحذيرات والنقل بين المنصات، والأخطاء تُفشل) عند تثبيته |
| `build` | `cmake --build <المجلد> --parallel` |
| `test` | `ctest --output-on-failure` عند تسجيل اختبارات (`enable_testing` و`add_test`) |

البوابتان `types` و`audit` تُسجَّلان `N/A`: المترجم هو فاحص الأنواع، ولا توجد أداة تدقيق قياسية للغتي C وC++.

## الإعداد الموصى به

- ارفع ملف `.clang-format`؛ وأضف `-Wall -Wextra` (و`-Werror` في الـ CI) إلى أهدافك.
- سجّل الاختبارات في CTest حتى يجد بوابة `test` ما تشغّله.
- ثبّت الاعتمادات بمدير حزمك (`vcpkg` أو `Conan`) وارفع ملف القفل أو البيان (manifest).

## التكامل المستمر (CI)

الملف `templates/stacks/cpp/ci.yml` يثبّت `cmake` و`cppcheck` و`clang-format` على جهاز Ubuntu.

</div>
