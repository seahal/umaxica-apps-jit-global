# XDB-07 credential removal requires an independent Ticket commit

- HEAD: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`. The worktree contains uncommitted changes to the
  files below; no commit was created, and the result applies to this worktree.
- Local test-database maintenance was required first: committed `enterprise_units`,
  `enterprise_unit_closures` and `persona_memberships` residue referenced non-fixture `enterprises`
  rows, so fixture loading failed while re-enabling foreign keys. Only those test rows were removed,
  and the disposable `test_*_N` worker clones were dropped so the next run rebuilt them from the
  cleaned base databases. No schema, migration or production data changed.

## Change

`IdentityCredentialRemovalCommitter` now refuses to run when the caller already owns a writing
transaction on the Ticket connection:

- Added `IdentityCredentialRemovalCommitter::TransactionConflict < ArgumentError`.
- `call!` invokes `require_independent_ticket_commit!` after `validate_binding!` and before any
  lock, evidence consumption or Zenith mutation. The check is
  `current_session.class.connection_class_for_self.connected_to(role: :writing) { lease_connection.transaction_open? }`,
  matching `IdentityTotpNameCommitter` and `IdentityPasskeyNameCommitter`.
- The exception inherits `ArgumentError`, so existing controller rescues keep the current HTTP
  contract; no response shape was changed. C-1 (422/503) remains gated and unimplemented.

## Tests

- `test/concurrency/identity_credential_removal_commit_order_test.rb`: added joined and savepoint
  outer-OP-transaction refusal cases for APP TOTP and ORG Passkey removal.
- `test/operations/identity_credential_removal_committer_test.rb`: converted to
  `use_transactional_tests = false` with explicit committed-record teardown.
- `test/operations/passkey_removal_authorization_test.rb`: new nontransactional class holding the
  two removal authorization cases moved out of `passkey_mutation_authorization_test.rb`.
- `test/integration/sign/app/credential_removal_constraints_test.rb`: converted to nontransactional
  with `purge_committed_client!` teardown and `self.fixture_table_names = []`.
- `test/operations/auth_method_guard_concurrency_test.rb`: added `self.fixture_table_names = []`,
  explicit reference fixtures, fixed-ID purge before setup and full dependent-row cleanup, removing
  its second-run order dependence.

## Verification

Command prefix:
`set -a && eval "$(grep '^PREFERENCE_COM_JWT' .env.container.devcontainer)" && set +a`.

| Command                                         | Result                                                 |
| ----------------------------------------------- | ------------------------------------------------------ |
| `bin/rails test` on the 8 affected files, run 1 | 62 runs, 557 assertions, 0 failures, 0 errors, 0 skips |
| same, run 2                                     | 62 runs, 557 assertions, 0 failures, 0 errors, 0 skips |
| combined with the XDB-18 group (90 runs)        | 90 runs, 816 assertions, 0 failures, 0 errors, 0 skips |
| `bin/rubocop` on the 10 changed files           | 10 files inspected, no offenses detected               |

Affected files: `test/operations/identity_credential_removal_committer_test.rb`,
`test/concurrency/identity_credential_removal_commit_order_test.rb`,
`test/operations/passkey_removal_authorization_test.rb`,
`test/operations/passkey_mutation_authorization_test.rb`,
`test/integration/sign/app/credential_removal_constraints_test.rb`,
`test/operations/passkey_mutation_concurrency_test.rb`,
`test/models/auth_ceremony_revocation_concurrency_test.rb`,
`test/operations/auth_method_guard_concurrency_test.rb`.

## Not established

- The full Minitest suite was not rerun; Phase 2 was stopped by the owner.
- No HTTP refusal status change was made or verified.
- Only the writing-connection Ticket transaction is detected; a caller transaction on a different
  connection or role is outside this guard.
