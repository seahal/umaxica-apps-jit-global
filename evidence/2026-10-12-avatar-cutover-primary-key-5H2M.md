# Avatar cutover marker primary-key repair

- **Scope:** Promote the existing singleton marker index on `avatar_ownership_cutovers.id` to the
  required PostgreSQL primary-key constraint without changing marker values or ownership behavior.
- **Revision:** `a1ec83a7384a424c97671356268ec5c4ad8347d4` (working tree was dirty; unrelated
  changes were preserved).
- **Before:** `id bigint NOT NULL`, `cutover_at` and timestamps, singleton check constraint, and
  a unique B-tree index on `id`; no primary-key constraint.
- **After:** The same columns, check constraint, and singleton semantics, with the existing unique
  B-tree promoted to `avatar_ownership_cutovers_pkey`.

## Verification

- `ruby -c db/avatars_migrate/20261012130000_promote_avatar_ownership_cutover_key.rb`: passed.
- `bundle exec rubocop db/avatars_migrate/20261012130000_promote_avatar_ownership_cutover_key.rb`:
  passed with no offenses.
- `git diff --check`: passed.
- On the run-owned disposable Avatar database
  `codex_integrity_20261010p3d2_avatar`, `bundle exec rails db:migrate:avatar` applied the
  migration successfully.
- `bundle exec rails db:rollback:avatar STEP=1` removed the constraint and restored the named
  unique index; a subsequent `db:migrate:avatar` reapplied it successfully.
- `bundle exec rails db:schema:dump:avatar` produced the expected `avatar_ownership_cutovers_pkey`
  schema entry. The dump also contains pre-existing dirty working-tree changes; it was not used to
  overwrite or discard those changes.
- Focused verification passed: `12 runs, 93 assertions, 0 failures, 0 errors, 0 skips` across the
  cutover barrier, trigger inventory, and Avatar transition inventory tests.

No shared, production, or remote database was changed.
