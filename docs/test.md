# Test Specification (TS)

> **Partially superseded by Identity Authority inversion:** Identity test expectations in this
> document must be read through `docs/qa/identity-authority-regression-checklist.md`. `acme/www`
> commits session, token, account, preference, authorization, and freshness state. `sign/id` is
> ceremony-only and must not be tested as the owner of sessions, refresh, preference, dashboards,
> account lifecycle, token issuance, logout, or step-up freshness.

## Project: Umaxica App (JIT)

### Aligned with IEEE 829 / ISO/IEC/IEEE 29119 Test Documentation

---

## 1. Introduction

### 1.1 Purpose

This TS defines how the Rails-based Umaxica App (JIT) will be verified across every public
surface—top, sign, help, docs, news, BFF, and API. It covers strategy, environments, tooling,
detailed cases, and acceptance criteria derived from the SRS and HLD.

### 1.2 References

- `docs/srs.md`
- `docs/hld.md`
- `docs/dds.md`
- `README.md`, `docs/checklist.md`
- IEEE 829 / ISO/IEC/IEEE 29119 guidance

---

## 2. Test Scope

### 2.1 In Scope

- Host-scoped routing and localization for `top`, `sign`, `help`, `docs`, `news`, `api`, `bff`
- Preference management (cookie consent, region/language/timezone, theme)
- Identity flows (registration, OTP, passkeys, OAuth placeholders, settings, withdrawal)
- Help-center contact submissions with Cloudflare Turnstile, OTP checks, and encrypted persistence
- API & BFF endpoints (health, inquiry validation, preference APIs)
- Security controls (JWT issuance, rate limiting, Turnstile, redirect whitelist, encryption)
- Observability (OpenTelemetry traces and health endpoints)
- Build/test automation (pnpm-managed JS checks/tests, `bin/rails test`, and `bin/ci`)

### 2.2 Out of Scope

- Non-Rails-hosted network endpoints (e.g., `asset-jp.umaxica.net`)
- External downstream services (e.g., GCP provisioning, Fastly caches) beyond smoke verification
- Third-party OAuth provider behavior (Google/Apple) beyond handshake scaffolding

---

## 3. Traceability

| SRS Section                     | TS Coverage |
| ------------------------------- | ----------- |
| §4.1 Cross-surface routing      | §7.1        |
| §4.2 Preference mgmt            | §7.2        |
| §4.3 Identity flows             | §7.3        |
| §4.4 Support/contact            | §7.4        |
| §4.5 API & BFF                  | §7.5        |
| §4.6 Data protection / security | §7.6, §8    |
| §5 Non-functional               | §8          |
| Acceptance criteria (AC-01..10) | §7 + §9     |

---

## 4. Test Approach

- **Unit tests (Ruby)**: `bin/rails test` covers models (e.g., `ServiceSiteContact`,
  `UserIdentityEmail`, `TimeBasedOneTimePassword`), controllers, concerns, services, consumers.
  Fixtures stored under `test/fixtures`; multi-database fixtures split by context. The test database
  configuration uses Rails' standard process parallelization with a conservative default of 1 worker
  for low-shared-memory local containers, overridable via `PARALLEL_WORKERS`, disables PostgreSQL
  query/maintenance parallelism for test connections, and prepares separate writer/reader database
  names for each configured connection.
- **Unit tests (JS/TS)**: `pnpm test` runs the JavaScript test baseline directly through Vitest.
- **Integration/system tests**: Rails integration and system tests remain the automated baseline.
  Browser-level Playwright scenarios are deferred until a concrete release flow requires them.
- **API/contract tests**: Rails controller/integration tests cover API behavior, with
  `committee-rails` available for OpenAPI response validation where schemas exist. Rswag is not an
  adopted dependency.
- **Security tests**: RSpec/Minitest cases for rate limiting, JWT signature validation, redirect
  sanitization, Turnstile failure handling, PII encryption.
- **Cache and rate-limit stores in test**: both default to `ActiveSupport::Cache::NullStore`, so no
  test inherits state it did not ask for. A test that passes only because an earlier test warmed the
  cache does not describe the behaviour it claims to, and rate-limit counters are keyed by request IP
  -- identical for every test -- so a shared counting store makes unrelated tests 429 depending on
  suite order. Cache tests stub `Rails.cache` with a `MemoryStore`; rate-limit tests declare
  `counts_rate_limits!` (`test/support/rate_limit_store_override.rb`), which swaps a `MemoryStore`
  behind the store controllers captured at class-load time. Neither store reaches an external
  Valkey in test or CI.
- **Performance tests**: Dedicated k6/wrk scenarios are deferred. Add them only when a concrete load
  target and environment are defined.
- **Observability verification**: OTEL traces appear in Tempo; Loki logs capture Turnstile failures;
  Grafana dashboards show request rate and application error signals.
- **Automation**: CI runs the configured Rails and JS gates: `bin/ci` for the Rails stack and GitHub
  Actions `pnpm check` plus `pnpm test:coverage` for JavaScript.

---

## 5. Test Environments

| Env                     | Purpose                                 | Stack                                                                                                                           |
| ----------------------- | --------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------- |
| Local                   | Developer loop                          | Podman Compose (Postgres primaries/replicas, Valkey, optional RustFS, Loki, Tempo, Grafana), Foreman with Rails + pnpm-managed JS tooling |
| Staging                 | Integrated QA, performance & regression | Mirrors production hostnames, uses managed Postgres/Valkey, OTEL exports to staging Tempo                                       |
| Production Verification | Smoke tests post-deploy                 | Fastly/Cloudflare fronted hosts, managed infra                                                                                  |

**Data**: Seed states provided via fixtures; Compose services start with empty DBs. Sensitive data
must be synthetic. Contact forms require Turnstile test keys or bypass for automated runs.

---

## 6. Domain Behavior Matrix

| Surface           | Hosts                                                   | Coverage Focus                                                             |
| ----------------- | ------------------------------------------------------- | -------------------------------------------------------------------------- |
| Top::Com/App/Org  | `www.umaxica.com`, `www.umaxica.app`, `www.umaxica.org` | Redirect correctness, preference UIs, health endpoints                     |
| Sign::App/Org     | `log.umaxica.app`, `log.umaxica.org`                    | Registration (email/phone), passkey/TOTP, JWT cookies, logout, withdrawal  |
| Help::Com/App/Org | `help.umaxica.com`, etc.                                | Contact form validation, Turnstile, encrypted persistence, email/SMS hooks |
| Docs::_/News::_   | `docs.umaxica.*`, `news.umaxica.*`                      | Health endpoints, React hydration placeholder                              |
| API::\*           | `api.umaxica.*`                                         | `/health` (text), `/api/v0/health.json`, inquiry validation endpoints                      |
| BFF::\*           | `bff.umaxica.*`                                         | Preference APIs, locale propagation                                        |

---

## 7. Test Cases

### 7.1 Routing & Health

- **TC-ROUTE-001** Top root redirect (per host): GET `/` and expect 302 to `EDGE_*` host with
  `allow_other_host`.
- **TC-ROUTE-002** Health endpoints: GET `/health` and `/health/{startup,liveness,readiness}`
  (`text/plain`) and `GET /api/v0/health.json` (`application/json`, `pass/warn/fail`) for each
  host. Verify status (200/503), exact body, `Cache-Control: no-store`, and `406` on a non-JSON
  `Accept` to the `.json` endpoint.
- **TC-ROUTE-003** Host constraint enforcement: hitting `top` routes with mismatched host
  returns 404.
- **TC-ROUTE-004** Rate limit guard: simulate >1,000 requests/hour to sign/help endpoints; expect
  429. Valkey backs the limiter in development and production; the test declares
  `counts_rate_limits!` and asserts against a deterministic in-process store.

### 7.2 Preferences & Cookies

- **TC-PREF-101** Region update: POST `/preference/region` with `lx=ja&ri=jp&tz=jst`; expect signed
  cookie update and redirect parameters normalized (lowercase codes).
- **TC-PREF-102** Invalid timezone: send unsupported value; expect flash alert with translation key
  and `422` status.
- **TC-PREF-103** Theme update: toggling to `dark` writes `root_<scope>_theme` cookie and persists
  to `root_<scope>_preferences`.
- **TC-PREF-104** Cookie consent toggles: editing `preference/cookie` stores boolean flags, default
  false.

### 7.3 Identity & Security (Sign)

- **TC-SIGN-201** Email registration happy path (Turnstile bypass in test):
  `POST /sign/.../registration/emails` -> expect session metadata, OTP mail, redirect to `edit`.
  Submitting correct OTP persists `UserIdentityEmail` and clears session.
- **TC-SIGN-202** Expired OTP: set `expires_at` in session to past time; `#update` returns 422 with
  error.
- **TC-SIGN-203** Telephone registration: invalid E.164 rejected; valid number triggers
  `Outbound::Sms`.
- **TC-SIGN-204** Passkey challenge: POST `/setting/passkeys/challenge`; expect JSON options with
  challenge stored in session. Replay fails once challenge consumed.
- **TC-SIGN-205** TOTP creation: GET `/setting/totps/new` returns QR data; POST with valid token
  persists encrypted secret; invalid token re-renders with error.
- **TC-SIGN-206** JWT issuance: calling `Authn#log_in` writes `access_token` (ES256) and encrypted
  `refresh_token`; tampering with token triggers `JWT::VerificationError`.
- **TC-SIGN-207** Logout: `DELETE /sign/.../authentication` clears auth cookies and redirects to
  login.

### 7.4 Help & Contact

- **TC-HELP-301** Successful contact: POST `/help/com/contacts` with valid email, phone, policy
  consent; expect encrypted DB record and notice.
- **TC-HELP-302** Turnstile failure: stub API to return `success=false`; controller logs warning,
  adds error to form, status 422.
- **TC-HELP-303** Policy enforcement: front-end script prevents submission; server-side also rejects
  unchecked consent.
- **TC-HELP-304** OTP requirement: missing OTP fields should fail validation with error message.

### 7.5 API & BFF

- **TC-API-401** Email validation endpoint: GET `/api/app/v1/inquiry/valid_email_addresses/:id` with
  Base64 email; expect JSON body with `valid`.
- **TC-API-402** Telephone validation: POST JSON to `/api/app/v1/inquiry/valid_telephone_numbers`;
  expects `valid` key and proper status codes.
- **TC-API-403** Health JSON: `GET /api/v0/health.json` returns
  `{"status":"pass|warn|fail","checks":{…}}` with `fail` → 503; a readiness failure must not drop
  the `liveness` check to `fail`. `GET /api/v0/revision.json` returns `{"revision":"<sha>"}` or
  `{"revision":null}`.

### 7.6 Docs/News/Help health

- **TC-DOC-501** GET `/` on docs/news hosts returns 200 with placeholder markup and hydration
  dataset.
- **TC-DOC-502** `/health` (text) + `/api/v0/health.json` respond for docs/news/help staff hosts.

### 7.7 Redirect & Security

- **TC-SEC-601** Redirect whitelist: generating jump token for allowed host works; unknown host
  rejected (no redirect, 404).
- **TC-SEC-602** Allow browser: spoof legacy User-Agent -> request blocked (based on `allow_browser`
  behavior).
- **TC-SEC-603** Preference cookie tampering: malformed JSON replaced with defaults; verify logs
  warn.
- **TC-SEC-604** PII encryption: retrieving `ServiceSiteContact` from DB should not expose plaintext
  values; assert encrypted columns differ from input.

### 7.8 Observability & Ops

- **TC-OBS-701** OTEL span creation: hitting `/sign` while `OTEL_EXPORTER_OTLP_ENDPOINT` is set
  emits span visible in Tempo.

### 7.9 Current Automation Matrix

| Layer              | Local command                                | CI status                                                   | Decision                                                                |
| ------------------ | -------------------------------------------- | ----------------------------------------------------------- | ----------------------------------------------------------------------- |
| Ruby unit/ctrl/int | `bin/rails test`                             | Covered by `bin/ci`                                         | Adopted baseline.                                                       |
| Rails system       | `bin/rails test:system`                      | Covered by `bin/ci`                                         | Adopted Rails-level browser/system baseline.                            |
| JavaScript checks  | `pnpm check`                                 | Covered by `.github/workflows/integration.yml`              | Adopted baseline.                                                       |
| JavaScript tests   | `pnpm test`                                  | `pnpm test:coverage` in `.github/workflows/integration.yml` | Adopted baseline; keep expanding behavior-specific coverage.            |
| API contracts      | Rails tests with selective `committee-rails` | Covered when Rails tests exercise schema validation         | Adopted selectively; no Rswag dependency.                               |
| Browser E2E        | Not adopted                                  | Not gated                                                   | Deferred until a named cross-browser release flow needs it.             |
| Performance/load   | Not adopted                                  | Not gated                                                   | Deferred until load targets and an execution environment are specified. |

---

## 8. Non-Functional Tests

| Category      | Test                                                                                                                           |
| ------------- | ------------------------------------------------------------------------------------------------------------------------------ |
| Performance   | Deferred until a concrete load target and environment are specified; then add a focused k6/wrk scenario.                       |
| Load          | Deferred until OTP/session capacity targets are specified; then simulate the target concurrency against staging-like services. |
| Reliability   | Restart Compose services mid-request; ensure graceful error pages and health endpoints report BOOTING vs OK.                   |
| Security      | Brakeman, Bundler Audit, RuboCop security cops; manual pen-test for JWT tampering, Turnstile bypass attempts, redirect abuse.  |
| Localization  | Preferences propagate `lx`, `ri`, `tz`, `ct` through redirects; fallback defaults apply when cookies absent.                   |
| Observability | Verify health dashboards chart request rates, OTP failures, and Turnstile errors.                                              |

---

## 9. Tooling, Data, and Automation

- **Tools**: Minitest, Rails system tests, `committee-rails`, Vitest, Oxlint, Oxfmt, Brakeman,
  Bundler Audit, database_consistency, curl scripts for manual smoke checks.
- **Fixtures**: Stored per DB context; use `ActiveRecord::FixtureSet.create_fixtures` per database
  connection. Sensitive examples anonymized.
- **Data cleanup**: Multi-DB tests must wrap in transactions (Rails 8 multi-db test helpers) or rely
  on DatabaseCleaner configured per DB.
- **Secrets**: Tests requiring Turnstile should use test keys; OTP mailers configure `letter_opener`
  in development/test.

---

## 10. Entry / Exit Criteria

- **Entry**: Feature merged to main, migrations applied, Compose services healthy, linting passes,
  required secrets present.
- **Exit**:
  - All tests in this TS executed or justified as not applicable.
  - Critical/High defects resolved or accepted with mitigation plan.
  - Health dashboards show green and OTEL traces are present.
  - Release checklist (docs/checklist.md) signed off by Product + Engineering.

---

## 11. Maintenance

- Update this TS whenever routes, controllers, or integrations change (e.g., new namespace, new API
  endpoint, new OTP flow).
- Keep automated tests aligned with acceptance criteria and traceability matrix.
- Document manual steps for smoke/perf tests in `docs/checklist.md` or runbooks.

> Testing is everyone’s responsibility. If a feature lacks coverage here, it is not ready for
> production.
