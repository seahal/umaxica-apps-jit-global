# OIDC Session Model Note

This note records the current direction for OIDC session liveness and access validation.

## Boundary

- Acme is the only Identity Provider and Authorization Server.
- Sign is a special relying party.
- Sign may verify whether the Acme authority session is still live before rendering sensitive pages.
- Sign must not become an IdP, session authority, or token authority.

## Direction

- Use OpenID Connect for authentication.
- Use Authorization Code Flow with PKCE.
- Prefer relying-party session cookies over browser-held auth tokens.
- Keep browser-visible state minimal.
- Treat session liveness assurance as distinct from step-up authentication.

## Sign Session Liveness Assurance

The preferred mechanism is OIDC `prompt=none` against Acme `/authorize`.

Target flow:

1. A sensitive Sign page calls `sign_require_live_session!`.
2. If the local Sign RP session is missing, fall back to the existing login flow.
3. If the local Sign RP session exists but liveness must be checked, redirect to Acme `/authorize`
   with `prompt=none`.
4. Acme returns success if the Acme authority session is still live.
5. Acme returns `login_required` if the user is no longer logged in at Acme.
6. The Sign callback handles the result and returns to the original URL on success.

Required OIDC parameters include at least:

- `response_type=code`
- `client_id`
- `redirect_uri`
- `scope=openid`
- `state`
- `nonce`
- `prompt=none`

## Failure Handling

- `login_required`: fail closed, purge the local Sign RP session, and redirect to the login/start
  flow.
- `temporarily_unavailable`, timeout, network error, or Acme 5xx: fail closed, do not render the
  sensitive page, do not automatically purge the local Sign RP session, and show or redirect to a
  recoverable authentication-check failure state.
- Do not silently allow access under timeout grace.

## Naming

Use Sign-scoped helper names.

Preferred examples:

- `sign_require_live_session!`
- `sign_live_session?`
- `sign_start_silent_session_check!`
- `sign_handle_silent_session_check_callback!`
- `sign_clear_session_due_to_authority_logout!`

Avoid `idp_*` helper names, including:

- `require_fresh_idp_session!`
- `idp_session_fresh?`
- `verify_idp_session_now!`
- `stamp_idp_session_confirmed!`

The word `fresh` should remain reserved for step-up and recent reauthentication. This feature is
session liveness assurance, not step-up.

## Persistence And Cache

- Do not add `last_idp_confirmed_at` columns to `client_tokens`, `operator_tokens`, or
  `visitor_tokens`.
- Do not persist session assurance timestamps in token tables.
- If throttling or caching is needed, use only short-lived volatile cache such as `Rails.cache` or
  SolidCache, keyed by Sign session identifier and scope.
- Cache entries are not authority.

## Route Contract

No proprietary Acme internal session-check route should be introduced.

If a dedicated Sign-local route contract is needed, keep it Sign-local, for example:

- `GET /auth/session_check`
- `GET /auth/session_check/callback`

If the existing Sign auth callback flow is sufficient, no new route is required.

## SameSite Risk

The `SameSite=Strict` interaction for the browser-based silent check is an implementation risk to
verify with browser tests. It is not a reason to introduce a proprietary Acme session-check API.

## What This Feature Is Not

This feature answers:

- Is the Acme authority session still live?

This feature does not answer:

- Did the user recently re-authenticate?
- Did the user perform step-up?
- Can the user change passkeys, password, or TOTP?

High-risk mutation pages should keep or add a separate `sign_require_fresh_authentication!` gate
later. That later gate can use `max_age=0` or the existing step-up ceremony.

## Tests To Add

- Local Sign session missing redirects to the normal login flow.
- Local Sign session present and Acme `prompt=none` success allows the sensitive page.
- Acme `login_required` purges the Sign session and requires login.
- Acme timeout or 5xx denies the sensitive page and preserves the Sign session.
- Helper names are `sign_*` and no `idp_*` helper names are introduced.
- No `last_idp_confirmed_at` migration exists.
- No Acme proprietary session-check route exists.

## Status

This note is the current design direction for Sign session liveness assurance. It replaces the older
proprietary session-check proposal.
