# WU-A4 XDB-08 APP Email Ticket-first finalization

Implemented the active APP Email registration finalizer's §6.1 ordering. It locks the Zenith owner
and candidate, rechecks Root, policy and OTP evidence immediately before Ticket consumption, commits
the Step-Up/bootstrap and registration receipts in Ticket, then commits the contact binding and
audit in Zenith. Source finalization relies on the consumed Ticket timestamp as the authorization
decision; a consumed Ticket without its committed Source provenance remains terminal. Exact retries
return the committed result only when the same contact and finalized audit provenance are present.
Ticket/Source storage errors map to HTTP 503.

The Email contact model now validates registration finalization against the registration OTP
receipt, which remains verifiable after Ticket consumption. Bootstrap tests distinguish a Ticket
failure (Ticket transaction rolls back; Source is untouched and retry can complete) from a Source
failure (Ticket remains consumed; Source stays untouched and retry is refused).

## Verification

- APP Email finalizer matrix: 18 runs, 266 assertions, 0 failures/errors/skips.
- Bootstrap finalizer and HTTP receipt tests: 21 runs, 613 assertions, 0 failures/errors/skips. The
  HTTP cases injected failures in each Ticket receipt write, received 503, and then completed the
  same still-pending Ticket through the original browser and OTP proof.
- Scoped RuboCop: 6 files inspected, no offenses. `git diff --check` passed.
- An earlier fixture-backed attempt could not load the existing test fixtures because of orphan
  `client_authority_locks.client_id=980190963`. The focused tests now omit unrelated global fixtures
  and create their own actors; no database cleanup or rebuild was performed.

## Not established

- APP Telephone and ORG finalizers are not changed by this slice.
- Source-write outage HTTP behavior outside the operation-level terminal-refusal test is unverified.
- Full `bin/rails test` was not run; the overall WU-A4 matrix and WU-A acceptance remain open.
- No migration or production/Neon action was performed.

HEAD: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`. The worktree had 693 staged, modified, or
untracked entries, including changes unrelated to this slice. No commit was created.
