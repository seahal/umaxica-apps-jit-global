# Health Endpoints

Health endpoints return the shared runtime health contract from the `Health` service layer.

As of the 2026-09-03 text+JSON contract there are two families:

- **Text probes** (`text/plain; charset=utf-8`, `Cache-Control: no-store`, no redirect, no auth,
  no `.txt` suffix, never JSON or HTML). Each surface mounts:
  - `GET /health` — aggregate. Body is exactly four lines in a fixed order:
    ```
    status: ok
    startup: ok
    liveness: ok
    readiness: ok
    ```
  - `GET /health/startup`, `GET /health/liveness`, `GET /health/readiness` — body `"ok\n"` and
    HTTP 200 when healthy, HTTP 503 when not.
- **Machine JSON** (`application/json`, `Cache-Control: no-store`, never `text/plain` or
  `text/html`, and a non-JSON `Accept` gets `406` rather than a silent fallback). Each surface that
  exposes `/revision` also mounts:
  - `GET /api/v0/health.json` —
    `{"status":"pass|warn|fail","checks":{"startup":{"status":…},"liveness":{"status":…},"readiness":{"status":…}}}`.
    HTTP: `pass`/`warn` → 200, `fail` → 503. A readiness failure never changes the liveness entry;
    liveness stays dependency-free.
  - `GET /api/v0/revision.json` — `{"revision":"<sha>"}`, or `{"revision":null}` when unset.

The literal `.json` is part of the route path (`format: false`), mirroring the
`.well-known/jwks.json` precedent; the controllers negotiate `Accept` explicitly and never
`respond_to`. Route paths for the text probes stay singular (`resource`, not `resources`).

Every check (`Health::LivenessCheck`, `Health::ReadinessCheck`, `Health::StartupCheck`,
`Health::SnapshotCheck`) returns a `Health::CheckResult` (`app/services/health.rb`). The result
object owns serialization (`as_public_json`) and the 200/503 decision (`http_status` / `ok?`); the
controllers (`HealthCheckRendering`, `app/controllers/concerns/health_check_rendering.rb`) only
render it.

These endpoints are internal-only checkpoints for orchestrators and monitoring, not a user-facing
contract; public traffic to them is blocked at the edge. User-facing availability is served by a
separate integrated status page (external service). See
`adr/internal-health-endpoint-edge-isolation.md` and `docs/operations/health-check.md`.

## Machine JSON contract (`/api/v0/health.json`)

```json
{
  "status": "pass",
  "checks": {
    "startup": { "status": "pass" },
    "liveness": { "status": "pass" },
    "readiness": { "status": "pass" }
  }
}
```

`HealthStatusSerializer` (`app/serializers/health_status_serializer.rb`) maps the internal
vocabulary onto the wire vocabulary with an exhaustive `case` (`else → raise`, per
`generic/no-silent-fallback.mdc`):

| `Health::CheckResult#status` | wire | notes |
| --- | --- | --- |
| `:ok` | `pass` | |
| `:degraded_acceptable` | `warn` | serving degraded; HTTP stays 200 |
| `:starting` + probe tolerates it (liveness) | `warn` | HTTP 200 |
| `:starting` + probe does not (startup, readiness) | `fail` | HTTP 503 |
| `:unready` | `fail` | |

Aggregate `status` is the worst of the three: any `fail` → `fail`; else any `warn` → `warn`; else
`pass`. Startup, liveness, and readiness are mapped from three independent `Health::*Check.call`
results, so a readiness outage yields `checks.readiness.status == "fail"` and overall `fail`/503
while `checks.liveness.status` stays `"pass"`. No hostname, dependency name, exception, path, or
environment value crosses this boundary — only the two enum-bounded strings.

## Text probe status codes

Individual probes: `"ok\n"` / 200 when `result.ok?`, `"unavailable\n"` / 503 otherwise, following
`Health::StatusPolicy.http_status` — `starting` is 200 on liveness and 503 elsewhere. The `/health`
aggregate line values (`ok` / `unavailable`) come from `CheckResult#as_public_json`, not the
pass/warn/fail vocabulary.

## Revision endpoints

`GET /revision` (text) and `GET /api/v0/revision.json` (JSON) derive from one shared code path,
`Rails.application.revision&.to_s` in `ApplicationRevisionRendering#application_revision`. The
framework resolves that from `ENV["REVISION"]`, a `REVISION` file, or Git; no endpoint reads Git,
the filesystem, or the environment directly, and none fabricates a value. When the revision is
unset: the text endpoint renders `"\n"` (empty value plus the mandatory trailing newline, never
the literal word `nil`), the JSON endpoint renders `{"revision": null}`.

## Caching

Every health and revision response carries `Cache-Control: no-store`, set as a `before_action`
(`HealthCheckRendering#disable_health_response_cache`, and `MachineJsonNegotiation` for the JSON
endpoints) so it also covers the `406` returned for a non-JSON `Accept` on the machine endpoints.
A health response is a verdict about one instance at one instant: a stored `200` keeps an
orchestrator sending traffic to an instance that has since failed readiness, and a stored `503`
keeps traffic away from one that has recovered. Rails would otherwise default these to
`max-age=0, private, must-revalidate`, which permits storage.
