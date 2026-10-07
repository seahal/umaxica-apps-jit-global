# Sign-in resend binding-fact verification

- Commit: `6fa6867d44b5499632079775cb0fb22cbfddd339`.
- The worktree contains inherited and current uncommitted changes affecting these results.
- Database scope: owned disposable 20-database fleet, manifest
  `tmp/auth-boundary-isolated-20261007fresh3.json`, run `20261007fresh3`.
  No shared or production database was modified.

## Reproduction and implementation

The APP public HTTP regression retained the actual code-entry resend state, released the original
binding and finalized the same address for another Identity. Before the fix it returned 200 instead
of 400 and could rotate the successor Contact's OTP: 1 run, 6 assertions, 1 failure (seed 42).
Version-2 encrypted state now snapshots Contact reference, owner and immutable binding fact.
Resend locks and rechecks that exact Contact and destination digest; it does not resolve by address.
The separate regression for a stale code-entry GET initially raised in APP and COM:
3 runs, 15 assertions, 2 errors, no skips. Both loaders now reject released Contacts before
issuing state and use the ordinary restart redirect.

Dummy state remains dummy after subsequent effective registration. Equal-width encrypted proof
fields prevent the existence flag from changing the observed ciphertext length.
The server-owned Auth continuity digest remains part of MessageEncryptor purpose verification.
No request-supplied owner or continuity value becomes authority.

## Executed checks

- `bin/rails test test/services/sign/in/otp_resend_service_test.rb -i /encrypted_state_length/ --seed 42`:
  1 run, 1 assertion, 0 failures, errors or skips.
- `bin/rails test test/controllers/auth/app/web/v0/in/email/otps_controller_test.rb
  test/controllers/auth/com/web/v0/in/email/otps_controller_test.rb --seed 42`:
  13 runs, 102 assertions, 0 failures, errors or skips.
- Final focused selection: `bin/rails test test/controllers/auth/app/in/emails_controller_test.rb
  test/controllers/auth/com/in/emails_controller_test.rb
  test/controllers/auth/app/web/v0/in/email/otps_controller_test.rb
  test/controllers/auth/com/web/v0/in/email/otps_controller_test.rb
  test/services/sign/in/otp_resend_service_test.rb
  test/services/sign_in_otp_resender_failures_test.rb
  test/services/sign/in/otp_resend_policy_test.rb --seed 42`:
  101 runs, 778 assertions, 0 failures, errors or skips.
- COM's HTTP cooldown test now executes the actual resender against a persisted occurrence and
  verifies refusal, body/header retry-window agreement and unchanged issued-history instead of
  replacing the resender with a canned response.
- Scoped RuboCop on the two resend services, APP/COM email sign-in controllers, service tests
  and both resend endpoint test files: 7 files inspected, no offenses, exit 0.
- Two attempted selections used incorrect test paths and exited with InvalidTestError before
  testing; paths were corrected before the final selection. These are not passing runs.

This is targeted Phase-19 evidence, not Final Verification. Full flow-specific OTP storage,
delivery-time lifecycle refusal, complete timing distributions and the remaining fault matrix
are not certified. Social callbacks and COM recovery distribution are unchanged. No checkbox
was completed on the strength of this partial verification.
