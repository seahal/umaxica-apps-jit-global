# Publisher And Message Database Retirement Implementation Notes

## Context

- Original plan/spec: remove the remaining publisher and message database connection blocks.
- Related ADR/docs/plans:
  - `adr/secure-jump-link-redirector.md`
  - `research/implementation/2026-06-02-publisher-post-decommission.md`
  - `research/implementation/2026-06-03-direct-message-skeleton-retirement.md`
- Implementation date: 2026-06-03

## Decisions Made During Implementation

- Decision: delete `app_publisher`, `com_publisher`, `org_publisher`, and `message` database
  connections, migration directories, schema dumps, and `MessageRecord`.
  - Why: publisher post tables had already been decommissioned, direct-message tables had already
    been dropped, and no runtime application code references these database connections.
  - Alternatives considered: keeping the empty database shells as placeholders. Rejected because the
    corresponding product skeletons have been retired.
  - Follow-up needed: decommission physical publisher/message databases and related deployment
    credentials outside Rails after rollout.

## Deviations From Plan

- Change: no new Rails migrations were added.
  - Why: these databases are being removed from Rails ownership after their application tables were
    decommissioned. Physical database deletion is an operations task.
  - Risk: external infrastructure may still define publisher/message DB credentials until cleaned
    up.
  - Follow-up: remove `POSTGRESQL_*_PUBLISHER_*`, `POSTGRESQL_MESSAGE_*`, and matching
    `DATABASE.*_PUBLISHER*` / `DATABASE.MESSAGE*` credentials after deployment.

## Review Notes

- Tests run:
  - `bin/rails runner 'names = ActiveRecord::Base.configurations.configs_for(env_name: Rails.env).map(&:name); puts names.grep(/publisher|message|redirector/).inspect'`
  - `bin/rails test test/config/routing_entrypoints_test.rb`
  - `bin/rails -T db:migrate | rg "publisher|message|redirector"`
- Tests not run:
  - Full suite was not run.
  - `bin/rails db:verify_no_schema_drift` was not rerun because the previous run exposed unrelated
    chronicle schema formatting drift.
- Documentation or ADR promotion needed:
  - No new ADR needed unless publisher or direct-message persistence is reintroduced.
