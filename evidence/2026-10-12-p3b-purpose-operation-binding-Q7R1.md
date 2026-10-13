# OTP purpose and operation binding evidence

Date: 2026-10-12

Repository: `/home/global/workspace`

Tested HEAD: `7576ff7cbc6787f7f80f1f42bfa538914ace6de1`

The worktree contained pre-existing implementation, test, migration, configuration and document
changes. This slice preserved them and was tested against the run-owned PostgreSQL manifest
`tmp/acceptance-isolated-20261010p8b-primary.json`; no shared or production database was used.

## Change

Email and Telephone ceremony OTP concerns now require a purpose/operation pair from the concrete
mapping documented in `adr/realm-separated-identifiers-and-dead-history.md`. Issuance validates the
pair after `with_lock` reloads the row. Delivery, verification and retained-evidence lookup apply the
same guard. The tests also mutate the persisted operation through the public issuance boundary to
confirm that a stale in-memory operation cannot issue proof.

## TDD and focused verification

The initial Red test at the public transaction boundary produced:

```text
17 runs, 253 assertions, 2 failures, 0 errors, 0 skips
```

After the smallest production change, the focused transaction/receipt/terminal collection passed:

```text
41 runs, 943 assertions, 0 failures, 0 errors, 0 skips
```

After lock-time revalidation was added, the focused transaction/receipt collection passed:

```text
31 runs, 517 assertions, 0 failures, 0 errors, 0 skips
```

The commands used the run-owned database manifest and four Rails workers:

```text
RAILS_ENV=test PARALLEL_WORKERS=4 POSTGRESQL_ISOLATED_TEST_RUN_ID=20261010p8b \
POSTGRESQL_ISOLATED_TEST_MANIFEST=tmp/acceptance-isolated-20261010p8b-primary.json \
POSTGRESQL_TEST_HOST=primary POSTGRESQL_DATABASE=postgres \
POSTGRESQL_TEST_PREPARE_DATABASES=<manifest database names> \
bundle exec rails test test/models/ceremony_otp_verification_receipt_test.rb \
  test/models/concerns/ceremony_transactionable_test.rb \
  test/models/ceremony_otp_terminal_database_test.rb
```

Targeted RuboCop passed for:

```text
app/models/concerns/email_ceremony_otp.rb
app/models/concerns/telephone_ceremony_otp.rb
test/models/concerns/ceremony_transactionable_test.rb
test/models/ceremony_otp_verification_receipt_test.rb
config/initializers/opentelemetry.rb
```

## Regression gates

After the final code change, the run-owned full Rails command was executed with the same manifest and
four workers. It passed:

```text
15198 runs, 128490 assertions, 0 failures, 0 errors, 0 skips
```

The JavaScript gate was also executed:

```text
Test Files  99 passed (99)
Tests       1140 passed (1140)
```

No CI or Podman command was used. This evidence covers the tested dirty worktree at the stated HEAD;
it is not an independent acceptance decision and does not close the remaining route/applicability,
retention, D-11, cutover or production-runtime items in `nine.md`.
