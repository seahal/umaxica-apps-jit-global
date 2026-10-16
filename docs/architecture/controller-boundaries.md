# Controller Boundaries

The application no longer uses `OpenController`, `PrivateController`, and `GuestController`
inheritance as the request access contract.

The current controller inheritance contract is intentionally narrow:

- `BareController` inherits directly from `ActionController::Base` and owns endpoints whose concrete
  controller/action metadata classifies them as bare.
- Surface-local `ApplicationController` inherits from `ActionController::Base` and owns the
  authentication-aware request lifecycle.

Authentication classification must be declared and audited explicitly by concrete controller/action
metadata, not inferred from `OpenController`, `PrivateController`, or `GuestController` inheritance.
Missing declarations resolve to `:deny_all`.

For `sign`, these boundaries are surface-local: `Sign::App::*Controller`, `Sign::Com::*Controller`,
and `Sign::Org::*Controller` own their own base classes so `app`, `com`, and `org` behavior stays
separated.

## Current Boundaries

### BareController

`BareController` is the named base for endpoints classified as bare. It is defined per surface, but
does not inherit the surface-local `ApplicationController`, so it avoids authentication, preference,
Actor, verification, authorization, and other application request lifecycle callbacks.

Common examples:

- health endpoints;
- robots endpoints;
- sitemap endpoints;
- public infrastructure endpoints with no actor semantics.

### ApplicationController

Use the surface-local `ApplicationController` for every endpoint that uses authentication-aware
request machinery.

It owns rate limiting, session/authentication resolution, preference resolution, Actor setup,
verification, authorization, observability, and Actor cleanup in the surface's established order.
Concrete controllers or actions declare one of the supported authentication modes:

| Mode        | Authenticated actor | Anonymous actor | Meaning                                                                       |
| ----------- | ------------------- | --------------- | ----------------------------------------------------------------------------- |
| `:deny_all` | closed              | closed          | Default fail-closed mode for undeclared, disabled, or unclassified endpoints. |
| `:guest`    | closed              | open            | Guest entry flows such as sign in, sign up, and recovery.                     |
| `:private`  | open                | closed          | Normal authenticated endpoints.                                               |
| `:open`     | open                | open            | Anonymous and authenticated actors are both allowed.                          |

`AUTHENTICATION_MODE` declarations must be local to the concrete controller or action. A parent
constant does not count. Undeclared endpoints are `:deny_all`.

`:open` does not permit authentication failure fallback. Open endpoints must distinguish absent
credentials from invalid, expired, revoked, or malformed credentials. Absent credentials may proceed
as anonymous; invalid credentials must use the normal authentication failure path.

Authentication mode is not the source of truth for Step-Up/AAL. Authorization policy owns the
required assurance boundary, method set, and step-up scope for a concrete actor/action/resource. The
step-up gate owns challenge issuance, redirect, return target validation, continuation, and
ticket/session mutation. Controller/action metadata may exist for route inventory and CI assertions,
but runtime must not use it as a second source of truth for step-up requirements.

Rails owns application-semantic rate limiting, not network-layer firewalling or generic HTTP abuse
controls. Public HTTP flood mitigation, path-based coarse limits, bot filtering, and viewer-IP
allow/deny belong to CloudFront + AWS WAF. ALB and ECS networking own origin gating. See
`adr/dos-and-firewall-controls-at-cdn-aws-edge-not-in-rails.md`.

### Legacy Compatibility Controllers

`OpenController`, `PrivateController`, and `GuestController` may exist temporarily as compatibility
classes while routes are migrated, but they are not the source of truth for authentication
classification.

`OpenController` compatibility descendants represent authentication-aware endpoints that should move
under surface-local `ApplicationController` with explicit `:open` declarations.

`PrivateController` is a compatibility wrapper for endpoints that require an authenticated actor.

Private controllers run the full surface pipeline for authentication, verification, authorization,
preferences, current actor setup, and request finishing in the established order.

Common examples:

- dashboards;
- signed-in user settings under `/setting`;
- operator-controlled configuration under `/configurator`;
- credential management;
- authenticated APIs tied to the current actor.

`GuestController` is a compatibility wrapper for flows that authenticated actors must not enter.

Guest controllers are for sign-in, sign-up, credential entry, and similar pages where an already
signed-in actor should be rejected or redirected according to the surface behavior.

New code must not rely on `OpenController`, `PrivateController`, or `GuestController` inheritance as
the authentication declaration.

## Etc: Temporary Exceptions

Some security-sensitive controllers are not yet migrated to the two-base target with explicit
authentication metadata. These are temporary exceptions, not another boundary category.

An exception is allowed only when a controller needs additional guard state that should first be
captured by concrete controller/action authentication metadata or a narrow local abstraction.

Current exception families:

- social authentication controllers that currently combine open entry actions with private unlink
  actions requiring step-up verification;
- session-limit gate controllers that are open to a pending login flow (the waiting unit) but
  reject ordinary active sessions; the waiting unit reaches only purge and cancel, never MFA reset;
- OAuth and OIDC callback controllers protected by provider state, callback guard, PKCE verifier,
  nonce, or session state;
- OAuth token exchange endpoints that use `null_session` and protocol-level client authentication
  instead of actor authentication;
- edge token, DBSC, and preference endpoints that are open but intentionally use only selected
  cookie, token, DBSC, and preference pipeline behavior.

Preferred retirement paths:

- split mixed Open/Private controllers by action boundary;
- move authentication-aware public entry points to surface-local `ApplicationController` with
  explicit `:open` declarations;
- use explicit controller/action authentication metadata for private, guest-only, optional, and bare
  behavior;
- keep surface behavior local to `app`, `com`, and `org` unless an existing shared concern already
  provides a safe abstraction.

When an exception is migrated, keep the security checks intact: CSRF behavior, callback state,
nonce, DPoP, DBSC challenge, session-limit gate, restricted-session handling, and step-up
verification must not be removed as an inheritance side effect.
