# Refresh Token Reuse: Overlap Window And Stale Cookie Recovery

Incident report and improvement-plan seed:
`plans/backlog/2026-09-12-refresh-token-race-incident-and-improvement-plan.md`

## Status

Backlog. Immediate cookie-detach recovery is implemented; this note is the remaining
fundamental work.

## Context

Refresh tokens rotate with one-time consume semantics. A second presentation of the previous
verifier is treated as compromise (`refresh_token_reuse_detected`) and the whole token family is
revoked.

During development and ordinary browsing, two close HTML GETs (Inertia navigation, a second tab,
or a retry) often present the same refresh cookie because the first response has not yet replaced
it. That is classified as reuse. The family is revoked while a later `Set-Cookie` from the first
request can still leave a discarded access JWT in the browser. `/oauth/authorize` is `:open`, so
those leftover credentials are "invalid credentials" and used to return 401
`auth.session_expired` instead of starting sign-in. The user cannot continue.

## Immediate recovery (done)

On reuse detection:

- log an English warning that refresh token reuse was detected;
- revoke the family (existing issuer path);
- call `destroy_refresh_token_from_cookie` and `clear_auth_cookies!`;
- on `:open` HTML requests, if the presented credentials are a discarded or undecodable session
  (`token_session_not_found`, `token_decode_failed`), detach cookies and continue as anonymous so
  the authorization ceremony can start.

This does not weaken replay detection. It only removes browser artifacts after the family is
already dead.

## Fundamental work

Implement the DB-only overlap window described in
`plans/backlog/db-backed-token-refresh-overlap-window.md`:

- keep replay detection for true compromise (older generation, other device, revoked successor);
- accept a near-simultaneous retry of generation N when N+1 was just issued on the same family and
  device inside a short overlap window;
- use PostgreSQL row locks only (no Redis / Valkey for this path).

Until that ships, development will still see reuse events. The English warning is the signal to
look for overlapping HTML refreshes rather than a wall-clock session TTL.

## Non-goals

- Do not treat every invalid JWT as anonymous on JSON or API endpoints.
- Do not skip family revoke on confirmed replay outside the overlap window.
- Do not log refresh verifiers, cookies, or authorization headers.

## Tests required for the overlap window

Covered in `plans/backlog/db-backed-token-refresh-overlap-window.md`. Add an HTML
`/oauth/authorize` case: after overlap-or-reuse recovery, the ceremony starts instead of 401.
