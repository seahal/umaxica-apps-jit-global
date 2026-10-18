# Session/Token Hardening Baseline

## Status

Accepted (2026-06-02)

Partially implemented. The cookie hardening pieces are done in code — `SameSite=Strict` for auth
cookies, production HSTS `includeSubDomains`, the `__Host-`/`__Secure-` prefix policy, and unifying
the prefix gating on `Jit::SessionCookieConfig.force_secure?`. The remaining items
(credential-change revocation, idle/renewal timeouts, step-up re-issue decision, optional global
`no-store`, HSTS `preload`) are deferred while the codebase is under large-scale editing.
Implementation status and open gaps are tracked in
`plans/backlog/session-token-hardening-implementation.md`.

## Context

This is a new-build authentication surface. The accepted hardening targets for production session
and token handling are:

1. Auth cookies are host-bound and protected: `__Host-` + host-only + `Secure` + `HttpOnly` +
   `SameSite`.
2. The auth cookie carries an opaque token only; durable state lives in the DB token rows.
3. Refresh tokens are rotated, with reuse/replay detection and family revocation.
4. Login, step-up, privilege transition, and credential change re-issue session/token state.
5. Idle, absolute, and renewal timeouts are enforced server-side.
6. HSTS, CSP, `Cache-Control: no-store`, and reliable logout revocation are in place.
7. IP / User-Agent / device fingerprint are risk signals, not hard session binds.

`acme/www` is the session and token authority (`adr/acme-session-and-token-authority.md`). The
current implementation already satisfies several of these targets; this ADR fixes the decided
end-state and records where the build deliberately diverges from the raw checklist.

## Decision

### Cookie hardening (point 1)

Production auth cookies use `__Host-` prefix + host-only (no `Domain`) + `Secure` + `HttpOnly` +
**`SameSite=Strict`** + `Partitioned`. `SameSite=Strict` is implemented in
`Authentication::CookieService` (`auth_cookie_options` and `auth_cookie_deletion_options`); it
applies to the auth cookies (access / refresh / DBSC) in all environments.

Update: preference cookies (the preference JWT access/refresh and the JS consent buffer) were
subsequently moved to `SameSite=Strict` as well, since the preference JWT is re-read on the next
same-site request and does not need to survive a cross-site inbound navigation. The **Rails session
cookie remains `SameSite=Lax`** because it carries OIDC state/nonce/PKCE and email-link flow state
that must be present on a cross-site top-level inbound navigation (the IdP callback and emailed
links). Moving the session cookie to `Strict` is deferred and tracked as a backlog item; it requires
making those cross-site entry points session-independent (DB-backed OIDC state, self-contained
signed email-link tokens).

**Cookie name prefix policy.** Host-only cookies use the `__Host-` prefix; cookies that must be
readable across subdomains use `__Secure-` (which permits a `Domain` attribute, forbidden under
`__Host-`).

- `__Host-`: auth cookies (access / refresh / DBSC), the Rails session cookie (`__Host-session`),
  and the step-up verification cookie. All are host-only (no `Domain`), `Path=/`, and `Secure`.
- `__Secure-`: preference cookies (access / refresh / DBSC). They are intentionally scoped to the
  apex domain (`Core::CookieDomain.for`, via `Core::CookieOptions` default `domain: true`) for
  cross-subdomain reads, so they cannot use `__Host-`.

The prefix is gated on `Jit::SessionCookieConfig.force_secure?` (true in production or when
`FORCE_SECURE_COOKIES=1`), unifying auth, verification, and session cookies on one predicate.
Because `force_secure?` implies the `Secure` attribute, the prefix is never applied to a non-Secure
cookie.

Known tradeoff of `Strict`: an inbound top-level navigation from an external origin (an emailed link
or a link on another site) does not carry the auth cookie on the first request, so the first hit
renders unauthenticated until a same-site request runs. This is accepted for the security posture of
this build. OIDC/social callback flows must set the auth cookie on their own response and must not
depend on a pre-existing auth cookie being sent on the cross-site callback navigation.

### Token shape (point 2)

Refresh tokens are opaque: only a SHA3 digest is stored in the DB token rows (`ClientToken`,
`OperatorToken`, `VisitorToken` via `RefreshTokenable`); the raw token is never persisted.

The access token is a **JWT** and this is accepted as a deliberate architecture choice. The "opaque
access token only" target is explicitly **waived** for access tokens in this build. Refresh tokens
remain opaque and DB-backed.

### Rotation, reuse detection, family revoke (point 3)

Ratified as already implemented: one-time-consume rotation with a generation counter and
`rotated_at` marker, reuse/replay detection, and family-wide revocation on reuse, per
`adr/refresh-revoke-aal-downgrade-and-replay-hardening.md`.

### Re-issue on security events (point 4)

- Login: rotate the Rails session id (`reset_session`) and issue fresh access/refresh tokens.
  Already implemented.
- Step-up elevation: rotate the Rails session id and stamp step-up freshness on the token. Already
  implemented. Whether step-up elevation should additionally rotate the refresh-token family (not
  just the session id) is left as an implementation decision in the plan.
- Privilege transition: governed by `adr/session-reset-on-privilege-transition.md`. Coverage across
  all privilege-transition paths must be confirmed during implementation.
- Credential change (password / passkey / email): **must revoke other active sessions and
  refresh-token families.** This is a new requirement; it is not wired today and is the primary gap
  under this point.

### Timeouts (point 5)

- Absolute cap: retained. Refresh-token `discard_at` is set at issuance and preserved across
  rotation, so the family has an absolute lifetime that rotation does not extend.
- Idle timeout: implemented. Server-side idle expiry is driven by token activity timestamps and
  `SecurityTokenLifetimes`.
- Renewal: define a sliding-renewal-with-absolute-cap policy so rotation can extend an idle window
  only up to the absolute cap. Initial per-surface values are TBC and must align with
  `adr/token-lifetime-policy-by-surface.md` (indicative: `app` idle ~ a few hours, `org` idle ~30–60
  minutes, absolute cap = surface refresh TTL).

### Transport and logout (point 6)

- HSTS: production HSTS is stricter — `includeSubDomains` is **enabled** with a one-year max-age
  (`config/environments/production.rb`). `preload` stays **off**: preload-list registration is
  effectively irreversible and requires every subdomain to serve HTTPS, so it is deferred until a
  deliberate review of the asset and regional domains. The CDN may override or replace the header.
  Only production is changed.
- CSP: out of scope for this ADR; tracked on a separate track.
- `Cache-Control: no-store`: currently applied selectively to sensitive endpoints. Broadening it to
  authenticated HTML responses is an optional follow-up.
- Logout revocation: ratified as implemented — `Authentication::Logoutable` revokes the current
  session (or all sessions) and clears auth cookies with `reset_session`.

### IP / UA / device as risk signal (point 7)

Partially superseded by `adr/ip-anomaly-session-revocation.md`: User-Agent remains audit/risk
context only, while coarse IP-network changes may emit `ip_change_detected` and trigger
feature-flagged revocation under that ADR. Device binding remains cryptographic via DBSC and DPoP.

## Consequences

- `SameSite=Strict` changes the first-hit experience for external inbound links; OIDC/social
  callbacks must be verified to set cookies on their own responses.
- Credential-change revocation must be implemented to close the main re-issue gap.
- Idle timeout is implemented; future work may tune per-surface values and sliding-renewal behavior.
- Enabling HSTS `preload` is effectively irreversible for the affected domains; review before
  shipping.

## Related

- `adr/acme-session-and-token-authority.md`
- `adr/refresh-revoke-aal-downgrade-and-replay-hardening.md`
- `adr/session-reset-on-privilege-transition.md`
- `adr/step-up-authentication-redesign.md`
- `adr/device-session-dbsc-device-id-boundary.md`
- `adr/cookie-domain-scope-by-surface.md`
- `adr/token-lifetime-policy-by-surface.md`
- `plans/backlog/session-token-hardening-implementation.md`
