# Solid Cache removal and migration to Valkey

Date: 2026-09-04
Worktree: branch `feature`, base commit `7408a4009`, continuing from
`evidence/2026-09-04-valkey-dependency-cleanup.md` in the same session.
Pre-existing unrelated modifications in `Gemfile.lock`, `pnpm-workspace.yaml`, and
`test/support/parallel_test_database_cloner.rb` were left untouched.

## Question

`Rails.cache` was Solid Cache on a dedicated PostgreSQL database. Should it be, and what was
actually stored in it?

## Live `Rails.cache` consumers before the change

| Consumer | Key | Reconstructed from | TTL | Stale fallback | Safe to lose |
| --- | --- | --- | --- | --- | --- |
| `ExternalAuthenticationInfrastructureOmniauthGoogleOidcEnforcement` | `external_authentication/google_oidc/jwks` | Google JWKS endpoint | 1 hour | no | yes |
| `ExternalSignIn::EntraJwksCache` | `external_sign_in/entra_jwks/<tenant>` | Entra JWKS endpoint | 1 hour | no | yes |
| `ExternalAuthentication::AppleNotificationJwksCache` | `external_authentication/apple_notification_jwks` | Apple JWKS endpoint | 1 hour | no | yes |
| `JumpRtReturnVerifier` fresh JWKS | `jump_rt:return_jwks:<sha256(url)>` | Jump JWKS endpoint | 5 minutes | yes | yes |
| `JumpRtReturnVerifier` stale JWKS | `jump_rt:return_jwks:stale:<sha256(url)>` | same endpoint | 1 hour | is the fallback | yes |
| `JumpRtReturnVerifier` unknown-`kid` negative cache | `jump_rt:return_jwks:negative:<sha256(url:kid)>` | refetch | 30 seconds | no | yes |
| `IdentityOneTimeReveal` | `identity:one_time_reveal:<sha256(jti)>` | re-issue the flow | 15 minutes | no | yes, fails closed |
| `OidcClientAssertionJwt` replay guard | `oidc:client_assertion:<ns>:<client>:jti:<jti>` | **nothing** | assertion `exp` + leeway | no | **no** |

The last row is why this migration was necessary. Consumed client-assertion JTIs are
replay-prevention state. They only worked because Solid Cache is a PostgreSQL table and never
evicts — a contract the cache API does not offer and Valkey does not honour. All cache keys are
constants or SHA-256 digests, so no consumer builds a key from unsanitised input.

## What moved where

**To Valkey (`CACHE_REDIS_URL`)** — the seven reconstructible entries above. Each already declared an
explicit TTL; none was changed. Losing any of them costs a refetch.

**To PostgreSQL** — `OidcClientAssertionJwt` now records consumed JTIs in `security_consumed_jtis`
under a new `oidc_client_assertion` purpose, next to the OIDC logout, logout-token, and Jump RT
return guards. The unique index on `(purpose, issuer, jti_digest)` provides the atomicity the
cache's `unless_exist:` provided, and a `RecordNotUnique` on a second use returns false. The old key
included the JWT namespace and the client id; the namespace is derived deterministically from the
client id, so keying on `issuer: client_id` alone is equivalent, not weaker. It fails closed: an
`ActiveRecord::ActiveRecordError` rejects the assertion.

**Deliberately left in PostgreSQL** (verified untouched): OAuth authorization codes, refresh-token
family and reuse detection, DPoP replay state (`*_dpop_proof_states`), OTP and ceremony transaction
state, credential mutation idempotency, Flipper flags, sign risk events, audit records, Solid Queue.
Short-lived is not the same as cacheable; the test is whether losing it is semantically safe.

`IdentityOneTimeReveal` stayed on `Rails.cache`, i.e. moved from PostgreSQL to Valkey. Its payload is
encrypted with `MessageEncryptor`, single-use, and TTL-bound to 15 minutes, and `consume!` returns
nil on a miss. An eviction costs the user a redo of the flow; it cannot reveal anything or leave
authoritative state wrong.

## Solid Cache components removed

- `gem "solid_cache"` from `Gemfile`; `bundle install` re-resolved (no `solid_cache` in `Gemfile.lock`).
- `config/cache.yml`
- `db/caches_migrate/` (4 files; three were repository-wide broadcast migrations already present in
  11-12 other migration directories, and all were `table_exists?`-guarded no-ops against the cache
  database)
- `db/cache_structure.sql`
- `config.cache_store = :solid_cache_store` and `config.solid_cache.connects_to` in
  `config/environments/production.rb`; the Solid Cache comments in `development.rb` and `test.rb`
- `test/integration/solid_infrastructure_test.rb` rewritten from asserting Solid Cache is
  *disconnected* to asserting it is *absent*, plus explicit assertions that Solid Queue is not
- the now-dead `solid_cache_` SQL allowlist entry in
  `test/security/invariants/read_only_route_write_invariant_test.rb`

## PostgreSQL cache databases removed

`cache` and `cache_replica` from all three environment blocks in `config/database.yml`
(`development_cache_db`, `test_cache_db`, `test_cache_replica_db`, `production_cache_db`), and
`POSTGRESQL_CACHE_PUB` / `POSTGRESQL_CACHE_SUB` from `compose.yaml`. `docs/architecture/model-database-inventory.md`
lost its `db/caches_migrate` row. No cache-only database remains in any environment. Queue
databases were not touched.

## Solid Queue verified unchanged

`config.active_job.queue_adapter` (`:solid_queue` in development and production, `:test` in test),
`config.solid_queue.connects_to`, the `queue` / `queue_replica` connections, `db/queues_migrate/`,
`config/queue.yml`, and `config/recurring.yml` job classes are all untouched.
`SolidInfrastructureTest#test_solid_queue_keeps_its_own_PostgreSQL_databases` asserts this directly.

## Development Compose

The single `valkey` service became two:

```
core
├─ CACHE_REDIS_URL      -> redis://valkey-cache:6379/0
└─ RATE_LIMIT_REDIS_URL -> redis://valkey-rate-limit:6379/0
```

Separate containers, separate volumes (`valkey-cache-volume`, `valkey-rate-limit-volume`), separate
healthchecks, both in `core`'s `depends_on`. Not `/0` and `/1` on one container: a logical database
index is not an isolation boundary, and one `FLUSHALL`, restart, OOM, or `maxmemory-policy` would
reach both stores. Neither port is published to the host.

## Configuration

Both environments resolve both stores through one-argument `ENV.fetch`, so a missing URL stops the
boot. Namespaces are `cache:<env>` and `rate_limit:<env>`, each with an optional
`*_NAMESPACE_SUFFIX`. No generic `VALKEY_URL` / `REDIS_URL` was reintroduced. No Upstash SDK, REST
access, or provider-specific hostname was added; both stores accept a `rediss://` URL unchanged.

## Test store policy

| Store | Default | Tests about that store |
| --- | --- | --- |
| `Rails.cache` | `NullStore` | stub a `MemoryStore` (already the existing pattern) |
| `config.x.rate_limit.store` | `NullStore` (was `MemoryStore`) | `counts_rate_limits!` swaps a `MemoryStore` in |

Rails' `rate_limit` DSL captures its `store:` argument in the `before_action` closure built while the
controller class body runs, so reassigning `Rails.configuration.x.rate_limit.store` afterwards never
reaches a loaded controller — which is why the previous suite-wide `MemoryStore` could only be
cleared, not replaced. The test environment now installs `SwappableCacheStore`
(`test/support/swappable_cache_store.rb`), a `SimpleDelegator` whose target can be swapped;
`counts_rate_limits!` (`test/support/rate_limit_store_override.rb`) points it at a `MemoryStore` for
the duration of each test in the declaring class and restores the null default afterwards.
Development and production assign their real stores directly, with no indirection.

32 test files whose assertions depend on counting were given `counts_rate_limits!`. Finding them
took three passes, and the two that the first pass missed are worth naming because they show how a
rate-limit dependency can hide:

1. 29 files found by searching for `too_many_requests` assertions.
2. `TelephoneRegistrableTest` and `SignOperatorTelephoneRegistrableGuardsTest`, which use
   `assert_raises(ActionController::TooManyRequests)` rather than inspecting a response status.
3. `IdentitySettingsPageCoverageTest`, which primes the store directly with `store.increment` and
   then asserts `assert_equal 429, response.status`. Against a null store the limit never fired,
   the controller proceeded to render, and the test failed with `ActionView::MissingTemplate` --
   a symptom that names neither rate limiting nor the store.

`BaseOauthTokenRateLimitTest` additionally asserts the swap is in force, so its 429 assertions
cannot pass vacuously against a null store. `Auth::App::Apple::NotificationsControllerTest` was
simplified: it reassigned `Rails.configuration.x.rate_limit.store`, which never reached the
controller.

A final sweep for `assert_equal 429`, `assert_response :too_many_requests`,
`assert_raises(ActionController::TooManyRequests)`, and `rate_limit.fetch(:store)` found no further
files needing the opt-in. `Auth::App::Sign::In::EmailsControllerEnumerationTest` asserts a 429 but
gets it from the database-backed send cooldown, not the `rate_limit` DSL, and
`ProblemTypeTest` only looks up a status code. Every other test that mentions rate limiting passes
unchanged against the null default, which is the intended result -- those tests are not about rate
limiting.

No test depends on an external Redis or Valkey.

## Findings from the security and performance review

1. **Rate limiting fails open, silently.** `ActiveSupport::Cache::RedisCacheStore#increment` rescues
   `RedisClient::ConnectionError` and returns `nil`; Rails' `rate_limiting` acts only
   `if count && count > to`. An unreachable Valkey therefore removes every rate limit fleet-wide,
   and before this change did so without a trace. This is pre-existing — the rate-limit store was
   already a `RedisCacheStore` — and whether it should fail closed instead is an availability
   decision, so the semantics were left alone. Both stores now take an `error_handler` that logs
   `valkey.store.unavailable` with the store label, operation, error class, and the degraded return
   value. The exception message is deliberately omitted: it can carry the store URL, which may embed
   credentials. `CacheBoundaryInvariantTest` asserts both handlers stay configured.
   **Follow-up for the user: decide whether rate limiting should fail closed.**

2. **`security_consumed_jtis` had no purge and grew without bound.** Pre-existing, but this change
   aggravates it by adding one row per OIDC token request. Added `SecurityConsumedJtiPurgeJob`,
   modelled on the existing `DpopProofStatePurgeJob`, scheduled every 15 minutes in development and
   production. Its only predicate is `expires_at < now`, which is the point past which the guarded
   token is already rejected on `exp` — deleting earlier would re-open the replay window.

3. **Cache stampede on a Valkey flush was considered and rejected as a change.** `race_condition_ttl`
   only applies to an entry that is present but expired, so it would not help the flush case at all,
   and the TTL-expiry case is one refetch per key per hour. All JWKS fetches already carry bounded
   open/read timeouts (2s/5s for Entra).

4. **No key-injection surface.** Every cache key is a constant or a SHA-256 digest.

## Commands executed and results

| Command | Result |
| --- | --- |
| `bin/rails test test/controllers/concerns/rate_limit_test.rb test/controllers/base/oauth_token_rate_limit_test.rb test/controllers/concerns/default_web_rate_limit_test.rb test/integration/base_endpoint_rate_limit_test.rb` | 24 runs, 5433 assertions, 0 failures, 0 errors |
| `bin/rails test test/services/oidc_client_assertion_jwt_test.rb` | 12 runs, 20 assertions, 0 failures, 0 errors |
| `bin/rails test test/integration/solid_infrastructure_test.rb` | 6 runs, 17 assertions, 0 failures, 0 errors |
| `bin/rails test test/security/invariants/cache_boundary_invariant_test.rb` | 5 runs, 18 assertions, 0 failures, 0 errors |
| `bin/rails test test/tooling/` | 40 runs, 274 assertions, 0 failures, 0 errors |
| `bundle exec rubocop` | 4410 files, 1 offense, in `test/support/parallel_test_database_cloner.rb` -- pre-existing, in an unrelated uncommitted change, left alone |
| `bundle exec erb_lint --lint-all` | 2811 files, no errors |
| `pnpm run lint` / `pnpm run format` | clean |
| `bin/rails test test/` (full) | 12328 runs, 69778 assertions, 1 failure, 0 errors, 1 skip |
| `COVERAGE=true bin/rails test test/` | line 99.14% (54092/54556), branch 82.45% (7710/9350), method 95.25% (9656/10137) |

The single failure is
`HostAuthorizationContractTest#test_development_compose_aliases_only_private_origins_and_configured_public_site_hosts`
(`jp.umaxica.dev` is aliased to `core` in `compose.yaml` but named by no `PUBLIC_*_URL`). It is
pre-existing and unrelated: the pre-migration baseline in the same session was 12314 runs with the
same one failure and 0 errors, and `git stash push compose.yaml` reproduced it against an
unmodified file earlier in the session.

Coverage against the `coverage/.last_run.json` baseline of line 99.15 / branch 82.44 / method 95.23:
line -0.01, branch +0.01, method +0.02, all inside the configured `maximum_drop` of 0.2 (line) and
0.5 (branch). 14 net new tests.

One flake was observed once and did not reproduce: `ActorSupportIncludedDoTest#test_current_lifecycle_methods_exist_in_module`
failed in one run and passed 9/9 in isolation and in every other run. It asserts over
`private_instance_methods` of a concern, which depends on what a parallel worker has autoloaded. It
is not related to this change and was not introduced by it.

## Static audit after the change

`solid_cache`, `SolidCache`, `solid_cache_store`, `config/cache.yml`, `caches_migrate`,
`cache_replica`, and `production_cache_db` have no live matches outside `adr/`, `plans/`, `notes/`,
and this evidence directory. `VALKEY_URL`, `REDIS_NORMAL_URL`, and `REDIS_CLIENT` have no live
matches at all outside `.github/workflows/ci.yml` (see Blocked).

## Intentionally retained historical references

- `adr/four-app-solid-cache-and-solid-queue.md` and `adr/distributor-solid-cache-queue-placement.md`
  already carry obsolete / superseded status notes. They describe an architecture that existed and
  were not rewritten. `adr/valkey-cache-and-rate-limit-stores.md` records the current decision and
  names them.
- `adr/identity-db-scope-reduction-and-solid-setup.md`, `notes/oidc-session-model.md`,
  `plans/audit-all-rails-cache-write-usage-logical-popcorn.md`, and
  `plans/docker-core-env-compose-async-harp.md` are historical records.

## Blocked

`.github/workflows/ci.yml` could not be edited: `.github`, `bin`, and `.devcontainer` are mounted
read-only in this environment (`mount` reports `ro`). Three now-dead entries remain in both the
`test-rails` and `coverage` jobs — `VALKEY_URL`, `POSTGRESQL_CACHE_PUB` / `POSTGRESQL_CACHE_SUB`, and
the `valkey` service — plus a `RATE_LIMIT_REDIS_URL` that nothing reads any more. **CI is not broken
by leaving them**: nothing in the suite connects to Valkey, and
`test/config/host_authorization_contract_test.rb`, the only test that boots a `RAILS_ENV=development`
subprocess, now supplies both Valkey URLs itself through `DEVELOPMENT_BOOT_ENV` rather than
inheriting them. `.devcontainer/compose.override.yml` still names the old `valkey` service and needs
the same rename to `valkey-cache` / `valkey-rate-limit`.

## Not verified

The two-service Compose split was not brought up: no container engine is available in this
environment (`podman` and `docker` are both absent). `compose.yaml` is asserted structurally by
`test/tooling/compose_restart_policy_test.rb` and `compose_host_port_exposure_test.rb`, both of which
were updated for the new service names and pass, but nothing here observed the containers boot, the
two stores stay isolated under a flush, or `podman compose config` render.

## Follow-up

1. Apply the `.github/workflows/ci.yml` and `.devcontainer/compose.override.yml` changes above once
   those paths are writable.
2. Decide whether rate limiting should fail closed when Valkey is unreachable (finding 1).
3. Bring up `podman compose up -d` and verify both Valkey services boot, that a cache flush leaves
   rate-limit counters intact, and the reverse.
4. Provision `CACHE_REDIS_URL` in production and decommission `production_cache_db`.
5. Upstash staging remains a separate task. No provider-specific code was added.
