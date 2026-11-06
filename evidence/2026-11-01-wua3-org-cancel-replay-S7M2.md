# WU-A3 ORG cancellation replay

HEAD: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`. The worktree contained pre-existing uncommitted
changes; no staged changes were present. They were preserved.

Added an ORG public-flow integration case that starts a real OP authorization, cancels from the Auth
Sign In page, commits the Visa cancellation continuation, and replays the same continuation. The
test asserts that both RP outcomes are the same `access_denied` result, the OIDC parent, Admission
Binding, and Auth Ceremony stay unchanged after replay, and the browser cookie-name set does not
change.

With `.env.container.devcontainer` loaded, ran
`bin/rails test test/integration/sign_entry_exit_org_flow_test.rb:53`: 1 run, 16 assertions, 0
failures, 0 errors, 0 skips. Targeted RuboCop reported no offenses; Ruby syntax and scoped
`git diff --check` passed. This is a focused ORG cancellation replay check and does not close WU-A3
or the broader `two.md` acceptance. No production or Neon database was accessed.
