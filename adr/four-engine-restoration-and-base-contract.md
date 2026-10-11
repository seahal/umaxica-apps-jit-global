# ADR: Restore Four-Engine Topology and Normalize Foundation Public Contract to `base`

> **Status update (2026-04-26):** Obsolete. Per `adr/split-into-regional-and-global-repos.md`
> (2026-04-25), both the Rails Engine strategy and the 4-app split strategy have been abandoned. The
> codebase is now divided into two independent repositories: this **global** repository (a single
> ordinary Rails app combining IdP and RP, served on `id.*` and `www.*`) and a separate **regional**
> repository (docs / news / help). The four-engine topology, the `base.*`/`post.*` host matrix, and
> the `FOUNDATION_BASE_*` ENV family described below no longer apply to this repository. Treat this
> document as historical only.

**Status:** Accepted (2026-04-17)

**Supersedes:** `adr/three-engine-consolidation.md` (2026-04-16)

## Context

The repository currently contains extracted code for four engines:

- `signature`
- `world`
- `station`
- `press`

An accepted ADR then redirected the target architecture to three engines by merging `station` and
`press` into a single Foundation-like engine. That decision does not match the current direction
anymore.

We now want to keep the four-way split and finalize the Foundation public contract around the `base`
host label. The remaining legacy names `main` and `core` are migration leftovers and should not
remain part of the public interface.

## Decision

We will keep a four-engine topology and normalize all Foundation public routing contracts to `base`.

Runtime ownership is handled separately by `adr/four-app-wrapper-runtime-and-root-retirement.md`.
That ADR also records root-app retirement, wrapper apps, controller path flattening, and the Zenith
surface rename to `acme`.

### Audience Tier Definitions

The platform uses five audience tiers. These tiers describe who or what a surface is for. They are
independent from engine boundaries and host labels.

| Tier  | Purpose                                                               |
| ----- | --------------------------------------------------------------------- |
| `app` | Public end-user audience                                              |
| `org` | Operator and administrative audience for the service                  |
| `com` | Corporate and public-information audience                             |
| `dev` | Developer and operational tooling audience                            |
| `net` | Private internal-service audience for inter-service API communication |

#### Semantics

- `app` is the general user-facing audience.
- `org` is the operator-facing audience used for administration and service operations.
- `com` is the corporate-facing audience used for public company information and corporate entry
  points.
- `dev` is the human operational audience used for Rails administration, developer tools,
  maintenance surfaces, and internal operational workflows.
- `net` is the non-public machine audience used for internal API communication between services.

#### Boundary Rules

- `app`, `org`, and `com` are human-facing audiences.
- `dev` is human-facing, but restricted to development and operations use.
- `net` is not a public-facing audience.
- `net` is intended for service-to-service communication, not for general browser-facing UI.
- `net` surfaces should default to API-first design and should not assume direct public access.

#### Design Implications

- `dev` should be used for operational dashboards, Rails management surfaces, maintenance tools, and
  internal developer workflows.
- `net` should be used for private APIs, internal callbacks, service integration endpoints, and
  future microservice communication paths.
- Public documentation, help, and corporate entry points should not rely on `net`.
- Authentication, authorization, logging, and network controls for `net` must still be explicitly
  enforced even when the surface is non-public.

### Engine Roles

| Engine          | Role                   |
| --------------- | ---------------------- |
| **Identity**    | Authentication / IDP   |
| **Zenith**      | Shared shell / summary |
| **Foundation**  | Business operations    |
| **Distributor** | API/content delivery   |

### Engine Host Matrix

All five audience tiers are available to every engine. Host ownership is defined by engine and host
label, while audience semantics remain consistent across the platform.

| Engine          | `app`        | `org`        | `com`        | `dev`        | `net`        |
| --------------- | ------------ | ------------ | ------------ | ------------ | ------------ |
| **Identity**    | `sign.app.*` | `sign.org.*` | `sign.com.*` | `sign.dev.*` | `sign.net.*` |
| **Zenith**      | `app.*`      | `org.*`      | `com.*`      | `dev.*`      | `net.*`      |
| **Foundation**  | `base.app.*` | `base.org.*` | `base.com.*` | `base.dev.*` | `base.net.*` |
| **Distributor** | `post.app.*` | `post.org.*` | `post.com.*` | `post.dev.*` | `post.net.*` |

### Foundation Naming Contract

The Foundation engine public contract is fixed as follows:

| Surface item    | Canonical name                      | Deprecated / removal target                        |
| --------------- | ----------------------------------- | -------------------------------------------------- |
| Host label      | `base`                              | `main`, `core`, `ww`                               |
| ENV family      | `FOUNDATION_BASE_*`                 | `MAIN_*`, `CORE_*`, `BASE_*`                       |
| Route helper    | `base_*`                            | `main_*`                                           |
| Trusted-origins | `FOUNDATION_BASE_*_TRUSTED_ORIGINS` | `CORE_*_TRUSTED_ORIGINS`, `BASE_*_TRUSTED_ORIGINS` |

Examples:

- `base.app.localhost`
- `FOUNDATION_BASE_APP_URL`
- `FOUNDATION_BASE_ORG_TRUSTED_ORIGINS`
- `base_app_root_url`

### Scope of This Decision

This decision applies to the public contract only:

- route host constraints
- environment variable names
- trusted-origin variable names
- named route helpers
- generated URLs and link targets
- documentation and tests

Internal Ruby namespaces may remain unchanged temporarily if needed to reduce migration risk. For
example, `Core::App::ApplicationController` may continue to exist during the transition even while
the public route helper becomes `base_app_*`.

> **Update (2026-04-22):** The temporary internal-namespace allowance above is withdrawn by
> `adr/rails-way-engine-architecture-restoration.md`. Under the restored Rails Way architecture, all
> engine-owned Ruby code is namespaced under `Jit::<Engine>::*` (for example,
> `Jit::Foundation::Base::App::ApplicationController`). There is no longer a transitional window in
> which bare `Core::*` / `Main::*` / `Docs::*` constants remain in engine code. See the Internal
> Namespace Contract section of that ADR.

## Consequences

### Positive

- Public naming becomes consistent across hosts, ENV, and helper APIs.
- Foundation routing is easier to reason about because one label has one meaning.
- Legacy `MAIN_*` / `CORE_*` fallback logic can be removed instead of maintained indefinitely.
- The four-engine split matches the current extracted repository layout.

### Negative

- A broad rename is required across routes, tests, views, helpers, and configuration.
- Any pending three-engine planning material must be retired or rewritten.
- Temporary mismatch may remain between public naming (`base`) and internal namespaces (`core`)
  until the namespace cleanup is handled separately.

## Migration Rules

1. Treat `FOUNDATION_BASE_*` as the only valid Foundation ENV contract.
2. Treat `FOUNDATION_BASE_*_TRUSTED_ORIGINS` as the only valid Foundation trusted-origins contract.
3. Remove fallback reads of `MAIN_*`, `CORE_*`, and transitional `BASE_*` names instead of extending
   them.
4. Rename Foundation named route helpers from `main_*` to `base_*`.
5. Leave Rails engine proxy `main_app.*` unchanged. It is a Rails host-app routing primitive, not a
   Foundation helper prefix.
6. Keep internal controller namespace changes out of scope unless they are required for correctness.
7. Physical directory names must match canonical engine names end-to-end (2026-04-18 decision).
   - Valid physical paths after Phase 2: `engines/identity`, `engines/zenith`, `engines/foundation`,
     `engines/distributor`.
   - Legacy physical names `signature`, `world`, `station`, and `press` are retired by a `git mv`
     rename inside Phase 2. No parallel-name period is retained.
   - Ruby namespaces align with canonical names: `Jit::Identity`, `Jit::Zenith`, `Jit::Foundation`,
     `Jit::Distributor`.
   - Gemspec package names align with canonical names: `jit-identity`, `jit-zenith`,
     `jit-foundation`, `jit-distributor`.
   - Deploy modes align with canonical names: `identity`, `zenith`, `foundation`, `distributor`.
8. Adopt `isolate_namespace` in every engine (2026-04-18 decision, aligned with
   `adr/engine-isolate-namespace-adoption.md`). The prior "No isolate_namespace" stance in
   `adr/four-engine-split.md` is superseded.
9. Zenith surface naming is `acme`, not `acme`, while the engine name remains `Jit::Zenith`.
10. Runtime boot belongs to wrapper apps, not to the root app, per
    `adr/four-app-wrapper-runtime-and-root-retirement.md`.

## Related

- `adr/four-engine-split.md`
- `adr/three-engine-consolidation.md`
- `adr/four-app-wrapper-runtime-and-root-retirement.md`
