# O-10 Support session revocation: owner boundary

Status: implementation investigation; not active and not a replacement for accepted revision 13.
Scope is Base ORG Support's APP Client session-purge owner API. Existing IAM receipts must not be
treated as receipts for this different operation.

## Existing behavior

`Base::Org::Api::V0::Support::AccountsController#revoke` authenticates the ORG caller, checks
Support policy and opens `with_owner_step_up`, but its mutation block receives no Step-Up evidence.
`AccountSessionRevocation.purge!` enumerates Client roots, invokes a separate
`AuthenticationLogoutCurrentSession` for each, then writes `AccountAccessEvent` in Chronicle. An
exception can leave a subset of roots stopped and no event. The existing Chronicle administrative
intent lives in a further independent transaction. A root-stop result, a Chronicle intent or an
event alone is not a durable receipt for the complete requested operation.

## Candidate authority and commit boundary

The authenticated owner must bind a canonical operation ID and request digest to the acting
Operator, target Client, realm, fixed reason and ticket. The registered Base ORG client assertion
and verified access token are required; the browser may not select the actor, its root or its
evidence. A matching repeated ID requires current authorization and the same immutable request
digest; a different request is conflict. Write Chronicle intent before initiating the mutation. The
operator's current read and revoke capabilities, actor eligibility, Normal context, exact proof and
target are all rechecked under owner locks; Action Policy's earlier cached result is insufficient.

A candidate source commit uses a target-Client Zenith durable result and identity-stop intent,
written atomically with an epoch cutoff, while the acting Operator's ORG OP device/root/grant locks
remain held after taking the operator Zenith lock. The target Client lock is on a **different**
Zenith database: all cross-realm writers and their lock ordering must be inventoried and a
deterministic, deadlock-safe sequence established before activation. Opening the OP transaction
without taking locks may precede both principal locks, but no nested transaction may defer the
target Client commit until after OP locks are released. The existing all-session identity-stop event
and OP receiver may supply part of the delivery, but its accepted reasons and support-specific
AccountAccessEvent/audit semantics need explicit extension and tests. Do not pass the ORG IAM
outcome as an APP target receipt.

A target principal COMMIT with a lost acknowledgement is indeterminate. Discard the affected
connection, release the read-only ORG OP transaction and consult an operation-specific target
outcome on a fresh target writer. A matching outcome proves that exact target stop intent was
committed; no reliable answer means no success or new operation. After confirmed target commit,
idempotent APP OP delivery selects only authority older than the cutoff and uses the accepted stop
primitive and durable back-channel logout participants. Do not do HTTP while locks are held. Record
an authoritative, idempotent AccountAccessEvent and Chronicle result with explicit recovery if
either database is unavailable; a successful OP stop cannot be undone by audit failure, and an
intent or partially delivered stop must not be presented as completed.

The existing separated-RP sign-out ADR permits an already-held Access JWT to survive an OP stop
until local logout receipt or its bounded expiration. Any claim that the same bound begins at target
epoch commit additionally requires proof that every old-epoch issuance, refresh and redelivery path
locks the Client and checks the epoch. The full revision 13 inverse-lock inventory and fixes are
prerequisites for activation.

## Verification required before connection

Public owner API tests need authorized success; missing, stale, swapped, expired and revoked proof;
invalid client assertion; capability or target eligibility changes while waiting; same-ID replay and
input conflict; Chronicle intent failure; target principal rollback and lost commit acknowledgement;
APP OP partial failure, retries, stop/BCL participant delivery and AccountAccessEvent/result
failure. On independent connections force both winners of operator authority loss against target
principal commit and of target login/refresh against the epoch transition. Assert no new root is
incorrectly stopped, no old root can mint after the cutoff, and no operation is reported complete
without its required audit and durable delivery state. Preserve existing user-facing status,
access-event and retention contracts.
