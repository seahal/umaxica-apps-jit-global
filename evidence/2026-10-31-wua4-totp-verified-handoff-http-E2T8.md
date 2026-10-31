# WU-A4 TOTP verification and finalization handoff

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`. The worktree contained uncommitted changes affecting implementation and tests.
- The existing Auth TOTP registration test errored in its obsolete admission-form setup before reaching its assertions (1 run, 3 assertions, 1 error). Its setup now follows the current HTTPS GET and confirmed Admission.
- The repaired case exercises candidate creation and a valid first TOTP through Auth HTTP. It verifies that no credential exists at that point, the parent is verified and no token freshness is issued; after the Auth handoff, a direct finalizer operation creates one credential with the intended title and first accepted window. It passed alone (1 run, 24 assertions).
- Three selected Auth controller cases and the enrollment query, issuer, verifier and finalizer files passed together (23 runs, 323 assertions, 0 failures, 0 errors, 0 skips).
- The test confirms the Admission binding directly, does not explicitly enable CSRF protection, and calls the Base finalizer operation directly rather than exercising the full Base browser POST. The finalizer's cross-database commit ordering and audit gaps are not resolved by this check.
