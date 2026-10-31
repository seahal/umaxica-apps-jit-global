# ORG birthdate access under Normal and Standby

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree contained uncommitted changes, including the test and the application behavior being checked.
- The existing Normal cases ran before modification (2 runs, 10 assertions). They exercise an admitted and completed Step-Up and show the unset or stored birthdate.
- A new public HTTP test uses a Standby Operator token and RP grant. It receives the specific Step-Up-unavailable 403, does not expose the stored birthdate or create a Step-Up transaction, and retains the Standby context. The full file passed afterward: 3 runs, 17 assertions, no failures or errors.
- Scoped RuboCop and `git diff --check` passed. The test does not prove the real Standby Root issuance journey, other protected operations, or every AC-41 case.
