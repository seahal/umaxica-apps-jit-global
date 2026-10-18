# APP and COM legacy verification surface retirement

- Date: 2026-10-04 UTC.
- Commit: `f313b126931cfe3c9ecf64bbb72fb1cd3a0aada5`.
- Worktree: uncommitted authentication changes and unrelated concurrent work.
- Database: owned isolated run `20261003auth6f3`, manifest
  `tmp/auth-boundary-isolated-20261003auth6f3.json`; APP ticket preparation, one worker.

SignAppVerificationBase and SignComVerificationBase were removed after searches found no
production consumers. This removes the duplicate APP Cookie OTP implementation, parameter-based
session restoration and recovery redirects, and the COM prepend overrides and old unbound OTP
delivery adapter. The obsolete APP private-method/inclusion harness tests were removed alongside
their definitions. The method-availability test now checks the real DB-backed Email OTP issuer's
60-second resend interval, rather than a constant on the retired concern. Searches of app, tests
and routes find no remaining reference to either removed constant.

`bin/rails test test/models/step_up_email_challenge_test.rb
test/operations/identity_step_up_email_code_issuer_test.rb
test/operations/identity_step_up_email_verification_committer_test.rb
test/controllers/auth/step_up_admission_test.rb test/services/step_up/available_methods_test.rb
test/policies/step_up_email_availability_test.rb test/unit/security/forbidden_rails_patterns_test.rb
test/unit/security/authentication_mode_inventory_test.rb` passed
**54 runs, 285 assertions, no failures/errors/skips**, seed 63825.
RuboCop inspected the changed availability test with no offenses. `git diff --check` passed.

The retained checks cover canonical admission, OTP replacement/delivery/verification state,
method lockout boundaries and authentication/security guards. They do not reproduce the retired
Cookie or parameter-restoration contracts, which intentionally supply no authority in the target
design. Other legacy concerns remain. The ORG inclusion test file also contains separate
VerificationOperator behavior tests; those must be preserved or migrated when its legacy concern
is retired. No route, schema, payload shape or active endpoint behavior changed in this slice.
Full R01–R16 remains incomplete. OTP logging remediation is excluded; browser verification is
user-owned.
