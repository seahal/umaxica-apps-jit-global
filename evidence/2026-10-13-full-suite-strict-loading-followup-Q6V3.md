# Full-suite follow-up under strict-loading test configuration

Recorded 2026-10-13 against full commit `aa92265b7e63bf874fddd0aa8f278d5ed19de6b5`, branch
`feature`. The worktree remained extensively dirty. The actor was a Codex agent; the execution
runtime did not expose its exact model or reasoning-effort label.

The test environment already had `strict_loading_by_default = true`,
`strict_loading_mode = :all`, and `action_on_strict_loading_violation = :raise`. The earlier
Step 20 probes and first full diagnostic are recorded in
`evidence/2026-10-13-strict-loading-diagnostic-W8K3.md`. This later full run followed the addition
of the 12-client Browser RP completion matrix. It is an additional run under the same strict
configuration, not a clean baseline under `:n_plus_one_only`.

The full Rails command was:

```sh
env -u POSTGRESQL_ISOLATED_TEST_RUN_ID RAILS_ENV=test PARALLEL_WORKERS=1 bin/rails test
```

Rails printed the ordinary `test_*` database manifest and finished all selected tests: **15,239
runs, 104,896 assertions, 89 failures, 2,322 errors, 0 skips**. It returned exit status 1. The
current `log/test.log` contained 765 matching lines for `ActiveRecord::StrictLoadingViolationError`;
that is a log-line count, not a count of distinct tests or error cases. Examples included unloaded
preference child associations, token-to-device-session associations, telephone-to-owner links,
authentication-admission bindings, Avatar lifecycle state, publishing taxonomy assignments, and
enforcement effects. Representative locations from the Minitest output were:

- `PreferenceInertiaPageContractTest#test_base_app_answers_an_Inertia_update_with_a_see-other_back_to_the_screen`:
  `app/controllers/concerns/preference_core.rb:259`.
- `TelephoneSignupSourceAuditTest#test_telephone_signup_rejects_invalid_audit_attribution_and_rolls_back_Source_facts_with_its_intent`:
  `app/models/client_telephone.rb:129`.
- `Auth::Com::Verification::PasskeysControllerTest#test_a_real_assertion_records_admitted_evidence_without_granting_Base_freshness_or_Auth_root_cookies`:
  `app/controllers/auth/com/verification/passkeys_controller.rb:25`.
- `ArchitectureBaselineTest#test_no_file_exceeds_its_recorded_architecture_debt` and
  `#test_baseline_does_not_list_resolved_files`: `test/tooling/architecture_baseline_test.rb:26`
  and `:48`.
- `Base::App::IdentityAuthoritySlice1ATest#test_base_sign_out_create_is_session_mutation_and_completes_on_the_base_surface`:
  `test/controllers/base/app/identity_authority_slice_1a_test.rb:62` expected the old completion
  destination `/sign/out?ri=jp`; the runtime returned `/sign/out/completion?ri=jp`.
- `Auth::Org::Sign::Up::InvitationsControllerTest#test_create_accepts_invitation_and_redirects_to_sign_in`:
  `test/controllers/auth/org/up/invitations_controller_test.rb:45` expected a redirect but received
  422.
- `OidcRefreshTokenCoalescingConcurrencyTest#test_barrier-driven_simultaneous_presentation_rotates_once_and_redelivers_the_same_response`:
  `RpSession::IssuanceRejected` at `test/services/oidc_refresh_token_coalescing_test.rb:674`.
- `TotpWindowConsumerConcurrencyTest#test_a_correct_code_cannot_revive_a_credential_revoked_before_its_locked_verification`:
  foreign-key violation at `test/consumers/totp_window_consumer_concurrency_test.rb:32`.

These are representative locations, not a complete per-test failure catalog. The full output also
contained credential-method expectation failures and other non-strict-loading failures; no
exhaustive categorization is claimed.

The prescribed JavaScript command was:

```sh
bun run test
```

It passed: **100 test files, 1,156 tests**.

No isolated fleet, database reset, migration, backfill or cutover ran. The Rails suite used only
the ordinary `test` databases, with `POSTGRESQL_ISOLATED_TEST_RUN_ID` unset. The diagnostic does
not pass Step 20, and this strict-mode execution cannot establish the planned Step 19 baseline.
The test environment and application associations were not changed after this diagnostic. The
frozen plan hashes still match `three.md`; no commit was made for incomplete steps.
