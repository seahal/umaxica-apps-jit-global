# database_consistency connection checkout failure: reproduction and repair verification

Date: 2026-10-19 (UTC, runs between 08:02 and 08:13)

## Revisions

- Application: work started at `ff58ff28125fafe405dc76809f6498b64d69e627`. During the work a
  concurrent agent committed `87c15e1e5d89344db7dcaaa85ebb1f6972c0c829` (08:02:22), recording the
  worktree changes that were already present (244 files, none under `config/environments/`). All
  runs below started at or after 08:02:29, so baseline and repaired runs used the same application
  code.
- Rails (application): `rails/rails` main `72ffadb2073a6f81696f4f6559eb6a7ce70496c7`, ActiveRecord
  `8.2.0.alpha`. Ruby 4.0.7.
- database_consistency: fork `seahal/database_consistency`, cloned at
  `vendor/fork/database_consistency/` (untracked by the application). Baseline: `3d94860` (upstream
  v3.0.16). Repair: local branch `fix/connection-api-compat`, commit `a5d7438` (not pushed).
- Application settings in effect unless overridden: `config.active_support.deprecation = :raise`
  (`config/environments/development.rb:75`) and
  `config.active_record.permanent_connection_checkout = :deprecated` (`development.rb:105`).

## Method

`bundle exec ruby <scratchpad>/dc_matrix.rb <checkout> <deprecation>` boots the application like
`bin/database_consistency`, then sets `ActiveRecord.permanent_connection_checkout` and
`Rails.application.deprecators.behavior` in-process (no configuration file edits), eager loads, and
calls `DatabaseConsistency.run` with the default configuration path. Under `:log` a counting
behavior is added that counts deprecation messages mentioning `ActiveRecord::Base.connection`.
"Internal errors" counts deprecated-connection error blocks in the generated diagnostic file. No
`--autofix` and no TODO generation were used.

## Results

| Gem      | checkout      | deprecation | exit | internal errors | connection deprecations logged | fail reports |
| -------- | ------------- | ----------- | ---- | --------------- | ------------------------------ | ------------ |
| baseline | `:deprecated` | `:raise`    | 1    | 7               | —                              | 0            |
| baseline | `:deprecated` | `:log`      | 1    | 0               | 27                             | 2119         |
| baseline | `true`        | `:raise`    | 1    | 0               | —                              | 2119         |
| baseline | `true`        | `:log`      | 1    | 0               | 0                              | 2119         |
| baseline | `:disallowed` | `:raise`    | 1    | 7               | —                              | 0            |
| repaired | `:deprecated` | `:raise`    | 1    | 0               | —                              | 2119         |
| repaired | `:deprecated` | `:log`      | 1    | 0               | 0                              | 2119         |
| repaired | `true`        | `:raise`    | 1    | 0               | —                              | 2119         |
| repaired | `true`        | `:log`      | 1    | 0               | 0                              | 2119         |
| repaired | `:disallowed` | `:raise`    | 1    | 0               | —                              | 2119         |
| repaired | `:disallowed` | `:log`      | 1    | 0               | 0                              | 2119         |

- The sorted fail-report lines of every repaired run were byte-identical to the baseline
  `true`/`:raise` run. Exit code 1 in those runs comes from the 2119 consistency findings, not from
  internal errors.
- Baseline failing runs printed "Some checks failed with an error" and wrote diagnostic files
  (`database_consistency_2026_10_19_08_02_29.txt`, `..._08_12_35.txt`); every error originated at
  `lib/database_consistency/helper.rb:50` (`Helper.connected?` calling `klass.connection`).
- The unmodified CLI with the application's own settings (`bundle exec database_consistency`,
  repaired gem) exited 1 with 2119 fail reports and no "Some checks failed with an error".

Cause: all three are needed — the gem calls `Model.connection`; the application opts into
`permanent_connection_checkout = :deprecated`; deprecations raise. With `:disallowed` the second and
third collapse into one: it fails regardless of deprecation behavior.

## Gem test suite (repaired branch, SQLite)

Dependencies were installed into the session scratchpad with `BUNDLE_GEMFILE=gemfiles/<name>`.

| Gemfile   | ActiveRecord                 | `Base.with_connection` | result                   |
| --------- | ---------------------------- | ---------------------- | ------------------------ |
| `ar_7_1`  | 7.1.6                        | no (fallback path)     | 454 examples, 0 failures |
| `ar_7_2`  | 7.2.4                        | yes                    | 455 examples, 0 failures |
| `ar_8_0`  | 8.0.5.1                      | yes                    | 455 examples, 0 failures |
| `ar_8_1`  | 8.1.4                        | yes                    | 455 examples, 0 failures |
| `ar_main` | 8.2.0.alpha (`bf6f1d5ca4bf`) | yes                    | 455 examples, 0 failures |

- New `spec/connection_checkout_spec.rb` (defined only when the setting exists): with the `lib`
  changes stashed it failed on `ar_8_1` with `RescueError.call` receiving
  `ActiveRecord::ActiveRecordError: Called deprecated ActiveRecord::Base.connection method`; with
  the repair it passed. The bug therefore reproduces on stable ActiveRecord 8.1.4.
- RuboCop (fork root Gemfile, rubocop 1.92.0, `--ignore-parent-exclusion` because the application's
  `.rubocop.yml` is a parent directory): 173 files inspected, no offenses.

## Not verified

- MySQL and PostgreSQL gem suites were not run locally (no databases configured for the gem).
- ActiveRecord 4.2–7.0 were not run locally; the upstream CI matrix on the fork is expected to cover
  them after a push.
- The upstream Issue and PR have not been submitted.

## Revision 2 (same day, ~08:30 UTC): `connection_pool.with_connection`, commit `d5d1781`

At the user's request the repair was rewritten to minimize the upstream diff: no new
`Helper.with_connection`; each `X.connection.foo` became
`X.connection_pool.with_connection { |conn| conn.foo }` (`&:name` where it fits), which exists on
all supported ActiveRecord versions without branching. The CHANGELOG entry was removed by the user.
`lib/` diff against `3d94860`: 18 files, +36/−28 (revision 1 commit `a5d7438`, superseded).

- Gem suites (SQLite): ar_7_1 454, ar_7_2/ar_8_0/ar_8_1/ar_main 455 examples, 0 failures.
- `spec/connection_checkout_spec.rb` with `lib/` reset to `3d94860` on ar_8_1: fails with
  `RescueError.call` receiving the deprecated-connection `ActiveRecordError`; passes on `d5d1781`.
- RuboCop: 173 files inspected, no offenses.
- Application matrix (all six checkout × deprecation combinations): exit 1, zero internal errors,
  zero connection deprecations, 2119 fail reports byte-identical to the baseline default run.
  `bundle exec database_consistency` with application settings: exit 1, 2119 fail reports, no "Some
  checks failed with an error", no new diagnostic file.
