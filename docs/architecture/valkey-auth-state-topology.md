# Valkey auth-state topology

Nonprod Compose exposes two canonical Valkey processes plus one compatibility
instance. Development and test share each process; isolation is by logical DB
and (in test) Rails namespaces, not extra Compose services.

| Service        | Role                                                                                         | Host publication     | Dev Container DNS |
| -------------- | -------------------------------------------------------------------------------------------- | -------------------- | ----------------- |
| `valkey-cache` | Reconstructible `Rails.cache` in development. `allkeys-lru`. Test uses MemoryStore.          | `127.0.0.1:6380`     | `valkey-cache`    |
| `valkey-kvs`   | Rate-limit and auth-state. `noeviction`.                                                     | `127.0.0.1:6381`     | `valkey-kvs`      |
| `valkey`       | Compatibility + diagnostics (`performance`, `coverband` in `config/valkey.yml`).             | `127.0.0.1:6379`     | `valkey`          |

Compose owns those endpoints (`VALKEY_CACHE_HOST` / `VALKEY_KVS_HOST` and
their ports). Responsibility → logical DB mapping lives in Rails
`config/valkey.yml`.

Do not move rails_performance or Coverband onto cache or KVS. Their
`KEYS`-shaped scans stay on the compatibility instance.

Auth-state access goes through `Umaxica::Valkey::Connection` (hiredis) and the
`Valkey::AuthState::*` stores. Keys are digest-based under `auth_state:authorization_code` /
`auth_state:sign_out_notice` namespaces. Tests clean with prefix SCAN/DEL only — never
`FLUSHALL`/`FLUSHDB`.

See `adr/valkey-nonprod-logical-db-topology.md`.
