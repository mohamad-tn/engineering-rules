<!-- rtl -->
<div dir="rtl">

# Node.js وReact وVue وAngular وSvelte وNestJS وExpress

المحرك: `scripts/stacks/node.sh`. يكتشف الإطار من `package.json` ومدير الحزم من ملف القفل (`npm` أو `pnpm` أو `yarn` بنوعيه أو `bun`).

| البوابة | ما تشغّله |
|---|---|
| `deps` | `npm ci` أو `pnpm install --frozen-lockfile` أو `yarn install --immutable` أو `bun install --frozen-lockfile`. يفشل التطبيق بلا ملف قفل؛ أما المكتبة العامة بلا قفل فتحصل على تحذير ويُثبّت اعتمادها دون إنشاء ملف قفل. |
| `format` | سكربت `format:check`، وإلا `Prettier` أو `Biome` إن كانا مضبوطين |
| `lint` | سكربت `lint`، وإلا `ESLint` أو `Biome` إن كانا مضبوطين |
| `types` | سكربت `typecheck`، وإلا `tsc --noEmit` عند وجود `tsconfig.json` |
| `test` | سكربت `test` (النص الافتراضي «no test specified» يُحسب بلا اختبارات) |
| `build` | سكربت `build` |
| `audit` | `npm audit --omit=dev` أو `pnpm audit --prod` أو `yarn audit` بمستوى `AUDIT_LEVEL` |
| `dup` | `jscpd` عند وجود `.jscpd.json` |

## الإعداد الموصى به

- ثبّت بيئة التشغيل: `.nvmrc` مع `"engines"` مع `.npmrc` فيه `engine-strict=true`.
- استخدم إصدارات دقيقة في `package.json` وارفع ملف القفل.
- أعطِ كل بوابة سكربتًا باسم قياسي حتى يشغّل الـ CI وجهازك الشيء نفسه.
- إعدادات اختيارية: `templates/stacks/node/configs/` (الملفان `.jscpd.json` و`.npmrc`).

## التكامل المستمر (CI)

الملف `templates/stacks/node/ci.yml` (`setup-node` ثم `stack-gates.sh --engine node`). مع `pnpm` أو `yarn` أضف خطوة `corepack enable` قبل البوابات. وخطوة `scope` تتخطى العمل الثقيل لطلبات الوثائق فقط مع بقاء الفحص المطلوب يُبلِّغ.

## ملاحظات

- مساحات العمل (Workspaces): الجذر يشغّل كل شيء، ولا تُشغَّل الحزم الفرعية مرتين. احتفظ بملف قفل واحد فقط في المشروع/مساحة العمل المكتشفة؛ وجود عدة ملفات ضمن البحث حتى جذر Git يفشل `deps` بدل اختيار مدير حزم بصمت.
- لا توجد بوابات خاصة بـ `React` و`Vue` و`Angular` و`Svelte` و`Vite` غير `build`. اضبط `CLIENT_BUNDLE_DIR` و`API_BASE_URL` لتفحص الحزمة المبنية أيضًا بحثًا عن مضيف خادم خاص.

</div>
