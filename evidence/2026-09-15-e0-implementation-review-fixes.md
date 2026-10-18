# E0 implementation review fixes

Date: 2026-09-15. Review of the uncommitted E0 change set described in `misc.md` (MISC-0011) and
`refactor.md`.

## Defects fixed

- `config/database.yml` called `ENV.fetch("POSTGRESQL_PORT")` in `test_default`, which is rendered
  in every environment. It is now required only when `Rails.env.test?`. Verified:
  `env -u POSTGRESQL_PORT RAILS_ENV=development bin/rails runner ...` booted and printed 38.
- `config/application.rb` ordered the safety initializer with
  `before: :active_record_initialize_database`, which matches no initializer
  (`active_record.initialize_database`), so no ordering was enforced. Corrected, and the guard now
  builds `ActiveRecord::DatabaseConfigurations` directly so it does not load `ActiveRecord::Base`.
- `DatabaseSafety` treated a missing configuration port as the expected port. It now rejects it.

## Retracted change

`db/structure.sql` had been reduced to a session-setting stub. It was first mistaken for a broken
dump and restored from HEAD; the full suite then failed `DatabaseReconstructionAuthorityTest`
because committed dumps are intentionally stubs. The stub was put back, so the uncommitted reduction
is correct.

## Verification

`scripts/test-isolated` against PostgreSQL `primary:5432` and Valkey `valkey:6379` DBs 3/4/5:
`bin/rails test test/config test/models/actor test/lib/umaxica test/services/oidc test/controllers/concerns/oidc`
— 323 runs, 1533 assertions, 0 failures, 0 errors, 0 skips. RuboCop on changed Ruby files: no
offenses.

Full suite (16 workers, seed 20144) with HEAD's `db/structure.sql`: 13,007 runs, 78,792 assertions,
1 failure (the dump-authority test above), 0 errors, 3 skips. After restoring the stub,
`test/tooling/database_reconstruction_authority_test.rb` was rerun; result below. Rerun: 5 runs, 72
assertions, 0 failures, 0 errors, 0 skips.

Final full suite on the final tree (16 workers, seed 18356): 13,007 runs, 78,795 assertions, 0
failures, 0 errors, 3 skips; wrapper exit 0.
