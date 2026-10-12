# Explicit dead-history destruction boundary

- Repository: `/home/global/workspace`
- Branch: `feature`
- HEAD used for this record: `321832f87102b952cc4431e66777455271d3fc84`
- Worktree: application, test, baseline and ADR changes were already dirty and were preserved; this
  record does not include them in a commit. No reset, clean, stash, rebase, merge, worktree, CI,
  Podman, production, shared-destructive operation or push was used.

## Change

Email and Telephone identifier rows now have explicit destruction modes. The irreversible channel
purgers call `purge_with_dead_history!`, which authorizes one transactionally coupled history insert
and source deletion after the existing owner, retention, hold and enforcement checks. Normal
identifier removal calls `destroy_without_dead_history!`; owner-dependent destruction is recognized
as whole-owner erasure and does not create a new dead-history row. An unmarked direct destruction of
a persisted identifier aborts instead of silently deleting the source without history. The existing
protected-email and retention refusal callbacks remain active.

The purgers still fingerprint the freshly locked persisted value, not unsaved in-memory changes. No
schema or migration was added in this slice. The six-model history schema, retention policy and
whole-owner erasure contract remain otherwise unchanged.

## TDD and focused verification

The first focused Red run was performed after changing the public destroy-boundary tests and before
the production methods existed:

```text
test/models/dead_identifier_destroy_test.rb
test/operations/dead_identifier_purge_concurrency_test.rb
14 runs, 47 assertions, 1 failure, 3 errors
```

The failures were the expected missing explicit lifecycle methods and the expected rejection of an
unmarked irreversible destroy; this was not an environment or syntax failure. After the smallest
implementation and cleanup of affected test fixtures, the focused history/concurrency collection
passed `29 runs, 141 assertions, 0 failures, 0 errors, 0 skips`. The broader six-model/history,
retention, controller and social-unlink collection passed
`181 runs, 918 assertions, 0 failures, 0 errors, 0 skips`.

## Shared-worktree Gate 2

An intermediate full Rails run exposed one unrelated/flaky OIDC clock-leeway assertion. The named
test was rerun alone and passed (`1 run, 2 assertions`), after which the complete run-owned
disposable writer scope was rerun with four workers:

```text
15141 runs, 128212 assertions, 0 failures, 0 errors, 0 skips
```

Vitest also passed with `99` files and `1140` tests. The full Rails run used the existing run-owned
manifest and did not touch production or shared databases.

Static checks for the changed concerns and callers passed: targeted RuboCop reported no offenses,
Brakeman reported zero warnings/errors, both concerns passed `ruby -c`, `git diff --check` passed,
and the repository knowledge checker passed.

## Limits

This is current implementation evidence, not an independent acceptance decision. It does not
authorize real-data purge, prove a host/container Alloy remount, complete the D-11 committed-
transaction isolation matrix, resolve Group/Avatar operational cutover, classify the two retained
legacy identifier tables, determine privacy-retention duration, or repair the historical HMAC-role
rollback hazard. The user-excluded independent acceptance work remains unperformed.
