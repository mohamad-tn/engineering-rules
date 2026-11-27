#!/usr/bin/env python3
"""Unit checks for release CI evidence parsing; no network access is used."""
from importlib.machinery import SourceFileLoader

CHECKS = SourceFileLoader("release_checks", "tools/release-checks.py").load_module()


def must_reject(log, name="static checks"):
    try:
        CHECKS.validate_logs(log, name)
    except ValueError:
        return
    raise AssertionError(f"release evidence was incorrectly accepted for {name}: {log!r}")


def main():
    good = "2026-11-27T12:00:00Z passed: 8  failed: 0  skipped: 0\n2026-11-27T12:00:01Z ALL TESTS PASSED\n"
    CHECKS.validate_logs(good, "static checks")
    must_reject("2026-11-27T12:00:00Z SKIP  missing tool\n" + good)
    must_reject("passed: 8  failed: 1  skipped: 0\nALL TESTS PASSED\n")
    must_reject("passed: 8  failed: 0  skipped: 1\nALL TESTS PASSED\n")
    must_reject("passed: 0  failed: 0  skipped: 0\nALL TESTS PASSED\n")
    must_reject("passed: 8  failed: 0  skipped: 0\n")
    must_reject("passed: 8  failed: 0  skipped: 0\nALL TESTS PASSED\nALL TESTS PASSED\n", "stack gates (real toolchains)")
    print("release CI evidence accepts only complete, non-skipped successful test summaries")


if __name__ == "__main__":
    main()
