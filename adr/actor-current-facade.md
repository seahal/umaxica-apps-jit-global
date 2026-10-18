# ADR: Actor Current Context

**Status:** Accepted (2026-05-13)

> **Hydration source supersession (2026-05-30, updated 2026-06-18):** This ADR's original text says
> `Actor.preferences` is initialized from the verified auth access-token `prf` claim, but that
> source is retired. `Actor.preferences` is hydrated from the Preference JWT (`*_preference_access`)
> payload, the signed projection of the database source of truth, and then valid request-local `lx`,
> `ct`, and `tz` overlays are applied without writing the database or JWT. The obsolete auth
> access-token `prf` claim is no longer read and is no longer emitted for newly issued auth access
> tokens. See the 2026-05-30 update in `adr/preference-soft-bubble-doctrine.md`.

## Context

The app previously had multiple request-context experiments:

- `Current < ActiveSupport::CurrentAttributes` stored actor, token, session, surface/domain,
  preference, and observability state.
- `Jumper`, `Acmeer`, and `Signer` are subdomain/surface-flavored `CurrentAttributes` classes.
- Application code read `Current.*` directly in some places.

This creates two problems. First, request-local storage and the application-facing API are coupled.
Second, subdomain-specific current classes make every new surface/tenant/region look like it needs a
new global-ish context class.

The desired direction is one request-local current-context container with immutable read values.

## Decision

Adopt `Actor` as the only current-context container. Application code may read resolved values from
Actor, but Actor writes are restricted to controller-boundary lifecycle and resolver/installer code.

`Actor` is backed by `ActiveSupport::CurrentAttributes`, but the mutable request-local slot stores
one immutable `Actor::Context` snapshot implemented with Ruby `Data.define`. Controllers,
middleware, authentication, preference resolution, host/context resolvers, policies, services, and
views may read resolved request context through `Actor`, for example:

```ruby
Actor.client
Actor.account
Actor.tld
Actor.whoami
Actor.authn.aal
Actor.authz.policy_user
Actor.step_up.satisfied?
Actor.preferences.language
Actor.configuration.sign.value
Actor.authn.login_public_id
```

`Actor` does not branch by subdomain. Host and surface differences are resolved before application
code runs, by a request-start resolver that populates `Actor`.

Preference remains an immutable value object exposed as `Actor::Preference` and read through the
second-layer `Actor.preferences` reader. It carries the request's localization and display
preference snapshot, including `language`, `region`, `timezone`, `theme`, `currency`, `date_format`,
`time_format`, `motion`, `density`, and `items_per_page`.

For normal authenticated requests, `Actor.preferences` is initialized from the Preference JWT
payload and then rebuilt with a request-local overlay for valid explicit `lx`, `ct`, and `tz`
parameters. That overlay is part of the current request's effective runtime context only. It must
not write the database, reissue tokens, or become the next persistent preference snapshot.

Updates replace the whole `Actor::Context` snapshot instead of mutating independent current
attributes in place. Existing `Actor.actor = ...` style writers are compatibility API only; new
write paths should install complete value objects through controller-boundary installer code.

`Actor.whoami` exposes the current actor type (`:client`, `:operator`, `:visitor`, or
`:unauthenticated`). `Actor.tld` exposes the current surface label (`:app`, `:com`, `:org`, `:net`,
or `:dev`).

`Actor.tld` is the only application-facing surface API. `Actor.surface` and `Actor.domain` are
removed and must not be restored as compatibility aliases.

Authentication state is exposed through `Actor.authn`. The application-facing identifier for the
current login/session row is `Actor.authn.login_public_id`; this corresponds to the current entry
shown in the user-facing configuration sessions pages, but avoids the ambiguous `session` name used
by Rails. Direct `Actor.session` reads are removed.

Decoded access-token claims are not a general application API. `Actor.token` is removed. If a
low-level auth or policy boundary must inspect raw access-token claims, use
`Actor.authn.access_claims` and prefer adding typed authentication readers such as `acr`, `amr`, or
`verified?` instead of spreading raw claim access.

Authorization keeps the existing Action Policy context key `:user`. `Actor` is the request-context
facade, but this ADR does not rename Action Policy's authorization context to `:actor`. Policy
support code should read explicit authorization context such as `Actor.authz.policy_user` and
`Actor.authz.token_claims`, not reach back into authentication storage.

Actor read paths are shallow by default. The normal maximum shape is `Actor.xxx.yyy`, where the
second layer names a resolved context area and the third layer names a concrete value or predicate.
The only accepted four-layer exception is configuration namespacing:
`Actor.configuration.<namespace>.<value>`. Use it only when the third layer is a clear configuration
category such as `sign`, `post`, or `security`, and the fourth layer is the actual value or
predicate-style value such as `value`, `enabled`, or `mode`.

Do not create fifth-layer configuration reads such as `Actor.configuration.sign.value.raw`. Do not
use deep Actor chains to walk runtime state transitions or unrelated object graphs, such as
`Actor.authz.policy.user.account.id` or `Actor.step_up.challenge.email.otp.verified_at`.
Resolver/concern code builds complete value objects and installs them into `Actor`; nested
configuration readers are not a source of truth for persistence or fallback behavior.

## Rejected Direction

The subdomain-specific current classes are removed:

- `Jumper`
- `Acmeer`
- `Signer`

Do not restore these classes as compatibility shims. Do not introduce more surface-specific
`CurrentAttributes` classes.

The old global `Current` class is also removed. Do not restore it as a compatibility shim.

`adr/jumper-current-boundary.md` is obsolete. Its provisional `Jumper` direction is no longer
current intent.

## Consequences

- Request-local storage and application API are both centered on `Actor`.
- `Actor` state is represented as an immutable snapshot, reducing hidden mutation between controller
  callbacks.
- Future surface, tenant, region, and host growth should extend resolver output and `Actor` fields,
  not create more `CurrentAttributes` classes.
- Existing direct reads of `Current.*` in application code are migrated to `Actor.*`.
- Existing `Jumper` / `Acmeer` / `Signer` tests and lifecycle wiring are removed with this
  direction.
- Action Policy keeps its existing `:user` context name unless a later accepted ADR explicitly
  changes it.

## Related

- `adr/jumper-current-boundary.md` — obsolete predecessor.
- `adr/current-context-boundary-by-engine.md` — obsolete engine-era predecessor.
- `adr/preference-soft-bubble-doctrine.md` — preference value-object doctrine; its read-side API is
  superseded from `Current::Preference` / `Current.preference` to `Actor::Preference` /
  `Actor.preferences`.

## R2-WU04 implementation amendment (2026-10-16)

The retired session-limit token status is not request-local authentication context. The unused
`Actor::Authentication#restricted?` reader and its construction flag were removed. Historical token
status 103 remains a durable status-row value for retention and inspection, but it is rejected
before principal creation and is never exposed through `Actor.authn`. Emergency authentication
context continues to come from the typed `authn_ctx` claim and the durable operator-token context.
