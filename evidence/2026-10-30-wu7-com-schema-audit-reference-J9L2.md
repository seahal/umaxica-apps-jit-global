# WU-7 local com schema dependent records

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`; the worktree had uncommitted changes affecting this observation.
- A read-only Rails runner in test counted the existing com Preference child tables and looked up Chronicle subjects using the parent IDs without printing them. `test_com_setting_db` contained 2 consent children, 1 theme child and zero rows in the other com Preference child tables with a `preference_id`. `test_chronicle_db` contained 1 `com_preference_chronicles` record referring to one of the test parents.
- The schema execution ticket now records this cross-database audit reference and the need to preserve and restore its association. The check did not enumerate all possible audit or hold references. No records or schemas were changed, and no migration or recovery rehearsal was executed.
