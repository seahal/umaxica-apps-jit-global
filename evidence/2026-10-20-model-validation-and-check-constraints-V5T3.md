# Model validations, CHECK constraints and NOT NULL columns for database_consistency

Date: 2026-10-20 HEAD: `87c15e1e5d89344db7dcaaa85ebb1f6972c0c829` Worktree: uncommitted changes from
the 2026-10-19 and earlier 2026-10-20 database_consistency work, another agent's remediation
(stopped before this work began), and unrelated edits were present. Schema dumps are the HEAD dumps
plus the hunks of this and the earlier sessions' migrations.

## Scope

Only changes that keep established behavior. Each step started from a failing contract test.

| Step               | Contract test                                                      | Change                                                                                                                                                                                |
| ------------------ | ------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Length             | `test/models/string_column_length_validation_contract_test.rb`     | `length: { maximum: N }` on 444 limited string columns in 176 models                                                                                                                  |
| Nil                | `test/models/not_null_column_nil_validation_contract_test.rb`      | `exclusion: { in: [nil] }` on 142 NOT NULL columns without defaults                                                                                                                   |
| Numericality       | `test/models/numericality_check_constraint_contract_test.rb`       | `CHECK (column >= 0)` for 15 columns in 8 databases                                                                                                                                   |
| Required           | `test/models/required_attribute_not_null_contract_test.rb`         | NOT NULL on 12 columns the model always requires (6 databases)                                                                                                                        |
| Presence           | existing tests                                                     | removed always-true or projection-only guards on sign-up flow `step`/`state` and `access_state`                                                                                       |
| Primary-key unique | `test/models/primary_key_unique_index_validation_contract_test.rb` | uniqueness validation for 98 unique indexes that include `id` (74 models), declared `allow_nil: true, if: :will_save_change_to_id?` so no query runs unless an explicit id is written |

- `public_id` stays excluded from the length contract, per user decision D2 in
  `specs/database-consistency-remediation/decisions.md`.
- Nil validation was reverted for 73 columns after the full suite showed established behavior
  changing. These are listed with reasons in `NIL_ALLOWED_BEFORE_SQL`: Avatar `active_handle_id`,
  ownership-transfer `requested_at`/`expires_at`, Publishing `content_digest`/`body`, and
  `position_snapshot`.
- `AvatarMoniker#moniker` skips the length and nil checks for malformed UTF-8. LengthValidator
  raised on that input, and AvatarMonikerValidator reports it instead.
- `ChronicleRetentionPolicy#duration_days` gained `CHECK (duration_days >= 0)`. The checker accepted
  the existing permanent/duration CHECK, but negative values could still be stored.
- Three required associations nullified on parent delete are left nullable:
  `plans/backlog/2026-10-20-required-belongs-to-nullified-on-parent-delete.md`.

## Results

- `bundle exec database_consistency`: 1608 → 889 failures. LengthConstraint 660 → 216 (public_id
  only), NullConstraint 215 → 73, NumericalityConstraint 14 → 0, ColumnPresence 45 → 24, UniqueIndex
  430 → 332.
- Migrations: migrate, rollback and reapply passed on every affected development database. The test
  databases were migrated as well.
- Schema dumps: only the new CHECK constraints, NOT NULL column lines and schema_migrations rows
  were applied to the existing dumps. Every remaining difference from regenerated dumps also existed
  before this change (NOT VALID foreign keys and CHECK re-deparse in the development databases).
- Final full `bin/rails test`: 18110 runs, 2 failures, 18 errors. The failing tests are exactly the
  20 in the earlier baseline (Avatar committed-concurrency receipts, Inertia `clearHistory`,
  `inertia_rails/devtools` routes), so no new failure remains.
- Previous full `bin/rails test`: 18036 runs, 7 failures, 18 errors. Compared with the earlier
  20-failure baseline, the only additional failures are 5 `BaseIdentityActivityLogPresenterTest`
  cases. They read ClientChronicle rows that non-transactional tests left committed, including rows
  created before this work. Run alone, that file passes: 14 runs, 0 failures. Reproduced in
  isolation by running `test/models/session_limit_resolution_transactionable_test.rb` (19 runs, 0
  failures) and then the presenter file (1 failure). That test commits session-limit resolutions,
  which write ClientChronicle rows. Its cleanup removes flows, tokens and resolutions with
  `delete_all`, never the chronicle rows, so the leak does not depend on model validation. Root
  cause: fixture loading resets the clients id sequence, so `Client.create!` reuses id 980190963
  that committed rows reference. Fixed in the tests: the presenter test clears chronicle rows for
  each freshly created client inside its transaction, and the session-limit test also cleans
  ClientChronicle and OperatorChronicle rows above its watermark.
- An intermediate full run found 32 regressions from the nil validation, which led to the 73 reverts
  above. The final run has none of them.

## Not done

- UniqueIndexChecker (332), checked by experiment: adding
  `validates :slug, uniqueness: { scope: :locale }` to PublishingEntrySlugRecord made
  `Edit::Org::Publishing::EntriesControllerTest#test_a_slug_already_used_in_the_same_locale_returns_422_without_creating_a_second_entry`
  error, because RecordInvalid now preempts CreateEntryOperation's RecordNotUnique rescue. The
  change was reverted, and the file matched its backup byte for byte. A bulk experiment then added a
  matching uniqueness validation (with the index predicate as `conditions`) for all 332 indexes in
  221 files. The checker reported 0 UniqueIndex findings, but the full suite had 2052 failing tests
  beyond the baseline (18110 runs, 143 failures, 1954 errors), concentrated in sign-in/sign-up, OTP,
  admission, secret login, session limit and avatar ownership transfer. All 221 files were restored
  and compared byte for byte. Operations such as `Publishing::PromoteRevisionOperation` and
  `CreateEntryOperation` rescue `RecordNotUnique` by constraint name, and a uniqueness validator
  would turn that into `RecordInvalid`.
- MissingDependentDestroyChecker (222), checked by experiment: in a temporary test (since deleted),
  destroying a media file used by a revision raised ActiveRecord::StatementInvalid from the RESTRICT
  foreign key. After adding `has_many ..., dependent: :delete_all` to MediaFile, the destroy
  succeeded and the revision's usage rows dropped to 0, silently losing content references.
  Vocabularies and taxonomy terms have BEFORE DELETE triggers that refuse every delete, so a
  dependent option there never runs and would misstate the design. The checker only accepts cascade,
  delete or nullify. 168 are Publishing history (taxonomy assignments, media usages, revision
  references), where RESTRICT keeps published history intact; the rest are authentication flow
  references of the same kind.
- ThreeStateBoolean (15), Core bridge cardinality (3), grant token foreign keys (3), the
  cross-database cascade (1) and required associations nullified on parent delete (3): recorded in
  `plans/backlog/2026-10-20-*.md`. The Publishing composite-FK target backlog is now resolved.
- ColumnPresence (21), checked by experiment: making the Organization/Persona title and name
  presence unconditional failed the `retains_saves_of_existing_records_projected_without_*` cases in
  `test/models/persona_organization_validation_contract_test.rb`. Making Publication
  `effective_from` presence unconditional failed `Publishing::RequiredCreationFieldsTest` on
  projected updates. All three files were restored and match their backups.

## Follow-up on 2026-10-20: the 73 withdrawn nil checks, item by item

- Correct records would be refused (25): Avatar `active_handle_id`, the 12 ownership-transfer
  `requested_at`/`expires_at` columns and the 12 `position_snapshot` columns. Each has a failing
  test. Improvement requested in
  `plans/backlog/2026-10-20-required-columns-assigned-after-validation.md`.
- The refusal changes form (48): `content_digest` × 24 goes from StatementInvalid to RecordInvalid,
  with all 12 contract tests failing. For `body` × 24, the nil check was applied to all 24 models
  and each model was then validated with `body: nil`. Every one of them reported
  `["must be a JSON object", :exclusion]` instead of `["must be a JSON object"]`. A string body was
  unchanged in all 24. The experiment was reverted, and the 24 files compared equal to their
  backups. Recorded in the same backlog file.
- After the test databases were dropped and rebuilt from migrations only (a schema-load rebuild
  lacks migration-seeded rows such as `OpAppProtocolEpoch` id 1), the full suite under the updated
  Rails revision `182206b65670` (Gemfile.lock changed outside this work) had 29 failures beyond the
  baseline:
  - `SchemaMigrationIfNotExistsTest`: the initializer no longer calls the removed
    `internal_string_options_for_primary_key`. The test now expects `primary_key: true`, as Rails'
    own SchemaMigration does. It passes under both Rails revisions.
  - 28 `ClientSecret*`/`AppSecretSignupJourneyTest` cases: these fail only under the new Rails
    revision. The same 7 files under the HEAD lockfile revision `72ffadb2073a` gave 65 runs and 1
    failure (the initializer test, since fixed). So the 28 come from the Rails update, not from
    these database changes.
