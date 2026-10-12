# Email reentry transaction-reference slice

This record covers the Email recovery/withdrawal reentry reference slice only. It is an execution
record for the current dirty tree, not a permanent acceptance result and not an independent review.

## Execution identity

- Repository: `/home/global/workspace`
- Branch: `feature`
- Full HEAD at execution: `28371962c8adab19e4793a526472e6ada41d78d9`
- Worktree: pre-existing application, test, locale and document changes were preserved. The reentry
  implementation and tests were uncommitted during verification.
- Rails test databases: the run-owned fleet described by
  `tmp/acceptance-isolated-20261010p8b-primary.json`; no shared or production database was used.
- CI, Podman, production operations, external delivery, remote synchronization and destructive
  shared-database operations were not used.

## TDD and focused verification

The first Red run added the NanoID-21 expectations to the public reentry issuer and reported:

```text
7 runs, 52 assertions, 5 failures, 0 errors, 0 skips
```

After adding explicit transaction- and grant-collision cases, the Red run reported:

```text
9 runs, 58 assertions, 7 failures, 0 errors, 0 skips
```

The implementation then generated new Email reentry transaction and grant references with
`PublicId.generate`, retrying only exact named single-column `transaction_id` or `grant_jti` unique
B-tree collisions inside a savepoint and finite collision budget. The existing UUID browser session
reference and UUID OTP generation contracts were retained. The binding reader was updated to accept
a new NanoID-21 or existing UUID transaction reference while requiring a UUID generation.

The final focused issuer and binding collection passed:

```text
11 runs, 187 assertions, 0 failures, 0 errors, 0 skips
```

The broader reentry delivery/verification collection passed:

```text
22 runs, 313 assertions, 0 failures, 0 errors, 0 skips
```

The targeted style check was:

```text
bundle exec rubocop app/operations/email_reentry_otp_issuer.rb app/values/email_reentry_otp_delivery_binding_value.rb test/operations/email_reentry_otp_issuer_test.rb test/values/email_reentry_otp_delivery_binding_value_test.rb
```

After one correctable empty-line offense was fixed, four files were inspected with no offenses.

## Full gates

Gate 2 ran the Rails suite with four workers against the run-owned database scope. Result:

```text
15175 runs, 128413 assertions, 0 failures, 0 errors, 0 skips
```

The command was `bundle exec rails test` with the manifest-backed `RAILS_ENV=test`,
`POSTGRESQL_ISOLATED_TEST_RUN_ID=20261010p8b`,
`POSTGRESQL_ISOLATED_TEST_MANIFEST=tmp/acceptance-isolated-20261010p8b-primary.json`,
`POSTGRESQL_TEST_HOST=primary`, `POSTGRESQL_DATABASE=postgres`, `POSTGRESQL_TEST_PREPARE_DATABASES`
set to the manifest database names, and `PARALLEL_WORKERS=4`. The run emitted existing Flipper,
OmniAuth and local-environment diagnostics but no test failures or errors.

Vitest was executed with `bun run test` and passed `99 files` and `1140 tests`.

## Scope and limits

The reentry slice covers Email recovery for APP, COM and ORG and withdrawal for APP and COM; the
existing ORG withdrawal rejection remains unchanged. It does not classify or change other ceremony
transaction, grant, result or OTP-generation issuers. It also does not establish the complete
ceremony-purpose inventory, direct-SQL identifier immutability, D-11 committed-transaction
isolation, Avatar cutover, retained legacy identifier semantics, host Alloy recreation/runtime
checks, privacy-retention policy or independent acceptance. The application and test changes remain
in the shared worktree and are intentionally separate from the document-only commit that records
this evidence.
