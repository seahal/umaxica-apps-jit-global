# Authentication flow integrity acceptance

These criteria specialize browser-binding admission for the approved F contract. Preserve existing
AUTH-2/3 IDs and the general AUTH-1/4 and SESSION-1–4 requirements when their worktree checklists
are persisted by their owner; see the integrated index for that provenance. The tracked sources
below remain the authority for CSRF, surface separation and committed session issuance. Sources:
[root-login boundary](../../adr/root-login-establishment-boundary.md),
[lifecycle vocabulary](../../adr/idp-flow-lifecycle-vocabulary.md),
[lifecycle state machine](../../adr/idp-flow-state-machine-lifecycle.md), and the accepted strict
GET-refusal/unsafe-HALT amendment F02–F08, retained here. Older ADR descriptions of redirect
recovery or target-only HALTED do not override that amendment. No current implementation pass is
claimed. Follow [independent investigation](integrated-stack.md#independent-investigation).

## FLOW-1 — Scope and authority

- Basis: F01/F06, AUTH-1/4, SESSION-1–4. Scope: actual app/com/org sign-in/up families, Email,
  discoverable passkey, social Google/Apple, org Entra normal/emergency and applicable MFA,
  capacity, checkpoint, selector and Auth/Base/OIDC handoff. Unsupported combinations remain
  unsupported.
- Given a valid family entry, trace when principal and authoritative ceremony/flow exist, then
  proceed through normal steps. Auth provides ceremony evidence; Base retains final session/OIDC
  authority, actor/flow locking, expiry/phase/token checks, cooldown/capacity and committed-success
  semantics. Capacity children stay bound to SESSION_ISSUANCE_PENDING; they are not authentication
  evidence.
- No universal `/sign`-GET-created flow, alternate session issuer, RESTRICTED placeholder or weaker
  callback authority is introduced. Check current controllers/locators and public session issuance
  tests, including
  [root establishment](../../test/integration/root_login_establishment_flow_test.rb). Full
  family/surface matrix is planned where tests are missing; one app test does not certify all.

## FLOW-2 — Safe reload and contradictory safe requests

- Basis: F02/F03/F08/F11. Scope: each actual phase-bound GET/HEAD endpoint.
- Given a valid current phase, reload succeeds without new proof/session artifacts. Given the same
  flow at another phase, request a past or unauthorized future phase: GET returns 409, text/plain,
  exact body `戻るはだめです`, no Location and preserved Auth no-store; HEAD retains status/headers
  without a body. The Japanese phrase is required customer copy, not repository prose.
- Flow and session workflow state remain unchanged: no halt/advance/cancel, OTP/challenge/provider
  creation or session issuance. No HTML/current-step recovery redirect. Non-phase errors keep their
  existing contract. Check
  [app phase regression tests](../../test/integration/sign_up_phase_regression_app_test.rb) and
  [step refusal tests](../../test/policies/sign_up_step_gate_refusals_test.rb), measuring
  before/after records and response. The local sign-in slice also has public-boundary coverage in
  [app MFA admission tests](../../test/controllers/auth/app/in/challenges_controller_test.rb),
  [com MFA admission tests](../../test/controllers/auth/com/in/challenges_controller_test.rb),
  and the app/com passkey and MFA controller tests; these references establish only the scenarios
  they actually exercise. Other families/surfaces require explicit planned-to-actual test
  references.

## FLOW-3 — Unsafe phase violation and terminal absorption

- Basis: F02–F04/F07/F08. Scope: validly browser-authorized original active-flow mutation requests.
- Given a bound request whose expected phase/generation contradicts the locked/reloaded authority,
  submit it: the owned lifecycle writer moves that flow to HALTED=930 with phase_regression or
  phase_violation and the same refusal response as FLOW-2. This is not CANCELLED/FAILED.
- Retry, late callback, challenge/OTP request or issuance from that halted flow produces no new
  effect and cannot return it to ACTIVE or another terminal. Infrastructure failure alone does not
  mean phase violation. Missing/forged/unowned bindings cannot halt an arbitrary current flow
  (FLOW-4).
- Check public HTTP plus locked transitions and audit, existing
  [state-machine tests](../../test/services/sign_up/state_machine_test.rb) and phase tests. Race
  testing must demonstrate atomic lock/reload/check/transition; a released-lock precheck followed by
  termination is not proof. The signed-instance codec contract is covered by
  [sign-in binding codec tests](../../test/services/sign_in_flow_binding_codec_test.rb). Full
  terminal consumer and independent-connection race coverage remains a planned acceptance item
  until actual evidence is recorded.

## FLOW-4 — Original A cannot mutate replacement B

- Basis: F05/F06, AUTH-2/3. Scope: every phase-bound form/link/callback with actual original-flow
  binding.
- Retain a page bound to flow A, explicitly start a new flow B through its authorized non-GET entry,
  then submit A's old request. B's state and artifacts do not change, and correctly bound B requests
  can complete under normal policy. A is observed/refused according to its own lifecycle; its
  request is never reassigned to the current session locator. Explicit restart never silently
  abandons an active A.
- Missing, malformed, oversized, tampered, wrong-kind/surface/flow, expired or terminal capability
  is refused without acquiring authority over B. Cover reachable null/empty/zero/NUL/encoding inputs
  and before/at/after expiry. Expected phase/version/generation is server-verifiable; unsigned
  labels/raw PKs are not authority. No raw locator nonce exposure or OAuth state/PKCE/CSRF/pt reuse.
- Check codec, Rails-generated URLs/bodies, session locator and HTTP tests. Existing app phase tests
  are a starting reference, not complete cross-family coverage; planned gaps must be named. The
  codec and app/com public controller references above must be checked against the current HEAD,
  not merely found by path. No JS Back/History API state is needed to decide a server request.

## FLOW-5 — Concurrent progression and committed work

- Basis: F04/F07, SESSION-1/2. Scope: two-tab requests, finalization and final issuance in actual
  DBs.
- Given two requests from the same phase, commit one progression and deliver the other's stale
  mutation: strict refusal/HALT applies only to still-active original work. Already committed
  account or valid session is not deleted, rolled back or recreated to implement HALT. A
  same-request retry cannot issue a second session from one flow.
- Repeated back/forward submissions do not multiply pending flows, OTPs, challenges, provider
  transactions, device sessions or refresh/session tokens. Artifact cleanup cannot bypass terminal
  admission; all consumers must refuse unusable proof. Keep separate original-operation bounded
  receipts without fresh success or deadline extension (CONTACT-4).
- Check actual independent-connection races and public integration counts, not only token_id unique
  index presence. Start at root establishment and phase regression tests; comprehensive
  race/consumer evidence is planned. Boundary tests cover lock waits and deadline before/at/after,
  and preserve CSRF.

## FLOW-6 — Audit and current explanation

- Basis: F08/F09/F12. Scope: halts/refusals on all implemented flow families and their
  documentation.
- Given a true halt, inspect its safe durable audit: surface, public correlation, reason, request
  ID, time and any safe phase classification are attributable. No raw email/telephone, credential
  ID, OTP, nonce, capability or secret appears in response, logs, spans or evidence. A generic log
  line alone does not establish the required audit contract; failures/retries remain explicit across
  DB boundaries.
- Inspect [sign-in](../security/sign-in-sequence.md), [sign-up](../security/sign-up-sequence.md),
  [lifecycle docs](../security/idp-flow-lifecycle.md) and
  [transition inventory](../mermaid/idp-state-machine-transition-inventory.md) against actual
  runtime. GET refusal is not a lifecycle edge; target vocabulary is not implemented behavior.
  Historical UML is changed only when it owns current behavior. No business state is changed to fit
  a stale diagram.
- Check public halt/audit tests and source/diagram comparison; additional safe-audit coverage is
  planned if absent. TDD chronology/reporting is PROC-3/4, not a static-code acceptance inference.
