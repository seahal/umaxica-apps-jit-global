# WU-3 OP participant attempt

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`; the worktree included extensive uncommitted WU-3 changes from multiple contributors.
- Removing the com authority-stop configuration and dispatcher entry passed the four focused OP tests (25 runs, 188 assertions), but `bin/rails test` then reported 17,534 runs, 140 failures, 256 errors and 0 skips. Compared with the baseline inventory, 33 failing test names were new; many exercised remaining visitor lifecycle and revocation callers.
- The OP participant removal and its new test were reverted after that run. The related legacy callers and their tests remain to be retired coherently. The full-suite result above therefore does not describe the current worktree.
- No production database or external environment was modified. Test preparation and parallel worker databases were used.
