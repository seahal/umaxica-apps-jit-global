# Uniqueness Enforced by Database Indexes Without Model Validation

Recorded 2026-10-20. Status: backlog, case-by-case review required.

## Situation

`database_consistency` reports 332 `UniqueIndexChecker` findings: a unique index exists but the
model has no matching `validates ... uniqueness`. By design, this application lets PostgreSQL detect
duplicates and handles `ActiveRecord::RecordNotUnique`, often matching the constraint name.
`Publishing::CreateEntryOperation` turns a slug collision into a 422, and the OTP, step-up, logout,
receipt and idempotency-key paths resolve concurrent requests the same way. No duplicate data is
admitted: the index always refuses it.

Adding uniqueness validations to all 332 at once (2026-10-20, reverted) failed 2052 tests. A
validation raises `RecordInvalid` before SQL, so the `RecordNotUnique` handling never runs. It also
adds a SELECT per save and still races under concurrency
(`evidence/2026-10-20-model-validation-and-check-constraints-V5T3.md`).

The rest of the uniqueness work is done: unique indexes that include the primary key have matching
validations declared with `allow_nil: true, if: :will_save_change_to_id?`.

## Rails validation and the database index differ

- Concurrency: the validation is a separate SELECT then INSERT; only the index is atomic.
- Failure: `RecordInvalid` with `errors`, against `RecordNotUnique` with a constraint name.
- NULL: without `allow_nil`, the validation treats nil as a duplicate. PostgreSQL treats NULLs as
  distinct.
- Case and expressions: `case_sensitive` against collation or expression indexes such as
  `lower(email)`.
- Partial indexes need an equivalent `conditions:`.
- `update_columns`, `insert_all` and raw SQL skip the validation, but never the index.
- A validation query routed to a replica can miss rows not yet replicated.

## Review per index

Classify each finding:

- A. A duplicate can come from user input (slug, vocabulary key, email). Consider a validation for a
  readable error, and update the `RecordNotUnique` handling in the same change.
- B. The index resolves concurrent requests (OTP, step-up, logout flow, idempotency keys). Keep
  database-only enforcement.
- C. Duplicates do not occur in practice (random digests such as `state` or `jti`). A validation
  adds only a query.

Separately, find writes that do not handle `RecordNotUnique` where a user can cause a duplicate.
Those return a 500 instead of a readable error.

The user decided on 2026-10-20 not to record this design in an ADR.
