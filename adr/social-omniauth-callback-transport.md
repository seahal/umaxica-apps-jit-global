# Social OmniAuth Callback Transport (2026-07-24)

## Status

Accepted

## Supersedes

This ADR supersedes only the callback-transport statement in
`adr/sign-up-authentication-handoff-and-social-rt.md` that specified an Apple POST callback. It does
not change that ADR's surface, authority, or route vocabulary decisions.

## Context

The app's Apple strategy explicitly requests `response_type=code` and `response_mode=query` with no
Apple scopes. Apple documents `query` as the appropriate response mode when no scopes are requested.
Google OpenID Connect returns its authorization response through a browser redirect. The previous
route and guard configuration accepted both GET and POST for Apple callbacks, and OmniAuth accepted
both GET and POST for request initiation. That accepted paths that neither configured provider flow
should use.

The application is deployed behind a proxy. Its inbound Rack host can be the private Auth origin,
while the redirect URI registered with providers must be the public Auth origin. Deriving the
outbound redirect URI from the inbound `Host` header can produce an unregistered or
attacker-influenced URI.

## Decision

The app social transport contract is:

| Phase             | Provider         | Method | Path                                                             |
| ----------------- | ---------------- | ------ | ---------------------------------------------------------------- |
| Ceremony entry    | Apple and Google | GET    | Existing app social session, registration, and link entry routes |
| OmniAuth request  | Apple and Google | POST   | `/social/apple` or `/social/google`                              |
| Provider callback | Apple and Google | GET    | `/social/apple/callback` or `/social/google/callback`            |
| Failure           | Apple and Google | GET    | `/social/failure`                                                |

The entry controller renders an auto-submitting, CSRF-token-protected POST form for the OmniAuth
request phase. It does not put ceremony state into the request URL. OmniAuth request middleware is
configured to accept POST only.

`OmniAuth.config.full_host` is the validated, immutable `PUBLIC_AUTH_SERVICE_URL`; it is never
derived from the incoming Rack request. Ingress host validation remains compatible with the trusted
proxy's private origin and is not a substitute for the registered public redirect URI.

The non-resourceful OmniAuth paths are a permanent, narrowly scoped routing exception while OmniAuth
is in use. They are limited to the app Auth surface and are protected by the callback guard and
provider-specific state binding.

## Consequences

- A POST callback is rejected by routing rather than being processed as a second Apple callback
  contract.
- A GET request cannot initiate an OmniAuth request phase.
- The public callback origin is stable across proxy configuration and hostile inbound Host headers.
- Browser JavaScript must be available for automatic form submission; a no-script submit control
  remains available.
- Changing Apple scopes or response mode requires a new ADR and route/strategy contract tests before
  production use.

## Verification

Route, controller, Rack-guard, and initializer tests cover the permitted methods, CSRF form, fixed
outbound origin, callback state, and rejection paths. The provider console must retain the exact
public GET callback URLs.

## Sources

- Apple, “Request an authorization to the Sign in with Apple server,”
  https://developer.apple.com/documentation/signinwithapplerestapi/request-an-authorization-to-the-sign-in-with-apple-server
  (accessed 2026-07-24).
- Google, “OpenID Connect,” Authorization endpoint reference,
  https://developers.google.com/identity/openid-connect/reference (accessed 2026-07-24).
- RFC 9700, Sections 4.6 and 4.11, https://www.rfc-editor.org/rfc/rfc9700.html (accessed
  2026-07-24).
- OmniAuth 2.1.4 and omniauth-rails_csrf_protection 2.0.1 installed source and README (reviewed
  2026-07-24).
