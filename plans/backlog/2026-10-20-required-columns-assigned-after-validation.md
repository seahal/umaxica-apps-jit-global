# Required Columns Assigned After Model Validation

Recorded 2026-10-20. Status: backlog, improvement required.

## Problem

These columns are NOT NULL in the database, but the application leaves them nil during model
validation and fills them in later in the save, in callbacks, or with database triggers. A model
validation that rejects nil therefore refuses valid records. When this was tried on 2026-10-20
(`evidence/2026-10-20-model-validation-and-check-constraints-V5T3.md`), the listed tests failed and
the validation was withdrawn. `database_consistency` keeps reporting each as
`NullConstraintChecker ... does not have a validator disallowing nil values`.

| Columns                                                                                                                  | Count | Failing test                                                                                                    | Where the value comes from                                                |
| ------------------------------------------------------------------------------------------------------------------------ | ----: | --------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------- |
| `Avatar#active_handle_id`                                                                                                |     1 | `AvatarTest#test_requires_active_handle`                                                                        | assigned during creation, after validation                                |
| `requested_at`, `expires_at` on Agent, Bureau, ClientPersona, Company, Enterprise, Individual `OwnershipTransferRequest` |    12 | `OwnershipTransferRequestValidationTest#test_*_skips_party_and_expiry_checks_when_attributes_are_blank` (all 6) | assigned when blank, after validation                                     |
| `position_snapshot` on the 12 Publishing `VersionMultipleTaxonomyAssignment` models                                      |    12 | `Publishing::OrderedTaxonomyPositionContractTest#test_*_rejects_invalid_positions_on_creation` (all 12)         | `apply_snapshot` and the `publishing_version_assignment_snapshot` trigger |

## Required improvement

Assign each value before validation, for example in `before_validation` or in the creating
operation, so the record is complete when it is validated. Then add a nil-rejecting validation.
Write characterization tests first, accept the change only if observable behavior stays the same,
and remove the matching entry from `NIL_ALLOWED_BEFORE_SQL` in
`test/models/not_null_column_nil_validation_contract_test.rb`. The `AGENTS.md` rule against giving
NULL a meaning applies: no intermediate state may depend on the column being NULL.

## Columns where a nil check changes the refusal

For these 48 columns, the record is complete at validation time and nil is already refused, but a
nil-rejecting validation changes how the refusal looks. Each was checked one model at a time on
2026-10-20.

| Columns                                                                     | Count | Observed change                                                                                                                                                                                                                                                |
| --------------------------------------------------------------------------- | ----: | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `content_digest` on the 24 Publishing `EntryRevision`/`EntryVersion` models |    24 | Updating to nil raised `ActiveRecord::StatementInvalid` from PostgreSQL. With the check it raises `ActiveRecord::RecordInvalid`. `Publishing::ContentDigestContractTest` pins the database refusal (all 12 families, each test covering revision and version). |
| `body` on the same 24 models                                                |    24 | A nil body reported `["must be a JSON object"]`. With the check every one of the 24 models also reports `:exclusion`. `Publishing::EncryptedContentStorageTest` pins the single message.                                                                       |

Either keep the current refusal and accept the checker reports, or decide to change these contracts,
update the pinning tests in the same change, and then add the validation.
