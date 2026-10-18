# ADR: Use Wrapper Apps For Runtime And Fully Retire The Root App

> **Status update (2026-04-26):** Obsolete. Per `adr/split-into-regional-and-global-repos.md`
> (2026-04-25), both the Rails Engine strategy and the 4-app split strategy have been abandoned. The
> codebase is now divided into two independent repositories: this **global** repository (a single
> ordinary Rails app combining IdP and RP, served on `id.*` and `www.*`) and a separate **regional**
> repository (docs / news / help). The wrapper-app architecture (`apps/identity`, `apps/zenith`,
> `apps/foundation`, `apps/distributor`) described below is permanently retired. Treat this document
> as historical only.

**Status:** Superseded (2026-04-22) by `adr/rails-way-engine-architecture-restoration.md`

**Original status:** Accepted (2026-04-18)

**Supersedes:** host-app-centered assumptions in `adr/engine-isolate-namespace-adoption.md`

> **Superseded notice (2026-04-22):** The wrapper apps architecture described in this ADR has been
> abandoned. The project returns to the Rails Way: a single host Rails app at the repository root
> that mounts four mountable engines (Fat Engine pattern). See
> `adr/rails-way-engine-architecture-restoration.md` for the current direction. This document is
> kept for historical traceability only; do not follow it for implementation.

## Context

The repository already has extracted engines, but runtime ownership is still mixed between engines
and the root app. That shape is confusing for contributors because ownership is ambiguous.

The target is closer to four near-independent Rails apps in one repository than to one permanent
root app that happens to mount engines.

## Decision

We will use one wrapper Rails app per engine and fully retire the current root app.

Ownership is fixed as:

- `engine = domain code`
- `wrapper app = runtime boot`
- `lib = shared engine-neutral code only`

Wrapper apps:

- `apps/identity`
- `apps/zenith`
- `apps/foundation`
- `apps/distributor`

Each wrapper app owns:

- `config/application.rb`
- `config/environment.rb`
- `config/routes.rb`
- `config/importmap.rb`
- `config/initializers/*`

Each engine owns:

- models
- DB-facing logic
- domain services
- engine-specific concerns
- helpers
- views
- assets
- locale files
- engine tests

The root app is migration-only and will be deleted.

## Additional Decisions

### Shared code

Shared code is restricted to `lib/`.

Put code in `lib/` only if it is:

- engine-neutral
- persistence-neutral
- route-neutral
- runtime-neutral or shared boot support

### Controller path flattening

Flatten redundant engine path nesting.

Target example:

- from `engines/foundation/app/controllers/jit/foundation/base/org/contacts_controller.rb`
- to `engines/foundation/app/controllers/base/org/contacts_controller.rb`

### Zenith surface naming

Zenith keeps:

- engine name `Jit::Zenith`
- mount alias `:zenith`

Zenith changes:

- `acme` -> `acme`

No compatibility alias for `acme` is retained.

## Consequences

### Positive

- ownership is easier for contributors to understand
- runtime boot follows standard Rails app structure
- engines become closer to independent Rails app boundaries
- the root app stops accumulating domain behavior

### Negative

- migration scope increases because root-owned runtime files must move or be deleted
- wrapper apps add more Rails app shells to maintain
- controller, view, helper, and test path changes become broader

## Migration Rules

1. Do not add new domain code to the root app.
2. Do not add new runtime ownership to the root app.
3. Every remaining root file must have one destination: move to engine move to wrapper app move to
   `lib/` delete during retirement
4. Remove `DEPLOY_MODE` after wrapper apps become the runtime entrypoints.
5. Use wrapper apps, not the root app, as the final `bin/rails s` target.

## Related
