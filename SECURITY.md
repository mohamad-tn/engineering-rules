# Security policy

## Reporting a vulnerability

Please report security problems privately through GitHub's **Report a vulnerability** button
(Security tab, "Advisories") on this repository. Do not open a public issue for a vulnerability.

Include what you found, how to reproduce it, and the affected file or script. You will get an acknowledgement
and we will agree a fix and a disclosure date with you.

## Supported versions

The latest release receives fixes.

## Scope and threat model

This project is a set of scripts and templates. Things that matter for its security:

- **Downloaded tools** are pinned and verified against a SHA-256 before they run (`install-release-tool.sh`).
  A bypass of that check is a vulnerability.
- **The secret scan** must never print secret values and must never accept an ignore file.
- **The scripts run project commands** (`npm test`, `go test`...), as any CI does. Running them on code you do not trust has the same risk as any CI job.
- **Templates** use read-only permissions and avoid `pull_request_target`. A template that widens permissions without need is a bug.

Not in scope: vulnerabilities in the third-party tools the gates call (report those upstream).
