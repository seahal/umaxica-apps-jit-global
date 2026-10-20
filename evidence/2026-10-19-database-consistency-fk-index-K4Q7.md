# database_consistency foreign key and index fixes

Date: 2026-10-19 HEAD: `87c15e1e5d89344db7dcaaa85ebb1f6972c0c829` Worktree: many unrelated
uncommitted changes were already present (models, `config/database.yml`, `Gemfile`,
`.env.container.devcontainer`, and emptied `db/*structure.sql` files). The checks below ran against
that worktree plus the migrations and schema dumps added in this change.

## Scope

Resolved without configuration-file exclusions, as 37 migrations across 21 databases:

- 22 foreign keys added with `validate: false` plus a separate validation migration. They cover
  avatar bindings, `handle_assignments`, zenith account/bridge/lifecycle tables, and
  `*_tokens.oidc_connection_id`. Five columns whose inverse association declares
  `dependent: :nullify` use `ON DELETE SET NULL`; the rest use `RESTRICT`.
- 54 indexes added concurrently: four association columns in each of the 12 RP cells, plus
  `state_id` and `logout_flow_participant_id` in the three `op_base_*` databases.
- 88 indexes removed concurrently because a composite index covers them, reversibly.

Withdrawn during verification: `op_{org,com,app}_grants.*_token_id → *_tokens` foreign keys.
`test/models/rp_session_test.rb` asserts that a grant survives physical deletion of its token row,
so the missing foreign key is intended and needs a design decision.

## Results

- `bundle exec database_consistency`: 2017 → 1895 failures. Every ForeignKeyChecker,
  MissingIndexChecker, and RedundantIndexChecker target in scope is gone. Remaining items in those
  checkers are the deferred ones: 3 grant foreign keys, 3 `Core*Bridge` `has_one` unique indexes,
  and 24 `(id, locale)` composite-key targets.
- Rollback and reapply passed for the publishing, avatar, org_zenith, and rp_tech_org migrations.
- The test databases were built from empty databases using only migrations, so every new migration
  ran from scratch.
- Schema dumps: generated after loading the HEAD dumps and migrating. Only the hunks for the
  intended objects were applied to the HEAD dumps. A statement-level comparison found 0 unexpected
  statements and 0 mismatches against the generated dumps.
- `bin/rails db:verify_no_schema_drift` reports drift. The cause predates this change: HEAD dumps
  already differ from a migrations-only build, including untouched databases such as `app_setting`,
  `chronicle`, and `occurrence`. A comparison against migrations-only dumps found no remaining drift
  involving the objects in this change.
- `bin/rails test` (fresh test databases, `POSTGRESQL_TEST_PREPARE_DATABASES` overridden to the 32
  current writable test databases): 15867 runs, 2 failures, 18 errors. None involve this change:
  - 13 committed-concurrency Avatar tests fail with "committed tests require run-owned worker
    receipts".
  - 3 tests fail on a missing Inertia `clearHistory` key.
  - 3 runtime-role and authentication-mode inventory tests fail on the
    `inertia_rails/devtools/entries` route.
  - Before the grant foreign keys were withdrawn, 5 additional failures came from them.
- Baseline for the 20 failures: all 37 new migrations were set aside, the HEAD dumps restored, and
  the test databases rebuilt. The 9 files containing the 20 failures were then run: 89 runs, 2
  failures, 18 errors. The failing test names matched the full-suite run exactly, so these failures
  exist without this change. The migrations and dumps were then restored.
