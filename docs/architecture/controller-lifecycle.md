# Controller Lifecycle

## Purpose

This document is the operating guide for controller boundary implementation.

The active controller bases are:

- `BareController`
- surface-local `ApplicationController`

`OpenController`, `PrivateController`, and `GuestController` are legacy compatibility wrappers, not
the source of truth for authentication classification.

Use this document with `docs/architecture/controller-boundaries.md` and
`docs/architecture/current_context.md`.

## Source Of Truth

Current implementation work should follow these documents in this order:

1. `adr/two-base-authentication-mode-boundaries.md`
2. `adr/static-and-guest-controller-boundaries.md`
3. `adr/actor-current-facade.md`
4. `adr/preference-soft-bubble-doctrine.md`
5. `adr/preference-setting-configurator-url-boundaries.md`
6. `docs/architecture/controller-boundaries.md`
7. `docs/architecture/current_context.md`
8. `docs/architecture/preference.md`

`adr/three-tier-controller-base.md` and `adr/public-controller-base.md` are historical context only.
Do not use them as the current implementation contract.

## Boundary Summary

`BareController` inherits directly from `ActionController::Base`. It is the named base for routes
that are classified as bare by concrete controller/action metadata, and it deliberately bypasses the
surface authentication-aware controller lifecycle.

Surface-local `ApplicationController` inherits directly from `ActionController::Base` and owns the
authentication-aware request lifecycle.

Authentication modes that are more specific than this base split, including bare endpoints,
guest-only flows, optional access, and step-up requirements, must be declared and audited explicitly
by concrete controller/action metadata and policy. They must not be inferred from legacy
compatibility inheritance alone. Missing declarations resolve to `:deny_all`.

## Request Lifecycle Shape

Controller lifecycle code should move toward this shape:

1. Rate limiting and request self-defense.
2. Token verification and decode.
3. Actor base initialization from verified token state.
4. Request-local preference overlay.
5. Side-effect reflection from resolved Actor values.
6. Action execution.
7. Guaranteed Actor cleanup.

`ActorSupport#set_current_context` belongs before authentication-sensitive state is completed. It
may set host/surface context and the unauthenticated actor fallback. It must not write cookies,
mutate preference records, issue tokens, or recover broken preference tokens from the database.

`ActorSupport#set_current_actor` belongs after authentication and preference loading have had the
opportunity to resolve the request resource. It completes the `Actor` snapshot with actor,
authentication, configuration, and preference values.

The target authenticated lifecycle is:

```text
rate limit
-> verify/decode access token
-> refresh preference token from DB for logged-in HTML preference edit entry when applicable
-> initialize Actor from token state
-> overlay valid request-local lx/ct/tz onto Actor.preferences
-> apply locale/timezone/theme from Actor.preferences
-> controller action
-> ensure Actor.clear
```

Current surface-local `ApplicationController` callbacks place the relevant lifecycle steps in this
order:

1. `set_preferences_cookie`
2. `transparent_refresh_access_token`
3. `set_current_actor`
4. `touch_session_activity!` inside current-resource resolution

`set_preferences_cookie` may write during preference bootstrap, preference refresh rotation,
refresh-token lifetime updates, and logged-in preference edit entry refresh. These writes are
allowed only as lifecycle exceptions.

`transparent_refresh_access_token` may write when a valid auth refresh cookie is present and the
HTML request lacks an access cookie. That path rotates or refreshes auth session/token state before
the Actor snapshot is finalized.

`set_current_actor` should install the immutable request Actor snapshot. It must not create
preference rows, rotate tokens, or repair malformed preference JWTs.

`touch_session_activity!` may write a throttled `last_used_at` update to the token/session row while
resolving the current authenticated resource. This is a session-lifecycle write, not a product data
write.

The GET/HEAD write categories above are allowlisted in
[`docs/security/db-write-allowlist.md`](../security/db-write-allowlist.md). New read-side writes
must be added there before tests or CI allow them.

The request-local `lx`, `ct`, and `tz` overlay changes only the current request's
`Actor.preferences`. It must not write the database, reissue JWTs, or update the persistent
preference snapshot. Locale, timezone, theme, observability, and similar request effects should be
applied after the Actor snapshot and request overlay are resolved. Runtime reads should use
`Actor.preferences`.

The logged-in HTML preference edit entry refresh is a bounded preference-screen exception. It exists
so preference edit screens can pick up actor-local DB changes made in another browser or device
before rendering. It must run before `set_current_actor`, and it must not be used as a generic
database fallback for normal pages or broken JWTs.

Actor cleanup should use the domain-facing `Actor.clear` API. Prefer a prepended `around_action`
with `ensure` for new lifecycle code so redirects, renders, and exceptions do not leave stale
request state behind.

## Authorization

Authorization uses Action Policy.

The Action Policy subject key remains `user`. In this codebase that name is an authorization-library
interface, not a `User` model or application-facing current-context API. Do not rename it to
`actor`; `Actor` is the CurrentAttributes facade.

## Preference Read Contract

Runtime preference reads should go through `Actor.preferences`.

For normal Rails request code, preference data flows in one direction:

```text
DB -> Preference JWT payload -> Actor.preferences
```

The database is the source of truth and storage boundary. The Preference JWT is the runtime read
cache. `Actor.preferences` is the immutable request runtime value built from that payload, with
valid request-local `lx`, `ct`, and `tz` values overlaid when explicitly present. Auth access tokens
do not carry preference snapshots. JS-readable preference cookies are Rails write-only compatibility
mirrors and must not be trusted as Rails request input.

The overlay is not a write path. For example, if the Preference JWT says `lx=ja` and the request
says `lx=en`, the current request renders with `Actor.preferences.language == "en"`, but the
database and Preference JWT remain `ja`.

Controllers should not directly read and interpret preference model internals when a concern method
or `Actor.preferences` exposes the needed value. Writes remain in the preference concerns and
surface-specific models because shared preference and actor-local preference are stored separately.

Here, "shared preference" means `AppPreference`, `OrgPreference`, or `ComPreference`: the
login-independent surface preference state. "Actor-local preference" means `UserPreference`,
`OperatorPreference`, or `VisitorPreference`: the account-local state for the current runtime actor.
This is not Rails `session`, and it is not the `Actor` CurrentAttributes object.

`/preference`, `/setting`, and `/configurator` are distinct URL responsibilities. `/preference` owns
login-independent preference edits, `/setting` owns signed-in user self-service settings, and
`/configurator` owns operator-managed configuration. Existing plural `/settings` routes are a
compatibility gap, not the target language for new route work.

## Cookie Key Compatibility

The language cookie key remains `language`.

Although the request/JWT shorthand key is `lx`, the `language` cookie name follows the Hono
framework language convention and is still in use. Do not rename the cookie to `lx` without a
separate compatibility plan.

The theme key remains `ct` for request parameters, JWT payloads, and theme cookie transport.

## Known Migration Gaps

Preference concerns must not register request callbacks or callback skips from `included do` blocks.
Controller bases and endpoint controllers own callback order explicitly. `PreferenceLocalization`
registers no callbacks from `included do`; controllers that need locale/timezone reflection place
`before_action :apply_localization_preferences` explicitly in their base class. All surface
`ApplicationController`s now also run `set_color_theme` after `set_current_actor`, so theme
reflection can rely on `Actor.preferences` being complete. These two gaps are resolved as of the
2026-07-17 controller-layer audit.

Some preference setup code still has deliberate side effects, including preference token reissue,
cookie writes, refresh token lifetime updates, and login-time adoption. Those effects should remain
inside preference/authentication concerns and must not be moved into `set_current_context`.
