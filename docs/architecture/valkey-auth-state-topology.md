# Valkey auth-state topology

Nonprod uses one Valkey service. Responsibility URLs map to logical DBs:

| URL env                | Dev DB | Test DB | Contents                               |
| ---------------------- | ------ | ------- | -------------------------------------- |
| `CACHE_REDIS_URL`      | 0      | 3       | Reconstructible `Rails.cache`          |
| `RATE_LIMIT_REDIS_URL` | 1      | 4       | Rate-limit counters                    |
| `AUTH_STATE_REDIS_URL` | 2      | 5       | Authorization codes + sign-out notices |

Auth-state access goes through `Umaxica::Valkey::Connection` (hiredis) and the
`Valkey::AuthState::*` stores. Keys are digest-based under `auth_state:authorization_code` /
`auth_state:sign_out_notice` namespaces. Tests clean with prefix SCAN/DEL only — never
`FLUSHALL`/`FLUSHDB`.

See `adr/valkey-nonprod-logical-db-topology.md`.
