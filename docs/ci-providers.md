# CI providers (and no CI at all)

Every gate is a command. GitHub Actions is a convenience, not a requirement.

## No CI

```bash
bash .github/scripts/local-proof.sh        # all gates, prints a Markdown block for the pull request
```

## GitLab CI

```yaml
gates:
  image: ubuntu:24.04
  before_script:
    - apt-get update && apt-get install -y git curl jq nodejs python3
  script:
    - export BASE_SHA="$CI_MERGE_REQUEST_DIFF_BASE_SHA" HEAD_SHA="$CI_COMMIT_SHA" PR_TITLE="$CI_MERGE_REQUEST_TITLE"
    - export PR_LABELS_JSON="$(python3 -c 'import json,os; print(json.dumps([x.strip() for x in os.getenv("CI_MERGE_REQUEST_LABELS", "").split(",") if x.strip()]))')"
    - bash .github/scripts/gitleaks-scan.sh .gitleaks.toml
    - bash .github/scripts/docs-check.sh .
    - if [ -f renovate.json ]; then bash .github/scripts/renovate-config-check.sh .; fi
    - node .github/scripts/policy-gates.mjs .
    - node .github/scripts/feature-flag-expiry.mjs .
    - BASE_SHA="$CI_MERGE_REQUEST_DIFF_BASE_SHA" HEAD_SHA="$CI_COMMIT_SHA" bash .github/scripts/pr-size-check.sh
    - bash .github/scripts/stack-gates.sh --root .
  variables:
    GIT_DEPTH: "0"
```

## Bitbucket Pipelines

```yaml
pipelines:
  pull-requests:
    "**":
      - step:
          name: gates
          script:
            - bash .github/scripts/local-proof.sh --base "$(git merge-base origin/main HEAD)"
```

## Jenkins

```groovy
stage('Gates') {
  steps { sh 'bash .github/scripts/local-proof.sh --base "$(git merge-base origin/main HEAD)"' }
}
```

## Notes

- Fetch full history (`GIT_DEPTH=0`, `fetch-depth: 0`): the secret scan reads all of it and refuses a shallow clone.
- Provide the toolchains your stack needs on the runner (the per-stack workflow templates show which).
- The docs-check changelog and docs-map rules need the pull-request title and labels:
  `PR_TITLE` and `PR_LABELS_JSON` (see [`docs-check.sh`](../skills/engineering-rules/templates/docs-check.sh)).
