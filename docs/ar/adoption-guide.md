<!-- rtl -->
<div dir="rtl">

# دليل التبنّي

## اختر نمطًا (Profile)

| النمط | لمن | حد الحجم (تحذير / فشل) | بوابات التقنية المطلوبة |
|---|---|---|---|
| `lite` | العمل الفردي والنماذج الأولية | 600 / 1200 | `deps` و`test` |
| `standard` | معظم المنتجات (الافتراضي) | 400 / 800 | `deps` و`test` و`build` |
| `strict` | الفرق والمنتجات المنظَّمة والمكتبات العامة | 300 / 600 | كما في standard مع `format` و`lint` و`types` و`audit` |

النمط ملف صغير هو `.github/engineering-rules.env`. عدّل أي قيمة فيه لاحقًا.

## مستودع جديد

<div dir="ltr">

```bash
bash skills/engineering-rules/scripts/install.sh --target ./my-project --profile standard
```

</div>

املأ الأماكن المحجوزة، وشغّل `doctor.sh`، واحفظ في commit، وشغّل `local-proof.sh`. انتهى.

## مستودع قائم (الطريق الواقعي)

1. ثبّت بالنمط `--profile lite`. لا يُكتب فوق أي شيء.
2. شغّل `bash .github/scripts/local-proof.sh`. توقّع إخفاقات؛ هي قائمة عملك المتراكمة.
3. أصلح الأهم أولًا: الأسرار المرفوعة (غيّرها)، ثم ملفات القفل الناقصة، ثم الاختبارات الفاشلة.
3أ. الـ Markdown القديم الفوضوي لا يمنعك: في النمطين `lite` و`standard` تُفحص فقط الملفات التي يغيّرها طلب الدمج وتُفحص روابطها (والخيار `DOCS_LINT_SCOPE=all` يفحص كل شيء).
3ب. أسرار قديمة في التاريخ: غيّرها، وسجّل ADR، ثم اضبط `SECRET_SCAN_FROM=<commit التبنّي>` في `.github/engineering-rules.env`. عندها يغطي الفحص الـ commits الأحدث فقط ويقول ذلك بوضوح.
4. لبوابة لا تستطيع تحقيقها الآن، عطّلها **عن قصد**: `STACK_SKIP_GATES=audit` في `.github/engineering-rules.env` مع تعليق مؤرَّخ ومهمة لإزالته. البوابة التي عطّلتها تخرج من قائمة المطلوب؛ أما التي «لا تفعل شيئًا» بصمت فلا تخرج.
5. انتقل إلى `standard` عندما ينجح `lite`، ثم `strict` عندما تريد.

تاريخ قديم فيه سر: غيّر السر. إعادة كتابة تاريخ مشترك قرار منفصل؛ ولا يُوجَّه فحص الأسرار نحو الـ commits الجديدة فقط إلا بعملية فريقك، وليس بملف تجاهل أبدًا.

## مستودع كبير متعدد المشاريع (Monorepo)

يُكتشف كل مشروع (`web/` بـ Next.js و`api/` بـ Go و`mobile/` بـ Expo...) ويأخذ تشغيله الخاص. استخدم `STACK_EXCLUDE="examples/ third_party/"` لتجاهل مجلدات، أو `.github/engineering-rules.stacks` لسرد المشاريع. لكل تقنية ملف workflow خاص بها يشغّل محركها فقط (`--engine`).

## عدة مستودعات (الخلفية، والويب، والموبايل، والبنية)

مستودع واحد (`infra`) يملك البوابات المشتركة وملف القواعد وتثبيت الأدوات. والباقي يستخدم `--layout member` الذي يثبّت `project-gates.multi-repo.yml`: يستدعي إجراءات مركّبة (composite actions) من `infra` مثبّتة على commit تمت مراجعته، فلا يستطيع مستودع إضعاف بوابة. أبقِ `AGENTS.md` واحدًا؛ وافتح طلبات التحديث بـ `scripts/sync-rules-file.sh`. تخطيط `infra` موصوف في [`templates/shared-actions/`](../../skills/engineering-rules-ar/templates/shared-actions).

## ترقية القواعد المثبّتة

<div dir="ltr">

```bash
bash skills/engineering-rules/scripts/install.sh --target ./my-project --update
```

</div>

الخيار `--update` يحدّث فقط ما تملكه المهارة (`.github/scripts/**` وملفات الـ workflow الخاصة بالبوابات). ويتذكر ما ثبّته في `.github/engineering-rules.manifest`: الملف الذي لم تلمسه يُحدَّث؛ والملف الذي عدّلته يبقى كما هو وتُكتب النسخة الجديدة بجانبه بامتداد `.new` لتقارن وتدمج. أما `AGENTS.md` والوثائق وCODEOWNERS والإعدادات فلا تُمَسّ أبدًا. وإذا اختلف `.github/tool-pins.env` عن تثبيتات النسخة الجديدة فيُخبَرك بذلك.

## حماية الفرع (إعداد وليس ملفًا)

على الفرع الافتراضي: اطلب طلب دمج، وموافقة واحدة، ومراجعة أصحاب الكود، ونجاح الفحصين `project-gates / gates` وفحوص `stack-*`؛ وامنع الدفع بالقوة. الأداة `doctor.sh` تقرأ هذه الإعدادات عند توفر `gh`.

## عادات اليوم التالي

- حدّث `docs/status.md` عند بداية كل مرحلة ونهايتها.
- أبقِ `docs/rules-compliance.md` صادقًا؛ وعُدّ صفوف «مخطط» واجعل الرقم ينخفض.
- راجع `.github/tool-pins.env` وإعداد Renovate المشترك بجدول زمني.

</div>
