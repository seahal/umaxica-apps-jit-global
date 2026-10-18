# Sign-up grant-reference boundary evidence

Date: 2026-10-12

This record describes checks performed against full HEAD `46e9ea9066d99849651e67a2906d6b61772d5e7e`
with the application, test and locale changes for this slice uncommitted in the shared worktree. The
commands used the run-owned isolated PostgreSQL manifest
`tmp/acceptance-isolated-20261010p8b-primary.json`; no shared or production database was used.

## Scope

The slice covers APP and COM Email/Telephone sign-up grant issuance and its existing signed
transaction binding. New `grant_jti` values are NanoID-21, while existing UUID-v4 grant values stay
valid opaque claims. The transaction reference and grant reference remain separate. Generated
collisions are retried only for the named single-column `transaction_id` or `grant_jti` unique
B-tree index, inside a savepoint and the finite shared retry budget.

## Red

The focused command was run with the twenty run-owned databases and four workers:

```text
scope=$(ruby -rjson -e 'm=JSON.parse(File.read("tmp/acceptance-isolated-20261010p8b-primary.json")); print m.fetch("databases").map { |d| d.fetch("name") }.join(",")')
RAILS_ENV=test PARALLEL_WORKERS=4 POSTGRESQL_ISOLATED_TEST_RUN_ID=20261010p8b POSTGRESQL_ISOLATED_TEST_MANIFEST=tmp/acceptance-isolated-20261010p8b-primary.json POSTGRESQL_TEST_HOST=primary POSTGRESQL_DATABASE=postgres POSTGRESQL_TEST_PREPARE_DATABASES="$scope" bundle exec rails test test/operations/email_sign_up_otp_issuer_test.rb test/operations/telephone_sign_up_otp_issuer_test.rb
```

The new assertions reproduced the previous UUID issuers and missing grant-collision handling:
`38 runs, 510 assertions, 8 failures, 0 errors, 0 skips`.

## Green and focused regression

The first Green attempt generated both references but raised four errors while Rails looked up a
missing `grant_jti` validation label: `38 runs, 506 assertions, 0 failures, 4 errors, 0 skips`. The
four locale fallback maps were then supplied with the existing neutral `grant_jti` attribute label.
After formatting, the focused command above passed:

```text
38 runs, 522 assertions, 0 failures, 0 errors, 0 skips
```

The broader sign-up command was:

```text
bundle exec rails test test/operations/email_sign_up_otp_issuer_test.rb test/operations/telephone_sign_up_otp_issuer_test.rb test/operations/sign_up_otp_delivery_guard_test.rb test/integration/telephone_sign_up_otp_delivery_test.rb test/integration/signup_otp_delayed_transport_test.rb test/integration/telephone_signup_source_proof_retry_test.rb test/integration/contact_email_signup_source_audit_test.rb
```

It passed `118 runs, 2336 assertions, 0 failures, 0 errors, 0 skips`.

Targeted RuboCop used:

```text
bundle exec rubocop app/operations/email_sign_up_otp_issuer.rb app/operations/telephone_sign_up_otp_issuer.rb test/operations/email_sign_up_otp_issuer_test.rb test/operations/telephone_sign_up_otp_issuer_test.rb
```

The final result was `4 files inspected, no offenses detected`. An earlier exploratory command
incorrectly included YAML locale files in RuboCop and produced parser diagnostics; it was not used
as a Ruby quality result and was followed by the targeted command above.

## Gate 2

The run-owned four-worker Rails Gate 2 passed:

```text
15171 runs, 128372 assertions, 0 failures, 0 errors, 0 skips
```

The full `bun run test` passed `99 files` and `1140 tests`.

## Limits

This is revision-scoped evidence, not a permanent acceptance result. It does not prove other grant
issuers, result identities, the complete ceremony-purpose inventory, direct-SQL immutability, D-11
committed-transaction isolation, production behavior, Podman/host runtime configuration, CI
behavior, shared-database safety or independent acceptance. No CI, Podman, production operation,
external send, shared destructive operation or remote synchronization was used. No secrets, raw OTP
values, tokens, personal data or database dumps were recorded.
