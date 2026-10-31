# WU-7 test database recovery snapshots

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`; the worktree had staged, unstaged and untracked changes.
- With the existing test database lock held, created PostgreSQL custom-format backups of the current `test_com_setting_db` and `test_chronicle_db` and table-scoped backups of `com_preference_chronicles` in each `test_chronicle_db_0` through `test_chronicle_db_15`. These capture the state after the incident, not the lost original Chronicle row.
- The 18 archives and their `SHA256SUMS` are in `/tmp/wu7-com-recovery-20261030-291189-onnric`, with directory mode 0700 and archive/manifest mode 0600. The manifest SHA-256 is `40b96615f620688803855aa29c1e18bb6733b3a01e9af3c1a88a7247baed7c60`. All 18 checksums verified and `pg_restore --list` and extraction to `/dev/null` succeeded for each archive.
- Dumps were taken separately, so they are not a cross-database atomic snapshot. No restore into a database was attempted, and extractability does not prove database restoration. `/tmp` is transient and these files may contain sensitive local data; external retention and access are not established.
- No database records were changed, restored or deleted. The lost original record remains unrecovered, the worker rows are not proven exact replacements, and WU-7 remains incomplete.
