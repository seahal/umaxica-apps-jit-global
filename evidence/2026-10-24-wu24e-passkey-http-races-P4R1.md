# WU-24e real HTTP Passkey races and pause checkpoint

Revision: `ba570a0007b1d40eabe32990a34831317fd98a93`.
Observed 2026-10-24 with uncommitted implementation, tests and documentation, including preceding
H8P2/S2E1 changes. The owner requested stopping at a coherent checkpoint. No production connection,
deployment, external provider request or schema change was performed in this iteration.

## Defects reproduced and repaired

- A real WebAuthn registration request, blocked on its Flow after verification, held no principal
  lock. When cancellation won, the old controller continued saving and raised
  `ClientSecretPasskeyReservationIssuer::Denied` instead of returning the expected 409.
  Meaningful Red: **1 run, 16 assertions, 1 failure, 0 errors/skips**.
- Two separately verified HTTP saves waited on the same Flow using two distinct PostgreSQL backend
  PIDs. Without rechecking the pending registration after acquiring that lock, one request raised a
  Secret capacity reservation conflict instead of converging on the existing success.
  Meaningful Red: **1 run, 18 assertions, 1 failure, 0 errors/skips**.
- The controller now rechecks terminal/discarded state, expiry and the request gate after acquiring
  the Flow lock and before the principal writer. Expiry uses `SignUpTermination`; terminated work
  renders the existing 409 phase refusal. The shared registration concern respects the rendered
  refusal instead of falling through to success. An already pending Passkey produces the same
  success response as the endpoint's existing retry path, without another credential or allocation.

## Executed verification

The new tests use the WebAuthn gem's real-cryptography FakeClient, real admitted Auth SIDs and
encrypted Rails continuity cookies, actual OTP verification and public lifecycle transitions.
CSRF protection is enabled. PostgreSQL wait observations and principal `FOR UPDATE NOWAIT` reads
verify actual contention and Flow-before-principal order, rather than a scheduled-thread guess.

- Cancellation winning: 409, canceled/cleanup-completed Flow, logically retained pending actor
  and contact, no Passkey, Secret allocation or Root issuance.
- Deadline fence: after a real Flow-lock wait, one microsecond before the cutoff accepts the
  provisional registration; at and one microsecond after it refuse with 409 and perform expiry/
  cleanup. The owning OP clock is controlled through its public database-clock seam. The cutoff
  uses whole seconds so the signed URL and Flow deadlines coincide. The accepted control is then
  canceled through the public operation, removing its pending Passkey and retiring its allocation.
- Parallel saves: two verified requests return 201 but persist one pending credential and one
  allocation, with no Root. Subsequent termination completes cleanup.

Final related command:

```sh
bin/rails test test/concurrency/sign_up_passkey_termination_http_test.rb test/controllers/auth/app/up/checkpoint_passkeys_controller_test.rb test/concurrency/sign_up_secret_lock_order_test.rb test/concurrency/sign_up_cleanup_principal_lock_test.rb test/services/sign_up_artifact_cleanup_atomicity_test.rb test/controllers/auth/com/sign/up/check/telephone/checkpoint_flow_test.rb test/security/invariants/lifecycle_direct_state_write_invariant_test.rb
```

Result: **34 runs, 604 assertions, 0 failures, 0 errors, 0 skips**. Three changed/new Ruby files
passed RuboCop; scoped whitespace verification passed. This is not a full-suite result.

An intermediate fixture teardown used records with stale optimistic-lock values after requests
updated them; owned data from a setup-error path remained and a combined run produced fixture FK
errors. Teardown now reloads owned records and removes its own dependent test artifacts. A test-only
cleanup, guarded against active Flows, Roots and Secret credentials, removed exactly one owned actor,
one Passkey and one allocation (zero telephones). No shared data reset or test-helper modification
was used. The final related run above passed after that correction.

## Remaining work and stopping point

The actual HTTP save/termination and deadline portion of A35-2 is now verified. A35-2 remains
partial until the exact cleanup-job/replayed-termination portion is reconciled with A6C4; the
existing retirement/Flow contention and principal-lock tests alone do not substitute for that
scope audit. Remaining WU-24 acceptance and the global schema gate remain open.

The 44-unit objective is not complete. Resume from the delivery ledger: reconcile those gates,
execute AX26 and WU-34, then continue sign-up unification and the remaining units. Existing Social
callback/RP-cookie failures and the global schema discrepancies recorded by S2E1/H8P2 remain
unwaived. All test processes were terminal at the pause checkpoint.
