# Email observability acceptance

Authority: O00–O13's approved local remediation, with the existing
[remediation ADR](../../adr/otp-observability-secret-exposure-remediation.md),
[owning plan](../../specs/otp-observability-secret-exposure-remediation/plan.md),
[logging ADR](../../adr/application-logging-boundary.md) and
[observability boundary](../security/observability-boundary.md). The local scope does not close
older production/Sentry/broader-review obligations: those remain separately owned and excluded here
(C10/C14). No incident or current PASS is asserted. Follow the
[investigation procedure](integrated-stack.md#independent-investigation).

## MAIL-1 — Sensitive filtering without lost safe diagnostics

- Basis: O00/O01. Scope: Rails filtering in all app/com/org Email paths and nested parameters.
- Given a map with synthetic secret and non-secret values, filter it using the application's public
  filter: password variants, client_secret, otp/otp_code, access/refresh/id tokens,
  authorization_code, code, rt, pt, state, actual uid/provider_uid keys and credential_id become
  FILTERED. reason_code, status_code, http_status_code, guid, public_id, provider, order, sort,
  support, attempt_count and event_uuid keep their safe values. Real capability transport keys
  remain protected.
- Short ambiguous keys use exact/intentional boundary matching; broad meaningful secret categories
  retain useful matching without uncontrolled widening. Test case/nesting and true/false matches,
  including boundary-similar keys; a regex example is not a substitute for current key inventory.
- Check [filter tests](../../test/unit/security/filter_parameter_logging_test.rb) and the actual
  filter_parameter_logging initializer. Extend missing two-sided cases; no current execution is
  claimed.

## MAIL-2 — Standard delivery without raw email application logging

- Basis: O02/O08/O13. Given a synthetic OTP message from each surface, boot the application with the
  shared public mailer logger policy and deliver via the local test adapter: delivery remains usable
  while raw content/recoverable MIME is absent from captured application logs, including DEBUG
  paths. ActionMailer::Base.logger is nil after configuration; inspect concrete overrides too.
- Suspension, perform_deliveries, deliver_now/deliver_later, Noticed and retries keep their current
  semantics. No interception bypass, private API override, Rails monkey patch, MIME rewriting or new
  delivery implementation. Named CSP Rails.event subscription stays scoped; raw framework mail
  events are not newly forwarded to external sinks. An internal framework payload may still contain
  MIME; this criterion does not claim its removal.
- Check config/application.rb, installed Rails Railtie setters/order, event_subscribers, three
  surface mailers and OutboundEmailSuspensionInterceptor. Perform direct safe boot and synthetic
  capture; all-surface success/suspension/failure/retry behavior coverage is planned where absent.
  Do not add setup-only Minitest cases or send real mail to prove configuration.

## MAIL-3 — Pre-export fixed allowlists

- Basis: O00/O03/O04. Given actual installed OTel instrumentation and a synthetic process/deliver
  notification with subject/addresses/args/body/headers/URL/token plus unknown future keys, inspect
  captured spans before any network export. Deliver permits controlled email.x_mailer only; process
  permits controlled mailer/action only. Optional message_id is omitted unless controlled non-PII
  generation is demonstrated. Forbidden/unknown fields are absent, not merely scrubbed downstream.
- Formal notification_payload_transform/process_payload_transform always return a fresh selected
  Hash; email_address: :omit is explicit if supported. Reconfirm installed version/API/key
  representation: preparation observed ActionMailer instrumentation 0.8.1 with transformed string
  email.* deliver keys and a non-Hash fallback risk, not a promise about future versions. Existing
  redactor/span scrubber remain secondary; no Sentry changes or broad redactor redesign.
- Check installed gem source, initializer and actual synthetic in-memory exported attributes;
  [redactor tests](../../test/unit/security/observability_redactor_test.rb) and
  [span scrubber tests](../../test/unit/security/observability_span_scrubber_test.rb) cover their
  own behavior. Full ActionMailer allowlist capture tests are planned where absent; source config
  alone cannot establish the dynamic export boundary. No live collector is used.

## MAIL-4 — Collector secondary defense

- Basis: O05/O07. Given Rails primary controls, feed synthetic prohibited mail
  subject/address/cc/bcc/ body/MIME/raw/args/OTP/token attributes to an authorized isolated local
  collector validation path: secondary deletion removes them while the
  Rails→OTLP→Alloy→Tempo/Prometheus topology remains.
- Syntax must be supported by the actual pinned Alloy version; the preparation's v1.19.2 is
  historical. Startup config loading remains; no management/reload API/port, SIGHUP sender or Rails
  config notifier. Collector protection is not permission for Rails to export secrets first.
- Check podman/alloy/config.alloy, Compose pin/routing and direct local binary configuration
  validation; static syntax success and synthetic processor behavior are separate observations.
  Dynamic processor acceptance is NOT_RUN/BLOCKED if no safe local facility exists. No
  Grafana/Tempo/Loki/SES query or production verification. Do not introduce setup tests or an
  alternate verification framework.

## MAIL-5 — Host-managed read-only directory

- Basis: O06/O07. Given root-first Compose resolution, rendered configuration points core's nested
  directory mount from ./podman/alloy to /home/global/workspace/podman/alloy with read_only true,
  following existing SELinux/mount conventions. Alloy's own config source remains read-only.
- After the user's authorized rebuild/recreate, inspect effective mounts and an approved harmless
  write-denial probe: core can read but cannot modify the policy directory. Host configuration
  remains the source. No remount/protection bypass or reload machinery is introduced.
- Check `.devcontainer/compose.yaml` and root compose.yaml through direct configuration rendering
  (avoid printing secrets), then runtime inspection only when authorized/available. Declaration PASS
  does not prove runtime mount PASS. Pending recreation leaves the dynamic subcondition NOT_RUN or
  BLOCKED; it does not block isolated P3b after MAIL-1/2/3 primary controls and full gates are
  satisfied.

## MAIL-6 — Scope, future production and truthful closure

- Basis: O09–O13. Given the remediation diff and reporting, Sentry, production infrastructure,
  provider/queue architecture, mail text, Rails pin and unrelated OTP/auth behavior are unchanged by
  this workstream. E/F changes retain separate authorization; no live incident or production fix is
  claimed.
- Existing ADR/plan/docs state future predeployment acceptance: no raw mail/MIME or
  OTP/verification/ recovery/access/refresh/id secrets persisted in sinks; Rails pre-export plus
  collector defense; explicit retention/access/config-distribution policy and verification before
  deployment. Production topology remains unbuilt. Existing broader owner/security-review closure is
  not self-approved.
- Check document/code diff against initial ownership snapshot, excluded-path changes and actual
  evidence scope. Future production items are deferred, not PASS or a local dynamic verification
  claim. Document and actual application acceptance remain distinct (PROC-5/6).
