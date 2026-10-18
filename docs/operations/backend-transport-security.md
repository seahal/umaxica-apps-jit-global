# Backend transport security

The Rails production configuration fails closed unless security-sensitive backend connections use
authenticated encrypted transport.

## Required production values

| Backend | Variables | Required value |
| --- | --- | --- |
| PostgreSQL writer | `NEON_PGSSLMODE` | `verify-full` |
| PostgreSQL readers | `NEON_REPLICA_PGSSLMODE` | `verify-full` |
| Valkey cache | `CACHE_REDIS_URL` | `rediss://` scheme |
| Valkey rate limit | `RATE_LIMIT_REDIS_URL` | `rediss://` scheme |
| Valkey auth state | `AUTH_STATE_REDIS_URL` | `rediss://` scheme |

`RAILS_ENV=production` is the relevant application configuration for staging as well as
production. The application rejects `disable`, `allow`, `prefer`, or other PostgreSQL modes that do
not provide full certificate and hostname verification. It also rejects `redis://` for production
Valkey URLs.

Development and test retain their existing local `redis://` topology. No local TLS certificate
authority is introduced by this contract.

## Deployment verification

Application boot validation does not establish that a live provider has the expected certificate
chain. Before enabling a deployment, operators must verify without recording secrets:

1. the four production PostgreSQL/Valkey configuration values have the required scheme or mode;
2. the provider supports certificate and hostname verification;
3. the application runtime has the provider's trusted CA material where required; and
4. writer, reader, cache, rate-limit, and auth-state connections complete a TLS handshake.

Record only pass/fail, environment, date, and the relevant variable name in evidence. Never record
connection URLs containing credentials, certificates, private keys, or raw service responses.

See `adr/backend-transport-tls-enforcement.md` for the architectural decision and its limits.
