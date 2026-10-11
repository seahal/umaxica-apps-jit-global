# Active Plan Serial Completion Notes

## Context

- Original plan/spec: `plans/active` serial completion request.
- Related decisions/docs/plans:
  - `plans/README.md`
  - `adr/acme-sign-core-base-port-boundary.md`
- Implementation date: 2026-06-14

## Decisions Made During Implementation

- Decision: Treat `plans/active` strictly as currently implementable or currently verifying work.
  - Why: The directory contained completed, superseded, inventory-only, and future-gated plans that
    made the active set look larger than the implementable set.
  - Follow-up needed: Continue moving completed plans to `plans/archive` and future-gated plans to
    `plans/backlog` as each active item is completed or blocked by a source-of-truth decision.

- Decision: Move publication work to backlog.
  - Why: `docs/architecture/regional-content.md` and the plan itself say regional content delivery
    is outside this repository until a current ADR changes that boundary.
  - Follow-up needed: Re-promote only after an ADR decides repository, routing, and storage
    ownership.

- Decision: Implement CSP report intake as a service behind the existing public bare controllers.
  - Why: The existing controller concern logged raw report fields directly. The active plan required
    defensive parsing, sanitization, classification, and structured aggregation.
  - Follow-up needed: Re-run focused CSP tests after the test DB host and fixture cleanup state are
    stable.

## Deviations From Plan

- Change: The CSP plan remains in `plans/active` after implementation.
  - Why: Focused verification was blocked by local test DB instability after one run reached the
    test assertions.
  - Risk: The implementation has only syntax checks plus a partially completed focused Rails run in
    this checkout.
  - Follow-up: Run the focused tests and archive the plan when they pass.

## Review Notes

- Tests run:
  - `ruby -c app/services/csp_violation_report_intake.rb`
  - `ruby -c app/controllers/concerns/csp_violation_report.rb`
  - `ruby -c test/services/csp_violation_report_intake_test.rb`
  - `ruby -c test/controllers/csp_violation_reports_controller_test.rb`
  - `bin/rails test test/services/csp_violation_report_intake_test.rb test/controllers/csp_violation_reports_controller_test.rb`
  - `PARALLEL_WORKERS=1 bin/rails test test/services/csp_violation_report_intake_test.rb test/controllers/csp_violation_reports_controller_test.rb`
  - `bin/rails test test/integration/health_endpoints_test.rb`
  - `bin/rails test test/integration/read_only_surfaces_test.rb test/controllers/public_robots_routing_test.rb test/controllers/controller_base_inheritance_test.rb test/controllers/controller_inheritance_invariant_test.rb`
  - `bin/rails test test/services/csp_violation_report_intake_test.rb test/controllers/csp_violation_reports_controller_test.rb`
  - `bin/rails test test/models/concerns/occurrence/hmac_test.rb test/services/security/token_lifetimes_test.rb test/services/sign/risk/engine_test.rb`
- Tests not run:
  - Full suite.
  - Administrative access lock focused tests to completion.
- Blocking details:
  - `RAILS_ENV=test bin/rails db:prepare` failed because host `primary` could not be resolved.
  - The first focused CSP Rails run later hit fixture cleanup deadlock/foreign-key state.
  - The second focused CSP Rails run failed before tests because host `primary` could not be
    resolved.
  - Later administrative access lock focused tests reached stale parallel test database clones and
    failed before assertions with missing tables such as `app_preference_binding_methods` and
    `clients`.

## Completion Update

- Archived after focused verification:
- Archived after medium cleanup implementation:
- Medium cleanup status:
  - Docs/news/help Rails routes now expose thin roots and `/api/v0/entries` read APIs.
  - Rails-owned docs/news/help public HTML entries routes, old `edge/v0/entries` routes, and unused
    docs/news/help robots controllers were removed.
  - Sign/Acme boundary plan was corrected for current state: Acme welcome route duplication is gone,
    `welcome_entry` helper compatibility stays, and Acme preference screen helper compatibility is
    intentionally preserved.
  - `plans/backlog/sign-acme-boundary-remediation.md` was demoted to backlog after completing the
    medium cleanup slice; remaining Sign route retirement is human-review-gated.
- Remaining active blocker:
  - GH issue #830 still needs a reachable, prepared test database before schema dump and focused
    verification can close.
  - Focused medium-cleanup tests could not complete because the local test DB host `primary` is not
    resolvable in this environment.
