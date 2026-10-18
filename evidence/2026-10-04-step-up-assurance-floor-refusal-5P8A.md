# Step-up assurance floor refusal

- Date: 2026-10-04 UTC.
- Commit: `f313b126931cfe3c9ecf64bbb72fb1cd3a0aada5`.
- Worktree: uncommitted authentication changes and unrelated concurrent work.
- Database: owned isolated run `20261003auth6f3`, manifest
  `tmp/auth-boundary-isolated-20261003auth6f3.json`; APP ticket preparation, one worker.

An added public-boundary case starts a Base permission demanding AAL2, then submits synthetic
Passkey AAL1 evidence. The existing transaction model refuses insufficient assurance; the opaque
result issuer also refuses the still-pending transaction. No verification event, consumption,
Base freshness or Auth completion is recorded. No production correction was needed.

The initial test setup hit the existing competing-transaction refusal. Canceling the setup's
previous permission through the production cancellation operation allowed the intended new
permission. The next run revealed that the model already refuses the evidence before Base
finalization, correcting the initial missing-check hypothesis. The final regression asserts this
existing refusal at its actual public boundary.

`bin/rails test test/operations/identity_step_up_ceremony_freshness_committer_test.rb` passed
**10 runs, 98 assertions, no failures/errors/skips**, seed 38741. RuboCop inspected the changed test
with no offenses. `git diff --check` passed.

This tests assurance classification and refusal, not a real AAL2 authentication or browser login.
Legacy JWT consumers, credential-management workflows and full-ledger work remain incomplete.
OTP logging remediation is excluded; browser verification is user-owned.
