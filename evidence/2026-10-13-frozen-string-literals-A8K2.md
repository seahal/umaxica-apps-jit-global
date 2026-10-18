# Frozen String Literal Step 8 Evidence

## Revision and worktree

- Full commit: `45ed455caa35c0efc2139c1969f541b5b3fc2242` on branch `feature`.
- The worktree was already dirty before this step, including deferred Xper retirement work and
  Step 7 routing changes. This step added frozen-string directives to 83 migration files and
  `config.ru`, and changed RuboCop and local CI configuration. The existing Rails generator
  RuboCop-autocorrection hook was exercised; this step did not change that hook. The results below
  include those uncommitted changes.
- Frozen plan hashes remain unchanged: `one.md` `663bb1a858f537edde4da80e53631a73e08a8022c59123fb2df391601d4cbe4c`;
  `two.md` `7297a6e0eb52fc4df2768c926e084297e654f827c0acd83f0d462c6c8ae4086d`.
- Acting agent: Codex GPT-6. The reasoning-effort setting is not exposed in this session.

## Checks performed

- Before the edits, a tracked-file inventory found 6,753 owned Ruby files and 94 missing directives:
  83 migrations, 10 Ruby binstubs, and `config.ru`. The two shell scripts under `bin/` were excluded.
- `bundle exec rubocop --config .rubocop_frozen_string_literal.yml --only Style/FrozenStringLiteralComment -A db config.ru`
  exited 0 and corrected 84 files. The correction changed only the frozen-string directive in each.
- `bin/rubocop --only Style/FrozenStringLiteralComment --format simple .` exited 0: 5,309 files
  inspected, no offenses. `bin/rubocop config/ci.rb config/environments/development.rb` also exited
  0 with no offenses.
- Four temporary invalid samples were rejected: missing directive, `false`, directive below code,
  and an inline disable of the frozen-string cop. The last case was rejected by the targeted
  `Style/DisableCopsWithinSourceCodeDirective` check configured to disallow disabling that cop.
- Rails generated a temporary migration in `db/migrate` and one in the configured
  `db/app_principals_migrate` path. Both received the directive through the repository's existing
  post-generation RuboCop autocorrection hook. `bin/rails destroy` removed both generated files.
- `git diff --check` exited 0.

## Incomplete acceptance at the initial observation

- The full dedicated cop command inspected 6,754 files and reported 10 remaining offenses, all in
  Ruby binstubs: `bin/brakeman`, `bin/bundler-audit`, `bin/ci`, `bin/jobs`, `bin/kamal`, `bin/rails`,
  `bin/rake`, `bin/rubocop`, `bin/setup`, and `bin/thrust`. The `bin/` mount is read-only, so these
  files could not be updated. The `.github/` mount is also read-only, so the GitHub Actions lint job
  could not be wired to the new check. The local CI check is present but remains red until the
  binstubs are updated.
- The required all-migrations-from-scratch run was not attempted. Neither
  `POSTGRESQL_ISOLATED_TEST_RUN_ID` nor `POSTGRESQL_ISOLATED_TEST_MANIFEST` is set, the referenced
  `scripts/postgresql-rebuild-isolated-test-fleet` path is absent, and `pg_isready -h 127.0.0.1 -p
  5432` reported no response. No database connection, preparation, migration, Minitest or Vitest
  command ran.
- AT-039 / REQ-039 and Step 8 remain **BLOCKED / INCOMPLETE**. No step commit was made.

## Follow-up under the standard Rails test-database direction

- Follow-up HEAD: `40c22179243f1970a139c89642d98f132b8735ea` on `feature`. The worktree remained
  dirty with the in-progress Frozen string changes and earlier deferred work.
- The user directed the implementation to use standard Rails `development` and `test` database
  configurations, not an isolated fleet; the decision is recorded as CHG-003 in the local
  `three.md`.
- `RAILS_ENV=test bin/rails db:migrate:status` reported 20 `test_*` databases and 1,429 migrations
  all `up`. `RAILS_ENV=test bin/rails db:verify_no_schema_drift` passed for 20 schema dumps. The
  detailed record is `evidence/2026-10-13-test-database-check-T3V8.md`.
- The full dedicated RuboCop command was rerun at this HEAD. It inspected 6,754 files and still
  reports 10 missing directives, all in read-only `bin/` scripts: `bin/brakeman`,
  `bin/bundler-audit`, `bin/ci`, `bin/jobs`, `bin/kamal`, `bin/rails`, `bin/rake`, `bin/rubocop`,
  `bin/setup`, and `bin/thrust`. No inline suppression offense was found.
- The Rails test workflow and its read-only catalog preflight are documented in
  `evidence/2026-10-13-route-tests-standard-db-L6P2.md`. No database reset or from-scratch migration
  replay was run. A test-database reset still needs explicit risk and recovery-plan approval under
  `AGENTS.md`.
- `.github/` and `bin/` are mounted read-only, so the remaining source changes and GitHub Actions
  wiring cannot be completed in this worktree. Step 8 remains **BLOCKED / INCOMPLETE**.
