# WU-A1 ORG sign-in fixture scope recheck

- HEAD: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`. Before this evidence file was added, the
  worktree had 503 modified tracked paths and 240 untracked paths; none were staged.
- A first fresh run of the ORG sign-in controller file stopped during the global `fixtures :all`
  setup because an unrelated `persona_memberships` fixture referenced a missing Enterprise. The
  controller cases did not run. The class uses only `operators` and `operator_statuses`, so its
  fixture table list is now restricted to those two existing fixtures.
- Re-ran
  `PARALLEL_WORKERS=1 RUBYOPT=-W0 bin/rails test test/unit/security/sign_entry_classification_guard_test.rb test/controllers/auth/org/sign_ins_controller_test.rb`
  after loading `.env.container.devcontainer`: 16 runs, 108 assertions, 0 failures, 0 errors, 0
  skips. This includes all nine ORG controller tests and the seven declaration/action classification
  guard tests.
- `ruby -c test/controllers/auth/org/sign_ins_controller_test.rb`,
  `bin/rubocop test/controllers/auth/org/sign_ins_controller_test.rb`, and `git diff --check`
  passed. No application code, schema or database rows were changed.
- This resolves the fixture-setup interruption for these files only. It does not close the complete
  WU-A1 runtime matrix; the full suite was not run.
