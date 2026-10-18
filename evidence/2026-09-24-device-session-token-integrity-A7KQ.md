# Device Session and Token Reference Integrity

## Record

- Work was performed against commit `2b027d5b38989d3068e4620262bfa6c6fde8df41`.
- The worktree was clean at the start. It contains uncommitted changes from this task, and those
  changes affect the results below. No commit, branch change, remote write, or database write was
  performed.
- The user selected a current-code re-audit because the referenced historic audit report was not
  attached, then explicitly approved the device-session/token before-and-after proposal for the
  three ticket databases. This record covers that approved slice only.

## Baseline and Scope

The checked-in structure snapshots map these application-owned tables to three separate logical
databases. They are snapshots, not proof of a currently connected database or its migration state.

| Database | Model/table pair | Tables | Foreign keys | Indexes |
| --- | --- | ---: | ---: | ---: |
| `app_ticket` | `ClientDeviceSession` / `client_device_sessions`; `ClientToken` / `client_tokens` | 40 | 15 | 148 |
| `com_ticket` | `VisitorDeviceSession` / `visitor_device_sessions`; `VisitorToken` / `visitor_tokens` | 28 | 15 | 105 |
| `org_ticket` | `OperatorDeviceSession` / `operator_device_sessions`; `OperatorToken` / `operator_tokens` | 29 | 14 | 109 |

In each committed ticket structure snapshot, `tokens.device_session_id` and
`device_sessions.current_refresh_token_id` are nullable and have ordinary single-column indexes,
but there is no foreign key connecting either direction. The corresponding model code creates a
device session for token creation, copies the session ID during class-level refresh rotation, and
updates the session's current-token pointer in the same token transaction. Actor model associations
delete tokens before device sessions. These observations are from checked-in code and snapshots;
live table contents and live constraint state were not queried.

Runtime versions observed locally:

- Ruby `4.0.7`; Rails `8.2.0.alpha`; libpq `18.0.1`.
- `psql` and `pg_dump` are `17.11`.
- PostgreSQL server version and the current server behind each logical connection were **not
  verified**. Repository container files pin PostgreSQL `17.7`, which does not prove the connected
  server version. The new SQL syntax requires PostgreSQL 15 or newer.

Finding status for this implementation slice:

| Finding group | Status | Current evidence |
| --- | --- | --- |
| F-01, F-02, F-15 | `CONFIRMED` for the three device-session/token reference pairs only | The committed structures omit both reference constraints; model rotation and lifecycle code establish the intended pair and ordering. Live state remains unverified. |
| F-03, F-21 | `NOT_VERIFIED` | The committed structures contain `NOT VALID` constraint definitions, but no live catalog or migration state was available. |
| F-04, F-05, F-06, F-07, F-08, F-10, F-12, F-13, F-14, F-16 | `NOT_VERIFIED` | This authorized implementation did not re-audit those column and index contracts. The referenced historic report was unavailable. |
| F-09, F-11 | `OUT_OF_SCOPE` | The implementation prompt explicitly defers partitioning and preference aggregation/JSONB work. |
| F-17, F-18, F-19, F-20 | `NOT_VERIFIED` | No legacy-use classification was completed. The implementation prompt prohibits removal or type changes here. |

These statuses are not a completion count for F-01–F-21. They do not treat unknown or unchecked
items as passes.

## Approved Contract and Plan

The persisted shape remains nullable in both directions. In each ticket database:

- `tokens.device_session_id` references `device_sessions.id` with `ON DELETE RESTRICT`.
- A unique index on `(device_session_id, id)` replaces the non-unique single-column token index.
  It preserves token history as many-to-one; the session ID alone is not unique.
- A deferred composite foreign key connects
  `(device_sessions.id, device_sessions.current_refresh_token_id)` to
  `(tokens.device_session_id, tokens.id)`. A non-null pointer must identify a token in its own
  session at commit. A null pointer remains valid.
- Deleting the pointed token clears only `current_refresh_token_id`. Deleting a session while token
  history still references it is restricted.
- Rails session associations use `dependent: :restrict_with_exception`. Actor deletion keeps its
  existing child-before-parent order; no cross-database foreign key is introduced.

Implementation order is: add the composite index concurrently with interruption-state checks;
add both foreign keys as `NOT VALID` in a transactional migration; validate them in a later
transaction; align Rails deletion behavior; then verify creation, rotation, invalid references,
nullable references, token deletion, session deletion, and actor deletion in tests.

## Adversarial Review

- Nullability is preserved so token records and initial sessions that legitimately have no pointer
  remain representable. The composite relationship still rejects a non-null pointer to another
  session's token.
- No uniqueness constraint was added on `device_session_id` alone, so refresh-token history remains
  many-to-one.
- Deleting the current token clears the pointer without unlinking the remaining token history or
  deleting the session. Direct session deletion is also protected by the database foreign key.
- Parent actor model ordering was checked: tokens are deleted before their device sessions for
  clients, visitors, and operators. The corresponding test cases were added.
- Existing rows are not backfilled or rewritten. `NOT VALID` additions protect new writes, and the
  validation migration stops if historical references violate the approved contract.
- The new composite index replaces an index with the same leading key. This supports session-ID
  lookups and token-side foreign-key checks; no workload or latency improvement is claimed without
  a database and representative measurements.
- Independent-connection race behavior and actual PostgreSQL constraint behavior remain unverified
  because no safe test database was available.

## Verification

- Ruby syntax checks passed for the changed Ruby files.
- Targeted RuboCop passed: 19 files inspected, no offenses.
- `git diff --check` passed.
- The targeted Minitest command exited 1 during Rails environment boot because required
  `VALKEY_KVS_HOST` is missing. No test body ran and no database connection was opened.
- Migration application, FK validation, live catalog inspection, independent-connection tests, and
  structure dump regeneration were not run. The test DB target could not be confirmed as an
  isolated disposable database, and no safe PostgreSQL service was available. Structure dumps were
  not edited manually.

The implementation uses PostgreSQL's column-specific `ON DELETE SET NULL` syntax and staged
`NOT VALID`/validation behavior as documented for [PostgreSQL 15](https://www.postgresql.org/docs/15/sql-createtable.html)
and [PostgreSQL 17](https://www.postgresql.org/docs/17/sql-altertable.html). Rails' migration guide
documents the single-column foreign-key DSL; the approved same-session ownership constraint uses
explicit composite-FK SQL: [Active Record Migrations](https://guides.rubyonrails.org/active_record_migrations.html).

## Changed-File SHA-256

Hashes identify the exact changed source files reviewed for this record; the evidence file itself
is intentionally not self-hashed.

| File | SHA-256 |
| --- | --- |
| `adr/device-session-dbsc-device-id-boundary.md` | `4c162fdcfe13a666a04b0cb32470c0313b8da11e920105914cffab33cc1a6bcd` |
| `app/models/client_device_session.rb` | `74ea33558a8cc6af10338bf0451472a05a7d9781b0932ea5ca6d67c79aca474b` |
| `app/models/operator_device_session.rb` | `e64f83ecd4e9ced8e1515368fb8cb9f7a22954ea4a664dfd56d461ce0012b3c1` |
| `app/models/visitor_device_session.rb` | `03fa38b44e770be67aae2ff9da8bf35cdfcce191623eb0a13e6128cb36728833` |
| `db/migration_support/device_session_token_indexes.rb` | `070bafd05825fb070a3e762e2c466f4194b1e8e28435a0c76c4581d95cd1076d` |
| `db/app_tickets_migrate/20260924150000_add_client_token_device_session_reference_index.rb` | `a9b685f8e9ae9e0c88e2278224f752ac428f713f00e41ee00537f1f50ff60fb1` |
| `db/app_tickets_migrate/20260924151000_add_client_device_session_token_foreign_keys.rb` | `0db7f8c8de1c656df1159556da51d07dcaebaac993f995763cdc2438139ca2e6` |
| `db/app_tickets_migrate/20260924152000_validate_client_device_session_token_foreign_keys.rb` | `e8ab7a4346111bcf6c7e77a10cbf434f3cb129cb8f07e1adf84f5e0b63d1274f` |
| `db/com_tickets_migrate/20260924150000_add_visitor_token_device_session_reference_index.rb` | `59c6071ec2c67c1a81a5c60db834aa4f5ca55c6bf90cdf57925e7efff6b87ee9` |
| `db/com_tickets_migrate/20260924151000_add_visitor_device_session_token_foreign_keys.rb` | `b37a406818146853f5b13da106ad52c3290ec1cb7a5c769843375a37f55c58ee` |
| `db/com_tickets_migrate/20260924152000_validate_visitor_device_session_token_foreign_keys.rb` | `629d2a015a15266a924091f05ba0cf6f04da15e897130af867db9993fc2e329d` |
| `db/org_tickets_migrate/20260924150000_add_operator_token_device_session_reference_index.rb` | `83e75d48b7019068467ae15294428a03fa3e67b18f09801c0cae0815a0b5cced` |
| `db/org_tickets_migrate/20260924151000_add_operator_device_session_token_foreign_keys.rb` | `739925fadde8fa6560924a581efa19f268c89cbf1a89905a44155af7b2152d4c` |
| `db/org_tickets_migrate/20260924152000_validate_operator_device_session_token_foreign_keys.rb` | `9056e7f7aa500518512b988b6a4b7bbb7b3361c401a0dd2e6a89b73c2f751b01` |
| `test/support/postgresql_constraint_assertions.rb` | `7aa56ec2c35466941b531fb0f0ce7b65222f2fd6c3bbfcbc7a4e06db4c4cd1cc` |
| `test/models/client_token_test.rb` | `aa70ccd200e8c488e8ad50fd854fd9e0bdf4f2cc5af5df1cb78d08551d85b3b1` |
| `test/models/concerns/refresh_tokenable_test.rb` | `dbdce67ed4e756e2b685384b3636dd6479500466bffc87a9e498de70f9536768` |
| `test/models/operator_token_test.rb` | `3dd421e385c3732f0ec2af277090cc84451cccdc46f508d0e967965aaacd7213` |
| `test/models/visitor_token_test.rb` | `2c8f93be6d9823e6ded9e2403649539d490dd43223c94de9b2b47790f0e61587` |
| `test/test_helper.rb` | `2a6ed0bc07d3bbc3678900acd27854521154d10e822bff1680874d5968701baa` |
