# Latest-pending step-up fallback retirement

- Date: 2026-10-04 UTC.
- Commit: `f313b126931cfe3c9ecf64bbb72fb1cd3a0aada5`.
- Worktree: uncommitted authentication changes and unrelated concurrent work.
- Database: owned isolated run `20261003auth6f3`, manifest
  `tmp/auth-boundary-isolated-20261003auth6f3.json`; APP ticket preparation, one worker.

VerificationBase no longer contains the reflective legacy session/transaction method-policy path
or latest-pending transaction lookup. No production controller defines its required legacy
current_step_up_session seam. Base method discovery now names the surface-supported methods
directly, preserving the previously effective branch. Auth's admitted transaction intersection
remains in AuthStepUpCeremonyContext and AuthStepUpCeremonyEntry.

`bin/rails test test/controllers/concerns/sign/org_verification_base_included_do_test.rb
test/controllers/auth/step_up_admission_test.rb test/operations/base_step_up_admission_issuer_test.rb`
passed **21 runs, 165 assertions, no failures/errors/skips**, seed 40776.
`git diff --check` passed.
RuboCop inspected the changed concern with no offenses.

Remaining legacy grant/result issuers and their test consumers need separate retirement; this
does not establish all transaction-binding, protected-operation or credential-management gates.
No schema, route or payload shape changed. OTP logging remediation is excluded; browser
verification is user-owned. Full R01–R16 remains incomplete.
