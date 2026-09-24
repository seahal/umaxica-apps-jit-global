# Authority family backfill slice

- Date: 2026-09-23
- HEAD: `91d71c6f61d60c13be350bff3b723e05d09adf37`
- Worktree: dirty; 279 staged, unstaged, or untracked entries were present before this record.
- External writes: none.

## Implemented

`AuthorityOwnerFamilyBackfillOperation` was added for one surface-local resource family. It accepts
only an explicit reviewed owner public identifier and lifecycle state for each resource, rejects
duplicate resource mappings and invalid input, applies the reviewed rows in one writer transaction,
rolls the batch back when a later row is rejected, and treats an identical complete batch as
idempotent. A partial mapping that does not cover the current resource family is rejected before
any write. It does not infer owners, switch authorization consumers, create a cutover marker, or
provide post-cutover rollback.

The corresponding public-operation tests cover successful replay, batch rollback on lifecycle
conflict, duplicate-resource rejection, partial-family rejection, and empty-review rejection. The plan, conflict ledger, and
authority architecture document record the new pre-cutover boundary. The authority ADR also now
identifies the existing read-only inventory as the conflict-audit boundary; no separate `dry_run`
mode or preview API is required. No migration or persisted shape was added by this slice.

## Verification

Passed:

- `ruby -c app/operations/authority_owner_family_backfill_operation.rb`
- `ruby -c test/operations/authority_owner_family_backfill_operation_test.rb`
- `bundle exec rubocop app/operations/authority_owner_family_backfill_operation.rb test/operations/authority_owner_family_backfill_operation_test.rb`
- `bundle exec brakeman --no-pager` — 0 errors, 0 security warnings
- `git diff --check`

The required preflight was attempted with the explicit `.env.devcontainer.example` selection. The
credential key existed and all required variable names were present after `LocalEnvironment.load!`,
but `primary` and `valkey-kvs` did not resolve in this process. The preflight stopped with
`PG::ConnectionBad: could not translate host name "primary" to address: Temporary failure in name resolution`.

The focused Rails command therefore stopped during Rails schema boot before test execution; no
assertions ran and no test result was produced. The full suite was not started because the focused
prerequisite failed. No localhost substitution, configuration edit, test deletion, skip, mock, or
external-service change was used.

## Adversarial review

- A subset mapping could have been reported as a successful family operation. The implementation
  now compares the reviewed public-ID set with the current resource family before any write and
  rejects incomplete input.
- Switching selector/switcher reads to ownership would have removed legitimate delegated/member
  act-as behavior. Those consumers remain unchanged and the owner-only cutover remains explicitly
  gated by a consumer-specific review.
- A missing Side US host or regional audience could have been filled from a guessed hostname or
  client ID. The regional matrix remains fail-closed and no registration was activated.

## Status impact

This advances the repository implementation slice for CF-003/CF-004 but does not close it. A
complete reviewed mapping against the actual isolated resource set, family consumer cutover, and
post-cutover forward-recovery proof still require database-backed acceptance in the approved test
environment. CF-007 remains fail-closed because canonical Side US host and regional audience
sources are still absent; no value was invented.
