# Identity stop does not enqueue logout notification for separated RPs

Status: Deferred; recorded at the user's request on 2026-10-22. No implementation change is
authorized by this entry. Stored in `docs/backlog/` at the user's explicit request.

## Problem

Applying an identity stop revokes OP authority but does not create the logout Outbox events needed
to close sessions in separated RP stores. An affected RP can continue accepting an already-issued
Access JWT until expiry because its local session and OP-session binding remain unrevoked.

`OpIdentityEventInvalidator.call` invokes `AuthenticationLogoutCurrentSession` without the
`within_commit` callback that invokes `OpLogoutCommitter` in the RP-initiated logout path. The
root and OP Grant are revoked, but no logout participant or delivery Outbox is created through
that path. Retrying delivery cannot recover a notification that was never recorded.

The accepted separated-RP contract permits residual acceptance until notification or JWT expiry
(currently 300 seconds plus 30 seconds of leeway). The issue here is the missing durable
notification, not the existence of that accepted bounded window. Shared-runtime authentication
that reads the revoked parent is a different path.

## Reproduction observed

1. Create an active Client root, an OP Grant for `rp_core_app`, and a matching local RP enrollment.
2. Present a correctly signed, client-bound Access JWT and the matching local-session identifier
   to `RpRequestAuthenticator`. Authentication succeeds.
3. Record an identity stop with `IdentityAuthenticationStopRecorder`, then apply it through
   `OpIdentityEventInvalidator.call`.
4. Confirm that the root and OP Grant are revoked and that `OpAppOutboxEvent.count` has not changed.
5. Confirm that the RP local session remains active and the same JWT/session pair still
   authenticates through `RpRequestAuthenticator`.

This was a local service-level reproduction using test signing material and a local JWKS fetcher.
It did not exercise real HTTP notification delivery or prove behavior in every realm or runtime.

## Follow-up when selected

- Ensure identity-stop revocation records the required logout participants and delivery Outbox
  atomically with the OP authority revocation, respecting actor/OP/RP database ownership.
- Review other revocation callers, including credential transitions and administrative session
  revocation, for the same omission; those callers need their own coverage.
- Add tests for durable notification creation, rollback, idempotent stop-event redelivery and
  delayed events that preserve post-recovery authority.
- Verify that applying the notification closes the matching RP binding and sessions, refuses late
  callbacks for that binding, and preserves unrelated or newer sessions.
- Preserve the accepted asynchronous delivery and JWT-expiry bound; notification acknowledgement
  must not become a prerequisite for the OP revocation commit.

## References and verification context

- [Separated-RP logout contract](../../adr/first-party-sign-out-op-commit-and-backchannel-logout-for-separated-rp-stores.md)
- [Identity stop invalidator](../../app/operations/op_identity_event_invalidator.rb)
- [Session logout primitive](../../app/controllers/concerns/authentication_logout_current_session.rb)
- [RP-initiated logout orchestration](../../app/controllers/concerns/oidc_rp_logout_authority.rb)
- [OP logout commit owner](../../app/operations/op_logout_committer.rb)
- [RP request authentication](../../app/services/rp_request_authenticator.rb)
- [RP logout receiver mutation](../../app/operations/rp_cell_session_revoker.rb)

Observed on 2026-10-22 against commit
`febec3225cc9a0cfa53b9cbe817d20d366aba5a2`, with pre-existing uncommitted changes in the worktree.
A temporary test outside the repository exercised the public service interfaces and test database.
Both temporary audit scenarios passed their assertions of the problematic behavior: 2 tests,
14 assertions, no failures, errors or skips. The temporary test is not a durable regression test.
