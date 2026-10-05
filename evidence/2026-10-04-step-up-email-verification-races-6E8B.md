# Step-up Email OTP verification races

- Date: 2026-10-04 UTC.
- Commit: `f313b126931cfe3c9ecf64bbb72fb1cd3a0aada5`.
- Worktree: uncommitted authentication changes and unrelated concurrent work.
- Database: owned isolated run `20261003auth6f3`, manifest
  `tmp/auth-boundary-isolated-20261003auth6f3.json`; APP ticket preparation, one worker.

`bin/rails test test/models/auth_ceremony_revocation_concurrency_test.rb
test/operations/identity_step_up_email_verification_committer_test.rb` passed
**9 runs, 89 assertions, no failures/errors/skips**, seed 38706.
RuboCop inspected the changed concurrency test file with no offenses. `git diff --check` passed.

The new APP and COM cases create and commit their own actor, verified email credential, token,
step-up parent, and server-side code generation. Two distinct PostgreSQL writer connections,
identified by backend IDs, simultaneously submit the same code through the production verification
committer. Exactly one succeeds and one refuses. The parent records Email OTP verification with
`aal=none`, no phishing resistance, and the actual credential reference. The generation is spent,
the losing request does not add a credential failure, and no Base freshness is issued.
Further replay is refused without altering the original verification timestamp or failure count.
All committed test-owned rows are removed after the threads finish.

The APP-only extension first passed 8 tests / 75 assertions, seed 11469. COM was then added as an
independent model/database case. ORG has no Email OTP case because that method remains prohibited.

These cases mark delivery successful through the existing public model API to isolate verification;
they do not perform mail delivery, inspect delivery logs, prove HTTP/browser continuity, or verify
Base finalization. The existing replacement-code, consecutive-failure and lockout operation cases
run alongside them. Resend-versus-verification races, credential revocation races, dependency
failures and other full-ledger acceptance work remain open. OTP logging remediation remains
excluded and browser verification is user-owned.
