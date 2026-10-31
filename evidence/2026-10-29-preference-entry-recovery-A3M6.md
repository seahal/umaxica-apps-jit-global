# Preference recovery and admission redirect tests

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`. Extensive uncommitted worktree changes affected these results.
- Updated existing app/org recovery tests to follow the current automatic admission redirect. They retain checks for missing, mismatched, revoked and expired preference credentials, no unintended record writes, and expiry boundaries.
- With `POSTGRESQL_TEST_PREPARE_DATABASES` set to the existing `.env` value and `PARALLEL_WORKERS=1`, `bin/rails test test/integration/preference_entry_recovery_test.rb` ran 17 tests and 94 assertions: 1 failure, 0 errors, 0 skips. The remaining replay case expects the old Auth sign-in POST flow; current Auth routes declare the sign-in session as show-only, so that case needs a replacement exercising replay at a current write boundary. It was not removed.
- Earlier focused runs of the missing-record tests passed 2 runs and 24 assertions, and the expiry-boundary case passed 1 run and 17 assertions.
- No full-suite rerun was performed after the changes. Test database preparation was used; no production persistence operation or external write was performed.
