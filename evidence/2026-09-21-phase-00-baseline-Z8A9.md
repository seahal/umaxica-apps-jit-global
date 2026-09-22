# Phase 00 implementation baseline

- Date: 2026-09-21 UTC
- HEAD: `ab4746f9d403021b3ea5fff53a0a6ae4b4e68ec9`
- Branch: `feature`
- Worktree: pre-existing staged/unstaged/untracked changes were present and preserved.
- Scope: baseline only; no application code, test, migration, schema, configuration, or external
  service was changed by this baseline run.
- GitHub/external writes: none.

## Environment preflight

The required environment file was selected explicitly:

```text
UMAXICA_ENV_FILE=/home/global/workspace/.env.devcontainer.example
POSTGRESQL_TEST_PREPARE_DATABASES=test_primary_db,test_app_ticket_db,test_com_ticket_db,test_org_ticket_db
```

`config/credentials/test.key` was present. Secret values were not printed.

The mandated preflight command completed successfully:

```text
bundle exec ruby -r ./lib/local_environment -e 'LocalEnvironment.load!; load "scripts/test-environment-check"'
```

PostgreSQL test target: PostgreSQL 17.7 on the isolated test service. Valkey `rate_limit` and
`auth_state` both responded to `PING` on the test Valkey service. No production or shared data
target was used.

## Focused baseline

```text
PARALLEL_WORKERS=1 bin/rails test test/controllers/auth/ceremony_admission_boundary_test.rb
```

Result: `8 runs, 43 assertions, 0 failures, 0 errors, 0 skips`.

## Full baseline

```text
bin/rails test
```

Result: `11491 runs, 72545 assertions, 8 failures, 0 errors, 5 skips`.

The eight failures were:

- `IdentitySessionRevocationTest#test_com_revoke_other_sessions_requires_a_fresh_step-up` —
  expected 401, received the Step-Up setup redirect (303).
- `Base::Org::Identity::Revocations::OthersControllerTest#test_destroy_requires_a_fresh_step-up` —
  expected 401, received the Step-Up setup redirect (303).
- `ArchitectureBaselineTest#test_baseline_does_not_list_resolved_files` —
  `app/controllers/palm/app/oidc/authorizations_controller.rb` remains in the explicit-method-
  visibility baseline although the file is deleted.
- `FqdnAvailabilityGateTest#test_the_gate_is_the_very_first_before_action_on_every_gated_controller` —
  `Auth::Org::Sign::OidcHandoffsController` has `authenticate_oidc_result_actor!` before the FQDN
  availability gate.
- `OidcRpBrowserFlowTest#test_acme_app_session-limit_limitation_revokes_one_session_and_resumes_authorization` —
  expected a redirect but received 410 for an expired/invalid sign-in limitation link.
- `Security::PublicEntrypointInventoryTest#test_public_application_routes_are_covered_by_the_documented_public_categories` —
  the six Auth OIDC handoff routes are not in the documented public-route categories.
- `OidcRpBrowserFlowTest#test_app_email_sign-in_session-limit_handoff_signs_in_Sign_and_leaves_capacity_for_RP_callback_session` —
  expected redirect to `sign/in/session`, received `sign/in/check`.
- `Auth::App::Sign::In::SessionsControllerTest#test_update_promotes_pending_email_OIDC_sign-in_cycle_and_signs_in_Sign_while_preserving_callback_capacity` —
  expected redirect to `sign/in/session`, received `sign/in/check`.

The suite also emitted expected provider-failure and CSRF diagnostic logs and reported five skips;
those are retained as baseline facts and are not treated as success.

## Baseline handling

These failures are not excuses to weaken assertions, add skips, or remove tests. Each will be
reproduced with its narrow test, classified against the current Frozen Plan and pre-existing diff,
and either fixed or recorded as an explicit independent blocker before the affected slice is
considered complete.
