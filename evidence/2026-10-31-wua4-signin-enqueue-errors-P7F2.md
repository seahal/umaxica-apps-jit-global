# Initial APP Email sign-in delivery error classification

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree had uncommitted changes affecting the application and tests.
- A focused HTTP case confirmed that a refused email queue returns 503 with the new Auth challenge retained. A second case injected an `ArgumentError` at the queue boundary; before the change it was swallowed as a delivery failure (2 runs, 12 assertions, 1 failure). After narrowing the rescue, both cases passed (2 runs, 12 assertions).
- The APP Email sign-in and web resend controller files passed together: 68 runs, 671 assertions, no failures or errors. Scoped RuboCop and `git diff --check` passed.
- The queue refusal was injected, not an actual outage. Connection failure classes in the initial path and other queue-adapter-specific exceptions were not separately exercised. The previously recorded Source cooldown enumeration discrepancy remains unresolved.
