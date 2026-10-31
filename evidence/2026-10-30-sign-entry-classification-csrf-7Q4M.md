# Sign entry classification and CSRF guards

- Commit: `336811e5072a93c0523e484f905082635b28f48f`; the worktree contained uncommitted changes affecting these checks.
- An excluded action override now requires a reason, and the classification guard checks that declaration. The standard CSRF source invariant no longer loads unrelated fixtures; its assertions remain unchanged.
- `bin/rails test test/unit/security/sign_entry_classification_guard_test.rb test/unit/security/standard_csrf_invariant_test.rb test/security/invariants/csrf_verification_strategy_invariant_test.rb`: 13 runs, 41 assertions, no failures or errors.
- The original full-fixture OTP controller suite remains unverified: an earlier fixture load failed on the `client_auth_admission_bindings.base_token_id` foreign key. No database data was removed to work around it.
