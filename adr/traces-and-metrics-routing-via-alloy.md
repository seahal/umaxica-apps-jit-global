# Traces and Metrics Routing via Alloy

Accepted: 2026-05-28

## Context

The repository ships a `compose.yaml` that already includes `tempo`, `prometheus`, `grafana`,
`loki`, and an `alloy` service, plus a separate `otel-collector` service. The Rails application has
`opentelemetry-sdk`, `opentelemetry-exporter-otlp`, and `opentelemetry-instrumentation-all` declared
in `Gemfile` with `require: false`. None of these are wired up: no initializer exists, no span has
ever been exported, and the two agents (`alloy` and `otel-collector`) duplicate roles with no
documented split.

Logs are out of scope for this decision. Application log policy is owned by
`application-logging-boundary.md`. Rails logs continue to be emitted to stdout.

Three boundaries already shape this design:

- The `app` / `com` / `org` surface separation must be preserved end-to-end; mixing surfaces is
  forbidden by `AGENTS.md`.
- PII, cookies, authorization headers, session ids, DBSC device ids, OTP codes, and step-up tokens
  must never leave the process inside telemetry payloads.
- The Rails container runs multiple process roles under `bin/dev` (web, jobs, scheduler). Their
  performance characteristics differ and must not be aggregated.

## Decision

### Single observability agent

Alloy is the only observability agent in this repository. The `otel-collector` service is retired.
All Rails OTLP traffic is sent to `alloy` on the `observability` docker network.

This decision originally also required the Rails container's `depends_on` to point at `alloy` rather
than `otel-collector`. That requirement is withdrawn; see "Amendment: `core` declares no dependency
on the agent" below. `core` declares no `depends_on` entry for any observability service.

### Routing

- Traces: Rails OTLP exporter → Alloy OTLP receiver → Tempo → Grafana.
- Metrics: Rails-emitted metrics use OTLP push to Alloy. Infrastructure-owned metrics (Postgres,
  Valkey, Kafka, container stats) are exposed by purpose-built exporters and scraped by Alloy. Alloy
  then writes everything to Prometheus via `prometheus.remote_write`. Grafana reads from Prometheus.
- Logs: out of scope. Rails continues to write to stdout. Future migration to Alloy → Loki is
  tracked separately and explicitly not addressed here.

### Phased environment scope

The first phase targets **development only**.

- `development`: OpenTelemetry SDK enabled, OTLP exporter pointing at `alloy:4318`, sampler at 1.0,
  all selected instrumentations enabled.
- `test`: OpenTelemetry SDK fully disabled via `OTEL_SDK_DISABLED=true` and an initializer
  early-return. No exporter, no batch processor, no background threads.
- `production`: deferred. Production wiring is not part of this ADR and must be introduced by a
  follow-up ADR that addresses sampling, retention, multi-instance service identity, and PII review
  on the live data path.

### Service identity

`service.name` is assigned per process role, not per Rails application. Initial allocation:

- `umaxica-core-web` — Puma / Rails server
- `umaxica-core-jobs` — Solid Queue worker
- `umaxica-core-scheduler` — Solid Queue dispatcher
- `umaxica-core-console` — Rails console / runner (SDK disabled by default)

Resource attributes always include:

- `service.namespace=umaxica`
- `service.instance.id` (hostname or pod identity)
- `deployment.environment` (`development` initially; `test` disables SDK)
- `service.version` from the build `COMMIT_HASH`

Surface (`app` / `com` / `org`) is **not** part of `service.name`. It is recorded as a span
attribute (`umaxica.surface`) so that surface boundary remains a request-level concern and does not
fragment the service catalog.

### Instrumentation policy

`opentelemetry-instrumentation-all` is loaded but `use_all` is forbidden. Instrumentations are
enumerated explicitly (`c.use 'OpenTelemetry::Instrumentation::Rack'`, etc.) so that any new
instrumentation entering the dependency graph requires an explicit code change. `db.statement`
capture remains on the SDK default — placeholders only, never bind values.

### PII redaction is two-stage

Personally identifiable and security-sensitive data must not reach storage even if a single
configuration mistake occurs. Redaction runs in two independent places:

1. **In-process SpanProcessor** in the Rails application. It strips cookie headers, authorization
   headers, set-cookie, URL query strings, and known sensitive attributes before the span is handed
   to the exporter. This is the application's responsibility: data leaves the process already
   cleaned.
2. **Alloy processor** (`otelcol.processor.attributes` and/or `otelcol.processor.transform`). It
   re-applies redaction on the agent side as defense in depth. New instrumentations that forget to
   filter, or future attribute additions in upstream gems, are caught here.

Both stages must be kept in sync. The list of redacted attribute keys lives in code and in Alloy
configuration; divergence is treated as a defect.

### Process and compose layout

- The observability service group (`alloy`, `tempo`, `prometheus`, `grafana`, `loki`) runs on a
  plain `up`. It was originally gated behind a compose profile; that gating was removed on
  2026-08-31 so that every developer gets the same telemetry without opting in, which is also what
  makes a trace reproducible from one machine to another. See the amendment below.
- Tempo, Prometheus, and (later) Loki must have explicit retention configured. Unbounded retention
  on local volumes is treated as a misconfiguration.
- The Tempo container's host port publication exists only for direct inspection during bring-up.
  Application traffic always goes via Alloy. Once the routing is stable, the Tempo host publication
  is removed.
- Grafana provisioning is mounted read-only. Default credentials are taken from environment
  variables, not committed defaults, and the admin credentials are treated as development-only.

### Request identifier preservation

The three correlation identifiers have separate authorities:

- `request_id` is the HTTP request correlation identifier managed by Rails
  `ActionDispatch::RequestId`. An incoming `X-Request-ID` may be preserved by Rails; otherwise Rails
  generates one.
- `trace_id` is the OpenTelemetry/W3C Trace ID read from a valid current `SpanContext`.
- `span_id` is the OpenTelemetry Span ID read from that same valid current `SpanContext`.

`request_id` must never be substituted for `trace_id` or `span_id`. The access log retains the
request identifier and includes the OpenTelemetry identifiers only when a valid current span exists.
OpenTelemetry being disabled therefore leaves `trace_id` and `span_id` absent or null; it does not
cause Rails to manufacture a tracing context.

`trace_id` remains the primary key for traces in Tempo. Each span carries the request_id as an
attribute where the existing instrumentation provides it. Rails request-completion access logs
surface the current trace/span identifiers without making them part of the authentication or audit
authority.

OpenTelemetry is technical/operational telemetry. Product analytics consent, including the optional
`performant` preference, does not alter the presence or value of technical trace/span correlation
identifiers.

In preparation for the eventual logs migration, Rails stdout output is expected to include
`trace_id` and `request_id` even though logs are not currently shipped to a backend. This keeps the
future Loki migration limited to agent configuration.

## Consequences

- The `otel-collector` service is removed from `compose.yaml`. `core` gains no `depends_on` entry in
  its place, per the amendment below.
- A development-only initializer is introduced that configures the SDK, the OTLP exporter, the
  in-process PII redaction SpanProcessor, and an explicit instrumentation allow-list. `test`
  short-circuits this initializer.
- Process roles under `bin/dev` (and equivalent production launchers) set `OTEL_SERVICE_NAME` per
  role. Mixing process roles into a single service identity is a regression.
- Alloy configuration carries the second redaction stage. Adding a new attribute on the application
  side requires reviewing whether Alloy's redaction list needs to be updated.
- The Tempo and Prometheus retention settings are required configuration, not optional tuning.
  Volumes without retention are treated as a bug.
- Metrics work is scoped to a follow-up change. Traces are landed first; metrics are introduced
  after the trace path is stable.
- A production rollout requires a new ADR. This decision does not authorize enabling the SDK outside
  development.

## Amendment: `core` declares no dependency on the agent

Amended: 2026-08-31

The original decision required two things that cannot both hold in Compose:

1. "The Rails container's `depends_on` points at `alloy`."
2. "The observability service group is gated behind a docker compose profile so that contributors
   not working on observability can run the application stack without it."

`core` carried no profile and started on a plain `up`, while `alloy` did not. A `depends_on` entry
naming a service that no active profile selects is a resolution error, not a silently ignored edge:
the dependency has no container to wait for. Honouring (1) therefore meant either pulling the whole
observability group into every developer's default `up`, which is what (2) existed to prevent, or
leaving `core` unstartable without `--profile observability`.

**(2) won, and then (2) itself was withdrawn.** The profile gating was removed on 2026-08-31; the
observability group now starts on a plain `up` alongside `core`. The `depends_on` requirement is
still not reinstated, for a different reason: it buys nothing.

`depends_on` orders container startup; it does not make the OTLP exporter's first export succeed.
The Ruby exporter is asynchronous and retries, so a `core` that starts before `alloy` loses at most
the spans buffered during the gap. There is no readiness relationship worth encoding, and adding one
would only slow every boot.

`OPEN_TELEMETRY` is `"true"` on `core` in `compose.yaml`, because `alloy` is now always there to
receive. The initializer still gates on it and still defaults to off, because `core` also runs
outside Compose -- a host `bin/rails`, a CI job, a one-off `podman run` -- where no agent exists and
an unresolvable `alloy` would otherwise produce a steady trickle of exporter retry warnings.

Before this, `OPEN_TELEMETRY` was declared in `compose.yaml` but read nowhere, so the SDK
initialised on every development boot regardless. The initializer now honours the variable.

This narrows the "development: OpenTelemetry SDK enabled" line in "Phased environment scope" above:
the SDK is available in development and off until asked for, because the agent it exports to is
itself opt-in. Turning both on is one command.

## Amendment: the gateway is completed, and host-native Rails is its first client

Amended: 2026-09-18

The original decision named Alloy the single agent but left three gaps that together meant no signal
ever reached storage from the repository's primary development topology — host-native Rails with
`podman compose` infrastructure.

**1. Alloy had no host ingress.** Its OTLP receivers existed only on the `observability` network, so
`alloy:4318` was unresolvable from a host `bin/dev`. The OTLP/HTTP receiver is now published as
`127.0.0.1:4318`, and nothing else is: OTLP/gRPC (4317) has no host-side client and the Alloy
management UI (12345) is an unauthenticated control surface. The endpoints are therefore:

```text
Compose `core`      OTEL_EXPORTER_OTLP_ENDPOINT=http://alloy:4318
host-native Rails   OTEL_EXPORTER_OTLP_ENDPOINT=http://127.0.0.1:4318   (the exporter default)
```

Neither is written into `config/initializers/opentelemetry.rb`. The endpoint is deployment
configuration read by the exporter from the environment; hardcoding a development address there
would also decide it for production, which this ADR does not authorize.

**2. Grafana had no host publication**, so the stack could not be read at all from a host browser.
Grafana is published on `127.0.0.1:13000` — the upstream container port `3000` is unchanged; only
the host side moves, because 3000 and 3001 belong to host-native and Dev Container Rails. Grafana
stays on the `observability` network alone, so it is reachable from this machine's browser and from
nowhere else: not the LAN, not Cloudflare Tunnel, not Tailscale. Its admin credentials remain
development-only environment values and assume exactly that boundary.

**3. Tempo was not actually receiving.** `podman/tempo/tempo.yaml` declared `otlp: protocols: grpc:`
with no endpoint. The embedded OpenTelemetry Collector receiver defaults to `localhost:4317`, which
binds the Tempo container's loopback, so Alloy's exports failed with `connection refused` and every
trace was dropped after its retry budget. The endpoints are now explicit `0.0.0.0` binds. The Jaeger
and Zipkin receivers are removed with the same change: nothing sent to them, and each was an
ingestion path into storage that bypassed the agent-side redaction stage this ADR requires.

The Grafana datasources now declare deterministic UIDs (`loki`, `tempo`, `prometheus`). Grafana
otherwise generates one per installation, and `tracesToLogsV2.datasourceUid: loki` then names a UID
that resolves only on the machine the reference was written on. Provisioning also deletes the three
datasources by name before recreating them, because Grafana matches an existing row by UID and exits
`1` — taking the whole service down — when a provisioned UID does not match the row it finds.

Logs are no longer out of scope; see the amendment to `adr/application-logging-boundary.md`. Alloy
tails development log files into Loki, which makes Alloy the single gateway for all three signals
rather than for two of them.

Retention is bounded for all three backends: Tempo 24h (`block_retention`), Prometheus 24h
(`--storage.tsdb.retention.time`), and now Loki 24h (`podman/loki/loki.yaml`, with
`compactor.retention_enabled: true` — without that flag the retention period is advisory and chunks
are kept forever, which is what the packaged `local-config.yaml` did).

**Metrics remain limited to agent and backend self-monitoring.** Alloy scrapes its own metrics and
Prometheus scrapes its own; there is no Ruby `MeterProvider` in the initializer, so there are no
Rails application metrics. Verified rather than assumed on 2026-09-18: `alloy_build_info` and
`up{job="prometheus"}` return series; nothing Rails-shaped does. A Ruby metrics SDK is not adopted
here on the strength of the traces path alone, and no `tracesToMetricsV2` correlation is provisioned
because it could only ever render an empty panel. Rails application metrics stay a follow-up.

The completed development topology:

```text
host-native Rails --OTLP/HTTP--> 127.0.0.1:4318 --> alloy --> tempo       (traces)
repository ./log  --file tail (read-only bind)---> alloy --> loki        (logs)
                                                   alloy --> prometheus  (metrics: agent self only)
browser --> 127.0.0.1:13000 --> grafana --> tempo / loki / prometheus
```

## Related

- `adr/application-logging-boundary.md` — log path is owned separately and is not changed by this
  decision.
- `adr/cookie-domain-scope-by-surface.md`, `adr/device-session-dbsc-device-id-boundary.md`,
  `adr/signed-return-targets-only.md` — sources of attribute names and values that must never appear
  in telemetry payloads.
- `plans/backlog/audit-log-write-points-and-otel-mapping.md` — informs the eventual span-attribute
  naming for audit-relevant events.
