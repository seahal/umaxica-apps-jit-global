# WU-4 session contract test progress

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`. Extensive uncommitted worktree changes, including the corporate authentication model removal and these test updates, affected the results.
- `PARALLEL_WORKERS=1 bin/rails test test/models/session_limit_resolution_transactionable_test.rb`: 17 runs, 104 assertions, no failures, errors, or skips. The cross-realm issuance rejection now uses the surviving operator realm against an app flow.
- `PARALLEL_WORKERS=1 bin/rails test test/models/session_limit_resolution_uniqueness_test.rb`: 4 runs, 48 assertions, no failures, errors, or skips.
- `PARALLEL_WORKERS=1 bin/rails test test/models/sign_flow_test.rb`: 43 runs, 331 assertions, no failures, errors, or skips.
- `PARALLEL_WORKERS=1 bin/rails test test/models/sign_in_token_uniqueness_test.rb`: 6 runs, 34 assertions, no failures, errors, or skips.
- `PARALLEL_WORKERS=1 bin/rails test test/models/step_up_nullable_evidence_contract_test.rb`: 4 runs, 20 assertions, no failures, errors, or skips.
- `bin/rails test` still stops while loading `test/models/step_up_transaction_reference_uniqueness_test.rb` because the deleted `Visitor` constant is referenced. The complete suite did not execute.
- Rails test database preparation was used; no production persistence operation or external write was performed.
