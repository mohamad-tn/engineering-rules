#!/usr/bin/env bash
# shellcheck shell=bash
# Swift engine (Swift Package Manager): server-side Swift and packages.
# Xcode app projects are built with xcodebuild in your own CI job.

run_swift() {
  have swift || { notrun deps "swift is not installed"; return 0; }
  echo "  swift: $(swift --version 2>&1 | head -n 1 | cut -c1-60)"

  gate_net deps -- swift package resolve
  [[ -f Package.resolved ]] || warn lockfile "Package.resolved is not committed: commit it to pin dependency versions"

  if have swiftformat; then
    gate format -- swiftformat --lint .
  elif have swift-format; then
    gate format -- swift-format lint --strict --recursive .
  else
    skip format "swiftformat or swift-format is not installed"
  fi
  if have swiftlint; then gate lint -- swiftlint lint --strict; else skip lint "swiftlint is not installed"; fi
  na types "covered by the compiler"

  gate test -- swift test
  gate build -- swift build
  na audit "SwiftPM has no built-in audit tool; rely on your dependency bot"
}
