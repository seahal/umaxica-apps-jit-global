# Telephone signup finalization lock order

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`. The worktree contained extensive uncommitted changes affecting this result.
- The APP telephone signup finalizer now takes the Zenith Client, telephone and active Passkey locks before the OP Flow and telephone-ceremony locks. It rechecks the locked Flow's principal against the locked Client before source finalization. An outer OP transaction remains open around the source transaction so Zenith commits before the OP transaction; the Flow's existing transition writer remains in use.
- Before and after the implementation edit, the finalizer, source-audit and proof-retry test files passed 14 runs and 322 assertions. After adding an owner-mismatch check, the finalizer file passed two runs and 28 assertions: an altered Flow owner is rejected while the telephone remains unverified. RuboCop on both changed files reported no offenses; scoped `git diff --check` passed.
- These tests do not separately prove lock acquisition order with independent database connections or inject a failure at each commit boundary. XDB-16 and the registration-completion receipt dependency remain open.

## Superseding correction

The lock-order edit and its added owner-mismatch assertions were reverted in the same working session. Subsequent source inspection found `SignUpArtifactCleanup.cleanup_pending_for` claims the OP Flow with `FOR UPDATE SKIP LOCKED`, and `SignUpArtifactCleanup#call` holds that Flow lock while acquiring the Zenith Client lock. Keeping the finalizer-only reversal could create an opposite-order wait between cleanup and finalization. The prior passing counts above describe the temporary implementation, not the final worktree. The original finalizer order remains; coordinated cleanup, finalization and cancellation ordering and independent-connection testing remain unresolved.
- After the revert, ran `PARALLEL_WORKERS=1 bin/rails test test/operations/sign_app_up_telephone_registration_finalizer_test.rb test/services/sign_up_artifact_cleanup_test.rb`: eight runs, 51 assertions, no failures or errors. This does not exercise the cross-connection race.
