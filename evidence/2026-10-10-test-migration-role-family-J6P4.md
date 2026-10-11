# Test migration role-family verification

- Date: 2026-10-10 UTC. Reviewed commit: `2a1644f73238839ed7ed513bd4681ea393a86682`.
- Worktree: dirty before this check, with unrelated application, migration, structure-dump, test,
  script, research, and evidence changes. Those changes were preserved. The three HMAC migration
  files were already modified before this check; this work extended their existing role-reuse
  guard.
- The failing `umaxica_app_email_hmac_definer_f2889e81e3d6` role had restricted authority and no
  membership, but its expected function/table/schema dependencies appeared in the parallel worker
  clones (`test_app_zenith_db_0` through `_15`) and the matching replica family while the base
  migration was still pending. PostgreSQL roles are cluster-wide, so treating every database-local
  dependency as a conflict incorrectly rejected the valid cloned test fleet.
- The APP, COM, and ORG identifier-HMAC migrations now accept dependencies only within the current
  writer/replica database family and continue to reject shared dependencies or dependencies from
  any unrelated database.
- `RAILS_ENV=test bin/rails db:migrate` applied the three pending migrations successfully and
  continued through the later pending migrations, including `20261010150000`. A repeat no-op
  `RAILS_ENV=test bin/rails db:migrate` exited 0.
- `RAILS_ENV=test bin/rails db:abort_if_pending_migrations` exited 0. Migration status reported
  `20261008025001`, `20261008025005`, and `20261008025009` as `up`.
- Ruby syntax checks, targeted RuboCop, and `git diff --check` exited 0.
- `RAILS_ENV=test bin/rails db:verify_no_schema_drift` exited 1 because all 20 committed
  `db/*_structure.sql` files were already modified in the worktree and their current contents
  do not match the migrated test databases. No structure dump was changed by this check.
- No Minitest was added for this environment-construction issue; the migration workflow itself was
  executed as the verification.
