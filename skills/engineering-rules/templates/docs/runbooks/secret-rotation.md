# Runbook: Secret and key rotation

> Status: Partial. Fill in the details for your providers, then mark it Verified.

When to use it: on schedule, after any exposure, or when the secret scan fails.
A secret scan finding blocks the merge. It is rotated, never allowlisted.

## Cadence

Set your own and write it here, for example: signing and encryption keys yearly
with an overlap period; provider and API credentials every 90 days and when
someone with access leaves.

## Steps

1. List what was exposed and where it is used.
2. Create the new secret in the secret store. Never in git, chat or docs.
3. Deploy the new value, then check that the service works.
4. Revoke the old secret at the provider.
5. Remove the leaked value from the working tree. History stays; the revoked secret is harmless.
6. Record the date and the reason in the pull request.

## Escalation

Owner of the affected service, then the project owner.
