# Principal Zenith Physical Consolidation Implementation Notes

## Context

- Original plan/spec: consolidate each `*_principal` physical database into the matching `*_zenith`
  physical database while keeping the `*_principal` connection keys empty for future regional-ready
  placement.
- Related decisions/docs/plans:
  - `adr/principal-zenith-physical-consolidation.md`
  - `docs/architecture/database-authority-placement.md`
  - `docs/architecture/database-boundaries.md`
  - `docs/architecture/model-database-inventory.md`
- Implementation date: 2026-06-30.

## Decisions Made During Implementation

- Decision: keep `AppPrincipalRecord`, `OrgPrincipalRecord`, and `ComPrincipalRecord` as semantic
  abstract base classes, but point them to the matching zenith database connections.
  - Why: existing model inheritance still communicates principal/actor semantics, while physical
    authority placement is now consolidated.
  - Alternatives considered: moving every model directly to `AppRpRecord`, `OrgRpRecord`, or
    `ComRpRecord`. That would erase useful semantic boundaries and create a broad model churn pass.
  - Follow-up needed: future model cleanup can revisit individual inheritance only when semantic
    names are settled.

- Decision: keep `*_principal` connection keys configured with empty reserved migration paths.
  - Why: the user explicitly wanted `*_principal` retained for later regional-ready models after it
    becomes empty.
  - Alternatives considered: deleting the connection keys. That would make later reserved placement
    harder and would be a wider configuration removal than requested.
  - Follow-up needed: do not add global authority models to these paths without a new placement
    decision.

- Decision: resolve migration version and class-name collisions by renaming zenith-side migration
  versions/classes before combining paths.
  - Why: Rails migration loading requires unique versions and class names across a database's
    migration paths.
  - Alternatives considered: renaming principal-side migration files. Zenith-side timestamp nudges
    were smaller and matched the requested destructive timestamp adjustment direction.
  - Follow-up needed: regenerate structure dumps from a clean database after the branch's migration
    state is ready.

## Deviations From Plan

- Change: no schema dump files were regenerated during this implementation pass.
  - Why: this branch already has broad unrelated worktree changes, and a clean multi-DB rebuild was
    not part of the focused implementation step.
  - Risk: committed structure dumps may not yet reflect the consolidated migration paths. All
    `*_structure.sql` files have `dump_schema_after_migration = false` set in every environment, so
    nothing auto-regenerates them; they still need an explicit dump pass.
  - Follow-up: run the project's multi-DB schema verification flow before merge.

## Follow-up Fix: `operator_accounts` table-name collision (2026-06-30)

- Problem: `bin/rails db:migrate:reset` failed with
  `PG::DuplicateTable: relation "operator_accounts" already exists` while running
  `db/org_zenith_migrate/20260519161001_rename_org_rp_tables.rb`. This is the concrete cause of the
  "Rails stopped on pending migrations" item logged above — it is not just a stale
  `schema_migrations` state, it is a genuine migration design conflict introduced by the physical
  consolidation.
- Root cause: `org_principals_migrate` and `org_zenith_migrate` each independently evolved their own
  `staffs`/`admins`-derived table lineage before the physical merge, and both lineages happened to
  rename their respective table to `operator_accounts`:
  - `db/org_principals_migrate/20260514113000_align_operator_model_table_names.rb` renamed the
    pre-consolidation `operators` table (department_id/status_id-shaped, referenced only by the
    now-dead `staff_operators` table) to `operator_accounts`.
  - `db/org_zenith_migrate/20260519161001_rename_org_rp_tables.rb` renamed the live `staff_accounts`
    table (staff_id/public_id-shaped, matching the current `OperatorAccount` model) to
    `operator_accounts`.
  - Before consolidation these were two separate physical databases, so the name collision was
    latent; after consolidation both lineages run against the same physical database and collide.
- Decision (confirmed with the user): keep the org_zenith-side table as `operator_accounts` (it
  matches the live `OperatorAccount` model). Renamed the org_principal-side legacy target to
  `legacy_operator_department_accounts` in
  `db/org_principals_migrate/20260514113000_align_operator_model_table_names.rb` (including its
  `up`, `down`, and index-rename helpers) and updated the matching FK references in
  `db/org_principals_migrate/20260518181000_validate_remaining_org_principal_foreign_keys.rb`. No
  data was dropped; the legacy table is unreferenced by any current model
  (`operator_workspace_accounts` / `operator_workspace_account_memberships` fully superseded it).
  - Follow-up needed: confirm whether `legacy_operator_department_accounts` (and the dead
    `staff_operators`-named FK entries pointing at it) can be dropped outright in a later,
    explicitly approved migration — this pass only resolved the naming collision.
- Verification: `bin/rails db:migrate:reset` and `RAILS_ENV=test bin/rails db:migrate:reset` both
  complete cleanly end to end across all ~25 databases. Also fixed an unrelated pre-existing bug in
  `test/models/principal_zenith_consolidation_test.rb#database_config`: `configs_for` needs
  `include_hidden: true` to find `*_replica` configs, since replica configs have
  `database_tasks? == false` by default and are filtered out otherwise.

## Review Notes

- Tests run:
  - Ruby syntax checks for the edited model/test files passed.
  - Static duplicate checks passed for migration versions, Rails migration names, and class names in
    the combined app/org/com principal plus zenith migration paths.
  - Rails runner config checks passed for development and test principal/zenith migration paths.
  - `bin/rails db:migrate:reset` and `RAILS_ENV=test bin/rails db:migrate:reset` both completed with
    no errors after the `operator_accounts` collision fix above.
  - `bin/rails test test/models/principal_zenith_consolidation_test.rb test/models/org_principal_record_test.rb test/models/app_principal_record_test.rb test/models/com_principal_record_test.rb test/controllers/auth/org/sign/in/entras_controller_test.rb`
    all pass.
  - Full `bin/rails test` was run: 8886 runs, 831 failures, 113 errors. None of the failures
    reference `operator_account`, `legacy_operator_department_accounts`, or org principal/zenith
    migration paths; they are pre-existing failures from other in-progress work on this branch
    (withdrawal controllers, OIDC redirect flows, MFA challenge flows, welcome-sequence redirects)
    and are out of scope for this fix.
- Tests not run: none related to this fix.
- Documentation promotion needed: stable docs and ADR were updated in this change. Schema dump
  regeneration (`*_structure.sql`) and `db:verify_no_schema_drift` are still outstanding — note that
  `db:verify_no_schema_drift`, referenced by `docs/operations/db-workflow.md` and `AGENTS.md`, does
  not currently exist as a rake task in this codebase; it needs to be implemented before that step
  in the documented workflow can actually be run.
