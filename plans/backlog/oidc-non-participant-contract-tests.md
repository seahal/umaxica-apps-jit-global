# OIDC/OAuth Non-Participant Contract Tests

Status: proposed backlog. Nothing here is implemented.

## Context

`adr/oidc-oauth-participation-allowlist-and-non-participant-surfaces.md` requires structural
regression guards for repository-owned Non-Participant surfaces. The current state those guards
would protect is described in `docs/architecture/oidc-non-participant-surfaces.md`. Today only the
participating side is tested.

## Prerequisites to decide first

1. **Make the allowlist complete.** `AuthBoundaryAuthorityMap` lists browser RP clients only, while
   the static client store also registers `app-ios-rp` and `app-android-rp`. Either add the approved
   native clients to the map, or name the second source that admits them. Until then a test of
   "registry contains only allowlisted clients" has no complete allowlist to compare against.
2. **Decide the fate of `core-next-rp`.** It is deprecated in the map and still registered. A
   registry guard must either admit it explicitly as a bounded compatibility registration or wait
   for its removal. It must not pass by being ignored.

## Guards to add

Each guard inspects public route, controller, or registry relationships. None reaches into private
methods.

1. The active client registry contains only clients admitted by the allowlist, with deprecated
   compatibility clients named explicitly rather than exempted wholesale.
2. Repository-owned Non-Participant route sets expose no RP `/sign` entrypoint, no `/oidc/callback`,
   and no Base `/oauth/*` authority endpoint. Auth's `/sign` ceremony namespace needs its own
   expectation, since Auth is a Non-Participant that legitimately owns that path.
3. Repository-owned Non-Participant controller stacks do not include or inherit the concerns that
   establish an authenticated actor. `Base::Dev::ApplicationController` and
   `Base::Net::ApplicationController` dropped `ActorSupport` on 2026-10-05; the guard should pin
   that neither regains it.
4. Repository-owned Non-Participant surfaces do not read or write `__Host-oidc_rp_*` cookies, and
   only Auth touches `__Host-auth_*`.
5. `.dev` route surfaces stay Non-Participants when a parent controller or mounted engine changes.
   Mission Control inherits the root `::ApplicationController`, so that class must stay free of
   authentication concerns. Several diagnostic engines are development-group gems that are not
   loaded in the test environment; the guard for those hosts has to work without the engine
   constant, or the limitation is recorded on the test.
6. Info, Docs, News, Help, and Guid stay out of the client registry and keep their bare route and
   controller contracts.
7. A newly added repository-owned surface is a Non-Participant by default. The guard should fail
   closed: a route set or controller tree that is neither allowlisted nor listed as a known
   Non-Participant fails until it is classified.

## Out of scope

Externally owned hosts such as Jump, the asset host, and the status host get no placeholder tests
here. Their owning repository or deployment enforces the classification.
