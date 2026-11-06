# WU-A6 support revocation fixture isolation attempt

- HEAD: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`. The worktree was extensively dirty; the
  temporary change to `test/controllers/base/org/support/session_revocations_test.rb` was reverted
  after the failed experiment. No application code, schema, or database row was changed.
- The earlier selected WU-A6 group stopped this fixture-backed file during Rails fixture loading
  with a `bureau_ownerships.operator_id` foreign-key violation referencing a missing `operators`
  row.
- A fixture-free variant was tried by constructing Operators and Clients in setup. The full file
  then produced 21 runs, 41 assertions, 12 failures, 1 error and 0 skips. Multiple authorized-root
  requests redirected to `/identity/passkeys/new`; the manually created operators did not reproduce
  the fixture-authenticator state used by these tests. The change was reverted, so this result does
  not describe the current file.
- The selected support-session revocation cases remain unverified in the present fixture state.
  Earlier focused evidence for three Normal/Standby support-revocation cases remains
  `evidence/2026-10-31-wua6-support-standby-operation-Y4K7.md`. No test database repair was
  attempted.
