# WU-A9 verified social subject guidance

- HEAD: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`.
- The worktree was already dirty with unrelated WU-9 and earlier-cycle changes; no commit was made.
- APP Google callback handling now renders HTTP 400 guidance for L1 only when a verified callback
  matches admitted sign-in, and for L2 only when it matches admitted sign-up. Both pages clear Auth
  continuity and link to the fixed Base `/sign` entry with normalized `ri` only. Other callback
  failures keep the generic response.
- `bin/rails test test/integration/social_login_admission_test.rb:230 test/integration/social_login_admission_test.rb:300`:
  2 runs, 53 assertions, 0 failures, 0 errors. The cases assert the new page, no-store/referrer
  headers, fresh-entry URL, cleared callback state, and no L1 account, identity, sign-up Flow or
  Root writes.
- `bin/rails test test/initializers/locale_bundle_integrity_test.rb`: 3 runs, 5 assertions, 0
  failures, 0 errors.
- `ruby -c` passed for the changed controller concern and integration test; YAML loading for both
  locale bundles and `git diff --check` passed.
- An earlier focused attempt stopped before L2 callback assertions because its selector bootstrap
  hit an existing cross-database persona uniqueness conflict. The unnecessary bootstrap was removed
  from that refusal-only test; the final focused run above passed.
- The full suite was not rerun in this slice.
