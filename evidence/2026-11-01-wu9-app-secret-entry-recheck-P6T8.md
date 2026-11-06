# WU-9 APP Secret entry recheck

- HEAD: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`. The worktree already had 552 changed or
  untracked paths before this evidence was added; checks ran against that uncommitted state. No
  commit was created.
- `test/integration/app_secret_parallel_login_test.rb:128` passed: 1 run, 37 assertions, 0 failures,
  0 errors, 0 skips. This browser journey entered through an APP Secret, submitted the current Visa
  POST continuation, and observed one Root Session and one matching Secret sign-in receipt despite
  duplicate callback submission.
- Re-ran `test/integration/app_secret_login_journey_test.rb:654`: 1 run, 24 assertions, 1 failure, 0
  errors, 0 skips. Manual Secret storage-confirmation returned HTTP 503 at the expected 303
  assertion; it reached and passed the earlier Step-Up checks. The current controller maps both
  `ClientSecretStorageConfirmationCommitter::TransactionConflict` and `DependencyFailure` to 503.
  The writer refuses an open OP transaction, while this integration-test class has not disabled
  Rails transactional fixtures. This is a source-based test-harness attribution; no isolated
  independent-commit HTTP confirmation test was run to establish the full manual delivery path.
- No production code changed in this slice. Scoped RuboCop for the prior Preference reader test and
  `git diff --check` passed. No migration, production/Neon operation, or full-suite run occurred.
  APP Secret sign-in through Visa has current focused evidence, but the complete WU-9 matrix and the
  manual storage-confirmation HTTP journey remain unverified.
