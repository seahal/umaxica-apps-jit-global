# Refresh Token Rotation

> **Current boundary (2026-09-15):** Base is the sole Identity Provider, Authorization Server and
> token authority. Auth is a credential ceremony surface; it is not an RP, token issuer, session
> authority or assurance-policy authority. Older Acme/Sign names in this document describe legacy
> physical namespaces only and do not change the current Base/Auth ownership boundary.

## Authority

Refresh token families are Base authority.

Base owns refresh token issuance, rotation, replay detection, family revocation, compromise state,
DBSC/device binding interaction, transparent refresh, explicit refresh endpoints, and audit. Auth
must not issue, rotate, refresh, revoke, or list refresh tokens. It must not issue access tokens or
downstream tokens.

The OIDC token endpoint accepts both `authorization_code` and `refresh_token` grants. A refresh
request is bound to the registered client and its RP session, validates the active parent session,
scope, sender constraint and absolute session ceiling, and rotates the presented token on the
writing database role. The RP session stores the original `auth_time`, `acr`, `amr`, and OIDC nonce;
refresh advances token `iat` but never substitutes the refresh or exchange time for `auth_time`.
Missing authentication-event time fails closed. Replay and revoke outcomes remain scoped to the
owning RP session/family, and the project continues to accept the residual risk that already-issued
short-lived access JWTs remain usable until their normal expiry after session termination.

Logical authority moves now; physical storage may remain where it is. Existing sign-side tables,
models, services, controllers, namespaces, and tests do not imply sign-side authority.

## Legacy Namespace References

References such as `Sign::RefreshTokenService` are legacy namespace or storage implementation
details. They do not make Auth the refresh-token authority.

During migration, code may still live in sign-named modules or use sign-side physical tables. That
placement must be treated as compatibility implementation until the code is moved or renamed. The
authority decision is already Base.

## Rotation Contract

Refresh tokens are stateful records. A successful refresh consumes the presented refresh token and
returns a newly issued token in the same family.

Base refresh rotation must:

- store verifiers only as digests;
- preserve a family identifier across rotations;
- issue a replacement refresh token atomically with access-token reissue;
- mark the previous token as rotated or retired;
- run on the writing role so row locks and mutation hit the primary database;
- keep access-token `jti`, protocol `sid`, and refresh-token family identifiers distinct;
- return refreshed access tokens to the default AAL1 context unless Base policy explicitly says
  otherwise.

### Absolute Session Lifetime

Refresh-token expiry is an internal token lifetime. **Session Expires At** is the absolute session
lifetime ceiling: successful refresh rotation MUST NOT extend it. The current root-token schema has
no second timestamp: `discarded_at` is initialized at session establishment, used to reject refresh
after that instant, and copied unchanged across rotation. Its user-facing meaning is therefore the
fixed session ceiling, never a sliding refresh expiry. OIDC usage rows retain their separate
`refresh_token_expires_at` internally, clamped to the root session ceiling. Newly issued Access and
Refresh Tokens also end no later than that ceiling. Logout scheduling, forced termination, or revoke
may end the session earlier. Reaching the ceiling invalidates refresh and authenticated session
resolution, so rotation cannot revive it. The implementation contract is covered by
`test/services/refresh_token_absolute_expiry_test.rb`,
`test/values/session_absolute_expiry_value_test.rb`,
`test/services/oidc/token_exchange_service_test.rb`, and
`test/integration/core_browser_api_boundary_test.rb`.

Successful refresh rotation remains internal to the user-facing activity history while its existing
Chronicle event is retained for audit. Replay detection is separately classified as a high-risk,
user-attention event.

Step-up freshness is not sticky across refresh. A refresh must not extend `recent_auth`, `sudo`,
`last_step_up_at`, or equivalent freshness.

## Browser Transparent Refresh

Transparent refresh is a Base browser recovery path for expired or missing access cookies. It is
not an Auth credential ceremony and not an Auth token endpoint.

Transparent refresh is allowed only when Base policy permits it, typically when:

- the request is `GET` or `HEAD`;
- the negotiated request format is HTML;
- the access-token cookie is absent or expired;
- the refresh-token cookie is present;
- the current request has not already attempted transparent refresh.

Transparent refresh must not run for state-changing methods, JSON requests, malformed HTML-like
`Accept` headers, requests that already carry a valid access-token cookie, or credential ceremony
routes on Auth.

## Replay And Compromise

Reusing an already-rotated refresh token is compromise evidence.

When replay is detected, Base owns the response:

- reject the refresh;
- revoke or quarantine the refresh token family according to policy;
- update session compromise state;
- clean up or invalidate related device/session binding state when required;
- clear or invalidate affected access cookies;
- emit audit and security telemetry without logging raw verifiers.

Revoked or expired tokens remain invalid but do not automatically imply replay compromise unless
Base policy classifies them that way.

## DBSC And Device Binding

DBSC and device binding are attached to Base session and refresh-token authority. Refresh rotation
must evaluate the expected device/session binding and reject mismatches according to Base policy.

Auth may execute credential ceremonies that help prove an actor or credential, but it must not
use DBSC/device binding to rotate refresh tokens or update session state.

## Downstream Tokens

Downstream tokens must be Base-issued. `core`, `line`, and future downstream services must not trust
Auth-issued session, access, refresh, or downstream tokens.

Refresh rotation may result in new Base access tokens or downstream-token eligibility, but Auth
does not mint those tokens.

## Grace Window Decision

There is no Redis-backed JTI deduplication or short grace window today. Redis, Valkey, and other
cache-backed session-state stores are not the refresh-token authority.

Any future grace or overlap behavior must be DB-backed or otherwise explicitly accepted by a current
ADR, must preserve replay detection, and must have tests for concurrent reuse, stale-token replay,
binding mismatch, revoked-token handling, and compromise-state updates.

## Verification

Regression coverage should prove:

- Auth cannot issue or rotate refresh tokens;
- Base rotates refresh token families atomically;
- replay revokes or quarantines the correct family;
- device/session binding mismatch fails closed;
- refreshed access returns to default AAL1 context;
- downstream services reject sign-issued tokens.

Existing tests with sign-named paths or services are compatibility tests until the implementation is
renamed. They must not assert sign-side authority.

## Related

- `docs/identity/authority-boundary.md`
- `docs/security/session-token-authority.md`
- `docs/security/downstream-token-authority.md`
- `docs/security/cookie-domain-scope.md`
