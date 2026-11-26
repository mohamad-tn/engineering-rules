#!/usr/bin/env bash
# shellcheck shell=bash
# Terraform and OpenTofu engine (infrastructure as code).

run_terraform() {
  local tf="${STACK_TF_BIN:-}"
  [[ -n "$tf" ]] || { have terraform && tf=terraform; }
  [[ -n "$tf" ]] || { have tofu && tf=tofu; }
  [[ -n "$tf" ]] || { notrun deps "neither terraform nor tofu is installed"; return 0; }
  echo "  tool: ${tf}"

  gate_net deps -- "$tf" init -backend=false -input=false
  if ! git ls-files --error-unmatch .terraform.lock.hcl >/dev/null 2>&1; then
    warn lockfile ".terraform.lock.hcl is not committed: commit it to pin provider versions"
  fi
  gate format -- "$tf" fmt -check -recursive -diff
  gate types -- "$tf" validate

  if have tflint; then gate lint -- tflint; else skip lint "tflint is not installed"; fi
  if [[ -n "$(find . -name '*.tftest.hcl' -not -path './.terraform/*' -print -quit)" ]]; then
    gate test -- "$tf" test
  else
    na test "no .tftest.hcl files"
  fi
  na build "infrastructure code has no build step"

  if have trivy; then
    gate audit -- trivy config --exit-code 1 --severity HIGH,CRITICAL --quiet .
  elif have tfsec; then
    gate audit -- tfsec --soft-fail=false .
  else
    notrun audit "trivy or tfsec is not installed"
  fi
}
