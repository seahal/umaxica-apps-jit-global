# Credential-registration grant-reference slice

This record covers the P2 Email/Telephone credential-registration `grant_jti` slice only. It is an
execution record, not a permanent acceptance result and not an independent review.

## Execution identity

- Repository: `/home/global/workspace`
- Branch: `feature`
- Full HEAD at execution: `c8837d1aed01a5b6e1360f845d5f2be3622c4c5c`
- Worktree: pre-existing application, test, locale, and document changes were present and were
  preserved. The two issuer implementations and their tests were uncommitted during verification.
- Rails test databases: the run-owned fleet described by
  `tmp/acceptance-isolated-20261010p8b-primary.json`; no shared or production database was used.
- CI, Podman, production operations, external delivery, remote synchronization and destructive
  shared-database operations were not used.

## TDD and focused verification

The Red command selected the two public issuer tests with the run-owned Rails test environment:

```text
bundle exec rails test test/operations/email_credential_registration_otp_issuer_test.rb test/operations/telephone_credential_registration_otp_issuer_test.rb
```

The initial result was `20 runs, 191 assertions, 7 failures, 0 errors, 0 skips`. The failures
covered the former UUID grant format and the missing transaction/grant collision retry behavior.

After the smallest implementation change, the same focused collection passed:

```text
20 runs, 248 assertions, 0 failures, 0 errors, 0 skips
```

The broader issuer and binding collection passed:

```text
37 runs, 745 assertions, 0 failures, 0 errors, 0 skips
```

The targeted style check was:

```text
bundle exec rubocop app/operations/email_credential_registration_otp_issuer.rb app/operations/telephone_credential_registration_otp_issuer.rb test/operations/email_credential_registration_otp_issuer_test.rb test/operations/telephone_credential_registration_otp_issuer_test.rb
```

Result: four files inspected, no offenses detected.

## Full gates

Gate 2 ran the Rails suite with four workers against the run-owned database scope. Result:

```text
15173 runs, 128384 assertions, 0 failures, 0 errors, 0 skips
```

The command was `bundle exec rails test` with the manifest-backed `RAILS_ENV=test`,
`POSTGRESQL_ISOLATED_TEST_RUN_ID=20261010p8b`,
`POSTGRESQL_ISOLATED_TEST_MANIFEST=tmp/acceptance-isolated-20261010p8b-primary.json`,
`POSTGRESQL_TEST_HOST=primary`, `POSTGRESQL_DATABASE=postgres`, `POSTGRESQL_TEST_PREPARE_DATABASES`
set to the manifest database names, and `PARALLEL_WORKERS=4`. The run emitted existing Flipper and
OmniAuth diagnostic messages but no test failures or errors.

Vitest was executed with `bun run test` and passed `99 files` and `1140 tests`.

## Scope and limits

The implementation generates new credential-registration `grant_jti` values with `PublicId.generate`
(NanoID-21), keeps existing UUID-v4 values opaque/readable, and retries only an exact named
single-column `grant_jti` or `transaction_id` unique B-tree collision within a savepoint and finite
collision budget. Transaction, grant, generation and proof/session purposes remain separate.

This record does not establish completion of other grant/result issuers, the full ceremony-purpose
inventory, direct-SQL identifier immutability, D-11 committed-transaction isolation, P10b/P12b
Avatar cutover, retained legacy identifier semantics, host Alloy recreation/runtime checks,
privacy-retention policy or independent acceptance. The application and test changes remain in the
shared worktree and are intentionally separate from the document-only commit that records this
evidence.
