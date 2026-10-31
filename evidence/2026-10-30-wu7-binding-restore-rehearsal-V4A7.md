# WU-7 binding column backup restore rehearsal

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`; staged, unstaged, and untracked changes were present.
- Under the test process lock, created local `test_wu7_binding_recovery_db` and restored the pre-migration custom-format dump identified in `plans/2026-10-30-wu7-binding-column-execution-ticket.md` using `pg_restore --no-owner --no-acl`. The combined command succeeded in approximately 0.12 seconds.
- A read-only query on the restored database found two cookie rows, zero non-null old browser-binding digests, zero new binding rows and one old digest index. Querying the old column succeeded. The recovery database was left in place; the original test database was not replaced.
- This did not verify application behavior against the restored database or restore the separate Chronicle database. It does not establish full WU-7 recovery or completion.
