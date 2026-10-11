# ADR: Restore Rails Way Engine Architecture with Fat Engines

> **Status update (2026-05-19):** Obsolete. Per `adr/split-into-regional-and-global-repos.md`
> (2026-04-25), both the Rails Engine strategy and the 4-app split strategy are abandoned. This
> repository is now a single ordinary Rails app for the global surface, with regional content split
> to a separate repository. Do not use the Fat Engine target described below for new work; treat
> this document as historical only.

**Status:** Obsolete (accepted 2026-04-22, superseded 2026-04-25)

**Supersedes:**

- `adr/four-app-wrapper-runtime-and-root-retirement.md` (2026-04-18) — the wrapper apps architecture
  is abandoned
- Partially supersedes `adr/engine-isolate-namespace-adoption.md` (2026-04-14) — the "models stay in
  the host app" decision is reversed in favor of Fat Engines

**Destructive migration is explicitly authorized.** The current `apps/*` wrapper app implementation,
`lib/cross_engine_url_helpers.rb`, and related root-app retirement work will be discarded. Prior
partial work on engine directory flattening and controller path flattening must be re-evaluated
against standard Rails Way generator output rather than preserved because it exists.

## Context

The repository has been migrating toward a four-wrapper-app architecture where each Rails engine
gets its own `apps/<name>/` wrapper app that acts as the runtime boot. After operating partially
with this design, several problems became clear:

1. **Not the Rails Way.** The wrapper apps pattern is not documented by Rails and has no established
   community precedent. New contributors cannot rely on standard Rails Guides, tutorials, or
   community resources.

2. **High learning cost.** Understanding the architecture requires reading multiple ADRs, internal
   plans, and the custom `CrossEngineUrlHelpers` module. Standard Rails knowledge alone is not
   sufficient.

3. **Testing is hard.** Running tests requires navigating into each wrapper app. There is no single
   `bin/rails test` entrypoint from the repository root. Fixture handling, shared test helpers, and
   database preparation are duplicated across four wrapper apps.

4. **Custom maintenance burden.** `CrossEngineUrlHelpers` is a fragile custom abstraction that
   re-implements functionality that `isolate_namespace` plus native Rails engine routing proxies
   provide out of the box.

5. **OSS gem ecosystem friction.** Most Rails gems assume a single host app. Integrations with auth
   gems, admin gems, monitoring tooling, and mainstream Rails gems require workarounds under the
   wrapper apps model.

6. **Migration is paused with unresolved failures.** Per `adr/ongoing-engine-migration-state.md`,
   the migration is paused with `UrlGenerationError` in tests and only `apps/identity` has been
   partially validated. Continuing down this path increases technical debt.

## Decision

Return to the standard Rails Way: **a single host Rails app at the repository root that mounts four
mountable engines**, with each engine owning its own models (Fat Engine).

### Target structure

- **Single host Rails app at the repository root.** `config/`, `bin/`, `app/`, `test/` return to the
  repository root as the canonical Rails application.
- **Four mountable engines** generated via `bin/rails plugin new engines/<name> --mountable`.
- **Fat Engine**: models, controllers, views, helpers, services, jobs, mailers, policies, and
  migrations all live in the owning engine.
- **`isolate_namespace`** on every engine: `Jit::Identity`, `Jit::Zenith`, `Jit::Foundation`,
  `Jit::Distributor`.
- **Native Rails engine routing proxies** replace `CrossEngineUrlHelpers`. Cross-engine links use
  `identity.sign_app_root_path`, `foundation.base_app_contacts_url`, etc.
- **Host app mounts all engines** in `config/routes.rb` with host constraints, per the four-engine
  host matrix in `adr/four-engine-restoration-and-base-contract.md`.

### What is discarded

- `apps/identity/`, `apps/zenith/`, `apps/foundation/`, `apps/distributor/` and all wrapper-app
  Rails configuration
- `lib/cross_engine_url_helpers.rb` and `config/initializers/cross_engine_urls.rb`
- Any "root app retirement" work; the root host app is the canonical Rails application

### What is retained

- Four-engine topology from `adr/four-engine-restoration-and-base-contract.md`
- Engine names: Identity, Zenith, Foundation, Distributor
- Internal module names: `sign`, `acme`, `base`, `post`
- Public contract naming (ENV, host labels, route helper prefixes)
- Audience tier definitions including `dev` and `net`

### What is reversed

- `adr/engine-isolate-namespace-adoption.md` said "Models stay in the host app." This is reversed.
  Models move into the owning engine. The original objection (engine-added table name prefixes) is
  handled by explicit `self.table_name = "..."` declarations or by overriding table naming in each
  engine's base record.

### What requires re-evaluation

Existing plans on engine directory flattening and controller path flattening may still have value,
but they must be validated against the output of the standard `bin/rails plugin new --mountable`
generator. Do not preserve prior flattening decisions simply because the work was already done.

## Deployment Model

The Rails Way answer to "deploy each engine independently" is a single host app with conditional
mounts, not multiple host apps.

### Deploy selector ENV: `DEPLOY_ENGINES`

The canonical deploy-selector ENV under this architecture is **`DEPLOY_ENGINES`**. It is a
comma-separated list of engine names. Unset means "mount every engine" (the developer default).

```ruby
# config/routes.rb (sketch)
Rails.application.routes.draw do
  enabled = ENV.fetch("DEPLOY_ENGINES", "identity,zenith,foundation,distributor").split(",")

  if enabled.include?("identity")
    mount Jit::Identity::Engine => "/", as: :identity
  end
  # ... other engines with host constraints
end
```

A production deployment that serves only Identity sets `DEPLOY_ENGINES=identity`. The same codebase
produces four different runtime variants without four wrapper apps.

#### Relationship to the retired `DEPLOY_MODE`

`DEPLOY_MODE` is **not** reintroduced. The old ENV was a single-value selector (`identity`,
`foundation`, etc.) that was deleted during the engine-flattening work under the wrapper-app
direction (see `adr/ongoing-engine-migration-state.md`). `DEPLOY_ENGINES` replaces it with a
multi-value CSV contract so one process can serve any subset of engines. No `DEPLOY_MODE` fallback
is provided; configuration that still sets `DEPLOY_MODE` must be migrated to `DEPLOY_ENGINES`.

The detailed deployment contract (including per-engine ENV selection and host-constraint layering)
is out of scope for this ADR and will be authored in a separate plan.

## Internal Namespace Contract (FQCN)

All engine-owned Ruby code is namespaced under `Jit::<Engine>::*`. This is a consequence of
`isolate_namespace Jit::<Engine>` in each engine definition and is made explicit here so there is no
ambiguity during migration.

| Engine      | FQCN prefix        | Example                                          |
| ----------- | ------------------ | ------------------------------------------------ |
| Identity    | `Jit::Identity`    | `Jit::Identity::Sign::App::SessionsController`   |
| Zenith      | `Jit::Zenith`      | `Jit::Zenith::Acme::App::ApplicationController`  |
| Foundation  | `Jit::Foundation`  | `Jit::Foundation::Base::App::ContactsController` |
| Distributor | `Jit::Distributor` | `Jit::Distributor::Post::App::DocsController`    |

### Rules

- Engine-owned controllers, models, helpers, mailers, jobs, policies, and services live under
  `Jit::<Engine>::*`. Bare top-level constants such as `Core::*`, `Main::*`, `Docs::*` are not
  permitted in engine code.
- The internal module segment (`Sign`, `Acme`, `Base`, `Post`) is retained. It is part of the FQCN,
  not a replacement for the `Jit::<Engine>` prefix.
- Public contracts (route helper prefixes, ENV families, host labels) are unchanged by this section.
  `base_app_*`, `FOUNDATION_BASE_*`, `base.*.localhost` continue to refer to Foundation.
- The temporary "internal namespaces may remain unchanged" allowance granted in
  `adr/four-engine-restoration-and-base-contract.md` (Scope of This Decision) is withdrawn as of
  2026-04-22. There is no transitional window in which bare `Core::*` etc. remain in engine code.
- Host app code (what remains at the repository root under the restored Rails Way architecture) is
  not under `Jit::<Engine>`. It uses the host's own namespaces.

## Consequences

### Positive

- Standard Rails patterns apply; community resources are directly usable.
- `bin/rails server` and `bin/rails test` work from the repository root.
- `CrossEngineUrlHelpers` can be deleted.
- OSS gems integrate naturally.
- Deployment flexibility is preserved through conditional `mount`.
- Engine-level independence is preserved via `isolate_namespace` and per-engine test suites.

### Negative

- Destructive migration. Current partial work (wrapper apps, relocated Rails config under
  `lib/config/`, `CrossEngineUrlHelpers`) is rolled back.
- Previously authored plans must be revised or marked superseded.
- Deployment topology changes from "one wrapper app per deploy unit" to "one Rails app with
  conditional engine mount by ENV."

### Neutral

- The four-engine topology is unchanged.
- The `base_*` / `post_*` / `sign_*` public contracts are unchanged.
- The `dev` and `net` audience tiers are unchanged.

## Migration Authorization

The following destructive changes are explicitly authorized under this ADR:

- Delete `apps/identity/`, `apps/zenith/`, `apps/foundation/`, `apps/distributor/`
- Delete `lib/cross_engine_url_helpers.rb` and `config/initializers/cross_engine_urls.rb`
- Restore `config/`, `bin/`, `app/` at the repository root as the canonical Rails app
- Regenerate engines via `bin/rails plugin new --mountable` where starting fresh is simpler than
  reshaping existing files
- Move models and model tests from the host app into the owning engine

Destructive actions must still be reviewed by a human before merging, but the direction is no longer
in question.

## Detailed Implementation Plan

This ADR decides direction only. The detailed implementation sequence is intentionally deferred and
will be authored in a separate plan under `plans/active/` before execution begins.

Existing plans that presuppose the wrapper apps architecture are marked superseded so that
implementers do not follow conflicting guidance:

Plans that may still apply but require re-evaluation are not marked superseded yet; they will be
reviewed when the detailed implementation plan is drafted.

## Related

- `adr/four-engine-restoration-and-base-contract.md` — four-engine topology (retained)
- `adr/four-engine-split.md` — original engine split (background)
- `adr/four-app-wrapper-runtime-and-root-retirement.md` — superseded by this ADR
- `adr/engine-isolate-namespace-adoption.md` — partially superseded (models move into engines)
- `adr/ongoing-engine-migration-state.md` — state document; to be updated to reflect this decision
