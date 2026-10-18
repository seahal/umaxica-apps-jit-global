# Legacy step-up lifecycle retirement

- Date: 2026-10-04 UTC.
- Commit: `f313b126931cfe3c9ecf64bbb72fb1cd3a0aada5`.
- Worktree: uncommitted authentication changes and unrelated concurrent work.
- Database: owned isolated run `20261003auth6f3`, manifest
  `tmp/auth-boundary-isolated-20261003auth6f3.json`; APP ticket preparation, one worker.

Unused SignVerificationStepUpLifecycle and SignVerificationStepUpSessionStore were removed with
the obsolete lifecycle seam entry. Searches found no production or behavioral test consumer.
Their local consumption, legacy signed-result issuance and replacement-session restoration paths
are retired. Canonical scoped admission and Base ticket finalization remain authoritative.

`bin/rails test test/controllers/concerns/surface_seam_contracts_test.rb
test/controllers/auth/step_up_admission_test.rb
test/operations/identity_step_up_ceremony_freshness_committer_test.rb
test/models/auth_ceremony_revocation_concurrency_test.rb` passed
**26 runs, 302 assertions, no failures/errors/skips**, seed 6844. `git diff --check` passed.

These checks cover selected admission, Base finalization and independent writer races. They do
not prove complete retirement of the remaining legacy grant/result primitives, primary credential
challenges or credential-management workflows. No schema, route or payload shape changed.
OTP logging remediation is excluded; browser verification is user-owned. Full R01–R16 remains open.
