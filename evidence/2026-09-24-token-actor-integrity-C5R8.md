# Token Actor and Device Session Integrity Evidence

- Work was performed against commit `2b027d5b38989d3068e4620262bfa6c6fde8df41` with uncommitted changes already present from the earlier approved device-session/token work. The worktree remains uncommitted.
- The user renewed the request to complete the main PostgreSQL integrity task after the focused same-actor database-shape proposal had been presented. This record covers the additional local implementation; it does not claim a live database rollout.

## Local implementation

- In each of `app_ticket`, `com_ticket`, and `org_ticket`, a new unique session `(actor_id, id)` index supports a composite token `(actor_id, device_session_id)` to session `(actor_id, id)` foreign key. The actor column is respectively `user_id`, `visitor_id`, or `staff_id`. The token session ID remains nullable; no token kind or actor data is rewritten.
- The index is built concurrently with definition and valid/ready checks. A same-named mismatched index stops; a matching interrupted invalid index is recreated. The foreign key is added `NOT VALID` and validated in a separate transaction with finite timeouts.
- The token/session actor foreign key adds to the previously approved token/session existence and current-pointer foreign keys. In the checked-in ticket snapshots the foreign-key counts are 15, 15, and 14; after these migrations the projected counts are 18, 18, and 17. The index counts are 148, 105, and 109; replacement of one token index plus one new session index projects 149, 106, and 110. These are projected local schema changes, not live counts.
- Direct SQL model tests were added for cross-actor session references in all three ticket databases. Existing FK-violation tests allow either relevant FK name where two constraints correctly reject the same missing-parent or parent-delete operation; they still require SQLSTATE `23503` and a named intended constraint.
- The request-boundary resolver rejects missing, inactive, or other-actor device sessions for bound tokens; sessionless token kinds remain on their existing path. Tests cover the success path and invalid actor/session cases for the shared resolver.

## Verification and blockers

- Ruby syntax checks passed for all 31 changed Ruby files.
- `bundle exec rubocop` passed for those 31 files with no offenses; `git diff --check` passed.
- Loading all 21 new ticket migration files with `bundle exec ruby -ractive_record` succeeded; this checked class/file loading without connecting to PostgreSQL.
- `bin/rails test test/controllers/concerns/authentication/current_resource_resolver_test.rb` stopped while booting because `VALKEY_KVS_HOST` is required and absent. No test body ran; this is not a test pass.
- No disposable isolated PostgreSQL server or Valkey server binaries were found in the environment. `POSTGRESQL_TEST_HOST` and `POSTGRESQL_PORT` were also absent. The repository test configuration requires them and defines multiple test databases. No migration, DML, live catalog query, structure dump generation, independent-connection race test, or migration/schema-load parity check was run.
- PostgreSQL server version, actual physical database/schema mapping, applied migration state, and existing violation counts remain unverified. The checked-in snapshots are not substitutes for live catalog evidence. The historic F-01–F-21 report was not supplied; current-code inventory is in `memos/postgresql-integrity-current-static-inventory.md`.
- No GitHub write, commit, branch change, shared database write, or unauthorized environment write was performed.

## SHA-256 of current changed source and documentation

| File | SHA-256 |
| --- | --- |
| `adr/device-session-dbsc-device-id-boundary.md` | `f9963e90e4e900bf5ad50751aea0a4c7c35c66e4edabca9b7559e4e7a96767d5` |
| `app/controllers/concerns/authentication_current_resource_resolver.rb` | `5f1fef025f02d368d745a8014b71e08fa40a7ea94934387a5ad8ceb9ad7adc94` |
| `app/models/client_device_session.rb` | `74ea33558a8cc6af10338bf0451472a05a7d9781b0932ea5ca6d67c79aca474b` |
| `app/models/operator_device_session.rb` | `e64f83ecd4e9ced8e1515368fb8cb9f7a22954ea4a664dfd56d461ce0012b3c1` |
| `app/models/visitor_device_session.rb` | `03fa38b44e770be67aae2ff9da8bf35cdfcce191623eb0a13e6128cb36728833` |
| `db/app_tickets_migrate/20260924150000_add_client_token_device_session_reference_index.rb` | `a9b685f8e9ae9e0c88e2278224f752ac428f713f00e41ee00537f1f50ff60fb1` |
| `db/app_tickets_migrate/20260924151000_add_client_device_session_token_foreign_keys.rb` | `0db7f8c8de1c656df1159556da51d07dcaebaac993f995763cdc2438139ca2e6` |
| `db/app_tickets_migrate/20260924152000_validate_client_token_device_session_reference.rb` | `bef0002d8c8dcaa4254268ea3d47b902073a4613a6db106e8d279d7b6e6f0f20` |
| `db/app_tickets_migrate/20260924153000_validate_client_current_refresh_token_owner.rb` | `3c1f433d2e9810e1424ba39c7c2fb87f42167a93a057731acd511c71fef99a97` |
| `db/app_tickets_migrate/20260924154000_add_client_device_session_actor_reference_index.rb` | `c81b6fc67bffd3563e63d95659a52802190871d05513b9d69208cf87d9ce91b7` |
| `db/app_tickets_migrate/20260924155000_add_client_token_device_session_actor_foreign_key.rb` | `6014903f0fc8ab3190b6899de08c3cee57580af71d0abe7ca0107487ee44687f` |
| `db/app_tickets_migrate/20260924156000_validate_client_token_device_session_actor_foreign_key.rb` | `48770631eb17f955e9d9b5a0b41f82dc14aa7854d003d41462f3b0634708595a` |
| `db/com_tickets_migrate/20260924150000_add_visitor_token_device_session_reference_index.rb` | `59c6071ec2c67c1a81a5c60db834aa4f5ca55c6bf90cdf57925e7efff6b87ee9` |
| `db/com_tickets_migrate/20260924151000_add_visitor_device_session_token_foreign_keys.rb` | `b37a406818146853f5b13da106ad52c3290ec1cb7a5c769843375a37f55c58ee` |
| `db/com_tickets_migrate/20260924152000_validate_visitor_token_device_session_reference.rb` | `28ca990d214a6dadc6a156c81576a6269f95c71a65ddad1f8f4a10be9c3deb0b` |
| `db/com_tickets_migrate/20260924153000_validate_visitor_current_refresh_token_owner.rb` | `a84b268355c074fc83eb426d8d148b6b542e08d297edecb9a8777446d3eea24b` |
| `db/com_tickets_migrate/20260924154000_add_visitor_device_session_actor_reference_index.rb` | `75bb41945f6baf5b24c34c6b35a7a0be5180a7874f5813f9c63458ea0e38bf09` |
| `db/com_tickets_migrate/20260924155000_add_visitor_token_device_session_actor_foreign_key.rb` | `ca9e8222cfe4fab42f3697a877ac2ce86cfb217ac3a4cf96824e4d6d18232338` |
| `db/com_tickets_migrate/20260924156000_validate_visitor_token_device_session_actor_foreign_key.rb` | `22437d62c25b861ecd1d843bc193eb0d19f955a34748667dcbfe9f345534792e` |
| `db/migration_support/device_session_token_indexes.rb` | `9c10d0508a677a8740ab876a587639427d82c232897055b29656691bda69a69e` |
| `db/org_tickets_migrate/20260924150000_add_operator_token_device_session_reference_index.rb` | `83e75d48b7019068467ae15294428a03fa3e67b18f09801c0cae0815a0b5cced` |
| `db/org_tickets_migrate/20260924151000_add_operator_device_session_token_foreign_keys.rb` | `739925fadde8fa6560924a581efa19f268c89cbf1a89905a44155af7b2152d4c` |
| `db/org_tickets_migrate/20260924152000_validate_operator_token_device_session_reference.rb` | `2e9a6a4f8d26c093c2e41cf6ec19615f57a4befcb99b383e84457531ec4dd8b3` |
| `db/org_tickets_migrate/20260924153000_validate_operator_current_refresh_token_owner.rb` | `4421b9d5d9b00cd7a10a15e5a723dcdea9d0f46598047afb9c39be655554c7b7` |
| `db/org_tickets_migrate/20260924154000_add_operator_device_session_actor_reference_index.rb` | `728ee5dab34b9c625755b5b28c1fbe933ef44355ec246955e9f4595eb8efd74c` |
| `db/org_tickets_migrate/20260924155000_add_operator_token_device_session_actor_foreign_key.rb` | `c5b543a77df8d5661970dd54ea81b93f7d7c5591ec6c36d000ed31f2ed202f14` |
| `db/org_tickets_migrate/20260924156000_validate_operator_token_device_session_actor_foreign_key.rb` | `6468d92b110572dac5572acce82e4485cd626a3174d934ea68571a9d9d0c5bd7` |
| `docs/operations/device-session-token-integrity-rollout.md` | `a3523e4208e6129b668b3fe492699ac915f6b1fd649d5cb07313f79e777894ad` |
| `memos/postgresql-integrity-current-static-inventory.md` | `5174bd00dbfc1edcb50d6a97e7689b7d45079cc70394e2caec1d3de6d40caa18` |
| `test/controllers/concerns/authentication/current_resource_resolver_test.rb` | `315a396284b285fdeae43c8ec7fe9c92ce0422f8624c7ba59ae40253b5574fd8` |
| `test/models/client_token_test.rb` | `ce54b90ff4121321d5dbd1b3ac94276a6762d492a367e2f863bf5163014f1502` |
| `test/models/concerns/refresh_tokenable_test.rb` | `dbdce67ed4e756e2b685384b3636dd6479500466bffc87a9e498de70f9536768` |
| `test/models/operator_token_test.rb` | `a1f8dedf96852b2cb371defa47adda56dfcb4401a17778cc586dcf269883c4e6` |
| `test/models/visitor_token_test.rb` | `9d347bd3496473005ff396d57e8cf04f826a5f36322cc935c95177dec3d995fb` |
