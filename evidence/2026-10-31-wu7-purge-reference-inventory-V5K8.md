# WU-7 local com preference purge reference inventory

HEAD: `336811e5072a93c0523e484f905082635b28f48f`. Staged, unstaged and untracked work affected
the inspection. The database query was read-only and verified the `test_com_setting_db` target.

The PostgreSQL catalog returned 15 foreign-key source tables referencing `com_preferences`. Each
matched a declared `PreferenceLifecyclePurger` association. The separately declared Chronicle
association lives outside this setting database. The first runner attempt stopped on the project's
deprecated connection API; the corrected `lease_connection` query succeeded.

The purger checks com Chronicle subject and actor references, and the job observes the existing
retention suspension flag. This database catalog check does not discover cross-database references
without foreign keys or external holds, and no purge was performed. Production and Neon were not
targeted.
