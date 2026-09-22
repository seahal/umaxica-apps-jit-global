# OIDC result readiness before one-shot consumption

- Date: 2026-09-22 UTC
- HEAD: `277673d13547d722fc88f830711eee69b923a7e8`
- Scope: local hardening of the Base Auth-result POST boundary.
- Worktree: existing changes were preserved. This slice changed the shared result-post concern,
  the three surface authorization controllers, and their public integration regression tests; no
  migration, schema, configuration, or external service was changed.
- External writes: none; no GitHub, AWS, Cloudflare, provider, production, shared database, email,
  or SMS service was contacted.

## Defect and contract

Before this slice, the endpoint validated the stored authorization request and then consumed the
one-shot Valkey result before `resume_authorization!` rejected a pending, expired, or otherwise
unready OIDC authorization transaction. That could discard a valid result without progressing the
transaction. The endpoint now checks transaction expiry, consumption, and authenticated state
before calling `BaseAuthAdmissionCoordinator.consume_result!`. Expiry is evaluated against the
transaction class's writer-database `clock_timestamp()` through `database_now`, and the surface
resume controllers use the same clock source as a second boundary because the transaction can
change after the pre-check.

The change is deliberately local. It does not claim atomicity across Valkey, the ticket database,
Browser Session creation, authorization-transaction consumption, authorization-code issuance, and
the HTTP response. Those cross-store failure and concurrency semantics remain the `CF-010` blocker.

## Tests

`test/controllers/base/oauth_authorization_surfaces_test.rb` now verifies through the public HTTP
contract that pending and expired com/org results are rejected without consuming the result. The
expired cases set the stored expiry before the real writer-database clock rather than relying on
Rails time travel. The test then consumes the result through the existing public store contract and
asserts success, proving that the result was still available exactly once after the refusal.

## Verification

- Ruby syntax for the four changed Ruby controllers and integration test: PASS.
- Scoped RuboCop for the five changed Ruby files: PASS; 5 files inspected, no offenses.
- `git diff --check`: PASS.
- Rails RED/GREEN execution: UNVERIFIED in this shell. The required preflight stopped before Rails
  boot because hostname `primary` could not be resolved; no fallback host or mock datastore was
  used.
