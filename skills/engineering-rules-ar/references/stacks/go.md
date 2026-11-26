<!-- rtl -->
<div dir="rtl">

# Go

المحرك: `scripts/stacks/go.sh`.

| البوابة | ما تشغّله |
|---|---|
| `deps` | `go mod download` و`go mod verify` |
| `mod-tidy` | يفشل إذا كان `go mod tidy` سيغيّر `go.mod` أو `go.sum` (وتُستعاد الملفات بعدها) |
| `format` | `gofmt -l` يجب أن يكون فارغًا |
| `types` | `go vet ./...` |
| `lint` | `golangci-lint run` عند وجود `.golangci.yml` |
| `test` | `go test ./...` (والمتغير `STACK_GO_RACE=1` يضيف `-race`) |
| `build` | `go build ./...` |
| `audit` | `govulncheck ./...` (`NOT RUN` إن لم يكن مثبّتًا) |

## الإعداد الموصى به

- إعداد اختياري: `templates/stacks/go/configs/.golangci.yml`.
- ثبّت `govulncheck` و`golangci-lint` بإصدارات محددة في الـ CI.

## التكامل المستمر (CI)

الملف `templates/stacks/go/ci.yml` (`setup-go` من `go.mod`).

</div>
