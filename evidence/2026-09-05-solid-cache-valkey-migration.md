# Solid Cache removal and Valkey cache / rate-limit separation

Date: 2026-09-05 Worktree: `umaxica-apps-global`, based on `0c2544695` (`[CHECKPOINT] ...`), with
the pre-existing uncommitted changes to `compose.yaml`,
`docs/operations/cloudflare-private-origin.md` and `test/config/host_authorization_contract_test.rb`
preserved.

Scope: Rails repository only. The Edge repository was not inspected or modified.

## Objective

Remove Solid Cache from the runtime architecture, move reconstructible application cache to Valkey,
and split Valkey into two explicitly separated responsibilities (application cache, rate-limit
counters) while leaving Solid Queue PostgreSQL-backed and unchanged.

## Live `Rails.cache` consumers found and classified

Every `Rails.cache` reference under `app/`, `lib/` and `config/` was enumerated. Six are
reconstructible cache; two are not.

| Consumer                                                                            | Key                                        | Purpose                                                          | Reconstructed from         | TTL                              | Stale fallback  | Loss safe? |
| ----------------------------------------------------------------------------------- | ------------------------------------------ | ---------------------------------------------------------------- | -------------------------- | -------------------------------- | --------------- | ---------- |
| `lib/external_authentication_infrastructure_omniauth_google_oidc_enforcement.rb:91` | `external_authentication/google_oidc/jwks` | Google OIDC JWKS                                                 | Google JWKS endpoint       | `1.hour`                         | no              | yes        |
| `app/lib/external_sign_in/entra_jwks_cache.rb:27`                                   | per-tenant Entra JWKS key                  | Entra ID JWKS                                                    | Entra tenant JWKS endpoint | `1.hour`                         | no              | yes        |
| `app/adapters/external_authentication/apple_notification_jwks_cache.rb:22`          | Apple notification JWKS key                | Apple server-notification JWKS                                   | Apple JWKS endpoint        | `1.hour`                         | no              | yes        |
| `app/values/jump_rt_return_verifier.rb:112`                                         | fresh JWKS key                             | Jump RT JWKS                                                     | Jump RT JWKS endpoint      | `5.minutes`                      | yes             | yes        |
| `app/values/jump_rt_return_verifier.rb:113`                                         | stale JWKS key                             | Jump RT resilience copy, read only when the upstream fetch fails | same endpoint              | `1.hour`                         | is the fallback | yes        |
| `app/values/jump_rt_return_verifier.rb:96`                                          | negative cache key per `kid`               | Suppress refetch storms for an unknown `kid`                     | n/a (absence is the value) | `30.seconds`                     | no              | yes        |
| `app/values/oidc_client_assertion_jwt.rb:101`                                       | consumed JTI                               | **Replay prevention**, not cache                                 | not reconstructible        | `exp - now + leeway` (<= ~5 min) | no              | **no**     |
| `app/services/identity_one_time_reveal.rb:57`                                       | one-time reveal payload                    | **Single-consume encrypted secret**, not cache                   | not reconstructible        | `15.minutes`                     | no              | **no**     |

The prompt's candidate list was verified rather than assumed; it was complete for the JWKS group and
did not include the two non-cache consumers, which the audit surfaced.

### TTL policy observed

Every live cache write already carried an explicit TTL; no indefinite writes existed and none were
introduced. The Jump RT fresh (`5.minutes`) / stale (`1.hour`) split is intentional: the stale copy
exists only to survive a temporary Jump RT JWKS outage and is deliberately longer-lived than the
fresh entry. The unknown-`kid` negative cache is deliberately short (`30.seconds`) because its only
job is to damp refetch storms, not to make a decision durable.

## State deliberately left in PostgreSQL

Not migrated to Valkey, because losing any of it changes correctness or security: authorization
codes, refresh-token families and reuse detection, DPoP replay protection, OTP and ceremony state,
credential mutation idempotency, durable feature flags, risk and audit records, accounts /
identities / authorities, and Solid Queue. None of these ran through `Rails.cache`, so none moved.

## Follow-up completed: two non-cache consumers returned to PostgreSQL

`OidcClientAssertionJwt` consumed-JTI records and `IdentityOneTimeReveal` payloads were on
`Rails.cache` (Solid Cache) before this work. They are not reconstructible: losing a JTI reopens a
replay window, and losing a reveal drops a secret the user is mid-flow to consume.

They now live in the app-ticket PostgreSQL database:

- `SecurityConsumedJti` (`purpose: oidc_client_assertion`) is the runtime replay store for
  `OidcClientAssertionJwt`. Tests may still inject a `MemoryStore`. Duplicate consume is
  `RecordNotUnique` → false.
- `SecurityOneTimeReveal` is a one-shot table (`jti_digest` unique, `consumed_at`, `expires_at`).
  `IdentityOneTimeReveal` issues and consumes through that model, not `Rails.cache`.

`db/app_tickets_migrate/20260905000000_create_security_one_time_reveals.rb` created the table;
`bin/rails db:schema:dump:app_ticket` wrote it into `db/app_ticket_structure.sql`. Development
`AppTicketRecord.lease_connection.table_exists?(:security_one_time_reveals)` is true.

`OidcClientAssertionJwt` still rescues a store outage and logs
`oidc.client_assertion.replay_store_unavailable`; validation still fails closed when that write
cannot complete.

## Solid Cache components removed

- `gem "solid_cache"` from `Gemfile`; the spec, `DEPENDENCIES` entry and `CHECKSUMS` line from
  `Gemfile.lock`. No other gem depended on it.
- `config/cache.yml`
- `db/caches_migrate/` (4 migrations, including `20260312100000_create_solid_cache_entries`)
- `db/cache_structure.sql`
- `config.cache_store = :solid_cache_store` and
  `config.solid_cache.connects_to = { shards: { cache: { writing: :cache } } }` in
  `config/environments/production.rb`
- The `SolidCache.configuration.connects_to` assertion in
  `test/integration/solid_infrastructure_test.rb`, replaced with assertions that Solid Cache is
  absent, that no `cache` / `cache_replica` connection is configured, and that `queue` still is
- The now-dead `solid_cache_` SQL allowlist branch in
  `test/security/invariants/read_only_route_write_invariant_test.rb`

## PostgreSQL cache databases removed

From `config/database.yml`:

- development `cache` -> `development_cache_db` (host `POSTGRESQL_CACHE_PUB`)
- test `cache` -> `test_cache_db`
- production `cache` -> `production_cache_db` (host `NEON_PGHOST`)

`cache_replica` did not exist in this repository. Also removed: `POSTGRESQL_CACHE_PUB` /
`POSTGRESQL_CACHE_SUB` from `compose.yaml` and from both `.github/workflows/ci.yml` job env blocks,
and the `db/caches_migrate` row from `docs/architecture/model-database-inventory.md`. No unused
cache database was retained for compatibility. No unrelated database was touched.

## Development Compose changes

`compose.yaml` now runs two Valkey services instead of one, replacing logical-DB separation with
physical separation:

- `valkey-cache` (`global-devcontainer-valkey-cache`, volume `valkey-cache-volume`)
- `valkey-rate-limit` (`global-devcontainer-valkey-rate-limit`, volume `valkey-rate-limit-volume`)

Both keep the previous service's `restart: on-failure:5`, capped json-file logging, and
`valkey-cli ping` healthcheck, and `core` now depends on both being healthy. Neither publishes a
host port.

Environment contracts:

```
CACHE_REDIS_URL:      redis://valkey-cache:6379/0
RATE_LIMIT_REDIS_URL: redis://valkey-rate-limit:6379/0
```

Removed as dead configuration with no verified live consumer: `VALKEY_URL`, `REDIS_NORMAL_URL`,
`REDIS_CLIENT`, `REDIS_SMOKE_TEST`, `REDIS_FAIL_FAST`, together with `config/initializers/redis.rb`
and `test/initializers/redis_test.rb`. `REDIS_CLIENT` had zero references under `app/` and `lib/`;
its only effect was a boot-time ping. Two test sites that referenced it were cleaned up rather than
left dangling: the `defined?(REDIS_CLIENT)` branch in `test/integration/health_endpoints_test.rb`,
which is dead once the constant is gone and is replaced by a comment recording that liveness now has
no Redis-shaped dependency to stub; and a block of stale speculative comments in
`test/services/sign/risk/engine_test.rb` claiming the risk engine reads from `REDIS_CLIENT`, which
it does not. The stale `REDIS_SMOKE_TEST` key was dropped from
`test/config/host_authorization_contract_test.rb`. No generic Redis abstraction was introduced to
replace them.

## Application configuration

`config/environments/development.rb` and `config/environments/production.rb` both use:

```ruby
config.cache_store = :redis_cache_store, {
  url: ENV.fetch("CACHE_REDIS_URL"),
  namespace: ["cache", Rails.env, ENV["CACHE_NAMESPACE_SUFFIX"].presence].compact.join(":"),
}
```

and keep the pre-existing separate rate-limit store on `ENV.fetch("RATE_LIMIT_REDIS_URL")` with
namespace `rate_limit:<env>[:suffix]`. Development no longer uses `:null_store`, so the real cache
path is exercised locally. Both URLs are one-argument `ENV.fetch`, so missing configuration fails at
boot rather than falling back silently. The `CACHE_NAMESPACE_SUFFIX` hook mirrors the existing
`RATE_LIMIT_NAMESPACE_SUFFIX` convention.

No provider-specific code was added: the application accepts `redis://` and `rediss://` only, and
contains no Upstash SDK, REST client, or endpoint handling.

## Test store policy

`config/environments/test.rb`:

```ruby
config.cache_store = :null_store
config.x.rate_limit.store = TestSupport::SwappableCacheStore.new(ActiveSupport::Cache::NullStore.new)
```

The rate-limit default changed from a shared `MemoryStore` to `NullStore`, so ordinary controller
and request tests accumulate no counters and cannot receive an unrelated test's 429.

`test/support/swappable_cache_store.rb` (new) is a `SimpleDelegator` around the configured store. It
exists because `rate_limit ..., store: rate_limit_store` in a controller class body captures the
store object once at class-load time; reassigning `config.x.rate_limit[:store]` would not reach
those captures, so the swap has to mutate the object they already hold.

`test/test_helper.rb`:

- the per-test `setup` now calls `reset!` instead of `clear`, so a test that raised before its
  ensure ran cannot leave a `MemoryStore` installed for the next test
- `rate_limit_counters!` — class macro installing a fresh `MemoryStore` per test
- `with_rate_limit_counters` / `with_application_cache` — block forms that restore the previous
  store in `ensure`

45 test files that assert `too_many_requests` or reach the rate-limit store directly declare
`rate_limit_counters!`, so their counter, threshold, 429, bucket-independence, window-expiry and
key/namespace assertions run against a deterministic retaining store exactly as before. Rate-limit
coverage was not weakened and no rate-limit assertion was deleted or relaxed.

Cache-behaviour tests already opted into their own deterministic store and were left as they were:
`test/services/jump_rt/return_verifier_test.rb` and
`test/integration/jump_rt_return_verification_test.rb` swap `Rails.cache` for a `MemoryStore` in
setup and restore it in teardown, and
`test/adapters/external_authentication/apple_notification_jwks_cache_test.rb` uses
`Rails.stub(:cache, MemoryStore.new)`. Between them they cover hit, miss/refetch, expiry, stale
fallback, `kid_not_found` invalidation and negative-cache expiry.

CI no longer depends on an external Redis/Valkey service: the `valkey` service block and the
`VALKEY_URL` / `RATE_LIMIT_REDIS_URL` env entries were removed from both Rails jobs in
`.github/workflows/ci.yml`.

## Solid Queue: verified unchanged

`config.active_job.queue_adapter = :solid_queue` and
`config.solid_queue.connects_to = { database: { writing: :queue } }` are untouched in
`config/environments/production.rb`. `gem "solid_queue"` remains in `Gemfile` and `Gemfile.lock`.
The `queue` connection remains in all three environments of `config/database.yml`,
`db/queues_migrate/` and `db/queue_structure.sql` are intact, and `POSTGRESQL_QUEUE_PUB` /
`POSTGRESQL_QUEUE_SUB` remain in Compose and CI. `test/integration/solid_infrastructure_test.rb` now
asserts positively that a `queue` connection is still configured.

## Commands executed and observed results

All Rails commands ran inside the `global-devcontainer-core` container against the Compose stack
(`primary`, `replica`, `valkey-cache`, `valkey-rate-limit`).

### Upstash logical-database support

Probed directly over TLS against the staging endpoint (`amazed-tapir-124974.upstash.io:6379`) with a
hand-rolled RESP client:

```
AUTH      -> +OK
PING      -> +PONG
SELECT 1  -> -ERR Only 0th database is supported! Selected DB: 1
SELECT 2  -> -ERR Only 0th database is supported! Selected DB: 2
```

This is why the architecture does not use logical DB indexes as the isolation boundary.

### Compose and Valkey isolation

```
podman-compose -f compose.yaml config                               -> exit 0
podman-compose -f compose.yaml build core                           -> exit 0
podman-compose -f compose.yaml up -d valkey-cache valkey-rate-limit -> both healthy
podman exec global-devcontainer-valkey-cache      valkey-cli ping   -> PONG
podman exec global-devcontainer-valkey-rate-limit valkey-cli ping   -> PONG
```

Isolation, using representative keys written directly:

```
KEYS * on valkey-cache      -> cache:development:jwks/google        (only)
KEYS * on valkey-rate-limit -> rate_limit:development:ip/127.0.0.1  (only)
FLUSHALL on valkey-cache      -> cache DBSIZE 0, rate-limit DBSIZE 1, counter TTL still 59
FLUSHALL on valkey-rate-limit -> rate-limit DBSIZE 0
```

### End-to-end through a booted Rails process

`bin/rails runner` in development, after clearing both stores:

```
Rails.env                                   -> development
Rails.cache.class                           -> ActiveSupport::Cache::RedisCacheStore
Rails.cache.write("migration_probe", "v", expires_in: 60); Rails.cache.read(...) -> "v"
Rails.configuration.x.rate_limit[:store]    -> ActiveSupport::Cache::RedisCacheStore
  .increment("probe_ip", 1, expires_in: 60)
Rails.application.config.active_job.queue_adapter -> :solid_queue

KEYS * on valkey-cache      -> cache:development:migration_probe    (only)
KEYS * on valkey-rate-limit -> rate_limit:development:probe_ip      (only)
```

The cache write landed only in `valkey-cache` and the rate-limit counter only in
`valkey-rate-limit`, with the expected environment-qualified namespaces, and both on DB 0.

### Bundler and databases

```
bundle install                     -> resolved cleanly against the edited Gemfile.lock
bin/rails db:prepare               -> succeeded (development boot; exercises CACHE_REDIS_URL)
RAILS_ENV=test bin/rails db:prepare -> exit 0
```

Both ran against the reduced inventory with no `cache` database. Development boot is itself a check
on the new `ENV.fetch("CACHE_REDIS_URL")` cache store, since a missing value raises at boot.

### Focused tests

```
bin/rails test test/integration/solid_infrastructure_test.rb \
  test/services/jump_rt/return_verifier_test.rb \
  test/integration/jump_rt_return_verification_test.rb \
  test/adapters/external_authentication/apple_notification_jwks_cache_test.rb \
  test/lib/external_sign_in/google_oidc_enforcement_jwks_test.rb
-> 52 runs, 147 assertions, 0 failures, 0 errors, 0 skips
```

```
bin/rails test test/controllers/concerns/rate_limit_test.rb \
  test/integration/base_endpoint_rate_limit_test.rb \
  test/integration/auth_endpoint_burst_rate_limit_test.rb \
  test/controllers/auth/authentication_rate_limit_test.rb \
  test/controllers/base/oauth_token_rate_limit_test.rb \
  test/controllers/surface_default_web_rate_limit_test.rb \
  test/controllers/concerns/default_web_rate_limit_test.rb \
  test/controllers/auth/otp_ceremony_rate_limit_answers_test.rb
-> 82 runs, 5927 assertions, 0 failures, 0 errors, 0 skips
```

```
bin/rails test test/integration/solid_queue_test.rb test/jobs
-> 67 runs, 181 assertions, 0 failures, 0 errors, 0 skips
```

```
bin/rails test test/unit/database_password_config_test.rb test/tooling/evidence_layout_test.rb \
  test/integration/solid_infrastructure_test.rb test/tooling/compose_restart_policy_test.rb
-> 16 runs, 151 assertions, 0 failures, 0 errors, 0 skips
```

### Full suite

```
bin/rails test
-> 12341 runs, 71261 assertions, 2 failures, 1 errors, 1 skips
```

The three remaining problems are pre-existing in this worktree and unrelated to this work. All three
concern `publishing`, which this change does not touch (`git status` shows no modified file under
`app/models/concerns/publishing/` or `app/operations/publishing/`):

- `Security::Invariants::FlatRubySourceLayoutInvariantTest#test_target_application_ruby_roots_do_not_contain_nested_ruby_files`
  and `#test_concern_files_define_matching_flat_constants` — 11 nested files under
  `app/models/concerns/publishing/`
- `PromoteRevisionRaceVerificationTest#test_the_idempotency_index_is_the_only_uniqueness_failure_treated_as_a_lost_race`
  — `NameError: uninitialized constant Publishing::PromoteRevisionOperation::IDEMPOTENCY_INDEX`

An earlier full run also showed
`Publishing::MoveTaxonomySubtreeOperationTest#test_rejects_a_cross-vocabulary_or_cross-locale_move`
failing on one seed and passing on another; it is seed-dependent and likewise unrelated.

### Issues this change introduced and fixed before the final run

The first full run surfaced five failures caused by this work, all now fixed and green:

1. `FlatRubySourceLayoutInvariantTest` rejected `lib/testing/swappable_cache_store.rb`: `lib/` must
   stay flat. The file moved to `test/support/swappable_cache_store.rb` (its proper home — it is
   test-only) and the module was renamed `Testing` -> `TestSupport`.
2. `ComposeRestartPolicyTest` x3 fetched the `valkey` service by name. Updated to `valkey-cache` and
   `valkey-rate-limit` in both the recovering-services list and the datastore healthcheck list, so
   the restart-policy, log-cap and healthcheck invariants now cover both new services.
3. `DatabasePasswordConfigTest` asserted 21 production `NEON_PGHOST` / `NEON_PGUSER` /
   `NEON_PGPASSWORD` occurrences; removing the `cache` connection makes it 20. Updated with a
   comment naming the reason, and the neighbouring "do not define read replicas" test extended to
   assert the `cache` connection itself is gone.
4. `BaseOauthTokenRateLimitTest` asserted `assert_instance_of MemoryStore, rate_limit_store` as a
   guard against silently testing against a non-retaining store. Now asserts on
   `rate_limit_store.backend`, preserving the guarantee through the delegator.

### Lint

```
bundle exec rubocop <56 changed .rb files>
-> 56 files inspected, no offenses detected
```

## Static post-migration audit

- `solid_cache` / `SolidCache` / `solid_cache_store` / `config/cache.yml` / `caches_migrate` /
  `cache_replica` / `production_cache_db`: zero live runtime references. Remaining matches are all
  historical documents — three ADRs (`four-app-solid-cache-and-solid-queue.md`,
  `distributor-solid-cache-queue-placement.md`, `identity-db-scope-reduction-and-solid-setup.md`),
  `plans/`, `notes/oidc-session-model.md` — plus negative assertions in
  `test/integration/solid_infrastructure_test.rb` and `test/unit/database_password_config_test.rb`.
  History was not rewritten; each ADR received a dated supersession note at the top pointing to
  `adr/solid-cache-removal-and-valkey-cache-separation.md`.
- `VALKEY_URL` / `REDIS_NORMAL_URL` / `REDIS_CLIENT` / `REDIS_SMOKE_TEST` / `REDIS_FAIL_FAST`: zero
  matches outside `plans/`, `adr/`, `memos/`, `notes/` and prior evidence records.
- `CACHE_REDIS_URL` / `RATE_LIMIT_REDIS_URL`: `config/environments/development.rb`,
  `config/environments/production.rb`, `compose.yaml`, and documentation.

## Documentation updated

- `adr/solid-cache-removal-and-valkey-cache-separation.md` (new)
- Supersession notes on the three Solid ADRs listed above
- `docs/hld.md` — architecture diagram line and the caching / rate-limiting section, now stating the
  PostgreSQL / Solid Queue / Valkey split, the two contracts, the TTL requirement, and that Valkey
  loss must not invalidate authoritative state
- `docs/dds.md` — `RateLimit` concern row, and section 5.3 rewritten as "Valkey Usage" describing
  the two responsibilities separately
- `docs/srs.md`, `docs/service-layer-design.md`, `docs/architecture/dds.md`,
  `docs/architecture/hld.md`, `docs/architecture/database-boundaries.md`,
  `docs/architecture/model-database-inventory.md` — cache database and Solid Cache references
  removed

## Not verified in this session

**Final post-edit Podman rerun.** After the PostgreSQL replay/reveal correction and Dev Container
Valkey override fix, Podman could not reach Compose configuration because the host runtime failed at
`chmod /run/user/1000/libpod: read-only file system`. Per the Podman-only execution boundary, no
host Ruby/Rails fallback was used. The earlier container results above remain evidence for the
preceding worktree state; the final focused tests, migration application, merged Compose validation,
and Dev Container recreation must be rerun once rootless Podman is writable.

**Production Rails boot.** `RAILS_ENV=production bin/rails runner` could not be reached: the boot
requires a large production-only ENV surface (`TRUSTED_PROXIES`, `BASE_SERVICE_URL` and the rest of
the host-family origins, Neon credentials) that this host does not hold. The attempt stopped at
`ConfigValues::HostFamilyValues.origin: Missing required ENV key: BASE_SERVICE_URL`, which is
unrelated to this change and would have failed identically before it.

Mitigating evidence for the production cache configuration specifically: the changed block in
`config/environments/production.rb` is structurally identical to the one in
`config/environments/development.rb`, which boots and was exercised end to end above; both use
one-argument `ENV.fetch`, so a missing URL fails loudly at boot rather than falling back; and
`test/controllers/concerns/rate_limit_test.rb` statically asserts that no environment config gives
these URLs a localhost fallback. A production-like smoke boot should still be run in the deployment
pipeline before release.

## Remaining risks and follow-up

1. **Production-like store binding.** Provision and bind `CACHE_REDIS_URL` and
   `RATE_LIMIT_REDIS_URL` in staging/production infrastructure. Rails requires both contracts and
   intentionally does not encode a provider or shared-versus-separate-resource decision.
2. **Eviction policy.** The cache database's `maxmemory-policy` should be chosen deliberately. Every
   entry carries a TTL, so `volatile-lru` is coherent, but this was not configured here.
3. **Pre-existing publishing failures.** The three unrelated failures above should be resolved
   independently; they were present before this work and block a fully green suite.
4. **Credential hygiene.** The Upstash token was shared in plain text during this work. It is not
   committed to this repository, and rotation is recommended.
