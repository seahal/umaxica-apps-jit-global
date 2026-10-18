# Base finalization, logout and cancellation

- Date: 2026-10-04 UTC.
- Commit: `f313b126931cfe3c9ecf64bbb72fb1cd3a0aada5`.
- Worktree: uncommitted authentication changes and unrelated concurrent work.
- Database: owned isolated run `20261003auth6f3`, manifest
  `tmp/auth-boundary-isolated-20261003auth6f3.json`; APP ticket preparation, one worker.

`bin/rails test test/models/auth_ceremony_revocation_concurrency_test.rb
test/operations/identity_step_up_ceremony_freshness_committer_test.rb` passed
**14 runs, 131 assertions, no failures/errors/skips**, seed 26753.

RuboCop inspected both changed test files: two files, no offenses. `git diff --check` passed.

The new APP race commits its own actor, credential, token, parent and continuity, then releases
two distinct PostgreSQL writer connections together. One attempts Base finalization; the other
revokes the token through the production lifecycle. After both finish, the token is revoked,
freshness is absent, the resolver refuses authority, and retrying the same result is rejected.
The parent and continuity must agree with the finalization outcome: consumed/completed when
finalization won, revoked/terminal when logout won. Cleanup deletes only test-owned rows.

The first race run failed because the test expected only the finalizer's domain exception on
retry. The existing admission reader can also reject the invalidated result first. The test now
accepts these two explicit refusal types; production behavior was unchanged. The race file then
passed 5 tests / 43 assertions, seed 57527.

Four added deterministic operation cases separately fix both orderings of logout and cancellation
against Base finalization. Logout clears freshness even after completed evidence; a finalized
result cannot restore a revoked session. Cancellation before completion prevents authority while
preserving the root session. Cancellation after completion refuses to rewrite consumed evidence
or its original timestamps.

Verification evidence is synthetic. These tests exercise real locks, lifecycle operations,
opaque result transport and persisted authority, but do not prove WebAuthn signature verification,
HTTP logout, browser behavior, every race scheduling order, or the independent COM/ORG Base
finalization races. They do not establish connection-loss or commit-acknowledgement failure behavior.
Full R01–R16 remains incomplete. Browser verification is user-owned; OTP logging remediation is
excluded; the additional Passkey candidate shape remains pending approval.
