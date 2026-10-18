# Legacy verification actions retirement

- Date: 2026-10-04 UTC.
- Commit: `f313b126931cfe3c9ecf64bbb72fb1cd3a0aada5`.
- Worktree: uncommitted authentication changes and unrelated concurrent work.
- Database: owned isolated run `20261003auth6f3`, manifest
  `tmp/auth-boundary-isolated-20261003auth6f3.json`; APP ticket preparation, one worker.

Four unused concerns were removed: SignEmailOtpRedeliveryEndpoint, SignVerificationEntry,
SignVerificationPasskeyActions and SignVerificationTotpActions. Searches found no production
consumer after the verification controller migration. This retires Cookie nonce redelivery,
parameter-started legacy entry, automatic Passkey challenge reissue, and Auth-side session
consumption through those action implementations. The obsolete fake-harness Passkey/TOTP action
tests and the entry seam row were removed with their definitions; stale explanatory comments now
describe the scoped ceremony boundary.

Replacement HTTP cases exercise missing admission for APP Passkey/TOTP and COM/ORG Passkey.
Two APP TOTP cases use the public admission continuation and real credential models, then reject
a valid code at the Turnstile boundary or reject malformed code after that boundary. Both retain
pending evidence, leave the TOTP window unconsumed, and grant neither Base freshness nor Auth
root cookies. The admission selection passed **9 tests / 138 assertions**, seed 40009. Its first
run failed only on the test framework's prohibition of `assert_equal nil`; explicit nil assertions
corrected that harness issue.

The post-retirement command covering admission, remaining concern seams, Action Policy/security
guards, Passkey/TOTP verification committers and Email issuance passed **30 runs, 279 assertions,
no failures/errors/skips**, seed 27253. Command:
`bin/rails test test/controllers/auth/step_up_admission_test.rb
test/controllers/concerns/surface_seam_contracts_test.rb test/unit/security/action_policy_usage_test.rb
test/unit/security/forbidden_rails_patterns_test.rb
test/operations/identity_step_up_passkey_verification_committer_test.rb
test/operations/identity_step_up_totp_verification_committer_test.rb
test/operations/identity_step_up_email_code_issuer_test.rb`.
`git diff --check` passed.
RuboCop inspected all four changed Ruby files with no offenses.

The HTTP tests create Base token records through model APIs; they do not prove genuine root-login
establishment or browser behavior. Other legacy verification concerns and primary challenge paths
remain, as do purpose-scoped credential-management workflows. This is not full R03/R06/R16 closure.
No schema, shared database, route, or response shape changed. OTP logging remediation is excluded;
browser verification is user-owned.
