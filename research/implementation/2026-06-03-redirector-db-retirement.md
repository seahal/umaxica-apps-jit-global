# Redirector Database Retirement Implementation Notes

## Context

- Original plan/spec: remove the unused `redirector` database.
- Related ADR/docs/plans:
  - `adr/secure-jump-link-redirector.md`
  - `docs/architecture/database-boundaries.md`
  - `plans/backlog/jwt-jwks-security-review-followups.md`
- Implementation date: 2026-06-03

## Decisions Made During Implementation

- Decision: delete the `redirector` / `redirector_replica` database connections, migrations, and
  empty schema dump.
  - Why: the accepted jump redirector ADR says this Rails app must not expose DB-backed JumpLink
    models or lifecycle behavior, and the current `redirector_structure.sql` contains no application
    tables.
  - Alternatives considered: keep the empty database as a placeholder. Rejected because the ADR
    explicitly retired DB-backed redirect records.
  - Follow-up needed: decommission any physical `*_redirector_db` instances and credentials outside
    Rails after confirming no other deployment component uses them.

## Deviations From Plan

- Change: no drop migration was added.
  - Why: removing the connection means Rails will no longer manage the database, and the schema dump
    was already empty. Physical database deletion is an operations task, not a Rails migration.
  - Risk: external infrastructure may still define redirector DB credentials until cleaned up.
  - Follow-up: remove deployment secrets/env vars for `POSTGRESQL_REDIRECTOR_*` and
    `DATABASE.REDIRECTOR*` after rollout.

## Review Notes

- Tests run:
  - `bin/rails runner 'names = ActiveRecord::Base.configurations.configs_for(env_name: Rails.env).map(&:name); puts names.grep(/redirector/).inspect'`
  - `bin/rails routes -g redirector`
  - `RAILS_ENV=test bin/rails db:migrate`
  - `bin/rails test test/config/routing_entrypoints_test.rb`
- Tests not run:
  - Full suite was not run.
  - `bin/rails db:verify_no_schema_drift` was not rerun after this change because the previous run
    exposed unrelated chronicle schema formatting drift.
- Documentation or ADR promotion needed:
  - No new ADR needed; this implements the accepted `secure-jump-link-redirector` direction.
