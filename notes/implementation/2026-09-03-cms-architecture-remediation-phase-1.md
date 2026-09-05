# CMS Architecture Remediation Phase 1 Implementation Notes

## Context

- Original plan/spec: Phase 1 implementation prompt (CMS architecture remediation).
- Related decisions/docs/plans: `adr/publishing-db-content-authority.md`,
  `docs/architecture/docs-help-news-content-boundary.md`, `docs/operations/db-workflow.md`.
- Implementation date: 2026-09-03

## Decisions Made During Implementation

- Decision: Entra OmniAuth registration is skipped in local environments when the client secret is
  absent; production still raises `KeyError`.
  - Why: publishing tests must boot without an unused IdP credential; production validation must
    not weaken.
  - Alternatives considered: fake production secrets (forbidden); always-register with blank secret
    (would hide a broken entra provider).
  - Follow-up needed: none for Phase 1.

- Decision: create empty `db/searches_migrate` and `db/storages_migrate` rather than retargeting
  `database.yml`.
  - Why: those paths are the configured owners; the databases are reserved and empty.
  - Alternatives considered: removing the connections. Rejected — ADR keeps storage reserved.
  - Follow-up needed: none.

- Decision: treat migrations as reconstruction authority; leave stub `*_structure.sql` files in
  place.
  - Why: every environment sets `dump_schema_after_migration = false`; dumps contain no tables.
    Regenerating 21 populated dumps is a separate architecture/ops decision.
  - Follow-up needed: decide whether to regenerate dumps or stop committing stubs.

- Decision: Edge 12-cell configuration extraction is deferred after inspecting
  umaxica-apps-edge@6cd77c4422ed85c51e6014de550d628e2e4764b2.
  - Why: VPC binding and service ids already live in `tools/workers-manifest.json`. Per-cell
    `PRIVATE_RAILS_ORIGIN` values are the Host-header dispatch contract. Extracting
    `rails-client.ts` into a shared package would change twelve Worker bundles. Astro is
    juxtaposed and not deployed; a shared-module refactor now would collide with that
    migration.
  - Follow-up needed: after Astro cutover or an explicit shared-client ADR.

## Deviations From Plan

- Change: no Edge code changes.
  - Why: Edge checkout is not present; wiring CMS consumption is forbidden in this phase anyway.
  - Risk: matrix documentation describes Edge units at the logical level only.
  - Follow-up: Edge maintainers confirm TanStack Start and per-cell hosts against the Edge repo.

## Review Notes

- Tests run: listed in `evidence/2026-09-03-cms-architecture-remediation-phase-1.md`.
- Tests not run: full `bin/rails test`; Edge unit/lint/build (repository absent).
- Documentation promotion needed: none beyond the docs already updated in this change.
