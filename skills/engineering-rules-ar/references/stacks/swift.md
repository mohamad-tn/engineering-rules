<!-- rtl -->
<div dir="rtl">

# Swift (مدير حزم Swift)

المحرك: `scripts/stacks/swift.sh`. يكتشف ملف `Package.swift`: لغة Swift على الخادم والحزم. أما مشاريع تطبيقات Xcode فتُبنى بـ `xcodebuild` في وظيفتك الخاصة (تحتاج توقيعًا وحزم المنصات).

| البوابة | ما تشغّله |
|---|---|
| `deps` | `swift package resolve`؛ ويحذّر إن لم يُرفع `Package.resolved` |
| `format` | `swiftformat --lint .` أو `swift-format lint --strict` عند تثبيتهما |
| `lint` | `swiftlint lint --strict` عند تثبيته |
| `test` | `swift test` |
| `build` | `swift build` |

البوابتان `types` و`audit` تُسجَّلان `N/A` (المترجم يفحص الأنواع، ولا توجد أداة تدقيق في SwiftPM).

## التكامل المستمر (CI)

الملف `templates/stacks/swift/ci.yml` يعمل على جهاز macOS ويثبّت إصدار bash حديثًا (macOS يأتي بإصدار 3.2).

## حالة الاختبار

مُتحقَّق منها على مستوى الأوامر بأدوات محاكاة؛ وأدوات Swift الحقيقية لم تتوفر حيث كُتبت هذه المجموعة. انظر `docs/ar/testing.md`.

</div>
