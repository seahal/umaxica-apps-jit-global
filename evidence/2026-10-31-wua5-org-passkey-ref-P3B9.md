# ORG Passkey registration reference

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree contained uncommitted changes, including the implementation and tests.
- A real ORG discoverable WebAuthn registration reproduced `NoMethodError` when finalization called `public_id` on `OperatorPasskey`. Finalization and retry now use `external_id` for that surface.
- `PARALLEL_WORKERS=1 bin/rails test test/operations/passkey_mutation_authorization_test.rb test/operations/identity_passkey_registration_committers_test.rb test/operations/identity_passkey_registration_commit_order_test.rb test/integration/base_passkey_mutation_step_up_test.rb` passed: 23 runs, 233 assertions, no failures or errors.
- App registration still uses its existing public ID in the receipt. Cross-surface external-ID convergence and persisted receipt migration have not been completed.
