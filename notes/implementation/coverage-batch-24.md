# Coverage Batch 24

Date: 2026-07-17 UTC

## Scope

Rails coverage only. VP/Vitest commands were intentionally not run.

## Coverage Snapshot

- Starting Rails line coverage: 91.3153% (45,065 / 49,351 lines).
- Ending Rails line coverage: 91.3132% (45,064 / 49,351 lines).
- Reported aggregate line delta: -0.0020 percentage points.
- Starting Rails branch coverage: 70.5372% (10,333 / 14,649 branches).
- Ending Rails branch coverage: 70.5236% (10,331 / 14,649 branches).
- VP coverage: not measured in this Rails-only batch.

The aggregate result varied slightly despite the targeted lines becoming fully covered. The full run
again excluded one SimpleCov result older than the 600-second merge timeout, and the report also
showed the usual runtime database warnings. The targeted controller evidence is stronger than the
small aggregate fluctuation: all three Side sitemap controllers now report 100% line coverage.

## Failures / Errors

- Starting failures / errors: 0 / 0.
- Ending failures / errors: 0 / 0.
- Ending full run: 9,138 runs, 43,513 assertions, 0 skips.

## Selected Targets

1. `Side::App::SitemapsController`.
2. `Side::Com::SitemapsController`.
3. `Side::Org::SitemapsController`.

Core sitemap controllers were not selected because the repository has no matching Core sitemap
templates; coverage-only tests would not prove a valid user-facing flow.

## Tests Added

- `test/integration/static_assets_endpoints_test.rb`
  - added Side app, corporate, and staff sitemap surfaces to the existing real-request matrix.

Focused verification passed: 3 runs, 80 assertions, 0 failures, 0 errors, 0 skips.

Ending target coverage:

- `app/controllers/side/app/sitemaps_controller.rb`: 7 / 7 lines.
- `app/controllers/side/com/sitemaps_controller.rb`: 7 / 7 lines.
- `app/controllers/side/org/sitemaps_controller.rb`: 7 / 7 lines.

## App / DB Changes

- No application or database files changed.
- No dead-code deletion was attempted.

## Dead-Code Evidence

- None. This batch was test-only.

## Commands Run

- `bin/rails test test/integration/static_assets_endpoints_test.rb`
- `bundle exec rubocop -a`
- `COVERAGE=true bin/rails test test/`

RuboCop auto-corrected unrelated pre-existing formatting in
`test/support/parallel_test_database_cloner.rb` and its test; those out-of-scope corrections were
restored.

## Skipped Risky Areas

- VP/Vitest tests and coverage, including `vp test --coverage`, were skipped by explicit scope.
- Authentication, sessions, OIDC, tokens, payment, withdrawal, external integrations, routes,
  configuration, fixtures, factories, CI files, and dependencies were not changed.
- Core sitemap controllers were deferred because their corresponding templates are absent.
- Runtime warnings and external paths were not investigated outside the repository.

## Next Batch Candidates

- Continue with deterministic read-only surfaces that have existing templates and route tests.
- Prefer targets where full aggregate coverage is stable and avoid incomplete controller/template
  pairs or security-sensitive flows.
