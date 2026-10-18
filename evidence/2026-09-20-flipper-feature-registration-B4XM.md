# Flipper feature registration

Date: 2026-09-20

## Problem observed

`RetentionPurgeJob` logged `Could not find feature "retention_purge_suspended". Call
Flipper.add(...)` on every run (every 15 minutes, per `config/recurring.yml`).

Cause: `app/values/feature_flags.rb` declares flag names, but nothing writes them into the
Flipper store. `db/seeds.rb` writes only the `:availability` flags, development only. No
`Flipper.add` call existed anywhere in the repository. A `:suspension` flag is fail-open, so
reads were correct and the purge ran normally; only the warning and the empty Flipper UI
resulted.

## Change

Added `lib/tasks/feature_flags.rake` with two tasks:

- `feature_flags:register` -- `Flipper.add` for every name in `FeatureFlags.names`. Creates
  without enabling, so it changes no operator-chosen state.
- `feature_flags:status` -- prints each flag with its polarity and current state, reading
  through `FeatureFlags.enabled?` rather than `Flipper` directly.

## Verification (development environment)

- `bin/rails feature_flags:register` -- created every registry flag; a second run reported
  every flag as `present`, confirming idempotence.
- `bin/rails feature_flags:status` -- all `:suspension` flags read `off` except
  `retention_purge_suspended`, which read `on`.
- `bundle exec rubocop lib/tasks/feature_flags.rake` -- no offenses.
- `bin/rails test test/security/invariants/feature_flag_registry_invariant_test.rb` --
  4 runs, 223 assertions, 0 failures.

## Finding requiring an operator decision

`retention_purge_suspended` is **on** in the development store, so `RetentionPurgeJob` returns
early without purging. It was enabled manually while diagnosing the warning; it was not
enabled by this change (`Flipper.add` cannot enable). Deciding whether to
`Flipper.disable(:retention_purge_suspended)` is an operator call and was left untouched.

Production and other environments were not inspected in this session.
