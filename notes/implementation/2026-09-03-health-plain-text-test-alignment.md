# Health plain-text test alignment

## Context

- Original plan/spec: none; full-suite failures after the health endpoints moved to
  resourceful plain-text paths (`/health/livenesses`, `/health/readinesses`,
  `/health/startups`) and `HealthCheckRendering` stopped negotiating JSON/HTML.
- Related decisions/docs: `docs/reference/health-endpoints.md`,
  `docs/operations/health-check.md`, `openapi/shared/paths/health-*.yml`.
- Implementation date: 2026-09-03.

## Decisions Made During Implementation

- Decision: keep the application contract as plain text and update tests, OpenAPI, and
  the health reference docs to match it.
  - Why: the controllers already render `ok` / `unavailable` (and a four-line snapshot on
    `/health`). Failures were leftover JSON/HTML assertions and singular probe paths.
  - Alternatives considered: restore JSON rendering so old tests pass (rejects the
    resourceful plain-text change already in the worktree).
  - Follow-up needed: ADRs and older notes still describe JSON probes; they are
    historical and were not rewritten here.

- Decision: surface identity is asserted from routing, not from a `namespace` field.
  - Why: the public body no longer carries JSON, so every healthy probe is identical
    `ok\n`. Distinct controllers per host remain the way a misdirected `Host` is
    detectable.

## Deviations From Plan

- None.

## Review Notes

- Tests run: the health integration, controller, OpenAPI, and browser-gate files listed
  in this session.
- Tests not run: full suite (too slow to repeat here unless those files pass first).
- Documentation promotion: `docs/reference/health-endpoints.md` and
  `docs/operations/health-check.md` were updated to the current paths and media type.
  `pnpm openapi:bundle` must be run so `public/openapi.*.yml` matches `openapi/`.
