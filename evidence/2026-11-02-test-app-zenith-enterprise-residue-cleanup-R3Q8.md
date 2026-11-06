# Test App Zenith enterprise residue cleanup

- HEAD: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`; the worktree had unrelated uncommitted changes.
- Symptom: fixture setup failed with `fk_rails_7793aa24bc` on `enterprise_units`, for example
  `enterprise_id=519260504` not present in `enterprises`.
- Observed: `test_app_zenith_db` held 23 enterprises, 20 units, 20 closures and 20 persona
  memberships. The units and memberships were created on 2026-11-02 between 02:13:21 and 02:13:29
  UTC. The worker and replica clones held the same counts. The test that committed them was not
  identified.
- Action: in `test_app_zenith_db`, `test_app_zenith_replica_db` and their numbered clones, deleted
  all rows from `persona_memberships`, `enterprise_unit_closures` and `enterprise_units`, and every
  `enterprises` row except public_id `AvatarOwnerFixture001`. No dump was taken. Development,
  production and schema dumps were not touched.
- Result: `bin/rails test` on `test/integration/anonymous_com_preference_write_journey_test.rb`,
  `test/controllers/concerns/preference_write_boundary_test.rb` and
  `test/models/enterprise_unit_test.rb`: 57 runs, 823 assertions, 0 failures, 0 errors. The full
  suite was not run.
