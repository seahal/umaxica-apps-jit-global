# WU-A2 APP Secret signup journey recheck

- HEAD: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`. The worktree already contained uncommitted
  changes; immediately before this evidence file was added, 503 tracked paths were modified, 237
  paths were untracked, and none were staged.
- The first isolated Telephone signup attempt returned HTTP 503 at OTP issuance while Rails' fixture
  transaction was active (1 run, 5 assertions). After moving these public journeys outside the
  enclosing fixture transaction, the file ran 24 tests / 1,484 assertions but had 21 teardown
  errors: deleting each synthetic Client was restricted by its `client_accounts` row.
- Teardown now removes the test-owned `ClientAccount` before its Client. A representative completed
  case passed (1 run, 63 assertions), then the complete file passed (24 runs, 1,484 assertions, 0
  failures, 0 errors, 0 skips) with
  `PARALLEL_WORKERS=1 RUBYOPT=-W0 bin/rails test test/integration/app_secret_signup_journey_test.rb`
  after loading `.env.container.devcontainer`.
- `ruby -c test/integration/app_secret_signup_journey_test.rb`,
  `bin/rubocop test/integration/app_secret_signup_journey_test.rb`, and `git diff --check` passed.
- Failed attempts left synthetic rows in the local test databases. A read-only check found 47 Client
  rows in IDs 980190964–980191014, with 43 ClientAccount, 26 ClientTelephone, 22
  ClientAuthorityLock, 22 ClientPasskey, 251 ClientSecretCredential and 232 ClientSecretIssuance
  rows. The corresponding OP Base time window contained 23 Admission Bindings, 46 Auth Ceremony
  Sessions, 23 OIDC authorization transactions and 1 Sign Up Flow. No manual database cleanup or
  rebuild was performed.
- The full test suite was not run. This recheck covers the APP Telephone signup journey in this
  file, not all WU-A2 acceptance.
