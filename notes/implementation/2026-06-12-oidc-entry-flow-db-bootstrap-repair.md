# OIDC Entry Flow DB Bootstrap Repair Implementation Notes

## Context

- Original plan/spec: latest OIDC Entry Flow Audit and the current OIDC/Sign boundary plan in the
  conversation.
- Related ADR/docs/plans: `adr/sign-residual-idp-surface-retirement.md`,
  `docs/identity/authority-boundary.md`.
- Implementation date: 2026-06-12.

## Decisions Made During Implementation

- Rebuilt the test database set with
  `RAILS_ENV=test bin/rails db:drop db:create db:migrate db:schema:dump`.
  - Why: `db:prepare` had left the chronicle database without the `app_preference_chronicle_*`
    tables because `db/chronicle_structure.sql` was stale/empty.
  - Alternatives considered: patching the missing table in place or hand-editing the SQL dump.
    Rebuilding from migrations was safer and restored all multi-DB schema dumps consistently.
  - Follow-up needed: keep the regenerated `db/*_structure.sql` files in sync with future schema
    work.

- Removed stale sign verification session constants from the surface-local verification concerns and
  their tests.
  - Why: those constants were no longer referenced after the OIDC/Sign boundary rewrite and were
    keeping the old session-key topology alive in tests.
  - Alternatives considered: keep compatibility aliases. Rejected because they preserved the stale
    boundary and complicated the new transaction-backed flow.
  - Follow-up needed: none unless another consumer reintroduces the old keys.

- Updated `db/seeds.rb` to use the current MFA model names.
  - Why: test database bootstrap failed with stale `ClientMultiFactor` / `VisitorMultiFactor` /
    `OperatorMultiFactor` constants.
  - Follow-up needed: none beyond normal seed maintenance.

## Deviations From Plan

- The plan called for continuing the OIDC/step-up implementation work, but the first blocker was a
  broken multi-DB test bootstrap rather than application logic.
  - Why: the chronicle schema dump was stale enough that targeted tests could not load
    fixture-backed models.
  - Risk: regenerating the schema dumps touched many `db/*_structure.sql` files, but that change is
    consistent with the current migrations and was required to make the test DB usable.

## Review Notes

- Tests run:
  - `RAILS_ENV=test bin/rails db:drop db:create db:migrate db:schema:dump`
  - `bin/rails test test/controllers/concerns/sign/app_verification_base_included_do_test.rb test/controllers/concerns/sign/com_verification_base_test.rb test/controllers/concerns/sign/org_verification_base_included_do_test.rb test/services/step_up/configured_methods_test.rb test/services/step_up/available_methods_test.rb`
  - `bin/rails test test/integration/oidc_rp_browser_flow_test.rb test/controllers/acme/oauth_oidc_authority_test.rb`
- Tests not run:
  - Full repository test suite.
- Documentation or ADR promotion needed:
  - None from this repair. The boundary behavior is already covered in the existing docs/plan set.
