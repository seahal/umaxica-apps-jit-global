# Observability Boundary

## Status

Current implementation guidance

## Purpose

This document records the current separation between:

- access logs
- application logs
- operational telemetry
- audit and security records
- product analytics

The goal is to prevent these concerns from being mixed into one system.

## Current Decision

The application does not use one event pipeline for every purpose.

Current logging behavior is:

- Access logs are emitted by Lograge from request-completion events.
- Application logs are emitted through `Rails.logger`.
- Event-style application log call sites are migrated to `Rails.logger` with `LogEvent.format`.
- `Rails.event` is not the application logging API.
- Non-log observability events may use `Rails.event.notify` when an accepted ADR defines the event
  boundary and subscriber behavior.

Structured application logging should be implemented with a logging gem or a dedicated logger
formatter. It should not be implemented by monkey-patching `Rails.event`.

## Access Logs

Access logs are request logs. Application code does not write them directly.

The current access log pipeline is:

- `config/initializers/lograge.rb`
- `config.lograge.enabled = !Rails.env.test?`
- `config.lograge.formatter = Lograge::Formatters::Json.new`
- `config.lograge.logger` writes one JSON object per line to stdout, and in development also to
  `log/development.access.jsonl` so Alloy can ship it to Loki
  (`adr/application-logging-boundary.md`). The line is identical; only the destinations differ.

Access logs should contain request-level fields such as method, path, status, duration,
`request_id`, and host. When a valid current OpenTelemetry span exists, the same JSON access-log
record also contains `trace_id` and `span_id`. Do not add domain behavior to Lograge.

The identifiers have distinct meanings and sources:

- `request_id` is the HTTP request correlation identifier managed by Rails
  `ActionDispatch::RequestId` and may originate from `X-Request-ID`.
- `trace_id` is the OpenTelemetry/W3C Trace ID from a valid current `SpanContext`.
- `span_id` is the OpenTelemetry Span ID from that valid current `SpanContext`.

`request_id` must never be substituted for `trace_id` or `span_id`. If OpenTelemetry is disabled or
the current span context is invalid, `request_id` remains available while `trace_id` and `span_id`
are absent or null. These identifiers are correlation metadata only; they are not authentication,
authorization, rate-limit, user-identity, or audit-integrity inputs.

## Application Logs

Application logs are logs written by application code, Rails internals, or gems.

Application logs are for developers and infrastructure operators. Use them for debugging, incident
response, operational visibility, and failure diagnosis. Do not make application logs the
authoritative record for important business, security, compliance, or accountability events.

Application code should use:

```ruby
Rails.logger.info("message")
Rails.logger.warn(LogEvent.format("auth.policy.missing", controller: self.class.name))
```

Use `LogEvent.format` only for event-shaped application log messages that need an event name and
structured payload. Plain operational messages can go directly to `Rails.logger`.

`JitLogEvent` applies `ObservabilityRedactor` to structured values. The redactor also removes
token-shaped JWT, Bearer, and named credential values when they appear inside free-form diagnostic
strings, including exception messages. Logging an exception is not permission to retain its raw
credentials or token material.

Do not add new uses of:

```ruby
Rails.event.info(...)
Rails.event.warn(...)
Rails.event.error(...)
Rails.event.debug(...)
Rails.event.record(...)
```

Those methods were custom application logging shims and are not part of the current logging
contract.

## Non-Log Observability Events

`Rails.event.notify` is reserved for non-log observability events. It is not a replacement
application logging API. Subscribers that turn those events into structured log lines must run
in-process and write through `Rails.logger`.

Current event:

| Event name                        | Producer                   | Subscriber               | Schema keys                                                                                                                                                                                                                                       |
| --------------------------------- | -------------------------- | ------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `security.csp_violation.reported` | `CspViolationReportIntake` | `CspViolationSubscriber` | `surface`, `host`, `category`, `disposition`, `document_uri`, `blocked_uri`, `source_file`, `effective_directive`, `violated_directive`, `original_policy`, `status_code`, `line_number`, `column_number`, `aggregation_key`, `user_agent_family` |

Rails CSRF notifications are operational application logs rather than durable audit records.
`CsrfNotificationSubscriber` subscribes in-process and writes these allowlisted fields through
`Rails.logger`: `controller`, `action`, and normalized `sec_fetch_site`. It must not log the request
object, notification message, Origin, cookies, authorization values, or authenticity tokens.

Two framework defaults would otherwise write the same events past that allowlist, so both are
constrained explicitly:

- **Rails' own CSRF warning is off outside development.** `ActionController::LogSubscriber` handles
  the same three `csrf_*.action_controller` events and writes `payload[:message]` verbatim. That
  message is built by `unverified_request_warning_message` and can read
  `HTTP Origin header (...) didn't match request.base_url (...)` — free text that never passes
  through `JitLogEvent.format`, so `ObservabilityRedactor` does not see it. `config/application.rb`
  sets `config.action_controller.log_warning_on_csrf_failure = false` so the redacted event is the
  single record. `config/environments/development.rb` sets it back to `true`: locally the raw reason
  is the signal that makes a blocked request diagnosable, and the log holds no real user data. The
  test environment inherits `false`, where `allow_forgery_protection` is off by default and CSRF
  detection is opt-in per test.
- **Every `Rails.event` subscription must be name-filtered.** `ObservabilityRedactor` is wired into
  `Rails.logger`, Sentry, and OpenTelemetry, but not into `Rails.event`. Framework structured-event
  subscribers are attached by default and forward raw payloads with filtering disabled
  (`ActiveSupport.event_reporter.notify(..., filter_payload: false)`); the Action Controller one
  forwards the CSRF `message` described above. A subscriber registered without a filter block would
  receive all of it unredacted. Until the redactor covers `Rails.event`, pass a block that selects
  the event names the subscriber wants.

The CSP report payload is allowlisted and scrubbed before emission. Raw CSP report bodies,
`script-sample`, cookies, authorization values, query strings, fragments, and unknown report keys
must not be emitted.

## Where Each Layer Is Stored In Development

Storage does not merge the layers; it only makes them queryable in one place.

```text
Lograge access logs      -> log/development.access.jsonl -> Alloy -> Loki    (24h)
Rails.logger application -> log/development.log          -> Alloy -> Loki    (24h)
OpenTelemetry traces     -> OTLP 127.0.0.1:4318          -> Alloy -> Tempo   (24h)
metrics                  -> Alloy self-metrics           -> Alloy -> Prometheus (24h)
audit / security records -> database tables                                  (authoritative)
```

Grafana reads all three backends and is published on `127.0.0.1:13000` for this machine's browser
only — never through Cloudflare Tunnel, Tailscale, or the LAN.

Two rules follow from this and are not negotiable:

- **Audit and security records never move to Loki.** Loki is a bounded 24h development copy of
  diagnostic output. It is not a record of fact, it is not retained, and it is not access-controlled
  the way the audit tables are. A durable record belongs in the database whether or not the same
  event also produces a log line.
- **Shipping logs adds no data.** The lines Alloy tails are the lines Rails already wrote, forwarded
  unmodified. Nothing about a log reaching Loki makes a cookie, authorization value, token, or
  request body loggable that was not loggable before — `JitLogEvent`, `ObservabilityRedactor`, and
  the allowlists described above remain the only gates on what enters a log line.

Telemetry redaction stays two-stage and independent of this: `ObservabilitySpanScrubber` in the
Rails process, then `otelcol.processor.attributes` in Alloy
(`adr/traces-and-metrics-routing-via-alloy.md`).

## Observability Layers

The application should keep these layers separate:

1. Access logs
2. Application logs
3. OTEL and technical telemetry
4. Audit and security records
5. Product analytics

## Layer 1: OTEL And Technical Telemetry

Primary purpose:

- reliability
- performance debugging
- incident investigation

Typical contents:

- request timing
- SQL timing
- background job timing
- external API latency
- exceptions
- service dependency failures

Primary audience:

- engineering
- SRE
- incident responders

OTEL should remain focused on technical observability.

Technical OpenTelemetry correlation is independent of product analytics consent. The optional
`performant` preference may govern a separately defined analytics layer, but it must not replace,
remove, or fabricate a `trace_id` or `span_id` supplied by a valid OpenTelemetry context.

## Layer 2: Audit And Security Events

Primary purpose:

- accountability
- abuse investigation
- security review
- compliance support

Typical contents:

- login success and failure
- session revoke
- passkey registration
- MFA or verification changes
- sensitive configuration changes
- staff actions on user-facing records

Primary audience:

- security
- operations
- compliance

Audit and security records are not the same as product analytics. Durable security-relevant records
should live in the appropriate audit or occurrence tables where the application already has those
models. A logger call may support incident response, but it is not a durable audit record.

Important audit, security, compliance, purchase, and other accountability events must be specified
before implementation. The specification must define the event schema, owner, retention expectation,
and access path. When such an event is needed, consider durable datastore registration from the
start instead of treating the application log as the source of truth.

## Layer 3: Product Analytics

Primary purpose:

- understand user flow
- understand activation and retention
- understand product adoption

Typical contents:

- signup started
- signup completed
- onboarding completed
- feature used
- first value reached

Primary audience:

- product
- growth
- business

Product analytics must remain separate from audit events and OTEL.

## Why Separation Matters

If the layers are mixed together:

- retention rules become unclear
- access control becomes unclear
- privacy review becomes harder
- dashboards become noisy
- event naming becomes unstable

Each layer exists for a different operational reason and should keep a different schema, retention
policy, and access path.

## Current Repository Fit

The repository already shows:

- OTEL usage for technical observability
- Lograge usage for access logs
- `Rails.logger` usage for application logs
- authentication and preference systems that can produce audit-worthy events
- cookie consent primitives that can later gate optional analytics

This means the repository can support separation, but the product analytics layer is not yet fully
defined.

## Minimum Rule For Implementation

For now:

- OTEL remains technical only
- Lograge remains access-log only
- `Rails.logger` remains the application-log API
- audit and security events cover required service and security actions
- product analytics stays pending until consent-aware rules are finalized

## Pre-Consent Event Allowlist

The previous `AnalyticsConsentGuard` event pipeline has been removed from application logging.
Product analytics remains pending and must be redesigned separately before reintroduction.

If product analytics is reintroduced, before optional `performant` consent is granted it may only
permit events that fall into the following classes. All other product analytics events must be
dropped.

| Class             | Event Patterns                                                                                                                                                                                                               | Rationale                                                 |
| ----------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------- |
| Authentication    | `auth.*`, `authentication.*`, `authorization.*`, `session.*`, `social_auth.*`, `sign.social.omniauth*`, `user.token.*`, `staff.token.*`, `user.occurrence.*`, `staff.occurrence.*`, `otp.*`, `webauthn.*`, `sign.webauthn.*` | Service delivery, fraud detection, audit accountability   |
| Security          | `rate_limit.*`, `telephone.verification.rate_limited`, `turnstile.*`, `captcha.*`, `security.*`, `redirect.blocked`, `redirect.invalid_url`, `sign.risk.*`                                                                   | Abuse prevention, bot mitigation, platform integrity      |
| Incident Response | `health_check.*`, `exception.*`, `unhandled_exception`, `error.unhandled`, `preference.*.error`, `preference.*.rotation_error`                                                                                               | Reliability monitoring, incident investigation, debugging |
| Contact           | `contact.submission.*`                                                                                                                                                                                                       | Confirm delivery of user-initiated contact                |

### Explicit Rule

**Product analytics and marketing analytics remain DISABLED before `performant` consent is
granted.** Events that answer "how do users move through the product?" require `performant` consent.

## Event Placement Rule

Use this rule when adding a new event:

- if it answers "what happened to this request?" -> access log / Lograge
- if it answers "what did the application code decide?" -> application log / `Rails.logger`
- if it answers "is the system healthy?" -> OTEL / technical telemetry
- if it answers "who did what?" -> audit or security record
- if it answers "how do users move through the product?" -> product analytics

If an event seems to fit more than one layer, split it into separate events rather than forcing one
event to serve multiple purposes.

## Pending Work

1. Select the structured application logging gem or formatter.
2. Define data retention and access rules per layer.
3. Link optional analytics startup to the consent model.
