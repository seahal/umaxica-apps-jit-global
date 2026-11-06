# WU-A3 OIDC writer clock ownership

HEAD: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`. The worktree was already uncommitted; during
verification it had 514 changed tracked paths and 243 untracked paths, with no staged entries. The
new evidence file is an additional untracked path. No commit or migration was made in this slice.

OIDC parent state, result-delivery, and grant-redemption writers now read their owning transaction
database clock after locking the parent. Their public APIs no longer accept a caller-supplied
`now:`. Authentication event time remains event evidence. The coordinator and token-exchange call
sites no longer forward a foreign clock into those writers. The security contract documentation now
states this ownership rule.

Verification:

- `test/models/concerns/oidc_authorization_transactionable_test.rb` passed: 15 runs, 203 assertions,
  0 failures, 0 errors, 0 skips.
- The targeted OIDC coordinator tests did not reach assertions: 2 runs, 0 assertions, 2 fixture
  setup errors. PostgreSQL rejected a `client_accounts.user_id` fixture because the referenced
  `clients` row was absent (`user_id=980190964`). A read-only aggregate then found 43
  `client_accounts` rows, 73 `clients` rows, and no orphan account references. The test-setup root
  cause remains unestablished, so no test database rows were deleted or rebuilt.
- Ruby syntax checks passed for the four changed application files and the two changed test files.
  `git diff --check` passed.
- The full suite was not run. WU-A3 acceptance and the broader `two.md` work remain open.
