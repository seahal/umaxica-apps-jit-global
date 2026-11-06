# WU-A4 XDB-07 credential removal dependency failures

HEAD: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`. The worktree was extensively modified and
uncommitted; no staged change or commit was created.

`IdentityCredentialRemovalCommitter` now wraps `ActiveRecord::StatementInvalid` and
`ActiveRecord::ConnectionNotEstablished` as `DependencyFailure`. The Base APP Email, Telephone,
Passkey and TOTP, and Base ORG Passkey destroy actions return HTTP 503 for `DependencyFailure` and
the existing `TransactionConflict`. The Email preference-update action also groups its existing
dependency failure with transaction conflict under the same 503 response.

Verification performed:

- `bin/rails test test/concurrency/identity_credential_removal_commit_order_test.rb test/operations/identity_credential_removal_committer_test.rb`:
  24 runs, 208 assertions, 0 failures, 0 errors, 0 skips.
- `bin/rails test test/integration/sign/app/credential_removal_constraints_test.rb:54`: 1 run, 4
  assertions, 0 failures, 0 errors, 0 skips. This confirms the nontransactional APP Email HTTP
  removal success path.
- Scoped RuboCop inspected eight changed implementation/test files with no offenses. Ruby syntax
  checks passed for those files; `git diff --check` passed.

The controller test `test/controllers/base/app/identity/emails_controller_test.rb` had previously
reached the action and observed HTTP 503 where it expected 303, because its default transactional
fixture cannot provide the independent Ticket commit required by the committer. Its expectation now
records the intended 503 refusal and unchanged Email state. A recheck did not reach the test body:
fixture setup failed while toggling foreign keys because the local test database contains an orphan
`client_authority_locks` row for Client id `980190963`. No database rows were deleted or changed in
response. An injected real HTTP storage outage was not exercised, and the full suite was not run.
