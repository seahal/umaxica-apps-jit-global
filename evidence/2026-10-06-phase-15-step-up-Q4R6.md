# Phase 15 step-up requirement and AAL retirement

- Commit: `bfe569a162078df62e8e3b3011367840780e3078`
- Worktree: dirty before and during verification; unrelated changes were preserved (`588` status entries at record time).
- Test databases: the verified manifest `tmp/auth-boundary-isolated-20261003auth6f3.json`, with `PARALLEL_WORKERS=1` and the explicit isolated-database environment.

## Verification

The Phase 15 contract group was run with:

```text
bin/rails test test/services/step_up_requirement_test.rb test/services/step_up/resolver_test.rb test/operations/base_step_up_admission_issuer_test.rb test/models/step_up_ceremony_transaction_transition_test.rb test/operations/identity_step_up_ceremony_freshness_committer_test.rb test/values/identity_step_up_ceremony_aal_test.rb test/services/identity/step_up_ceremony_contract_test.rb
```

Observed result: `124 runs, 870 assertions, 0 failures, 0 errors, 0 skips`.

The registration, cancellation, TOTP, passkey, operator, transaction, coordinator and token-authority group was also run. The final focused subsets were green, including `43 runs, 508 assertions, 0 failures, 0 errors, 0 skips` and the passkey registration file's `13 runs, 69 assertions, 0 failures, 0 errors, 0 skips`.

The three explicit step-up requirement migrations were applied successfully to the owned app, com and org Ticket databases in the manifest. They add explicit policy/evidence columns and retain AAL columns as deprecated labels. `write_status!` is private and remains the only status write point in `StepUpCeremonyTransactionable`.

Phase 15 is complete; the full suite and final verification remain later plan gates.
