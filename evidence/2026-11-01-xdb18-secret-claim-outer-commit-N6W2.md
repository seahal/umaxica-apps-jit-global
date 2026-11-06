# XDB-18 Secret claim requires an independent source commit

- HEAD: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`. The worktree contains uncommitted changes to the
  files below; no commit was created, and the result applies to this worktree.
- Local test-database maintenance was required first: committed `enterprise_units`,
  `enterprise_unit_closures` and `persona_memberships` residue referenced non-fixture `enterprises`
  rows, so fixture loading failed while re-enabling foreign keys. Only those test rows were removed,
  and the disposable `test_*_N` worker clones were dropped so the next run rebuilt them from the
  cleaned base databases. No schema, migration or production data changed.

## Change

`ClientSecretClaimCommitter` now refuses to claim a Secret while the caller already owns a writing
transaction on the source connection:

- Added `ClientSecretClaimCommitter::TransactionConflict < ArgumentError`.
- `call!` invokes `require_independent_source_commit!` after `verify_claim_request!` and before the
  Secret lookup, Ticket lock or Zenith mutation. The check is
  `AppZenithRecord.connected_to(role: :writing) { AppZenithRecord.lease_connection.transaction_open? }`,
  so both a joined outer transaction and a savepoint are detected.
- This closes the reported defect where an outer `AppZenithRecord.transaction` rolled back the
  consumed Secret after a non-nil claim, making the Secret findable again.
- `bind_oidc_flow!` was left unchanged: it writes only Ticket state and consumes no source Secret.
- The direct caller `Auth::App::Sign::In::SecretsController#create` does not rescue this exception.
  An invariant violation therefore surfaces as an error instead of reporting an unauthenticated
  success; the normal request path has no outer source transaction and is unaffected.

## Tests

- `test/operations/client_secret_claim_concurrency_test.rb`: added joined and savepoint outer-Zenith
  transaction refusal cases. Each asserts the credential remains unclaimed, the Secret stays
  findable, and no `secret.claimed` audit fact exists after the outer rollback.
- `test/operations/client_secret_claim_committer_test.rb`: converted to
  `use_transactional_tests = false` with an explicit fixture subset and committed-record teardown
  (transactions are unlinked rather than deleted because admission bindings restrict deletion).

## Verification

Command prefix:
`set -a && eval "$(grep '^PREFERENCE_COM_JWT' .env.container.devcontainer)" && set +a`.

| Command                                         | Result                                                 |
| ----------------------------------------------- | ------------------------------------------------------ |
| `bin/rails test` on the 3 affected files, run 1 | 28 runs, 259 assertions, 0 failures, 0 errors, 0 skips |
| same, run 2                                     | 28 runs, 259 assertions, 0 failures, 0 errors, 0 skips |
| combined with the XDB-07 group (90 runs)        | 90 runs, 816 assertions, 0 failures, 0 errors, 0 skips |
| `bin/rubocop` on the 10 changed files           | 10 files inspected, no offenses detected               |

Affected files: `test/operations/client_secret_claim_committer_test.rb`,
`test/operations/client_secret_claim_concurrency_test.rb`,
`test/controllers/auth/app/in/secrets_controller_test.rb` (16 runs, 136 assertions, 0 failures, 0
errors in a single-worker run; its previous errors were the test-database fixture failure above).

## Not established

- The full Minitest suite was not rerun; Phase 2 was stopped by the owner.
- No successful end-to-end HTTP Secret claim was executed in a transactional integration test after
  the guard; the existing claim HTTP tests are baseline-listed failures or nontransactional.
- Only the writing-connection source transaction is detected; a caller transaction on a different
  connection or role is outside this guard.
