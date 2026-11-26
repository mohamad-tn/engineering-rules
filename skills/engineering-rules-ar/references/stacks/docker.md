<!-- rtl -->
<div dir="rtl">

# Docker

المحرك: `scripts/stacks/docker.sh`. يكتشف الملفات `Dockerfile` و`Dockerfile.*` و`*.Dockerfile` في مجلد.

| البوابة | ما تشغّله |
|---|---|
| `lint` | `hadolint` على كل ملف Dockerfile (`NOT RUN` إن لم يكن مثبّتًا) |
| `build` | فقط عند ضبط `STACK_DOCKER_BUILD=1` وتوفر Docker: `docker build -f <file> .` |

بدون `STACK_DOCKER_BUILD=1` تكون بوابة البناء `N/A`: بناء الصور يحتاج خدمة تعمل في الخلفية (daemon) ويستغرق وقتًا.

## الإعداد الموصى به

- ثبّت الصور الأساسية بوسم (والأفضل بـ digest)، وتجنب `latest`، وشغّل التطبيق بمستخدم رقمي غير جذري (non-root).
- ثبّت إصدارات الحزم حيثما تسمح التوزيعة (`apk add pkg=1.2.3-r0`).
- ملف `.dockerignore` واحد حتى لا تدخل الأسرار ومجلد `node_modules` إلى سياق البناء.
- ثبّت `hadolint` بإصدار محدد في الـ CI (قالب الـ workflow يوضح تثبيتًا متحققًا منه بمجموع تحقق).

## التكامل المستمر (CI)

الملف `templates/stacks/docker/ci.yml`.

</div>
