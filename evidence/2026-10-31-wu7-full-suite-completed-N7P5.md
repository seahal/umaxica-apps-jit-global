# WU-7 full-suite rerun after WU-A13 test correction

HEAD: `336811e5072a93c0523e484f905082635b28f48f`. Staged, unstaged and untracked changes affected
the run. No commit was made. Production and Neon were not targeted.

The preceding execution's process handle was missing and its log had no final test summary. The
current cgroup reported no OOM kills; this does not establish why that execution stopped.

Ran `PARALLEL_WORKERS=1 bin/rails test` with required local test configuration through a detached
launcher that retained start/end timestamps and exit status. Started 2026-10-31T02:39:39Z and
finished 2026-10-31T02:54:04Z. The suite completed in 856.131622 seconds with exit status 1:
16,325 runs, 157,805 assertions, 132 failures, 181 errors and no skips. Transient execution files
are under `/tmp/wu7-full-verification-gtQSgRbQ/`; raw logs are not copied into the repository.

Compared all 313 reported failure/error names with
`plans/2026-10-28-baseline-failing-tests.md`, removing terminal result punctuation and locations
and checking the full and method names. Found 22 distinct candidate names outside that baseline.
This is a name comparison, not a causal regression diagnosis. Candidates include the previously
observed signup, admission, social, passkey and database reconstruction cases. The removed obsolete
under-thirteen leap-day test is absent from failures.

The full run is complete, but the zero-baseline-external-failures condition and WU-7 closure are
not established. Actual preference purge remains separately unapproved and was not performed.
