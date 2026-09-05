# Software Requirements Specification (SRS)

## Project: Umaxica App (JIT)

### Aligned with ISO/IEC/IEEE 29148:2018 guidance

---

## 1. Purpose and Scope

### 1.1 Purpose

Umaxica App (JIT) replaces the legacy edge-only portal with a unified Ruby on Rails platform that
serves every public surface owned by Umaxica—corporate, service, staff, help, docs, news, BFF, and
API domains. The SRS defines the business goals, functional expectations, and quality attributes
that the Rails monolith must satisfy while orchestrating user onboarding, customer support, and
staff tooling across `umaxica.[app|com|org]` and auxiliary subdomains.

### 1.2 Scope

- Domains in scope (production + regional mirrors):
  - Public sites: `www.umaxica.app`, `www.umaxica.com`, `www.umaxica.org`
  - Service endpoints: `sign.umaxica.*`, `api.jp.umaxica.*`, `docs.[jp|us].umaxica.*`,
    `help.[jp|us].umaxica.*`, `news.[jp|us].umaxica.*`
  - Staff estate: `www.umaxica.org`, `log.umaxica.org`, `api.umaxica.org`, etc.
  - Network-only hosts (e.g., `asset-jp.umaxica.net`) are proxied but not powered by Rails.
- Subsystems: top-level marketing pages, authentication (sign), help center/contact flows,
  documentation and news portals, BFF preference endpoints, public API endpoints for inquiry
  validation, and supporting infrastructure (Valkey, OpenTelemetry, opt-in RustFS, Fastly/Cloudflare
  integrations).

### 1.3 Intended Audience and Use

- Product and engineering leadership – prioritization, roadmap alignment
- Domain engineers (Rails/React/pnpm toolchain) – implementation details and traceable requirements
- DevOps/SRE – hosting, observability, security posture
- QA/Release – acceptance criteria, traceability to tests and documentation

---

## 2. Stakeholders and Roles

| Role                  | Responsibilities                                                                                                      | Tooling / Notes                                           |
| --------------------- | --------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------- |
| Product Owner         | Defines feature scope, localization priorities, and compliance targets                                                | Roadmap, Notion/Jira                                      |
| Tech Lead / Architect | Owns multi-surface Rails architecture, multi-DB strategy, and integration points (Valkey, SMS, email)                 | Rails, Docker Compose                                     |
| Front-End Engineer    | Builds Turbo/React views in `src`, owns theme and preference UX                                                       | pnpm, Vite Plus, Tailwind, Turbo                          |
| Back-End Engineer     | Implements controller logic (e.g., `config/routes/*.rb` namespaces), models, encryption, OTP/passkey workflows        | Rails 8, PostgreSQL, Valkey                               |
| Platform/DevOps       | Manages Compose stack (PostgreSQL shards, Valkey, optional RustFS, Grafana/Loki/Tempo), CI (`integration.yml`), and deployments | Podman, Foreman, GitHub Actions                           |
| QA Engineer           | Designs Minitest/spec + JS/TS tests (via pnpm), Rswag/OpenAPI verification, smoke/load tests                          | `bin/rails test`, `pnpm test` (when added), Playwright/k6 |
| Security/Compliance   | Oversees JWT keys, Cloudflare Turnstile secrets, GDPR/ePrivacy consent storage                                        | Secrets management, monitoring                            |

---

## 3. System Overview

- **Runtime & language**: Ruby 3.4.7 / Rails 8.x monolith with multi-database (`connects_to`)
  separation (identity, universal, guest, profile, token, etc.) backed by PostgreSQL 18 (primary +
  replica).
- **Frontend toolchain**: Vite Rails with pnpm-managed Vite Plus tooling for Turbo/Stimulus/React
  entrypoints under `src`; browser CSS is bundled through Vite entrypoints while Rails still serves
  non-browser static assets.
- **Cache and rate-limit counters**: Valkey (Redis-compatible) backs two separate, non-authoritative
  stores -- `Rails.cache` (`CACHE_REDIS_URL`) and the rate-limit counters (`RATE_LIMIT_REDIS_URL`).
  Sessions are cookie-backed and Active Job is Solid Queue (PostgreSQL). Solid Cache is not used.
- **Security & identity**: JWT auth cookies (ES256) via the `Authn` concern, WebAuthn passkeys,
  HOTP/TOTP (ROTP), `Outbound::Sms`, and Cloudflare Turnstile for bot defense.
- **Observability**: OpenTelemetry instrumentation exports to Tempo via OTLP; logs/metrics land in
  Loki/Grafana (docker/observability stack).
- **Storage & CDN**: Shrine uses memory storage in test and filesystem storage otherwise. An
  opt-in RustFS profile supports explicit S3-compatible integration checks; production object
  storage remains deferred.
- **Surface mapping** (driven by ENV such as `TOP_CORPORATE_URL`, `ID_SERVICE_URL`, etc.): | Surface
  | Host examples | Namespace | Responsibilites |
  |---------|---------------|-----------|-----------------| | Top (marketing / preferences) |
  `www.umaxica.com`, `www.umaxica.app`, `www.umaxica.org` | `Top::Com/App/Org` | Redirects to edge,
  exposes `/health`, `/api/v0/health.json`, preference UIs (cookie/region/theme). | | Sign |
  `log.umaxica.app`, `log.umaxica.org` | `Sign::App/Org` | Registration (email/phone), OTP,
  passkeys, OAuth (Google/Apple), recovery, withdrawals. | | Help | `help.umaxica.com` |
  `Help::Com/App/Org` | Contact forms, ticket intake (`ServiceSiteContact`), Turnstile enforcement.
  | | Docs / News | `docs.umaxica.*`, `news.umaxica.*` | `Docs::*`, `News::*` |
  Documentation/newsroom placeholders with health pages. | | BFF | `bff.umaxica.*` | `Bff::*` |
  Non-auth preference/email endpoints for clients. | | API | `api.umaxica.*` | `Api::*` | JSON APIs
  (`/v1/inquiry/valid_email_addresses`, `valid_telephone_numbers`, `health`). |

---

## 4. Functional Requirements

### 4.1 Cross-surface routing and platform services

- **FR-01**: Each namespace (`top`, `sign`, `bff`, `api`, `docs`, `news`, `help`) must enforce
  host-level constraints defined in `config/routes/*.rb` using `ENV` variables to prevent routing
  leakage.
- **FR-02**: All surfaces implement the 2026-09-03 health contract via the shared `Health` service
  layer: `text/plain` probes at `/health` (four-line aggregate) and
  `/health/{startup,liveness,readiness}` (`ok\n` / 503), plus machine JSON at
  `/api/v0/health.json` (`pass/warn/fail`) and `/api/v0/revision.json`. Every response carries
  `Cache-Control: no-store` (a health verdict must not be cached). Details in
  `docs/reference/health-endpoints.md`.
- **FR-03**: Controllers must set consistent default URL parameters (`lx`, `ri`, `tz`) using
  `DefaultUrlOptions` so deep links retain localization context.
- **FR-04**: Request throttling is enforced through the `RateLimit` concern (`rate_limit to: 1000
  within 1.hour` against the Valkey-backed `config.x.rate_limit.store`) for every ActionController
  except API health, with overrides for test environments.

### 4.2 Preference management & localization

- **FR-05**: Region/language/timezone updates in preference controllers must validate against the
  current preference option registry, persist to DB-backed preference rows, and reissue the
  Preference JWT projection in `preference_access` / `__Host-preference_access`.
- **FR-06**: Theme selection (`Theme` concern) must support `system/dark/light` with shorthand codes
  (sy/dr/li) and rewrite to the correct edit URL per scope (Top::App/Com/Org).
- **FR-07**: Cookie consent toggles (`Preference::CookieController` using `Cookie` concern) must
  respect ePrivacy, storing permanent signed booleans for functional/performance/targeting cookies.

### 4.3 Identity, authentication, and account security (sign.\*)

- **FR-08**: Registration flows under `Sign::App::Registration` shall support email signup with
  Cloudflare Turnstile verification, HOTP issuance (ROTP), and `UserIdentityEmail` persistence using
  encrypted attributes.
- **FR-09**: Telephone registration controllers mirror email flow but dispatch OTP codes through
  `Outbound::Sms`.
- **FR-10**: Authentication controllers (`Sign::App::Authentication::*`) must issue short-lived
  access tokens (JWT ES384) and refresh tokens using `Auth::Base#log_in`. Refresh now requires
  `device_id` (`jit_auth_device_id` cookie or `X-Device-Id` header). If both are present they must
  match; missing/mismatch must return `401`, force logout for browser clients (clear
  access/refresh/device cookies + reset session), and require re-login.
- **FR-11**: Passkey management (`Sign::App::Setting::PasskeysController`) must expose
  `/setting/passkeys/challenge` and `/verify` endpoints compatible with WebAuthn spec and persist
  credentials in `UserPasskey`. Passkey-backed sessions always require an enrolled email or
  telephone identity (no passkey-only login) and may be used both for sign-in after that identity
  check and as an MFA factor.
- **FR-12**: TOTP provisioning (`Sign::App::Setting::TotpsController`) must generate QR codes
  (`rqrcode`) with session-stored secrets, verify first token, and persist to
  `TimeBasedOneTimePassword` (encrypted key).
- **FR-13**: OAuth integrations use OmniAuth and must be wired for CSRF-safe flows. Google is
  available on `app` and `org`; Apple is available only on `app`; `com` rejects both providers.
- **FR-14**: Withdrawal controllers must collect user intent and mark accounts for deletion once the
  `Authn` layer supports revocation.

### 4.4 Support, inquiry, and content surfaces

- **FR-15**: Help center contact forms (`Help::Com::ContactsController`) shall validate input via
  `ServiceSiteContact`, requiring either email or telephone, policy acceptance, and OTP
  confirmation. IP addresses must be logged (`ip_address` column) and PII encrypted at rest.
- **FR-16**: Successful contact submissions must trigger surface-scoped email notifications and
  remain observable through application logs and traces.
- **FR-17**: News and Docs namespaces must redirect to content-specific roots and expose health
  status; they are placeholders for static/dynamic content served through Rails/Turbo (React slots
  defined in `src/pages`).

### 4.5 API and BFF services

- **FR-18**: Public API endpoints under `Api::App::V1::Inquiry` must provide Base64-safe email
  validation (`valid_email_addresses#show`) and JSON phone validation
  (`valid_telephone_numbers#create`) using the same `ServiceSiteContact` validator to avoid
  duplicating rules.
- **FR-19**: BFF preference endpoints (`Bff::*::Preference::EmailsController`) must reuse
  `PreferenceRegions` logic while remaining stateless (no session writes) and support locale query
  aliases (`tz/tz`, `lx/lang`).
- **FR-20**: API/BFF responses must include structured error payloads and standard headers (CORS via
  `rack-cors`) to enable SPA and mobile clients.
  - Mobile/bearer clients must treat refresh `401` as logout: delete local access/refresh tokens and
    redirect to login.

### 4.6 Data protection and compliance

- **FR-21**: Personally identifiable records must reside in their designated database clusters
  (`IdentitiesRecord`, `ComPrincipalRecord`, `OccurrenceRecord`, etc.) with `connects_to` wiring
  honoring read replicas for reporting workloads.
- **FR-22**: Sensitive columns (emails, telephone numbers, OTP secrets) must use Active Record
  encryption with deterministic mode for lookups where required.
- **FR-23**: Preference credential cookies (`preference_access`, `preference_refresh`, and
  `preference_dbsc`, with `__Host-` prefixes in production) must keep their documented security
  attributes. Any downstream readable mirror must be documented separately from the credential
  cookie contract.
- **FR-24**: All database operations (create, update, delete) involving `User` and `Staff` entities
  must be recorded in the Audit log (`UserIdentityAudit`, `StaffIdentityAudit`) to ensure
  traceability and accountability.

### 4.7 Observability, CI/CD, and ops readiness

- **FR-24**: OpenTelemetry instrumentation (`config/initializers/opentelemetry.rb`) must be active
  in production and optionally in development (when OTLP collector is reachable) to push traces to
  Tempo; spans must include hostnames to differentiate surfaces.
- **FR-25**: Compose stack (PostgreSQL primaries/replicas, Valkey, optional RustFS,
  Grafana/Loki/Tempo) must stay reproducible for local dev; `Procfile.dev` orchestrates Rails with
  pnpm handling JS tooling.
- **FR-26**: GitHub Actions integration pipeline (`integration.yml`) plus Lefthook pre-commit must
  run `bundle exec rubocop`, `erb_lint`, `pnpm run lint`, `pnpm run check`, and `bin/rails test`.
- **FR-27**: Health dashboards (Grafana) must visualize request rate, OTP/passkey errors, and
  Turnstile failures.

---

## 5. Non-Functional Requirements

| Category             | Requirement                                                                                                                                                                                         |
| -------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Performance          | P95 response time ≤ 300 ms for `/health` endpoints; OTP submissions and preference updates complete within 2 s end-to-end; pnpm lint/format cycles and Tailwind watch rebuilds complete within 5 s. |
| Availability         | ≥ 99.0 % uptime for top/sign/help hosts, measured monthly; automated failover to replica PostgreSQL instances for read-heavy queries.                                                               |
| Scalability          | Support ≥ 1k req/min per host with linear scale-out via additional Rails pods.                                                                                                                      |
| Security             | Enforce HTTPS-only traffic, HSTS headers, CSRF protection, signed cookies, JWT validation, Cloudflare Turnstile challenge, rate limiters, and WebAuthn/TOTP options.                                |
| Privacy & Compliance | Preference cookies must capture consent state (GDPR/ePrivacy). PII stored encrypted with separation by database cluster. Audit logs retained ≥ 180 days.                                            |
| Maintainability      | Namespaced controllers/views keep code per host ≤ 500 LOC; shared concerns (`Authn`, `PreferenceRegions`, `Theme`, etc.) must remain framework-agnostic.                                            |
| Localization         | UI copy available in Japanese (default) and English; URL params `lx`, `ri`, `tz`, `ct` propagate through redirects and forms.                                                                       |
| Observability        | OTEL traces for HTTP, the Valkey rate-limit store, and Action Mailer; structured logs shipped to Loki; uptime monitors poll `/health` (text) + `/api/v0/health.json`.                                               |

---

## 6. Constraints and Dependencies

### 6.1 Technical constraints

- Ruby 3.4.7, Rails 8.x, pnpm 12.0.0, Node.js 24.19.0 (for tooling), PostgreSQL 18.
- Multi-database config defined in `config/database.yml` requires environment variables for each
  host (e.g., `POSTGRESQL_IDENTITY_PUB`, `POSTGRESQL_ACTIVITY_PUB`/`POSTGRESQL_ACTIVITY_SUB`, and
  `POSTGRESQL_BEHAVIOR_PUB`).
- Asset pipeline relies on Vite for browser CSS and pnpm-managed JS tooling for the app UI; Rails
  continues to serve static non-browser assets where appropriate.
- Dependencies include ROTP, WebAuthn, OmniAuth (Google/Apple), Rswag, Action Policy, Shrine,
  Fastly gem, AWS SDK.

### 6.2 Environmental & configuration constraints

- Required ENV keys: host mappings (e.g., `TOP_CORPORATE_URL`, `ID_SERVICE_URL`, `API_STAFF_URL`),
  downstream edge hosts (`EDGE_*`), the rate-limit store URL (`RATE_LIMIT_REDIS_URL`),
  Cloudflare Turnstile secret, JWT private/public keys, SMS provider selector, storage credentials
  (when the optional RustFS profile is used), OTLP endpoint.
- The devcontainer Compose override publishes the optional RustFS API and console on loopback
  ports 9000/9001 by default; both ports are configurable through `.env`.
- Foreman/Procfile required for multi-process dev; CI uses GitHub Actions runners with a PostgreSQL
  service. CI needs no Valkey service: the test environment's rate-limit store is an in-memory
  `ActiveSupport::Cache::MemoryStore`.

### 6.3 External services & integrations

- Email providers: AWS SES, ActionMailer + SMTP credentials.
- SMS: `Outbound::Sms` with `SMS_PROVIDER` selecting the concrete provider; queued message bodies
  are encrypted before enqueueing.
- Cloud providers: Google Cloud (Cloud Run/Build/Storage/Artifact Registry) for deployment,
  Cloudflare (R2, Turnstile, DNS), Fastly (asset CDN).
- Observability: Tempo/Loki/Grafana stack via Docker; production may forward to managed Grafana
  Cloud.

---

## 7. Acceptance Criteria

| ID    | Condition                                                                                                                                 |
| ----- | ----------------------------------------------------------------------------------------------------------------------------------------- |
| AC-01 | `GET .../health` returns 200 `text/plain` (four-line aggregate); `GET .../api/v0/health.json` returns `{"status":"pass",…}` for each host namespace.          |
| AC-02 | Editing language/region/timezone/theme updates cookies and redirects back to the proper Top scope with query parameters preserved.        |
| AC-03 | Email registration flow issues an OTP via ActionMailer only when Turnstile succeeds and saves `UserIdentityEmail` with encrypted address. |
| AC-04 | Telephone registration rejects invalid E.164 numbers and uses the configured SMS provider.                                                |
| AC-05 | Passkey flow returns creation options, stores the challenge in session, and accepts subsequent verification payloads.                     |
| AC-06 | Help contact form cannot submit without policy consent; valid submissions persist to `service_site_contacts` and emit a Mailer call.      |
| AC-07 | API inquiry endpoints validate addresses/phones using shared rules (no divergent regex).                                                  |
| AC-08 | Rate limiting, JWT verification, and Cloudflare Turnstile secrets are configurable per environment and validated during smoke tests.      |
| AC-09 | OpenTelemetry traces are visible in Grafana Tempo for at least the top/sign/help flows in staging/production.                             |
| AC-10 | CI pipeline executes `bundle exec rails test`, `pnpm run lint`, `pnpm run check`, `rubocop`, and `erb_lint` before merging.               |

---

## 8. Appendices & References

- Repository guides: `README.md`, `AGENTS.md`, `docs/checklist.md`
- Infrastructure: `compose.yml`, `Procfile.dev`
- Security: `SECURITY.md`, `CODE_OF_CONDUCT.md`
- Testing assets: `test/`, `spec/`, `rswag` configuration
- Change log: tracked via Git history and PR descriptions

> **Note:** This SRS is internal-facing and must be updated whenever routes, data stores, or
> external integrations change. It supersedes the legacy Acme portal specifications.
