# WU-9 ORG Preference status foreign-key validation

- HEAD: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`.
- The worktree had extensive uncommitted changes affecting the result; no commit was created.
- Before this slice, the ORG Setting development database had `fk_org_preferences_on_status_id` with
  `convalidated=false`; the test database had the same constraint validated. Both had zero orphan
  status references. The development parent table had 0 rows and the test parent table had 2 rows.
- The existing ORG cutover migration retained the legacy status FK without validating it. Added
  `20261101025006_validate_org_preference_status_foreign_key.rb`; its `up` validates that existing
  FK, and its `down` restores the same FK as `NOT VALID`. No preference row was deleted or updated.
- `bin/rails db:migrate:org_setting` applied the older empty migration
  `20261031201209_replace_org_preference_legacy_shape.rb` and the new validation migration to local
  development. `RAILS_ENV=test bin/rails db:migrate:org_setting` applied the validation migration to
  the local test database. Production and Neon were not targeted.
- After migration, read-only catalog queries reported `convalidated=true` and 0 orphan references in
  both databases. Parent row counts were 0 in development and 2 in test. The generated
  `db/org_setting_structure.sql` now records the validated constraint.
- `bundle exec rubocop db/org_settings_migrate/20261101025006_validate_org_preference_status_foreign_key.rb`
  passed. `git diff --check` passed for the migration and generated ORG Setting structure dump.
- The current Visa continuation group passed: 19 runs, 304 assertions, 0 failures, 0 errors, 0 skips
  (`visa_authorization_continuations_test.rb`, `sign_entry_exit_flow_test.rb`, and
  `sign_entry_exit_org_flow_test.rb`).
- `bin/rails db:verify_no_schema_drift` failed and listed nine changed schema dumps: the four WU-9
  APP/ORG setting and Zenith dumps, plus `avatar`, `chronicle`, `occurrence`, `op_base_app`, and
  `op_base_org`. The task reports tracked dump changes together with schema comparison results, so
  this run does not attribute each listed file to a schema mismatch. No other dump was regenerated
  in this slice.
- The WU-9 closure full suite had already been run once before this slice and was not rerun. The
  existing full-suite failure result remains open; this evidence does not establish WU-9 or `two.md`
  completion.
