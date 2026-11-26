# Runbook: Secret and key rotation

> Status: Partial. Fill in the details for your providers, then mark it Verified.

When to use it: on schedule, after any exposure, or when the secret scan fails.
A secret scan finding blocks the merge. It is rotated, never allowlisted.

## Cadence

Set your own and write it here, for example: signing and encryption keys yearly
with an overlap period; provider and API credentials every 90 days and when
someone with access leaves.

## Steps

1. Treat an exposed credential as compromised. Identify its provider, scope, uses and likely exposure window; notify the service owner.
2. Create a replacement in the approved secret store. Never put it in git, chat or docs.
3. Deploy the replacement and verify the service works; revoke the old credential immediately (for active abuse, revoke first and accept an outage rather than wait).
4. Remove the value from the working tree and rotate any credentials derived from it. Do not assume revocation clears the finding: this scanner examines git history too.
5. If the secret is in shared history, coordinate a repository-history rewrite and require collaborators to re-clone or carefully rebase. If history cannot be rewritten, keep the credential revoked and use `SECRET_SCAN_FROM=<adoption commit>` only with an approved ADR that records the remaining historical exposure; this narrows scanning and is not equivalent to erasing history.
6. Record the incident, rotation/revocation timestamps, affected systems and follow-up actions in the approved incident record (never include the secret itself).

## Escalation

Owner of the affected service, then the project owner.
