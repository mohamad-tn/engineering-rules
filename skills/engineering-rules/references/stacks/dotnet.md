# .NET

Engine: `scripts/stacks/dotnet.sh`. Works on a solution (`.sln`, `.slnx`) or a project.

| Gate | Runs |
|---|---|
| sdk-pin | `global.json` present (warns if not) |
| deps | `dotnet restore --locked-mode` when `packages.lock.json` exists |
| format | `dotnet format --verify-no-changes` |
| build | `dotnet build -c Release -warnaserror` |
| test | `dotnet test` when a test project (`Microsoft.NET.Test.Sdk`) exists |
| audit | `dotnet list package --vulnerable --include-transitive`; passes only when the tool says "no vulnerable packages" |

## Recommended setup

- `Directory.Build.props`: nullable on, warnings as errors, analyzers, `RestorePackagesWithLockFile`.
- `global.json` with `rollForward: disable`.
- Opt-in configs: `templates/stacks/dotnet/configs/`.
- Migrations (EF Core): commit the idempotent SQL, lint it, apply it to an empty database in CI, and never migrate at application start.
  Add those as extra jobs; they depend on your database.

## CI

`templates/stacks/dotnet/ci.yml` (setup-dotnet from `global.json`).

## Notes

`NuGet` must be reachable for `deps`. When it is not, the gate reports NOT RUN, not PASS.
