# Secret claim operation checks

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`. The worktree had extensive uncommitted changes affecting this result.
- Ran `PARALLEL_WORKERS=1 bin/rails test test/operations/client_secret_claim_committer_test.rb test/operations/client_secret_claim_concurrency_test.rb`: 10 runs, 113 assertions, no failures, errors or skips. The named cases cover independent competing admitted flows, source-claim survival of Ticket rollback, terminal reconciliation, and rejection of an already-authenticated OIDC transaction.
- Inspection of `ClientSecretClaimCommitter` shows the source credential claim occurs in the Zenith actor lock inside the independently held Ticket transaction, with the Ticket locator bound separately before that claim. This is partial XDB-18 evidence; the full signup and authentication path, all relevant fault points, and the existing nullable flow-principal design were not resolved by this run.
