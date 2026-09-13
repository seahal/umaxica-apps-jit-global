# Rails.cache.write Inventory & Classification

Audit-only report. No application behavior was changed. Scope = repo root only
(`/home/global/workspace`). Read patterns searched:
`Rails.cache.{write,read, delete,fetch,exist?,increment,decrement,read_multi,write_multi,delete_matched}`
plus wrapper objects exposing `.store.write/read/delete` and Rails 8.1 `rate_limit` macro usage.

This file lives at the in-flight plan path; rename to `plans/rails-cache-write-inventory.md` if the
canonical name from the task description is preferred.

---

## Context

The repo uses `solid_cache_store` for app cache and a dedicated Redis store
(`config.x.rate_limit.store`) for the Rails 8.1 `rate_limit` macro. Tests use `:null_store` for
cache and an in-memory store for rate-limit. Several call sites use `Rails.cache` (and a few
`.store` wrappers over it) to hold what is arguably **not** cache: anti-replay JTIs, OTP secrets,
ceremony candidates, cooldown windows, and one-time reveal payloads. This inventory catalogs every
call site so each can be re-evaluated individually before any refactor.

---

## Configuration baseline

| File                                 | Setting                     | Value                                                                                      |
| ------------------------------------ | --------------------------- | ------------------------------------------------------------------------------------------ |
| `config/environments/development.rb` | `config.cache_store`        | `:solid_cache_store` (sharded `cache`/`cache_replica`)                                     |
| `config/environments/development.rb` | `config.x.rate_limit.store` | `ActiveSupport::Cache::RedisCacheStore` via `RATE_LIMIT_REDIS_URL`, namespace `rate_limit` |
| `config/environments/production.rb`  | `config.cache_store`        | `:solid_cache_store` (sharded)                                                             |
| `config/environments/production.rb`  | `config.x.rate_limit.store` | `ActiveSupport::Cache::RedisCacheStore` via `RATE_LIMIT_REDIS_URL`                         |
| `config/environments/test.rb`        | `config.cache_store`        | `:null_store`                                                                              |
| `config/environments/test.rb`        | `config.x.rate_limit.store` | `ActiveSupport::Cache::MemoryStore.new`                                                    |
| `config/cache.yml`                   | Solid Cache                 | encryption on; prod/dev 1 week TTL, 256 MB; test 1h, 16 MB                                 |

`rate_limit_store` is read from `Rails.configuration.x.rate_limit.fetch(:store)` in
`app/controllers/concerns/rate_limit.rb` and passed explicitly to every
`rate_limit ... store: rate_limit_store` declaration except the CSP violation endpoint (see Section
4 below).

> **Note.** Test environment uses `null_store`; production tests that exercise cached state inject
> `MemoryStore` or `RedisCacheStore` per-test. Test files that call `Rails.cache.write` directly are
> doing so against the test-injected store, not against the production Solid Cache.

---

## 1. Production call sites — direct `Rails.cache.*`

Each row is one call site. Classification labels come from the rubric in the task prompt.

### 1.1 `app/services/identity_one_time_reveal.rb`

| #   | Line | Op       | Key                                      | Value                                 | TTL                    | Counterpart        | Feature                                       |
| --- | ---- | -------- | ---------------------------------------- | ------------------------------------- | ---------------------- | ------------------ | --------------------------------------------- |
| 1   | 37   | `write`  | `identity:one_time_reveal:<sha256(jti)>` | encrypted payload (binary) + metadata | 15 min (`DEFAULT_TTL`) | read@58, delete@61 | One-time secret reveal (recovery codes, etc.) |
| 2   | 58   | `read`   | same                                     | —                                     | —                      | paired w/ 37       | Reveal step                                   |
| 3   | 61   | `delete` | same                                     | —                                     | —                      | paired w/ 37       | Consume after reveal                          |

- **Classification:** `ephemeral_security_state`
- **Risk:** high
- **Recommendation:** `move_to_explicit_Redis_ephemeral_store` (needs strict one-time-use semantics;
  SolidCache eviction would cause silent loss of a secret the user is mid-flow to consume)
- **Reasoning:** This is the canonical "value is a secret, existence + TTL + one-shot are the
  contract". Putting it on a generic cache means GC eviction silently kills the user's flow, and
  SolidCache's encryption-at-rest is fine for confidentiality but provides no ownership/atomicity
  guarantees. Either a dedicated Redis namespace with explicit TTL semantics or a small DB-backed
  table (`one_time_reveal` with `consumed_at`) is appropriate.

### 1.2 `app/services/step_up_cooldown_stamp.rb`

| #   | Line | Op      | Key                                                 | Value  | TTL                | Counterpart                       | Feature                     |
| --- | ---- | ------- | --------------------------------------------------- | ------ | ------------------ | --------------------------------- | --------------------------- |
| 4   | 11   | `write` | `step_up_cooldown:<actor_type>:<actor_id>:<method>` | `true` | per-method (5–60s) | read in `step_up_cooldowns.rb:19` | Step-up auth cooldown stamp |

- **Classification:** `rate_limit_or_lockout`
- **Risk:** medium
- **Recommendation:** `keep_on_Rails_cache` — but tighten store binding so it shares the
  Redis-backed rate-limit store rather than the SolidCache app store. Silent eviction here lets a
  user bypass the cooldown.
- **Reasoning:** Pure throttle window. Loss = degraded rate limit, not lost data. Belongs with the
  other `rate_limit` machinery, not in SolidCache.

### 1.3 `app/services/step_up_cooldowns.rb`

| #   | Line | Op           | Key                                                     | Value | TTL | Counterpart | Feature                             |
| --- | ---- | ------------ | ------------------------------------------------------- | ----- | --- | ----------- | ----------------------------------- |
| 5   | 19   | `read_multi` | `step_up_cooldown:<actor_type>:<actor_id>:<method>` × N | bool  | —   | paired w/ 4 | Read active cooldowns for UI/policy |

- **Classification:** `rate_limit_or_lockout`
- **Risk:** medium
- **Recommendation:** `keep_on_Rails_cache` (same store as 1.2)
- **Reasoning:** Mirror of 1.2; co-located refactor.

### 1.4 `app/services/jump_rt_return_verifier.rb`

| #   | Line | Op       | Key                                                                 | Value     | TTL                            | Counterpart          | Feature                                     |
| --- | ---- | -------- | ------------------------------------------------------------------- | --------- | ------------------------------ | -------------------- | ------------------------------------------- |
| 6   | 98   | `write`  | `jump_rt:return_jwks:negative:<sha256(jwks_url)>` (with kid suffix) | `true`    | `NEGATIVE_CACHE_TTL = 30s`     | read@137             | Negative-cache unknown kid                  |
| 7   | 109  | `delete` | `jump_rt:return_jwks:<sha256(jwks_url)>`                            | —         | —                              | when `force: true`   | Invalidate fresh JWKS                       |
| 8   | 110  | `read`   | same                                                                | JWKS hash | —                              | paired w/ 114        | Fresh JWKS read                             |
| 9   | 114  | `write`  | same                                                                | JWKS hash | `CACHE_TTL = 5min`             | paired w/ 110        | Refresh fresh JWKS                          |
| 10  | 115  | `write`  | `jump_rt:return_jwks:stale:<sha256(jwks_url)>`                      | JWKS hash | `STALE_CACHE_TTL = 1h`         | read@118             | Stale fallback JWKS                         |
| 11  | 118  | `read`   | stale key                                                           | JWKS hash | —                              | paired w/ 115        | Stale fallback on fetch failure             |
| 12  | 137  | `read`   | negative key                                                        | bool      | —                              | paired w/ 6          | Skip refetch when kid known-missing         |
| 13  | 200  | `write`  | `jump_rt:return_jti:<sha256("<iss>:<jti>")>`                        | `true`    | dynamic = `exp - now` (capped) | `unless_exist: true` | One-time JTI replay guard for return tokens |

- **Lines 6–12 Classification:** `true_cache`
- **Risk:** low
- **Recommendation:** `keep_on_Rails_cache`
- **Reasoning:** Classic JWKS doc cache. Loss → one extra HTTPS fetch. Negative cache + stale
  fallback are performance/availability optimizations, not correctness invariants.

- **Line 13 (`jti` replay guard) Classification:** `ephemeral_security_state`
- **Risk:** high
- **Recommendation:** `move_to_explicit_Redis_ephemeral_store` (`unless_exist: true` is the
  atomic-check that prevents return-token replay; SolidCache eviction would allow a replay within
  the token's `exp` window).
- **Reasoning:** This is anti-replay, not cache. It must outlive process restarts and cannot be
  silently evicted while the token is still cryptographically valid. Note: `DpopJtiReplayGuard`
  already uses a DB uniqueness constraint for the analogous DPoP case — same pattern would fit
  return tokens (a `jump_rt_consumed_jti` table with `(iss, jti)` unique index and `expires_at` for
  sweep).

### 1.5 `app/services/oidc_logout_request.rb`

| #   | Line | Op                    | Key                                  | Value  | TTL                           | Counterpart  | Feature                        |
| --- | ---- | --------------------- | ------------------------------------ | ------ | ----------------------------- | ------------ | ------------------------------ |
| 14  | 86   | `replay_store.exist?` | `oidc:logout_request:consumed:<jti>` | bool   | —                             | paired w/ 15 | Reject replayed logout request |
| 15  | 103  | `replay_store.write`  | same                                 | `true` | `REPLAY_TRACKING_TTL = 2m30s` | paired w/ 14 | Mark logout request consumed   |

- **Classification:** `ephemeral_security_state` (RP-Initiated Logout one-shot)
- **Risk:** high
- **Recommendation:** `move_to_explicit_Redis_ephemeral_store` (or DB; same argument as 1.4 line 13)
- **Reasoning:** Replay defense for OIDC logout. `@replay_store` defaults to `Rails.cache`
  (SolidCache in prod). Silent eviction = replay window opens.

### 1.6 `app/services/oidc_logout_token_codec.rb`

| #   | Line | Op                    | Key                           | Value  | TTL                | Counterpart  | Feature                                                                                     |
| --- | ---- | --------------------- | ----------------------------- | ------ | ------------------ | ------------ | ------------------------------------------------------------------------------------------- |
| 16  | 107  | `replay_store.exist?` | `oidc:logout_token:jti:<jti>` | bool   | —                  | paired w/ 17 | Reject replayed back-channel logout token                                                   |
| 17  | 109  | `replay_store.write`  | same                          | `true` | `REPLAY_TTL = 10m` | paired w/ 16 | Mark back-channel logout token consumed; raises `"replay store unavailable"` if write fails |

- **Classification:** `ephemeral_security_state` (OIDC Back-Channel Logout JTI)
- **Risk:** high
- **Recommendation:** `move_to_explicit_Redis_ephemeral_store` or `move_to_PostgreSQL_or_Chronicle`
- **Reasoning:** Same as 1.5. Note this site already does the right thing by treating a failed write
  as a fatal "replay store unavailable" — that defensiveness is what tells you it isn't true cache.
  SolidCache is the wrong substrate for a contract that loud.

### 1.7 `app/services/identity_social_ceremony_candidate_store.rb`

| #   | Line | Op                        | Key                                        | Value                                                                                                                 | TTL                   | Counterpart      | Feature                              |
| --- | ---- | ------------------------- | ------------------------------------------ | --------------------------------------------------------------------------------------------------------------------- | --------------------- | ---------------- | ------------------------------------ |
| 18  | 75   | `self.class.store.write`  | `identity:social_ceremony:candidate:<ref>` | candidate hash incl. `auth_hash`, `provider`, `actor_ref`, `session_ref`, `transaction_id`, `operation`, `expires_at` | `ttl_for(expires_at)` | paired w/ 19, 20 | Social OAuth callback ceremony state |
| 19  | 80   | `self.class.store.read`   | same                                       | hash                                                                                                                  | —                     | paired w/ 18     | Resume candidate on callback         |
| 20  | 97   | `self.class.store.delete` | same                                       | —                                                                                                                     | —                     | paired w/ 18     | Consume after finalize               |

- **Classification:** `ceremony_state` (with strong security overtones — the candidate carries
  OmniAuth `auth_hash` and binds a pending identity)
- **Risk:** high (**flagged by task prompt as the priority candidate**)
- **Recommendation:** `move_to_PostgreSQL_or_Chronicle` / `replace_with_existing_domain_model`
- **Reasoning:** Already a clear "transaction with expires*at" — the cache store is a leaky
  implementation choice. The sibling `IdentitySocialCeremonyReplayStore` and the rest of the
  `Identity*CeremonyTransaction`models are DB-backed; this candidate store should follow the same
  pattern (e.g. an`identity_social_ceremony_candidates`table keyed by`ref`, with `expires_at`,
  `consumed_at`, encrypted payload). See sibling DB-backed pattern in
  `client_totp_ceremony_transaction.rb`. Default store fallback at `default_store()`swaps
  in`ActiveSupport::Cache::MemoryStore.new`whenever`Rails.cache`is a`NullStore` — that hack itself
  signals the storage choice is wrong. \_Do not refactor in this task; flagged as the highest
  priority for follow-up.\*

### 1.8 `app/services/identity_totp_ceremony_candidate_store.rb`

| #   | Line | Op                        | Key                                      | Value                                                                                            | TTL                   | Counterpart      | Feature                        |
| --- | ---- | ------------------------- | ---------------------------------------- | ------------------------------------------------------------------------------------------------ | --------------------- | ---------------- | ------------------------------ |
| 21  | 71   | `self.class.store.write`  | `identity:totp_ceremony:candidate:<ref>` | candidate hash incl. encrypted `private_key`, `digest`, `actor_ref`, `session_ref`, `expires_at` | `ttl_for(expires_at)` | paired w/ 22, 23 | TOTP enrollment ceremony state |
| 22  | 76   | `self.class.store.read`   | same                                     | hash                                                                                             | —                     | paired w/ 21     | Resume candidate on verify     |
| 23  | 93   | `self.class.store.delete` | same                                     | —                                                                                                | —                     | paired w/ 21     | Consume after finalize         |

- **Classification:** `ceremony_state` (carries TOTP seed material before promotion to
  `ClientTotpCredential`)
- **Risk:** high
- **Recommendation:** `move_to_PostgreSQL_or_Chronicle`
- **Reasoning:** Same shape as 1.7. The TOTP secret in transit is sensitive; promote to a DB table
  mirroring `Identity*CeremonyTransaction`.

### 1.9 `app/services/identity_secret_credential_ceremony_candidate_store.rb`

| #   | Line | Op                        | Key                                                   | Value                                                                            | TTL                   | Counterpart      | Feature                                                  |
| --- | ---- | ------------------------- | ----------------------------------------------------- | -------------------------------------------------------------------------------- | --------------------- | ---------------- | -------------------------------------------------------- |
| 24  | 68   | `self.class.store.write`  | `identity:secret_credential_ceremony:candidate:<ref>` | candidate hash incl. `password_digest`, `actor_ref`, `session_ref`, `expires_at` | `ttl_for(expires_at)` | paired w/ 25, 26 | Password (secret credential) registration ceremony state |
| 25  | 73   | `self.class.store.read`   | same                                                  | hash                                                                             | —                     | paired w/ 24     | Resume on confirm                                        |
| 26  | 90   | `self.class.store.delete` | same                                                  | —                                                                                | —                     | paired w/ 24     | Consume after finalize                                   |

- **Classification:** `ceremony_state`
- **Risk:** high
- **Recommendation:** `move_to_PostgreSQL_or_Chronicle`
- **Reasoning:** Same shape as 1.7 / 1.8. Carries a `password_digest` pre-promotion. Should be a
  DB-backed transaction with `expires_at` and `consumed_at`.

### 1.10 `app/controllers/concerns/sign_app_verification_base.rb` (Acme `app` surface email-OTP)

| #   | Line | Op       | Key                                                                    | Value                                                             | TTL      | Counterpart          | Feature                        |
| --- | ---- | -------- | ---------------------------------------------------------------------- | ----------------------------------------------------------------- | -------- | -------------------- | ------------------------------ |
| 27  | 21   | `exist?` | `email_otp_cache_key` (`step_up_session:<id>:email_otp`)               | bool                                                              | —        | —                    | Has OTP been issued?           |
| 28  | 25   | `fetch`  | `email_otp_resend_cache_key`                                           | hash                                                              | implicit | paired w/ 34 (write) | Resend throttle read           |
| 29  | 118  | `delete` | `email_otp_cache_key`                                                  | —                                                                 | —        | paired w/ 30         | Clear OTP after success/expiry |
| 30  | 182  | `write`  | `email_otp_cache_key`                                                  | hash `{ secret_credential: "<hashed_otp>" }` (and related fields) | 15 min   | paired w/ 29, 32     | Issue OTP                      |
| 31  | 216  | `read`   | `email_otp_cache_key`                                                  | hash                                                              | —        | paired w/ 30         | Verify OTP attempt             |
| 32  | 251  | `exist?` | `email_otp_resend_cache_key` (`step_up_session:<id>:email_otp_resend`) | bool                                                              | —        | paired w/ 33         | Resend throttle check          |
| 33  | 255  | `write`  | `email_otp_resend_cache_key`                                           | hash                                                              | 60s      | paired w/ 32         | Stamp resend cooldown          |

- **Lines 27, 29, 30, 31 Classification:** `ephemeral_security_state`
- **Lines 28, 32, 33 Classification:** `rate_limit_or_lockout`
- **Risk:** high (OTP material), medium (resend throttle)
- **Recommendation (OTP):** `move_to_explicit_Redis_ephemeral_store` or
  `replace_with_existing_domain_model` (use the same DB-backed pattern as other ceremony
  transactions; an `email_otp_attempt` row with `digest`, `expires_at`, `consumed_at`,
  `attempt_count`)
- **Recommendation (resend throttle):** consolidate into the Redis-backed `rate_limit_store`
- **Reasoning:** Email OTP is the credential under verification; losing it mid-flow forces the user
  to restart. Storing it in SolidCache is workable but mixes security-bearing state with general
  cache. The resend throttle is rate-limit and belongs with the rate-limit store.

### 1.11 `app/controllers/concerns/sign_com_verification_base.rb` (Acme `com` surface email-OTP)

| #   | Line | Op       | Key                   | Value | TTL    | Counterpart  | Feature   |
| --- | ---- | -------- | --------------------- | ----- | ------ | ------------ | --------- |
| 34  | 67   | `delete` | `email_otp_cache_key` | —     | —      | paired w/ 35 | Clear OTP |
| 35  | 133  | `write`  | `email_otp_cache_key` | hash  | 15 min | paired w/ 34 | Issue OTP |

- **Classification:** `ephemeral_security_state`
- **Risk:** high
- **Recommendation:** same as 1.10 (OTP block)
- **Reasoning:** Same surface-mirrored pattern as 1.10 for the `com` surface.

### 1.12 `app/controllers/concerns/sign_email_otp_verification_support.rb`

| #   | Line | Op       | Key                          | Value | TTL      | Counterpart      | Feature         |
| --- | ---- | -------- | ---------------------------- | ----- | -------- | ---------------- | --------------- |
| 36  | 18   | `exist?` | `email_otp_cache_key`        | bool  | —        | —                | OTP issued?     |
| 37  | 22   | `fetch`  | `email_otp_resend_cache_key` | hash  | implicit | paired w/ 41     | Resend throttle |
| 38  | 82   | `delete` | `email_otp_cache_key`        | —     | —        | paired w/ 40     | Clear           |
| 39  | 92   | `read`   | `email_otp_cache_key`        | hash  | —        | paired w/ 40     | Verify          |
| 40  | 131  | `write`  | `email_otp_cache_key`        | hash  | 15 min   | paired w/ 38, 39 | Issue OTP       |
| 41  | 127  | `exist?` | `email_otp_resend_cache_key` | bool  | —        | paired w/ 37     | Resend throttle |

- **Classification & Recommendation:** mirror of 1.10 (this concern is the shared support module
  that 1.10/1.11 delegate to in the new code path). Treat 1.10/1.11/1.12 as a single migration
  target.

### 1.13 `app/controllers/concerns/sign_email_otp_redelivery_endpoint.rb`

| #   | Line | Op     | Key                                                          | Value        | TTL | Counterpart                                     | Feature                                        |
| --- | ---- | ------ | ------------------------------------------------------------ | ------------ | --- | ----------------------------------------------- | ---------------------------------------------- |
| 42  | 42   | `read` | `email_nonce_cache_key` (`step_up_session:<id>:email_nonce`) | nonce string | —   | paired w/ test seeders at lines 1.X tests below | Read email anti-replay nonce during redelivery |

- **Classification:** `ephemeral_security_state` (anti-replay nonce)
- **Risk:** medium
- **Recommendation:** `move_to_explicit_Redis_ephemeral_store` (or DB nonce row)
- **Reasoning:** Nonce semantics, not cache. Note: I did **not** find a production `write` for
  `email_nonce`; the writes I see are in test fixtures (see Section 3). The production write site
  must exist — please confirm during follow-up that the issuing site has a paired writer (it may be
  issued upstream via `IdentityEmailCeremonyTransaction` and seeded into cache there).

### 1.14 `app/controllers/sign/app/verification/emails_controller.rb`

| #   | Line | Op     | Key                     | Value        | TTL | Counterpart     | Feature                      |
| --- | ---- | ------ | ----------------------- | ------------ | --- | --------------- | ---------------------------- |
| 43  | 110  | `read` | `email_nonce_cache_key` | nonce string | —   | (see 1.13 note) | Verify email nonce on submit |

- **Classification / Risk / Recommendation:** same as 1.13.

### 1.15 `app/controllers/sign/app/verification/base_controller.rb`

| #   | Line | Op       | Key                   | Value | TTL | Counterpart                    | Feature                     |
| --- | ---- | -------- | --------------------- | ----- | --- | ------------------------------ | --------------------------- |
| 44  | 69   | `delete` | `email_otp_cache_key` | —     | —   | paired w/ writers in 1.10/1.12 | Clear OTP on cancel/restart |

- **Classification / Recommendation:** roll up with 1.10/1.12 (same OTP key lifecycle).

### 1.16 `app/controllers/sign/com/verification/base_controller.rb`

| #   | Line | Op       | Key                   | Value | TTL    | Counterpart         | Feature                          |
| --- | ---- | -------- | --------------------- | ----- | ------ | ------------------- | -------------------------------- |
| 45  | 71   | `delete` | `email_otp_cache_key` | —     | —      | paired w/ 1.11/1.12 | Clear OTP                        |
| 46  | 137  | `write`  | `email_otp_cache_key` | hash  | 15 min | paired w/ 45        | Issue OTP (com surface override) |

- **Classification / Recommendation:** same as 1.11.

### 1.17 `app/controllers/sign/com/verification/emails_controller.rb`

| #   | Line | Op     | Key                     | Value | TTL | Counterpart | Feature                            |
| --- | ---- | ------ | ----------------------- | ----- | --- | ----------- | ---------------------------------- |
| 47  | 135  | `read` | `email_nonce_cache_key` | nonce | —   | see 1.13    | Verify email nonce on submit (com) |

- **Classification / Recommendation:** same as 1.13.

---

## 2. Wrapper / indirect cache call sites

Already covered by the `.store` wrappers listed in 1.5–1.9; called out here for quick orientation.
None of these is a _true_ abstraction over multiple backends — they all fall through to
`Rails.cache` (or to an in-test `MemoryStore.new`). Each wrapper is the right seam to redirect to a
purpose-built store when it is migrated.

| Wrapper class                                          | File                                       | Default backend                       | Section |
| ------------------------------------------------------ | ------------------------------------------ | ------------------------------------- | ------- |
| `IdentityOneTimeReveal`                                | `app/services/identity_one_time_reveal.rb` | `Rails.cache` (direct)                | §1.1    |
| `JumpRtReturnVerifier` (JWKS + JTI)                    | `app/services/jump_rt_return_verifier.rb`  | `Rails.cache` (direct)                | §1.4    |
| `OidcLogoutRequest#replay_store`                       | `app/services/oidc_logout_request.rb`      | `Rails.cache` (injectable)            | §1.5    |
| `OidcLogoutTokenCodec#replay_store`                    | `app/services/oidc_logout_token_codec.rb`  | `Rails.cache` (injectable)            | §1.6    |
| `IdentitySocialCeremonyCandidateStore.store`           | (s)                                        | `Rails.cache` w/ MemoryStore fallback | §1.7    |
| `IdentityTotpCeremonyCandidateStore.store`             | (s)                                        | `Rails.cache` w/ MemoryStore fallback | §1.8    |
| `IdentitySecretCredentialCeremonyCandidateStore.store` | (s)                                        | `Rails.cache` w/ MemoryStore fallback | §1.9    |

The `default_store` fallback that returns `ActiveSupport::Cache::MemoryStore.new` when `Rails.cache`
is `NullStore` is a strong indicator that these wrappers are misusing the cache subsystem to back
ceremony state.

---

## 3. Test-only call sites

Test code drives `Rails.cache` directly to set up / assert state. These are not production behavior;
they belong to whichever production site they correspond to (and will need updating in lockstep with
any migration).

| File                                                               | Line | Op       | Key                                      | Drives feature                                 |
| ------------------------------------------------------------------ | ---- | -------- | ---------------------------------------- | ---------------------------------------------- |
| `test/services/step_up/available_methods_test.rb`                  | 19   | `delete` | `step_up_cooldown:...`                   | §1.2/1.3                                       |
| `test/services/jump_rt/return_verifier_test.rb`                    | 54   | `exist?` | jwks cache                               | §1.4                                           |
| `test/services/jump_rt/return_verifier_test.rb`                    | 57   | `exist?` | jwks cache                               | §1.4                                           |
| `test/services/jump_rt/return_verifier_test.rb`                    | 194  | `write`  | stale jwks                               | §1.4                                           |
| `test/integration/jump_rt_return_verification_test.rb`             | 167  | `write`  | jwks cache                               | §1.4                                           |
| `test/integration/solid_infrastructure_test.rb`                    | 17   | `read`   | `reading_role_test_key`                  | Solid Cache infra smoke test                   |
| `test/controllers/sign/app/verification/emails_controller_test.rb` | 281  | `read`   | `email_otp_cache_key_for_id(...)`        | §1.10                                          |
| `test/controllers/sign/app/verification/emails_controller_test.rb` | 356  | `exist?` | `email_otp_cache_key`                    | §1.10                                          |
| `test/controllers/sign/app/verification/emails_controller_test.rb` | 447  | `write`  | `step_up_session:<id>:email_nonce` (15m) | §1.13 — **only writer seen for `email_nonce`** |
| `test/controllers/sign/app/verification/emails_controller_test.rb` | 452  | `write`  | OTP cache                                | §1.10                                          |
| `test/controllers/sign/com/verification/emails_controller_test.rb` | 170  | `exist?` | OTP                                      | §1.11                                          |
| `test/controllers/sign/com/verification/emails_controller_test.rb` | 256  | `write`  | OTP                                      | §1.11                                          |
| `test/controllers/sign/com/verification/emails_controller_test.rb` | 260  | `read`   | OTP                                      | §1.11                                          |
| `test/controllers/sign/com/verification/emails_controller_test.rb` | 369  | `write`  | `email_nonce`                            | §1.13                                          |
| `test/controllers/concerns/sign/app_verification_base_test.rb`     | 161  | `write`  | OTP                                      | §1.10                                          |
| `test/controllers/concerns/sign/app_verification_base_test.rb`     | 168  | `delete` | OTP                                      | §1.10                                          |
| `test/controllers/concerns/sign/app_verification_base_test.rb`     | 213  | `write`  | OTP                                      | §1.10                                          |
| `test/controllers/concerns/sign/app_verification_base_test.rb`     | 216  | `read`   | OTP                                      | §1.10                                          |
| `test/controllers/concerns/sign/app_verification_base_test.rb`     | 260  | `write`  | OTP                                      | §1.10                                          |
| `test/controllers/concerns/sign/com_verification_base_test.rb`     | 145  | `write`  | OTP                                      | §1.11                                          |
| `test/controllers/concerns/sign/com_verification_base_test.rb`     | 148  | `read`   | OTP                                      | §1.11                                          |
| `test/controllers/concerns/sign/com_verification_base_test.rb`     | 205  | `read`   | OTP                                      | §1.11                                          |

**Classification:** `test_only` — **Risk:** low — **Recommendation:** update alongside the
corresponding production site migration.

> Open question: the only `Rails.cache.write` against `step_up_session:<id>:email_nonce` I located
> is in test code (lines noted above). Production code only `read`s the nonce (§1.13, §1.14, §1.17).
> Either the issuer writes through a different abstraction (e.g. `IdentityEmailCeremonyTransaction`)
> or the nonce is issued via a path not captured by these greps. **Worth a focused trace before any
> migration touches the nonce path.**

---

## 4. Rate-limit macro (`rate_limit ..., store: rate_limit_store`)

The Rails 8.1 `rate_limit` macro is used pervasively. All controller-level declarations explicitly
pass `store: rate_limit_store` (resolved via `app/controllers/concerns/rate_limit.rb` → Redis in
prod/dev, `MemoryStore` in test). Counts (`rg -c 'rate_limit\s'` across `app/controllers`):

- Per-surface defaults at `<surface>::ApplicationController` (acme/core/sign × app/com/org, plus
  acme/net, acme/dev) — 11 declarations.
- `acme/{app,com,org}/oauth/tokens_controller.rb:16` — 3 declarations,
  `to: 10, within: 1.minute, only: :create`.
- `acme/app/oauth/authorizations_controller.rb:12` — 1 declaration.
- `app/controllers/concerns/csp_violation_report.rb:9` — 1 declaration,
  `to: 120, within: 1.minute, only: :create` — **does not pass an explicit `store:` argument**, so
  it falls back to `Rails.cache` (= SolidCache in prod). This is a documented carve-out (CSP
  endpoint runs without other authentication chain), but the inconsistency is worth flagging.
- ~50 additional declarations across sign/auth controllers (passkey options/verifications, email OTP
  creation/verification/resend, secret credential entry, social connect/disconnect). All use
  `rate_limit_store`.

**Classification:** `rate_limit_or_lockout`.

**Risk:** mostly low; `csp_violation_report.rb` is **medium** because of the SolidCache fallback
(cross-store mismatch).

**Recommendation:**

- `csp_violation_report.rb`: pass `store: rate_limit_store` (or document why it intentionally uses
  SolidCache).
- Otherwise `keep_on_Rails_cache` (via the Redis rate-limit store).

---

## 5. Adjacent stateful services that _do not_ use `Rails.cache`

Listed for completeness so they aren't accidentally picked up in a sweep.

| File                                                              | Storage backend                                            | Why mentioned                          |
| ----------------------------------------------------------------- | ---------------------------------------------------------- | -------------------------------------- |
| `app/services/dpop_nonce_service.rb`                              | DB (`*DpopProofState`)                                     | Anti-replay precedent already on DB    |
| `app/services/dpop_jti_replay_guard.rb`                           | DB uniqueness constraint                                   | Same                                   |
| `app/services/dpop_request_verifier.rb`                           | stateless                                                  | —                                      |
| `app/services/jump_rt_issuer.rb`                                  | stateless JWT                                              | —                                      |
| `app/services/jump_rt_return_policy.rb`                           | config only                                                | —                                      |
| `app/services/oidc_issuer.rb`                                     | config only                                                | —                                      |
| `app/services/oidc_client_registry.rb`                            | `Concurrent::AtomicReference` (process-local)              | App-lifetime cache, not request-scoped |
| `app/services/sign_up_step_gate.rb`                               | session-driven                                             | —                                      |
| `app/services/sign_in_otp_resend_state.rb`                        | `MessageEncryptor` (token-bound) + process-local key cache | —                                      |
| `app/services/social_auth_signup_finalizer.rb`                    | DB (delegates to ceremony transactions)                    | —                                      |
| `app/services/common_otp_policy.rb`                               | config only                                                | —                                      |
| `app/controllers/concerns/sign_passkey_sign_in_endpoint.rb`       | session + DB; no cache                                     | —                                      |
| `app/controllers/concerns/sign_social_authentication_endpoint.rb` | delegates to `IdentitySocialCeremonyCandidateStore` (§1.7) | —                                      |
| `app/models/client_totp_credential.rb`                            | DB, encrypted column                                       | —                                      |
| `app/models/actor/configuration.rb`                               | in-memory value object                                     | —                                      |

The existing DB-backed `Identity*CeremonyTransaction` / `Identity*CeremonyReplayStore` family (totp,
social, email, passkey, telephone, secret_credential, step_up) is the natural home for the ceremony
candidates and the JTI replay guards.

---

## 6. Documentation-only references

| File                                                 | Line | Notes                                                                                                                              |
| ---------------------------------------------------- | ---- | ---------------------------------------------------------------------------------------------------------------------------------- |
| `adr/identity-db-scope-reduction-and-solid-setup.md` | 222  | Example `bundle exec rails runner 'Rails.cache.write("k", "v"); ...'` in prose. **Classification:** `test_only` / docs. No action. |

---

## 7. Prioritized follow-up list (highest risk first)

> Order reflects severity + ease of mistaking the storage choice as "cache". Each item is a separate
> decision; this report does **not** prescribe a migration order beyond highlighting that 1, 2, 3, 5
> share the Identity ceremony pattern and could be handled as one initiative.

1. **`IdentitySocialCeremonyCandidateStore` (§1.7)** — **flagged by task as priority**. Move to
   DB-backed ceremony transaction (mirror the existing
   `Identity*CeremonyReplayStore`/`Identity*CeremonyTransaction` family).
2. **`IdentityTotpCeremonyCandidateStore` (§1.8)** — same shape; TOTP seed material is sensitive.
3. **`IdentitySecretCredentialCeremonyCandidateStore` (§1.9)** — same shape; carries
   `password_digest`.
4. **OIDC logout replay guards (§1.5, §1.6)** — anti-replay JTI on SolidCache. Either dedicated
   Redis namespace with explicit TTL or DB uniqueness constraint (matches `DpopJtiReplayGuard`
   precedent).
5. **`JumpRtReturnVerifier` JTI replay (§1.4 line 13)** — same as 4; the JWKS cache lines on this
   same class are fine to keep as cache.
6. **`IdentityOneTimeReveal` (§1.1)** — one-shot secret reveal; move to explicit ephemeral store.
7. **Email OTP cache (§1.10–§1.12, §1.16)** — high-volume security state. Either a DB-backed
   `email_otp_attempt` row or a dedicated Redis namespace.
8. **Email nonce cache (§1.13–§1.14, §1.17)** — investigate the missing production writer first;
   then migrate to an explicit ephemeral store.
9. **Step-up cooldown (§1.2, §1.3)** — re-bind to `rate_limit_store` (Redis) to match the other
   rate-limit machinery and avoid SolidCache eviction widening the cooldown window.
10. **`csp_violation_report.rb` rate_limit (§4)** — pass `store: rate_limit_store` or document the
    SolidCache fallback.
11. JWKS doc cache (§1.4 lines 6–12) — **keep**. True cache.

---

## Verification

This is an inventory-only deliverable. No code/config was changed, no migrations were authored, no
tests were run beyond the read-only grep inspections shown in this document.

To regenerate / sanity-check this inventory:

```bash
rg -n 'Rails\.cache\.(write|read|delete|fetch|exist\?|increment|decrement|read_multi|write_multi|delete_matched)' \
   --no-heading -g '!node_modules' -g '!tmp' -g '!log' -g '!coverage'

rg -n '(@store|@replay_store|\.store|replay_store)\.(write|read|delete|fetch|exist\?)' \
   app/services app/controllers app/models --no-heading

rg -n 'rate_limit\s' app/controllers --no-heading
```

Expected: the union of these three searches produces all the call sites listed in §1–§4 (modulo test
fixtures already listed in §3).
