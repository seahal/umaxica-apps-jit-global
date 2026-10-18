# Legacy step-up timing retirement

- Date: 2026-10-04 UTC.
- Commit: `f313b126931cfe3c9ecf64bbb72fb1cd3a0aada5`.
- Worktree: uncommitted authentication changes and unrelated concurrent work.
- Database: owned isolated run `20261003auth6f3`, manifest
  `tmp/auth-boundary-isolated-20261003auth6f3.json`; APP ticket preparation, one worker.

Unused SignVerificationTiming and SignVerificationCommonBase were removed together with the
obsolete common-base seam entry. Searches showed no remaining controller or test consumer.
This retires the separate GET 15-minute / POST 30-minute shortcut, reflective actor-token lookup,
and Auth-side recent-proof session consumption. The current requirement/resolver and Base
finalization remain authoritative.

`bin/rails test test/controllers/concerns/surface_seam_contracts_test.rb
test/controllers/auth/step_up_admission_test.rb
test/operations/identity_step_up_ceremony_freshness_committer_test.rb` passed
**19 runs, 231 assertions, no failures/errors/skips**, seed 3671. `git diff --check` passed.

This verifies the selected admission, remaining seam and Base finalization regressions, not all
protected operations or genuine login. Other legacy concerns and credential-management workflows
remain incomplete. No route, schema or payload shape changed. OTP logging remediation is excluded;
browser verification is user-owned.
