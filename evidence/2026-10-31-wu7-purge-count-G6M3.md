# WU-7 local test preference purge candidate measurement

HEAD: `336811e5072a93c0523e484f905082635b28f48f`. The worktree had staged, unstaged and untracked
changes. The read-only Rails runner verified `RAILS_ENV=test` and targeted local
`test_com_setting_db` and `test_chronicle_db` on the configured test database service.

At the com database time 2026-10-31T00:44:13.835445Z, there were two preference parents, zero
whose latest issuance expiry plus the 30-day grace period had elapsed, and therefore zero
subject-referenced, actor-referenced or unreferenced candidates. The measurement is a snapshot,
not a reservation; unknown external holds and future candidates have not been ruled out.

No job, purge, backup or restore was run in this observation. The separate backup and restoration
rehearsal and explicit approval described by the execution ticket remain outstanding. Production
and Neon were not targeted.
