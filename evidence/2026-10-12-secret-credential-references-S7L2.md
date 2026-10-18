# Secret Credential ceremony transaction and grant-reference slice

This record covers the generated Secret Credential ceremony reference slice only. It is an execution
record for the current dirty tree, not a permanent acceptance result and not an independent review.

## Execution identity

- Repository: `/home/global/workspace`
- Branch: `feature`
- Full HEAD at execution: `124de15a7876dbd2db355d4235bf2c81e1f57b11`
- Worktree: pre-existing application, test, locale and document changes were preserved. The concern
  and replay-store test changes were uncommitted during verification.
- Rails test databases: the run-owned fleet described by
  `tmp/acceptance-isolated-20261010p8b-primary.json`; no shared or production database was used.
- CI, Podman, production operations, external delivery, remote synchronization and destructive
  shared-database operations were not used.

## TDD and focused verification

The first Red run added public replay-store/model expectations and reproduced the former UUID
generation and missing collision retry:

```text
7 runs, 16 assertions, 5 failures, 0 errors, 0 skips
```

The implementation then made `SecretCredentialCeremonyTransactionable.create_transaction!` use a
separate `PublicId.generate` value for each missing `transaction_id` and `grant_jti`. It retries
only an exact named single-column `transaction_id` or `grant_jti` unique B-tree collision inside a
savepoint and the finite `PublicId::MAX_COLLISION_RETRIES` budget. Explicit inputs, unrelated
validation or uniqueness failures and exhausted retries remain explicit failures. `result_jti`,
candidate references, secret material and actor/session references were not changed.

The focused replay-store collection passed:

```text
7 runs, 27 assertions, 0 failures, 0 errors, 0 skips
```

The related Secret Credential contract, result-issuer, final-committer, consumer and purger
collection passed:

```text
50 runs, 313 assertions, 0 failures, 0 errors, 0 skips
```

The targeted style check was:

```text
bundle exec rubocop app/models/concerns/secret_credential_ceremony_transactionable.rb \
  test/services/identity_secret_credential_ceremony_replay_store_test.rb
```

Two files were inspected with no offenses.

## Full gates

Gate 2 ran the Rails suite with four workers against the run-owned database scope. Result:

```text
15180 runs, 128432 assertions, 0 failures, 0 errors, 0 skips
```

The command was `bundle exec rails test` with the manifest-backed `RAILS_ENV=test`,
`POSTGRESQL_ISOLATED_TEST_RUN_ID=20261010p8b`,
`POSTGRESQL_ISOLATED_TEST_MANIFEST=tmp/acceptance-isolated-20261010p8b-primary.json`,
`POSTGRESQL_TEST_HOST=primary`, `POSTGRESQL_DATABASE=postgres`, `POSTGRESQL_TEST_PREPARE_DATABASES`
set to the manifest database names, and `PARALLEL_WORKERS=4`. The run emitted existing Flipper,
OmniAuth and local-environment diagnostics but no test failures or errors.

Vitest was executed with `bun run test` and passed `99 files` and `1140 tests`.

## Scope and limits

This slice covers only generated `transaction_id` and `grant_jti` values for the concrete APP, COM
and ORG Secret Credential ceremony transaction models. It does not classify or change `result_jti`,
permanent secret-credential identifiers, candidate references, protocol values or other ceremony
transaction/grant/result issuers. It also does not establish direct-SQL identifier immutability,
D-11 committed-transaction isolation, Avatar cutover, retained legacy identifier semantics, host
Alloy recreation/runtime checks, privacy-retention policy or independent acceptance. The application
and test changes remain in the shared worktree and are intentionally separate from the later
document-only commit that records this evidence.
