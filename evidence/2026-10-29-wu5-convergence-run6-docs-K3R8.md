# WU-5 convergence run6 + documentation/state-machine follow-up

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`; full WU-3/4/5 uncommitted worktree.
- run6 (`bin/rails test`, rebuilt from-migration test fleet): 16,071 runs, 132,657 assertions,
  128 failures, 136 errors, 0 skips. Baseline comparison: 228 failing identifiers, **3 non-baseline**:

    - Auth::App::SignUpCsrfFailureTest#test_a_telephone_sign-up_submission_without_a_token_is_refused_and_recorded_as_a_rejected_step (403 → 400)
    - AuthCeremonyAdmissionBoundaryTest#test_each_realm_verification_entry_admits_full_reauthentication_through_its_exact_persisted_purpose (nil `[]` in test helper at ceremony_admission_boundary_test.rb:247)
    - PreferenceBrowserApiContractTest#test_a_cross-site_PATCH_without_a_valid_CSRF_token_is_forbidden_and_changes_nothing (403 → 200)

  All three pass outside the full parallel run:
  `env POSTGRESQL_TEST_PREPARE_DATABASES=$NEWLIST PARALLEL_WORKERS=1 bin/rails test test/controllers/auth/app/sign_up_csrf_failure_test.rb test/integration/preference_browser_api_contract_test.rb test/controllers/auth/ceremony_admission_boundary_test.rb`
  → 50 runs, 3,249 assertions, 0 failures, 0 errors. Run7 (full parallel rerun) was started to test
  whether the three are worker-order artifacts; its result is recorded in the WU-5 closure record.
- `bin/rails routes` after the removals: no visitor_* route outputs (grep 0) and only the retained
  anonymous com surfaces (Base/Warp com roots, revisions, health, robots/sitemap, CSP report, PWA,
  preference API/cookies/themes screens) appear under `*_com` names; no auth/visa/core com route
  emits any route line.
- `docs/mermaid/README.md` updated for WU-5: the corporate-credential-retirement note now records the
  completed realm removal (databases, shared tables, `ComRpRecord` model family) and the retention of
  the anonymous com Preference family until WU-7; the 25 visitor-realm inventory rows were re-marked
  `RETIRED (WU-5: tables and writers removed)` so no `idp-visitor-*` row can be read as a current
  model-level authority.
