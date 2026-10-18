# P3d ceremony delivery and proof matrix recheck

- Repository: `/home/global/workspace`
- Branch: `feature`
- HEAD: `ccceabd05d2e3a8f923ce398046f99d026a5b78e`
- Worktree: 213 changed paths were preserved; no reset, cleanup, commit or push was performed.
- Scope: existing Email/Telephone ceremony model, operation, integration and delivery tests on the run-owned PostgreSQL fleet `20261010p8b`, with four workers. No production or shared database was used.

## Command

```text
bundle exec rails test \
  test/models/ceremony_otp_delivery_test.rb \
  test/models/ceremony_otp_finite_deadline_test.rb \
  test/models/ceremony_otp_deadline_boundary_test.rb \
  test/models/email_ceremony_otp_verification_admission_test.rb \
  test/models/telephone_ceremony_otp_verification_admission_test.rb \
  test/models/telephone_ceremony_otp_reissue_test.rb \
  test/models/ceremony_otp_terminal_database_test.rb \
  test/models/signup_otp_proof_database_test.rb \
  test/models/credential_registration_otp_proof_database_test.rb \
  test/operations/contact_registration_otp_delivery_issuer_test.rb \
  test/operations/contact_registration_otp_verification_committer_test.rb \
  test/operations/contact_registration_otp_resend_issuer_test.rb \
  test/operations/email_credential_registration_otp_issuer_test.rb \
  test/operations/email_credential_registration_otp_delivery_guard_test.rb \
  test/operations/email_credential_registration_otp_bootstrap_delivery_test.rb \
  test/operations/email_credential_registration_otp_resend_issuer_test.rb \
  test/operations/telephone_credential_registration_otp_issuer_test.rb \
  test/integration/telephone_credential_registration_otp_delivery_test.rb \
  test/integration/telephone_sign_up_otp_delivery_test.rb \
  test/integration/telephone_signup_http_delivery_test.rb \
  test/integration/telephone_signup_source_proof_retry_test.rb \
  test/services/sign_otp_ceremony_test.rb \
  test/services/sign_otp_ceremony_lock_deadline_test.rb \
  test/services/sign_otp_ceremony_malformed_code_test.rb \
  test/services/sign/telephone_otp_delivery_test.rb
```

## Result

`418 runs, 6843 assertions, 0 failures, 0 errors, 0 skips` in 8.318 seconds.

This collection exercised ceremony expiry/deadline boundaries, purpose and binding checks,
DB proof-shape and terminal protections, Email and Telephone registration issuer/verifier/resend
paths, delivery guards, HTTP Telephone signup delivery and stale source-proof retry behavior.
It narrows but does not close the complete provider/credential, every realm/purpose concurrency,
source/fixture/constraint and cross-database transport inventory required by CONTACT-4/5.
The test helper's run-owned fleet was used; this record does not treat the result as a production
or shared-database verification.
