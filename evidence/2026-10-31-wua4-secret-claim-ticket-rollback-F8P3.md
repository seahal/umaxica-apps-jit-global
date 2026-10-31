# Secret claim under Ticket rollback

HEAD: `336811e5072a93c0523e484f905082635b28f48f`. The worktree had extensive uncommitted changes, including Secret claim code and its concurrency test; this result applies to that worktree.

`PARALLEL_WORKERS=1 bin/rails test test/operations/client_secret_claim_concurrency_test.rb -n '/source_claim_survives_Ticket_rollback/'` passed: 1 run, 14 assertions. With no outer Zenith transaction, the Secret claim survives an outer Ticket rollback and subsequent existing reconciliation retires the halted flow without making the Secret reusable.

This does not contradict the separate outer Zenith rollback probe in `evidence/2026-10-31-wua4-secret-claim-outer-source-T6Y3.md`: an already-open Zenith transaction controls the source commit and can restore the Secret. No production fix was made in this check.
