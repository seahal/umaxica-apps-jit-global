# Detailed Design Specification (DDS)

## Project: Umaxica App (JIT)

### Conforms to IEEE 1016:2009 and ISO/IEC/IEEE 42010:2011

---

## 1. Introduction

### 1.1 Purpose

This DDS translates the high-level design of the Umaxica App (JIT) into implementation-ready detail.
It describes how each namespace, controller, concern, model, service, and infrastructure component
collaborates to satisfy the SRS.

### 1.2 Scope

- All Rails namespaces within `app/controllers`
- Front-end bundles in `src`
- Data models spanning the multi-database setup defined in `config/database.yml`
- Supporting services (`app/services`, `app/consumers`, ActionMailer, Sms providers)
- Observability, configuration, and deployment mechanisms (pnpm-managed JS tooling, Compose,
  Foreman, CI)

### 1.3 References

- `docs/srs.md`, `docs/hld.md`
- `README.md`, `AGENTS.md`, `docs/checklist.md`
- ISO/IEC/IEEE 42010, IEEE 1016

---

## 2. Architectural Context

### 2.1 System Context

The Rails monolith handles seven public surfaces (`top`, `sign`, `help`, `docs`, `news`, `api`,
`bff`). Each surface is isolated by host constraints and has its own controllers, yet they share
cross-cutting concerns.

```
Browser ⇄ Fastly/Cloudflare ⇄ Rails (Top/Sign/Help/Docs/News/API/BFF)
    ├─ PostgreSQL (identity, guest, universal, token, etc.)
    ├─ Valkey cache (Rails.cache, TTL-bound)
    ├─ Valkey rate limit (distributed counters)
    ├─ ActionMailer + SMTP
    ├─ Outbound::Sms
    └─ OpenTelemetry exporter → Tempo / Logs → Loki / Dashboards → Grafana
```

### 2.2 Primary Modules

| Layer          | Components                                                                                |
| -------------- | ----------------------------------------------------------------------------------------- |
| Presentation   | Namespaced controllers and Turbo/React views under `src`                                  |
| Domain Logic   | Concerns in `app/controllers/concerns`, services in `app/services`, models per DB         |
| Integration    | `app/mailers`, `Outbound::Sms`, OTEL instrumentation                                      |
| Infrastructure | Compose services (Postgres, Valkey, optional RustFS, Loki, Tempo, Grafana), pnpm/Tailwind toolchain |

---

## 3. Module Design

### 3.1 Routing & Namespacing

- `config/routes.rb` only `draw`s partials to keep the file maintainable.
- Each partial inside `config/routes/*.rb`:
  - Scopes traffic via `constraints host: ENV["<HOST_VAR>"]`
  - Adds nested modules (e.g., `scope module: :com, as: :com`)
  - Defines RESTful resources for health endpoints, preferences, docs, API, etc.
- All surfaces expose `text/plain` health probes (`/health` aggregate,
  `/health/{startup,liveness,readiness}`) plus machine JSON `/api/v0/health.json` and
  `/api/v0/revision.json`, via `HealthCheckRendering` / `ApplicationRevisionRendering` delegating
  to the `Health` service layer. See `docs/reference/health-endpoints.md`.

### 3.2 Shared Controller Concerns

| Concern               | Key responsibilities                                                                                             |
| --------------------- | ---------------------------------------------------------------------------------------------------------------- |
| `Auth::Base`          | JWT (ES384) issuance/verification (`kid` header + keyring), login/logout helpers, refresh/device cookie handling |
| `RateLimit`           | Exposes `config.x.rate_limit.store` (a Valkey-backed `ActiveSupport::Cache::RedisCacheStore`) to the `rate_limit` DSL |
| `DefaultUrlOptions`   | Reads signed preference cookie to append `lx`, `ri`, `tz` query params                                           |
| `PreferenceRegions`   | Normalizes locale/timezone inputs, persists to session/cookies, handles errors                                   |
| `Theme`               | Provides theme editing/updating with shorthand codes and preference cookie syncing                               |
| `Cookie`              | Stores ePrivacy consent flags in signed cookies                                                                  |
| `CloudflareTurnstile` | Validates Turnstile tokens via HTTP POST                                                                         |
| `Redirect`            | Validates allowed redirect hosts and Base64 tokens                                                               |
| `Health`              | `Health` service layer + `HealthCheckRendering` render text probes and `/api/v0/health.json`                     |

### 3.3 Top Namespace

- Controllers under `app/controllers/top/(com|app|org)` extend `ActionController::Base`, include
  `DefaultUrlOptions`, `PreferenceRegions`, `Theme`, `Cookie`, and `RateLimit` as needed.
- `Top::*::RootsController#index` redirects to `EDGE_*` hosts via
  `redirect_to "https://#{ENV['EDGE_*_URL']}", allow_other_host: true`.
- `Preference::*` controllers (region, cookie, theme, reset) provide UI for personalization and
  ePrivacy. Data stored inside signed cookies named `root_<scope>_preferences` and
  `root_<scope>_theme`.
- Views interact with JS entrypoints in `src/pages/**` to show localized text, doc/help/news URLs,
  etc.

### 3.4 Sign Namespace

**Registration flow** (`app/controllers/sign/app/registration/emails_controller.rb`):

1. `#new`: clears session slot, ensures user not logged in, instantiates `UserIdentityEmail`.
2. `#create`: validates Turnstile, generates HOTP secret + counter, stores intermediate state in
   session, dispatches OTP via the surface-specific `Email::*::OtpMailer`.
3. `#edit`: ensures session data matches requested ID and not expired.
4. `#update`: validates OTP; on success, persists `UserIdentityEmail`, clears session, redirects to
   home.

**Authentication flow** (`sign/app/authentication`):

- Email login obtains HOTP private key stored in encrypted cookie `:htop_private_key`.
- Passkeys: `PasskeysController` integrates WebAuthn gem; client JS `views/passkey.js` fetches
  `/setting/passkeys/challenge`, uses `navigator.credentials.create`, and POSTs `/verify`.
- Recoveries and TOTPs live under `sign/app/setting`; TOTPs use `ROTP` and `RQRCode`.
- Sessions: `Sign::App::SessionsController#create` (placeholder) will use `Authn#log_in`.

**Security features**:

- `Sign::*::ApplicationController` mixes in authentication, rate limiting, default URL options, and
  Action Policy.
- `authenticate_user!` ensures `logged_in?` before hitting settings endpoints.
- JWT cookies: `Auth::Base` writes `jit_auth_access` (JWT) + `jit_auth_refresh` +
  `jit_auth_device_id` (or `__Secure-` prefixed names in production).
- Refresh contract: `device_id` is mandatory from cookie or `X-Device-Id` header. If both are
  provided they must match, and must equal the token family `device_id`.
- Refresh deny behavior: missing/mismatched `device_id` returns `401`; browser clients are
  force-logged-out (session reset + auth cookies cleared). Mobile/bearer clients should clear local
  tokens on `401` and redirect to login.
- Refresh deny and reuse telemetry is persisted to `UserOccurrence`/`OperatorOccurrence` with
  structured `context` JSON.

### 3.5 Help Namespace

- `Help::Com::ContactsController` handles `new/create/show`.
- `ServiceSiteContact` (ComPrincipalRecord) encrypts email, phone, title, description; requires
  either email or telephone plus policy consent.
- Turnstile integration ensures bot mitigation; errors are logged via `Rails.logger`.
- OTP dispatch uses surface-specific `Email::{App,Com,Org}::OtpMailer` classes and `Outbound::Sms`.

### 3.6 Docs & News Namespaces

- Mirror the top namespace with simpler controller sets (root + health endpoints).
- React/Turbo entrypoints under `src/pages/docs/**` and `src/pages/news/**` hydrate placeholder
  content.

### 3.7 API Namespace

- Base controllers inherit from `ActionController::API` for lean responses.
- `Api::App::V1::Inquiry::ValidEmailAddressesController`: `#show` decodes Base64 `params[:id]`,
  instantiates `ServiceSiteContact` to reuse validation logic, and responds with
  `valid: true|false`.
- `ValidTelephoneNumbersController`: accepts JSON body, validates via same model.
- Host constraints ensure corporate/service/staff API stacks remain separated.

### 3.8 BFF Namespace

- Targets non-authenticated clients needing preference/email operations without hitting the full
  Rails views.
- The preference concerns override `default_url_options`, `set_locale`, and `set_timezone` using
  session or query params.
- Email preference controllers share translation scopes: e.g.,
  `Bff::App::Preference::EmailsController#translation_scope => "bff.app.preferences"`.

### 3.9 Front-End Bundles

- `src/entrypoints/application.ts` imports Turbo, Stimulus controllers, shared browser helpers, and
  the single Vite stylesheet graph.
- Additional Vite entrypoints live under `src/entrypoints`, with page modules under `src/pages`.
- JavaScript is bundled through Vite Rails; pnpm and Vite Plus manage linting, formatting, tests,
  and build tooling.
- Tailwind CSS is compiled through the Vite-backed frontend pipeline and surfaced through `bin/dev`.

### 3.10 Services & Integrations

- `Outbound::Sms` handles SMS dispatch for OTP-related flows.
- Other service placeholders (`AccountService`, `CoreService`, `EntityService`) mark future
  boundaries (business/customer mgmt, tokens).

### 3.11 Background Work

- Email delivery is handled directly through ActionMailer from the relevant controllers/services.
- Background work remains optional and should be introduced only when a concrete use case requires
  it.

### 3.12 Observability

- `config/initializers/opentelemetry.rb` loads OTEL SDK, exporter, and instrumentation.
- Production config sets `service_name = "umaxica-app-jit-core"` and `use_all`.
- Development example demonstrates how to point to OTLP endpoint (`tempo:4318`).
- Compose includes Loki/Tempo/Grafana; logs/traces accessible via forwarded ports.

---

## 4. Key Flows

### 4.1 Preference Update (Top::App::Preference::Region)

1. User visits `/preference/region/edit?lx=ja&ri=jp`.
2. `PreferenceRegions#set_edit_variables` normalizes query params, populates `@current_*`.
3. User submits new locale/timezone.
4. `#update` calls `apply_updates` → `assign_if_present` / `update_language` / `update_timezone`.
5. On success, the preference write path persists the DB row and reissues the Preference JWT
   projection in `preference_access` / `__Host-preference_access`.
6. Controller redirects to edit URL with normalized query params.

### 4.2 Email Registration Flow

1. `Sign::App::Registration::EmailsController#new` resets session, renders form.
2. `#create` verifies Turnstile, generates HOTP secret/counter, stores metadata in session, and
   emails OTP via the surface-specific `Email::*::OtpMailer`.
3. User enters OTP → `#update` reuses `UserIdentityEmail` validations; ensures session ID matches
   and not expired.
4. On success, `UserIdentityEmail` persists to identity DB, session cleared, redirect with success
   flash.

### 4.3 Help Contact Submission

1. User visits `help.umaxica.com/contacts/new`.
2. Form ensures policy consent via `src/pages/app/inquiry/before_submit.js`.
3. `#create` builds `ServiceSiteContact`, ensures Turnstile passes, encrypts PII, and stores IP
   address.
4. Send immediate email through the surface-specific alert mailer.
5. Redirect back with success notice.

### 4.4 Passkey Enrollment

1. Browser calls `/setting/passkeys/challenge`; controller fetches `User.last`, ensures
   `webauthn_id`, collects exclude credentials.
2. `WebAuthn::Credential.options_for_create` returns challenge; stored in
   `session[:webauthn_create_challenge]`.
3. VisitorAccount JS uses `navigator.credentials.create` with challenge; POSTs
   `/setting/passkeys/verify`.
4. Server verifies challenge (TODO) and persists `UserPasskey` with `webauthn_id`, `public_key`,
   `sign_count`.

---

## 5. Data Design

### 5.1 Models & Storage

| Model                                  | Base DB              | Notes                                                                            |
| -------------------------------------- | -------------------- | -------------------------------------------------------------------------------- |
| `User`, `Staff`                        | `IdentitiesRecord`   | `has_many :emails`, `:phones`, `webauthn_id` stored                              |
| `UserIdentityEmail`                    | `IdentitiesRecord`   | Includes `Email` concern, encrypts `address`, `before_create` sets UUID v7       |
| `ServiceSiteContact`                   | `ComPrincipalRecord` | Encrypts email/phone/title/description, validates OTP codes, stores `ip_address` |
| `TimeBasedOneTimePassword`             | `OccurrenceRecord`   | Encrypts `private_key`, stores `last_otp_at`, `first_token` virtual attr         |
| `UserPasskey`                          | `ApplicationRecord`  | Validates `webauthn_id`, `public_key`, `description`, `sign_count`               |
| `UserToken`, `OperatorToken`           | `TokensRecord`       | Reference tokens for JWT refresh handling                                        |
| `IdentifierRegionCode` and join tables | `OccurrenceRecord`   | Future mapping for personas/staff region codes                                   |

### 5.2 Cookies & Sessions

- Preference credential cookie: `preference_access` / `__Host-preference_access`, with refresh and
  DBSC siblings using the same basename pattern. The payload projects DB-backed preference fields
  such as `lx`, `ri`, `tz`, and `ct`.
- Theme cookie: `root_<scope>_theme`.
- Consent cookies: `:accept_functional_cookies`, `:accept_performance_cookies`,
  `:accept_targeting_cookies`.
- Auth cookies: access + refresh + device cookies (same security options; environment-dependent
  names).
- HOTP private key: `cookies.encrypted[:htop_private_key]`.
- Session: stores preference drafts, OTP metadata, WebAuthn challenges. The session is a Rails
  cookie store; no session state lives in Valkey.

### 5.3 Valkey Usage

Valkey backs two responsibilities, on two physically separate services, under two independent
configuration contracts. Neither is authoritative.

| Contract               | Store                       | Purpose                           |
| ---------------------- | --------------------------- | --------------------------------- |
| `CACHE_REDIS_URL`      | `Rails.cache`               | reconstructible application cache |
| `RATE_LIMIT_REDIS_URL` | `config.x.rate_limit.store` | distributed rate-limit counters   |

| Property                  | Value                            |
| ------------------------- | -------------------------------- |
| Authority                 | none                             |
| Durable application state | none                             |
| Loss of the cache         | cache miss, refetch from source  |
| Loss of the counters      | current rate-limit windows reset |

Every application cache entry carries an explicit TTL; rate-limit entries expire with their window.
The two stores are separated by service rather than by Redis logical database index, so either can
be flushed or restarted without touching the other.

Sessions are cookie-backed, Active Job is Solid Queue (PostgreSQL), Flipper flags are
PostgreSQL-backed, consumed JTIs and risk events are PostgreSQL-backed. Solid Cache is not part of
the runtime architecture. Adding a third Valkey use case requires an ADR.

---

## 6. External Interfaces

| Interface            | Endpoint(s)                                                                                               | Details                                                                                                                                                                         |
| -------------------- | --------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| HTTP/Turbo           | `/`, `/health`, `/api/v0/health.json`, `/preference/*`, `/sign/*`, `/help/contacts`, `/api/v1/inquiry/*`, `/bff/*` | Host-specific responses; `allow_browser` enforces modern clients.                                                                                                               |
| Cloudflare Turnstile | `https://challenges.cloudflare.com/turnstile/v0/siteverify`                                               | Called server-side with secret key, form response, and client IP.                                                                                                               |
| ActionMailer         | `Email::{App,Com,Org}::{OtpMailer,AlertMailer,PromotionalMailer}`                                         | OTP, alert, and promotion senders are fixed per surface and purpose, for example `otp@umaxica.app` and `promotion@umaxica.org`. OTP job arguments carry encrypted OTP payloads. |
| SMS                  | `Outbound::Sms`                                                                                           | Called via `Outbound::Sms.deliver_later` for OTP-related flows; `SMS_PROVIDER` selects the concrete provider. SMS job arguments carry encrypted message bodies.                 |
| OpenTelemetry        | OTLP exporter                                                                                             | Default endpoint `http://tempo:4318/v1/traces` (configurable).                                                                                                                  |
| Storage              | RustFS S3-compatible API                                                                                  | Opt-in local `object-storage` Compose profile with `object_storage:prepare`/`object_storage:smoke` rake tasks (`lib/tasks/object_storage.rake`) for manual verification. Not wired into the application: Shrine (`config/initializers/shrine.rb`) uses `Memory` storage in test and local `FileSystem` storage otherwise, and Active Storage (`config/storage.yml`) is `Disk`-only. |

---

## 7. Configuration & Environment

- `.env` / credentials must define hostnames (`TOP_*`, `AUTH_*`, `DOCS_*`, `NEWS_*`, `HELP_*`,
  `BFF_*`, `API_*`, `EDGE_*`, `PEAK_*`), DB hosts (`POSTGRESQL_*`, including the
  `POSTGRESQL_ACTIVITY_PUB/SUB` pair and `POSTGRESQL_BEHAVIOR_PUB`), the Valkey store URLs
  (`CACHE_REDIS_URL`, `RATE_LIMIT_REDIS_URL`), Cloudflare Turnstile keys, JWT keys, AWS credentials,
  OTLP endpoint.
- `compose.yaml` launches the normal infrastructure; the `object-storage` profile adds RustFS with
  four persistent volumes. Other volumes store data per
  service.
- `bin/dev` ensures the Rails server, Vite dev server, and background jobs run concurrently via
  `foreman start -f Procfile.dev`.
- Build/test commands:
  - `bundle install`, `pnpm install`
  - `bin/rails db:prepare`
  - `bin/dev`
  - Tests: `bin/rails test`
  - Lint: `bundle exec rubocop`, `bundle exec erb_lint .`, `pnpm run lint`, `pnpm run format`,
    `pnpm run check`

---

## 8. Security Mechanisms

- **Authentication**: JWT-based session cookies with ES256 keys stored in credentials.
- **Authorization**: Action Policy is included; settings controllers call `authorize!`.
- **Bot mitigation**: Cloudflare Turnstile required for registration/contact forms; server logs
  failures.
- **Rate limiting**: Rails' `rate_limit` DSL against the Valkey-backed `config.x.rate_limit.store`.
- **Data encryption**: Active Record encryption for PII (emails, phones, private keys, titles,
  descriptions). `ServiceSiteContact` ensures deterministic encryption for lookups where needed.
- **Passkeys & OTP**: WebAuthn for passkeys, ROTP for HOTP/TOTP, RQRCode for QR codes,
  `Outbound::Sms` for SMS OTP.
- **Redirect safety**: `Redirect::ALLOWED_HOSTS` enumerates acceptable targets;
  `generate_redirect_url` rejects unknown hosts.
- **Browser allowlist**: `allow_browser versions: :modern` prevents outdated user agents from
  hitting sensitive surfaces.
- **Secrets management**: Rails credentials provide JWT keys, Turnstile secrets, SMTP and AWS keys;
  Compose expects sanitized `.env`.

---

## 9. Error Handling & Logging

- `Health` concern logs initialization errors and returns 503/500 when the app is booting or raises
  exceptions.
- Controllers surface validation errors via flash messages and status codes
  (`422 Unprocessable Content`).
- Turnstile failures are logged at warn/error level with context.
- `ServiceSiteContact` `before_create` raises if required content missing to prevent blank
  submissions.
- OTEL instrumentation emits spans for HTTP requests, rate-limit store calls, and ActionMailer
  deliveries (once
  instrumentation enabled).
- Logs stream to STDOUT → Loki (when Compose stack used) or platform logging (Cloud Run).

---

## 10. Deployment & Operations

- **Local**: Compose + Foreman; pnpm handles JS lint/format tasks.
- **CI**: GitHub Actions pipeline runs bundler install, database setup, Rails tests, pnpm linting,
  Brakeman, Bundler Audit, and Vite Plus checks.
- **Staging/Production**:
  - Rails server deployed to Google Cloud Run (per README) or equivalent.
  - Fastly/Cloudflare handle DNS & TLS; `EDGE_*` hostnames define redirect targets.
  - Observability data flows to Tempo/Loki/Grafana (self-hosted or managed).
  - Infrastructure managed by Terraform (as referenced in README).
- **Backups**: PostgreSQL and production object-storage backup policies remain outside this local
  development design.

---

## 11. Future Enhancements

1. Flesh out staff/admin flows (owner/customer/news/docs CRUD).
2. Continue replacing legacy helper-style checks with explicit Action Policy authorization.
3. Publish OpenAPI via Rswag and mount `/api-docs`.
4. Add geolocation- and cookie-based personalization to `Top::*` once privacy reviewed.
5. Automate Fastly cache purges after docs/news updates.
6. Expand SMS providers and add delivery receipt handling.

---

> This DDS must evolve with the codebase. Any substantive change to controllers, models, services,
> or infrastructure (especially security-sensitive areas) requires a corresponding update here.
