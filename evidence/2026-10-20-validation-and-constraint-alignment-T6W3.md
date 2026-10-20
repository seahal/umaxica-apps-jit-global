# Model validation and database constraint alignment

Date: 2026-10-20 HEAD: `87c15e1e5d89344db7dcaaa85ebb1f6972c0c829` Worktree: uncommitted changes from
earlier database_consistency work in this and another session were present. The other session was
stopped by the user before this work started. Schema dumps were restored from HEAD plus this
session's migration hunks after they had been found emptied; the emptied copies were kept in the
session scratchpad.

## Scope

Only changes that keep existing behavior were made, each driven by a failing contract test first:

| Area                 | Change                                                                                           | Contract test (Red → Green)                                                |
| -------------------- | ------------------------------------------------------------------------------------------------ | -------------------------------------------------------------------------- |
| String length        | `length: { maximum: N }` on 444 columns in 176 models                                            | `string_column_length_validation_contract_test.rb`: 176 failing models → 0 |
| NOT NULL nil         | `exclusion: { in: [nil] }` on 142 columns                                                        | `not_null_column_nil_validation_contract_test.rb`: 126 failing models → 0  |
| Numericality         | `CHECK (column >= 0)` on 15 columns in 8 databases                                               | `numericality_check_constraint_contract_test.rb`                           |
| Required columns     | NOT NULL on 12 always-required columns in 6 databases                                            | `required_attribute_not_null_contract_test.rb`                             |
| Conditional presence | Removed always-true or unused guards on sign-up flow `step`/`state` and actor `access_state` (9) | existing suite                                                             |

The ChronicleRetentionPolicy `duration_days >= 0` CHECK was not reported by the checker, because an
unrelated CHECK mentions the column. The stricter contract test found it.

## Withdrawn after the full suite

A nil check on 73 columns changed tested behavior, so it was removed and the columns are listed in
`NIL_ALLOWED_BEFORE_SQL` with the reason: `Avatar.active_handle_id`, ownership transfer
`requested_at`/`expires_at`, Publishing `content_digest` and `body`, and `position_snapshot`.
`AvatarMoniker#moniker` validators are skipped for malformed UTF-8, because both validators call
`blank?`, which raises on invalid bytes. The domain validator still reports malformed input.

## Results

- `bundle exec database_consistency`: 1608 → 987 failures.
- Migrations: migrate, rollback and reapply passed on every touched development database. Schema
  dumps received only the new constraint, column and schema_migrations lines. Their index, foreign
  key, CHECK and NOT NULL statements matched regenerated dumps, apart from pre-existing `NOT VALID`
  drift in development databases.
- Final `bin/rails test`, run on test databases dropped and rebuilt from the dumps: 18036 runs, 3
  failures, 18 errors.
  - 20 of these failing tests are in the 2026-10-19 baseline (Avatar committed-concurrency, Inertia
    `clearHistory`, `inertia_rails/devtools` routes).
  - The other one is `BaseIdentityActivityLogPresenterTest` deduplication. It passed three times
    when its file ran alone, and it depends on rows that other non-transactional tests leave behind.
    It is recorded as order-dependent and was not fixed here.
- One test was changed: `avatar_authority_lifecycle_constraint_test.rb` raw inserts now supply the
  membership status that the column requires. The test still checks the same duplicate rejection.

## Remaining (not changed: behavior would change, or a decision is pending)

- UniqueIndex 430: operations rescue `RecordNotUnique` by constraint name; validators would change
  the exception.
- MissingDependentDestroy 222: deletion behavior.
- Length 216 `public_id`: user decision D2.
- Null 73: listed above.
- ColumnPresence 24: projected-record saves (C7/C11), plus
  `plans/backlog/2026-10-20-required-belongs-to-nullified-on-parent-delete.md`.
- ThreeStateBoolean 15, MissingIndex 3, ForeignKey 3, ForeignKeyCascade 1: existing backlog notes.
