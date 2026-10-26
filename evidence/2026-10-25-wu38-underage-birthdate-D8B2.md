# WU-38 / D-178: underage birthdate is never written; late Passkey save refused only

Revision: `bde2346c17e2aa911acc95de1f6035f80498f2da`, with extensive uncommitted work (other agents, Codex and this change).

## Change

- `SignUpSequenceControllerSupport#clear_sign_up_birthdate_requirement` (shared by APP
  email/telephone/Google/Apple and COM email/telephone) validates the unsaved birthdate, decides age,
  and saves only an eligible value. Underage: attribute restored, attempt halted through
  `SignUpTermination` (same-request cleanup, unchanged).
- `Auth::App::Sign::Up::Check::Telephone::PasskeysController#save_passkey_registration!`: an expired
  Flow is refused like a terminal or lapsed one; no inline expire/cleanup (D-177).
- Docs: one.md D-177 wording and D-178; two.md WU-38; `docs/policy/signup-eligibility.md`;
  `docs/security/sign-up-sequence.md`; `docs/security/credential-abuse-rate-limits.md`;
  `docs/mermaid/idp-visitor-sign-up.mmd`; `docs/mermaid/idp-state-machine-transition-inventory.md`;
  `docs/checklists/authentication.md` AUTH-21; acceptance A38-5/A38-6.

## Observed

- Red: with the old order (save before the age check) restored temporarily, the COM underage test
  failed: one `UPDATE "visitors" SET "birthdate"` was recorded. Restored; it passes.
- The APP/COM birthdate test files used the retired admission form sequence; their setup now uses
  `bootstrap_auth_sign_in_admission!`. The APP Email-resubmission test was rewritten to the D-177
  refusal (its subject, superseding an in-progress attempt, was removed).
- `bin/rails test` on the three birthdate controller files, APP/COM email and telephone up
  controllers, locator, hold query/refusal, curfew cleanup, age eligibility, eligibility policy and
  HasBirthdate: 276 runs, 2,700 assertions, 0 failures, 0 errors.

## Not verified

`test/concurrency/sign_up_passkey_termination_http_test.rb` (rewritten for D-177) fails in setup
because reference rows are absent in the reset test databases; a separate test-isolation task owns
that. Full suite not run. 

## Addendum: OTP inline expiry removed; Passkey concurrency test

- `{Email,Telephone}SignUpOtp{Issuer,VerificationCommitter,DeliveryGuard}` no longer call
  `SignUpTermination` for an overdue parent (owner decision 2026-10-25). Tests that expected EXPIRED
  now assert the Flow stays nonterminal. `bin/rails test` on the four `*sign_up_otp*` operation
  tests, `signup_otp_delayed_transport_test.rb` and `sign_otp_ceremony_lock_deadline_test.rb`: 94 runs,
  0 failures after the issuer follow-up assertion was corrected (38 runs for the two issuer files).
- `sign_up_passkey_termination_http_test.rb` (reference rows now ensured in its setup by the
  isolation task; travel kept past the deadline): `PARALLEL_WORKERS=1`, 5 runs, 151 assertions,
  0 failures.
- Not fixed: APP/COM `check/{email,telephone}/otps_controller_test.rb` still fail in their setup on
  the retired admission form sequence (Design D), unrelated to this change.
