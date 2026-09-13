# Current Context Architecture

## Purpose

This document records the current request-context model for this Rails application.

The request-local current context container is `Actor`. Do not introduce or restore `Current`,
`Jumper`, `Acmeer`, `Signer`, or other surface-specific current containers.

## Status

Current as of 2026-05-17.

The accepted decision is `adr/actor-current-facade.md`.

## Runtime Contract

`Actor` is the only request-local current-context container. It may be read as the immutable
current-request facade, but normal controller actions, services, policies, views, and serializers
must not build or mutate Actor state directly.

The request-local storage slot holds an immutable `Actor::Context` snapshot implemented with Ruby
`Data.define`. Updating actor state replaces the snapshot. It does not mutate independent current
attributes in place.

`Actor` is a resolved request-context snapshot, not a cache source. Lifecycle code must rebuild the
snapshot from the current authentication, preference, and controller state instead of preferring
previous `Actor.authn` or preference association values. This favors correctness over avoiding
repeated reads.

Application code may read the resolved immutable request context through `Actor`, for example:

- `Actor.actor`
- `Actor.actor_type`
- `Actor.whoami`
- `Actor.client`
- `Actor.operator`
- `Actor.visitor`
- `Actor.tld`
- `Actor.preferences`
- `Actor.authn`
- `Actor.authz`
- `Actor.step_up`
- `Actor.configuration`
- `Actor.signed_in?`
- `Actor.signed_up?`

Actor writes are restricted to controller-boundary lifecycle code and resolver/installer paths.
Prefer `current_*`, `require_*!`, `resolve_*`, and `*_satisfied?` APIs where they already expose the
same fact.

Removed current-context readers:

- `Actor.surface` and `Actor.domain` duplicated the surface label and are removed. Use `Actor.tld`.
- `Actor.session` is removed. Use `Actor.authn.login_public_id`.
- `Actor.token` is removed. Use typed `Actor.authn` or `Actor.authz` readers. Lifecycle code must
  not use an existing `Actor.authn.access_claims` value as a cache when rebuilding context.

## Request Lifecycle

Controllers that need request context include `ActorSupport`.

`ActorSupport` provides lifecycle methods only. Including it must not register controller callbacks.
Controllers opt in explicitly with `before_action` / `after_action`.

`ActorSupport#set_current_context` resolves request context that is safe before authentication, such
as host/surface context and the unauthenticated actor fallback.

`ActorSupport#set_current_actor` resolves the authenticated actor, authn/authz state, step-up state,
and preferences after authentication has had a chance to load or refresh the request resource. The
legacy `set_current` method remains a compatibility alias for `set_current_actor`.

`ActorSupport#with_actor_lifecycle` clears `Actor` in an `ensure` block for controller bases that
use an around-action lifecycle. `Finisher#purge_current` was a compatibility cleanup method for
older after-action wiring with no remaining runtime callers; it has been removed.

Use `Actor.clear` for application code that explicitly empties the current request context.
`Actor.reset` remains the Rails `ActiveSupport::CurrentAttributes` lifecycle method and has the same
clearing effect, but application code should prefer the domain-facing `clear` name.

The resolved context includes:

- authenticated actor or `Unauthenticated.instance`
- actor type (`:client`, `:operator`, `:visitor`, or `:unauthenticated`)
- `Actor.tld` from `HostContextResolver`
- `Actor.authn.login_public_id`
- typed authentication state derived from access-token claims
- resolved `Actor::Preference`
- resolved `Actor::Authz`
- resolved `Actor::StepUp`
- observability identifiers when performant consent allows them

## Surface Actors

The three user-facing surfaces use these runtime actor names:

| Surface | Actor type  | Helper           |
| ------- | ----------- | ---------------- |
| `app`   | `:client`   | `Actor.client`   |
| `org`   | `:operator` | `Actor.operator` |
| `com`   | `:visitor`  | `Actor.visitor`  |

`Actor.whoami` returns the current actor type. `Actor.tld` returns the current surface label:
`:app`, `:com`, `:org`, `:net`, or `:dev`.

Storage names may still contain compatibility prefixes such as `user_*` or `staff_*`. Those storage
names do not change the runtime current-context API.

## Preference

Preference is exposed as an immutable value object through `Actor.preferences`.

Request code should not read preference state from controller instance variables, raw JWT claims, or
legacy current-context APIs when `Actor.preferences` is available.

`Actor::Preference` contains the resolved runtime preference used by the app/org/com preference
flows. In normal authenticated requests it is initialized from the Preference JWT payload, then
valid request-local `lx`, `ct`, and `tz` values are overlaid when explicitly present. That overlay
affects only the current request and must not be copied back to the database or JWT.

Logged-in HTML preference edit screens may first refresh the current surface preference token from
the actor-local preference DB so another browser's preference change is visible before the edit
screen renders. This refresh is a bounded preference-screen entry flow and must run before
`Actor.preferences` is initialized.

- localization: `language`, `region`, `timezone`
- presentation: `theme`, `motion`, `density`, `items_per_page`
- format defaults: `currency`, `date_format`, `time_format`
- consent cookie state through `Actor.preferences.cookie`

Authenticated request setup must not repair a missing or malformed preference access-token by
reading the preference database. Treat that as a token failure and route it through the normal
failure path. A request that has not loaded a Preference JWT uses the default preference values
(theme `sy`) rather than `Actor::Preference::NULL`. `Actor::Preference::NULL` is reserved for an
unbound context (jobs, mailers, tests, and the empty snapshot before a request installs state).

## Authentication

Authentication state is exposed as an immutable value object through `Actor.authn`.

Use `Actor.authn.login_public_id` for the current login/session identifier. This is the same kind of
identifier used to mark the current row on `/setting/sessions`, but it intentionally does not use
the bare name `session` because Rails session state is a different concept.

Do not treat raw access-token payloads as the normal application contract. Prefer typed readers on
`Actor.authn`, such as:

- `login_public_id`
- `acr`
- `amr`
- `restricted?`
- `verified?`

`Actor.authn.access_claims` may exist as a low-level authentication-boundary escape hatch, but new
controller and service code should ask for typed authentication state instead of reading token claim
hashes directly. Authorization code that needs claims should receive them through `Actor.authz`.

## Authorization

Action Policy uses `user` as the authorization subject name. In this codebase that name is an
authorization-library interface, not a `User` model or application-facing current-context API.

Do not rename the Action Policy subject to `actor`: `Actor` is already the request-local current
context facade. Controllers should continue wiring Action Policy with
`authorize :user, through: :current_client`, `:current_operator`, or `:current_visitor` as
appropriate for the surface. Policies read token claims through `Actor.authz.token_claims`, not by
falling back into authentication storage.

`Actor.signed_in?` is the request-level predicate for an authenticated actor. It is true when the
current actor type is `:client`, `:operator`, or `:visitor`.

`Actor.signed_up?` is true only when the current request has an authenticated actor with a persisted
identity. Anonymous users and unsaved actor objects return false.

## Configuration

Configuration state is exposed through `Actor.configuration`.

Most Actor read paths must stay at `Actor.xxx.yyy`. Configuration is the only accepted exception
that may use a fourth layer for namespaced settings: `Actor.configuration.<namespace>.<value>`. For
example, `Actor.configuration.sign.value` is allowed because `sign` is a configuration category and
`value` is the resolved value inside that category.

The third layer under `Actor.configuration` must be a clear configuration namespace such as `sign`,
`post`, or `security`. The fourth layer must be an actual value or predicate-style value such as
`value`, `enabled`, or `mode`. Do not add fifth-layer reads such as
`Actor.configuration.sign.value.raw`, and do not use deep non-configuration chains such as
`Actor.authz.policy.user.account.id`.

Lifecycle and resolver code may install an `Actor::Configuration` value object with shallow typed
namespace objects. Normal code must not infer persistence, fallback, or cross-request behavior from
it. `Actor.configuration` is resolved request context, not the durable configuration source of
truth.

When no configuration is available, `Actor.configuration` returns a null object. Unknown readers
return a null value that is safe to chain and answers false to predicate-style feature checks such
as `enabled?` and `configured?`. This keeps guest and anonymous request paths from raising nil
errors when a view or service asks for optional configuration. This null chaining is only a safety
fallback; it is not permission to design real APIs deeper than four layers.

## Bare And Authentication-Aware Endpoints

Bare infrastructure endpoints should avoid the full `Actor` lifecycle.

`BareController` serves pure infrastructure endpoints such as health, robots, and sitemap responses
when they do not need authentication, preference, verification, or `Actor` state. Bare endpoints
must not read actor, session, preference, authorization, verification, or authentication pipeline
state.

Use the surface-local `ApplicationController` when an endpoint is reachable without authentication
but still needs to inspect session, preference, authentication, or actor state when present. Such
endpoints must declare `AUTHENTICATION_MODE = :open` on the concrete controller or action.

`:open` does not allow invalid credentials to fall back to anonymous behavior. Missing credentials
may proceed anonymously; invalid, expired, revoked, or malformed credentials must use the normal
authentication failure path.

## Rules

- Use `Actor` as the only request-local current-context container.
- Treat Actor values as immutable snapshots; replace the whole value object through the lifecycle
  installer when request state changes.
- Extend `Actor` deliberately when new request context is needed.
- Keep request context request-local and clear it after the response.
- Do not use `Actor` values as memoized inputs while rebuilding `Actor`; resolve from current
  request/auth/preference state.
- Prefer typed helpers and value objects over raw token hashes where practical.
- Keep Actor read paths to `Actor.xxx.yyy`, except `Actor.configuration.<namespace>.<value>`.
- Keep Action Policy's authorization subject name as `user`; it is not a `User` model reference.
- Do not restore old or surface-specific current containers.

## Related

- `adr/actor-current-facade.md`
- `adr/static-and-guest-controller-boundaries.md`
- `docs/architecture/actor-naming.md`
- `docs/architecture/controller-boundaries.md`
