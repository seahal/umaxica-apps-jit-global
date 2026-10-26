# search / storage first migration and schema dump consistency

Revision: `bde2346c17e2aa911acc95de1f6035f80498f2da`, with extensive uncommitted work (including the uncommitted WU-10/WU-16 and COM
status migrations that the regenerated dumps reflect).

- Added `db/{searches,storages}_migrate/20261025200000_create_extensions.rb` (pgcrypto) and updated
  both READMEs, so these reserved databases always get `schema_migrations`.
- Fixed `down` in `db/{app_principals,com_principals,occurrences}_migrate/20240627130203_create_extensions.rb`
  (`disabl_extension` typo and inverted condition).
- `bin/rails db:migrate` (development and test): both new migrations ran.
  `bin/rails db:rollback:search db:rollback:storage` reverted them, `db:migrate` re-applied them.
- `bin/rails db:schema:dump`; search/storage dumps now contain pgcrypto and version 20261025200000.
- `SchemaDriftVerification.dump_matches?` over all 32 development configurations: 32 checked,
  0 mismatched.
- `bin/rails db:verify_no_schema_drift` still aborts only on its `git diff` step (26 uncommitted
  dump files); it passes only after the dumps are committed.
- Not performed: the zenith fresh migrate in a throwaway database (cluster-wide HMAC roles).
