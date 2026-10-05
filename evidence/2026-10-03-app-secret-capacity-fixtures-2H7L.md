# app Secret capacity query and fixture cutover

Executed on 2026-10-03 (UTC), on feature HEAD
`f313b126931cfe3c9ecf64bbb72fb1cd3a0aada5` with concurrent uncommitted work.

Added ClientSecretCapacityQuery over the app Zenith writer and exposed immutable
active/reserved count values. A counts confirmed, unclaimed, unrevoked, undiscarded
credentials. R sums positive unconfirmed/uncanceled reservations strictly before
their expiry. Account access state is independent. Mutation callers must hold the
Client lock and supply one writer timestamp after locking; this query is not an
atomic allocation operation.

Replaced the old app credential fixture fields with new ownership, issuance, digest,
and confirmation facts. Added three synthetic completed manual issuance fixtures.
Deleted only app's obsolete kind/status fixture files. Removed app's fixed reusable
Secret and dropped-table reference initialization from development/test seeds;
com/org seed content remains. No seed command was executed in this slice.

All commands used the task-owned `codex_integrity_20261003secret_*` disposable fleet
through `bundle exec ruby /tmp/umaxica-secret-db-task.rb test ...`:

- Capacity Red: two missing-class errors after database/fixture preparation succeeded.
- Initial capacity Green: two tests, eight assertions, no failures/errors/skips.
- A later expanded run exposed a fixture isolation issue: prior full-fixture loading
  had supplied an active Secret for Client one. Query and persistence tests now
  explicitly load their relevant credential/issuance fixtures and use an owner with
  no initial Secrets, rather than depending on an empty database. Expectations were
  preserved, with no deletion-based cleanup or success mocks.
- Combined capacity, credential, source outbox, issuance-state, and count selection:
  **31 tests, 191 assertions, no failures/errors/skips**. Covers A=0/1/18/19/20,
  rejecting a corrupted A=21, A=18/R=2 as reservation conflict, reserved-account
  capacity, other Client exclusion, and microsecond expiry boundaries.
- Base Dashboard guidance under the new full fixture set: **12 tests, 81 assertions,
  no failures/errors/skips**.
- Existing Visitor and Operator Secret model tests plus Visitor credential creation
  tests: **19 tests, 62 assertions, no failures/errors/skips**. This is focused com/org
  credential regression, not proof of their full recovery/Emergency/browser journeys.

RuboCop was run on the query, count value, query tests, and adjusted persistence
test; a ternary formatting offense was corrected. `git diff --check` passed.

The old kind/status model classes and other executable app references remain to
be retired as their callers are replaced. The old Recovery top-up app path is not
reported as fixed by these fixture changes. No producer concurrency or enrollment
distribution has been verified by a read-only capacity query.

The delivery payload tuple proposal is pending explicit approval under
`.agents/harnesses/rules/generic/data-shape-design.mdc`. No payload codec, new TTL,
or delivery behavior was implemented while that decision was pending.
