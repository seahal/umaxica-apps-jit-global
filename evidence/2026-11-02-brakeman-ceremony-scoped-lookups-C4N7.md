# Scoped Auth ceremony lookups

- Commit: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`. Extensive pre-existing uncommitted changes
  were present. This verification includes the local changes to
  `app/controllers/concerns/base_step_up_intent.rb` and `app/mailers/email/app/otp_mailer.rb`.
- The APP and ORG redeemed Step-Up conflict continuation lookups now constrain both admission
  purpose and the already validated Step-Up transaction reference before selecting the admitted
  session ID. The existing active-session and restart checks remain.
- The APP sign-in OTP mailer lookup now constrains admission purpose to `authentication_handoff`.
  The existing locked delivery guard still verifies generation, destination, code, current contact
  binding, parent availability and expiry. Queue parameters do not become authentication authority.
- `bin/brakeman -q -o /tmp/brakeman-three-find.json`: exit 0; security warnings 0, including no
  UnscopedFind warnings. No ignore configuration was changed.
- `bin/rails test test/controllers/base/step_up_intent_authority_test.rb test/mailers/email/auth_email_otp_delivery_binding_test.rb`:
  40 runs, 0 assertions, 0 failures, 40 errors, 0 skips. All errors were fixture setup foreign-key
  violations: `avatars.lifecycle_state_id=1` lacks its referenced `avatar_lifecycle_states` row.
  Public behavior is not runtime-verified by this run. No fixture or database repair was performed.
- `bin/rubocop app/controllers/concerns/base_step_up_intent.rb app/mailers/email/app/otp_mailer.rb`:
  2 offenses in untouched methods, Metrics/AbcSize on `redirect_to_step_up_ceremony!` and
  Metrics/MethodLength on `issue_bootstrap_admission!`. Checking the HEAD version via
  `bin/rubocop --stdin app/controllers/concerns/base_step_up_intent.rb` reproduces those same
  offenses. No mailer offenses.
- Ruby syntax checks on both changed files and scoped `git diff --check`: passed.
