# Independent OTP destination budgets and retained failures

Commit: `48ff7040de2b50a8a08ed660fa71878a029ba577`.
Uncommitted worktree changes affected the checks below.

Email and Telephone now own independent destination-budget classes, each with its own atomic Lua
script, failure threshold, window and input validation. The former shared stateful class was removed;
all application and test callers select the actual channel owner explicitly. Existing Valkey key
shape, five-failure threshold and fixed fifteen-minute TTL are unchanged. Cross-channel calls are
explicit errors, not fallback dispatch. Infrastructure outage and corrupt state remain fail-closed.

The first new focused run failed to load because the new Email budget class did not yet exist.
After implementation, the initial two-channel threshold tests passed two runs and 24 assertions.
Expanded channel tests cover scope isolation, malformed/corrupt inputs, expired budgets, outage and
separate-client concurrent increments.

`bin/rails test test/models/channel_otp_verification_failure_budget_test.rb
test/models/otp_verification_failure_budget_test.rb test/models/auth_email_otp_challenge_test.rb
test/operations/contact_registration_otp_verification_committer_test.rb
test/operations/contact_registration_otp_resend_issuer_test.rb` passed: 189 runs, 1,620 assertions,
zero failures, errors or skips. It used the normal runner without extra command environment variables.

An earlier expanded run produced 183 runs, 1,396 assertions, zero failures and 30 errors because
AuthEmailOtpChallengeTest lacked APP/COM sign-in state reference rows. Errors occurred during admission
parent creation, before budget comparison. Test setup now supplies the two classes' semantic DEFAULTS;
the Auth challenge file then independently passed 32 runs and 166 assertions before the combined
green run. No assertions were removed or relaxed.

Six concrete identifiers now each exercise retained-failure boundaries 0, 1, MAX-1, MAX, MAX+1,
issuance, resend, expired proof, cancellation and explicit consumed-success clearing.
`bin/rails test test/models/otp_failure_retention_test.rb` passed 26 runs, 226 assertions, zero
failures, errors or skips. These coverage additions passed the already implemented channel policies;
they do not certify migration of every HTTP flow to ceremony-owned proof.

Overlapping selections are not additive. Full Rails tests, full RuboCop and final invariant checks
remain outstanding. No production, external secret or GitHub mutation was performed.

Focused RuboCop passed for twelve changed policy, caller and test files; `git diff --check` passed.

HTTP/signup expansion initially produced 89 runs, 182 assertions, zero failures and 84 errors:
the endpoint tests lacked their own sign-in state rows and signup tests lacked flow/cleanup
reference rows. Each affected test class now creates the necessary semantic DEFAULTS in its
framework setup, without adding application test-only behavior. The signup service file passed
20 runs and 199 assertions. The APP/COM Email sign-in and Contact resend HTTP selection passed
69 runs and 908 assertions, with zero failures, errors or skips. These are overlapping focused
selections, not a full-suite result.

After removing the existing COM endpoint test's code-side corporate-host defaults, its required
configuration rerun passed 19 runs, 173 assertions, zero failures, errors or skips.
