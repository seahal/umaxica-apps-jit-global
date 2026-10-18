# Health Endpoint Contract Redesign Notes

Status: implementation note for the completed health endpoint redesign.

Scope: migrate the flat `Health*` service classes to the namespaced `Health::` service layer, unify
the probe contract on `/health/liveness|readiness|startup`, and render every response from a single
`Health::CheckResult`. Applied across every surface (acme/base/core/docs/help/news/palm app/com/org,
acme net/dev, sign app/com/org) — 98 health routes. The service layer is implemented in the flat
`app/services/health.rb` file to satisfy the repository source-layout invariant.

## Deviations and non-obvious decisions

- **Singular controller names via the `controller:` route option.** The spec mandates singular
  controllers (`HealthController`, `Health::LivenessController`), which diverges from the prior
  Rails-default plural convention (`HealthsController`, `Health::LivesController`). `resource`
  pluralizes the controller by default, so each route declares it explicitly, e.g.
  `resource :liveness, only: :show, controller: "liveness"` in `config/routes/{acme,sign,core}.rb`.

- **`details` carries the metadata that does not fit the four fixed top-level keys.** The public
  contract fixes the top level to `status / check / dependencies / details`. The useful `surface` /
  `revision` / `generated_at` fields from the old contract — plus the internal status vocabulary
  when a result is degraded — are parked under `details`. The spec examples show `details: {}` for
  brevity; populating it does not break the four-key contract.

- **Two-state public `status`, richer internal vocabulary preserved.** `Health::CheckResult`
  collapses the internal statuses (`ok`, `degraded_acceptable`, `unready`, `starting`;
  `Health::STATUSES`) to public `"ok"` / `"unavailable"` at the top level, while keeping the exact
  internal status in `details.status` when not `:ok`. The HTTP 200/503 mapping is unchanged from the
  old `HealthStatusPolicy`: `ok`/`degraded_acceptable` → 200, `unready` → 503, `starting` → 503
  except on liveness (→ 200).

- **`DependencyResult`, not `Check::Result`.** The per-dependency unit is named
  `Health::DependencyResult` to avoid colliding with the per-check `Health::CheckResult`.

- **Flat rendering concern.** The controller rendering concern is `HealthCheckRendering` in
  `app/controllers/concerns/health_check_rendering.rb`. It deliberately stays outside the `Health::`
  namespace because controller concerns are required to use flat top-level constants.

## Legacy removal and security boundary

- `/health/live` and `/health/ready` were removed outright — no compatibility shim. They had no
  in-repo consumers; infrastructure probe configs (outside this repo) must cut over to `liveness` /
  `readiness` before deploy. `test/integration/edge_health_routes_test.rb` guards against
  reintroduction on any surface (alongside the already-retired `/edge/v0/health` and
  `/web/v0/health`).

- **`error_class` omitted from readiness failures by decision.** A failed dependency surfaces only
  the non-sensitive public status (`{ "database": "failed" }`). Exception classes, messages, and
  topology are never serialized, preserving `docs/security/observability-boundary.md`. Failures are
  logged server-side (see `Health::Checks::Database`), not exposed in the response body.

## Verification

Test DB must be current before running (the suite errors in fixture loading otherwise): run
`bin/rails db:test:prepare` first. Health coverage: `test/services/health_test.rb`,
`test/integration/health_endpoints_test.rb`, `test/integration/health_check_test.rb`,
`test/integration/edge_health_routes_test.rb`,
`test/controllers/acme/app/health_controller_test.rb`.
