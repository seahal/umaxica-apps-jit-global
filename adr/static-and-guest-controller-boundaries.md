# ADR: Open / Bare / Private / Guest Controller Boundaries

**Status:** Deprecated (2026-05-24)

This ADR is superseded for implementation purposes by
`adr/two-base-authentication-mode-boundaries.md`. The current direction is to stop using
`OpenController`, `PrivateController`, and `GuestController` inheritance as the request access
contract. The semantic controller-base target is `BareController` plus each surface-local
`ApplicationController`; authentication classification is explicit controller/action metadata and
policy, not four-way controller inheritance.

## Context

The controller base hierarchy is still transitional. Several controllers express their request
boundary by inheriting from a broad `ApplicationController` and then declaring flags such as
`public_strict!`, `guest_only!`, or `auth_required!`.

That makes intent harder to read from the class declaration alone:

- endpoints that are open to both anonymous and authenticated actors are mixed with fully private
  endpoints;
- lightweight endpoints that should not know about authentication still inherit authentication,
  preference, session, and actor lifecycle behavior;
- guest-only pages such as sign-up and sign-in still carry explicit `guest_only!` or
  `reject_logged_in_session` declarations;
- `ApplicationController` is created by Rails generators and therefore remains the unavoidable
  default parent for newly generated controllers until a developer chooses the correct boundary.

Earlier ADRs used `PublicController`, `OpenController`, and then `StaticController` while the
boundary vocabulary was still settling. The current direction is to name the four access contracts
directly:

- open to anyone, but authentication-aware;
- bare of authentication behavior;
- private to authenticated actors;
- guest-only, where authenticated actors are rejected.

## Decision

Adopt these controller boundary names for `sign` and `acme`:

- `OpenController` is the base for endpoints that are reachable with or without authentication.
  These endpoints may read session/authentication state when present, but they do not require a
  signed-in actor.
- `BareController` is the lightweight base for endpoints that do not implement authentication at
  all. These endpoints should not read session, preference, authentication, authorization,
  verification, or `Current`/`Actor` state.
- `PrivateController` is the base for endpoints that require an authenticated actor and run the full
  surface pipeline.
- `GuestController` is the base for pages that must reject an already-authenticated actor, such as
  sign-up and sign-in entry flows.

`sign` and `acme` should both use this pattern. The implementation may be phased, but the intended
shape is the same for both boundaries.

`ApplicationController` remains as a Rails compatibility entry point, not as a semantic access
boundary. Since `rails generate controller` creates controllers inheriting from
`ApplicationController`, generated controllers may start there temporarily. Before a generated
controller is considered complete, its parent must be changed to one of `OpenController`,
`BareController`, `PrivateController`, or `GuestController` unless there is an explicit documented
reason to keep the compatibility parent.

The long-term direction is to remove controller-local flag declarations for this boundary:

- `public_strict!` becomes unnecessary when a controller inherits from `OpenController` or
  `BareController`, depending on whether it needs authentication awareness.
- `auth_required!` becomes unnecessary when a controller inherits from `PrivateController`.
- `guest_only!` becomes an implementation detail of `GuestController`.

## Boundary Semantics

### OpenController

`OpenController` is for endpoints that are accessible regardless of whether the actor is signed in.

It may include session, preference, authentication, actor lifecycle, and observability concerns so
the endpoint can personalize behavior for authenticated actors. It must not require login by
default, and it must not run step-up or private authorization gates unless a specific action opts
into them through a narrower controller or explicit policy.

Examples:

- sign-in callback or continuation endpoints that need to inspect a possible session;
- preference endpoints that can operate anonymously but can also bind to a signed-in actor;
- product-facing pages that can render differently for signed-in and anonymous actors.

### BareController

`BareController` is for endpoints that have no authentication implementation.

It should include only the concerns needed by those endpoints, such as browser gating, CSRF
protection, and default rate limiting. It should avoid the full authentication, authorization,
verification, preference, and `Current`/`Actor` lifecycle unless the endpoint is reclassified as
`OpenController`.

Examples:

- health endpoints;
- robots endpoints;
- sitemap endpoints;
- static-style infrastructure endpoints.

### PrivateController

`PrivateController` is for endpoints that require a signed-in actor.

It owns the full surface pipeline: rate limit, preference, authentication, step-up verification,
authorization, actor/current lifecycle, and finisher behavior in the established order. Controllers
under this base should not need endpoint-local `auth_required!` declarations.

Examples:

- dashboards;
- account and configuration screens;
- credential management;
- private API endpoints tied to an authenticated actor.

### GuestController

`GuestController` is for pages where authenticated actors should not enter the flow.

It may share most of the `OpenController` or `PrivateController` machinery during migration, but its
contract is distinct: if an actor is already authenticated, the request is rejected or redirected
according to the surface's guest-flow behavior. Ordinary endpoint controllers should not repeat
`guest_only!` after they inherit from this base.

Examples:

- sign-up entry pages;
- sign-in entry pages;
- credential-entry pages that are invalid for an already-authenticated actor.

### ApplicationController

`ApplicationController` is not one of the four semantic access boundaries.

It remains available because Rails tooling and existing controllers depend on it. During migration,
it may continue to contain the existing surface pipeline and compatibility policy DSL. New or
migrated controllers should treat it as a generated starting point and then move to the correct
boundary base.

Keeping `ApplicationController` as a compatibility parent is intentional. A generated controller
that accidentally remains under `ApplicationController` may be noisy or overly restrictive, but that
failure mode is preferable to silently placing new code under the wrong open or bare boundary.

### Temporary Explicit Exceptions

Some controllers combine the four boundary semantics with additional security state that is not yet
represented by a dedicated base class. These controllers may temporarily remain on
`ApplicationController` or another existing compatibility parent when moving them directly to one of
the four bases would risk dropping a required guard.

This is not a fifth boundary. It is an exception bucket for controllers that need a named derivative
of one of the four bases before they are safe to migrate.

Current exception shapes include:

- social authentication entry controllers that combine an open `continue` action with private unlink
  actions that require step-up verification;
- session-limit gate controllers that are open at the access-policy level but require a valid
  pending session-limit gate;
- OAuth and OIDC callback controllers that are open but rely on provider state, callback guard, or
  PKCE/session validation;
- OAuth token exchange endpoints that are unauthenticated browser-session endpoints, use
  `null_session`, and authenticate clients through protocol parameters instead of an actor session;
- edge token, DBSC, and preference endpoints that are open but deliberately keep only selected parts
  of the session, cookie, preference, or token pipeline.

These exceptions must be documented before they are left behind. New code should not add additional
`ApplicationController` exceptions unless it records the security state that prevents immediate
migration and identifies the intended derivative base.

## Compatibility

Existing `PublicController` constants may remain temporarily as compatibility aliases or subclasses
of `BareController`.

Existing `StaticController` constants may remain temporarily during the rename to `BareController`.
New or migrated lightweight endpoint code should prefer `BareController`.

Existing `OpenController` constants that currently inherit from `StaticController` must be audited.
Under this ADR, `OpenController` is authentication-aware and is not a synonym for `BareController`.

Existing `guest_only!`, `public_strict!`, and `auth_required!` call sites may remain temporarily
while controllers are migrated. After migration, endpoint-local calls to those DSL methods should be
treated as legacy and removed.

## Relationship To Earlier ADRs

This ADR refines and partially supersedes the naming and tier direction in:

- `adr/public-controller-base.md`
- `adr/three-tier-controller-base.md`

Those ADRs remain useful historical context for why separate controller bases exist, but their
`PublicController` naming, the interim three-tier model, and the temporary `StaticController` naming
are no longer the current direction for `sign` and `acme`.

## Consequences

- Controller inheritance becomes the access contract: `OpenController`, `BareController`,
  `PrivateController`, or `GuestController`.
- `ApplicationController` remains compatible with Rails generators but is no longer treated as the
  semantic destination for new controllers.
- The difference between "public but authentication-aware" and "no authentication implementation"
  becomes explicit through `OpenController` versus `BareController`.
- Security-sensitive exception controllers may temporarily remain on compatibility parents, but only
  as documented follow-up work toward a derivative of one of the four bases.
- `public_strict!`, `auth_required!`, and repeated `guest_only!` declarations can be removed
  incrementally from migrated controllers.
- Compatibility constants such as `PublicController` and `StaticController` can be retired only
  after all references have moved to the four boundary names.
- `sign` and `acme` should converge on the same controller boundary naming, even if migration timing
  differs by surface.
