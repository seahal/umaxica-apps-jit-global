# Read-Only Content Surfaces And Sign/Acme Remediation Notes

## Context

- Original plans:
  - `plans/backlog/sign-acme-boundary-remediation.md`
- Related decisions:
  - `adr/acme-sign-core-base-port-boundary.md`
  - `adr/read-only-content-surfaces-in-rails.md`
  - `docs/architecture/regional-content.md`
- Implementation date: 2026-06-13

## Decisions Made During Implementation

- Decision: `docs`, `news`, and `help` are implemented as v1 read-only content surfaces in this
  Rails repository.
  - Why: the user explicitly requested the full content implementation from the active plan.
  - Follow-up needed: promote any future CMS, taxonomy, revision/version, or OIDC RP behavior into a
    separate ADR before implementation.

- Decision: v1 content entries use the existing surface zenith databases.
  - Why: the user selected zenith placement during planning.
  - Risk: this extends zenith beyond account/subject projection storage.
  - Follow-up needed: consider dedicated `app_content`, `com_content`, and `org_content` connections
    if content delivery grows beyond the lean read model.

- Decision: Sign org top-level management placeholders now redirect to Acme org authority.
  - Why: `adr/acme-sign-core-base-port-boundary.md` assigns account/org/control-plane authority away
    from Sign.
  - Follow-up needed: decide whether these Acme org targets later move to Base.

## Deviations From Plan

- Change: Acme preference route enumeration was not replaced with a single parametric route.
  - Why: many existing views/tests call screen-specific route helpers such as
    `edit_acme_app_preference_theme_url`; removing them would create broad compatibility churn.
  - Risk: route cleanup remains incomplete.
  - Follow-up: add an explicit helper compatibility layer before collapsing those routes.

- Change: `db:verify_no_schema_drift` was run and reported drift while structure files were
  intentionally modified but not committed.
  - Why: the verifier compares generated schemas against the git baseline.
  - Risk: none if `db/app_zenith_structure.sql`, `db/com_zenith_structure.sql`, and
    `db/org_zenith_structure.sql` are included with the migration.

## Review Notes

- Tests run:
  - `RAILS_ENV=test bin/rails db:migrate`
  - `bin/rails routes`
  - focused surface/content/redirect/inheritance/health tests: 46 runs, 1093 assertions, passing
  - `bin/rails test test/controllers/acme test/controllers/sign`
- Tests not fully passing:
  - The broad Acme/Sign controller suite reported existing fixture/JUMP redirect and stale
    expectation failures outside the focused changes. It also includes expectations for Sign-local
    authority behavior intentionally changed by this slice.
- Documentation promotion needed:
  - If content editing, taxonomy, import format stability, or Base ownership becomes product
    behavior, move it from plans/notes into stable docs or ADRs.
