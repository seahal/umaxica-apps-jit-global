# TOTP ceremony reference generation evidence

- Date: 2026-10-12
- Tested HEAD: `7576ff7cbc6787f7f80f1f42bfa538914ace6de1`
- Worktree: pre-existing dirty implementation tree; no unrelated paths were reset or discarded.
- Database: run-owned disposable PostgreSQL manifest
  `tmp/acceptance-isolated-20261010p8b-primary.json`; no shared or production database was used.

## Change

The APP TOTP ceremony transaction factory now issues independently generated NanoID-21 values for
`transaction_id` and `grant_jti` through `PublicId.generate`. It retries only an exact generated
single-column unique B-tree collision inside a savepoint and the finite `PublicId` collision budget.
The enrollment issuer delegates this responsibility to the factory instead of keeping a second retry
loop. Explicit caller-supplied identifiers and unrelated failures remain errors. Result identities,
OTP generations, TOTP secrets and protocol values were not changed.

## Verification

The initial Red test reproduced the previous UUID generation at the public factory boundary:
`5 runs, 33 assertions, 1 failure, 0 errors, 0 skips`.

The focused TOTP collection was:

```text
43 runs, 398 assertions, 0 failures, 0 errors, 0 skips
```

Command:

```text
RAILS_ENV=test PARALLEL_WORKERS=1 POSTGRESQL_ISOLATED_TEST_RUN_ID=20261010p8b \
POSTGRESQL_ISOLATED_TEST_MANIFEST=tmp/acceptance-isolated-20261010p8b-primary.json \
POSTGRESQL_TEST_HOST=primary POSTGRESQL_DATABASE=postgres \
POSTGRESQL_TEST_PREPARE_DATABASES=<manifest database names> \
bundle exec rails test \
test/operations/identity_totp_enrollment_issuer_test.rb \
test/operations/identity_totp_ceremony_result_issuer_test.rb \
test/operations/identity_totp_enrollment_final_committer_test.rb \
test/operations/identity_totp_enrollment_verification_committer_test.rb \
test/services/identity/totp_ceremony_contract_test.rb \
test/operations/identity_totp_ceremony_transaction_purger_test.rb \
test/jobs/totp_ceremony_transaction_purge_job_test.rb
```

Targeted RuboCop passed for the two production files and the changed test:

```text
3 files inspected, no offenses detected
```

After the code change, the shared-worktree full Rails gate passed:

```text
15199 runs, 128493 assertions, 0 failures, 0 errors, 0 skips
```

with four parallel workers against the same run-owned manifest. `bun run test` also passed:

```text
99 files passed, 1140 tests passed
```

The run did not use CI, Podman, production services, external delivery, shared destructive
operations or remote synchronization. This is implementation evidence, not independent acceptance
or proof of untested external/provider behavior.
