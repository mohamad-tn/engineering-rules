<!-- rtl -->
<div dir="rtl">

# كيف يعمل

## القطع

| القطعة | أين | مهمتها |
|---|---|---|
| ملف القواعد | `AGENTS.md` (من `templates/AGENTS.md`) | الملف القصير الواحد الذي يتبعه البشر ومساعدو الذكاء الاصطناعي |
| البوابات الأساسية | `scripts/*.sh` و`scripts/*.mjs` و`templates/docs-check.*` و`templates/pr-size-check.sh` | تُفشل طلب الدمج بسبب الأسرار، والوثائق الناقصة، والإعدادات المكتوبة في الكود، والاعتمادات التجريبية، وأعلام الميزات المنتهية، والتغييرات الضخمة |
| بوابات التقنية | `scripts/stack-gates.sh` و`scripts/stacks/<engine>.sh` | تكتشف التقنيات وتشغّل التثبيت والتنسيق وفحص الكود والأنواع والاختبارات والبناء والتدقيق لكل منها |
| الإثبات | `scripts/local-proof.sh` | يشغّل كل شيء ويطبع كتلة لطلب الدمج |
| التكامل المستمر (CI) | `templates/project-gates.yml` و`templates/stacks/*/ci.yml` | تستدعي السكربتات نفسها على GitHub Actions |
| الإعداد | `scripts/install.sh` و`scripts/doctor.sh` | أمر واحد للتبنّي وآخر للفحص |
| المهارة | `SKILL.md` و`references/` | تخبر مساعد الذكاء الاصطناعي كيف يتبنّى ويلتزم |

## الحلقة

<div dir="ltr">

```text
roadmap -> phase -> task (about one pull request, about 400 lines)
        -> gates (CI, or local-proof.sh with the output pasted in the pull request)
        -> human review -> human merge -> phase gate at the end of each phase
```

</div>

## قرارات التصميم

**سكربتات وليست خدمة.** البوابة سكربت له رمز خروج. لهذا تعمل في أي CI وعلى الجهاز، ولا يوجد شيء تستضيفه أو تسجّل فيه أو تأتمنه على كودك.

**مفردات نتائج موحّدة.** كل بوابة تقنية تنتهي بـ `PASS` أو `FAIL` أو `SKIP` أو `NOT RUN` أو `N/A`. والمشغّل يحوّل `SKIP` و`NOT RUN` إلى فشل للبوابات التي تطلبها (`STACK_REQUIRE`)، فلا يستطيع غياب أداة أو غياب اختبارات أن يتنكر في هيئة نجاح. ويُحجز `N/A` لما لا وجود له في التقنية (لغة PHP بلا خطوة بناء).

**اكتشاف تلقائي مع تجاوز صريح.** تُكتشف التقنيات من ملفات الدلالة (`package.json` و`go.mod` و`Cargo.toml` و`*.csproj` و`composer.json` و`pubspec.yaml` و`pyproject.toml` و`pom.xml` و`Gemfile`...). ويمكنك سرد المشاريع صراحة في `.github/engineering-rules.stacks` واستبدال أمر أي بوابة بـ `STACK_CMD_<GATE>`.

**أدوات مثبّتة ومتحقَّق منها.** الأدوات التي تنزّلها البوابات (`gitleaks` و`lychee` ومدققات تعمل عبر `npx`) مثبّتة في `.github/tool-pins.env`؛ والملفات التنفيذية المنزَّلة يُتحقق من SHA-256 لها قبل أن تعمل. وإجراءات GitHub Actions في القوالب مثبّتة على commit SHA.

**الأسرار تُغيَّر ولا تُتجاهل.** فحص الأسرار يقرأ كل تاريخ Git، ويخفي قيم مخرجاته، ويرفض ملف `.gitleaksignore`.

**الاستثناءات ظاهرة.** `no-docs-needed` و`pr-size-reason` وسمان مع سبب مكتوب في الطلب؛ والمراجع يقبل أو يرفض.

**حالة صادقة.** القواعد: «مفروضة» أو «مُنجزة» أو «مراجَعة» أو «تشغيلية» أو «مخططة». والمخططة لا تُقرأ أبدًا كأنها مفروضة.

## ما الذي يشغّل كودك

بوابات التقنية تشغّل أوامر **مشروعك نفسه** (`npm test` و`go test` و`cargo build`...). تعامل مع طلب دمج من نسخة (fork) غير موثوقة كما تتعامل مع أي كود غير موثوق في الـ CI: الـ workflows المرفقة تستخدم `pull_request` (وليس `pull_request_target`)، وصلاحيات قراءة فقط، و`persist-credentials: false`.

## استمرارية التسليم

عندما يتعذر الـ CI المستضاف هناك أربعة مستويات: مستضاف، و`runner` ذاتي الاستضافة، وإعادة تشغيل ملفات الـ workflow محليًا بأداة `act`، وبدون اتصال إطلاقًا. البوابات والمراجعة لا تُخفَّف أبدًا، والمساعدون لا يدمجون أبدًا. التفاصيل: [`continuity.md`](../../skills/engineering-rules-ar/references/continuity.md).

</div>
