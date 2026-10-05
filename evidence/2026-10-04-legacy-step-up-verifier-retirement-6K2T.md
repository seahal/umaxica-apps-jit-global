# Legacy step-up verifier retirement

- Date: 2026-10-04 UTC.
- Commit: `f313b126931cfe3c9ecf64bbb72fb1cd3a0aada5`.
- Worktree: uncommitted authentication changes and unrelated concurrent work.
- Database: owned isolated run `20261003auth6f3`, manifest
  `tmp/auth-boundary-isolated-20261003auth6f3.json`; APP ticket preparation, one worker.

Unused SignVerificationPasskeyChecks and SignVerificationTotpChecks were removed with their
obsolete abstract seam entries. Searches found no production or behavioral test consumer.
Canonical verification continues through the current DB-bound Passkey/TOTP committers.

`bin/rails test test/controllers/concerns/surface_seam_contracts_test.rb
test/controllers/auth/step_up_admission_test.rb
test/operations/identity_step_up_passkey_verification_committer_test.rb
test/operations/identity_step_up_totp_verification_committer_test.rb` passed
**17 runs, 176 assertions, no failures/errors/skips**, seed 16530. `git diff --check` passed.

The selected admission and verifier checks do not prove all primary sign-in/signup challenges,
all credential-management paths or browser behavior. Remaining legacy lifecycle/state concerns
and full-ledger work remain incomplete. No schema, route or payload shape changed. OTP logging
remediation is excluded; browser verification is user-owned.
