# Logout proof mismatch and realm regressions

Recorded 2026-10-15 UTC against commit `7d4e2d941f4eb576eb77076c2c2a4e54badfa847`, with uncommitted
application/test/documentation changes present.

After correcting the non-APP unavailable response, the existing Core COM/ORG, Warp COM/ORG and Base
COM/ORG sign-out files passed 22 runs / 210 assertions / 0 failures / 0 errors / 0 skips. The
initial broader command named a nonexistent Edit controller-test file and failed before running
tests; the corrected command selected the six existing files. Edit authority behavior is exercised
by the separate authority-first integration file.

Extended the twelve-client completion matrix with a one-byte-modified 32-byte intent proof, while
retaining the correct browser session and Rails authenticity token. Every client returns 422, leaves
the transaction at origin_cleanup_issued and does not finalize. The subsequent valid continuation
still succeeds. This is new missing rejection coverage; no further application change was needed.
Matrix result: 1 run / 459 assertions / 0 failures / 0 errors / 0 skips.

Commands used
`env -u POSTGRESQL_ISOLATED_TEST_RUN_ID RAILS_ENV=test PARALLEL_WORKERS=1 bin/rails test` with the
named files, on normal Rails test databases. Targeted RuboCop inspected the three production/matrix
files without offenses, then the extended matrix without offenses. Scoped diff checking passed. No
database reset or isolated fleet was used. Complete authority-flow coverage and real-browser
acceptance remain separate unfinished work.
