# WU-7 preference credential recovery matrix

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`. The worktree contained uncommitted changes affecting the result.
- The com cases in the former all-surface refresh recovery matrix failed before the change: 5 runs, 4 failures and 1 error. They required com refresh and DBSC credentials and invoked a removed refresh-token generator.
- Restricted that refresh-specific matrix to app and org. The focused app/org recovery cases and existing com tests for ignoring legacy credentials, read-only GET/HEAD and invalid JWT writes passed together: 13 runs, 270 assertions, zero failures, errors or skips.
- The full suite was not re-run in this slice. No production or Neon database was targeted.
