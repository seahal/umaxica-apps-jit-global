# ORG session-limit cancellation lock-order regression

Date: 2026-11-04 Full commit hash: `b30345216886c98af1f04cbd434f067f12decf01` Worktree: extensively
uncommitted; this result includes the scoped test and inventory edits described here.

## Work

Added an independent-connection ORG regression for `SessionLimitOidcCancellationCommitter`. The test
holds the Operator row on one connection, observes the cancellation worker waiting for that row, and
proves that a second connection can still acquire the corresponding OIDC authorization parent using
`FOR UPDATE NOWAIT`. After the actor lock is released, it verifies that cancellation completes and
the resolution and sign-in flow are cancelled. This complements the existing APP race test and the
existing ORG success case.

Also traced every direct production entry into `SignUpArtifactCleanup`: terminal cleanup runs after
the flow lock block returns, the cancellation controller and expiry job do not hold an OP row lock
before entry, and the retention worker starts an OP transaction but selects its candidate without a
row lock before delegating to the actor-first cycle lock. No current direct caller-held OP Flow row
lock was found. Indirect callbacks and future callers remain unverified.

## Verification

- `PARALLEL_WORKERS=1 bin/rails test test/operations/session_limit_oidc_cancellation_committer_test.rb`
  — **3 runs / 28 assertions / 0 failures / 0 errors / 0 skips**.
- `bin/rubocop test/operations/session_limit_oidc_cancellation_committer_test.rb` — passed.
- Post-switch regression rerun,
  `PARALLEL_WORKERS=1 bin/rails test test/controllers/base/app/avatar_ownership_transfers_controller_test.rb test/integration/step_up_authentication_test.rb`
  — **50 runs / 229 assertions / 3 failures / 0 errors / 0 skips**. Q-1's valid mode change returns
  422 without an RP-local session-aware owner commit. The two O-11 contact-registration expectations
  still receive the current fail-closed 503.
- `PARALLEL_WORKERS=1 bin/rails test test/integration/base_rp_contact_registration_refusal_test.rb`
  — **2 runs / 36 assertions / 0 failures / 0 errors / 0 skips**.

Only configured test databases were used. No database cleanup, development or production database
access, API-shape change, or schema change was performed. The broader lock-order inventory remains
incomplete.
