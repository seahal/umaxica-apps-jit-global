# Application Logging Boundary

Accepted: 2026-05-21

## Context

The application previously had a `structured_logging.rb` initializer that mixed several concerns:

- JSON formatting for the Rails application logger
- convenience methods on `Rails.event`
- forwarding `Rails.event` emissions back into `Rails.logger`
- product analytics consent filtering

This made access logs, application logs, event reporting, and analytics consent look like one
pipeline even though they have different purposes.

## Decision

Access logs stay on Lograge. Lograge owns request-completion logging and emits one normalized JSON
object per request.

Application logs use `Rails.logger`. Code that needs to write operational application logs should
call `Rails.logger.debug/info/warn/error/fatal` directly. Existing event-style application log calls
are migrated to logger calls.

Application logs are for developers and infrastructure operators. They should support debugging,
incident response, operational visibility, and failure diagnosis. They are not the authoritative
record for important business, security, compliance, or accountability events.

Purchase events, audit logs, compliance records, and similarly important events must be explicitly
specified before implementation. The specification must identify the event schema, owner, retention
expectation, and access path. Teams must consider from the start whether such events belong in a
durable datastore instead of, or in addition to, application logs.

Structured application logging should be provided by a logging gem or a dedicated logger formatter,
not by ad hoc `Rails.event` monkey patches. Until that dependency is selected, application event
messages are formatted through the small `LogEvent` helper and sent through `Rails.logger`.

`Rails.event` is not the application logging API. It may be reconsidered later for non-log event
reporting, but it must not be required for ordinary application log output.

## Consequences

- Access log shape remains controlled by `config/initializers/lograge.rb`.
- Application log output remains controlled by the configured Rails logger.
- Important purchase, audit, security, and compliance events require explicit specification and
  durable storage consideration before implementation.
- Application code no longer depends on custom `Rails.event.info/warn/error/debug/record` methods.
- Future structured logging work can replace `LogEvent` and the Rails logger formatter without
  changing the access-log pipeline.
- Product analytics consent filtering must be redesigned separately if product analytics events are
  reintroduced.

## Amendment: development logs reach Loki by file tail

Amended: 2026-09-18

The layer split above is unchanged. What changes is transport: in development, Grafana Alloy tails
the repository's log files into Loki, so the same logs are queryable beside the traces they belong
to. Nothing about who writes what moves.

```text
Lograge      -> log/development.access.jsonl -> alloy -> loki   (access logs)
Rails.logger -> log/development.log          -> alloy -> loki   (application logs)
audit / security records -> database rows                       (unchanged, never Loki)
```

Audit, security, compliance and purchase records stay database rows. Loki holds a 24h development
copy of diagnostic output and is not a record of fact; moving an authoritative record there would be
the exact mixing this ADR exists to prevent.

### Why file tail

Five transports were compared:

1. **Dedicated file + `loki.source.file`** — chosen.
2. **Reuse of the existing file logger alone** — would merge access logs into `log/development.log`,
   collapsing two layers into one Loki stream.
3. **stdout tee** — host-native Rails' stdout is a terminal on the host. A container cannot read it,
   so this works in the Dev Container and fails in the repository's primary topology.
4. **journald** — host-native Rails under `bin/dev` is not a systemd unit, and mounting the host
   journal into a container is a far larger grant than a read-only directory.
5. **OTLP logs** — the Ruby OpenTelemetry Logs SDK is not the stable, broadly instrumented path the
   traces SDK is. Adopting it because it is newer would trade a working logger contract for an
   experimental one; it stays a future option, not this change.

The file tail is the only option that works identically for host-native Rails and for Dev Container
Rails, because both write into the same repository `./log` directory, which Alloy mounts read-only.

### What this adds to the Lograge pipeline

`config/initializers/lograge.rb` keeps stdout and, **in development only**, broadcasts the same JSON
line to `log/development.access.jsonl`. Production is untouched and remains stdout-only. The access
log is a separate file from `log/development.log` precisely so the Lograge and `Rails.logger` layers
stay distinguishable in Loki (`job="rails-access"` and `job="rails-application"`).

### Capacity, rotation and retention ownership

- **Rotation** of the access log is the Rails logger's: 3 files of 16 MB, so the repository log
  directory is bounded whether or not the observability stack runs. `log/development.log` remains
  the framework's own file under the developer's control.
- **Retention** of the shipped copy is Loki's: 24h, enforced by the compactor
  (`podman/loki/loki.yaml`), matching Tempo and Prometheus.
- **Volume** is bounded on the write path by Loki's ingestion rate limits.

No log is stored a third time: Alloy keeps only tail positions, not copies.

### Labels

Loki labels carry `job`, `service_name`, `layer`, `filename`, and — for access logs — `method` and
`status` lifted from the JSON line. Deliberately not labels: `request_id`, `trace_id`, and path,
each of which would create a new Loki stream per request. They remain in the line itself, which is
forwarded unmodified, so `trace_id` still correlates a log line to its Tempo trace.

## Related

- Current operations doc: `docs/security/observability-boundary.md`
