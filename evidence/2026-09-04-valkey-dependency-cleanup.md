# Valkey / Redis dependency cleanup

Date: 2026-09-04
Worktree: branch `feature`, base commit `7408a4009` (`[CheckPoint] ......`).
Pre-existing unrelated modifications were present in `Gemfile.lock`, `pnpm-workspace.yaml`,
and five test files; they were left untouched.

## Question

Does the repository's Redis / Valkey configuration match the runtime dependency the
application actually has?

## Searches performed

Repository-wide `grep` (excluding `.git`, `node_modules`) for `VALKEY_URL`,
`REDIS_NORMAL_URL`, `RATE_LIMIT_REDIS_URL`, `REDIS_CLIENT`, `REDIS_SMOKE_TEST`,
`REDIS_FAIL_FAST`, `Redis.new`, `RedisCacheStore`, `redis://`, `rediss://`, `Valkey`,
`Redis`, plus targeted `grep` over `app/`, `lib/`, `config/`, `test/` for `Memorize`,
`RedisMemorize`, `REDIS_RACK_ATTACK_URL`, `REDIS_SESSION_URL`.

## Consumers found before the cleanup

| Reference | Classification |
| --- | --- |
| `config.x.rate_limit.store` in `config/environments/{development,production}.rb` | live application dependency (`ActiveSupport::Cache::RedisCacheStore`, `ENV.fetch("RATE_LIMIT_REDIS_URL")`) |
| `config/initializers/redis.rb` → `REDIS_CLIENT`, `REDIS_NORMAL_URL`, `REDIS_SMOKE_TEST`, `REDIS_FAIL_FAST` | dead configuration — the constant's only use was its own `ping` smoke test |
| `VALKEY_URL` in `compose.yaml` and `.github/workflows/ci.yml` | dead configuration — no consumer in `app/`, `lib/`, `config/`, or `test/` |
| `test/initializers/redis_test.rb` | test support for the dead generic client only |
| `REDIS_SMOKE_TEST=0` in `test/config/host_authorization_contract_test.rb` (2 sites) | test support for the dead smoke test |
| `REDIS_CLIENT` stub and forbidden-token list in `test/integration/health_endpoints_test.rb` | test support for the dead constant; health probes never touched Redis |
| Redis comments in `test/services/sign/risk/engine_test.rb` | stale — `SignRiskEngine` scores from `ClientOccurrence` / `OperatorOccurrence` / `VisitorOccurrence` in PostgreSQL |
| `rescue Redis::BaseError` in `app/controllers/concerns/external_authentication_endpoint.rb` (2 sites) and `lib/omniauth/strategies/umaxica_entra.rb` | stale-looking but behaviourally live — see "Not changed" |
| `OpenTelemetry::Instrumentation::Redis` in `config/initializers/opentelemetry.rb` | live — instruments the rate-limit store's `redis` gem calls |
| `Valkey` in `docs/operations/*`, `adr/traces-and-metrics-routing-via-alloy.md`, `adr/public-controller-base.md`, `docs/security/credential-abuse-rate-limits.md`, `docs/architecture/dpop.md`, `docs/security/refresh-token-rotation.md` | documentation, already accurate |
| `docs/dds.md`, `docs/hld.md`, `docs/srs.md`, `README.md` | documentation, inaccurate (claimed sessions, `Memorize`, Rack cache, `REDIS_RACK_ATTACK_URL`, `REDIS_SESSION_URL`) |
| `plans/**`, `memos/**`, `notes/**`, `adr/audit-findings-2026-03-30.md` | stale historical material, intentionally retained |

## Removed

- `config/initializers/redis.rb` (whole file: `REDIS_CLIENT`, `NullRedisClient`,
  `REDIS_NORMAL_URL`, `REDIS_SMOKE_TEST`, `REDIS_FAIL_FAST`, the boot-time `PING`).
- `test/initializers/redis_test.rb` (whole file — covered only the removed client).
- `compose.yaml`: `VALKEY_URL` and `REDIS_NORMAL_URL` from the `core` service.
- `test/config/host_authorization_contract_test.rb`: both `REDIS_SMOKE_TEST` entries.
- `test/integration/health_endpoints_test.rb`: the `REDIS_CLIENT` `ping` stub in
  "liveness remains dependency free" and `Redis`/`REDIS_CLIENT` from the forbidden-token list.
- Stale comments: `config/initializers/flipper.rb` and `config/initializers/opentelemetry.rb`
  (both pointed at the deleted initializer), `test/services/sign/risk/engine_test.rb`,
  `app/services/sign_risk_emitter.rb`.
- Documentation claims of Valkey-backed sessions, `Memorize`, `RedisMemorize`, Rack cache,
  and the non-existent `REDIS_RACK_ATTACK_URL` / `REDIS_SESSION_URL`, in `docs/dds.md`,
  `docs/hld.md`, `docs/srs.md`, `README.md`.

The `redis` gem stays in the `Gemfile`: `ActiveSupport::Cache::RedisCacheStore` requires it.

## Remaining live Valkey consumer

One, unchanged in behaviour:

    config.x.rate_limit.store =
      ActiveSupport::Cache::RedisCacheStore.new(
        url: ENV.fetch("RATE_LIMIT_REDIS_URL"),
        namespace: ["rate_limit", Rails.env, ENV["RATE_LIMIT_NAMESPACE_SUFFIX"].presence].compact.join(":"),
      )

Development and production both use the one-argument `ENV.fetch`, so a missing URL fails at
boot. Test keeps `ActiveSupport::Cache::MemoryStore`. Compose keeps the local `valkey`
service and `RATE_LIMIT_REDIS_URL: "redis://valkey:6379/1"`; database 1 was kept rather than
renumbered to 0, to avoid churning existing development volumes.

## Not changed, deliberately

- `rescue Redis::BaseError` in `ExternalAuthenticationEndpoint` and the Entra strategy.
  Flipper is PostgreSQL-backed (`config/initializers/flipper.rb`), so this rescue cannot fire
  in production today, but it is a fail-closed availability gate covered by a behavioural test
  (`test/controllers/concerns/external_authentication_endpoint_test.rb:104`). Narrowing it to
  `ActiveRecord::ActiveRecordError` is a behaviour change to an authentication gate and is out
  of scope here. Recorded as follow-up.
- `plans/docker-core-env-compose-async-harp.md` still names `VALKEY_URL` and
  `REDIS_NORMAL_URL`; it is a record of a completed migration and describes the state at the
  time. Left historical.
- `adr/audit-findings-2026-03-30.md` line 308 references the old emitter FIXME. Dated audit
  record, left historical.

## Blocked

`.github/workflows/ci.yml` could not be edited: `.github`, `bin`, and `.devcontainer` are
mounted read-only in this environment (`mount` reports `ro` for all three). The intended
change, verified by reading the file but not applied, is to drop `VALKEY_URL` and the `valkey`
service from both the `test-rails` and `coverage` jobs while keeping
`RATE_LIMIT_REDIS_URL`. `RATE_LIMIT_REDIS_URL` must stay set even though nothing connects to
it: `test/config/host_authorization_contract_test.rb` boots a `RAILS_ENV=development`
subprocess whose one-argument `ENV.fetch` would otherwise fail at boot. Nothing in the suite
opens a Valkey connection — the test environment uses `MemoryStore`, and the development
subprocess only exercises `ActionDispatch::HostAuthorization` against a stub Rack endpoint,
never constructing a request that reaches the lazily-connected store.

## Commands executed and results

| Command | Result |
| --- | --- |
| `bin/rails test test/controllers/concerns/rate_limit_test.rb test/controllers/base/oauth_token_rate_limit_test.rb` | 13 runs, 5094 assertions, 0 failures, 0 errors, 0 skips |
| `bin/rails test test/config/host_authorization_contract_test.rb test/integration/health_endpoints_test.rb test/services/sign/risk/engine_test.rb` | 36 runs, 2169 assertions, 1 failure, 0 errors, 0 skips |
| `bin/rails test test/tooling/ test/unit/security/forbidden_rails_patterns_test.rb test/initializers/` | 78 runs, 494 assertions, 0 failures, 0 errors, 0 skips |

The single failure is
`HostAuthorizationContractTest#test_development_compose_aliases_only_private_origins_and_configured_public_site_hosts`
(`jp.umaxica.dev` is aliased to `core` in `compose.yaml` but named by no `PUBLIC_*_URL`).
Confirmed pre-existing and unrelated: `git stash push compose.yaml` and re-running
`bin/rails test test/config/host_authorization_contract_test.rb:125` reproduced the same
failure against the unmodified `compose.yaml`.

## Resulting contract

Valkey is a non-authoritative, disposable distributed store used by Rails for rate-limit
counters. `RATE_LIMIT_REDIS_URL` is the application-facing configuration contract.

| Property | Value |
| --- | --- |
| Purpose | distributed rate-limit counters |
| Authority | none |
| Durable application state | none |

Sessions are cookie-backed, the Rails cache is Solid Cache (PostgreSQL) in production and
`:null_store` in development and test, Active Job is Solid Queue (PostgreSQL), Flipper flags
are PostgreSQL-backed, token and refresh-token state is PostgreSQL-backed, and sign risk
events are PostgreSQL-backed. A second Valkey use case requires an ADR.

## Follow-up

1. Apply the `.github/workflows/ci.yml` change above once the path is writable.
2. Decide whether the `Redis::BaseError` rescues around Flipper reads should become
   `ActiveRecord::ActiveRecordError`, and update the covering test with them.
3. Upstash staging integration remains a separate task. No Upstash code, `@upstash/*`
   dependency, REST access, or hard-coded hostname was added; the store speaks plain RESP and
   accepts a `rediss://` URL through `RATE_LIMIT_REDIS_URL` unchanged.
