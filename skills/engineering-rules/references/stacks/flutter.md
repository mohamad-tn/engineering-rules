# Flutter and Dart

Engine: `scripts/stacks/flutter.sh`. Uses `flutter` for apps and `dart` for pure Dart packages.

| Gate | Runs |
|---|---|
| deps | `pub get`, then fails if `pubspec.lock` changed |
| format | `dart format --output=none --set-exit-if-changed .` |
| lint | `flutter analyze` (or `dart analyze --fatal-infos`) |
| test | `flutter test` when `test/*_test.dart` exists |
| build | only when `STACK_FLUTTER_BUILD` is set, for example `apk --debug` |
| secrets-files | tracked keystores and credentials under `android/` and `ios/` |

The installer sets `STACK_REQUIRE=deps,test` for Flutter projects, because building needs platform
SDKs. Add `build` to `STACK_REQUIRE` when your CI builds.

## Recommended setup

- Commit `pubspec.lock` for apps.
- `analysis_options.yaml` with `flutter_lints` and strict analysis (`templates/stacks/flutter/configs/`).
- Keep signing keys and `key.properties` out of git.
- `pub` has no official audit tool; rely on your dependency bot.

## CI

`templates/stacks/flutter/ci.yml` (flutter-action with caching).
