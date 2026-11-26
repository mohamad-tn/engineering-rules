#!/usr/bin/env bash
# shellcheck shell=bash
# Go engine.

run_go() {
  have go || { notrun deps "go is not installed"; return 0; }
  echo "  go: $(go env GOVERSION)"

  gate_net deps -- bash -c "go mod download && go mod verify"
  gate mod-tidy -- bash "${STACK_TOOLS_DIR}/go-tidy-check.sh"

  # shellcheck disable=SC2016
  gate format -- bash -c 'out="$(gofmt -l . | grep -v "^vendor/" || true)"; if [ -n "$out" ]; then echo "$out"; echo "run gofmt -w"; exit 1; fi'
  gate types -- go vet ./...

  if any_file ".golangci.yml" ".golangci.yaml" ".golangci.toml"; then
    if have golangci-lint; then gate lint -- golangci-lint run; else notrun lint "golangci-lint is not installed"; fi
  else
    skip lint "no .golangci.yml"
  fi

  if [[ "${STACK_GO_RACE:-0}" == "1" ]]; then gate test -- go test -race ./...; else gate test -- go test ./...; fi
  gate build -- go build ./...

  if have govulncheck; then
    gate_net audit -- govulncheck ./...
  else
    notrun audit "govulncheck is not installed (go install golang.org/x/vuln/cmd/govulncheck@latest)"
  fi
}
