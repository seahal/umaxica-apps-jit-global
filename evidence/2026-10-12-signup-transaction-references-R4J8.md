# Sign-up transaction-reference boundary evidence

Date: 2026-10-12

This record describes checks performed against full HEAD `6c61d2c0c0436508cdae149313a0abb6ab911fa4`
with the application and test changes for this slice uncommitted in the shared worktree. The working
tree also contained unrelated pre-existing changes; the commands below were run against the
run-owned isolated PostgreSQL manifest `tmp/acceptance-isolated-20261010p8b-primary.json`, not a
shared or production database.

## Scope

The slice covers APP and COM Email/Telephone sign-up transaction issuers and the corresponding
session/delivery binding readers. New transaction references are generated as NanoID-21 values;
existing UUID-v4 transaction references remain readable. OTP `generation` remains a UUID-v4 one-time
proof identity. Collision recovery is limited to the concrete named single-column `transaction_id`
unique B-tree index and uses a savepoint with a finite retry budget. No cross-purpose or
cross-surface fallback was added.

## Red

Command:

```text
scope=$(ruby -rjson -e 'm=JSON.parse(File.read("tmp/acceptance-isolated-20261010p8b-primary.json")); print m.fetch("databases").map { |d| d.fetch("name") }.join(",")')
RAILS_ENV=test PARALLEL_WORKERS=4 POSTGRESQL_ISOLATED_TEST_RUN_ID=20261010p8b POSTGRESQL_ISOLATED_TEST_MANIFEST=tmp/acceptance-isolated-20261010p8b-primary.json POSTGRESQL_TEST_HOST=primary POSTGRESQL_DATABASE=postgres POSTGRESQL_TEST_PREPARE_DATABASES="$scope" bundle exec rails test test/operations/email_sign_up_otp_issuer_test.rb test/operations/telephone_sign_up_otp_issuer_test.rb
```

The new NanoID assertions failed against the former UUID issuers:
`30 runs, 386 assertions, 4 failures, 0 errors, 0 skips`.

## Green and focused regression

After the issuer and binding changes, the focused issuer collection passed
`34 runs, 502 assertions, 0 failures, 0 errors, 0 skips`.

The focused command was:

```text
RAILS_ENV=test PARALLEL_WORKERS=4 POSTGRESQL_ISOLATED_TEST_RUN_ID=20261010p8b POSTGRESQL_ISOLATED_TEST_MANIFEST=tmp/acceptance-isolated-20261010p8b-primary.json POSTGRESQL_TEST_HOST=primary POSTGRESQL_DATABASE=postgres POSTGRESQL_TEST_PREPARE_DATABASES="$scope" bundle exec rails test test/operations/email_sign_up_otp_issuer_test.rb test/operations/telephone_sign_up_otp_issuer_test.rb
```

The binding-value collection passed `6 runs, 272 assertions, 0 failures, 0 errors, 0 skips`. The
broader sign-up delivery and transport collection passed
`114 runs, 2316 assertions, 0 failures, 0 errors, 0 skips` and covered delayed transport, delivery
guards, telephone delivery, telephone source-proof retry and contact-email source audit paths.

The binding-value command was:

```text
bundle exec rails test test/values/sign_up_otp_delivery_binding_value_test.rb test/values/email_sign_up_otp_delivery_binding_value_test.rb
```

The broader command was:

```text
bundle exec rails test test/operations/email_sign_up_otp_issuer_test.rb test/operations/telephone_sign_up_otp_issuer_test.rb test/operations/sign_up_otp_delivery_guard_test.rb test/integration/telephone_sign_up_otp_delivery_test.rb test/integration/signup_otp_delayed_transport_test.rb test/integration/telephone_signup_source_proof_retry_test.rb test/integration/contact_email_signup_source_audit_test.rb
```

Targeted RuboCop passed for these eight changed Ruby files:

- `app/operations/email_sign_up_otp_issuer.rb`
- `app/operations/telephone_sign_up_otp_issuer.rb`
- `app/values/email_sign_up_otp_delivery_binding_value.rb`
- `app/values/telephone_sign_up_otp_delivery_binding_value.rb`
- `test/operations/email_sign_up_otp_issuer_test.rb`
- `test/operations/telephone_sign_up_otp_issuer_test.rb`
- `test/values/sign_up_otp_delivery_binding_value_test.rb`
- `test/values/email_sign_up_otp_delivery_binding_value_test.rb`

The result was `8 files inspected, no offenses detected`.

The RuboCop command was:

```text
bundle exec rubocop app/operations/email_sign_up_otp_issuer.rb app/operations/telephone_sign_up_otp_issuer.rb app/values/email_sign_up_otp_delivery_binding_value.rb app/values/telephone_sign_up_otp_delivery_binding_value.rb test/operations/email_sign_up_otp_issuer_test.rb test/operations/telephone_sign_up_otp_issuer_test.rb test/values/sign_up_otp_delivery_binding_value_test.rb test/values/email_sign_up_otp_delivery_binding_value_test.rb
```

## Gate 2

Using the run-owned twenty-database scope and four Rails workers, the full Rails command
`bundle exec rails test` passed:

```text
15167 runs, 128354 assertions, 0 failures, 0 errors, 0 skips
```

The full Vitest command `bun run test` passed `99 files` and `1140 tests`.

## Limits

These results are revision-scoped evidence, not a permanent acceptance result. They do not prove the
remaining unclassified ceremony transaction, grant, result or OTP-generation inventory, direct SQL
immutability, D-11 committed-transaction isolation, production behavior, Podman/host runtime
configuration, CI behavior, shared-database safety or the independent acceptance investigation. No
CI, Podman, production operation, external send, shared destructive operation or remote
synchronization was used. No secrets, raw OTPs, tokens, personal data or database dumps were
recorded.
