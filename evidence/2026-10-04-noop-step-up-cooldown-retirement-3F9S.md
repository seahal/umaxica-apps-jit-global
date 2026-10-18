# No-op step-up cooldown retirement

- Date: 2026-10-04 UTC.
- Commit: `f313b126931cfe3c9ecf64bbb72fb1cd3a0aada5`.
- Worktree: uncommitted authentication changes and unrelated concurrent work.
- Database: owned isolated run `20261003auth6f3`, manifest
  `tmp/auth-boundary-isolated-20261003auth6f3.json`; APP ticket preparation, one worker.

Unused StepUpCooldownStamp and StepUpCooldowns were removed after confirming zero production
consumers. Availability tests retain their real credential assertions and drop the no-op calls
and tests of the obsolete cache-key/empty-result contract. DB-backed issuance owns resend
throttling; the method policy evaluates stored credential lockout state.

`bin/rails test test/services/step_up/available_methods_test.rb
test/policies/step_up_email_availability_test.rb
test/operations/identity_step_up_email_code_issuer_test.rb` passed
**24 runs, 62 assertions, no failures/errors/skips**, seed 41481. `git diff --check` passed.

These checks do not establish complete failure-budget, delivery, HTTP or full-ledger coverage.
Credential management and other remaining migration work are incomplete. No schema, route or
payload shape changed. OTP logging remediation is excluded; browser verification is user-owned.
