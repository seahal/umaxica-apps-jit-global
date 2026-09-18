# Alloy Single-Gateway Observability Bring-Up

Date: 2026-09-18
Scope: root `compose.yaml` observability group, host-native topology.

Everything below was executed in this session on the development host (rootless Podman, Compose
project `umaxicaappsglobaldc`). Only the observability services were started; the datastore services
were left stopped.

## Commands

```sh
podman compose config                                   # exit 0
podman compose up -d loki tempo prometheus alloy grafana
podman ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
ss -lntp | grep -E ':(13000|4318|4317|12345|3100|9090|3200)'
ruby -Itest test/tooling/compose_host_port_exposure_test.rb        # 6 runs, 16 assertions, 0 failures
ruby -Itest test/tooling/observability_gateway_contract_test.rb    # 7 runs, 35 assertions, 0 failures
```

## Host listeners

```text
LISTEN 127.0.0.1:4318    rootlessport   (alloy OTLP/HTTP)
LISTEN 127.0.0.1:13000   rootlessport   (grafana)
```

Those two lines are the complete match set for the pattern above. No `0.0.0.0` and no LAN address
appears for any observability port; `tempo`, `prometheus` and `loki` show no host mapping in
`podman ps`.

## Grafana

`GET http://127.0.0.1:13000/api/health` → `200 {"database":"ok","version":"13.2.0"}`.

`GET /api/datasources` → three datasources with the provisioned UIDs, each `/health` `200`:

| name       | uid          | url                     | health                                    |
| ---------- | ------------ | ----------------------- | ----------------------------------------- |
| Loki       | `loki`       | http://loki:3100        | `Data source successfully connected.`     |
| Prometheus | `prometheus` | http://prometheus:9090  | `Successfully queried the Prometheus API.` |
| Tempo      | `tempo`      | http://tempo:3200       | `Data source is working`                  |

## Traces

An OTLP/HTTP export was posted from the **host** to `http://127.0.0.1:4318/v1/traces` — the exact
endpoint host-native Rails uses — and read back through Grafana's Tempo proxy:

```text
POST /v1/traces                              -> 200 {"partialSuccess":{}}
GET  /api/datasources/proxy/uid/tempo/api/traces/<trace id> -> 200, span "GET /verification"
```

The span was sent carrying four attributes. Tempo stored one:

```text
sent:   http.method, http.url (with ?token=...), http.request.header.authorization, cookie
stored: http.method
```

The agent-side redaction stage deleted the URL, the authorization header and the cookie. This is a
positive check of the second redaction stage, not only of the transport.

## Logs

Marker lines were appended to `log/development.log` and `log/development.access.jsonl` and queried
back through Grafana's Loki proxy:

```text
{job="rails-application"} -> 1 stream, labels {job, service_name, layer=application, filename}
{job="rails-access"}      -> 1 stream, labels {job, service_name, layer=access, filename, method=GET, status=200}
```

Both layers arrive, separately labelled, with the access line's `method`/`status` lifted by the
JSON stage. The lines themselves are forwarded unmodified.

## Metrics

Queried through Grafana's Prometheus proxy:

```text
up{job="prometheus"}                            -> 1 series
alloy_build_info                                -> 1 series
alloy_component_controller_running_components   -> 1 series
loki_build_info                                 -> 0 series
```

Agent and Prometheus self-monitoring only. There is no Ruby `MeterProvider` in
`config/initializers/opentelemetry.rb`, so **no Rails application metric exists**, and none was
fabricated to make a panel look populated.

## Defects found and fixed during bring-up

1. **Tempo was not receiving at all.** `podman/tempo/tempo.yaml` declared `otlp: protocols: grpc:`
   with no endpoint. The embedded collector receiver defaults to `localhost:4317`, binding the Tempo
   container's own loopback, so Alloy's every export failed:
   `dial tcp 10.89.1.3:4317: connect: connection refused`. Fixed with explicit `0.0.0.0` endpoints;
   the trace above is the proof it now lands. Pre-existing, and invisible while nothing exported.
2. **Grafana exited 1 on startup** after the datasource UIDs were pinned:
   `Datasource provisioning error: data source not found`. Grafana matches an existing row by UID,
   and `grafana-volume` already held rows with generated UIDs. Fixed with a `deleteDatasources:`
   block, which converges from either state and is a no-op on a fresh volume.
3. **Alloy skipped the access log permanently.** A literal `loki.source.file` target for a file that
   does not exist logs `failed to create source, skipping` and never retries — the normal state
   before Rails has ever run. Fixed by discovering both files through `local.file_match`
   (`sync_period = "15s"`).

## Not verified

Host-native Rails was **not** started: `bundle exec` fails on this host (the bundle is deliberately
incomplete here — the host does not run Rails). The host-side OTLP endpoint, the Loki file
transport and the Grafana path were therefore exercised with synthetic payloads written to the same
endpoints and the same files Rails writes. What remains unverified is only the Rails-side half:
that the SDK initialises under `OPEN_TELEMETRY=true` and that Lograge writes
`log/development.access.jsonl`. Neither the Compose topology nor the ingestion path depends on the
machine it is checked from.
