# Resume sample Minitest and test-database preparation

- Repository: `/home/global/workspace`
- Branch: `feature`
- Code HEAD used for this record: `ccceabd05d2e3a8f923ce398046f99d026a5b78e`
- The worktree had existing staged, unstaged and untracked changes; they were preserved. No
  reset, clean, stash, worktree, push, CI, Podman, production, or shared-database operation was
  used.

## Observed preparation boundary

The first sample command, run with the container's inherited
`POSTGRESQL_TEST_PREPARE_DATABASES` value of the four ticket/primary databases, stopped before
loading the test file because Rails found pending migrations in the other configured writer
databases. It reported 43 pending migrations. This was a test-environment preparation failure,
not a test assertion failure.

The guarded preparation task was then run against the twenty non-replica writer databases derived
from the current test configuration, without changing the process environment permanently:

```text
POSTGRESQL_TEST_PREPARE_DATABASES=test_primary_db,test_publishing_db,test_app_zenith_db,test_com_zenith_db,test_org_zenith_db,test_app_setting_db,test_com_setting_db,test_org_setting_db,test_app_ticket_db,test_com_ticket_db,test_org_ticket_db,test_app_signal_db,test_com_signal_db,test_org_signal_db,test_avatar_db,test_chronicle_db,test_occurrence_db,test_queue_db,test_search_db,test_storage_db RAILS_ENV=test bundle exec rails db:test:prepare
```

The command exited 0 and applied the pending local test migrations, including the Avatar Group
concrete ownership table and the identifier-capacity/staff-event transitions. It did not reset or
drop a database.

## Focused public test

After preparation, the same twenty-database scope ran:

```text
POSTGRESQL_TEST_PREPARE_DATABASES=test_primary_db,test_publishing_db,test_com_zenith_db,test_org_zenith_db,test_app_zenith_db,test_app_setting_db,test_com_setting_db,test_org_setting_db,test_app_ticket_db,test_com_ticket_db,test_org_ticket_db,test_app_signal_db,test_com_signal_db,test_org_signal_db,test_avatar_db,test_chronicle_db,test_occurrence_db,test_queue_db,test_search_db,test_storage_db RAILS_ENV=test bundle exec rails test test/services/identifier_hmac_maintenance_boundary_test.rb
```

Observed result: `4 runs, 108 assertions, 0 failures, 0 errors, 0 skips`.

This is a focused sample only. It does not replace the required current full gate, and the
inherited four-database environment remains an external container configuration issue until the
container is recreated or its approved test-database variable is corrected.

## Preparation-source alignment

The local `config/ci.rb` preparation source and its static configuration contract were then
updated to enumerate the same twenty non-replica writer databases. No CI job was invoked. The
focused configuration contract was rerun with the same explicit writer scope and passed:
`15 runs, 66 assertions, 0 failures, 0 errors, 0 skips`. This source change does not alter the
currently inherited container environment; a container recreation or approved host-side
environment update is still required for an unqualified `bundle exec rails test` to self-prepare.

After all twenty local test writer databases had been prepared, the requested unqualified sample
command was rerun:

```text
bundle exec rails test test/services/identifier_hmac_maintenance_boundary_test.rb
```

It passed with `4 runs, 108 assertions, 0 failures, 0 errors, 0 skips`. The command still printed
the inherited four-database preparation scope; its success relies on the local databases already
being current, so it is not evidence that the stale container variable will prepare future
migrations for all writers.
