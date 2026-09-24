# CF-011 pre-deployment acceptance recheck

- Date: 2026-09-23
- Repository: `seahal/umaxica-apps-jit-global`
- HEAD: `91d71c6f61d60c13be350bff3b723e05d09adf37`
- Worktree: pre-existing staged, unstaged, and untracked changes were preserved. No reset,
  cleanup, commit, push, GitHub write, provider access, or shared-data operation was performed.

## Finding and local correction

The CF-011 DB-backed regression set passed with one worker, but the parallel full suite still
reported seven errors for missing visitor fixed-reference rows. The base test database contained
the rows after the normal seed command, while stale worker clones did not. The failure was caused
by two local test-environment defects:

- `db/seeds.rb` did not replay `VisitorSecretCredentialKind`, `VisitorSecretCredentialStatus`, or
  `VisitorPasskeyStatus` fixed rows after a schema-only load.
- `ParallelTestDatabaseCloner` fingerprinted schema and migration sources but not `db/seeds.rb`,
  so an existing worker clone could be reused after a seed contract changed.

The seed allowlist now includes those existing visitor reference models. The parallel clone
fingerprint now includes the seed file contents, so worker clones are rebuilt when the seed
contract changes. No new status, schema, compatibility path, or provider behavior was introduced.

## Environment verification

The required test environment was selected without printing values:

```text
UMAXICA_ENV_FILE=/home/global/workspace/.env.devcontainer.example
POSTGRESQL_TEST_PREPARE_DATABASES=test_primary_db,test_app_ticket_db,test_com_ticket_db,test_org_ticket_db
```

`config/credentials/test.key` was present and its contents were not read. The required preflight
passed against the local Compose services:

```text
PostgreSQL: 10.89.0.3/32:5432, PostgreSQL 17.7
Valkey rate_limit: valkey-kvs:6379, db=4, PONG, Valkey 7.2.4
Valkey auth_state: valkey-kvs:6379, db=6, PONG, Valkey 7.2.4
```

All required PostgreSQL/Valkey variable names were present after loading; values were not printed.

## Verification

Focused acceptance was run before the full suite:

```text
bin/rails test <parallel-cloner, visitor-reference, and CF-011 contract set>
77 runs, 367 assertions, 0 failures, 0 errors, 0 skips
```

The full Rails suite was then run with the configured Compose-backed PostgreSQL and Valkey
services:

```text
bin/rails test
11,579 runs, 73,647 assertions, 0 failures, 0 errors, 8 skips
```

The eight skips were existing suite skips; none was added for this change. Targeted syntax,
RuboCop, and `git diff --check` verification also passed:

```text
ruby -c test/support/parallel_test_database_cloner.rb  # Syntax OK
ruby -c db/seeds.rb                                    # Syntax OK
bin/rubocop test/support/parallel_test_database_cloner.rb db/seeds.rb
2 files inspected, no offenses detected
git diff --check                                      # passed
```

The fixed-reference counts in the test writer database were present for all three visitor tables.
The full parallel suite additionally proves that newly rebuilt worker clones receive those rows;
the former seven missing-reference errors did not recur.

## Decision

`CF-011: CLOSED — PRE-DEPLOYMENT ACCEPTANCE SATISFIED`.

This closes only the repository/provider-neutral acceptance scope: state transitions, authenticated
receipt binding, idempotency, retry/permanent-failure behavior, manual recovery, and the required
DB-backed regression suite are locally verified. Provider credentials, provider authentication,
provider-specific receipt protocol, production worker topology, and production/provider end-to-end
delivery remain mandatory later deployment/provider gates and are not claimed here.
