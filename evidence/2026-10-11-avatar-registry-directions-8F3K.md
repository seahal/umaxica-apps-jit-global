# Avatar registry four-direction slice

Date: 2026-10-11

The slice was executed in `/home/global/workspace` on branch `feature` at starting
HEAD `a1ec83a7384a424c97671356268ec5c4ad8347d4`. The worktree contained unrelated
staged, unstaged and untracked changes; no reset, clean, stash, push or code commit
was performed. The application and test edits remained uncommitted.

## Change

The registry operation acceptance tests now cover Enterprise→Enterprise and
Bureau→Bureau in addition to the existing cross-surface directions. The tests
assert the concrete current period, target owner, and absence of a current period
from the source family. The permanent ownership checklist records that the
operation-level four-direction evidence does not yet certify authenticated HTTP
transport, legacy-writer cutover, or independent-connection concurrency.

## TDD and focused verification

- Initial focused run after adding the tests: `21 runs, 120 assertions, 1 failure,
  0 errors, 0 skips`. The failure was a test fixture moniker longer than the
  model's 16-character limit, not an application failure.
- After correcting the fixture input, the focused command was:
  `bundle exec rails test test/operations/avatar_ownership_transfers_test.rb`
  with `PARALLEL_WORKERS=1` and the repository's six test database targets.
  Result: `21 runs, 126 assertions, 0 failures, 0 errors, 0 skips`.

## Full gates

After the slice, the isolated PostgreSQL Rails gate used run ID
`20261010p3d2`, the repository's 20-database disposable fleet manifest, and
four workers. Command: `bundle exec rails test`. Result:

`15042 runs, 127541 assertions, 1 failure, 0 errors, 0 skips`.

The sole failure was the pre-existing `Security::AcmeRenameInventoryTest` finding
`Apex-scoped` in the unrelated untracked file
`adr/preference-tld-sharing-and-jwt-lifecycle-reassessment.md:30`. No registry
test or new error failed. This is not claimed as a green full gate.

The disposable worker catalog was checked after teardown. The first cleanup
attempt raced with worker database termination and reported remaining clones;
the subsequent read-only cleanup check passed with all planned worker names absent
and parent databases preserved. No shared or production database was dropped.

The registry concurrency regression was then run with the same run-owned fleet,
four workers and independent PostgreSQL connections:
`bundle exec rails test test/operations/avatar_ownership_transfers_concurrency_test.rb`.
Result: `6 runs, 22 assertions, 0 failures, 0 errors, 0 skips`. A preliminary
attempt without the run-owned manifest was blocked by the repository's committed-
test guard; it was not counted as a pass. The owned worker catalog was verified
clean afterward.

The additive app registry transport now authorizes reservation accept/cancel through
`AvatarTransferReservationPolicy` before the operation's locked revalidation. Its
focused HTTP test command was `bundle exec rails test
test/controllers/base/app/avatar_ownership_transfers_controller_test.rb`, with
`10 runs, 45 assertions, 0 failures, 0 errors, 0 skips`. Targeted RuboCop for the
policy, both transfer controllers and the app controller test reported no offenses.
The org transport uses the same policy boundary. After correcting the fixture to
exercise an Enterprise-owned Avatar accepted by the Bureau destination, the focused
command `bundle exec rails test
test/controllers/base/org/avatar_ownership_transfers_controller_test.rb` reported
`3 runs, 24 assertions, 0 failures, 0 errors, 0 skips`. The first attempt used the
source-side org controller to accept an org-to-app transfer and correctly returned
403; that was a test contract error, not a production change.

The latest full Rails gate used the same run-owned four-worker fleet and reported
`15045 runs, 127557 assertions, 2 failures, 2 errors, 0 skips`. In addition to the
unrelated Apex inventory failure, it exposed two parallel-suite contamination
failures involving pending Avatar transfer rows and an unrelated RP sequence
expectation. The operation and reservation files pass together in an isolated
34-test run (`34 runs, 167 assertions, 0 failures, 0 errors, 0 skips`), so the
full-suite failures remain unaccepted and require separate isolation/root-cause
work before a green Gate 2.

The Vitest full gate command `bun run test` passed with `99` files and `1140`
tests. No live provider, production, Alloy remount, or external service check was
performed.

The later full Rails run after adding the isolated registry race test reported
`15043 runs, 127542 assertions, 1 failure, 1 error, 0 skips`: the same unrelated
`Apex-scoped` inventory failure plus a parallel-only `one_pending_avatar`
unique-constraint error in the existing ownership-transfer test class. The
ownership-transfer file alone passed with four isolated workers (`21 runs, 126
assertions, 0 failures, 0 errors`), so this cross-suite contamination remains
classified as an existing full-suite isolation defect rather than a registry
operation assertion. It still prevents a green Gate 2 and requires separate
repair before final acceptance.

## Remaining acceptance

Authenticated app/org acceptance integration is now covered, but HTTP create/cancel
matrix coverage, all legacy caller cutover, independent-connection acceptance races,
P12b backfill/write barrier, and final Gate 4 remain open. The full Rails failure
remains separately classified until the unrelated ADR change and parallel-suite
contamination are resolved or dispositioned by their owners.
