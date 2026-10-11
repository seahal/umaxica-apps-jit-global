# Publisher Post Decommission Implementation Notes

## Context

- Original plan/spec: user requested removal of `app_publisher`, `org_publisher`, and
  `com_publisher` post routing, controllers, models, and related database state.
- Related plans/docs: `adr/regional-docs-news-content-model.md`.
- Implementation date: 2026-06-02.

## Decisions Made During Implementation

- Decision: implement the decommission as Stage 1 first.
  - Why: publisher database connections and migration paths must remain until the destructive drop
    migrations have been applied in each target environment.
  - Alternatives considered: deleting `config/database.yml` publisher entries in the same change.
  - Follow-up needed: after production has applied the decommission migrations, remove the publisher
    database entries, migration directories, and structure dumps in a separate Stage 2 change.

- Decision: keep rollback structural only.
  - Why: the user approved destructive table removal; rollback can recreate empty table structures
    for operational recovery, but deleted production data cannot be restored by migration rollback.
  - Alternatives considered: irreversible migrations.
  - Follow-up needed: production rollout should rely on backups or snapshots if data retention is
    still required.

## Deviations From Plan

- Change: Stage 2 was intentionally not applied in this change.
  - Why: removing publisher DB config before every target environment applies the drop migrations
    would make the migrations unreachable through normal Rails tasks.
  - Risk: publisher DB tasks remain temporarily even though application code no longer uses the
    publisher post models.
  - Follow-up: apply the migrations, then remove the remaining publisher DB configuration and schema
    artifacts.

## Review Notes

- Tests run:
  - `bin/rails runner 'Rails.application.eager_load!; puts "eager loaded"'`
  - `bin/rails routes -g post`
  - `RAILS_ENV=test bin/rails db:migrate`
  - `RAILS_ENV=test bin/rails db:rollback:app_publisher STEP=1 db:migrate:app_publisher db:rollback:com_publisher STEP=1 db:migrate:com_publisher db:rollback:org_publisher STEP=1 db:migrate:org_publisher`
  - `bin/rails test test/models/avatar_test.rb test/models/database_pk_type_test.rb test/models/id_column_type_test.rb test/models/model_table_fixture_consistency_test.rb test/unit/security/rails_way_harness_inventory_test.rb`
- Tests not run:
  - Full `bin/rails test`.
- Documentation or ADR promotion needed:
  - Stage 2 should update or remove any remaining docs that describe the publisher databases as
    active once the database configuration is removed.
