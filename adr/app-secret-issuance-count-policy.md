# app Secret issuance count policy

## Status

Accepted target contract, recorded 2026-10-03 (UTC). The count value and writer
query are implemented; complete allocation, delivery and registration integration
remain unfinished. This ADR does not claim that those journeys passed.

## Decision

Apply one app-only policy to sign-up and signed-in Passkey registration. When a
registration operation reserves capacity, use the locked Client's writer-time
active Secret count A: 0–18 adds two, 19 adds one with an upper-limit notice, and
20 adds none with a normal omission notice. Manual addition allocates one when
there is room. This replaces app's shared recovery top-up behavior; com's existing
recovery policy and org Emergency behavior remain independent.

Two is an issuance quantity, not a minimum balance. A=1 adds two, producing three
after confirmation. Ordinary consumption from two to one to zero does not trigger
warnings, replenishment, forced screens or login restrictions. Existing protection
of the last usable authentication method remains a separate contract.

For Client C and one Zenith writer timestamp T:

```text
A = COUNT credentials WHERE client_id = C.id
    AND confirmed_at IS NOT NULL
    AND claimed_at IS NULL AND claim_operation_id IS NULL
    AND revoked_at IS NULL AND discard_at > T

R = SUM issuance.planned_count WHERE client_id = C.id
    AND planned_count > 0
    AND confirmed_at IS NULL AND canceled_at IS NULL
    AND expires_at > T
```

Maintain A <= 20 and A + R <= 20. Account suspension, registration state and
session availability do not release credential capacity. Pending candidates do
not count in A. Expired reservations cease to count at equality with their
deadline even if cleanup jobs are stopped; subsequent confirmation must refuse
them. Confirmation moves the complete fixed candidate set from R to A atomically.

Capacity mutations serialize under the Zenith Client lock and share one row-lock
order. At most one live pending issuance belongs to a Client. A different live
operation conflicts even if numerical room remains; A=18/R=2 is a pending
operation, not twenty active Secrets. Ordinary authorized retries return the
existing result. They do not allocate again or disclose another session's values.

Fix the candidate set and quantity at reservation time. Later capacity changes
do not silently increase or shrink that set. A zero-count issuance records a
terminal omission without expiry, candidates, reservation or plaintext payload;
retrying the registration cannot turn that omission into a later batch.

## Consequences and rejected alternatives

The shared ten-item recovery top-up constant cannot implement this contract.
Neither replenishing to a total of two nor maintaining a minimum of two meets
the agreed behavior. Automatic revocation of older Secrets to create room is
also excluded. These alternatives change user intent or other surfaces.

Reservation is short-lived but belongs to Zenith because Client and credential
capacity must commit in one database transaction. Ticket remains authoritative
for its own authentication workflow; it is not a cache and does not participate
in a distributed capacity transaction. Saved Secret validity, reservation expiry,
Step-Up freshness and physical retention are separate clocks.

## Verification boundary

The public ClientSecretIssuanceCountValue and ClientSecretCapacityQuery tests
cover counts, reservation conflict and expiry predicates. Those results do not
prove allocation locking or either Passkey registration journey. Completion also
requires real multi-connection issuance/confirmation/claim races, both registration
paths across A=0..20, atomic confirmation, zero-generation omission and browser
notification tests. See the [integration acceptance catalog](../plans/analysis/base-secret-core-acceptance.md)
and [persistence proposal](../plans/analysis/app-secret-persistence-shape-proposal.md).
