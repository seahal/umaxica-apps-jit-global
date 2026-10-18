# Coverage Improvement — Batch 2

## Goal

Continue incremental coverage improvement toward 99% through daily safe batches.

## Result

Batch 2 added **13 new tests** covering **10 new lines** and **6 new branches**, raising coverage
from 90.71% to 90.73%.

## Changes Made

### Tests Added

#### 1. CspViolationReportIntake (5 new tests)

- `test_empty_array_and_non_hash_json_values_are_ignored` — covers L75 normalize_reports empty array
  case
- `test_legacy_report_with_non_hash_csp_report_is_ignored` — covers L91 legacy_report_body non-Hash
  fallback
- `test_invalid_uri_in_blocked_uri_falls_back_to_splitting_on_query_fragment` — covers L134
  sanitize_url URI::InvalidURIError rescue
- `test_invalid_uri_in_extension_detection_falls_back_to_scheme_prefix_check` — covers L159
  extension_url? URI::InvalidURIError rescue
- `test_missing_blocked_uri_defaults_aggregation_key_to_unknown` — covers aggregation_key nil
  coalescing

#### 2. SignUpCycleLocator (3 new tests)

- `test_raises_for_unsupported_surface` — covers L82 normalize_surface ArgumentError
- `test_raises_for_wrong_cycle_class_in_issue!` — covers L71 ensure_supported_cycle! ArgumentError
- `test_returns_nil_when_payload_is_missing_required_keys` — covers L34 KeyError rescue in current

#### 3. Actor::Configuration (5 new tests)

- `test_bracket_access_uses_fetch_to_access_values` — covers L61 the `[]` method delegation
- `test_respond_to_missing_returns_true_for_any_method` — covers L73
  Configuration#respond_to_missing?
- `test_hash_consistency_with_equality` — covers L83 hash method computation
- `test_null_value_responds_to_any_message` — covers L37 NullValue#respond_to_missing?
- `test_null_value_methods_return_sentinel_behavior` — covers NullValue sentinel predicates

## Test Files Created/Modified

- `test/services/csp_violation_report_intake_test.rb` — added 5 tests
- `test/services/sign_up_cycle_locator_test.rb` — new file, 3 tests
- `test/unit/actor/configuration_test.rb` — new file, 5 tests

## Key Insights

- CSP report handling has multiple URI parsing error paths that need explicit invalid-URI inputs to
  trigger rescue blocks
- SignUpCycleLocator's error paths (unsupported surface, unsupported cycle type, missing payload
  keys) are all reachable through input validation
- Actor::Configuration#hash and #respond_to_missing? are sentinel delegation methods rarely
  exercised in tests but important for Set/Hash compatibility and method_missing chains

## Coverage Metrics

- **Starting:** 90.71% (40501 / 44648 lines)
- **Ending:** 90.73% (40511 / 44648 lines)
- **Delta:** +10 lines (+0.02%)
- **Branches:** 67.52% → 67.57% (+6 branches)
- **Tests added:** 13
- **Assertions added:** 51

## Pre-existing Failures (9 total, baseline unchanged)

1. PageTitlePresenceTest — 32 acme views missing page_title declarations
2. StepUpAuthenticationTest — 2 tests expect 2XX but get 303 redirects
3. Sign::IdentityAuthoritySlice1ATest — 2 tests for controller hierarchy/redirect status
4. RailsWayHarnessInventoryTest — 2 controller concerns with callback side effects

## Next Batch Candidates

- app/services/sign_up_state_machine.rb (9 uncovered lines) — state machine branches
- app/services/org_operator_lifecycle_invitation_acceptance.rb (9 uncovered lines) — invitation flow
- app/services/sign_otp_ceremony.rb (10 uncovered lines) — OTP ceremony flow
- app/models/concerns/sign_up_flow_ticket.rb (8 uncovered lines) — flow ticket state
- app/models/concerns/passkey_ceremony_transactionable.rb (7 uncovered lines) — transactionable
  concern

## Notes

- Batch 2 focused on error paths and edge cases in validation/parsing services
- 0.02% improvement reflects law of diminishing returns — remaining uncovered lines cluster in
  higher-risk areas (auth flows, complex services, controller concerns)
- Target files with 5-10 uncovered lines and clear error paths for next batch
- Consider grouping related ceremony services (TOTP, Passkey, Email, Social) for systematic coverage
  of transactional concerns
