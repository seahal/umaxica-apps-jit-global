# ADR: Adopt isolate_namespace for Rails Engines

> **Status update (2026-04-26):** Obsolete. Per `adr/split-into-regional-and-global-repos.md`
> (2026-04-25), the Rails Engine strategy is abandoned. The codebase is now divided into two
> independent repositories: this **global** repository (a single ordinary Rails app combining IdP
> and RP, served on `id.*` and `www.*`) and a separate **regional** repository (docs / news / help).
> `isolate_namespace`, the `Jit::<Engine>::*` namespacing, and the engine routing proxies described
> below no longer apply. Treat this document as historical only.

**Status:** Accepted (2026-04-14), partially superseded (2026-04-22)

**Supersedes:** The "No isolate_namespace" decision in `adr/four-engine-split.md` (2026-04-09)

**Partially superseded by:** `adr/rails-way-engine-architecture-restoration.md` (2026-04-22) — the
"Models stay in the host app" decision below is reversed in favor of Fat Engines.
`isolate_namespace` itself is retained. `CrossEngineUrlHelpers` is discarded in favor of native
Rails engine routing proxies.

## Context

When the 4-engine split was implemented (2026-04-09), `isolate_namespace` was deliberately skipped
to avoid mass-renaming controllers and test files. Each engine was mounted at `/` with host
constraints, and a custom `CrossEngineUrlHelpers` module handled cross-engine route dispatch.

After operating with this design, the following problems became clear:

1. **CrossEngineUrlHelpers is complex and fragile.** It manually dispatches route helpers to
   per-engine proxy instances because Rails engine `url_helpers` modules conflict when included
   together. This is a workaround for a problem that `isolate_namespace` solves natively.

2. **Engine boundaries are not enforced at the code level.** Without `isolate_namespace`, any engine
   can accidentally reference host app or other engine internals without explicit qualification.
   This undermines the Zenith/Foundation/Distributor boundary goal.

3. **The Rails documentation strongly recommends `isolate_namespace` for mountable engines.**
   Skipping it means losing native routing proxies, namespace collision protection, and
   engine-scoped view resolution.

4. **Model ownership can stay engine-local.** The original concern about `isolate_namespace` adding
   table name prefixes is not a blocker for the accepted four-app target. Model ownership and
   wrapper-app runtime ownership are now governed by
   `adr/four-app-wrapper-runtime-and-root-retirement.md`.

## Decision

Adopt `isolate_namespace` for all four engines:

| Engine      | Namespace          | Module | isolate_namespace target |
| ----------- | ------------------ | ------ | ------------------------ |
| Identity    | `Jit::Identity`    | `sign` | `Jit::Identity`          |
| Zenith      | `Jit::Zenith`      | `acme` | `Jit::Zenith`            |
| Foundation  | `Jit::Foundation`  | `base` | `Jit::Foundation`        |
| Distributor | `Jit::Distributor` | `post` | `Jit::Distributor`       |

### Key design points

- **Model ownership is outside this ADR.** `isolate_namespace` isolates controllers, routes, and
  views. Final model and runtime ownership is defined by
  `adr/four-app-wrapper-runtime-and-root-retirement.md`.
- **Engine routing proxies replace `CrossEngineUrlHelpers`.** Cross-engine links use
  `signature.sign_app_sessions_path`, `foundation.base_app_contacts_path`, etc.
- **`main_app` prefix required for host app routes from within engines.** This makes boundary
  crossings visible in code.
- **Each engine defines its own `ApplicationController` inheriting from `::ApplicationController`.**
  This allows shared concerns to flow from the host while keeping engine controllers namespaced.

### Engine definition example

```ruby
# engines/identity/lib/jit/identity/engine.rb
module Jit
  module Identity
    class Engine < ::Rails::Engine
      isolate_namespace Jit::Identity

      engine_name "identity"
    end
  end
end
```

Physical directory names match canonical engine names. The legacy physical names `signature`,
`world`, `station`, and `press` are retired by a `git mv` rename in the same migration wave that
adopts `isolate_namespace`. Equivalent rename applies to Zenith (`engines/zenith`), Foundation
(`engines/foundation`), and Distributor (`engines/distributor`). Runtime boot then moves into
wrapper apps per `adr/four-app-wrapper-runtime-and-root-retirement.md`.

### Mount example

```ruby
# apps/identity/config/routes.rb
Rails.application.routes.draw do
  mount Jit::Identity::Engine => "/", as: :identity
end
```

## Consequences

### Positive

- **Native routing proxies**: `identity.*_path`, `foundation.*_path` etc. replace custom dispatch
- **Enforced boundaries**: Accidental cross-engine dependencies become visible as `main_app.` calls
- **Standard Rails pattern**: New contributors understand the architecture without learning custom
  helpers
- **`CrossEngineUrlHelpers` can be retired**: Removes a fragile custom abstraction
- **Engine-scoped view resolution**: Each engine's views are isolated within the four-app target

### Negative

- **FQCN changes**: Controller fully-qualified class names gain the engine prefix (e.g.,
  `Jit::Identity::Sign::App::SessionsController`), though internal `module Sign` remains unchanged
- **All cross-engine route references must be updated**: Every call to another engine's routes needs
  the engine proxy prefix
- **Larger rename scope**: This should be combined with the engine rename (#725) to avoid doing the
  work twice

### Migration notes

- Combine this change with the engine rename work (#725) to minimize churn
- Update `CrossEngineUrlHelpers` references to use native engine proxies
- After migration, remove `lib/cross_engine_url_helpers.rb` and
  `config/initializers/cross_engine_urls.rb`

## Related

- `adr/four-engine-split.md` (original decision, partially superseded)
- `adr/four-app-wrapper-runtime-and-root-retirement.md`
- `lib/cross_engine_url_helpers.rb` (to be retired)
- GitHub #725 (parent rename issue)
