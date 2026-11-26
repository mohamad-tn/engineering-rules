# Go

Engine: `scripts/stacks/go.sh`.

| Gate | Runs |
|---|---|
| deps | `go mod download` and `go mod verify` |
| mod-tidy | fails if `go mod tidy` would change `go.mod` or `go.sum` (the files are restored afterwards) |
| format | `gofmt -l` must be empty |
| types | `go vet ./...` |
| lint | `golangci-lint run` when `.golangci.yml` exists |
| test | `go test ./...` (`STACK_GO_RACE=1` adds `-race`) |
| build | `go build ./...` |
| audit | `govulncheck ./...` (NOT RUN if it is not installed) |

## Recommended setup

- Opt-in config: `templates/stacks/go/configs/.golangci.yml`.
- Install `govulncheck` and `golangci-lint` at pinned versions in CI.

## CI

`templates/stacks/go/ci.yml` (setup-go from `go.mod`).
