# PostgreSQL Integrity Follow-up Evidence

- Baseline commit: `2b027d5b38989d3068e4620262bfa6c6fde8df41`.
- The worktree contained uncommitted changes from the prior approved device-session/token slice. This follow-up modified that slice and added local audit, rollout, and authentication changes. All results below are against the uncommitted worktree.
- The historic F-01–F-21 audit report was not attached; the user selected a current-code re-audit.

## Observed static state

- Parsed 20 checked-in PostgreSQL structure snapshots: 838 tables (705 model-backed application candidates, 4 legacy-named candidates, 59 recognized framework/gem tables, 70 uncertain). The per-table list is in `memos/postgresql-integrity-current-static-inventory.md`.
- Parsed 203 `NOT VALID` constraint definitions in the snapshots. These do not establish live `convalidated` state. No exact duplicate full `CREATE INDEX` definition was found within a snapshot.
- The three ticket database snapshots contain token/session columns without the approved references. No live physical database, schema, server version, or applied migration state was confirmed.
- The new runtime guard rejects a token bound to a missing or inactive session, a token whose actor differs from the access-token subject, and a bound session belonging to another actor. The existing sessionless-token path remains represented in the resolver test.
- Each of the three pairs now validates the two foreign keys in separate transactions, reducing validation lock overlap. The previous test infrastructure helper was removed; SQLSTATE and constraint names are asserted directly in the public model tests.

## Checks and limits

- `ruby -c` passed for all 22 changed Ruby files.
- `bundle exec rubocop` passed for the same 22 files: no offenses.
- `git diff --check` passed.
- Minitest, PostgreSQL migration application, live constraint validation, independent-connection races, and migration-versus-schema-load parity were not run. A disposable isolated target for every Rails test database connection was not confirmed. The prior targeted Minitest attempt stopped during boot because `VALKEY_KVS_HOST` was absent; no later passing test is claimed.
- No schema dump was generated or edited. The PostgreSQL server version is unverified; local tools observed in the prior record were Ruby 4.0.7, Rails 8.2.0.alpha, psql/pg_dump 17.11, and libpq 18.0.1.
- No GitHub write, commit, branch change, shared database write, or migration execution was performed.

## Current disposition

- **Locally implemented, not dynamically verified:** the approved three-database device-session/token reference slice and its request-boundary guard.
- **Deferred with reason:** F-09 and F-11 by task instruction; legacy removal and type changes under F-17–F-20 by task instruction.
- **Blocked with evidence:** the remaining F-03/F-21 live validation state, individual F-04–F-08/F-10/F-12–F-14/F-16 data contracts, complete historic finding-to-object mapping, and schema parity require the absent report, live catalog or confirmed disposable databases, or decisions about each persisted shape. The static inventory does not convert any of these to verified.
- **Pending shape approval:** a proposed same-actor composite FK for token/session pairs. The existing approved FKs prove session existence and current-token same-session membership, but do not prove token/session actor equality.

## SHA-256 of changed source and documentation

| File | SHA-256 |
| --- | --- |
| `adr/device-session-dbsc-device-id-boundary.md` | `33c0bc9e536b8aad235dbc1503d137be93b7d2c9461a3e3a672faa402298fdb7` |
| `app/controllers/concerns/authentication_current_resource_resolver.rb` | `5f1fef025f02d368d745a8014b71e08fa40a7ea94934387a5ad8ceb9ad7adc94` |
| `app/models/client_device_session.rb` | `74ea33558a8cc6af10338bf0451472a05a7d9781b0932ea5ca6d67c79aca474b` |
| `app/models/operator_device_session.rb` | `e64f83ecd4e9ced8e1515368fb8cb9f7a22954ea4a664dfd56d461ce0012b3c1` |
| `app/models/visitor_device_session.rb` | `03fa38b44e770be67aae2ff9da8bf35cdfcce191623eb0a13e6128cb36728833` |
| `db/app_tickets_migrate/20260924150000_add_client_token_device_session_reference_index.rb` | `a9b685f8e9ae9e0c88e2278224f752ac428f713f00e41ee00537f1f50ff60fb1` |
| `db/app_tickets_migrate/20260924151000_add_client_device_session_token_foreign_keys.rb` | `0db7f8c8de1c656df1159556da51d07dcaebaac993f995763cdc2438139ca2e6` |
| `db/app_tickets_migrate/20260924152000_validate_client_token_device_session_reference.rb` | `bef0002d8c8dcaa4254268ea3d47b902073a4613a6db106e8d279d7b6e6f0f20` |
| `db/app_tickets_migrate/20260924153000_validate_client_current_refresh_token_owner.rb` | `3c1f433d2e9810e1424ba39c7c2fb87f42167a93a057731acd511c71fef99a97` |
| `db/com_tickets_migrate/20260924150000_add_visitor_token_device_session_reference_index.rb` | `59c6071ec2c67c1a81a5c60db834aa4f5ca55c6bf90cdf57925e7efff6b87ee9` |
| `db/com_tickets_migrate/20260924151000_add_visitor_device_session_token_foreign_keys.rb` | `b37a406818146853f5b13da106ad52c3290ec1cb7a5c769843375a37f55c58ee` |
| `db/com_tickets_migrate/20260924152000_validate_visitor_token_device_session_reference.rb` | `28ca990d214a6dadc6a156c81576a6269f95c71a65ddad1f8f4a10be9c3deb0b` |
| `db/com_tickets_migrate/20260924153000_validate_visitor_current_refresh_token_owner.rb` | `a84b268355c074fc83eb426d8d148b6b542e08d297edecb9a8777446d3eea24b` |
| `db/migration_support/device_session_token_indexes.rb` | `070bafd05825fb070a3e762e2c466f4194b1e8e28435a0c76c4581d95cd1076d` |
| `db/org_tickets_migrate/20260924150000_add_operator_token_device_session_reference_index.rb` | `83e75d48b7019068467ae15294428a03fa3e67b18f09801c0cae0815a0b5cced` |
| `db/org_tickets_migrate/20260924151000_add_operator_device_session_token_foreign_keys.rb` | `739925fadde8fa6560924a581efa19f268c89cbf1a89905a44155af7b2152d4c` |
| `db/org_tickets_migrate/20260924152000_validate_operator_token_device_session_reference.rb` | `2e9a6a4f8d26c093c2e41cf6ec19615f57a4befcb99b383e84457531ec4dd8b3` |
| `db/org_tickets_migrate/20260924153000_validate_operator_current_refresh_token_owner.rb` | `4421b9d5d9b00cd7a10a15e5a723dcdea9d0f46598047afb9c39be655554c7b7` |
| `docs/operations/device-session-token-integrity-rollout.md` | `5cdb7813dfc06512671c31d41369468a76fa20df2e7fee15ab064a88aa315e2a` |
| `memos/postgresql-integrity-current-static-inventory.md` | `e7cbcc11ccabebb91241ba382ff66727975fa0e1a5fbb9bc9c200de06279d957` |
| `test/controllers/concerns/authentication/current_resource_resolver_test.rb` | `315a396284b285fdeae43c8ec7fe9c92ce0422f8624c7ba59ae40253b5574fd8` |
| `test/models/client_token_test.rb` | `e647e4ff7603dce5340dc13900ae3ada386ef626cd1e172299ec27874518d070` |
| `test/models/concerns/refresh_tokenable_test.rb` | `dbdce67ed4e756e2b685384b3636dd6479500466bffc87a9e498de70f9536768` |
| `test/models/operator_token_test.rb` | `825d32b9cb81caca96ce33250e993a0507987e2522149b83c572e4ab2b433f76` |
| `test/models/visitor_token_test.rb` | `1e774d89c0450355e1acba639e8225ee1f0903d6b692f6d8fdb6d52dadbd89d3` |
