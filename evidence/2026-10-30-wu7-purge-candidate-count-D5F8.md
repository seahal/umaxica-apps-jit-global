# WU-7 local test purge candidate count

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`. The worktree had staged, unstaged and untracked changes affecting the observation.
- A read-only `RAILS_ENV=test bin/rails runner` query against the com setting and Chronicle test databases used the com database clock at 2026-10-30T23:53:13.646502Z. It found two preference parents, none at or past last-issued expiry plus 30 days, and therefore no current purge candidate with or without a com Chronicle subject/actor reference.
- This is a point-in-time count and does not establish the absence of external holds. No purge, scheduling, migration, backup or restore was performed. The local-only proposed execution and recovery prerequisites are recorded in `plans/2026-10-30-wu7-preference-purge-execution-ticket.md`.
