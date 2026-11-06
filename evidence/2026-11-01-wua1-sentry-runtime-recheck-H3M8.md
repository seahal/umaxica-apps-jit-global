# WU-A1 Sign Entry Sentry runtime recheck

HEAD: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`. Before this evidence file was added, the worktree
had 730 status entries: 500 modified tracked files and 230 untracked files, with no staged files.
Existing changes were preserved. No commit was created.

Loaded `.env.container.devcontainer` and ran the selected WU-A1 boundary suites with
`PARALLEL_WORKERS=1`:

- `test/unit/security/sign_entry_classification_guard_test.rb`
- `test/integration/sign_entry_sentry_test.rb`
- `test/integration/sign_entry_sentry_parent_failure_test.rb`
- `test/resolvers/sign_entry_sentry_resolver_test.rb`
- `test/integration/acceptance_wu29_sign_entry_sentry_blocked_test.rb`
- `test/integration/acceptance_wu29_sentry_toggle_test.rb`
- `test/integration/acceptance_wu29_root_login_sentry_test.rb`

The first command completed with 30 runs, 244 assertions, 0 failures, 0 errors, and 0 skips. The
second completed with 5 runs, 136 assertions, 0 failures, 0 errors, and 0 skips. The selected
results cover route/action classification, APP/ORG Sentry behavior, verified-parent resolution,
unavailable-parent refusal, preservation of an attached-but-unconfirmed Admission while blocked,
availability flag changes across requests, and blocked-root boundaries. Existing NanoID
frozen-string warnings appeared.

This is a selected runtime recheck, not closure of WU-A1. The earlier baseline-listed ORG sign-in
controller failures and the remaining WU-A1 runtime matrix are unresolved. No full test suite was
run and no code was edited during either test run.
