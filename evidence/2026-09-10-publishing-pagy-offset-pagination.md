# Publishing Pagy offset pagination

Date: 2026-09-10

## What was verified

- Locked Pagy version: 43.6.2 (`Gemfile.lock`).
- Shared collection pagination uses `pagy(:offset, relation, limit: 20, page:, raise_range_error: true)` after `include Pagy::Method` on `PublishingContentRendering`.
- Twelve cells (`info|docs|news|help` × `app|com|org`) share that concern and expose `{ data, page: { current, previous, next, last } }`.
- `PublishingEntriesCursor` is deleted; `next_cursor` / `has_more` / caller `limit` are gone from the public contract.

## Commands

- `bin/rails test test/contracts/publishing_entries_pagination_contract_test.rb test/contracts/openapi_content_entries_contract_test.rb test/queries/publishing_published_entries_query_test.rb` — 65 runs, 0 failures.
- `bin/rails test test/tooling/architecture_baseline_test.rb test/contracts/publishing_entries_pagination_contract_test.rb` — 15 runs, 0 failures.
- `bin/rubocop` on touched Ruby files — 0 offenses.
- `bun run openapi:lint` — valid.

## Notes

- `bin/rails test` (entire suite) did not load: pre-existing duplicate `test "Token.extract_resource_type returns nil for nil payload"` in `test/controllers/concerns/auth/base_test.rb` (lines 250 and 496). That file is not part of this change.
- No index was added. Early-page OFFSET 0 / LIMIT 20 remains the first-page path; deep OFFSET is a documented future measurement.
