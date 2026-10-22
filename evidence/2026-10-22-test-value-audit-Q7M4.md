# Test value audit observations

- Date: 2026-10-22 UTC.
- Commit: `febec3225cc9a0cfa53b9cbe817d20d366aba5a2`.
- Worktree: pre-existing uncommitted production, test, configuration and documentation changes
  affected the inspected code and executions. No clean-HEAD comparison was performed. This audit
  added research/evidence documents only; it did not change production or test sources.
- Report: [test value audit](../research/2026-10-22-test-value-audit/README.md).

## Source inspection

Discovery used `git ls-files --cached --others --exclude-standard -z`, selecting `test/`, `gait/`,
`e2e/` and Ruby/JS/TS test/spec suffixes elsewhere. Installed dependencies and ignored generated
files were excluded. The manifest records 2,779 source/support/fixture files and their SHA-256
hashes. Its aggregate digest is
`174b5de48dd6b5041cf1d9f67c6bf5e4652e3ebbfae0e6147057640b7268869b`.

Temporary read-only extractors in `/tmp/umaxica-test-audit/` used Prism 1.8.1 under Ruby 4.0.7 and
the installed Babel parser with TypeScript/JSX plugins. They parsed 2,376 Ruby suffix files and
113 JS/TS spec files without parse errors. Nine private helpers/controller actions with `test_`
names were excluded after ownership/visibility inspection. The resulting inventory contains
14,756 source definitions: 13,659 Ruby, 1,064 Vitest and 33 Playwright. Loops and each tables can
expand one definition into multiple runtime tests. Two comment-only markers and one production
test-provider adapter contain no test definitions.

A separate read-only Prism parse indexed 3,349 production Ruby files and 20,351
class/module/method entries without parse errors. Static constant/import matching is recorded as
a candidate source relationship, not a verified runtime call trace.

Body token comparison found 107 groups containing 375 definitions. Surrounding setup, imports,
class bindings and generated parameters are outside the hash, so these counts are not redundant
test counts. The report distinguishes 37 confirmed finding groups affecting 59 definitions from
two candidate families affecting 51 definitions. Unreviewed individual semantic decisions remain
explicitly open; this is not a completed semantic approval/rejection of all tests.

## Executions

1. Focused ordinary Rails run:

   ```bash
   PARALLEL_WORKERS=1 bin/rails test \
     test/controllers/branch_coverage_batch35_zero_files_test.rb:71 \
     test/controllers/concerns/branch_coverage_batch13_mass_guards_test.rb \
     test/controllers/concerns/branch_coverage_batch15_more_auth_prefs_test.rb \
     test/controllers/concerns/branch_coverage_batch19_surgical_raises_test.rb \
     test/services/branch_coverage_batch39_easy_misses_test.rb
   ```

   Observed: seed 63566; 13 runs, 37 assertions, 0 failures, 0 errors, 0 skips; exit 0.

2. `bun run test`: 100 files passed; 1,160 tests passed; reported duration 13.47 seconds; exit 0.
   Coverage and whole-suite mutation analysis were not run.

3. A temporary Ruby process loaded selected suites and changed only process-local method
   definitions. `Health::DependencyResult#public_status` returned an incorrect synthetic value;
   both AppealReviewsController actions raised. Six selected tests produced eight assertions,
   one expected failure, no errors and no skips, seed 5451. The genuine `HealthTest` detected the
   wrong public status. Five suspect tests stayed green, including the Health case whose wrong
   constructor arguments trigger a test-local fallback and the appeal case that never invokes
   either controller action. Repository source files were not patched. This is a local
   counterexample, not a general mutation score.

4. The first `PARALLEL_WORKERS=4 bin/rails test` launch was refused by
   `ParallelTestDatabaseCloner.acquire_test_process_lock!` while the mutation process remained
   active. No full-suite result was obtained from that launch. After that process exited, the
   command was rerun sequentially: seed 55776; 18,421 runs, 159,883 assertions, 60 failures,
   1 error, 0 skips; reported test duration 503.127849 seconds; exit 1. The error was
   `ActiveRecord::RecordNotFound` in the wrong-email-code bootstrap test. All 61 unsuccessful
   runtime outcomes are indexed in the report's execution document. Root causes were not
   diagnosed or attributed to a particular existing change; failed tests were not classified as
   low value merely because they failed.

5. Browser E2E was not executed. All 13 Playwright spec files and both runner configurations were
   inspected statically. No production deployment or live external-provider behavior was
   verified.

6. The final document validation found exactly 14,756 unique inventory anchors across 98 Markdown
   files, checked 60,954 local links/source-line references and found no missing file, invalid
   line or missing generated anchor. All 2,779 source/support/fixture content hashes still
   matched the recorded manifest. The 61 unsuccessful runtime outcomes all mapped to source
   definitions. `git diff --check` passed for tracked changes; a separate whitespace scan of the
   new audit documents and this evidence record found no trailing whitespace.

Raw logs, response bodies, credentials and browser artifacts are not included in this record.
No test was removed, skipped or weakened, and no security guard allowlist was changed.
