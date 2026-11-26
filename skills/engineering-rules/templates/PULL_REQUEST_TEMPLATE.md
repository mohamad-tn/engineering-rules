## Summary

<!-- What changed and why, in two or three sentences. Link the task. -->

Task: `<task id or link>`

## Type

<!-- Use a Conventional Commit type in the title: feat, fix, docs, refactor, chore, ci, test. -->

## Definition of done

- [ ] Tests cover the behavior and fail without the change
- [ ] Gates pass (CI, or the local proof below)
- [ ] Docs changed with the code; `CHANGELOG.md` has an entry (not needed for `chore`, `ci`, `test`)
- [ ] No secret, token, private host or personal data added
- [ ] New dependency, rule deviation or new pattern has an ADR: `<link>` or "not needed"
- [ ] Size is within the limit, or label `pr-size-reason` and the reason below

## Proof

<!-- Pick one. -->
- [ ] CI is green
- [ ] Hosted CI was not available. Local proof (output of `scripts/local-proof.sh`) is pasted below.

<details>
<summary>Local proof</summary>

```text
paste here
```

</details>

## Risk and rollback

<!-- What can break, who is affected, how to undo it. "None" is a valid answer if true. -->

## Exceptions

<!-- Only if you used `no-docs-needed` or `pr-size-reason`: state the reason here. -->
