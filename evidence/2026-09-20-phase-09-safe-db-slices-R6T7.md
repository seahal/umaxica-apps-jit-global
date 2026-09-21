# Phase 09 targeted database safeguards

- Date: 2026-09-20
- Scope: targeted Phase 09 slices only; no production or shared database reset
- Environment: test database and live PostgreSQL/Valkey services loaded from the devcontainer environment file

## Foreign-key retention protection

Before the change, the public test contract was added first. The focused RED run reported 50 runs,
151 assertions, and two failures: both sign-up-flow token deletes were allowed by the existing
cascade behavior.

The migration was initially stopped by Strong Migrations because adding and validating a foreign
key in one step would block writes. It was split into an unvalidated FK migration followed by a
separate validation migration. The isolated test database then applied both migrations successfully.

The final focused run was:

```text
PARALLEL_WORKERS=1 bin/rails test test/models/client_token_test.rb test/models/visitor_token_test.rb test/jobs/retention_purge_job_test.rb
62 runs, 214 assertions, 0 failures, 0 errors, 0 skips
```

An explicit test-database inspection reported `ON DELETE RESTRICT` for both
`client_sign_up_flows.token_id -> client_tokens.id` and
`visitor_sign_up_flows.token_id -> visitor_tokens.id`. The tests cover both Rails deletion
attempts and direct SQL deletion attempts, and verify that parent and child rows remain.

## Approved avatar index

The pre-change test database had only the partial unique current-row index on `avatar_id`. The
approved non-unique all-rows index was added with the exact name
`idx_avatar_ownership_periods_avatar_id_all_rows`, using a concurrent PostgreSQL index migration.

```text
PARALLEL_WORKERS=1 bin/rails test test/models/avatar_ownership_period_test.rb test/models/avatar_test.rb
19 runs, 72 assertions, 0 failures, 0 errors, 0 skips
```

The regression test verifies the full-row non-unique index and independently verifies preservation
of the partial unique `valid_to = infinity` index.

## Approved reason-note encryption

The new raw-database test first failed because the marker was stored as plaintext. The seven
approved fields were then declared with non-deterministic Active Record Encryption. The focused
verification was:

```text
PARALLEL_WORKERS=1 bin/rails test test/models/sensitive_reason_note_encryption_test.rb test/models/account_access_event_test.rb test/services/administrative_access_lock_test.rb test/models/app_enforcement_case_test.rb test/models/com_enforcement_case_test.rb test/models/org_enforcement_case_test.rb
34 runs, 157 assertions, 0 failures, 0 errors, 0 skips
```

Each field was read back through Active Record and through a raw database connection. The raw
values did not contain the plaintext marker. No IP, subject, password digest, token digest, or
JSON-wide encryption was added.

## Explicitly not completed by this evidence

This record does not claim completion of the full database reconstruction, populated structure SQL
dumps, broad Retainable column renaming, global DB-clock migration, or an all-table timestamp
constraint audit. Those require a separate inspected scope and clean isolated database
reproduction.
