# O-10 Support Case request-path verification

Date: 2026-11-05

HEAD: `b30345216886c98af1f04cbd434f067f12decf01`. The worktree had extensive uncommitted changes,
including the Case implementation and test fixture changes.

The Base ORG Support Case controller requests previously stopped before their actions because the
test fixture did not enroll a Base ORG RP-local session or send its session cookie. The fixture now
enrolls the local session through `RpCallbackCommitter` and sends
`OidcRpBrowserCredentialContract::SESSION_COOKIE`. This corrects an earlier `zero.md` diagnosis that
attributed the 401 to a missing client assertion.

Verification used configured test databases only. The focused command
`RAILS_ENV=test PARALLEL_WORKERS=1 bin/rails test test/controllers/base/org/support/enforcement_cases_controller_test.rb test/operations/enforcement_case_apply_failure_test.rb test/operations/enforcement_case_apply_authority_test.rb test/operations/enforcement_case_apply_concurrency_test.rb test/operations/enforcement_case_end_missing_principal_test.rb`
passed **34 runs / 130 assertions / 0 failures / 0 errors / 0 skips**. `bundle exec rubocop` on the
four changed Case operation/model files and the controller test passed (5 files, no offenses). Ruby
syntax checks passed for those five files. Scoped `git diff --check` passed.

This confirms the request tests reach the Case actions and the focused operation regressions pass.
It does not establish actor-lock versus OP-lock ordering on independent connections for every Case
path, and it does not complete the full O-10 lock graph. No production or development database was
accessed.
