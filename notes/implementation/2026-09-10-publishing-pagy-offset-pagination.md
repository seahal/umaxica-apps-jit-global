# Publishing Pagy Offset Pagination Implementation Notes

## Context

- Original plan/spec: replace signed-cursor public collection pagination with Pagy offset pages
- Related decisions/docs/plans: `adr/api-collection-contract.md` (superseded mechanism),
  `adr/api-collection-offset-pagination.md`
- Implementation date: 2026-09-10

## Decisions Made During Implementation

- Decision: include `Pagy::Method` on `PublishingContentRendering`, not `ApplicationController`.
  - Why: the twelve cells inherit `BareController`, which does not go through `ApplicationController`.
  - Alternatives considered: ApplicationController include (would miss these endpoints).
- Decision: parse `page` in the application and pass it to `pagy(:offset, ..., page:, raise_range_error: true)`.
  - Why: Pagy 43 `Request#resolve_page` coerces invalid values to 1.
  - Follow-up needed: none.
- Decision: no index added on `(effective_from, public_id)`.
  - Why: publications already have `entry_id` and a gist window exclusion; no EXPLAIN pathology was
    observed as an obvious missing index on early pages. Deep OFFSET remains a known limitation.
  - Follow-up needed: measure if collections grow large; Pagy `:keyset` is the intended next step.

## Deviations From Plan

- Change: management HTML listing still uses `PublishingManagementEntriesQuery` page objects.
  - Why: out of scope (authenticated RW UI).
  - Risk: two pagination styles exist in the repository until that UI is migrated.
  - Follow-up: org publishing RW UI task.

## Review Notes

- Tests run: focused publishing pagination and query tests, then `bin/rails test` and style gates.
- Documentation promotion needed: ADR accepted; OpenAPI bundled.
