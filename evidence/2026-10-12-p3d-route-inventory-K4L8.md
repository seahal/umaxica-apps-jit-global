# P3d current route and legacy-proof inventory

Date: 2026-10-12

Repository: `/home/global/workspace`

Branch: `feature`

Code HEAD: `ccceabd05d2e3a8f923ce398046f99d026a5b78e`

The worktree was already dirty. Existing staged, unstaged and untracked changes were preserved;
no reset, clean, stash, worktree, push, production operation or shared-database operation was used.
The run-owned PostgreSQL manifest was `tmp/acceptance-isolated-20261010p8b-primary.json`, with
four Rails workers and all twenty declared databases.

## Current-source inventory

The executable current-source search covered `app/`, `lib/` and `config/` Ruby/Rake files for
`otp_private_key`, `otp_counter`, `sign_up_otp_context`, `credential_registration_otp_context`,
`store_otp`, `get_otp`, `clear_otp`, `otp_expired?` and `otp_active?`. It found no current writer,
reader or lifecycle method for the retired identifier-owned proof. The remaining occurrences are
outside that runtime inventory: ceremony contract forbidden-claim lists, parameter-filtering and
legacy translation metadata, or public adapter arguments that reject retired counters before
transport. The six identifier tables have no retired proof columns in the current structure dumps;
`otp_expires_at` occurrences in current runtime code belong to concrete ceremony transactions.

The source/consumer inventory was also checked across the current issuer, delivery-guard,
notifier, verification-committer, finalizer, reentry and sign-up operation families. The current
proof boundary is ceremony-owned; model-owned writes found by the inventory are limited to the
channel-specific failure counter, lock deadline and issuance timestamp required by the accepted
Email/Telephone policy. No identifier-owned HOTP material is written by those paths.

## Public route regression collection

The following current public operation, delivery, proof, adapter and integration tests were run
with the run-owned manifest:

```text
bundle exec rails test \
  test/adapters/signup_otp_delivery_payload_test.rb \
  test/adapters/otp_email_notifier_adapter_test.rb \
  test/adapters/otp_telephone_adapter_test.rb \
  test/models/otp_failure_retention_test.rb \
  test/models/ceremony_otp_delivery_test.rb \
  test/models/ceremony_otp_verification_receipt_test.rb \
  test/models/channel_otp_verification_failure_budget_test.rb \
  test/models/credential_registration_otp_proof_database_test.rb \
  test/models/email_ceremony_otp_verification_admission_test.rb \
  test/models/signup_otp_proof_database_test.rb \
  test/models/telephone_ceremony_otp_verification_admission_test.rb \
  test/notifiers/notify/email_credential_registration_otp_delivery_test.rb \
  test/notifiers/notify/email_reentry_otp_delivery_test.rb \
  test/notifiers/notify/email_sign_up_otp_delivery_test.rb \
  test/operations/contact_registration_otp_bootstrap_finalizer_test.rb \
  test/operations/contact_registration_otp_delivery_issuer_test.rb \
  test/operations/contact_registration_otp_finalizer_test.rb \
  test/operations/contact_registration_otp_issuer_test.rb \
  test/operations/contact_registration_otp_resend_issuer_test.rb \
  test/operations/contact_registration_otp_verification_committer_test.rb \
  test/operations/email_credential_registration_otp_bootstrap_delivery_test.rb \
  test/operations/email_credential_registration_otp_delivery_guard_test.rb \
  test/operations/email_credential_registration_otp_issuer_test.rb \
  test/operations/email_credential_registration_otp_resend_issuer_test.rb \
  test/operations/email_reentry_otp_issuer_test.rb \
  test/operations/email_reentry_otp_verification_committer_test.rb \
  test/operations/email_sign_up_otp_issuer_test.rb \
  test/operations/sign_up_otp_delivery_guard_test.rb \
  test/operations/sign_up_otp_delivery_issuer_test.rb \
  test/operations/telephone_credential_registration_otp_finalizer_test.rb \
  test/operations/telephone_credential_registration_otp_issuer_test.rb \
  test/operations/telephone_credential_registration_otp_verification_committer_test.rb \
  test/operations/telephone_sign_up_otp_issuer_test.rb \
  test/services/sign/telephone_otp_delivery_test.rb \
  test/integration/contact_registration_otp_bootstrap_receipt_recovery_test.rb \
  test/integration/contact_registration_otp_delivery_lock_test.rb \
  test/integration/contact_registration_otp_http_resend_test.rb \
  test/integration/contact_registration_otp_noticed_transport_test.rb \
  test/integration/contact_registration_otp_transport_binding_test.rb \
  test/integration/telephone_credential_registration_otp_delivery_test.rb \
  test/integration/telephone_sign_up_otp_delivery_test.rb \
  test/integration/telephone_signup_http_delivery_test.rb \
  test/integration/telephone_signup_source_proof_retry_test.rb
```

Observed result: `682 runs, 10952 assertions, 0 failures, 0 errors, 0 skips` with four workers.
This is route and consumer evidence for the current dirty worktree. It is not a claim that every
HTTP family, provider callback or cross-database fault scenario in CONTACT-4/5 has been exercised.
The remaining acceptance work is the explicit route matrix and fault campaign, not a discovered
identifier-owned HOTP writer.

After the focused run, a read-only PostgreSQL catalog/session check reported zero
`codex_integrity_20261010p8b_w%` worker databases and zero active sessions.

No application or schema changes were made by this inventory-only step. The full Rails/Vitest Gate
2 result recorded in `evidence/2026-10-12-p3d-adapter-retirement-gate-J8R4.md` remains the latest
full-suite result for the current implementation state; this focused run was performed afterward
without changing application behavior.
