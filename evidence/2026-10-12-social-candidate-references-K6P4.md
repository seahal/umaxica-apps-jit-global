# Social candidate reference transition

## Scope

This record covers the Social ceremony candidate reference slice only. It was performed against
the local dirty worktree at `git rev-parse HEAD`:

```text
7576ff7cbc6787f7f80f1f42bfa538914ace6de1
```

The worktree already contained unrelated implementation changes. No reset, clean, stash, worktree,
push, CI, Podman, production, external-service or shared destructive operation was used.

## Change

`IdentitySocialCeremonyCandidateStore` now uses the shared generated-reference factory. New
candidate references are NanoID-21 values. The candidate model accepts only NanoID-21 or retained
UUID-v4 references, and the APP Social link-completion controller uses that candidate-specific
contract instead of widening the global admission pattern. Existing UUID rows remain readable.
The named `ref` unique-index collision path is bounded and keeps provider callback data and the
candidate binding unchanged.

## Verification

- Initial contract Red: `14 runs, 146 assertions, 1 failure, 1 error, 0 skips` (former UUID issuer
  and missing candidate reference predicate).
- Focused Social contract and integration collection:
  `35 runs, 303 assertions, 0 failures, 0 errors, 0 skips`.
- Targeted RuboCop: four changed Ruby files inspected, no offenses.
- Run-owned Rails Gate 2, four workers: `15201 runs, 128498 assertions, 0 failures, 0 errors,
  0 skips`.
- Vitest: `99 files passed, 1140 tests passed`.

The Rails and JavaScript results are evidence for this worktree revision, not a permanent acceptance
claim. Independent acceptance investigation, live provider behavior, D-11 committed-transaction
coverage and production/shared-data verification were not performed.
