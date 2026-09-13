# Adopt Faraday for hand-written outbound HTTP

## Context

A survey of recent Rails gem recommendations was compared against this repository's `Gemfile`.
Nearly every recommendation is already adopted (pagy, action_policy, strong_migrations,
database_consistency, prosopite, brakeman, solid_queue, flipper, discard, shrine, ruby-vips,
vite_rails, test-prof, ruby-lsp). `view_component` was reviewed and rejected. `alba`, `searchkick`,
`neighbor`, `rodauth-rails`, and `bullet` were rejected as redundant with jbuilder/inertia,
`pg_search`, absent requirements, the existing argon2 + webauthn + rotp + omniauth stack, and
`prosopite` respectively.

Faraday is the one remaining candidate with a concrete justification, and the survey of call sites
turned up a defect that motivates the change independently of the gem choice:

- All eight hand-written outbound HTTP call sites use stdlib `Net::HTTP` directly.
- **Four set no timeout at all**, falling back to the stdlib 60s read default:
  `app/lib/external_sign_in/entra_jwks_cache.rb`, `app/services/org_entra_sign_in_preflight.rb`,
  `app/services/oidc_rp_token_client.rb`, `lib/jit_security_turnstile_verifier.rb`. Three of these
  are on the sign-in path and one is on the bot-check path, so a slow or hung upstream stalls a
  request-handling thread for a minute.
- Timeout values, error rescue lists, and logging are duplicated and inconsistent across the four
  call sites that _do_ set timeouts.

`faraday (2.14.3)` is already resolved in `Gemfile.lock` (pulled in by `openid_connect`, `oauth2`,
`signet`, `googleauth`, `rack-oauth2`, `webfinger`), and
`config/initializers/opentelemetry.rb:31-32` already enables both the Faraday and the `Net::HTTP`
instrumentations. Adopting Faraday therefore adds no new transitive dependency surface and loses no
tracing coverage.

Intended outcome: one shared, explicitly configured HTTP connection factory; every outbound call
gets a timeout; retry policy is stated per call site rather than left implicit.

## Approach

### 1. Declare Faraday and pin the adapter

Add to `Gemfile` (default group, alongside the other runtime clients):

```ruby
# HTTP client for hand-written outbound requests. Already resolved transitively via the
# OIDC/OAuth gem chain; declared here because application code depends on it directly.
gem "faraday"
```

Do **not** set `Faraday.default_adapter` globally — that would silently change the transport used by
`omniauth_openid_connect`, `omniauth-google-oauth2`, and `omniauth-apple`. Configure the adapter
per-connection in the factory instead.

### 2. Add a shared connection factory

New file: `app/lib/outbound_http/connection.rb` (namespace mirrors the existing
`app/lib/external_sign_in/` layout).

Responsibilities, kept deliberately small:

- Build a `Faraday::Connection` with **required** `open_timeout` and `read_timeout` arguments — no
  defaults, so a caller that forgets a timeout fails at construction rather than inheriting a silent
  60s fallback. This is the `generic/no-silent-fallback.mdc` rule applied to timeouts.
- Enforce HTTPS on the target URI, preserving the existing check in
  `app/values/jump_rt_return_verifier.rb`.
- Disable redirect following. `faraday-follow_redirects` is in the lock but must not be enabled:
  `app/jobs/oidc_backchannel_logout_delivery_job.rb` posts to registry-supplied relying-party URIs,
  and following redirects there would defeat the allowlist and reintroduce SSRF.
- Accept an optional retry policy; **off by default**.
- Use the explicit `:net_http` adapter so behaviour matches what the current tests exercise.

Do not add response logging middleware. Request URIs on these paths carry tokens and tenant
identifiers; `adr/application-logging-boundary.md` and `docs/security/observability-boundary.md`
apply, and the existing redaction in `oidc_rp_token_client.rb` is the pattern to preserve.

### 3. Migrate the call sites

Migrate in two batches so the risky ones land separately.

**Batch A — read-only JWKS/discovery GETs.** Idempotent, so a bounded retry is safe and is the real
win over the current code:

- `app/lib/external_sign_in/entra_jwks_cache.rb:39-46` — _currently has no timeout_
- `app/services/org_entra_sign_in_preflight.rb:115-124` — _currently has no timeout_; also narrow
  the `rescue StandardError` to the specific network/parse errors, matching
  `apple_notification_jwks_cache.rb`
- `app/adapters/external_authentication/apple_notification_jwks_cache.rb:36-50`
- `app/values/jump_rt_return_verifier.rb:141-158`
- `lib/external_authentication_infrastructure_omniauth_google_oidc_enforcement.rb:97-113`

Keep each class's existing caching and its `FetchError`-style failure contract unchanged. Only the
transport moves.

**Batch B — POSTs. No retry.**

- `app/services/oidc_rp_token_client.rb:29-40` — OAuth authorization-code exchange. Codes are
  single-use; a retry burns the code and turns a timeout into a hard sign-in failure. Timeout only.
- `lib/jit_security_turnstile_verifier.rb:94-95` — Turnstile siteverify. Add a timeout; **do not
  change the existing failure disposition** at line 53. Tighten the broad `rescue StandardError` to
  the network error set only after confirming against
  `test/unit/jit/security/turnstile_verifier_test.rb` which branch each error must take.
- `app/jobs/oidc_backchannel_logout_delivery_job.rb:79-88` — already retried at the ActiveJob layer;
  adding connection-level retry would multiply attempts. Transport swap only.

`app/services/outbound_sms_providers_aws_sns.rb` is out of scope — it goes through the AWS SDK's
Seahorse transport and is already retried at `app/jobs/outbound/sms_delivery_job.rb:10`.

### 4. Regression guard

Add a test asserting no application file under `app/` or `lib/` references `Net::HTTP` directly, in
the style of the existing invariant tests
(`test/security/invariants/mounted_engine_invariant_test.rb`). This is what stops the pattern from
reappearing; without it the migration decays.

## Files

| File                                                                             | Change                                   |
| -------------------------------------------------------------------------------- | ---------------------------------------- |
| `Gemfile`                                                                        | declare `faraday`                        |
| `app/lib/outbound_http/connection.rb`                                            | new — connection factory                 |
| `app/lib/external_sign_in/entra_jwks_cache.rb`                                   | Batch A + **add timeout**                |
| `app/services/org_entra_sign_in_preflight.rb`                                    | Batch A + **add timeout**, narrow rescue |
| `app/adapters/external_authentication/apple_notification_jwks_cache.rb`          | Batch A                                  |
| `app/values/jump_rt_return_verifier.rb`                                          | Batch A                                  |
| `lib/external_authentication_infrastructure_omniauth_google_oidc_enforcement.rb` | Batch A                                  |
| `app/services/oidc_rp_token_client.rb`                                           | Batch B, no retry                        |
| `lib/jit_security_turnstile_verifier.rb`                                         | Batch B + **add timeout**                |
| `app/jobs/oidc_backchannel_logout_delivery_job.rb`                               | Batch B, transport only                  |
| `test/lib/outbound_http/connection_test.rb`                                      | new                                      |
| `test/security/invariants/no_direct_net_http_test.rb`                            | new                                      |

## Test impact

Every existing test for these classes stubs `Net::HTTP` directly and **will break**:

- `test/lib/external_sign_in/entra_jwks_cache_test.rb` (stubs `:get_response`, incl. a
  `Net::ReadTimeout` case at line 99)
- `test/services/oidc/rp_token_client_test.rb` (stubs `:post_form`)
- `test/adapters/external_authentication/apple_notification_jwks_cache_test.rb` (stubs `:start`)
- `test/lib/external_sign_in/google_oidc_enforcement_jwks_test.rb`
- `test/services/jump_rt/return_verifier_test.rb`
- `test/unit/jit/security/turnstile_verifier_test.rb`

Rewrite these onto `Faraday::Adapter::Test` stubs. This replaces brittle method-stubbing with a
supported test adapter and is a genuine benefit of the change, but it is the bulk of the work — plan
for the test edits to exceed the application edits. WebMock/VCR are not in the bundle and should not
be added; `Faraday::Adapter::Test` covers these cases.

Each migrated class keeps its existing coverage for success, non-2xx, malformed-JSON, and timeout,
plus a new assertion that the configured timeout is actually applied.

## Verification

```bash
bin/rails test test/lib/outbound_http/connection_test.rb
bin/rails test test/lib/external_sign_in/entra_jwks_cache_test.rb \
               test/services/oidc/rp_token_client_test.rb \
               test/adapters/external_authentication/apple_notification_jwks_cache_test.rb \
               test/lib/external_sign_in/google_oidc_enforcement_jwks_test.rb \
               test/services/jump_rt/return_verifier_test.rb \
               test/unit/jit/security/turnstile_verifier_test.rb
bin/rails test test/security/invariants/
bin/rails test                      # full suite — auth paths are broadly covered
bundle exec brakeman --no-pager     # confirm no new SSRF/redirect warnings
bundle exec rubocop
```

Also confirm after the change that OpenTelemetry still emits client spans for these calls — the
Faraday instrumentation is already enabled at `config/initializers/opentelemetry.rb:31-32`, so spans
should continue to appear with the `net_http` adapter underneath.

## Explicitly out of scope

- Reconfiguring the HTTP layer of `stripe`, `svix`, `aws-sdk-*`, `sentry-ruby`, `web-push`,
  `webauthn`, or `mcp`. They ship their own transports and are working.
- Setting `Faraday.default_adapter`, which would change the OmniAuth/OIDC gem chain's transport as a
  side effect.
- Enabling `faraday-follow_redirects` anywhere.
- Adopting `alba`, `searchkick`, `neighbor`, `rodauth-rails`, `bullet`, or `view_component`.

## Deviations from this plan during implementation

1. **No retry, anywhere.** The plan proposed a bounded retry for the idempotent Batch A fetches.
   Faraday 2 moved retry into the separate `faraday-retry` gem, which is not in `Gemfile.lock`, so
   this would have meant adding a dependency and installing it over the network to serve a benefit
   no current call site asked for. Dropped on YAGNI grounds; the change is now purely timeout and
   transport unification. `OutboundHttp::Connection` takes no retry argument, so adding one later is
   a deliberate edit rather than a flag flip.

2. **`lib/jit_security_turnstile_verifier.rb` keeps its broad `rescue StandardError`.** The plan
   allowed narrowing it after checking the test. No test covers a network-error branch there, and
   that rescue is what routes an unreachable Cloudflare into the `unavailable: true` degraded-mode
   path. Narrowing it blind would have been a change to the bot-check failure disposition, which is
   outside this change. The timeout was added as planned.

3. **`require_https` is a required argument, not an internal policy.** The plan described
   unconditional HTTPS enforcement. `OidcBackchannelLogoutDeliveryJob` posted with
   `use_ssl: uri.scheme == "https"`, so the scheme comes from the client registration; forcing HTTPS
   there would have been a silent behaviour change. Each call site now states its policy, and every
   one except that job requires HTTPS.

4. **The invariant test is broader than planned.** It bans `URI.open`, `OpenURI`, `HTTParty`,
   `RestClient`, `Excon`, and `Typhoeus` alongside `Net::HTTP`, and adds a second test that
   `Faraday.default_adapter` is never reassigned.

## Verification results

Run inside `global-devcontainer-core` (the host bundle is not installed; `bundle check` fails there
and succeeds in the container).

- The ten touched test files: **89 runs, 276 assertions, 0 failures, 0 errors**.
- `bundle exec rubocop` over all 21 changed files: **no offenses**.
- `bundle exec brakeman --no-pager`: **0 security warnings, 0 errors**.
- Full suite `bin/rails test`: **10375 runs, 58994 assertions, 1 failure, 0 errors, 1 skip**.

The single failure is
`ViteAssetNonceTest#test_every_Vite_asset_tag_on_an_Inertia_page_carries_the_response_nonce`
("expected the entrypoint to emit modulepreload links"). It is **pre-existing and unrelated**: it
fails identically with every change in this branch stashed, and it reports a stale Vite build
manifest rather than anything on the HTTP path. It needs a fresh `pnpm build`, not a fix here.
