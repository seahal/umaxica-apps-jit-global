# Email authentication regression completion

- Date: 2026-11-03.
- Revision: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`. Extensive pre-existing uncommitted work
  affects these results. No commit was created.
- Scope: the Email sign-in/sign-up handoff in `zero.md` (2026-11-03 03:00), expanded to OTP
  issuance, notifier delivery, proof binding, enumeration/isolation, and Source/Ticket failure
  windows. This is not a full repository or every email-related feature acceptance.

## Corrections and observed discrepancies

The first focused run of the two Email checkpoint controller files and the Root-completion journey
produced **27 runs / 300 assertions / 26 failures / 0 errors / 0 skips**. The delivery coordinator's
committed-Source/Ticket requirement rejected their ambient test transactions.

The two controller files and the Root-completion journey now exercise real commits without global
fixtures, retaining existing HTTP entry and assertions. The Source-audit HTTP file needed the same
correction when broader tests reached it. Teardown removes only rows created during each serialized
test, including completion receipts, account rows and the bootstrap identity/persona/enterprise
graph. The session initially exposed incomplete teardown: its 29 retained synthetic owners and
subsequently identified 27 bootstrap graphs were removed with guarded, test-only cleanup. No
existing test fleet or development database was reset. After the final 200-test run, read-only
queries found zero session-owned bootstrap identities and zero persona memberships/enterprise units
in the test source database; subsequent fixture-based guards passed.

Other discrepancies resolved:

- OTP deadline tests advanced browser wall time as well as the Ticket clock. The database-selector
  delay then switched GET reads to the separate replica fixture database, where the newly committed
  candidate did not exist. Control only the owning Ticket clock for the before/equal/after deadline
  checks; retain the real HTTP read and mutation paths. The originally failing boundary also passed
  in the final combined seed.
- Old cancellation assertions expected an Auth-local signup restart. The existing implementation and
  current continuation contract end the admission through Visa. Tests verify the signed cancellation
  destination and require a fresh Base admission before a new attempt.
- The Root-completion journey expected the obsolete Auth POST and Base completion endpoint. It now
  supplies navigation metadata to Auth's handoff and verifies Visa's read-only result GET and
  existing authorization POST, CSRF and foreign-browser refusals, original-parent ownership, and
  single-Root replay behavior.
- The notifier unit test called the committed HTTP delivery coordinator under a transaction. It now
  invokes the real OTP issuer and notifier directly; committed coordinator behavior remains covered
  by the HTTP delivery tests.
- Real commit tests exposed two unhandled `FlowInvalidTransition` cases at final registration
  authorization: an expired Flow and a suspended actor. The checkpoint finalizer now returns the
  existing browser expiry/validation responses, invokes the existing expiry state-machine writer for
  an overdue Flow, and preserves the original error/reconciliation path when a committed
  registration receipt exists. Existing Source-audit cases verify no contact finalization/audit on
  refusal and preservation/reconciliation after Source commit. No new lifecycle state, issuer, route
  or schema was introduced.
- Temporary predicate-only clock diagnostics were removed; `EmailSignUpOtpFormQuery` was restored
  byte-for-byte to its pre-diagnostic content.

The initial expanded boundary run was **70 runs / 874 assertions / 12 failures / 1 error / 0
skips**. After enabling real commits, the remaining two Source-authorization exceptions reproduced
as errors, then passed after the HTTP correction (**13 runs / 568 assertions / 0 failures / 0 errors
/ 0 skips**). One attempted repeat was refused by the shared test-process lock; it ran no tests and
was retried after the other process completed. No lock was bypassed.

## Final verification

All Rails commands below used:

```text
UMAXICA_ENV_FILE=/home/global/workspace/.env.container.devcontainer RAILS_ENV=test PARALLEL_WORKERS=1
```

`bin/rails test <the following 23 paths> --seed 43071` completed with **200 runs / 3,288 assertions
/ 0 failures / 0 errors / 0 skips**, exit 0:

- `test/controllers/auth/app/in/emails_controller_test.rb`
- `test/controllers/auth/app/in/emails_controller_extra_test.rb`
- `test/controllers/auth/app/in/emails_controller_security_test.rb`
- `test/controllers/auth/app/in/emails_controller_enumeration_test.rb`
- `test/controllers/auth/app/web/v0/in/email/otps_controller_test.rb`
- `test/controllers/auth/app/sign/up/check/email/otps_controller_test.rb`
- `test/controllers/auth/app/sign/up/check/email/birthdates_controller_test.rb`
- `test/integration/email_signup_http_delivery_commit_test.rb`
- `test/integration/email_signup_base_root_completion_test.rb`
- `test/operations/email_sign_up_candidate_creator_test.rb`
- `test/operations/email_sign_up_otp_issuer_test.rb`
- `test/operations/email_reentry_otp_issuer_test.rb`
- `test/operations/email_reentry_otp_verification_committer_test.rb`
- `test/notifiers/notify/email_sign_up_otp_delivery_test.rb`
- `test/notifiers/notify/email_reentry_otp_delivery_test.rb`
- `test/values/email_sign_up_otp_delivery_binding_value_test.rb`
- `test/values/auth_email_otp_delivery_binding_value_test.rb`
- `test/values/email_reentry_otp_delivery_binding_value_test.rb`
- `test/mailers/email/otp_verification_token_storage_test.rb`
- `test/mailers/email/auth_email_otp_delivery_binding_test.rb`
- `test/integration/email_sign_in_enumeration_parity_test.rb`
- `test/integration/email_sign_in_flow_isolation_test.rb`
- `test/integration/contact_email_signup_source_audit_test.rb`

`bin/rails test <the following six paths>` completed with **21 runs / 72 assertions / 0 failures / 0
errors / 0 skips**, exit 0:

- `test/operations/app_sign_up_registration_receipt_test.rb`
- `test/security/invariants/lifecycle_direct_state_write_invariant_test.rb`
- `test/security/invariants/csrf_verification_strategy_invariant_test.rb`
- `test/security/invariants/auth_phase_refusal_response_writer_invariant_test.rb`
- `test/unit/security/standard_csrf_invariant_test.rb`
- `test/unit/security/forbidden_rails_patterns_test.rb`

Frontend command:

```text
bun run test gait/features/auth/signin/signin_interaction.test.tsx gait/features/auth/signin/signin_screens.test.tsx gait/features/auth/signup/contact_sign_up_form.test.tsx
```

Result: **3 files / 55 tests passed**, exit 0.

Scoped `bin/rubocop` passed for the controller concern and five changed test files (6 files, no
offenses). Scoped `git diff --check` passed. The current signup diagram, transition inventory and
authentication-flow checklist were updated with the existing refusal/expiry behavior.

Raw output remains outside the repository in `/tmp/email-final-regression-20261103.log`,
`/tmp/email-guards-20261103.log`, `/tmp/email-ui-20261103.log` and
`/tmp/email-style-final-20261103.log`. Provider/mail transport is exercised through the existing
local test adapters, not real recipient delivery. Live browser journeys, production/CDN transport,
all other email features and the full repository suite were not run.
