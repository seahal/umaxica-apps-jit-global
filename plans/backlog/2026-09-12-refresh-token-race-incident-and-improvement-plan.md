# Refresh Token Race: Incident Report And Improvement Plan Seed

Date: 2026-09-12

Status: Report. Use this as the source for a later improvement plan. The overlap window itself is
not implemented.

Related:

- `plans/backlog/db-backed-token-refresh-overlap-window.md` — fundamental overlap design (backlog
  since 2026-05-19)
- `plans/backlog/refresh-token-reuse-overlap-and-stale-cookie-recovery.md` — recovery already
  shipped vs remaining work
- `notes/implementation/2026-09-12-refresh-token-reuse-cookie-detach.md` — what landed on 2026-09-12
- `adr/refresh-revoke-aal-downgrade-and-replay-hardening.md` — reuse is a compromise event
- `adr/two-base-authentication-mode-boundaries.md` — `:open` must not ignore invalid credentials

Japanese user-facing copy quoted below is the production string that appeared in the incident, not
repository prose.

## 1. Incident

Observed on `www.umaxica.app` in development (`log/development.log`, 2026-09-12 around 09:14 UTC).

Sequence:

1. The signed-in user opened `/identity?ri=jp`. The access cookie was absent, so HTML transparent
   refresh succeeded (`auth.transparent_refresh.success`) and rotated the refresh token.
2. A second `/identity` HTML GET arrived about 200ms later with the previous refresh verifier.
3. The issuer classified that as reuse (`authentication.refresh.reuse_detected`), set
   `discarded_at` on the whole refresh family, and failed transparent refresh
   (`client.token.refresh.failed` / `reason: refresh_token_reuse_detected`).
4. `/identity` then treated the user as unauthenticated and redirected to `/oauth/authorize`.
5. `/oauth/authorize` is `AUTHENTICATION_MODE :open`. Leftover session credentials still looked
   like invalid credentials (`auth.open.invalid_credentials` / `reason: token_session_not_found`).
6. The endpoint returned HTTP 401 with `auth.session_expired`:

   > セッションの有効期限が切れました。もう一度サインインしてください。

7. The same 401 appeared on `/sign/out/new`. The user could not start sign-in and could not sign
   out.

This was not a wall-clock session TTL expiry. The access token was missing, two HTML GETs raced on
the same refresh cookie, and the leftover cookies after family revoke blocked the open ceremony.

## 2. Race definition

Refresh tokens are one-time. Generation N is consumed when it rotates to N+1. Presenting N again
is `refresh_token_reuse_detected` and revokes the family.

The race:

```
Request A  GET /identity   (no access cookie, refresh = generation N)
Request B  GET /identity   (still no access cookie, refresh = generation N)
           A rotates N → N+1, Set-Cookie of N+1
           B presents N after A consumed it → reuse → family discarded
Browser may apply A's Set-Cookie after B's delete, so a discarded access JWT remains.
```

Typical triggers:

- Inertia visit plus a second document GET
- two tabs
- retry or lost response
- identity hub then dashboard while the first refresh has not yet replaced the cookie

Legitimate concurrency is indistinguishable from theft under the current rule, because the rule
has no overlap window.

## 3. Problems when the race fires

1. **False compromise.** A same-browser retry is scored as token theft. The whole family is
   revoked, including the successor A just issued.
2. **Session death.** The user is signed out without choosing to sign out.
3. **Stale cookies.** Access, refresh, or device-session identifiers can remain after the family
   is dead, especially if A’s `Set-Cookie` arrives after B’s cookie delete.
4. **Sign-in lockout (the fatal symptom).** `:open` HTML (`/oauth/authorize`) treats those
   leftovers as invalid credentials and 401s instead of “no credentials, start the ceremony”.
   Sign-out can 401 the same way. The account is not deleted; the browser cannot enter the
   ceremony.
5. **Misleading copy.** `auth.session_expired` talks about expiry. Operators looking for TTL
   miss reuse. Before 2026-09-12 the structured event existed but was easy to miss.

Security that must stay: reuse from another device, generation N-2, or a revoked successor remains
compromise and must still revoke.

## 4. What shipped on 2026-09-12 (recovery, not the race)

- English warning: `Refresh token reuse detected; the refresh token family was revoked so the
  user can sign in again.` Grep `Refresh token reuse detected` in development logs.
- On reuse, `destroy_refresh_token_from_cookie` and `clear_auth_cookies!` run (same idea as idle
  timeout).
- `:open` HTML with `token_session_not_found` or `token_decode_failed` detaches cookies and
  continues as anonymous so `/oauth/authorize` can start. JSON still 401s.

This does not stop the race. Overlapping HTML refreshes can still revoke the family. The recovery
only tries to make sign-in possible afterward.

## 5. Proposed improvement plan (not implemented)

### Goal

Keep replay detection for real theft. Stop classifying a same-device, same-family retry inside a
short window as theft. After a real revoke, the browser must always be able to start sign-in.

### Workstream A — Overlap window (fundamental)

Implement `plans/backlog/db-backed-token-refresh-overlap-window.md`.

When A has just rotated N to N+1, B presenting N is a benign retry only if all of these hold:

- same family
- same device / binding
- N names N+1 as successor
- N was consumed inside the overlap window
- N+1 is still active

Otherwise revoke as today. PostgreSQL row locks only. No Redis/Valkey for this path. Apply to auth
and preference rotation.

### Workstream B — Stale credential detach (keep and test end to end)

Keep the 2026-09-12 cookie detach. Add an HTML `/oauth/authorize` integration case: after reuse or
overlap recovery, the ceremony starts (redirect or sign-in UI), never a stuck 401
`auth.session_expired`.

### Workstream C — Operator signal

Keep the English warning. Optionally add a metric for `refresh_token_reuse_detected` vs overlap
accepts so false compromise is visible.

### Explicitly out of scope

- Weakening reuse detection outside the window
- Logging refresh verifiers, cookies, or authorization headers
- Treating every bad JWT as anonymous on JSON APIs
- Client-only coordination as the security control

### Suggested first tests for the later plan

- Two parallel HTML GETs with generation N: one rotation, one overlap accept, family still live
- Generation N-2 still revokes even if N-1 is inside the window
- Different device / binding still revokes
- After real reuse, `/oauth/authorize` as HTML starts the ceremony
- Token-check JSON still 401s on invalid JWT
