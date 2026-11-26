# Swift (Swift Package Manager)

Engine: `scripts/stacks/swift.sh`. Detects a `Package.swift`: server-side Swift and packages. Xcode app projects are
built with `xcodebuild` in your own job (they need signing and platform SDKs).

| Gate | Runs |
|---|---|
| deps | `swift package resolve`; warns if `Package.resolved` is not committed |
| format | `swiftformat --lint .`, or `swift-format lint --strict --recursive .` if swiftformat is not installed and swift-format is available |
| lint | `swiftlint lint --strict` when installed |
| test | `swift test` |
| build | `swift build` |

`types` and `audit` are N/A (the compiler checks types; SwiftPM has no audit tool).

## CI

`templates/stacks/swift/ci.yml` runs on a macOS runner and installs a current bash (macOS ships 3.2).

## Test status

Verified at the command level with a stubbed toolchain; the real Swift toolchain was not available where this
suite was authored. See `docs/testing.md`.
