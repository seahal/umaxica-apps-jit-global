# ADR: Split Application into 4 Rails Engines

> **Status update (2026-04-26):** Obsolete. Per `adr/split-into-regional-and-global-repos.md`
> (2026-04-25), the Rails Engine strategy is abandoned outright. The codebase is now divided into
> two independent repositories: this **global** repository (a single ordinary Rails app combining
> IdP and RP, served on `id.*` and `www.*`) and a separate **regional** repository (docs / news /
> help). The 4-engine split (`signature` / `world` / `station` / `press` and later Identity / Zenith
> / Foundation / Distributor), the `engines/` directory, `DEPLOY_MODE`, and `CrossEngineUrlHelpers`
> are all retired. Treat this document as historical only.

**Status:** Implemented (2026-04-09), partially superseded (2026-04-14)

**Supersedes:** GitHub #553 (2-way Global/Local split)

**Partially superseded by:** `adr/engine-isolate-namespace-adoption.md` (the "No isolate_namespace"
decision and engine names are revised)

## Context

The application was previously planned to be split into 2 deployment units (Global and Local). This
decision revises that approach to split into 4 engines driven by network topology and security
requirements.

## Decision

We will split the application into 4 Rails Engines:

### Engine Overview

| Engine         | Host Pattern          | Purpose                                      | Network                    |
| -------------- | --------------------- | -------------------------------------------- | -------------------------- |
| **Signature**  | sign.{app,com,org}.\* | Authentication, passkeys, OIDC, social login | Public, permanent URLs     |
| **Zenith**     | www.{app,com,org}.\*  | Global BFF, dashboard, settings              | Public, flexible evolution |
| **Foundation** | base.{app,com,org}.\* | Regional operations, contacts, staff admin   | Regional per-region deploy |
| **Publisher**  | post.{app,com,org}.\* | Content delivery                             | Closed (Cloudflare VPN)    |

> **Note (2026-04-14):** Engine names were updated from signature/world/station/press to
> Signature/Zenith/Foundation/Publisher. Module names were updated: `core` to `base`, `docs` to
> `post`.

### Architecture Diagram

```
                       ┌─────────────────────────────────┐
                       │         Public Internet          │
                       └──────┬──────────┬───────────────┘
                              │          │
                  ┌───────────▼──┐  ┌────▼────────────┐
                  │  signature   │  │     world        │
                  │ sign.{t}.*   │  │  {t}.*           │
                  │ Auth/Passkey │  │  Global BFF      │
                  │ Permanent URL│  │  Next.js backend │
                  └──────────────┘  └─────────────────┘

                  ┌──────────────┐  ┌─────────────────┐
                  │   station    │  │     press        │
                  │ www.{t}.*    │  │ docs/news/help.* │
                  │ Regional ops │  │ Closed network   │
                  │ Contacts/Mgmt│  │ CF VPN tunnel    │
                  └──────────────┘  └─────────────────┘

                  {t} = {app, com, org}
```

### Design Principles

1. **Thin Engines**: Engines own routes, controllers, and views only. Models and database
   configuration stay in the main app, shared by all engines.

2. ~~**No isolate_namespace**~~: **Superseded (2026-04-14).** `isolate_namespace` will be adopted
   for all engines. See `adr/engine-isolate-namespace-adoption.md` for rationale.

3. **Shared Concerns**: Cross-cutting concerns (authentication, authorization, rate limiting) stay
   in `app/controllers/concerns/`. Sign-specific concerns (29 files) move with the signature engine.

4. **DEPLOY_MODE**: Changed from 2 modes (global, local) to 4 modes (signature, world, station,
   press) plus development (loads all).

## Consequences

### Positive

- **URL Stability**: Authentication endpoints have permanent URLs that will never change
- **Security Isolation**: Content delivery runs on a closed network via Cloudflare VPN
- **Independent Evolution**: Each engine can evolve independently without affecting others
- **Regional Deployment**: Station engine can be deployed per-region

### Negative

- **Complexity**: More deployment units to manage
- **Cross-Engine References**: Named route helpers pointing to other domains need URL configuration
- **Testing**: Need to ensure engines work both in isolation and together

## Implementation

All phases completed as of 2026-04-09:

| Phase        | Scope                                                                     | Issue | Status |
| ------------ | ------------------------------------------------------------------------- | ----- | ------ |
| 1. Scaffold  | 4 engine skeletons, DEPLOY_MODE, Gemfile, routes                          | #667  | Done   |
| 2. Press     | 42 controllers, 39 views extracted to `engines/press/`                    | #671  | Done   |
| 3. World     | 39 controllers, 31 views extracted to `engines/world/`                    | #669  | Done   |
| 4. Station   | 54 controllers, 22 views extracted to `engines/station/`                  | #670  | Done   |
| 5. Signature | 163 controllers, 29 concerns, 175 views extracted to `engines/signature/` | #668  | Done   |

### Cross-Engine URL Resolution

After extraction, a `CrossEngineUrlHelpers` module was introduced
(`lib/cross_engine_url_helpers.rb`) to resolve route helpers across engine boundaries. Each engine
has a separate proxy instance because Rails engine `url_helpers` modules conflict when included
together (each defines `_routes`; the last included wins). The module dispatches helper calls to the
correct proxy based on route name prefix and auto-injects the host from ENV variables for `_url`
variants.

### Remaining Work

- **Engine rename (#725)**: Engines are renamed (World to Zenith, Station to Foundation, Press to
  Publisher). Modules `core` to `base`, `docs` to `post`. The `sign-to-visa` rename was cancelled;
  `sign` module name is retained.
- **isolate_namespace adoption**: All engines will adopt `isolate_namespace`. Combined with the
  rename to avoid double churn. See `adr/engine-isolate-namespace-adoption.md`.
- **CrossEngineUrlHelpers retirement**: After `isolate_namespace` is adopted, the custom helper
  module will be replaced by native Rails engine routing proxies.

## Related Issues

- Phase 1 (scaffold): #667
- Extract signature: #668
- Extract world: #669
- Extract station: #670
- Extract press: #671
- Supersedes: #553

## References

- `engines/signature/`
- `engines/world/`
- `engines/station/`
- `engines/press/`
- `lib/cross_engine_url_helpers.rb`
- `config/initializers/cross_engine_urls.rb`
