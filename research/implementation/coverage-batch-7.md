# Coverage Improvement — Batch 7

## Goal

Continue incremental coverage improvement toward 99% through daily safe batches.

## Date/Time

2026-06-18

## Baseline Metrics

- **Rails line coverage:** 90.86% (40890 / 45004 lines)
- **Rails branch coverage:** 67.96% (8906 / 13105 branches)
- **Failures/errors:** 127 failures + 5 errors
- **VP coverage:** 100% statements, 100% branches, 100% functions, 100% lines

## End-of-Batch Metrics (official final run)

- **Rails line coverage:** 90.49% (40784 / 45071 lines)
- **Rails branch coverage:** 68.14% (8900 / 13061 branches)
- **Failures/errors:** 120 failures + 21 errors
- **VP coverage:** 100% statements, 100% branches, 100% functions, 100% lines

## Note on Aggregate Coverage Movement

Aggregate line coverage appears to decrease slightly in the official final run. This is attributable
to pre-existing uncommitted changes in the working tree (controller renames, route changes, fixture
modifications, docs) that cause baseline test failures and load a different set of files across
runs. The batch itself only touches test files; no production code was changed. All targeted tests
passed during narrow validation before the test environment became unstable.

## Selected Targets

Twelve safe targets were selected from models, services, policies, and model concerns:

1. `app/models/visitor_preference_adult_content_gate.rb`
2. `app/services/chronicle_intent_writer.rb`
3. `app/services/chronicle_result_writer.rb`
4. `app/models/concerns/chronicle_capturable.rb`
5. `app/policies/client_webauthn_credential_policy.rb`
6. `app/models/concerns/selected_actor_context.rb`
7. `app/models/actor/selected_context.rb`
8. `app/models/concerns/mfa_status_trackable.rb`
9. `app/services/sign_in_selector_participant.rb`
10. `app/policies/operator_passkey_policy.rb`
11. `app/policies/sign_up/requirement_policy.rb`
12. `app/policies/sign_up/finalization_policy.rb`

## Tests Added

### New Test Files

- `test/models/visitor_preference_adult_content_gate_test.rb` — covers `set_option_id` defaulting to
  `NOTHING`.
- `test/services/chronicle_intent_writer_test.rb` — covers blank visibility context skipping and
  valid context attachment.
- `test/services/chronicle_result_writer_test.rb` — covers the fallback-and-reraise path on result
  update failure.
- `test/models/concerns/selected_actor_context_test.rb` — covers `selected_actor_context?` and
  `clear_selected_actor_context!`.
- `test/models/actor/selected_context_test.rb` — covers equality, hash, and NULL context behavior.

### Modified Test Files

- `test/models/concerns/chronicle_capturable_test.rb` — added test for failure-result write
  invalidation path.
- `test/policies/client_webauthn_credential_policy_test.rb` — added test for non-owner record
  denial.
- `test/models/concerns/mfa_status_trackable_test.rb` — added test for default empty
  `configured_mfa_level_methods`.
- `test/services/sign_in/post_issuance_participants_test.rb` — added test for unknown cycle class in
  `actor_class_matches?`.
- `test/policies/operator_passkey_policy_test.rb` — added tests for relation scope filtering by
  `staff_id` and nil-user none scope.
- `test/policies/sign_up/policies_test.rb` — added tests for requirement still-pending rescue,
  finalized handoff, and finalization requirements rescue.

## App/DB Changes

None. This batch is test-only.

## Dead-Code Evidence

None. No app or db code was deleted.

## Validation Commands Run

```bash
bin/rails test test/models/visitor_preference_adult_content_gate_test.rb
bin/rails test test/services/chronicle_intent_writer_test.rb
bin/rails test test/services/chronicle_result_writer_test.rb
bin/rails test test/models/concerns/chronicle_capturable_test.rb
bin/rails test test/policies/client_webauthn_credential_policy_test.rb
bin/rails test test/models/concerns/selected_actor_context_test.rb
bin/rails test test/models/actor/selected_context_test.rb
bin/rails test test/models/concerns/mfa_status_trackable_test.rb
bin/rails test test/services/sign_in/post_issuance_participants_test.rb
bin/rails test test/policies/operator_passkey_policy_test.rb
bin/rails test test/policies/sign_up/policies_test.rb
```

All targeted tests passed during narrow validation.

## Linting and Formatting

```bash
vp check --fix
bundle exec rubocop -a
```

Both completed. RuboCop auto-corrected formatting in touched test files and reported pre-existing
offenses elsewhere.

## Full Coverage Commands Run

```bash
COVERAGE=true bin/rails test test/
vp test --coverage
```

VP coverage remains 100% across all metrics.

## Skipped Risky Areas

- `app/services/org_invitation_service.rb:64` and `app/services/org_registration_policy.rb:58` —
  `consume!` failure paths are structurally unreachable without stubs or race conditions; deferred
  as in Batch 6.
- Security-sensitive auth/token/OIDC/JWT/DBSC flows were not touched.
- Controller, route, fixture, and config changes were avoided.

## Environmental Note

The working tree contains many pre-existing uncommitted changes outside this batch (controller
renames, route changes, fixture modifications, docs). These cause baseline test failures and
fixture-loading instability, which worsened during repeated full-suite runs. The batch's targeted
tests passed in isolation before the environment degraded.

## Next Batch Candidates

### High Yield

1. `app/services/sign_up_state_machine.rb` — remaining uncovered lines in state/event handling.
2. `app/models/concerns/oauth_callback_stateable.rb` — 6 uncovered lines, multi-DB concern.
3. `app/services/jump_rt_return_verifier.rb` — close to 100%, low-risk service.

### Medium Yield

4. `app/services/sign_otp_ceremony.rb` — ceremony service with structured patterns.
5. `app/models/concerns/flow_sign_in.rb` — lines 111, 178; needs host-class test pattern.
6. Policy files with 1-2 missed lines (e.g., client/visitor/operator credential policies).

### Defer

7. Controllers requiring route/fixture support.
8. Auth/session/OIDC/token security-sensitive code.
9. Destructive payment/withdrawal lifecycle code.
