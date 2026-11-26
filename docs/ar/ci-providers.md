<!-- rtl -->
<div dir="rtl">

# مزوّدو CI (وبدون CI إطلاقًا)

كل بوابة أمر. و`GitHub Actions` للراحة وليس شرطًا.

## بدون CI

<div dir="ltr">

```bash
bash .github/scripts/local-proof.sh        # all gates, prints a Markdown block for the pull request
```

</div>

## GitLab CI

<div dir="ltr">

```yaml
gates:
  image: ubuntu:24.04
  before_script:
    - apt-get update && apt-get install -y git curl jq nodejs
  script:
    - bash .github/scripts/gitleaks-scan.sh .gitleaks.toml
    - bash .github/scripts/docs-check.sh .
    - node .github/scripts/policy-gates.mjs .
    - node .github/scripts/feature-flag-expiry.mjs .
    - BASE_SHA="$CI_MERGE_REQUEST_DIFF_BASE_SHA" HEAD_SHA="$CI_COMMIT_SHA" bash .github/scripts/pr-size-check.sh
    - bash .github/scripts/stack-gates.sh --root .
  variables:
    GIT_DEPTH: "0"
```

</div>

## Bitbucket Pipelines

<div dir="ltr">

```yaml
pipelines:
  pull-requests:
    "**":
      - step:
          name: gates
          script:
            - bash .github/scripts/local-proof.sh --base "$(git merge-base origin/main HEAD)"
```

</div>

## Jenkins

<div dir="ltr">

```groovy
stage('Gates') {
  steps { sh 'bash .github/scripts/local-proof.sh --base "$(git merge-base origin/main HEAD)"' }
}
```

</div>

## ملاحظات

- اجلب التاريخ كاملًا (`GIT_DEPTH=0` أو `fetch-depth: 0`): فحص الأسرار يقرأ كل التاريخ ويرفض النسخة السطحية (shallow clone).
- وفّر أدوات التقنية التي تحتاجها على الـ runner (قوالب الـ workflow لكل تقنية توضح أيها).
- قاعدتا سجل التغييرات وخريطة الوثائق في فحص الوثائق تحتاجان عنوان الطلب ووسومه: المتغيران `PR_TITLE` و`PR_LABELS_JSON` (انظر [`docs-check.sh`](../../skills/engineering-rules-ar/templates/docs-check.sh)).

</div>
