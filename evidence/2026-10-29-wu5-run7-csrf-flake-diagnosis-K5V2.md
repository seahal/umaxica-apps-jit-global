# WU-5 convergence run7: remaining non-baseline failures and diagnosis

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`; full WU-3/4/5 uncommitted worktree.
- run7 (`bin/rails test`, migration-built test fleet, same command as run6): 16,071 runs,
  132,523 assertions, 127 failures, 137 errors, 0 skips. Baseline comparison: 225 identifiers,
  **1 non-baseline**:

    `AuthCeremonyAdmissionBoundaryTest#test_each_realm_verification_entry_admits_full_reauthentication_through_its_exact_persisted_purpose`
    — `NoMethodError: undefined method '[]' for nil` at ceremony_admission_boundary_test.rb:247
    (`meta[name=csrf-token]` absent while response status was 200).

- Reproduction split, run in isolation *and* repeated three times:
  `env POSTGRESQL_TEST_PREPARE_DATABASES=$NEWLIST PARALLEL_WORKERS=1 bin/rails test test/controllers/auth/ceremony_admission_boundary_test.rb`
  → 34 runs, 720 assertions, 0 failures, 0 errors (green seeds ×3).
- Cross-check with a wider slice under full parallelism:
  `bin/rails test test/controllers/auth/` → 891 runs, 7,573 assertions, 40 failures, 35 errors —
  every failing identifier in that slice is in the baseline plan file; the boundary test was green
  there. The failure therefore needs the *full suite's* worker ordering, not the auth directory.

## Working diagnosis (checked, not confirmed)

- In run6 the *same* class failed once and two other CSRF-boundary tests flaked
  (`Auth::App::SignUpCsrfFailureTest` expected 403 got 400; `PreferenceBrowserApiContractTest`
  cross-site PATCH expected 403 got 200). All three share one knob: tests mutate the global
  `ActionController::Base.allow_forgery_protection` / `Rails.configuration.action_controller...`
  without restoring in an `ensure` on every path (confirmed in
  `test/controllers/auth/app/sign_up_csrf_failure_test.rb:22` — sets config true, no restore;
  `with_forgery_protection` in preference_browser_api_contract_test.rb:355 restores), and
  `adr/csrf-protection-disabled-in-test-environment.md` makes the default off, so ordering decides
  whether a boundary test sees protection on or off. The two runs reproduced the flake twice
  (run6: 3 ids incl. this test; run7: this test alone), while isolated runs are green.
- Not yet performed: worker-order bisection; a run8 full-suite repeat is in progress at the time of
  this record. If run8 reproduces, the fix is a per-test ensure around the global toggle in the three
  named files (same pattern as the already-fixed pair at ceremony_admission_boundary_test.rb:11-13/97-99).

## Documentation follow-up completed in this cycle

- `docs/mermaid/idp-visitor-*.mmd` (39 files) moved to
  `docs/mermaid/archive/visitor-com-retired/`; `docs/mermaid/README.md` records the move and the
  RETIRED markers; `idp-state-machine-transition-inventory.md` stamps all 37 `idp-visitor-*` sections
  with the WU-5 retirement note.
