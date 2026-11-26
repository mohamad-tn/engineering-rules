# Terraform and OpenTofu

Engine: `scripts/stacks/terraform.sh`. Detects directories that contain `*.tf` files. Uses `terraform`, or `tofu` when
only that is installed (`STACK_TF_BIN` chooses one).

| Gate | Runs |
|---|---|
| deps | `init -backend=false -input=false` (no state, no cloud credentials needed) |
| format | `fmt -check -recursive -diff` |
| types | `validate` |
| lint | `tflint` when installed |
| test | `test` when `*.tftest.hcl` files exist (otherwise N/A) |
| audit | `trivy config` or `tfsec` for HIGH and CRITICAL findings (NOT RUN if neither is installed) |

It warns when `.terraform.lock.hcl` is not committed: that file pins provider versions.

## Recommended setup

- Commit `.terraform.lock.hcl`; pin provider and module versions.
- Keep state remote and never in git; the secret scan blocks state files with credentials.
- Run `plan` in a separate, reviewed pipeline with real credentials; these gates need none.

## CI

`templates/stacks/terraform/ci.yml` installs a pinned, checksum-verified OpenTofu. For HashiCorp Terraform use the
`hashicorp/setup-terraform` action pinned to a commit SHA.
