# ADR: Default No-Store Policy for Global and Publishing Controllers

- Status: accepted
- Date: 2026-10-01
- Approval source: the user's default no-store cache policy migration specification.

## Context

Whether a response may be stored by a browser, proxy, or CDN was decided action by action. Some
actions set `private, no-store` by writing the `Cache-Control` header, some used a local
`before_action :no_store`, some relied on `AuthenticationBase#apply_authenticated_page_cache_policy!`,
and the rest fell through to the Rails default (`max-age=0, private, must-revalidate`, or the Rack
`ETag` default), which still lets the browser HTTP cache and the back/forward cache keep the page.
Whether a response that carries credential, session, or other private state was protected depended
on each implementer, reviewer, and QA pass noticing it.

Human review is no longer treated as the safety boundary for cacheability. A forgotten directive on
a response that carries private state is a disclosure defect that review is not reliably placed to
catch, while a forgotten directive on a cacheable public response only costs performance.
Cacheability is a performance optimization, so the safe value is the default and caching is the
explicit exception.

The policy applies to the controller families this repository owns as Global or Publishing
authority (`adr/global-regional-database-ownership.md`, `adr/publishing-db-content-authority.md`,
`docs/architecture/regional-content.md`). Core, Palm, and Warp (the former Side) are classified as
Regional boundaries whose credential and BFF halves happen to be served here, and they have their
own runtime and cache requirements. They are outside this default.

## Decision

```text
Global / Publishing policy roots:
  default = Cache-Control: no-store

Cacheable action:
  explicit opt-in inside the action that owns the representation

Regional / Core / Palm / Warp:
  outside this default policy
```

### Unit of application

The policy is declared on the **policy-root controller**: each surface-local `ApplicationController`
or `BareController` that inherits directly from `ActionController::Base` and so owns an independent
callback hierarchy, plus `Auth::RedirectOnlyController`, which is the Auth-owned root of the
redirect-only controllers under the repository-wide `ApplicationController`, and each
`ActionController::API` controller in a Global or Publishing namespace, which owns its own callback
chain. The repository-wide
`ApplicationController` is not a policy root: mounted engines (Blazer, Mission Control) and
`UnknownHostsController` inherit it, and no surface owns them. A host or FQDN is a test subject, not
the unit of ownership. The current inventory lives in `docs/reference/http-cache-policy.md`.

A policy root declares the policy once, explicitly:

```ruby
include ::DefaultNoStore

prepend_before_action :apply_default_no_store
```

Subclasses inherit it and never re-declare it. A Publishing controller inherits the policy from the
root it already descends from (`Edit::Org::ApplicationController` for management, the surface-local
`BareController` for public content delivery).

### Why `prepend_before_action`

Requests can end before the action runs: the FQDN availability gate, rate limiting, authentication
redirects, restricted-session gates, and other callbacks render or redirect early. Prepending puts
the cache prohibition ahead of every one of them, so early-terminated controller responses carry
`no-store` too.

`apply_default_no_store` therefore runs ahead of the FQDN availability gate. The gate's invariant
("nothing runs ahead of the availability switch") exists so that a switched-off surface spends no
rate-limit budget and touches no session or action. `apply_default_no_store` only replaces the
in-memory cache-control directives of the response being built; it reads no request input and has
no other effect, so placing it first does not weaken that invariant. The gate stays the first
callback after it.

A subclass that prepends its own callback and then calls `ensure_fqdn_gate_first!` must then
re-prepend `apply_default_no_store`, so the order stays no-store, gate, subclass callback. This is a
reordering of the inherited callback, not a second policy declaration. The same holds when an
included concern does the prepending (`OidcRpLogoutLauncher`). At migration time this applied to
the Auth preference, sign-in check, sign-in session, and OIDC handoff controllers and to
`Edit::Org::Sign::OutsController`.

`after_action` is not used. An after-callback would overwrite the explicit opt-in an action made, and
would not run for responses halted earlier in the chain.

### Explicit cache opt-in

Rails' conditional and freshness APIs are the only way an action opts in:

```text
fresh_when
stale?
expires_in
expires_now
http_cache_forever
```

In Rails 8.2, `fresh_when` (and therefore `stale?`) and `expires_in` (and therefore
`http_cache_forever`) remove the `no_store` directive before applying their own; `expires_now`
replaces the directives with `no-cache`. The opt-in is therefore visible in the action that owns the
representation.

### Prohibitions

- Do not `skip_before_action :apply_default_no_store`. Caching is enabled by an action owning an
  explicit cache policy, not by removing the default.
- New code does not opt into caching by writing `response.headers["Cache-Control"]`,
  `response.set_header("Cache-Control", ...)`, or `response.cache_control[...]`. A directly written
  cacheable header is overridden by the default `no_store` when the response is committed.
- `DefaultNoStore` registers no callbacks: no `included do`, `ActiveSupport.on_load`, `class_eval`,
  `ApplicationController.include(...)`, or `respond_to?`-based capability detection.

### Scope limits

- Existing protocol-specific `no-store` contracts (health, revision, token, credential, OIDC, DBSC,
  secret-credential pages, `Pragma: no-cache`) are kept as they are. Applying the same directive
  twice is harmless and is not refactored by this decision.
- Static and fingerprinted assets served by Propshaft or Vite are outside controller policy.
- When a policy root moves to Regional ownership, the change that moves it removes `DefaultNoStore`
  from that root and defines the Regional cache contract at the same time. An expected future move
  alone does not exclude a root today.
- The future Xper Experience API (`/api/v0/experience`) is expected to opt into a browser-private
  revalidation contract (`private, no-cache` with a weak `ETag`) through `fresh_when` or `stale?`.
  The default does not forbid that; this decision does not implement it.

## Consequences

- An action that makes no cache decision answers `Cache-Control: no-store` on every in-scope
  surface, including responses halted by callbacks.
- Existing explicit caching keeps working: Publishing entries (`expires_in` + `stale?`), the JWKS
  document (`expires_in`), Base dashboard avatar images (`stale?`). The sitemap concern, which wrote
  a cacheable header directly, is converted to `expires_in` so its CDN contract survives.
- Responses that previously fell through to the framework default become `no-store`. This includes
  `robots.txt`, the Xper sitemap and robots placeholders, landing pages, and controller-rendered
  error pages. Any of them that later needs caching opts in from its action. The PWA service worker
  routes are served by the framework's `Rails::PwaController`, which is not under a policy root.
- `test/security/invariants/default_no_store_policy_invariant_test.rb` fails when a policy root loses the
  declaration, when the callback is not first, when a subclass skips it, or when an excluded
  Regional root acquires it. It does not assert that excluded roots never send `no-store`.
- Standalone `ActionController::API` endpoints in Global and Publishing namespaces (the Base OAuth
  token endpoint, Apple server notifications, the Edit OIDC back-channel logout receiver) declare
  the policy themselves and keep their existing protocol headers such as `Pragma: no-cache`.
