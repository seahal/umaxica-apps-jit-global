# Full Rails suite comparison

HEAD: `336811e5072a93c0523e484f905082635b28f48f`. The worktree contained extensive uncommitted changes affecting this run.

`PARALLEL_WORKERS=1 bin/rails test` completed in 928.9 seconds with exit 1: 16,765 runs, 163,361 assertions, 103 failures, 104 errors and no skips. The local log is `/tmp/two-full-suite-20261031-current.log`.

Comparing the 207 distinct reported test names to `plans/2026-10-28-baseline-failing-tests.md`, by full name and by method name as in the previous comparison, yielded 15 names outside the baseline. They are recorded in `/tmp/two-full-suite-20261031-current-outside-baseline.txt`. The comparison is a name match rather than a diagnosis; the current result fails the zero-outside-baseline acceptance criterion.

The outside-baseline set includes three database reconstruction checks, three birthdate cases, one architecture-debt guard, two enforcement cases, four authority-stop count tests and two logout count tests. Subsequent fixes and focused verification must be recorded separately. No production or Neon database was targeted.
