# WU-7 lifecycle job scheduling inventory

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`. The worktree contained staged, unstaged and untracked changes affecting the inspection.
- A read-only search found `PreferenceLifecycleJob` in the job implementation and tests, but not in `config/recurring.yml`. Development and production both schedule `RetentionPurgeJob`; neither schedules the com preference lifecycle job. `config/queue.yml` includes a retention worker in both environments.
- `PreferenceLifecycleJob` invokes the com purger when the existing retention suspension flag is disabled. Section 4.9 of `two.md` requires separate approval for actual purge, including measured counts and recovery. No recurring task was added or started, and no non-test purge or production/Neon operation was performed. Automatic lifecycle collection remains unconfigured.
