# Legacy cancellation and audit retirement

- Date: 2026-10-04 UTC.
- Commit: `f313b126931cfe3c9ecf64bbb72fb1cd3a0aada5`.
- Worktree: uncommitted authentication changes and unrelated concurrent work.
- Database: owned isolated run `20261003auth6f3`, manifest
  `tmp/auth-boundary-isolated-20261003auth6f3.json`; APP ticket preparation, one worker.

Unused SignVerificationCancellation and SignVerificationAuditAndCookie were removed with their
obsolete abstract seam entries. Searches found no production consumer. This removes the old
local-state deletion/cross-host cancellation form implementation and its legacy audit adapter;
the current exact-transaction cancellation and Base finalization remain in place.

`bin/rails test test/controllers/concerns/surface_seam_contracts_test.rb
test/controllers/auth/step_up_admission_test.rb
test/operations/identity_step_up_ceremony_freshness_committer_test.rb
test/integration/totp_registration_boundary_test.rb` passed
**25 runs, 354 assertions, no failures/errors/skips**, seed 33321. `git diff --check` passed.

The selected cancellation ordering, admission and TOTP HTTP roundtrip checks do not establish
complete audit coverage, genuine-login coverage for every surface or production behavior.
Other legacy state/lifecycle concerns and credential-management workflows remain incomplete.
No schema, route or payload shape changed. OTP logging remediation is excluded; browser
verification is user-owned.
