# Signup Source authority and failure retention

Commit: `48ff7040de2b50a8a08ed660fa71878a029ba577`; uncommitted implementation changes affected all checks.

Email now has a named `finalize_sign_up_binding!` writer on its independent binding implementation.
It validates the original realm, live checkpoint Parent, browser nonce, cleared OTP requirement,
owner/candidate/destination and historically consumed typed ceremony under locks. It promotes the
pending signup Email status with the binding timestamp. APP owner promotion is a separate named
Client operation. Neither operation issues a Root, resets failures or requires renewed sixty-second
receipt freshness. Existing Source audit/provenance orchestration remains at the controller boundary.

The Email model contract first reproduced four failures and two errors (seed 11035) for the missing
writer. An incorrect Rails lock-block argument caused two implementation errors (seed 60918);
the local Rails `locking/pessimistic.rb` documents that the block receives the database transaction,
not the locked record. Explicitly retaining the ceremony fixed that regression.

All 26 failure-retention cases now use channel-owned issuance, cancellation, expired ceremonies and
actual successful consumption instead of identifier `store_otp` or unconditional `clear_otp` reset.
The unchanged boundary partitions include 0, 1, MAX-1, MAX, MAX+1 and finite lockout expiry in all
six models. The ten Email binding cases include late checkpoint completion, foreign browser,
uncleared requirement, unconsumed proof and expired Parent.

`bin/rails test test/models/otp_failure_retention_test.rb test/models/email_signup_binding_authority_test.rb`
passed: 36 tests, 437 assertions, zero failures/errors/skips, seed 39908.
Scoped RuboCop on these two tests, Client, EmailContactBinding and shared signup orchestration
passed: five files, no offenses.

The Telephone implementation worker separately reported the four-file signup-finalizer command:

```text
bin/rails test test/operations/sign_app_up_telephone_registration_finalizer_test.rb test/operations/sign_com_up_telephone_registration_finalizer_test.rb test/operations/telephone_signup_source_audit_test.rb test/integration/telephone_signup_source_proof_retry_test.rb
```

RED: 25/510, two failures and three errors for missing original flow/browser arguments, seed 3024.
GREEN: 25/593, zero failures/errors/skips, seed 11464; nine scoped Ruby files passed lint and whitespace
checks. Both finalizers now use named Telephone Source writers and preserve APP passkey requirements,
original audit operation, Source rollback and idempotent retries. Identifier `clear_otp` is removed.

The independent two-file signup service-test migration passed 26/449, seed 30718, after correcting
two test-fixture errors reproduced at seed 32092.

The actual Email HTTP Source-fault matrix remains under migration: seed 61225 reproduced missing
test-local canonical cleanup reference rows in all 24 journeys and the then-missing Client Email
owner writer in one additional model case. The writer is now covered above; that historical HTTP
run is not green evidence. No full-suite or final-gate completion is claimed.
