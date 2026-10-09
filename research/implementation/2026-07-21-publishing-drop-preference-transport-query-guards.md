# Publishing Drop, Preference Transport, And Query Guards

## Context

- Related decisions: `adr/publishing-db-content-authority.md` and
  `docs/operations/publishing-legacy-table-drop-deployment-checklist.md`.
- The production legacy-table DROP remains unapproved and unexecuted.
- Review found that preference response transport was emitted inside a database rotation that could
  still roll back, and that publishing index serialization issued three association queries per
  entry.

## Decisions Made During Implementation

- The app/com/org legacy DROP migrations use one fail-closed migration-only module. Production
  requires an exact operator approval value, while every environment requires the full expected
  table set and zero rows.
- Known dependency ordering replaces `force: :cascade`; unexpected schema state is an error rather
  than an idempotent skip.
- Preference guest persistence and response transport are separate operations. Sign-out commits
  guest creation, safe-copy seeding, and old-row retirement before issuing refresh, DBSC, or access
  transport.
- Publishing entries expose scoped active-publication and canonical-slug associations. The index
  preloads those associations and the published version, reducing the measured `1 + 3N` query
  pattern to a fixed maximum of four queries.
- Pagination and the public JSON response contract remain unchanged.

## Review Notes

- Production DROP execution was not performed and still requires separate human approval, backup
  verification, and the production audit.
- Targeted verification passed: 129 tests, 633 assertions, no failures or errors. Targeted RuboCop
  and `bin/rails zeitwerk:check` also passed.
- The full Rails suite completed with 9,395 tests and 44,885 assertions, with one failure and ten
  errors outside the touched boundaries. Observed failures included missing Avatar persona
  identity-state setup, an Actor NullValue expectation mismatch, and missing `assert_not_includes`
  assertions in the repository-language tooling tests.
