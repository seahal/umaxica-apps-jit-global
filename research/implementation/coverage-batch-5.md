# Coverage Improvement — Batch 5

## Goal

Continue incremental coverage improvement toward 99% through daily safe batches.

## Result

Batch 5 added **6 new tests** covering **+8 lines (+0.02%)** and **+3 branches (+0.02%)**, raising
coverage from 90.79% to 90.81%.

### Targeted Files

| File                                             | Before           | After            | Delta    |
| ------------------------------------------------ | ---------------- | ---------------- | -------- |
| `app/models/concerns/token_status_management.rb` | 98.82% (84/85)   | 100% (85/85)     | +1 line  |
| `app/services/csp_violation_report_intake.rb`    | 98.92% (92/93)   | 100% (93/93)     | +1 line  |
| `app/services/chronicle_recorder.rb`             | 98.36% (60/61)   | 100% (61/61)     | +1 line  |
| `app/services/jump_rt_issuer.rb`                 | 98.61% (71/72)   | 100% (72/72)     | +1 line  |
| `app/services/sign_up_state_machine.rb`          | 93.38% (127/136) | 94.85% (129/136) | +2 lines |

## Changes Made

### Tests Added

#### TokenStatusManagement (1 new test)

- `test_token_status_model_raises_for_unknown_token_class` — `token_status_model` raises
  `ArgumentError` when model name doesn't match OperatorToken, ClientToken, or VisitorToken
  (line 118)

#### CspViolationReportIntake (3 new tests)

- `test_handles_non-hash_non-array_input_gracefully` — `normalize_reports` returns `[]` for JSON
  string input (line 75)
- `test_handles_numeric_json_input_gracefully` — `normalize_reports` returns `[]` for JSON number
  input (line 75)
- `test_handles_null_json_input_gracefully` — `normalize_reports` returns `[]` for JSON null input
  (line 75)

#### ChronicleRecorder (1 new test, replaced weaker old test)

- `test_sanitize_error_message_truncates_long_messages` — verifies error messages are truncated to
  `MAX_ERROR_MESSAGE_BYTES` bytes using `byteslice` (line 144). Replaced old test that used
  hardcoded 1024 instead of the constant and didn't verify exact truncation boundary.

#### JumpRtIssuer (1 new test)

- `test_returns_nil_for_url_with_invalid_percent_encoding` — passes URL with invalid `%gg` encoding
  to trigger `URI::InvalidURIError` rescue, returning `nil` (line 88)

#### SignUpStateMachine (2 new tests)

- `test_failed_helper_builds_failed_result` — tests the `failed` method builds a `SignUpResult` with
  `:failed` status, error message, and `cleanup_required?` (line 280)
- `test_checkpoint_version_matches_rescues_invalid_integer_format` — tests that
  `checkpoint_version_matches?` returns `false` when `checkpoint_version` payload is non-numeric,
  covering the `rescue ArgumentError, TypeError` path (line 268)

## Test Files Modified

- `test/models/concerns/token_status_management_test.rb` — 1 new test (total 22)
- `test/services/csp_violation_report_intake_test.rb` — 3 new tests (total 14)
- `test/services/chronicle_recorder_test.rb` — 1 new test, replaced 1 (total 22)
- `test/services/jump_rt/issuer_test.rb` — 1 new test (total 15)
- `test/services/sign_up/state_machine_test.rb` — 2 new tests (total 21)

## Coverage Metrics

- **Starting:** 90.79% (39856 / 43898 lines)
- **Ending:** 90.81% (39864 / 43898 lines)
- **Delta:** +8 lines (+0.02%)
- **Branches:** 67.54% → 67.56% (+3 branches, +0.02%)
- **Tests added:** 8 (total batch 1-5: 64 new tests)
- **Assertions added:** varies

## Failures

Pre-existing baseline (13 total: 10 failures + 3 errors — comparable to batch 4 baseline):

1. AcmeRouteContractTest — 2 failures (string vs symbol action comparison)
2. ReadOnlySurfacesTest — 2 errors (missing route slug param)
3. StepUpAuthenticationTest — 2 failures (303 redirect instead of 2XX)
4. PageTitlePresenceTest — 1 failure (32 views missing page_title)
5. RailsWayHarnessInventoryTest — 1 failure (2 concerns with callback side effects)
6. Sign::IdentityAuthoritySlice1ATest — 2 failures (redirect and controller hierarchy)
7. Palm::App::Api::V0::ProfilesControllerTest — 1 failure (401 Unauthorized)
8. Actor::ConfigurationTest — 1 failure (NullValue respond_to expectations)
9. TotpCeremonyTransactionPurgeJobTest — 1 error (NoMethodError: stub issue)

Batch 5 did not introduce any new failures.

## Observations

### Four Files Pushed to 100%

TokenStatusManagement, CspViolationReportIntake, ChronicleRecorder, and JumpRtIssuer all reached
100% coverage. These were files with exactly 1 uncovered line each — ideal candidates for simple
targeted test additions.

### SignUpStateMachine Remaining Gaps

7 lines remain uncovered in `sign_up_state_machine.rb`:

- **Line 54**: `evaluate_event` — else branch for non-persisted tickets or tickets without
  `with_cycle_lock` method
- **Line 91**: `ok(next_event: :submit_contact)` — the `:start` event case
- **Line 101**: `transition_to!("GUARDRAIL_PENDING", ...)` — the `:enter_guardrail` event
- **Line 139**: `SignUpResult.build(...)` — in `complete_social_callback` handoff path
- **Line 218**: `SignUpResult.build(status: :sign_in_handoff_stopped, ...)` — stopped case
- **Line 222**: `invalid("unknown sign-in handoff status")` — else case
- **Line 252**: `terminal?` fallback — when ticket doesn't respond to `sign_up_terminal?`

These require more complex integration-style setup or specific ticket states.

### Coverage Diminishing Returns

As coverage rises, each batch improves fewer lines. Batch 1-4 averaged ~5.75 lines per batch. Batch
5 gained 8 lines. This is still positive but the low-hanging 1-line files are nearly exhausted.

## Commands Run

```bash
bin/rails test test/models/concerns/token_status_management_test.rb
bin/rails test test/services/csp_violation_report_intake_test.rb
bin/rails test test/services/chronicle_recorder_test.rb
bin/rails test test/services/jump_rt/issuer_test.rb
bin/rails test test/services/sign_up/state_machine_test.rb
vp check --fix
bundle exec rubocop -a
COVERAGE=true bin/rails test test/
```

## Skipped Risky Areas

- `security_jwt_preference_token_codec.rb:211` — "OTHER" case fallback. No existing test file;
  creating one for a 1-line JWT security path carries unnecessary risk.
- `oidc_access_token_authenticator.rb:47` — administrative lock path. Security-sensitive.
- `identity_social_ceremony_final_committer.rb:66` — actor mismatch in ceremony flow.
- `single_use_token.rb:139` — DB role switching concern.
- `flow_sign_in.rb` — uncovered lines 111/178 require host class with DB table setup; deferred to a
  future batch.
- `oauth_callback_stateable.rb` — 6 uncovered lines, multi-DB concern requiring careful setup.

## Next Batch Candidates

### High Yield

1. **`sign_up_state_machine.rb`** (remaining 7 lines) — line 54 (non-persisted ticket), line 91
   (`:start` event), line 101 (`:enter_guardrail`), and lines 139/218/222/252 (handoff/terminal
   paths). Medium complexity but high-value for a nearly-100% file.

2. **`security_jwt_preference_token_codec.rb:211`** — 1 uncovered line. Create test file following
   `security_jwt_auth_access_token_codec_coverage_test.rb` pattern.

3. **`models/concerns/flow_sign_in.rb`** — lines 111, 178. Create test file using `FlowBaseTest`
   host-class pattern with `cycle_base_test_records` table.

### Medium Yield

4. **`models/concerns/oauth_callback_stateable.rb`** — 6 uncovered lines. Multi-DB concern. Needs
   host class with table and connection_owner setup.

5. **`services/sign_otp_ceremony.rb`** — 10 uncovered lines. From batch 4 candidates.

### Deferred

6. `policies/sign_up/base_policy.rb` — 7 uncovered lines. Requires restructuring or testing through
   RequirementPolicy to bypass mutable_ticket? gate.
7. Controllers — require route/fixture support, security-sensitive.
8. Auth/Token/OIDC flows — security-sensitive.
