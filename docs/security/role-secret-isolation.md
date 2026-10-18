# Role Secret Isolation (R5-WU03A)

Status: **Proposed — awaiting S review of the exact role manifest.** No credential file, master key,
database login or launch definition has been changed yet. Scope is local development and test only;
production, CI and external services are out of scope.

Owner specification: `one.md` section 4.1 and R5-WU03A. This page is the current description of
which runtime role may read which secret, and why.

## Why this exists

Today every process boots with one `config/credentials/development.key`, one shared `.env` and one
PostgreSQL login (`POSTGRESQL_PASSWORD`) that reaches every database. An RP process can therefore
decrypt the OP signing keys and open OP, Zenith and sibling RP databases even if its code never
calls them. R5 requires that compromising one RP cell cannot mint OP credentials or read another
surface's state, so each role must hold only its own secrets.

## Mechanism

- **Reader:** Rails 8.2 `Rails.app.creds` (`ActiveSupport::CombinedConfiguration`), which the code
  already uses. Required values use `Rails.app.creds.require(:NAME)`; optional values use `option`
  with an explicit nil branch (`generic/no-silent-fallback.mdc`).
- **Lookup order caveat:** in development `Rails.app.creds` reads ENV, then `.env`, then encrypted
  credentials. Splitting credentials alone is therefore insufficient: secrets must be removed from
  the shared `.env`/ENV that a role process receives, or that role can still read them.
- **Store:** one encrypted credentials file and one key per role, e.g.
  `config/credentials/development/rp-core-app-jp.yml.enc` with `rp-core-app-jp.key`. A process is
  started with exactly one role key (`RAILS_MASTER_KEY` for that role) and the matching
  `config.credentials.content_path`/`key_path`, selected from a trusted startup role name.
- **Role selection:** the startup configuration names one role from a fixed allowlist before any
  credential or connection is loaded. Request input (Host, `ri`, token claims) never selects a role.
- **OS boundary:** credentials split is necessary but not sufficient. Each role process must not be
  able to read other roles' `.key` files, the shared `.env` or container-control sockets; this is
  enforced by per-role container mounts/UIDs, not by code.
- **Database logins:** one non-superuser PostgreSQL login per role with CONNECT and table grants on
  its own databases only (no CREATEDB/CREATEROLE/BYPASSRLS). The current shared login stays only for
  maintenance tasks, never for a role process.

## Proposed role manifest

Names follow `one.md` section 5.1. "Public" values (issuer URLs, public JWKS) are configuration, not
secrets, and may be shared.

| Role                                                                                                                                                                    | Secrets it may hold                                                                                                                                                                                   | Databases it may log in to                                                                                 |
| ----------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------- |
| `op-base-app`, `op-base-com`, `op-base-org`                                                                                                                             | That realm's `AUTH_JWT_PRIVATE_KEYSET`; OP cookie/session `SECRET_KEY_BASE`; that realm's OTP verifier / history / Active Record encryption keys used by OP rows; RP client **public** assertion keys | `op_base_<realm>` (+ replica), required read/write on `<realm>_zenith` through the identity authority path |
| `auth-app`, `auth-com`, `auth-org`                                                                                                                                      | Credential-ceremony secrets: OmniAuth/Apple/Entra/Google, `SOCIAL_AUTH_CEREMONY_HMAC_KEY`, email/telephone HMAC and OTP keys, Turnstile, SES sending                                                  | Those ceremony stores currently owned by Auth (to be enumerated from R5-WU01 manifest)                     |
| `rp-<client>` (12 JP cells: `base-app-ww`, `base-com-ww`, `base-org-ww`, `edit-org-ww`, `tech-org-ww`, `core-{app,com,org}-jp`, `warp-{app,com,org}-jp`, `palm-app-jp`) | That cell's client assertion private key (`<CELL>_PRIVATE_KEY`); that cell's cookie/session `SECRET_KEY_BASE`                                                                                         | `rp_<family>_<realm>` local store only                                                                     |
| Domain authorities (`publishing`, `avatar`, org IAM/Support/Enforcement)                                                                                                | Their own protocol secrets (e.g. `ENFORCEMENT_*_IDENTIFIER_HMAC_KEY` for Enforcement)                                                                                                                 | Their canonical stores only                                                                                |
| `maintenance` (not a runtime role)                                                                                                                                      | Shared admin login for migrations/rebuilds                                                                                                                                                            | All, invoked manually only                                                                                 |

Never held by any RP role: OP signing keys, another cell's private key, OP/Zenith/sibling DB logins,
or a universal master key. Observability UIs (Flipper, Blazer, PgHero, Coverband, Swagger, Rails
Performance) are operator tools; their passwords stay out of every RP role.

## Open points for S review

1. Exact credential key names per role (current names above are reused where the code already reads
   them; new names follow `<CELL>_PRIVATE_KEY`).
2. Which existing Active Record encryption / HMAC keys each role needs; this depends on the R5-WU01
   model ownership manifest and is not guessed here.
3. Solid Queue: per-role schema and login, as required by R5-WU03A, after confirming the installed
   version supports a per-role connection.
4. Development launcher — **decided by the user on 2026-10-17: do not split containers.** All roles
   keep running in the existing single development container. Consequence: the R5-WU03A
   mount/process-visibility boundary is not provided, so `AT-R5-03A` cannot claim full effective
   isolation in development; it must record this as a known gap. Within the container, the remaining
   achievable boundary is per-role credentials files and per-role database logins (and, if adopted
   later, per-role Linux users owning each role key with mode `0400`).

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

Not closed: every role runs as the same Linux user in the single development container, so a role
process can still read another role's key file and decrypt its bundle. This is the accepted
container-split gap above.

## Activation (R5-WU19)

- OP side: `op_client_activations` per realm OP store, written only by `OpClientActivationWriter`
  (exact client, current contract epoch, actor, audit reference, source-manifest digest). An
  `op-base-*` process refuses `/oauth/authorize` and `/oauth/token` with `unauthorized_client` for a
  client without an enabled row at the current epoch. The `shared` role does not consult it.
- RP side: every `rp-*` process requires `UMAXICA_RP_BROWSER_ADMISSION` (`open` or `closed`, no
  default). While `closed` the cell serves only its back-channel logout receiver and health, so
  durable revocation still lands.
