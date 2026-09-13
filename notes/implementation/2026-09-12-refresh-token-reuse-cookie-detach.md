# Refresh Token Reuse Cookie Detach

## Context

- Original plan/spec: user report that dashboard showed `auth.session_expired` and blocked
  sign-in after identity navigation.
- Related decisions/docs/plans: `adr/two-base-authentication-mode-boundaries.md`,
  `adr/refresh-revoke-aal-downgrade-and-replay-hardening.md`,
  `plans/backlog/db-backed-token-refresh-overlap-window.md`,
  `plans/backlog/refresh-token-reuse-overlap-and-stale-cookie-recovery.md`.
- Implementation date: 2026-09-12.

## Decisions Made During Implementation

- Decision: keep family revoke on reuse; add an English `Rails.logger.warn` plus a `message` field
  on the existing structured event so development logs are greppable without decoding JSON.
  - Why: reuse is rare and was easy to miss next to `auth.open.invalid_credentials`.
  - Alternatives considered: structured event only (already existed; not grepped).
  - Follow-up needed: overlap window in the backlog plan.

- Decision: on reuse, call `destroy_refresh_token_from_cookie` and `clear_auth_cookies!` from
  `handle_invalid_refresh_token_reason`, matching idle-timeout recovery.
  - Why: leftover access JWTs made `/oauth/authorize` 401 instead of starting the ceremony.
  - Alternatives considered: treat all invalid credentials as anonymous on `:open` (rejected by
    the two-base authentication mode ADR except for discarded/undecodable session artifacts on
    HTML).

- Decision: `:open` HTML + `token_session_not_found` / `token_decode_failed` detaches cookies and
  continues as anonymous. JSON stays 401.
  - Why: convert "invalid leftover session" into "no credentials" without changing binding or
    actor-mismatch failures.

## Deviations From Plan

- None. The overlap window is not in this change.

## Review Notes

- Tests run: refresh issuer reuse log; cookie clear after reuse; open HTML recovery; open JSON
  still 401.
- Tests not run: full suite.
- Documentation promotion needed: backlog plan is the fundamental proposal.
