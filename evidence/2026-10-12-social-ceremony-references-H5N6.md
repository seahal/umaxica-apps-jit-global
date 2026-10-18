# Social ceremony transaction and grant-reference slice

This record covers the generated Social ceremony reference slice only. It is an execution record for
the current dirty tree, not a permanent acceptance result and not an independent review.

## Execution identity

- Repository: `/home/global/workspace`
- Branch: `feature`
- Full HEAD at execution: `93b59c289a70c971a95f1987f117a43cbf2cabdb`
- Worktree: pre-existing application, test, locale and document changes were preserved. The Social
  concern and test changes were uncommitted during verification.
- Rails test databases: the run-owned fleet described by
  `tmp/acceptance-isolated-20261010p8b-primary.json`; no shared or production database was used.
- CI, Podman, production operations, external delivery, remote synchronization and destructive
  shared-database operations were not used.

## TDD and focused verification

The first Red run strengthened the public Social transaction assertions and added generated
transaction- and grant-collision cases. It reproduced the former UUID generation and missing retry:

```text
5 runs, 18 assertions, 3 failures, 0 errors, 0 skips
```

The implementation then made `SocialCeremonyTransactionable.create_transaction!` use separate
`PublicId.generate` values for missing `transaction_id` and `grant_jti`. It retries only an exact
named single-column `transaction_id` or `grant_jti` unique B-tree collision inside a savepoint and
the finite `PublicId::MAX_COLLISION_RETRIES` budget. Explicit values, provider subject/candidate
values and unrelated failures remain explicit. OAuth/OIDC state, provider protocol values, candidate
capability references and `result_jti` were not changed.

The focused Social transaction collection passed:

```text
5 runs, 37 assertions, 0 failures, 0 errors, 0 skips
```

The related Social contract, result-issuer, consumer and integration collection passed:

```text
69 runs, 400 assertions, 0 failures, 0 errors, 0 skips
```

The targeted style check was:

```text
bundle exec rubocop app/models/concerns/social_ceremony_transactionable.rb \
  test/models/concerns/social_ceremony_transactionable_test.rb
```

Two files were inspected with no offenses.

## Full gates

Gate 2 ran the Rails suite with four workers against the run-owned database scope. Result:

```text
15182 runs, 128433 assertions, 0 failures, 0 errors, 0 skips
```

The command was `bundle exec rails test` with the manifest-backed `RAILS_ENV=test`,
`POSTGRESQL_ISOLATED_TEST_RUN_ID=20261010p8b`,
`POSTGRESQL_ISOLATED_TEST_MANIFEST=tmp/acceptance-isolated-20261010p8b-primary.json`,
`POSTGRESQL_TEST_HOST=primary`, `POSTGRESQL_DATABASE=postgres`, `POSTGRESQL_TEST_PREPARE_DATABASES`
set to the manifest database names, and `PARALLEL_WORKERS=4`. The run emitted existing Flipper,
OmniAuth and local-environment diagnostics but no test failures or errors.

Vitest was executed with `bun run test` and passed `99 files` and `1140 tests`.

## Scope and limits

This slice covers only generated `transaction_id` and `grant_jti` values for the APP Social ceremony
transaction model and its issuer. It does not classify or change Social `result_jti`, provider
subject values, OAuth/OIDC state, candidate capability references, permanent external-identity
identifiers or other ceremony transaction/grant/result issuers. It also does not establish
direct-SQL identifier immutability, D-11 committed-transaction isolation, Avatar cutover, retained
legacy identifier semantics, host Alloy recreation/runtime checks, privacy-retention policy or
independent acceptance. The application and test changes remain in the shared worktree and are
intentionally separate from the later document-only commit that records this evidence.
