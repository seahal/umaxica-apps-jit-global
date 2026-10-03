# Social Login Cooldown And One-Shot Completion

## Status

Accepted (2026-06-22)

> **Supersession (2026-10-02):** `adr/root-login-establishment-boundary.md` replaces the cooldown
> anchor and the bootstrap exemption below. The cooldown now reads `root_login_established_at`, the
> instant the previous root login committed, not a "freshly issued `ClientToken`"; and no caller,
> including sign-up completion and OIDC authorization resume, may skip the cooldown or the session
> limit. One-shot social ceremony results remain as decided here.

## Context

Google social sign-in can appear intermittent when a user repeats the flow shortly after a
successful login. Log review showed that the Google provider callback can succeed and still be
followed by an Acme-side `429 Too Many Requests` response.

The current social-login boundary is:

- Sign validates provider callback state and stores social ceremony evidence.
- Acme consumes the signed ceremony result and owns durable account/session decisions.
- `AuthenticationBase::LOGIN_COOLDOWN` is 30 seconds and is enforced before issuing another user
  session token unless the call is an explicitly approved bootstrap handoff.
- Social ceremony results and candidates are one-shot replay-protection artifacts.

## Decision

Keep the login cooldown as desired security behavior for social login.

A social login attempt that reaches Acme completion but targets a user with a freshly issued
`ClientToken` inside the cooldown window must be treated as a valid cooldown rejection, not as a
Google provider failure.

Do not bypass the cooldown for ordinary repeated Google or Apple social login completions. Use
`bootstrap_actor: true` only for narrow handoff cases that are explicitly part of the existing
bootstrap contract, such as sign-up completion or OIDC authorization resume. Do not broaden that
exception just because the provider callback succeeded.

Keep social ceremony results and candidates one-shot. If a browser retries the same
`social_ceremony_result` after Acme has consumed it, the retry must fail closed instead of creating
or reusing a session.

## Consequences

- Logs must classify successful provider callback plus Acme `429` as cooldown enforcement.
- Provider debugging should start before the ceremony evidence is stored; cooldown debugging starts
  after Acme begins session establishment.
- User-facing presentation may be improved later, but any copy or redirect change must preserve the
  cooldown and one-shot replay guarantees.
- Tests for future social-login changes should cover the distinction between provider callback
  success, cooldown rejection, and consumed-result retry.

## Related

- `adr/acme-session-and-token-authority.md`
- `adr/sign-credential-gateway-surface.md`
- `docs/security/social-callback-boundary.md`
- `docs/security/session-token-authority.md`
