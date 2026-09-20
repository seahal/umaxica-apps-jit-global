# Minitest private-method test removal and dead-code cleanup

Date: 2026-09-19 21:35 – 2026-09-20 01:18 JST. Branch `feature`, base commit `b2decc4f1`.

## Commands

- Baseline and final: `COVERAGE=true bin/rails test test/ --verbose` (SimpleCov via `.simplecov`,
  parallel workers merged with `merge_subprocesses`).
- Private-call detection: a scratchpad-only runtime probe loaded through `RUBYOPT` that recorded
  every `send`/`__send__` from `test/` whose target was private or protected, cross-checked with a
  Prism static scan against runtime method visibility, plus manual review of visibility widening
  (`public :x`, `send(:public, ...)`), forwarding wrappers, and `instance_method(...).bind_call`.

## Results

| Metric | Baseline | Final |
| --- | --- | --- |
| Runs | 13375 | 11322 |
| Assertions | 81027 | 71975 |
| Failures / errors / skips | 12 / 7 / 4 | 12 / 7 / 3 |
| Line coverage | 98.62% (59473/60303) | 95.74% (57207/59747) |
| Branch coverage | 88.28% (8924/10108) | 74.20% (7389/9958) |
| Method coverage | 96.25% | 90.82% |
| Wall time | 444 s | 410 s |

The 19 failing/erroring tests are identical before and after (McpEndpoint, McpForgeryProtection,
ObservabilityGatewayContract, OidcAccessTokenAuthenticatorNoRpSessionLookup, RiRoutingContract).
No new failure was introduced. SimpleCov threshold processing is skipped by SimpleCov because of
those pre-existing failures; the line figure is nevertheless below the `.simplecov` minimum of 97.

The line-coverage drop is 2.88 percentage points, beyond the 1.0-point tolerance set for this task.
It comes from removing tests that reached production code only by calling private methods.

## Changes

- About 1,750 test blocks that invoked private methods directly were removed; 180 test files
  became empty and were deleted.
- About 135 production methods with no caller were deleted as dead code.
- New public-path tests: refresh binding (idle window, DPoP, DBSC, device session), preference
  refresh replay and DBSC binding, preference option-name resolution, org withdrawal gate,
  preference token rejected as an access token, canonical DBSC path under context params,
  preference reference-default recovery. Mutation checks confirmed that the refresh, withdrawal and
  DBSC-path tests fail when the guarded production branch is disabled.

## Defects observed, not fixed

- `AuthorizationAudit#build_log_data` calls `exception.policy.record`; `ActionPolicy::Unauthorized#policy`
  is a class, so every authorization-failure audit raised `NoMethodError` inside the rescue and no
  `AUTHORIZATION_FAILED` chronicle was written (11/11 occurrences in the test log).
- `SingleUseToken.create_rotated_record!` copies the unique `dbsc_session_id`, so rotating a
  DBSC-bound preference refresh token raises.
- `SocialCallbackGuard.verify_request_phase!` and the `AuthenticationBase.access_policy` DSL have
  no production call site.

## Follow-up: adversarial re-audit and recovery (2026-09-20 01:30 – 05:56 JST)

Final run `COVERAGE=true bin/rails test test/ --verbose` (05:48–05:55): 11345 runs, 72269
assertions, 12 failures / 7 errors / 3 skips (the same baseline set; none new), line 96.05%
(57242/59590), branch 75.22% (7456/9911), 425 s. The line target of 97.62% and the `.simplecov`
97% gate are not met.

Re-audit: 1956 removed test blocks were inventoried from `git diff HEAD` and classified by the
current coverage of the private methods each one called: 75 called only deleted dead code, 553
called methods whose bodies are fully covered by public tests, 1090 called methods that are still
partly uncovered, 238 called no detected private method (reviewed by hand; several were
security tests and were rebuilt through public paths).

Branch analysis: 1535 previously covered branches are no longer covered; at most 150 of them
disappeared with deleted dead code. The rest are decision, guard and raise arms that the removed
tests reached through harnesses; 1138 of them are in authentication, session, preference and
OIDC files.

Production fixes, each RED then GREEN through a public path:
- `AuthorizationAudit`: no AUTHORIZATION_FAILED chronicle was ever written (NoMethodError on
  `exception.policy.record`, then ReadOnlyError on GET). Fixed; guarded by
  `test/security/invariants/authorization_failure_audit_invariant_test.rb`.
- `SingleUseToken.create_rotated_record!`: DBSC-bound preference refresh rotation violated the
  unique `dbsc_session_id`. Fixed; guarded in `test/integration/preference_refresh_replay_test.rb`.

Test-only production code removed: private "test-facing delegators" in `PreferenceToken`.

Open questions recorded, code left unchanged: `SocialCallbackGuard.verify_request_phase!` and the
`access_policy` DSL have no call site; session-limit cancellation controllers and several leaf
controllers have no route; `SessionLimitPendingGuard` is included nowhere; the com step-up email
OTP flow is only exercised by tests that redefine controller methods (the public-path test loses
the OTP session between requests, cause not determined).
