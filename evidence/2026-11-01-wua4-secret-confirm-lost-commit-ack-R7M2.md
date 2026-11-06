# WU-A4 XDB-06 Secret confirmation lost commit acknowledgement

HEAD: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`.

The worktree was already extensively dirty and had no staged changes. This test and its `four.md`
update are uncommitted.

Added a nontransactional APP test that disconnects the Zenith connection after PostgreSQL commits
storage confirmation and its source audits, then injects a lost acknowledgement. The first call
reports `DependencyFailure`; fresh reads show the issuance and candidate confirmed, one
`secret.storage_declared` row, one `secret.created` row, and consumed Step-Up. After issuing fresh
Step-Up bound to the same issuance, retry returns the existing confirmation, leaves the new proof
unconsumed, and does not duplicate either audit event.

Verification:

- Before the addition,
  `UMAXICA_ENV_FILE=/home/global/workspace/.env.container.devcontainer PARALLEL_WORKERS=1 bin/rails test test/operations/client_secret_storage_confirmation_concurrency_test.rb`:
  6 runs, 61 assertions, 0 failures, 0 errors, 0 skips.
- With the new case, the same file: 7 runs, 74 assertions, 0 failures, 0 errors, 0 skips.
- Focused new case: 1 run, 13 assertions, 0 failures, 0 errors, 0 skips.
- `UMAXICA_ENV_FILE=/home/global/workspace/.env.container.devcontainer PARALLEL_WORKERS=1 bin/rails test test/operations/client_secret_storage_confirmation_committer_test.rb`:
  9 runs, 157 assertions, 0 failures, 0 errors, 0 skips.
- `bundle exec rubocop test/operations/client_secret_storage_confirmation_concurrency_test.rb`:
  clean.
- `ruby -c test/operations/client_secret_storage_confirmation_concurrency_test.rb`: syntax OK.
- `git diff --check -- test/operations/client_secret_storage_confirmation_concurrency_test.rb`:
  clean.

The full suite was not run. This checks the APP manual-confirmation lost-ack path and fresh-proof
retry only; the broader XDB-06 cross-database audit and signup-specific authorization path remain
open.
