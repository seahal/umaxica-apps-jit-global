# WU-A4 XDB-08/09 APP Contact Ticket-first follow-up

APP Email and Telephone credential-registration finalizers now consume the Ticket result and Step-Up
evidence before committing the Zenith contact binding and audit. Root and OTP proof are rechecked
immediately before Ticket consumption. A Ticket storage failure leaves the Source unchanged and is
surfaced as a dependency failure; a Source failure after Ticket consumption leaves the candidate
unbound and refuses a retry without committed Source provenance. Exact retry requires the same
committed candidate and audit facts.

## Verification

- `bin/rails test test/operations/contact_registration_otp_finalizer_test.rb test/operations/telephone_credential_registration_otp_finalizer_test.rb test/integration/contact_registration_otp_bootstrap_receipt_recovery_test.rb`:
  44 runs, 721 assertions, no failures, errors or skips.
- The HTTP bootstrap file also passed alone (2 runs, 136 assertions). The two rebound-device cases
  passed alone (2 runs, 22 assertions); both are included in the 44-run result.
- Scoped RuboCop inspected nine implementation/test files with no offenses. `git diff --check`
  passed for the changed slice.
- Earlier failed nontransactional test cleanup had left four known synthetic APP actors in local
  test databases. Their Client, identity, persona, enterprise and Avatar graphs were deleted by
  exact IDs. A subsequent read confirmed zero rows for those IDs. The HTTP test teardown now removes
  only the graph created by its own actors.

## Remaining

- ORG Contact finalization still lacks its own approved Zenith audit shape and is not changed here.
- The rest of WU-A4 and the full test suite remain open. No production/Neon operation or migration
  was performed.

HEAD: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`. The worktree was dirty; 698 staged, modified or
untracked entries were present before this evidence file was added. No commit was created.
