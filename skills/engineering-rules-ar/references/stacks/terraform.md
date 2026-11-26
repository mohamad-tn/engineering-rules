<!-- rtl -->
<div dir="rtl">

# Terraform وOpenTofu

المحرك: `scripts/stacks/terraform.sh`. يكتشف المجلدات التي فيها ملفات `*.tf`. يستخدم `terraform`، أو `tofu` عندما يكون هو المثبّت وحده (والمتغير `STACK_TF_BIN` يختار واحدًا).

| البوابة | ما تشغّله |
|---|---|
| `deps` | `init -backend=false -input=false` (بلا حالة ولا بيانات اعتماد سحابية) |
| `format` | `fmt -check -recursive -diff` |
| `types` | `validate` |
| `lint` | `tflint` عند تثبيته |
| `test` | `test` عند وجود ملفات `*.tftest.hcl` (وإلا `N/A`) |
| `audit` | `trivy config` أو `tfsec` لنتائج الخطورة العالية والحرجة (`NOT RUN` إن لم يوجد أي منهما) |

يحذّر عندما لا يكون `.terraform.lock.hcl` مرفوعًا: هذا الملف يثبّت إصدارات المزوّدين.

## الإعداد الموصى به

- ارفع `.terraform.lock.hcl`؛ وثبّت إصدارات المزوّدين والوحدات.
- أبقِ الحالة (state) بعيدة ولا ترفعها إلى Git أبدًا؛ فحص الأسرار يمنع ملفات الحالة التي فيها بيانات اعتماد.
- شغّل `plan` في خط أنابيب منفصل مراجَع ببيانات اعتماد حقيقية؛ وهذه البوابات لا تحتاج أيًّا منها.

## التكامل المستمر (CI)

الملف `templates/stacks/terraform/ci.yml` يثبّت OpenTofu بإصدار مثبّت ومتحقَّق منه. ولاستخدام Terraform من HashiCorp استخدم إجراء `hashicorp/setup-terraform` مثبّتًا على commit SHA.

</div>
