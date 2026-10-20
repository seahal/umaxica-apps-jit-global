# NanoID public_id fixed at 21 characters

Date: 2026-10-20 HEAD: `87c15e1e5d89344db7dcaaa85ebb1f6972c0c829` Worktree: other uncommitted
database_consistency work was present
(`evidence/2026-10-20-model-validation-and-check-constraints-V5T3.md`,
`evidence/2026-10-20-rails-182206b-compatibility-R3K9.md`). Rails revision `182206b65670`.

## Decision

On 2026-10-20 the user amended `adr/identifier-contract.md`. NanoID is always 21 characters, so
every NanoID `public_id` is stored as `varchar(21)` with `CHECK (char_length(public_id) = 21)`, and
the model validates exactly 21 characters. The earlier storage capacity of 25 is withdrawn.

## Scope check

- 264 models include `PublicId` and have a `public_id` column. All of them generate the value with
  `PublicId.generate` (NanoID, 21 characters). Before the change, 216 were `varchar(21)` (109 with
  an exact-21 CHECK), 46 unbounded, 1 `varchar(25)` and 1 `varchar(255)`.
- Development and test data: all 222 stored values matched `/\A[A-Za-z0-9_-]{21}\z/`. Production
  data was not inspected. Each CHECK is added NOT VALID and validated in a separate migration, so a
  non-conforming production row stops the validation step without changing data.
- `logout_transactions`, `members`, `posts` and `post_versions` are not written through the PublicId
  concern. By design they keep their 25-character capacity check.

## Changes

- `PublicId` validates `length: { is: 21 }`, and `STORAGE_SIZE` was removed.
- 26 databases, 155 tables, migrations `20261020130000` and `20261020130001`: the column is narrowed
  to `varchar(21)` where needed, the old `*_public_id_max_length` (<= 25) checks are removed, and
  `chk_<table>_pid` is added and then validated.
  - Four tables carry `BEFORE UPDATE OF public_id` immutability triggers. Their migration drops and
    recreates each trigger from `pg_get_triggerdef` around the type change.
  - Migrate, rollback and reapply passed on every development database. The recreated triggers match
    the dumps apart from schema qualification.
- Dumps: only the `public_id` column lines, the added and removed checks, and schema_migrations rows
  were applied. These lines matched dumps regenerated from the migrated databases for all 26
  databases.
- Tests:
  - `test/support/public_id_fixed_length_assertions.rb` checks the column type, 20/21/22-character
    model and database boundaries, and the nil and empty partitions.
  - Every one of the 264 models' own `test/models/<model>_test.rb` calls it (202 files created, 62
    extended). `test/models/public_id_fixed_length_contract_test.rb` guards that no PublicId model
    skips it.
- Test data:
  - 38 non-NanoID fixture values and their literal references in tests were padded to 21 characters
    with `x`. Padding with `0` first created six-digit runs that the log filter redacted in Secret
    Chronicle metadata, which failed `ClientSecretAuditDeliveryJobTest`.
  - Tests that built short random values now use `PublicId.generate`.
  - Two tests that stored a blank `public_id` now assert that the database refuses it.

## Results

- `bundle exec database_consistency`: 889 → 673. All 216 public_id LengthConstraint findings are
  gone.
- Full `bin/rails test` on test databases rebuilt from migrations only: 18376 runs, 21 failures and
  errors. 20 are the known baseline. The 21st was `Core::Com::Api::V0::SessionsControllerTest`'s
  blank-visitor case, rewritten as above. That file then passed (5 runs, 0 failures).
