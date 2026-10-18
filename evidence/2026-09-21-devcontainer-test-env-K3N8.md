# Dev Container test environment: `bin/rails test` blocked by a missing variable

Date: 2026-09-21

Environment construction, so this is recorded here rather than covered by a Minitest or
Vitest case (`.agents/harnesses/rules/project/no-environment-tests.mdc`).

## Observed failure

Inside `global-devcontainer-core`, `bin/rails test test/models` aborted before any test ran:

```text
Umaxica::TestEnvironment::ConfigurationError: POSTGRESQL_TEST_PREPARE_DATABASES is required
lib/umaxica/test_environment/database_safety.rb:220:in 'DatabaseSafety.required'
lib/umaxica/test_environment/database_safety.rb:100:in 'DatabaseSafety.prepare_database_names!'
lib/tasks/test_db_prepare.rake:16
```

`DatabaseSafety.required` uses `ENV.fetch` with no default, so an unset name aborts the run.
That is the intended guard: an implicit default could migrate a database the run never meant
to touch.

## Services and other variables were not the cause

- `getent hosts primary valkey-cache valkey-kvs` resolved to `10.89.0.3/.4/.5`.
- The catalog check reached PostgreSQL `17.7 (Debian 17.7-3.pgdg12+1)` at `10.89.0.3/32:5432`
  and listed all 38 `test_*` databases.
- `bun run test` passed unchanged in the same container: 85 files, 1065 tests.

Only the one variable was missing.

## Where the variable has to live

`lib/local_environment.rb` never overrides an already-exported name, and it loads exactly one
file: `UMAXICA_ENV_FILE`, else `.env`, else `.env.example`. `.env` exists in this worktree, so
`.env.devcontainer.example` is never read by Rails here. It reaches the process only because
`.devcontainer/compose.yaml` lists it under `env_file:`. `.env.local` is read by nothing.

Checked: `POSTGRESQL_HOST` does not appear in `.env`, yet the running process has
`POSTGRESQL_HOST=primary` -- confirming Compose's `env_file` as the delivery path.

So the setting was added to `.env.devcontainer.example` (tracked), where a rebuild carries it
into the container environment. Its value matches the `db:test:prepare` step in `config/ci.rb`:

```text
POSTGRESQL_TEST_PREPARE_DATABASES=test_primary_db,test_app_ticket_db,test_com_ticket_db,test_org_ticket_db
```

## Verification

With that value supplied to the current (pre-rebuild) process:

```text
POSTGRESQL_TEST_PREPARE_DATABASES=test_primary_db,test_app_ticket_db,test_com_ticket_db,test_org_ticket_db \
  PARALLEL_WORKERS=1 bin/rails test test/lib/local_environment_coverage_test.rb
```

Result: 4 runs, 12 assertions, 0 failures, 0 errors, 0 skips.

```text
POSTGRESQL_TEST_PREPARE_DATABASES=... PARALLEL_WORKERS=1 bin/rails test test/models/client_token_test.rb
```

Result: 42 runs, 134 assertions, 0 failures, 0 errors, 0 skips.

The same value was then written to the gitignored `.env`, which is the file `LocalEnvironment`
actually reads in this worktree, so the current container no longer needs the variable on the
command line. Re-run with the name explicitly removed from the process environment:

```text
env -u POSTGRESQL_TEST_PREPARE_DATABASES PARALLEL_WORKERS=1 bin/rails test test/models/client_token_test.rb
```

Result: 42 runs, 134 assertions, 0 failures, 0 errors, 0 skips.

Two copies now hold the value for two different delivery paths: `.env` serves the running
container through `LocalEnvironment`, and the tracked `.env.devcontainer.example` serves a
rebuilt container through Compose's `env_file`. A change to the test scope has to be made in
both, alongside `config/ci.rb`.

The post-rebuild path -- the variable arriving from Compose -- was not exercised in this
session; the container was not rebuilt.

## Unrelated observation, not addressed here

Every run emits `lib/local_environment.rb:11: warning: already initialized constant
LocalEnvironment::KEY`, so the file is loaded more than once (boot plus autoload). Harmless to
the run; outside this task's scope.
