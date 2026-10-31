# Auth admission surface dispatch

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`. Extensive uncommitted worktree changes affected these results.
- Removed deleted corporate Auth route branches from `AuthCeremonyAdmission`. The clean URL dispatch now handles app and org explicitly and raises for other surfaces instead of selecting org implicitly.
- With `POSTGRESQL_TEST_PREPARE_DATABASES` set to the existing `.env` value and `PARALLEL_WORKERS=1`, `bin/rails test test/controllers/auth/ceremony_admission_boundary_test.rb test/integration/sign_entry_exit_org_flow_test.rb test/integration/social_login_admission_test.rb` passed 48 runs and 979 assertions, with no failures, errors or skips. `bin/rails test test/integration/routes/com_social_boundary_test.rb test/security/invariants/controller_lifecycle_order_invariant_test.rb` passed 4 runs and 30 assertions, with no failures, errors or skips.
- Diagnostic execution of `test/integration/app_secret_signup_journey_test.rb:38` ran 24 cases and failed all 24: the Visa authorization GET returned HTTP 303 where the test expected a legacy confirmation form. A more descriptive assertion was added; the journeys are not yet repaired.
- The full suite was not rerun after this change. Test database preparation was used; no production persistence operation or external write was performed.
