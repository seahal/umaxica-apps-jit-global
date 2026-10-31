# WU-7 local test purge recovery rehearsal

HEAD: `336811e5072a93c0523e484f905082635b28f48f`. Staged, unstaged and untracked changes affected
the work. All operations targeted the local test PostgreSQL service `primary`; no production or
Neon database was targeted.

- `pg_dump --format=custom --no-owner --no-acl` produced separate archives of
  `test_com_setting_db` and `test_chronicle_db` under
  `/tmp/wu7-purge-recovery-20261031-Zli41Pt7/`. SHA-256: setting
  `cf39cda19ed77f1e2f82c0fdf2135574df3bbf04c40d9d8288a905166f698fb4`, Chronicle
  `a3babff8d15096da7c4cdc7770925675ec901b44beee4dc3d1fbf9bbaae06719`. `pg_restore --list`
  succeeded on both archives.
- Created separate scratch databases `test_wu7_restore_setting_Zli41Pt7` and
  `test_wu7_restore_chronicle_Zli41Pt7`; `pg_restore --exit-on-error --no-owner --no-acl`
  completed on both. The source and restored parent, cookie, binding, receipt, Web Push and com
  preference Chronicle tables had matching row counts and per-table content fingerprints.
  Observed counts were respectively 2, 2, 0, 0, 0 and 1. The scratch databases and archives were
  retained.
- No Ruby/Rails process was observed locally immediately before the snapshots, but complete writer
  quiescence was not established. The independent database snapshots are not atomic, and this
  rehearsal does not verify all external holds or all tables. No purge or replacement of either
  source database was performed. Remeasure and establish quiescence before any approved operation.
