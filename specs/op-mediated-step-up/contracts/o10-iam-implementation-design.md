# O-10 IAM implementation design

Status: working implementation design under accepted revision 13; not evidence of implementation.
This design covers only Base ORG IAM capability grant and revoke owner writes. Revision 13 remains
authoritative. Unit 7 remains blocked on the complete reverse-lock inventory and its fixes.

## Durable result and request identity

Add an append-only `org_iam_operation_outcomes` table in the org Zenith database. Each committed row
represents one completed mutation, never a pending decision. Use a non-null unique UUID
`operation_id`; an operation kind constrained to `grant` or `revoke`; actor and subject public IDs;
a canonical, versioned request digest; the affected capability grant public ID; and non-null result
facts sufficient to reconstruct the existing response, including the expiration for a grant. Include
database timestamps and explicit non-null fields; use a separate result shape per kind or a checked
status/reference design, not NULL as an operation state. The digest covers every behavior-affecting
input, including action, actor, subject, capability or grant reference, duration, reason and ticket,
using a stable canonical encoding. The server computes it; the client cannot supply the digest.
Restrict deletion and update of outcomes as authoritative audit history.

Insert the outcome in the **same** Zenith transaction as the grant or revocation. The unique
operation ID serializes retries; a uniqueness race rolls back the losing mutation and reads the
winner in a new transaction. An existing outcome is replayable only after exact kind, actor, subject
and digest equality; a mismatch is a conflict. A matching committed outcome returns the same grant
reference and expiration, without re-executing the mutation. Matching an intent alone or a
failed/manual-recovery Chronicle record is not evidence of principal commit. No row on a reliable
fresh connection after a known rollback means the mutation did not commit; an unavailable or
inconclusive outcome lookup remains indeterminate and is not retried as a new operation. Retention
must cover at least the administrative audit and replay windows; it must not delete the outcome
while Chronicle can refer to it.

## Transaction ownership and authorization

1. Authenticate the owner caller and access token, validate input, check the initial policy, compute
   the immutable request identity, and write or inspect the Chronicle intent **before** taking
   principal or OP locks. Preserve existing idempotency conflict and audit-intent behavior. A
   request with an already committed matching outcome can follow the existing authorized replay
   policy, but never performs another mutation.
2. Reject a pre-existing Zenith or OP transaction on the relevant writer connections: a nested
   savepoint cannot establish the required commit ordering. Begin an outer, read-only OP transaction
   without taking OP locks, then start and explicitly own the inner Zenith transaction and lock the
   acting Operator row first. Starting the OP transaction alone is not acquisition of an OP row
   lock. Recheck actor eligibility and acquire the necessary Zenith capability/grant locks in a
   documented deterministic order. The recheck must serialize against grant and revoke writers that
   can change the actor's required authority. For revocation preserve the continuity-holder
   invariant and its deterministic locking; audit every competing writer, including bootstrap,
   before activation. Recheck target eligibility and Action Policy authorization using fresh
   database state, not cached policy or association data.
3. Within the already open read-only OP transaction, lock the actor's OP device, its current root
   and the access-token's OP grant in device → root → grant order. Use the existing
   `StepUpEvidenceVerifier` only after confirming its locked checks cover the verified token event,
   subject, audience, context, freshness and the live chain. Re-evaluate time after every
   potentially blocking lock, with the owning database clock, immediately before the principal
   write. Reject expiration or changed authority; do not mutate the OP transaction and do not do
   network I/O while either lock set is held.
4. Perform the IAM mutation and insert the outcome on the Zenith connection. Commit Zenith **while
   the OP transaction and locks remain open**. Record a successful COMMIT acknowledgement before
   declaring success. Then end the read-only OP transaction. If ending that transaction fails after
   a confirmed Zenith commit, discard the OP connection, emit a fixed diagnostic and continue with
   the confirmed principal outcome; this failure cannot undo Zenith's commit.
5. With both lock sets released, write Chronicle's result. Report completion only when the required
   result is confirmed. If result delivery or invalidation fails, preserve the committed outcome and
   return the existing unconfirmed/manual-recovery response; never rerun the mutation.
   Reconciliation compares the exact intent identity with the durable outcome and writes the result
   idempotently, without interpreting the presence of an intent as proof of commit. Do not silently
   change the existing Chronicle API or claim atomicity across databases.

The correct nesting is
`OP.transaction { Zenith.transaction { actor.lock!; verify_and_lock_op!; mutate_and_record! } }`:
the OP transaction must take no OP row locks before the actor lock, and the Zenith block commits
before the outer OP transaction ends. The implementation must own both transactions and verify the
actual transaction depth so an outer Zenith transaction cannot defer the principal commit. It must
not let an ensure block commit a failed or unknown transaction. On exceptions before COMMIT, roll
back Zenith and then release OP. A lost COMMIT acknowledgement requires discarding the uncertain
Zenith connection, releasing OP, and resolving the outcome through a **fresh** writer connection.
Only a confirmed matching outcome proves success. A failed lookup or ambiguous acknowledgement stays
indeterminate and must not write a failed Chronicle result that falsely states rollback. The exact
exception classification and connection disposal must be verified with failure injection before
enabling this path.

## Required verification and outstanding work

Exercise both grant and revoke through the authenticated owner API, including policy denial, changed
capability, wrong actor/subject/client/grant and step-up event, stale or revoked device/root/grant,
Standby, fresh success, and replay with identical and different input. On independent connections
force both winners of OP revocation versus principal commit and of actor-capability revocation
versus authorization; verify freshness expiry while waiting, principal rollback, a COMMIT that took
effect but lost its acknowledgement, an inconclusive fresh lookup, and OP transaction-release
failure after confirmed commit. Inject Chronicle intent, result and invalidation failures; confirm
no mutation without intent, no success report for unconfirmed audit, and reconciliation without
duplicate mutation. Test duplicate operation IDs concurrently and preserve last-capability-holder
protection.

The IAM owner endpoints are wired through `OrgIamOwnerMutation` and the audited principal-commit
path. They call `require_owner_step_up` to obtain evidence without an enclosing transaction; the
reusable `with_owner_step_up` wrapper opens an OP transaction and cannot wrap this commit primitive.
The focused owner API and principal-commit/race tests passed 9 runs / 101 assertions on 2026-11-04.
This does not complete the contract: full reverse-lock inventory, remaining recovery/fault cases and
review of all competing writers remain open. See the latest `zero.md` report and
`lock-order-inventory.md`.

## Owner endpoint integration notes

The current owner controller's `with_owner_step_up` opens an OP transaction before yielding and
cannot wrap the commit primitive: the primitive owns both transactions and refuses nesting. The
active IAM endpoints instead obtain evidence with `require_owner_step_up`, validate the request and
invoke the audited coordinator. Grant and revoke request digests are computed server-side by
`OrgIamRequestDigest`; they include behavior-affecting inputs without raw credentials. This
integration is active and has the focused verification above; the remaining work is the incomplete
acceptance and lock-graph coverage, not route connection.

Under the actor lock, evaluate a fresh `OperatorCapabilityGrantPolicy` against fresh records and the
current trusted authentication context, without reusing Action Policy's prior cached result. Lock
the acting operator's capability grants in ID order before the OP chain and re-evaluate the policy
after any wait. The subject's eligibility for a grant is also rechecked immediately before the
write. Revocation needs a distinct replay authorization: the normal `revoke?` policy rejects a grant
after it is revoked, so an exact committed replay cannot simply run the original `revoke?` check.
Recheck the current operator's read and revoke capabilities and context, then confirm the matching
operation outcome before returning its result; for a new mutation, recheck the target grant is
unrevoked under its lock and retain continuity-holder protection. A revoked grant without the
matching outcome never authorizes a replay. Do not call `with_owner_step_up` around this new
boundary.

Map evidence or current-policy failure to the existing forbidden response, changed request identity
to conflict, and unknown commit or unconfirmed Chronicle result to a localized
unavailable/unconfirmed response. A confirmed principal commit followed by OP transaction release
failure returns the confirmed result after discarding the failed OP connection and recording a fixed
diagnostic, subject to Chronicle result confirmation. `intent`, `failed` and
`manual_recovery_required` Chronicle records are not principal outcomes. A pre-existing intent with
no matching durable outcome must not start a second mutation. Only the creator of a new intent can
execute the mutation; replay checks require current authorization and the matching durable outcome
before reconciliation.

The first local race exercises a writer holding the OP device lock while an independent
`OpAuthorityStopCommitter.stop_root` waits, followed by refusal of the stopped proof; the
independent capability-revocation race checks the actor's capability row lock. These do not cover
every lock winner, ambiguous delivery, continuity capability or global reverse edge. The endpoint is
currently connected under the 15:00 owner instruction, but this partial coverage does not establish
full O-10 acceptance. Keep the incomplete verification visible and do not treat route presence as
proof that the revision 13 lock inventory and competing-writer requirements are complete.
