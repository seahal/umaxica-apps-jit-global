# E1 Replay Owner and Partial-Failure Tests Implementation Notes

## Context

- Original plan/spec: repository-root `refactor.md` Phase E1
- Related decisions/docs/plans: `misc.md` MISC-0007; bounded owner-binding slice already in coordinator/Lua
- Implementation date: 2026-09-17

## Decisions Made During Implementation

- Decision: add coordinator tests only; no production change.
  - Why: Ruby/Lua already bind ownership before replay revocation and require `:linked` before token success.
  - Alternatives considered: HTTP endpoint matrix across app/com/org; deferred until a dedicated request-level slice.
  - Follow-up needed: concurrent consume race, link timeout after Valkey mutation, HTTP response-loss recovery.

## Deviations From Plan

- Change: tests exercise `OidcTokenExchangeCoordinator` rather than a public token HTTP request.
  - Why: existing suite already proves this coordinator as the production grant owner.
  - Risk: a controller wrapper regression would not be caught by these cases.
  - Follow-up: add a Base token-endpoint request once E4 public-boundary work starts.

## Review Notes

- Tests run: isolated `test/services/oidc/token_exchange_service_test.rb` and `test/services/valkey/auth_state/authorization_code_store_test.rb` (86 runs, 357 assertions, 0 failures).
- Tests not run: full Rails suite, SimpleCov, `bin/ci`, physical DPoP/DBSC.
- Documentation promotion needed: none; E1 public HTTP matrix remains open.
