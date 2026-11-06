# WU-A4 XDB-06 Secret confirmation final Zenith commit boundary

HEAD: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`. The worktree had 527 status entries, including
this change; no staged changes were present. No commit was made.

Added a signed-in confirmation case that injects failure at the final Zenith commit after OP Step-Up
consumption. It verifies the issuance and candidate remain unconfirmed, neither
`secret.storage_declared` nor `secret.created` is committed, and the Step-Up evidence remains spent.

Ran with `.env.container.devcontainer` loaded:

- The new final-commit case passed: 1 run, 5 assertions, 0 failures, 0 errors, 0 skips.
- `PARALLEL_WORKERS=1 bin/rails test test/operations/client_secret_storage_confirmation_concurrency_test.rb`
  passed: 6 runs, 61 assertions, 0 failures, 0 errors, 0 skips.
- `ruby -c`, RuboCop and scoped `git diff --check` passed for the changed test file.

This verifies the signed-in XDB-06 final-Zenith-commit failure window. It does not establish the
sign-up confirmation path's complete cross-database boundary matrix.
