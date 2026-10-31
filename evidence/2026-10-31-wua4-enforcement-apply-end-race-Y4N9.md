# Enforcement apply versus Case end

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree contained extensive uncommitted changes, including the code exercised here.
- A temporary nontransactional probe paused the apply immediately before the actual `AdministrativeAccessLock.lock!` call, ended the active Case on another connection, then allowed the original lock operation to run. It observed the Case ended and its Client administratively locked: 1 run, 4 assertions, 0 failures, 0 errors. The OP stop-delivery boundary was stubbed; the principal update itself used the real service. Synthetic data and the temporary probe were removed.
- An earlier attempt stopped on an independently fixed strict-loading error and did not establish the race; this run did.
- No partial fix was applied. A fix must preserve Zenith-before-OP commit and recover post-commit failures, and must account for other blocking Cases and concurrent end. Live OP delivery and the full suite were not checked.
