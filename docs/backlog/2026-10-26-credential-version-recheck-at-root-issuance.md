# Recheck the verified credential before root issuance

Status: deferred from WU-44 by the owner on 2026-10-26. This is not a sign-out defect and does not
gate the sign-out suite.

## Problem

A sign-in can verify a credential, wait before acquiring the actor lock, and then acquire that lock
after `CredentialSecurityTransition` or `IdentityCredentialRemovalCommitter` has committed a change
to that credential. The transition revokes other roots under the actor lock, but the in-flight sign-in
can still create a new Root using its earlier verification result. This can happen when a password
or secret changes, or a passkey is removed, while the sign-in is waiting.

The current root-issuance recheck validates actor eligibility and records the current authentication
epoch under the actor lock. Those checks do not establish that the particular credential used by the
sign-in is still the same credential that was verified.

## Why deferred

Closing the gap requires durable per-method credential-version evidence to survive from credential
verification to final root issuance, plus a schema change. Sign-in and root-issuance code are frozen
for this WU-44 acceptance slice. The remaining case is tracked as A44-9 in `three.md` and does not
change the accepted point-in-time behavior of plain revoke-others.

## Existing controls

- `CredentialSecurityTransition` and `IdentityCredentialRemovalCommitter` acquire the actor lock
  before changing a credential and revoking other roots.
- `AuthenticationBase#commit_login_session_under_actor_lock` reloads the actor and rechecks
  root-issuance eligibility under that lock (D-163).
- New roots record the actor's authentication epoch; authentication boundaries require epoch
  equality and read the actor from the writer (D-165).
- Credential changes revoke other roots while holding the actor lock. This does not invalidate an
  in-flight sign-in that verified the old credential before the change and acquires the lock after
  the transition commits.

## Proposed approach

The 2026-10-23 WU-44 evidence proposed recording a version or immutable fact for the specific
credential method used by the sign-in, then comparing it under the actor lock immediately before
Root creation. The evidence must identify the exact verified credential and method, and credential
mutation must advance or replace the corresponding fact in the same transaction as the change.
Issuance refuses when the fact no longer matches. The check must cover password/secret change and
passkey removal without treating unrelated credential changes as a match.

No migration or implementation is selected by this backlog entry. Before implementation, resolve
the decisions below and add a separate acceptance test with two connections: verify the old
credential, commit its change while login waits, then assert that no Root from the old verification
survives.

## Owner decisions needed before implementation

- Should credential versions live on each credential row, on the actor, or in a separate version
  record?
- Which credential changes invalidate a pending verification for each method, including replacing
  a password/secret, removing a passkey, rotating a credential, and changing a method's enabled
  status?
- What immutable credential reference should a sign-in flow retain so the final comparison cannot
  accidentally match a different credential of the same method?
- Which sign-in methods must carry this evidence, and what is the refusal behavior when historical
  flows lack it?
- What production migration and rollout plan preserves existing sign-in flows while the new fact is
  introduced?

## Acceptance

`three.md` A44-9: when an old credential is verified and its change commits before the login acquires
the actor lock, the login is refused under that lock or any Root it creates is revoked by the
transition. No surviving Root may result from the old credential verification. Verify the current
Root and Access JWT boundaries as well as the credential-specific decision.

This item concerns root issuance after stale credential verification. It is not a sign-out defect,
does not change D-164 single-root or grant revocation semantics, and does not gate acceptance of the
sign-out suite.

## References

- `evidence/2026-10-23-wu44-root-issuance-epoch-E4R4.md`
- `adr/root-login-establishment-boundary.md`
- `three.md` A44-9
