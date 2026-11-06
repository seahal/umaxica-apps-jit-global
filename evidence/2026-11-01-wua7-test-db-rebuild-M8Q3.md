# WU-A7 test database schema recovery

HEAD: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`. Before this evidence file was added, the worktree
had 500 modified tracked files, 229 untracked files, and no staged files. Existing changes were
preserved.

The WU-A7 read-only inventory found `test_app_zenith_db` had 9 Clients and 0
`client_withdrawal_flows`. The flow table lacked `status_id`, although the checked-in migration and
structure dump define that column and `db:migrate:status:app_zenith` reported the migrations as up.

Before rebuilding, a custom-format snapshot was written to
`/tmp/test-app-zenith-before-wua7-rebuild-20261101T2030Z.dump` (556,253 bytes; SHA-256
`ad5385ad8142de9f21996076c69ec77b906546cb5b764f01609be1f71a0f1394`). `pg_restore --list` returned
1,319 entries. The pre-existing working copy of `db/app_zenith_structure.sql` was separately copied
to `/tmp/app-zenith-structure-before-wua7-rebuild.sql` (SHA-256
`a710695c8d6a9596aebf24aec700191c4f312a8a8d9a1557895962c73376d054`).

With `.env.container.devcontainer` loaded, ran
`RAILS_ENV=test bin/rails db:migrate:reset:app_zenith`. Rails reported dropping and recreating only
`test_app_zenith_db`, then applied migrations through `20261101175522`; a subsequent
`db:version:app_zenith` returned that version. The test Client count is now 0, and grouping
`ClientWithdrawalFlow` by `status_id` succeeds with an empty result. Test Org was not reset and
still has 6 Operators. No production or Neon database was accessed.

The reset removed 9,973 lines from `db/app_zenith_structure.sql`. The pre-reset working copy was
restored, then `RAILS_ENV=test bin/rails db:schema:dump:app_zenith` completed successfully. Its
generated output differed from the pre-reset file on 34 lines, all foreign-key definitions changing
validation markers to `NOT VALID`. Because no corresponding migration was added in this slice, the
prior working copy was restored again (SHA-256 remains
`a710695c8d6a9596aebf24aec700191c4f312a8a8d9a1557895962c73376d054`). The reset test database's
foreign-key validation state therefore differs from that preserved schema dump.

`RAILS_ENV=test bin/rails db:verify_no_schema_drift` failed and listed
`db/app_setting_structure.sql`, `db/app_zenith_structure.sql`, `db/op_base_app_structure.sql`,
`db/op_base_org_structure.sql`, `db/org_setting_structure.sql`, and `db/org_zenith_structure.sql`.
All six were already modified in the worktree when the task ran; its result does not distinguish
actual schema drift from the dirty-file guard. No Minitest or full suite was run; no application or
migration code was changed. WU-A7 shape approval and the ORG indefinite-suspension mapping remain
pending.
