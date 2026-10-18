# CF-010 cross-store handoff shape review

- Date: 2026-09-22 UTC
- Repository HEAD: `277673d13547d722fc88f830711eee69b923a7e8`
- Worktree: pre-existing modified and untracked files were present; no unrelated files were reset or removed.
- Scope: read-only review of the Auth-to-Base OIDC result handoff and the minimum persistent shape needed before implementation.
- No application code, migration, schema, or external service was changed by this review.

## Current evidence

The three surface-local OIDC transaction models are `ClientOidcAuthorizationTransaction`,
`VisitorOidcAuthorizationTransaction`, and `OperatorOidcAuthorizationTransaction`. They live in
the app, com, and org ticket databases respectively. Their current state machine is
`pending -> authenticated -> consumed`; the tables have no durable Auth-result digest or
post-consumption/finalization marker.

`BaseAuthAdmissionCoordinator.register_result_and_issue!` first commits the PostgreSQL
authentication transition and then issues the opaque Valkey result. If Valkey issuance fails,
the transaction is already authenticated and a retry is rejected by the pending-only transition.

The Base result POST currently consumes the Valkey result before `resume_authorization!` creates
the Browser Session, consumes the PostgreSQL OIDC transaction, and issues the Valkey authorization
code. These are separate resource boundaries. A failure after result consumption can therefore
leave a consumed result with no Browser Session, a Browser Session with no authorization code, or
an authorization transaction that is consumed before code issuance succeeds.

The current code and transaction fields are:

- Valkey stores only the opaque result payload/digest and a short-lived consumed tombstone; the
  raw result code is not persisted.
- The OIDC transaction stores actor and authentication evidence, but no result digest/state or
  finalization reference.
- Base Browser Session rows and RP authorization-code records are separate from the Auth result
  record, even where the Browser Session and OIDC transaction share a surface ticket database.

## Required decision gate

The implementation must not add migration/model fields until the exact persistent shape and
recovery semantics are approved. The existing plan deliberately requires this confirmation and
prohibits a generic/polymorphic flow table.

The minimum viable proposal for review is:

1. Extend each existing surface-local OIDC authorization transaction, rather than creating a
   generic table or putting authority into `AuthCeremonySession`.
2. Persist only digests/references and finite timestamps, never raw Auth result or authorization
   codes. The transaction would need an explicit result-delivery state (or an equivalent
   derived state), a result digest/reference, and a result expiry/consumption marker.
3. Persist a Base-finalization state sufficient to make Browser Session creation, transaction
   consumption, and authorization-code issuance retryable without replacing actor/authentication
   metadata or creating a second Browser Session. The exact fields for the Base Session reference
   and authorization-code idempotency/recovery must be chosen together; adding only a result
   digest does not solve the finalization boundary.
4. Keep Auth ceremony sessions ceremony-local, keep Valkey as short-lived transport, and keep
   Base as the only Browser Session/RP Session/authorization-code authority.
5. Define failure behavior for each boundary: DB commit failure, Valkey result issue/consume
   failure, Browser Session creation failure, authorization-code issue failure, response loss, and
   concurrent retry. No distributed ACID claim may be made.

## Verification status

- Source inspection: complete for the current coordinator, result POST, three Base resume
  controllers, transaction concern, Auth ceremony handoff, Browser Session creation path, and
  authorization-code issuer.
- Runtime Rails verification: not completed in the current shell. The required preflight stopped
  before Rails boot because `primary` and `valkey-kvs` did not resolve; no localhost fallback or
  configuration change was attempted.
- External services: not contacted.

## Disposition

CF-010 remains open and is a shape/partial-success design gate, not an implementation-complete
slice. Safe local guards already landed in this worktree do not close the cross-store protocol.
