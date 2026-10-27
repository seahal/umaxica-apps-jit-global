# Admission curfew boundary

HEAD: `aeb09ca9fb97ef1ca24c0195b2fa1d28d21245df`. The worktree contained uncommitted changes affecting this check.

- `PARALLEL_WORKERS=1 bin/rails test test/integration/admission_curfew_test.rb`: 8 runs, 71 assertions, no failures, errors or skips. The APP admitted page was served at a controlled database time one second before curfew; existing tests exercise cancellation at and after curfew.
- `bundle exec rubocop test/integration/admission_curfew_test.rb --format simple`: no offenses before the final clock-control adjustment.

The tests do not establish the same boundary for every consumer or surface; A06-1 remains partial.
