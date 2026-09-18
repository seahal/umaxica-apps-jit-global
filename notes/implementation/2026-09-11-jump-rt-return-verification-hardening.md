# Jump RT Return Verification Hardening

## Context

- Original plan/spec: audit of Rails verification of Jump Gateway re-signed `rt` JWTs
- Related decisions/docs/plans: `adr/secure-jump-link-redirector.md`, `docs/operations/jump-rt-key-rotation.md`
- Implementation date: 2026-09-11

## Decisions Made During Implementation

- Decision: Cap Jump RT TTL at 30 seconds for both issuance and return verification.
  - Why: Jump return tokens are 30 seconds; Rails previously accepted up to 5 minutes.
  - Alternatives considered: Keep 5-minute issuer TTL and cap only the verifier. Rejected because outbound tokens would still be long-lived.
  - Follow-up needed: Confirm production `JUMP_RT_TTL_SECONDS` is unset or <= 30. Values above 30 now fail boot.

- Decision: Clock leeway is 5 seconds.
  - Why: 60 seconds was larger than the token lifetime.
  - Alternatives considered: Zero leeway. Rejected as too brittle across hosts.

- Decision: Remove stale JWKS fallback. Cache live JWKS for 30 seconds. Unknown-kid negative cache is 5 seconds.
  - Why: Fail closed when Jump JWKS is unreachable rather than honoring keys for up to an hour.
  - Alternatives considered: Keep stale cache only for previously seen kids. Rejected as still verifying after a rotation/revocation window.

- Decision: Production JWKS URL must equal `{origin}/.well-known/jwks.json`. Distinct JWKS hosts are rejected at boot.
  - Why: Prevent pointing verification at an attacker-controlled JWKS via env.
  - Alternatives considered: Hard-code `https://jump.umaxica.net/.well-known/jwks.json` only. Rejected so a staging origin can still derive its own well-known path.

- Decision: Classify `jwks_unavailable`, `unknown_kid`, `issuer_mismatch`, and `audience_mismatch` separately from `invalid_signature`.
  - Why: Operators need distinct structured reasons without logging the token.
  - Follow-up needed: None.

- Decision: Rejection logs use `request.path`, not `request.original_url`.
  - Why: Avoid putting `?rt=` into application logs even before redaction.

## Deviations From Plan

- Change: Non-production still allows `JUMP_GATEWAY_JWKS_URL` overrides so tests can assert HTTP JWKS rejection.
  - Why: Fetch-time HTTPS enforcement needs a non-derived URL in tests.
  - Risk: A mis-set local env could fetch a non-origin JWKS. Production still pins the path.
  - Follow-up: None.

## Review Notes

- Tests run: `bin/rails test` on Jump RT verifier, issuer, token lifetimes, Jump gateway config, and return verification integration tests (80 runs, passing).
- Tests not run: full `bin/rails test`, live fetch of `https://jump.umaxica.net/.well-known/jwks.json`.
- Documentation promotion needed: ADR and jump-rt key rotation runbook updated in this change.
