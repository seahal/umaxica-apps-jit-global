# Engine Extraction Prep Phase 4 And 6 Note

This note records the completion of the remaining work from the engine extraction prep plan.

## Status

Completed on 2026-04-07.

## Context

The active prep plan tracked two remaining items:

- Phase 4: dynamic `robots.txt`, sitemap helper, and health response fixes
- Phase 6: Debride investigation with no code deletion

## Evidence

- `app/controllers/concerns/robots.rb` now returns surface-specific `robots.txt` content and sets
  cache headers.
- `app/controllers/concerns/sitemap.rb` now includes `sitemap_entry(...)` for XML builder call
  sites.
- `app/controllers/concerns/health.rb` now returns `revision` and `surface` in JSON, and the
  destructuring bug is fixed.
- `test/controllers/concerns/health_test.rb`, `test/concerns/robots_test.rb`, and
  `test/concerns/sitemap_test.rb` cover the current behavior.
- `bin/debride` was run and saved a report to `tmp/debride_report.txt` for local review.

## Debride Summary

The report lists many low-confidence "might not be called" methods across the codebase. This was an
investigation step only. No code was deleted based on the report.

## Consequences

- The remaining prep work is complete.
- The prep plan can stay out of `plans/active/` and the result is preserved here for traceability.
