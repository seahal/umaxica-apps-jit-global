# ADR: PublicController Base for Unauthenticated Endpoints

**Status:** Historical (superseded; 2026-05-24)

> Current direction: `OpenController` and each surface-local `ApplicationController` inherit
> directly from `ActionController::Base`; auth-free endpoint classification is explicit metadata,
> not a `PublicController`/`BareController` inheritance contract.

## Context

The `acme`, `sign`, and `jump` boundaries each expose a small number of fully public endpoints that
do not need authentication, authorization, session, preference, verification, or `Current`/`Actor`
state:

- `/health` exists in all three boundaries.
- `/robots.txt` and `/sitemap.xml` exist in `acme` and `sign`.

These controllers currently inherit from the heavy `<Boundary>::<Tld>::ApplicationController` chain
and opt out of the auth and preference machinery via
`skip_before_action :canonicalize_query_params, raise: false`,
`skip_before_action :set_region, raise: false`, and similar calls.

This pattern is fragile:

- Every new `before_action` added to an `ApplicationController` silently runs on these public
  endpoints unless someone remembers to add another `skip_before_action`.
- `raise: false` hides the case where a previously-skipped callback was removed or renamed, so the
  endpoint quietly starts running new behavior.
- The skip list grows over time and obscures what these endpoints actually need.

The boundaries also have different surface counts and different request needs:

- `acme` covers 5 TLDs (`com`, `org`, `app`, `dev`, `net`).
- `sign` covers 3 TLDs (`com`, `org`, `app`).
- `jump` covers 3 TLDs (`com`, `org`, `app`).

The desired shape is a small, explicit base that includes only what public endpoints actually need,
and excludes the entire auth/preference/Current stack by construction rather than by opt-out.

## Decision

Introduce one `PublicController` per boundary, inheriting directly from `ActionController::Base`:

- `Acme::PublicController`
- `Sign::PublicController`
- `Jump::PublicController`

Each `PublicController` is a sibling of the existing `<Boundary>::<Tld>::ApplicationController`
chain, not an ancestor and not a descendant. Public endpoints (`HealthsController`,
`RobotsController`, `SitemapsController`) inherit from `<Boundary>::PublicController` directly,
without an intermediate per-TLD base class.

```
ActionController::Base
├── Acme::Com::ApplicationController        (heavy, authenticated)
├── Acme::Org::ApplicationController
├── Acme::App::ApplicationController
├── Acme::PublicController                  (light, unauthenticated)
├── Sign::Com::ApplicationController
├── Sign::Org::ApplicationController
├── Sign::App::ApplicationController
├── Sign::PublicController
├── Jump::ApplicationController             (jumper context)
└── Jump::PublicController
```

### Included in `PublicController`

- `allow_browser versions: :modern`
- `include RateLimit` and `before_action :check_default_rate_limit`
- `protect_from_forgery using: :header_or_legacy_token, with: :exception`
- `public_strict!`

### Excluded from `PublicController`

The following are intentionally not included, even with skip directives:

- `Session`
- `Authentication::*`
- `Authorization::*`
- `Verification::*`
- `Preference::*`
- `ActorSupport`
- `Finisher`
- `ActionPolicy::Controller`
- `Oidc::SsoInitiator`
- `set_region`, `set_color_theme`, `set_preferences_cookie`, `resolve_param_context`,
  `canonicalize_query_params`, `reset_flash`, `transparent_refresh_access_token`, `enforce_*`,
  `set_current`, `set_current_observability`, `purge_current`

`Jump::PublicController` does not populate `Current` for the `Actor` facade. Public endpoints under
`jump` do not need current surface or actor state.

## Nesting

`PublicController` lives at the boundary level only. Per-TLD subclasses are not introduced. Public
endpoints for every TLD share the same boundary `PublicController`.

This keeps the class hierarchy shallow at the cost of giving up TLD-specific behavior in the base
class. Public endpoints already produce content that is either TLD-independent (`/health`) or driven
by request host (`/robots.txt`, `/sitemap.xml`), so a shared base is sufficient.

## Rate Limiting

Use the existing `RateLimit` concern, which wraps Rails 8.1's built-in `rate_limit` DSL with a
Redis/Valkey-backed counter. Apply only the default limit (300 req/min/IP via
`check_default_rate_limit`).

The `rack-attack` gem is not adopted. All rate limiting is handled by the Rails-native concern.

A rate limit profile dedicated to public endpoints (for example a higher ceiling tuned for load
balancer probes and crawlers) is out of scope for this ADR. The default profile is accepted as the
starting point and can be revisited if probes or crawlers are throttled in practice.

## CSRF

`protect_from_forgery using: :header_or_legacy_token, with: :exception` is included as
defense-in-depth. Public endpoints respond to `GET` only, so CSRF enforcement is effectively a guard
against an accidentally-added state-changing action.

`trusted_origins:` is not configured at the `PublicController` level. The existing
`<Boundary>::<Tld>::ApplicationController` classes set `trusted_origins` per TLD via
`HostOriginEnv.trusted_origins(...)`, but public endpoints do not accept cross-origin POSTs, so
origin lists are not required.

## Deferred

The following are explicitly deferred and not part of this decision:

- `Cache-Control` / `expires_in` headers on `/robots.txt` and `/sitemap.xml` for CDN caching.
- A dedicated public-endpoint rate limit profile.
- Edge-layer DDoS protection (CDN, WAF, `rack-attack`).
- Legacy `acme/*/edge/v0/healths_controller.rb` and `sign/*/edge/v0/healths_controller.rb` endpoints
  were later retired instead of migrated to `PublicController`.

## Consequences

- Public endpoints stop opting out of auth and preference callbacks via
  `skip_before_action ..., raise: false`. They no longer inherit those callbacks at all.
- New `before_action` lines added to a heavy `ApplicationController` no longer affect public
  endpoints by default.
- The class hierarchy gains three new files (`acme/public_controller.rb`,
  `sign/public_controller.rb`, `jump/public_controller.rb`).
- Public endpoints lose access to TLD-specific helpers and configuration that lived on the heavy
  `ApplicationController`. This is intentional; any helper a public endpoint needs must be obtained
  through an explicit concern include or through the request directly.
- DDoS protection on these endpoints is bounded by the default 300/min/IP limit until a dedicated
  profile or edge-layer policy is added.

## Related

- `adr/three-tier-controller-base.md` — overarching doctrine that places this work as Phase 1 of a
  three-tier base hierarchy (`ApplicationController` / `OpenController` / `PublicController`).
- `adr/actor-current-facade.md` — current request-context facade. `Jump::PublicController`
  deliberately does not populate it.
- `adr/four-engine-restoration-and-base-contract.md` — boundary base class contract.
