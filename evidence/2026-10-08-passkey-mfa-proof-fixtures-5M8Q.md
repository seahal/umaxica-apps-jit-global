# Passkey MFA primary Email proof fixtures

Commit: `6405c465c82dd45625d294ad8f8c2fe7827a4390`. The checkout contained uncommitted
implementation, migration, schema and test changes.

The existing APP/COM Passkey MFA cases now enter Auth through the public attach, confirm and redeem
sequence. Their Email candidates have effective bindings. Existing fixture bodies use the actual
encrypted queued code and current Auth ceremony generation rather than overwrite identifier HOTP.
Flow assertions use the public MFA/guardrail predicates, not the removed `step` attribute. TOTP
credential secrets and Passkey verification remain separate and unchanged. No new helper, production
bypass, test-helper infrastructure change or weakened refusal assertion was introduced.

- Initial two-file reproduction: 28 runs, 22 assertions, 22 failures, six errors, seed `46411`.
  Unadmitted Auth returned 400; interruption cases read the removed flow `step` attribute.
- After fixture migration: 28/308, no failures and fourteen COM setup errors, seed `53520`. Contact
  finalization advances its owner lock version; the fixture now reloads the Visitor before its
  subsequent MFA configuration update instead of bypassing optimistic locking.
- `bin/rails test test/controllers/auth/app/in/mfa/passkeys_controller_test.rb test/controllers/auth/com/in/challenge/passkeys_controller_test.rb`:
  28 runs, 594 assertions, zero failures/errors/skips, seed `43589`, 11.861672 seconds.
- `bundle exec rubocop test/support/auth_email_mfa_helper.rb test/controllers/auth/app/in/mfa/passkeys_controller_test.rb test/controllers/auth/com/in/challenge/passkeys_controller_test.rb`:
  three files, no offenses.

At this initial point, other callers of the existing fixture body still required focused
verification; the subsequent results are recorded below. No whole-suite pass or final Definition of
Done is claimed.

## Remaining MFA fixture callers

`bin/rails test test/controllers/auth/app/in/challenges_controller_test.rb test/controllers/auth/com/in/challenges_controller_test.rb test/controllers/auth/app/in/mfa/totps_controller_test.rb`
initially reproduced 23 failures in 29 cases, seed `20236`. Their existing fixtures now also use
public Auth admission, effective Contact bindings and the actual encrypted Email code. TOTP
verification itself was not modified.

After fixture migration, two cancellation cases expected the historical FAILED state rather than the
current `halt_sign_in!` transition, and one TOTP case expected a Root cookie from Auth. The
corrected tests verify HALTED and retained replay refusal; TOTP success verifies no Root token write
or access/refresh cookie, original Email attribution and the current checkpoint-pending flow. A
subsequent incorrect guardrail-pending assertion failed once and was aligned with the actual
`advance_pending_sign_in_flow_after_primary!` participant chain.

Final result: 29 runs, 486 assertions, zero failures/errors/skips, seed `24239`, 13.613555 seconds.
Scoped RuboCop on these three files and the corrected production cancellation comment passed. The
three realm sign-in diagrams and matching cancellation inventory rows now describe HALTED. The
removed TOTP failure diagnostic previously embedded the raw code and pending MFA data; normal
assertions retain useful failure status without exposing those values.
