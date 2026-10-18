# ORG legacy verification concern retirement

- Date: 2026-10-04 UTC.
- Commit: `f313b126931cfe3c9ecf64bbb72fb1cd3a0aada5`.
- Worktree: uncommitted authentication changes and unrelated concurrent work.
- Database: owned isolated run `20261003auth6f3`, manifest
  `tmp/auth-boundary-isolated-20261003auth6f3.json`; APP ticket preparation, one worker.

The unused SignOrgVerificationBase concern and its inclusion-only test class were removed.
Its separate VerificationOperator direct-coverage class remains in its existing file without
changes to its test bodies or helper. The old inclusion class supplied no production consumer.
Searches found no remaining production reference to the removed concern.

`bin/rails test test/controllers/concerns/sign/org_verification_base_included_do_test.rb
test/controllers/auth/step_up_admission_test.rb` passed **18 runs, 152 assertions,
no failures/errors/skips**, seed 7194. `git diff --check` passed.
RuboCop inspected the changed test file with no offenses.

The retained legacy harness is not admission, genuine-login, or end-to-end proof and still requires
public-boundary migration. Other shared legacy concerns, primary challenge storage and credential
management remain incomplete. No database, route or payload shape changed. OTP logging remediation
is excluded; browser verification is user-owned.
