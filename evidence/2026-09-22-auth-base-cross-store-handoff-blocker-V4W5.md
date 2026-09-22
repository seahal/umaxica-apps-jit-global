# Auth/Base handoff cross-store blocker

- Date: 2026-09-22
- Repository HEAD: `277673d13547d722fc88f830711eee69b923a7e8`
- Branch: `feature`
- Worktree: already dirty before this record; no application, test, migration, or configuration
  files were changed for this review.
- Scope: read-only adversarial review of the remaining Auth/Base issuance boundary (`CF-010`).

## Confirmed state transitions

`BaseAuthAdmissionCoordinator.register_result_and_issue!` first commits the OIDC authorization
transaction transition through `OidcAuthorizationTransactionCoordinator.register_result!` and then
issues the opaque result in Valkey (`app/services/base_auth_admission_coordinator.rb:150-162`).
The Auth controller completes the Auth ceremony only after both operations return
(`app/controllers/concerns/auth_oidc_result_handoff.rb:32-41`).

The result endpoint now validates the stored authorization request before consuming the Valkey
result (`app/controllers/concerns/oidc_authorization_result_post.rb:13-30`). That local
validation-order defect was fixed and is covered separately by
`evidence/2026-09-22-result-validation-before-consume-S1T2.md`; it is not part of the remaining
CF-010 blocker. After the result is consumed, the app resume path creates the Base Browser Session
through `log_in`, consumes the authorization transaction, and only then issues the authorization
code (`app/controllers/base/app/oauth/authorizations_controller.rb:115-158`). The same structure
is present in the com and org controllers.

## Failure scenarios

1. If the PostgreSQL authentication transition commits and Valkey result issuance fails, the
   transaction is `authenticated` but no result code reaches Auth. A retry attempts the
   pending-only transition again and is rejected. The Auth ceremony is not completed, so the flow
   is stranded without a safe retry or explicit recovery protocol.
2. If the Base result is consumed and `log_in` succeeds, a later transaction-consume or
   authorization-code issuance failure can leave a Browser Session while no authorization code is
   returned. Retrying cannot reuse the one-shot result. Conversely, moving the consume earlier or
   adding an unbounded retry would risk replay or duplicate session issuance.
3. A Valkey consume, PostgreSQL commit, cookie write, and code response are not one distributed
   transaction. Treating them as one would conceal partial success rather than make it atomic.

These are availability and state-reconciliation hazards at the authentication authority boundary,
not evidence that the current implementation should be reordered opportunistically. Reordering
would choose a new failure contract without deciding whether the system uses an idempotent durable
result record, a compensating terminal state, a recoverable resume operation, or another approved
protocol.

The deterministic local loss case has since been narrowed: the Base result endpoint refuses an
expired, consumed, or unauthenticated authorization transaction before consuming its Valkey result,
using the transaction writer database clock for expiry. The public regression and static
verification are recorded in
`evidence/2026-09-22-result-readiness-before-consume-T3U4.md`. This does not protect the race after
that pre-check or make the Valkey, PostgreSQL, Browser Session, authorization-code, and HTTP
response boundaries distributed-atomic.

## Adjudication

- Severity: **BLOCKER** for the complete Base-only issuance acceptance gate.
- Confidence: **Confirmed by source inspection**; failure injection and independent-store runtime
  tests remain unexecuted in this environment.
- Affected contract: Auth is ceremony-only; Base owns Browser Session, RP Session, and
  authorization-code authority; result/admission values are one-shot and fail closed.
- Required decision before implementation: define the permitted partial-success states and the
  recovery/idempotency protocol for Valkey result issuance, Browser Session creation, transaction
  consumption, and authorization-code issuance. The decision must include failure-injection tests
  for each boundary and must not introduce a second session authority or a Valkey revocation
  authority.

No production or test data, external service, AWS/Cloudflare resource, or GitHub resource was
accessed or changed. No code change is claimed by this record. `CF-010` remains open; the separate
Retention blocker remains closed, and notification delivery/receipt/retry/permanent-failure is
unaffected by this finding.
