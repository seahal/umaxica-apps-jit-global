# Strict Loading diagnostic

Work performed against commit `aa92265b7e63bf874fddd0aa8f278d5ed19de6b5` on branch `feature`.
The worktree was dirty with task and unrelated edits; no existing work was discarded. All Rails
commands used the ordinary `test` database with `POSTGRESQL_ISOLATED_TEST_RUN_ID` unset, as
requested. The isolated disposable fleet required by `one.md` was not used.

The test environment now sets `strict_loading_by_default = true`,
`strict_loading_mode = :all`, and `action_on_strict_loading_violation = :raise`. Production and
development settings were not changed.

Direct observation with `RAILS_ENV=test bin/rails runner` confirmed A–D: the effective settings
were `true/:all/:raise`; traversing unloaded singular and collection associations raised
`ActiveRecord::StrictLoadingViolationError`; preloaded singular and collection associations
succeeded. The probe read existing rows and made no database writes.

The existing Prosopite N+1 regression did not retain its detection ability under `:all`:
`bin/rails test test/integration/prosopite_smoke_test.rb:18` ran 1 test and failed because
`ActiveRecord::StrictLoadingViolationError` was raised before `Prosopite::NPlusOneQueriesError`.

One full diagnostic Rails run was completed on the ordinary test database:
`env -u POSTGRESQL_ISOLATED_TEST_RUN_ID RAILS_ENV=test PARALLEL_WORKERS=1 bin/rails test`.
It finished with 15,224 runs, 84,592 assertions, 102 failures, 3,833 errors, and 0 skips. The
output showed strict-loading errors across OIDC logout, Avatar creation, authentication admission,
preference persistence, RP session issuance, social identity, publishing, enforcement and other
paths. `log/test.log` contains 401 occurrences of `ActiveRecord::StrictLoadingViolationError` and
2 occurrences of `TestSupport::ExternalCommunicationError`; these are log occurrences, not a
complete classification of Minitest errors. The full run completed, so no tests were left unrun.

The CSRF logout regression group passed after supplying both Base authority and RP cookies and
real session-bound tokens: 6 files, 26 runs, 291 assertions, no failures, errors or skips.
RuboCop passed for the seven touched Ruby/configuration files, and `git diff --check` passed.

The strict-loading result is not clean. Per the stop condition in `one.md`, the strict-loading
setting and application associations were not adjusted after this diagnostic.
