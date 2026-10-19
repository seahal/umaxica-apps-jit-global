# Role Secret Isolation (R5-WU03A)

Status: development and test use **one Rails-standard credentials set and one database login for
every role** (user decision 2026-10-19, `adr/runtime-secret-isolation-deferred.md` amendment). This
page describes what a runtime role still controls and what it does not.

Per-role secret isolation for deployed environments remains deferred to the pod and secret-store
design in `plans/backlog/2026-10-18-production-runtime-secret-isolation.md`.

## What a runtime role does not control

- **Credentials.** Every process reads `config/credentials/<env>.yml.enc` with `<env>.key`. There
  are no per-role bundles, and every process shares one `SECRET_KEY_BASE`: cookies and
  `secret_key_base`-derived digests must verify across hosts and processes.
- **Database login.** Development and test connect with the fixed Dev Container login written in
  `config/database.yml`; there is no per-role PostgreSQL login and no PostgreSQL-grant boundary
  between roles.
- **Operating-system boundary.** All roles run in the single development container (user decision
  2026-10-17).

Consequently an RP role process in development can read every secret in the environment's
credentials. `AT-R5-03A` cannot pass in development or test; that is intended.

## What a runtime role controls

`UMAXICA_RUNTIME_ROLE` names one role from the fixed allowlist in `lib/runtime_role.rb`, read once
at boot and never from request input. It selects the controllers the process serves (below), the
private signing keys it requires and keeps in its environment, and the OP/RP code paths.

## Route ownership and cell authentication (R5-WU17)

A role process serves only the controllers `RuntimeRole.route_owner` assigns to it. The table lives
in `lib/runtime_role.rb`; `lib/runtime_role_route_guard.rb` (prepended to `ActionController::Base`
and `ActionController::API`) answers `404` with no body and no cookie before any controller callback
runs. An unclassified controller raises `RuntimeRole::UnownedRoute` and is refused, so a new route
needs an explicit owner. The `shared` role serves every controller.

- Base identity, credential, Step-Up verification, withdrawal, recovery, selector, welcome and OP
  protocol paths belong to the realm OP role (`op-base-<realm>`) on the shared public host. They
  read the canonical actor, which only the OP may read (user decision 2026-10-17).
- Base Self-RP entry, callback, Refresh, logout receivers and relay pages belong to
  `rp-base-<realm>-ww`; owner APIs belong to their domain or OP role.
- An `rp-*` process authenticates only from its own cell: the Access JWT verified against the OP
  JWKS plus the opaque `rp-session` cookie naming a live local session bound to the token's
  `sid`/`sub`/epoch (`RpCellLocalSession`, `RpRequestAuthenticator`). Callback and Refresh write the
  cell store (`RpCallbackCommitter`, `RpRefreshCommitter`). Base cells read the selected
  account/organization from the OP (`GET /api/v0/identity/selection`).
- Required in every `rp-*` process: `UMAXICA_RP_CONTRACT_EPOCH`, the release epoch the cell was
  deployed for (read with one-argument `ENV.fetch`). The `shared` and OP roles do not read it.

Core session API (`GET /api/v0/session`) in a cell process: the actor is the local principal, so
`actor.id` is the cell principal's public ID and `display_name` falls back to it. This external
contract change was approved by the user on 2026-10-17.

## Private keys held by an RP cell process (R5-WU18A finding)

The development keyset installer exports every local signing key into the process environment. In an
`rp-*` process it now removes every private key except `RuntimeRole.rp_private_env_names`: the
cell's own private_key_jwt client key, its surface's Jump RT key and the preference keyset. The JWT
registry requires private keys only for those records in that process; all public keysets still
load. Probe on 2026-10-17 (`rp-palm-app-jp`): 39 `*_PRIVATE_KEY*` variables before, 3 after.

Not a secret boundary: every role reads the same credentials file, so the key removal limits what a
cell process _uses_, not what it could decrypt.

## Activation (R5-WU19)

- OP side: `op_client_activations` per realm OP store, written only by `OpClientActivationWriter`
  (exact client, current contract epoch, actor, audit reference, source-manifest digest). An
  `op-base-*` process refuses `/oauth/authorize` and `/oauth/token` with `unauthorized_client` for a
  client without an enabled row at the current epoch. The `shared` role does not consult it.
- RP side: every `rp-*` process requires `UMAXICA_RP_BROWSER_ADMISSION` (`open` or `closed`, no
  default). While `closed` the cell serves only its back-channel logout receiver and health, so
  durable revocation still lands.
