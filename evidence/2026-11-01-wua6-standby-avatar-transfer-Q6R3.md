# WU-A6 ORG Standby Avatar transfer request

This slice checks the high-risk ORG Avatar transfer-request boundary under a Standby session.

## Observed result

The test seeds an ORG Standby session with matching fresh Step-Up evidence, then sends the transfer
request through the Base controller and Avatar authority. It receives HTTP 403 with the existing
JSON `auth.step_up.emergency_unavailable` message. No `AvatarTransferReservation` or additional
Operator Step-Up Ceremony is created; the Step-Up timestamp and Standby context remain unchanged.

The focused case passed: 1 run, 8 assertions, 0 failures, 0 errors, 0 skips. The full controller
file passed: 16 runs, 114 assertions, 0 failures, 0 errors, 0 skips. Scoped RuboCop, Ruby syntax
checking, and `git diff --check` passed.

## Test setup findings and limits

The first run failed before the test body while Rails loaded unrelated global fixtures and hit a
missing Operator foreign key in `bureau_ownerships`. The test class creates its own actor and
ownership graph, so it now disables those unrelated fixture files. The next run reached the public
request and showed that the expected error is the translated message inside JSON, not the literal
`step_up_required`; the assertion now checks the actual public response shape.

This covers only the transfer request action, using seeded Standby context. Transfer accept/cancel,
real Standby Root issuance, and the full AC-41 operation matrix remain unverified. The full suite
was not run in this slice. Verification used configured local test databases only; no production or
Neon database was accessed. No production behavior or schema was changed.

The work was performed against full HEAD `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`. Before this
evidence file was added, `git status --short` reported 572 entries. Existing uncommitted work was
preserved; no commit was created.
