# WU-A2 App/Org public OIDC Cancel path recheck

- HEAD: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`; the worktree had uncommitted changes.
- Ran
  `bin/rails test test/integration/sign_entry_exit_org_flow_test.rb:38 test/integration/sign_entry_exit_flow_test.rb:83`
  with the repository's local nonsecret environment contract loaded.
- Result: 2 runs, 42 assertions, 0 failures, 0 errors, 0 skips. Both App and Org flows returned
  `access_denied` through the Visa continuation and retained the canceled OIDC parent.
- This verifies the selected public Cancel paths only; it does not close WU-A2/A3 or `two.md`. The
  full suite was not run.
