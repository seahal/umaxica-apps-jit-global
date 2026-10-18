# Runtime role provisioning and database isolation probe (R5-WU03A / R5-WU17)

- Commit: 17903f7d121aa33efe29f2db9235c9aa5db4b001; worktree has the uncommitted R4/R5 changes,
  including `lib/tasks/runtime_roles.rake` and `lib/runtime_role.rb`, which are the subject of this
  record.
- Date: 2026-10-17T13:08:55Z
- Scope: local development PostgreSQL only (single development container, per user decision).

## Provisioning

The user ran `bin/rails runtime_roles:provision` twice.

1. The first run created the `op-base-app` bundle and login, then aborted:
   `NoMethodError: undefined method 'postgresql_connection' for class ActiveRecord::Base` (removed
   in Rails 8). The task was fixed to build `ActiveRecord::ConnectionAdapters::PostgreSQLAdapter`
   directly and always disconnect it.
2. The second run printed `provisioned <role> -> <login> (<databases>)` for all 21 non-shared roles
   (3 OP, 3 Auth, 12 RP cells, 3 domain).

Per-role bundles and keys are in `config/credentials/development/`; `git check-ignore` confirms the
`*.key` files are ignored. The encrypted `*.yml.enc` files are untracked and not committed.

## Isolation probe (read-only connects as each role login)

| Role login     | Database                             | Result  |
| -------------- | ------------------------------------ | ------- |
| rp-core-app-jp | rp_core_app                          | CONNECT |
| rp-core-app-jp | rp_core_com, op_base_app, app_zenith | refused |
| rp-base-org-ww | rp_base_org                          | CONNECT |
| rp-base-org-ww | org_zenith                           | refused |
| op-base-app    | op_base_app                          | CONNECT |
| op-base-app    | rp_core_app                          | refused |
| domain-avatar  | avatar                               | CONNECT |
| domain-avatar  | op_base_app                          | refused |

Rails reports these refusals as `Database not found`. A raw `PG.connect` as
`umaxica_role_rp_core_app_jp` to `development_op_base_app_db` (which exists in `pg_database`)
returns `User does not have CONNECT privilege.`, so the refusal is the grant, not a missing
database.

## Role process boot

`UMAXICA_RUNTIME_ROLE=rp-palm-app-jp UMAXICA_RP_CONTRACT_EPOCH=1 bin/rails runner ...` booted with
the role's own credentials bundle and database login, printed `role=rp-palm-app-jp`, read its own
store (`RpPalmAppPrincipal.count` = 0), and was refused for `OpAppGrant.count` and `Client.count`
(`ActiveRecord::NoDatabaseError`, the CONNECT refusal above).

## Role HTTP server (Palm cell)

Two fixes were needed before an `rp-*` server could answer: the development pending-migration page
check connected to every database (now only under `shared`), and Flipper preloads flags from
`primary` (provisioning now grants CONNECT on `primary` plus SELECT on `flipper_features` and
`flipper_gates` only). The user reran provisioning; every line ended `; flags read-only`.

`UMAXICA_RUNTIME_ROLE=rp-palm-app-jp UMAXICA_RP_CONTRACT_EPOCH=1 bin/rails server -p 3911` with
`Host: palm-jp.umaxica.app` / `X-Forwarded-Proto: https`:

| Request                                                         | Result                                      |
| --------------------------------------------------------------- | ------------------------------------------- |
| GET /dashboard (flag `fqdn_available_palm_service` absent)      | 503 (FQDN gate closed, flag read succeeded) |
| GET /dashboard after enabling that flag in the development DB   | 401 (no credentials)                        |
| GET /sign                                                       | 200                                         |
| GET /dashboard with forged `rp-access` and unknown `rp-session` | 401                                         |
| GET /identity/birthdate with the Base host                      | 404, empty body (role route guard)          |
| POST /oauth/token with the Base host                            | 404, empty body (role route guard)          |

## Not covered

- No cross-process Code Flow ran: the cell calls the OP at its public issuer URL, and reaching a
  separate local OP process needs the development ingress (Jump/Edge), which is outside the
  authorized scope. The in-process equivalent is covered by
  `test/integration/rp_cell_local_session_readiness_test.rb` (12/12).
- The single development container provides no mount or process-visibility boundary (documented gap
  in docs/security/role-secret-isolation.md).
- Solid Queue is still one shared `queue` database granted to every role.
