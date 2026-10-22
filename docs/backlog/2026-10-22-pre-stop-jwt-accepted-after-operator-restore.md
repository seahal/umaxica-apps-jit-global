# Pre-stop JWT accepted after operator restore while invalidation is pending

Status: Deferred; recorded at the user's request on 2026-10-22. No implementation change is
authorized by this entry. Stored in `docs/backlog/` at the user's explicit request.

## Problem

An operator's pre-suspension Access JWT can authenticate again after restore when OP-side
invalidation of the suspension is still pending. Restoring the account must not restore authority
issued before the stop.

`OrgOperatorLifecycleExecute` advances the actor's `authentication_epoch` and records an identity
stop event during suspension. `OpIdentityEventInvalidator.deliver` queues a retry if its OP operation
fails. Restore clears the actor's deactivation fields without waiting for that invalidation.

`OidcAccessTokenAuthenticator` checks the root's active status and the actor's lifecycle, but does
not compare the root's authentication epoch with the actor's current epoch. Consequently, the old
JWT is accepted after restore even though `AuthenticationEpochValue.root_current?` returns false.

## Reproduction observed

1. Create an active operator root and RP Grant, and issue an Access JWT. Authentication succeeds.
2. Suspend the operator through an approved lifecycle request. Inject
   `ActiveRecord::ConnectionNotEstablished` at `OpIdentityEventInvalidator.call` so the real delivery
   handler queues the invalidation. Authentication is refused while the operator is suspended.
3. Restore the operator through an approved lifecycle request before the queued event is applied.
4. Confirm the root's epoch is older than the actor's epoch. The original JWT authenticates again.

The observed window ends when the JWT expires or the queued invalidation revokes the root. This
was a local service-level reproduction; production behavior and browser flows were not exercised.

## Follow-up when selected

- Enforce the monotonic authentication epoch at the appropriate authoritative request boundary,
  using current actor state and preserving the separate RP trust boundaries.
- Review other root-authentication paths for the same missing comparison; this reproduction
  establishes the operator OIDC path only.
- Add regression coverage for pending invalidation, suspend/restore, and successful eventual
  delivery. Cover older, equal and newer root epochs, and the existing legacy missing-epoch rule.
- Ensure newly established post-recovery roots remain usable and delayed stop events cannot
  revoke them.

## References and verification context

- [Operator lifecycle execution](../../app/services/org_operator_lifecycle_execute.rb)
- [Identity stop delivery](../../app/operations/op_identity_event_invalidator.rb)
- [Access token authentication](../../app/services/oidc_access_token_authenticator.rb)
- [Authentication epoch rules](../../app/values/authentication_epoch_value.rb)
- [Existing identity invalidation tests](../../test/operations/op_identity_event_invalidator_test.rb)

Observed on 2026-10-22 against commit
`febec3225cc9a0cfa53b9cbe817d20d366aba5a2`, with pre-existing uncommitted changes, including changes
to operator lifecycle execution. A temporary test outside the repository exercised the public
service interfaces and test database, with fault injection at the OP invalidation dependency. Both
temporary audit scenarios passed their assertions of the problematic behavior: 2 tests,
14 assertions, no failures, errors or skips. The temporary test is not a durable regression test.
