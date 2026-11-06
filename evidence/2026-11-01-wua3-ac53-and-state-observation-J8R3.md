# WU-A3 AC-53 retention and local state-shape observations

HEAD: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`. At the start of this record the worktree had 364
tracked paths with changes and 71 untracked paths; no staged changes. Existing work was kept; no
commit was created.

Implemented the AC-53 cleanup slice. For App and Org, a browser that receives either first-attach
`auth_sid` last can advance only the matching admission. The mismatched target returns 400 without
changing its binding, parent, or Auth session. After parent, binding, and session retention pass,
the collector deletes the losing expired `issued`/unadmitted Auth session only after deleting its
last binding reference. Admitted and terminal continuity remain outside this collector. Binding and
Auth session retention decisions use their explicit `status_id` values.

Focused tests: `auth_admission_binding_purger_test.rb`,
`acceptance_wua3_initial_attach_race_test.rb`,
`identity_step_up_ceremony_transaction_purger_test.rb`, and
`oidc_authorization_transaction_purger_test.rb` — 15 runs, 219 assertions, 0 failures, 0 errors, 0
skips. The AC-53 test covers App and Org and both `auth_sid` arrival orders. RuboCop passed for the
three changed Ruby files; Ruby syntax and `git diff --check` passed.

Local development and test `db:migrate:status:op_base_app` and `db:migrate:status:op_base_org`
reported the WU-A3 binding, Auth Ceremony, and OIDC state migrations as `up`. This record did not
apply migrations; when or by whom they were applied was not established. Read-only checks found NOT
NULL `status_id`, validated status foreign keys, reference rows (6 for binding, 8 for Auth Ceremony,
4 for OIDC), and no legacy OIDC text `status` column in all four App/Org development/test databases.
Development affected tables had zero rows. Test App currently had 40 bindings, 35 Auth Ceremony
sessions and 43 OIDC parents; test Org had 0 bindings, 17 Auth Ceremony sessions and 0 OIDC parents.
These are post-test observations, not a pre-migration inventory. Development binding status foreign
keys have Rails-generated names; test binding status foreign keys have the explicit names in the
migration files.

`bin/rails db:verify_no_schema_drift` failed and listed nine dumps, including
`db/op_base_app_structure.sql` and `db/op_base_org_structure.sql`; the other listed dumps were
`app_setting`, `app_zenith`, `avatar`, `chronicle`, `occurrence`, `org_setting`, and `org_zenith`.
Targeted live-dump comparison also differed for the development OP Base schemas. No schema dump was
regenerated. The pre-cutover snapshots requested by the execution ticket were not captured before
these migrations were already reported `up`; no production or Neon database was accessed.

This closes only the focused AC-53 retention gap. WU-A3 acceptance and the broader two.md work
remain incomplete; migration provenance, pre-cutover snapshots, schema parity, and the remaining
acceptance matrix are unverified.
