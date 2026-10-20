# Publishing redundant (id, entry_id, locale) unique indexes removed

Date: 2026-10-20 HEAD: `87c15e1e5d89344db7dcaaa85ebb1f6972c0c829` Worktree: uncommitted changes from
the 2026-10-19 database_consistency work
(`evidence/2026-10-19-database-consistency-fk-index-K4Q7.md`) and unrelated pre-existing edits were
present.

## Change

`db/publishing_migrate/20261020090000_remove_redundant_publishing_locale_unique_indexes.rb` removes,
concurrently and reversibly, the 24 `uidx_<surface>_<audience>_{ver,rev}_id_entry_locale` indexes on
`publishing_*_entry_{versions,revisions}`.

- `(id, entry_id)` is already unique, so `(id, entry_id, locale)` enforces nothing more.
- `db/publishing_structure.sql` had no foreign key referencing the three-column set. No code in
  `app/`, `lib/` or `test/` refers to these index names.
- `(id, entry_id)` and `(id, locale)` stay. They are the referenced keys of the composite foreign
  keys that keep publications on the same entry and taxonomy assignments in the same locale.

## Results

- `bundle exec database_consistency`: 1802 → 1754 failures. Removed: all 24
  RedundantUniqueIndexChecker findings and the 24 UniqueIndexChecker findings on the removed
  indexes.
- Development DB: migrate, rollback and reapply passed.
- Schema dump: regenerated dump carried pre-existing CHECK re-deparse drift, so only the 24 index
  removals and the schema_migrations row were applied to the existing dump. Sorted index and foreign
  key statements matched the regenerated dump exactly.
- Test DB migrated (`schema_migrations` max `20261020090000`; only `uidx_help_org_ver_id_entry`
  remains among the `id_entry` indexes). Test files referencing `Publishing::`: 672 runs, 0
  failures, 0 errors.

## Not resolved

48 UniqueIndexChecker findings on `(id, entry_id)` and `(id, locale)` remain. A uniqueness validator
on a set containing the primary key checks nothing, and removing the indexes would drop the
composite foreign keys that depend on them.
