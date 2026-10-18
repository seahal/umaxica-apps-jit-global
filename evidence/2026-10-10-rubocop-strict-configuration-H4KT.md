# RuboCop strict configuration refactor

- Commit: `747ec3939c376be2513b860ec48901adb491decb`, with this refactor's changes uncommitted in
  the worktree.
- Date: 2026-10-10. Run inside `global-devcontainer-core`.
- Versions: rubocop 1.91.0, rubocop-ast 1.50.0, rubocop-rails 2.38.0, rubocop-performance 1.27.0,
  rubocop-minitest 0.41.0, rubocop-rake 0.7.1, rubocop-i18n 3.3.0, rubocop-thread_safety 0.8.0,
  rubocop-rubycw 0.2.2. rubocop-rails-omakase 1.1.0 was installed before and is removed.

## Before

| Measure                                                                           | Value                                      |
| --------------------------------------------------------------------------------- | ------------------------------------------ |
| `bundle exec rubocop`                                                             | 0 offenses, 5302 files                     |
| `bundle exec rubocop --ignore-disable-comments`                                   | 2171 offenses in 227 files                 |
| `rubocop:disable` / `rubocop:enable` / `rubocop:todo` in `app lib config db test` | 775 / 353 / 0                              |
| `Enabled: false` / `Exclude:` / `Allowed*` blocks in `.rubocop.yml`               | 6 / 17 / 4                                 |
| Tracked RuboCop cache                                                             | 51 files under `config/tmp/rubocop_cache/` |

## What removing the Omakase inheritance showed

rubocop-rails-omakase disables the Bundler, Gemspec, Layout, Lint, Metrics, Naming, Performance,
Rails, Security and Style departments and re-enables 43 cops. The project re-enabled Layout,
Security, Rails, Performance and Minitest but not Lint, Metrics, Naming or Style.

- With the `inherit_gem` removed and nothing else changed: 360 cops became enabled (245 `true`, 115
  `pending`), reporting 13,929 offenses in 2,719 files across 148 cops.
- `Metrics/ClassLength`, `ModuleLength`, `BlockLength`, `BlockNesting` and `ParameterLists` carried
  a project `Max` but were never enforced, because their department was off.

## After

| Measure                                                               | Value                                     |
| --------------------------------------------------------------------- | ----------------------------------------- |
| `bundle exec rubocop`                                                 | 0 offenses, 5304 files, exit 0            |
| `bundle exec rubocop --ignore-disable-comments`                       | 408 offenses in 140 files, 22 cops        |
| `rubocop:disable` / `rubocop:enable` (tracked Ruby, Rake, `scripts/`) | 243 / 150                                 |
| Cops enabled that were disabled before                                | 241 (163 `true`, 78 `pending`)            |
| Cops disabled that were enabled before                                | 0 (`--show-cops` before/after comparison) |
| Cops switched off individually as deferred debt                       | 117, plus the five Metrics limits above   |

Offenses with suppressions ignored, after: `I18n/RailsI18n/DecorateString` 151,
`Naming/MethodParameterName` 63, `ThreadSafety/ClassAndModuleAttributes` 57,
`Minitest/MultipleAssertions` 35, `Rails/SkipsModelValidations` 16, `Rails/HasManyOrHasOneDependent`
13, and 16 further cops with 11 or fewer each.

## How suppressions were removed

- 239 `rubocop:disable` comments were redundant (the cop did not fire there) and were deleted; 47 of
  them carried a reason, which was kept as an ordinary comment.
- 852 `assert <boolean expression>` calls that were suppressed for `Minitest/AssertEqual`,
  `AssertOperator`, `AssertSame`, `AssertPredicate`, `AssertMatch`, `RefuteEqual`, `AssertIncludes`,
  `AssertNil` and `AssertKindOf` were rewritten to `assert_withheld { ... }`
  (`test/support/withheld_assertions.rb`). The suppressions existed so that credentials and ceremony
  material are not printed on failure; the helper keeps that property.
- 105 `cookies.merge(...)` calls suppressed for `Lint/Void` now go through `store_raw_cookies`
  (`test/support/cookie_jar_helper.rb`).
- `ThreadSafety/NewThread` is excluded for `test/**` and `scripts/**` in configuration.

## Measured but not changed

- Migrations stay excluded from every cop (`db/**/*_migrate/**/*.rb`, 1,351 files). With that
  exclusion lifted, RuboCop reports 4,542 offenses in 454 migration files across 31 cops
  (`Style/MethodCallWithArgsParentheses` 3,474).
- `Layout/ClassStructure` for `app/models`: with the merged category order, 356 offenses in 180
  model files. No model was reordered; `Include` still names controllers only.

## Tests

`bin/rails test`, full suite, 14,906 runs:

| Run | When                                                           | Result              |
| --- | -------------------------------------------------------------- | ------------------- |
| 1   | after the configuration change and redundant-directive removal | 2 failures, 1 error |
| 2   | after the assertion and cookie-helper rewrites                 | 1 failure, 1 error  |

Failing in both: `PrimaryDatabaseOwnershipTest` (expects `test_primary_db_N`, got
`test_publishing_db_N`) and `RecoverySecretParallelGetTest` (`visitor_device_session is nil`).
Failing in run 1 only: `OidcSevenFirstPartyRpClientsTest` (missing private key for `CORE_APP`). None
of the three touches code changed here. They were not run against the commit before this refactor,
so "pre-existing" is an inference from their content, not an observation.

`Rails.application.eager_load!` was not run separately; the full suite loads the application.
