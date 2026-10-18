# Admission and CSRF targeted regression

- Commit: `6fa6867d44b5499632079775cb0fb22cbfddd339`.
- Inherited and current uncommitted worktree changes affect this result.
- Owned disposable database fleet: `20261007fresh3`, manifest
  `tmp/auth-boundary-isolated-20261007fresh3.json`; no shared application.
- `pgrep -af '[r]ails test'` found no other run before execution.

Executed serially with seed 42:

```bash
bin/rails test +  test/controllers/auth/admission_csrf_transport_test.rb +  test/controllers/auth/step_up_admission_test.rb +  test/controllers/auth/ceremony_admission_boundary_test.rb +  test/services/base_auth_admission_coordinator_test.rb +  test/services/base_auth_admission_cancellation_test.rb +  test/services/auth_admission_binding_concurrency_test.rb +  test/models/auth_admission_binding_test.rb +  test/operations/auth_admission_binding_purger_test.rb +  test/controllers/base/oidc_result_browser_binding_test.rb +  test/services/identity/ceremony_result_numeric_date_test.rb +  test/services/valkey/auth_state/opaque_admission_store_test.rb +  test/security/invariants/csrf_verification_strategy_invariant_test.rb +  test/unit/security/standard_csrf_invariant_test.rb +  test/controllers/protocol_controller_csrf_boundary_test.rb +  --seed 42
```

Result: **157 runs, 2338 assertions, 0 failures, 0 errors, 0 skips**.

This selection covers the named browser-substitution, redemption rollback/restart, Ticket
concurrency, expiry, cleanup, OIDC result binding and forgery contracts present in these files.
It is not proof that every purpose and mutation is covered. No Phase-16 checkbox was closed
solely from a passing selection. The explicitly deferred OIDC cancellation transition remains
deferred, Social GET callbacks are unchanged, and real-browser SameSite/CSP behavior is NOT VERIFIED.
