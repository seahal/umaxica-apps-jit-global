# Integrated Auth, Avatar, Warp, and Base Dashboard Implementation Plan

**Status:** Local implementation verified where repository inputs permit; data cutover and external gates remain. The corresponding issue text is kept as a local draft.
**Prepared:** 2026-09-24
**Authority:** Accepted ADRs, current code, tests, and the user's explicit decisions remain
authoritative. The direct user instruction authorizes local implementation; GitHub issue creation or
update is neither required nor permitted for this task.

## 1. Objective

Combine the twelve supplied work requests and the two additional requests into one ordered,
reviewable implementation program. Preserve the security boundaries and public contracts that the
requests leave unchanged, reconcile older wording with the current Base/Auth architecture, and state
the work, acceptance evidence, and remaining external gates explicitly.

This document records the implementation program and local execution state. The current direct user
request authorizes local implementation, tests, and evidence. It does not authorize production
access, external registrations, operational key generation or deployment, GitHub writes, or
destructive production data changes.

## 2. Confirmed decisions and interpretation

- Include all twelve supplied requests, the `Side`/`Wide` to `Warp` rename, and the authenticated
  Base Dashboard UI changes.
- Put Persona identity and the temporary Menu links placement on the **Base app/com/org
  Dashboards**.
- Rename the current `PUBLIC_SIDE_SERVICE_URL`, `PUBLIC_SIDE_CORPORATE_URL`, and
  `PUBLIC_SIDE_STAFF_URL` configuration keys to `PUBLIC_WARP_SERVICE_URL`,
  `PUBLIC_WARP_CORPORATE_URL`, and `PUBLIC_WARP_STAFF_URL`. Keep their values and public FQDNs
  unchanged. Do not support both old and new keys at runtime.
- Give Warp's Jump RT issuance the independent `WARP_APP`, `WARP_COM`, and `WARP_ORG` signing
  namespaces and surface-specific keys. Keep these keys separate from the OIDC client signing
  keys and identifiers.
- The Base UX requirement names `/dashboard`, while the current Base authenticated Dashboard is
  rendered by `/` and Base has no `/dashboard` route. The implementation plan adds a named,
  authenticated `/dashboard` route for app/com/org, retains the existing root behavior, and uses
  route helpers for the return links. This resolves the path contract without hard-coded URLs.
- Keep the persisted `AcmeLogoutTransaction.origin_surface = "side"` value and OIDC IDs such as
  `side-app` unchanged. They are storage/protocol contracts, not Rails namespace names. The
  internal Rails residual search must separately report these protected values rather than
  mechanically renaming them.

### 2.1 Execution and semantic corrections

- A workstream number is not a global serialization gate. Start any unfinished slice whose direct
  prerequisites are satisfied; verify and retain already-correct implementation instead of
  rebuilding it. The full Side/Wide inventory is a prerequisite only to the rename operations that
  depend on it.
- Absence of a GitHub issue does not block local work. Keep the issue body in a local draft and keep
  all registration or deployment activity outside this task.
- Base Dashboard identity is the selected surface Persona's display name plus the image delivered
  through its existing active Avatar binding, if the repository has an approved image-delivery
  interface. The image is presentation data: it does not make the independent Avatar resource the
  authenticated principal, establish ownership, or authorize Avatar operations. Persona moniker and
  Avatar moniker remain separate values.
- The limited retry/read behavior for an Auth result is specific to the current Base/Auth result
  transport and idempotent finalization contract in the accepted ADR. It does not relax one-use
  contracts for admission references, ceremony grants, Turnstile tokens, OTPs, credentials, recovery
  reveal receipts, authorization grants, or other capabilities. Durable authorization-grant
  redemption remains atomically single-use.
- Temporary Credential verification must exclude concurrent use through durable app-database
  state, such as a row lock or conditional state transition with a persistent consumed/claimed fact.
  A process lock, browser state, Valkey counter, or in-memory flag alone is not an exclusion
  guarantee. The implementation must define crash/unknown-outcome handling and test competing uses
  through independent database connections.
- GET navigation does not change authentication, session, preference, or credential state. The
  specified recovery-secret reveal may consume only its own one-time reveal receipt; that narrow
  read-side effect does not authorize other GET mutations.
- Turnstile validation remains server-authoritative. Check ceremony continuity and the canonical
  step before Siteverify; bind accepted responses to the expected action, cdata, hostname, and
  ceremony. Browser Back cannot roll back server state. Distinguish verified success, proven
  non-commit, proven commit, and unknown outcomes; unknown security-sensitive outcomes fail closed
  and are not automatically retried or compensated. Siteverify idempotency and domain-mutation
  idempotency remain separate contracts.
- Warp renames only classified internal Rails names and the explicitly approved local configuration
  keys. Public FQDNs/paths and protected OIDC identifiers, MCP identity, cookie/session contracts,
  and persisted `origin_surface="side"` remain unchanged.
- Owner and moniker implementation, tests, migration design, and synthetic isolated-database
  verification are local work. Real-data inventory application and family cutover require their own
  reviewed disposition and recovery evidence; their absence does not block unrelated local slices.
- The implementation must not add test-only configuration requirements or make ordinary Rails
  tests newly depend on Valkey. A service check that cannot run in the available environment remains
  explicitly unverified; a stubbed boundary test is not evidence that the service itself works.
- The supplied critical review preserves these decisions and adds adversarial acceptance proposals.
  They are tracked below as execution checks or capability-specific gates, not as evidence that a
  new JWT claim, cookie, product visual, or public API was approved.

## 3. Baseline findings before local execution

This section records the repository state inspected while consolidating the plan, before the local
implementation documented in Section 7.2. Do not read its historical “current” descriptions as the
post-change state.

### 3.1 Base/Auth architecture

- The accepted `adr/base-auth-ceremony-and-seven-rp-boundary.md` establishes Base as the physical
  Authorization Server and Auth as a ceremony service. Core app/com/org, the existing Side app/com/org
  RPs, and Edit org remain distinct RPs.
- The current architecture amendment makes Base's durable authorization transaction the finalization
  authority and permits bounded re-reading of a valid opaque Auth result. Older attachment wording
  about one-shot result redemption must not override this current amendment.
- The primary-auth concurrency requirement and the ceremony-monotonicity requirement are compatible
  when implemented at their proper levels: Base-issued generation orders competing operations;
  Auth's ceremony steps are monotonic within an operation. Arrival time and browser history are not
  authority.

### 3.2 Side/Wide inventory and persistence

- `Side` is one Rails surface with three independent faces, not a separate app/com/org lifecycle.
  The inventory found 63 controllers, 3 view templates, 19 Inertia pages, 6 JS/Inertia entrypoints,
  3 surface stylesheets, 16 controller tests, one route file, two shared concerns, and two dashboard
  components under or named for Side. Their controller namespace, paths, route-helper prefix,
  frontend stack identifiers, config accessors, and source references are rename candidates.
- `Wide` appears as the three `wide.*.localhost` development/test host aliases for those faces. It
  is a host alias, not another Rails surface or lifecycle. Rename these local aliases to
  `warp.*.localhost`; do not change production FQDNs.
- The inspected schema and migrations contain no `Side::` / `Wide::` STI or polymorphic class name,
  serialized class name, GlobalID, or Side-named job/model argument. There are no Side or Wide model
  or job classes. `AcmeLogoutTransaction.origin_surface` is the explicit persisted `"side"` enum
  value; retain it and map Warp sign-out to that stored value at the persistence boundary.
- FQDN availability slots are runtime host classifications, but their generated Flipper feature
  names are persisted operational flags. Rename the in-memory slots to Warp and keep the existing
  `fqdn_available_side_service`, `fqdn_available_side_corporate`, and
  `fqdn_available_side_staff` feature keys through an explicit storage-boundary mapping.
- OIDC client IDs and regional client IDs (`side-app`, `side-app-jp`, and the corresponding com/org
  IDs), OIDC client-name metadata (`Side App RP`, `Side Com RP`, `Side Org RP`), OIDC key namespaces
  (`SIDE_APP`, `SIDE_COM`, `SIDE_ORG`), RP-session client bindings, the `side-service` token audience,
  and MCP realm/server identities containing `"side"` are protocol/client metadata and remain
  unchanged. `AuthBoundaryAuthorityMap`'s `surface` metadata is internal
  routing metadata and will use `"warp"` while preserving each client ID, audience, actor type,
  client signing namespace, and RP-session client ID.
- The current public host values are `www-jp.umaxica.app`, `.com`, and `.org`. The configuration
  builder uses `PUBLIC_SIDE_*_URL`, while the active OIDC registry separately reads `SIDE_*_URL`.
  Both old host-key families are internal inputs for these same public faces; replace them with the
  approved `PUBLIC_WARP_*_URL` keys and do not read both names at runtime. Regional US host
  candidates remain unconfigured and fail closed; no host or audience is inferred from this rename.
- No `Side = Warp`, `Wide = Warp`, compatibility module, deprecated alias, `const_missing`, or
  runtime fallback is allowed.

### 3.3 Persona, Avatar, and Dashboard

- Base's authenticated root currently renders the app/com/org Dashboard; `config/routes/base.rb`
  has Preference and sign-out routes but no named `/dashboard` route.
- The current Menu arrays put Switcher first on app and Selector first on com/org. The required
  post-login Menu order is Persona identity, Preference, Switcher, Logout. Preserve Selector's
  pre-access role; use the existing post-login Switcher routes for all three surfaces.
- The concrete surface Personas are `ClientPersona` (app), `Individual` (com), and `Agent` (org).
  Their Persona moniker is distinct from the Avatar moniker being refactored. Display the selected
  Persona's display name from its canonical Persona moniker; do not substitute Avatar moniker,
  email, database/public ID, GUID, credential ID, or session identifier.
- The Avatar database has surface-local Avatar-to-Persona/Individual/Agent bindings and private
  image storage, but the reviewed code has no established public image-delivery interface. Resolve
  the Avatar through the authenticated, selected Persona and its existing active binding. Never
  accept a client-selected Persona or Avatar ID from a URL parameter. Dashboard image rendering is
  blocked until an approved delivery contract exists; do not expose storage URLs or invent a route.
- `GroupAvatarMembership` and `AvatarMoniker` tables/models already exist. Some supplied text that
  describes them as absent is stale; implementation must inspect and complete the current contract,
  not create duplicate structures.

### 3.4 Approved decisions and known gates

- The supplied human decision approves six surface-local owner mappings: Client to Persona/Enterprise,
  Visitor to Individual/Company, and Operator to Agent/Bureau. Organization is not Bureau. Membership,
  administrator, assignment, legacy organization, and identity-binding data do not independently
  confer owner authority.
- The approved regional OIDC target contains twelve Core/Side JP/US cells and global `edit-org`.
  Repository code must remain fail-closed when a canonical host, audience, registration, or key
  binding is missing. Current repository evidence reports no independent Side/Warp US host source
  and no regional audience SSOT; do not infer either from a request Host or client ID.
- The six resource-family lifecycle schemas, some ownership consumers, group membership, and Avatar
  moniker-history structures already exist. Family-wide owner consumer cutover and its forward-only
  recovery proof remain separate acceptance gates. Do not claim those gates closed merely because
  the approved decision or schema is present.

### 3.5 Known blockers and their scope

| Gate | Current state | What it blocks | What can proceed |
| --- | --- | --- | --- |
| Regional OIDC host/audience inputs | The regenerated read-only report has missing canonical audience for all six Core JP/US cells and all three Warp JP cells; the three Warp US cells have no canonical host; global `edit-org` is complete. No independent Warp US host source or regional audience SSOT is present. | Registration, regional client activation, and deployment of those clients. | Keep the local registry fail-closed, preserve the approved IDs, and continue unrelated work. Supply canonical host/audience/registration inputs before activation; do not infer them. |
| Persona/Organization family cutover | Full reviewed inventory, all consumer switches, zero unresolved authority-required rows, and forward-recovery proof are not complete. | Creating the point-of-no-return family marker or declaring the family cut over. | Read-only inventory, reviewed backfill tooling, guardrails, and explicitly scoped consumers that do not claim family cutover. |
| Avatar moniker data/schema removal | Current `avatars.moniker` values and temporal `AvatarMoniker` rows require a read-only conflict inventory and a bounded migration/recovery disposition before destructive migration execution. | Applying the destructive schema/data migration to a populated database. | Validator/service/model work, tests, migration design, and permitted isolated test-database verification. |
| Warp signing/deployment inputs | New per-surface JWT key configuration is approved, but production keys and deployment environment changes are not present or authorized here. | Production deployment and live Warp Jump RT issuance. | Local code and test key coverage; deploy preparation documentation. |
| www-jp production anomaly status | Local findings and classifications are recorded in Section 7.5; no current production logs were accessed. | Claiming production behavior is resolved or unchanged. | Authorized read-only access to current production logs. | Local SSO, preference, query-count, and configuration checks are complete; browser HMR remains inconclusive. |
| F1 recovery reveal residuals | The source request explicitly defers the current actor-public-ID `session_nonce` and pre-reveal top-up activation behavior. | No current implementation scope; those risks remain open for later design. | Keep receipt consumption one-use; HEAD/OPTIONS do not consume or disclose, and response loss does not trigger automatic re-disclosure. |
| Dashboard image delivery and absence matrix | The repository report has not established an approved image-delivery interface or the valid absence/error contract for each surface. | Claiming image integration complete or inventing a URL/placeholder/provisioning path. | Complete named routes, navigation, Persona monikers, and read-only selection separately; inspect the actual binding and delivery contract. |
| Auth generation and attempt fencing | Local PostgreSQL tests cover competing authentication results, one-time grant redemption, and stale-generation Base finalization. Six opaque admission/result transport tests skip because `AUTH_STATE_REDIS_URL` is unset; live provider behavior is separately unverified. | Claiming real-Valkey transport verification or live Turnstile verification. | The row-locked local ordering, stale-result, ceremony replacement, and fail-closed boundary tests ran; continue unrelated work and run service-specific checks when configured. |
| Emergency Credential commit acknowledgement | Durable exclusion must survive commit and the owning authority needs trusted proof of the same app RP commit. | Activating a Credential sign-in when claim, RP session commit, and consume span an unproved protocol. | Audit existing status/DB ownership; implement local state and tests that do not assert an unproved cross-DB guarantee. |
| Legacy App LOGIN row disposition | The old App secret login route and model verifiers can be removed locally, but any existing App Principal rows still require logical revocation/discard. | Applying a batch state change to populated `app_principals` rows. | A read-only count and classification against the actual database, an approved bounded recovery/restore method, and explicit approval for the persistent write. Until then, keep legacy rows unable to authenticate in application code and continue all independent work. |
| Avatar mutation consistency | Same-Avatar writers, Group membership, principal lifecycle, and Step-Up may cross database boundaries. | Claiming race-safe transfer/attach/permission-revocation ordering without a real authority contract. | Complete inventories and same-database constraints; keep only the affected mutation activation gated. |
| Avatar moniker destructive migration | Current and historical data plus the actual connection/constraint graph need a bounded recovery disposition. | Applying destructive data/schema changes to populated or production data. | Implement validators, service behavior, non-destructive schema preparation, and synthetic isolated-database verification. |
| Org selected-Avatar extension | The owning session field and writer/reader contract are not established by the reviewed material. | Inventing a claim, cookie redesign, or org selection behavior. | Keep the existing selected-actor boundary; resolve only if an original accepted source request requires this field. |
| Read-only navigation and legacy CSRF session state | Current preference loading is read-only on GET/HEAD, browser auth refresh is disabled, and session-activity tracking defaults off. Existing OIDC/social protocol callback writes remain separately listed. HTML forms use `:header_or_legacy_token`; a session-storage-skip experiment broke the legacy-token path and was reverted. | Claiming every GET/HEAD in the repository is globally write-free across protocol callbacks, or claiming CSRF-protected HTML emits no session state without proof. | Keep task-specific return/navigation GETs and audited read-only routes free of auth/session/preference/credential mutation. F1 may consume only its own reveal receipt. Inventory protocol callbacks separately; do not expand them or weaken CSRF. Any session-free HTML claim requires an approved CSRF design and public request proof. |
| Auth admission real-Valkey verification | `AUTH_STATE_REDIS_URL` is unset in this environment; the six tests in `BaseAuthAdmissionCoordinatorTest` therefore skip. | Claiming that admission/result transport has been verified against a running Valkey service. | Run those tests with an explicitly configured local Valkey service. Continue local database, request, and unrelated tests; do not substitute a mock as service evidence. |

These are phase-scoped gates, not contradictions to silently work around. They do not prevent all
local implementation, but they do prevent the specific blocked operations and any claim that those
operations are complete.

## 4. Governing invariants

1. Base is the sole physical OIDC Authorization Server; Auth performs credential/authentication
   ceremonies and does not own RP callbacks, authorization codes, RP sessions, or independent AAL
   authority.
2. Keep app/com/org trust boundaries, databases, cookies, sessions, authorization, and ownership
   local. Any named cross-database interaction remains a bounded protocol and never becomes a
   cross-database transaction or foreign key.
3. Preserve public FQDNs, existing URL paths, OIDC client IDs/audiences, callback and logout
   contracts, cookies, session semantics, temporary-token contracts, and persisted values except for
   the explicitly requested addition of Base `/dashboard`.
4. No silent fallback, legacy execution path, compatibility alias, inferred owner, guessed
   audience/host, client-controlled identity, or browser-history/referrer-based authorization.
5. Unexpected state fails explicitly. Recovery is explicit and bounded; it does not silently issue a
   replacement token, restore consumed credentials, or downgrade a security decision.
6. Preserve the current result-finalization amendment and use the accepted ADR when older source
   prompts conflict with it.
7. Production/provider/cloud/GitHub writes, external RP registration, production key creation,
   deployment, and destructive production data changes are out of scope.

## 5. Dependency-ordered workstreams

### Phase 0 — Baseline and contract freeze

1. Re-read `git status`, current ADRs, the current integrated hardening plan, affected code, route
   declarations, migrations, tests, frontend stacks, environment samples, and deployment docs before
   editing. Preserve all pre-existing user changes.
2. Build the final source inventory for every `Side`, `Wide`, `side`, and `wide` occurrence. Classify
   each as an internal Rails identifier, public/protocol identifier, persisted value, natural-language
   word, or historical record. Inventory STI/polymorphic values, serialized values, GlobalID/job
   arguments, logs/metrics/traces, and frontend component references before moving files.
3. Record the pre-change route/host matrix and current tests for app/com/org and the existing Core,
   Base, Auth, Palm, and Edit boundaries.
4. Update stale documentation that says `GroupAvatarMembership` or Avatar moniker history is absent.
   Historical ADRs/changelogs/migration filenames remain intact; add a current-name note only where
   needed to prevent readers mistaking historical names for current Rails constants.

**Gate:** Before a Side/Wide file, constant, route declaration, helper, or configuration key is moved
or removed, classify its uses and list its protocol/persistence exceptions. This rename-specific
gate does not stop independent workstreams. It is repository fact gathering, not a request to
re-decide the approved owner or regional-client decisions.

### Phase 1 — Base/Auth boundary and monotonic authentication flow

1. Reconcile the executable architecture with the accepted Base/Auth ADR: remove any remaining
   executable Auth RP/OIDC callback or authorization path; keep Base as the only AS and Auth as
   ceremony-only. Retire stale executable configuration and tests without adding compatibility
   routes.
2. For each primary-auth operation, have Base issue an authoritative logical generation. A later
   valid operation supersedes earlier operations regardless of callback arrival order. Stale Auth
   results cannot issue a token, create/replace a session, or overwrite the latest operation.
3. Make Auth ceremony steps monotonic within each generation. Browser Back/BFCache, duplicate or
   parallel requests, and stale form state cannot move a ceremony backward or replay a completed
   transition. An unknown result is explicit; it is not silently compensated or restarted.
4. Preserve the current Base result transport/finalization contract: opaque short-lived Valkey
   transport, durable Base generation/digest/expiry checks under the locked transaction row,
   idempotent Browser Session finalization, one durable grant per authorization transaction, and
   rollback of a failed durable token issuance.
5. Keep Base available as the recovery boundary. Auth state or Auth outage cannot block a valid Base
   recovery entry; recovery requires the canonical Base flow and never silently issues a new
   primary token.
6. Preserve ordinary org Entra sign-in. Keep the exceptional emergency Passkey path in Restricted
   Mode; do not add org self-service registration, JIT creation, or an alternate ordinary sign-in.
   Retain the neutral sign-in/sign-up purpose vocabulary and reject purpose/admission mismatches.
7. Keep preference-refresh/OAuth failure behavior explicit, avoid exposing provider internals to
   users, and preserve server-side authentication authority.
8. Keep ceremony authority singular: the current-ceremony store identifies the browser's ceremony,
   the ceremony session owns continuity/expiry/terminal lifecycle, and the context store owns the
   active step, generation, flow kind, and required ephemeral context. Do not duplicate step
   authority across cookies, Rails session, PostgreSQL, and Valkey.
9. For non-canonical ceremony navigation, GET is read-only and redirects with 303 to the current
   canonical step; mutation requests validate continuity, step, and generation before Siteverify.
   Wrong, past, future, completed, expired, replaced, or stale-session steps do not invoke
   Siteverify or domain mutations. A safely resumable completion may roll forward; otherwise return
   to the canonical Base entry.
10. Preserve the Turnstile matrix for Email Sign Up issue/verify, Email Sign In issue/verify, and
    Telephone Sign Up issue/verify. Issue and verify use separate actions. Keep action, cdata,
    hostname, and ceremony binding; retain rate limits, enumeration resistance, OTP expiry,
    single-use, failed-attempt accounting, CSRF, and resend-count rules.
11. Use the existing Turnstile widget/components. Pending, expired, timeout, and error states clear
    the token and prevent client submission; verified enables one submission; submitting prevents
    duplicate submission. The server remains authoritative. BFCache restoration must not rely on
    JavaScript for correctness.
12. Atomically claim each server-side ceremony/step/generation attempt with a bounded expiry. A
    competing request stops before Siteverify and domain mutation. Siteverify idempotency does not
    make domain mutations idempotent. Classify each security-sensitive result as proven not
    committed, proven committed, or unknown; only proven-not-committed work may retry after timeout
    with a new token. Unknown outcomes fail closed without automatic retry or compensation.
    Reuse existing durable success evidence and add no generic execution table unless a concrete
    step lacks one.
13. Treat provider calls as non-atomic with database transactions. Existing outbox/job mechanisms
    own delivery retries; a provider timeout does not justify inferring or reversing security state.

**Acceptance:** stale-generation, callback reordering, duplicate, parallel, BFCache/back-navigation,
unknown-state, and service-failure request tests; org Entra normal and emergency Restricted Mode
tests; no Auth-owned RP routes or session/AAL authority; no token/session issuance from a stale
result. Also test current/past/future/completed/stale/expired/replaced navigation; that wrong-step
POST does not invoke Siteverify or mutate domain state; the full six-flow OTP Turnstile matrix;
missing/expired/error/mismatched/network-failure tokens; duplicate and parallel attempt claims and
bounded timeout; BFCache restore; and proven-not-committed/proven-committed/unknown recovery without
restoring consumed OTPs. Update the ADR and flow docs to the current result-finalization semantics.

### Phase 2 — Side/Wide to Warp internal rename and Jump RT issuance

1. Move the Side controllers/views/routes/frontend stack entries into Rails-conforming `Warp`,
   `Warp::App`, `Warp::Com`, and `Warp::Org` namespaces and `warp/`, `warp/app/`, `warp/com/`,
   `warp/org/` paths. Keep app/com/org symmetry and exact Zeitwerk constant/path matching.
2. Rename route controller/module declarations and internal route helpers to Warp names while
   retaining every existing public path and host. Update specs, scripts, docs that describe current
   implementation, and internal log/trace names where they are not externally consumed contracts.
3. Rename the local `wide.*.localhost` development/test aliases to `warp.*.localhost`. Keep all
   public `www-*` FQDNs and their values unchanged.
4. Rename the public-face host inputs to the corresponding `PUBLIC_WARP_*_URL` names in
   application config, examples, tests, and deployment documentation, including the active OIDC
   registry's legacy `SIDE_*_URL` inputs. Do not accept old and new key sets or silently fall back
   to a Side key. Deployment operators must update the variables before a later deployment; no
   deployment write is part of this plan.
5. Add `WARP_APP`, `WARP_COM`, and `WARP_ORG` to the Jump RT surface issuer registry, map each to
   the exact existing public Warp FQDN, and use independently configured `JWT_WARP_*` active `kid`,
   private key, public keyset, and revoked-kid inputs. Missing or malformed non-local key material
   fails boot/configuration checks. Never reuse the OIDC client signing key or key ID, and never
   generate production keys in this repository task.
6. Change controller-to-Jump-RT namespace resolution to recognize `Warp::*`; add exact negative
   coverage for unknown namespaces. Keep `OIDC_CLIENT_SIDE_*`, `side-*` client IDs, audiences,
   RP-session identifiers, persisted `origin_surface="side"`, and protocol-visible MCP realm/name
   values unchanged. Change internal client-registry surface metadata from `side` to `warp` while
   keeping the `side-*` client-id keys. Any Warp-to-`side` mapping is an explicit storage/protocol
   boundary conversion, not a compatibility fallback.
7. Keep the approved regional RP matrix fail-closed. Do not activate missing Warp US hosts or
   regional audiences and do not invent `PUBLIC_WARP_*_US_URL` values without canonical repository
   inputs and the required separate registration/deployment gate.

**Acceptance:** `bin/rails zeitwerk:check`; exact route/host parity for `www-jp.umaxica.app`,
`www-jp.umaxica.com`, and `www-jp.umaxica.org`; Jump RT issue/verify/replay/key separation tests;
app/com/org symmetry; no old Rails namespace/path/helper/environment key; and a classified residual
report for immutable protocol, persistence, and historical-document values.

### Phase 3 — OAuth authorize rate-limit correctness

1. Keep the check order IP, browser, then client. A rejected earlier check short-circuits later
   checks.
2. Return `429` for a limit rejection and `503` when the required Valkey backend is unavailable or
   reports an operation error. Never fall back to process memory, another backend, or fail-open
   behavior.
3. Make nil, malformed, and error results distinct and explicit. Do not collapse configuration or
   backend errors into a successful/allowed decision.
4. Preserve per-client isolation, route behavior, and existing auth policy; record operational signal
   requirements using the current alerting convention, without inventing an unapproved numeric
   threshold.

**Acceptance:** ordered short-circuit matrix; allow/reject/store-outage/store-error/nil cases;
nearest boundary and equivalence partition coverage; request tests for `429`/`503`; and updated
operator guidance.

### Phase 4 — Sign-out correctness and cross-surface audit findings

1. Keep sign-out as an explicit CSRF-protected mutation. GET confirmation, completion, cancellation,
   and return representations do not mutate authentication state. Disable transparent token refresh
   during sign-out on every affected Base/Core/Warp/Auth/Palm path.
2. Reconcile com/org coordinated logout ordering and CSRF checks without weakening order. Emit
   existing structured accepted/rejected audit events without secrets or tokens.
3. Verify the Palm → Base → Auth → Base → Palm completion protocol is one-shot and replay-safe.
   Keep one-shot completion state and clear failure outcomes; no GET mutation or hidden second
   sign-out path.
4. Apply the cross-surface findings only as specified:
   - **F1:** add `resource :recovery_secret, only: :show, path: "recovery-secret"` under Base app/com
     identity and route both to `RecoverySecretsController#show`. Move the com reveal-only
     `SecretsController` to that name; connect the existing app controller. Update only reveal URL
     destinations in existing TOTP/passkey/sign-up callers, not the sign-up sequence. Render the
     two surface-specific Inertia pages, return no secret for spent/expired/malformed tokens, and
     set `Cache-Control: no-store, no-cache, must-revalidate, private`, `Pragma: no-cache`,
     `Expires: 0`, and `Referrer-Policy: no-referrer`. Preserve the specified one-time
     reveal-receipt consume contract. This is the only explicit GET side effect in this workstream;
     it does not change session, authentication, or other credential state. Keep Com's existing
     top-up-before-reveal behavior in this workstream. App Passkey/TOTP/sign-up auto-top-up removal
     belongs to Phase 7. Do not redesign `IdentityOneTimeReveal` token transport or its current
     actor-public-ID `session_nonce`; record those as explicit residual risks for a later design.
   - **F2:** preserve logout mutation CSRF, ordering, and accepted/rejected security records for
     com/org.
   - **F3:** prohibit transparent refresh while sign-out is in progress.
   - **F4:** make docs/news host routing use the existing canonical host source.
   - **F5:** normalize the token resource path for `refresh` without changing the token contract.
   - **F6:** update provider documentation to match the implemented provider boundary.
   - **F7:** move the com reveal-only controller as described under F1. Remove app
     `RemovalsController`/`RotationsController` compatibility shims and the stale
     `KNOWN_VIOLATIONS` entry only if both `rails routes` and repository-wide reference search show
     zero runtime references; otherwise retain the shim for this cycle.
   - **F8:** remove `CORE_NETWORK_URL` and `CORE_DEVELOPER_URL` fallback paths; the corresponding
     `PRIVATE_CORE_*` settings are the sole current contract.
   - **F9:** remove com/org Palm configuration, retaining Palm app configuration only.
   - **F11:** remove the com-only required telephone gate; preserve the approved app/org policies.
   - **F12:** make MFA reset app/com/org GET-only unavailable placeholders. No POST/create/update/
     destroy route, MFA mutation, credential revocation, fake success, or dummy persistence. GET
     must not change actor, MFA, session, credential, or Chronicle state.
   - **F13:** set the com edge refresh controller's default authentication mode to `deny_all`,
     preserving the explicitly declared `open` action behavior.
   - **F14:** add com/org theme/cookie public-behavior coverage matching the app contract while
     preserving any proven surface-specific behavior.
   - **F10:** billing/billings route naming is deferred.
   - **F15:** redirect-only shims remain deferred while the active sign-in/sign-up redesign owns
     that flow.
5. Keep sign-out destination and completion helpers surface-local. Preserve `ri` using the canonical
   route/context mechanism and test JP/US partition behavior where the route contract includes it.

**Acceptance:** public request/route tests for every applicable surface; ordinary navigation GETs
do not mutate auth/session/preference/credential state, and existing documented lifecycle or
protocol callback exceptions are inventoried without expansion; CSRF and order regressions;
accepted/rejected logging shape; Palm replay/concurrency; RecoveryPasscode one-time reveal,
cache/referrer headers, malformed/spent/expired behavior, HEAD/OPTIONS non-consumption, parallel
app/com GETs with exactly one disclosure, and a lost-response retry that does not re-disclose; no
application-controlled prefetch for the reveal link; both documented residual risks; reset
GET-only/non-mutation/POST absence; host and token-resource contracts. F10/F15 are explicit
exclusions, not forgotten work.

### Phase 5 — Persona/Organization owner authority and Avatar membership

1. Use only the approved six direct owner mappings. Candidate backfill is surface-local, explicitly
   reviewed, lock-protected, idempotent, and conflict-rejecting. Membership, administrator,
   assignment, legacy Organization, or identity-binding data cannot self-promote into ownership.
2. Require explicit lifecycle state and an eligible principal/resource. Ambiguous, zero, inactive,
   contradictory, access-blocked, cross-surface, and legacy-only records remain rejected or manual
   review. Family cutover requires zero unresolved authority-required active rows.
3. Preserve forward-only behavior after a family marker/consumer cutover. Do not switch delegated
   selector/switcher access to owner-only semantics. Do not claim family cutover complete without
   consumer inventory and forward-recovery evidence.
4. Treat Avatar as an independent resource. Use `AvatarOwnershipPeriod` as ownership SSOT, keeping
   owner authority, Avatar operation permissions, social graph, group membership, and account
   binding separate.
5. Do not use `AvatarAssignment`, `AvatarMembership`, Avatar/Persona bindings, or a legacy
   `owner` assignment role as ownership or operational authorization. Audit all security-sensitive
   AvatarPolicy, selector, switcher, and controller checks. Remove a legacy dependency only after its
   separate history/compatibility use is disproven. A binding remains association data, not authority.
6. Resolve operational access through active Persona/Agent membership in the current owner
   collective and a shared permission resolver; policy code checks permissions, not role strings.
   The v1 OWNER mapping grants the defined high-privilege Avatar permissions; MEMBER/GUEST receive
   none implicitly. Keep app/org permission meaning equivalent.
7. Represent selector behavior with separate Avatar capability and default-provisioning semantics:
   app requires/selects an Avatar and bootstraps its default; org allows selection but does not
   auto-create one and must remain usable with zero Avatars; com has no Avatar creation, selection,
   or operations. Add the missing org selected-Avatar session field only through its owning token
   contract. Revalidate current ownership, membership, and permission on every request; a stale
   selected Avatar ID is not authority.
8. Add current ownership periods for Avatar Groups, separate from their account-management scope.
   Group and initial owner are created atomically in the Avatar database. Group owner surfaces are
   app/org only. Do not infer existing Group owners from current/primary membership; unresolved
   records remain non-mutable until reviewed.
9. For GroupAvatarMembership, require active Group and Avatar, both current owners, equal owner
   surface/collective, active membership in that collective, and the attach/detach permission.
   Continue enforcing Group account scope. Keep `role` persisted as the sole value `member`: remove
   caller-controlled roles, validate in the model, and add the matching database check. Do not
   accept public IDs alone as proof of access.
10. Implement explicit Avatar ownership transfer state (`pending`, `accepted`, `cancelled`,
    `expired`) in the Avatar database with explicit source/target surface and collective IDs,
    request/accept/cancel actor surface/public IDs, timestamps, and no generic cross-database actor
    FK. One Avatar may have at most one pending transfer; enforce this race-safely in the database.
    Only app/org are valid endpoints; same-owner transfer is rejected; Group ownership transfer is
    out of scope.
11. A transfer request expires after five days; no response never auto-accepts. Expiry is checked
    against `expires_at` on every accept even if a background job is delayed. Expired pending rows
    may be materialized as expired by the existing queue, but the job is not the security boundary.
    A new request may expire an old pending row safely before inserting a new one.
12. Require operation-specific Step-Up for request, accept, and cancel, without imposing AAL2.
    Preserve the existing Step-Up confirmation/resubmit flow; do not auto-replay state-changing
    POSTs. Request authorization requires the current source owner, active membership, permission,
    fresh proof, eligible Avatar lifecycle, valid target, and no pending transfer. Requests do not
    change ownership.
13. Accept through the target owner's active membership and permission; look up by transfer public
    ID rather than the target's not-yet-selected Avatar. Lock/recheck transfer and current ownership
    in the Avatar DB transaction, revalidate expiry/source/target/lifecycle/replay conditions, then
    close the old and open the new ownership period with one timestamp and mark accepted atomically.
    Do not write a distributed transaction or mutate another surface's ticket/session database.
14. On transfer, end only GroupAvatarMembership rows whose Group owner no longer matches the new
    Avatar owner, in the same Avatar DB transaction. Keep matching memberships, public IDs, handles,
    moniker history, lifecycle history, content relations, and social graph. Legacy bindings,
    assignments, and stale session selection must not preserve old-owner authority. Cancel is
    source-owner-only, permission-checked, Step-Up-protected, pending-only, and replay-safe.
15. Correct stale ADR/docs that claim group membership tables are absent. Do not add a duplicate
    table/model or flatten surface-specific controllers into an unapproved shared authorization
    boundary.

**Acceptance:** surface-local owner/lifecycle tests, ambiguous/manual-review tests, cutover guard and
forward-only regression tests, selector app/org/com behavior, permission-resolver and Group attach/
detach public request tests, transfer source/target/replay/expiry/concurrency tests, app-to-org and
org-to-app transfer, com prohibition, matching/mismatching Group membership cleanup, stale selected
Avatar rejection, legacy-owner rejection, no Step-Up/AAL2 drift, and no cross-database write.

### Phase 6 — Avatar moniker lifecycle

1. Treat the current `AvatarMoniker` table/model as existing implementation to audit. Make its
   temporal current row the Avatar moniker SSOT, with one current row per Avatar (`valid_to =
   infinity`) protected by the existing partial unique index. Do not use latest `valid_from` as
   authority or fall back to `avatars.moniker`, public ID, or handle when the current row is absent;
   missing current state is a fail-fast data-integrity error.
2. Expose an explicit `Avatar#current_avatar_moniker`/read-only `Avatar#moniker` API derived only
   from that row. Do not add a setter; a dedicated service owns moniker changes.
3. Make `avatar_monikers.moniker` Rails Active Record Encryption non-deterministic (`encrypts
   :moniker` default), with `varchar(512) NOT NULL` storage and no search/sort/index on encrypted
   plaintext. Keep user-input limits independent from ciphertext storage size.
4. Use a focused validator. NFC-normalize before validation; reject nil, empty, whitespace-only,
   and leading/trailing whitespace without trimming. Limit normalized UTF-8 plaintext to 128 bytes
   (127/128 valid, 129 invalid) and 16 extended grapheme clusters (15/16 valid, 17 invalid), using
   Ruby's standard grapheme API and stopping when the 17th cluster is found. Reject NUL, C0, DEL/C1,
   TAB, CR, LF, U+2028/U+2029, BOM, zero-width space, and bidi formatting/control characters. Do not
   ban Japanese/non-ASCII text, combining marks, valid emoji/ZWJ, ZWNJ, or variation selectors.
   Profanity/reserved-word dictionaries are out of scope.
5. Use frontend `Intl.Segmenter` or the established equivalent for the 16-grapheme UX check; do not
   treat HTML `maxlength=16` as this contract. A coarse 128-character native input limit may be
   additional UX protection only.
6. Measure the actual encrypted payload under the repository's Active Record Encryption settings.
   Prove an allowed 128-byte plaintext fits in `varchar(512)`; expand physical storage to 1024 only
   if the measured encrypted value requires it. Do not relax plaintext/grapheme limits.
7. Remove `avatar_moniker_status_id`, its index/FK/reference data/model when unused, and the
   undefined `set_by_actor_id`; `valid_from`/`valid_to` are the sole state representation. Add a
   new migration under repository migration rules; do not rewrite historical migrations.
8. Make Avatar, initial handle, initial encrypted moniker, required ownership period, binding, and
   assignment graph atomic. Preserve retention purge behavior and the requested Avatar deletion
   cascade. Review old `avatars.moniker` data and current temporal rows before dropping the column;
   the requested change rejects backward compatibility, but any destructive data disposition still
   requires an explicit, bounded migration/recovery plan under repository policy.
9. Keep Persona moniker fields distinct. Base Dashboard identity reads the selected Persona's
   moniker; Avatar identity uses the Avatar's temporal moniker only where an Avatar name is shown.

**Acceptance:** normalization/byte/grapheme boundaries; null/blank/malformed and prohibited Unicode
partitions and valid Unicode equivalence classes; open-row uniqueness and temporal transition;
encryption properties and measured ciphertext capacity; atomic creation; purge/FK behavior; frontend
grapheme check; no setter or old-column fallback; and migration/recovery evidence on permitted local
test data.

### Phase 7 — App emergency Secret Credential

1. Retire the old permanent Secret Credential authentication path on every surface: remove the
   `PERMANENT` alias, mixed `ALLOWED_FOR_SECRET_SIGN_IN` allowlists, legacy model sign-in scopes and
   verifier methods, and the shared `verify_and_consume!` verifier. Do not count these rows as AAL1
   methods. Preserve persisted kind IDs, including the stored `LOGIN` values; do not rename or
   rewrite database enum values as part of the code cleanup. Legacy rows must not authenticate
   through any new-axis verifier or compatibility branch.
2. Require an authenticated app session and the specified Step-Up before issuing. Persist one
   absolute five-minute expiry; do not extend it on retry.
3. Count only credential-mismatch failures, cap at five, and test 4/5/6 attempts. Other failures
   remain outside that counter. A successful sign-in commits the app RP sign-in first and then
   consumes/deletes the temporary credential exactly once; failures do not return credentials.
   The successful-use path must acquire durable app-database exclusion before an attempt can create
   an RP session; process-local locks or Valkey-only claims are insufficient. A retry or competing
   request cannot create a second session. Define the crash/unknown-outcome rule without reviving a
   claimed, consumed, expired, or locked Credential.
4. Use the current Solid Queue retention purge schedule and retention architecture. Do not add a new
   queue/scheduler or leave expired current rows permanently.
5. The result is AAL1. Do not conflate this Credential with existing one-time RecoveryPasscodes:
   RecoveryPasscodes may remain app/com under their own contract. Keep org emergency Passkey flow
   separate.
6. Keep `/sign/in/emergency/credential` inactive until a committed durable claim is bound to a
   trusted, same-operation proof that the app RP session commit succeeded. Auth success, a redirect,
   client callback, process lock, or Valkey claim is not that proof. Unknown outcomes remain claimed
   and fail closed; retries may reconcile only the same durably identified operation.
7. Inventory and logically revoke/discard existing legacy App `LOGIN` rows using existing retention
   fields so the current purge job can process them. Keep this data write separate from code
   retirement. Do not apply it to a populated database until the bounded row criteria, recovery
   method, and explicit persistent-write approval are recorded.

**Acceptance:** public route and controller tests; permission/Step-Up; TTL below/at/after expiry;
retry and mismatch BVA/EP; 4/5/6 cap; independent-connection concurrency/replay proving persistent
exclusion; RP-session commit/consume ordering; crash/unknown-outcome behavior; purge; app-only
boundary; legacy App `LOGIN` rows rejected by all authentication entry points; no old permanent or
shared-consume model APIs; unchanged persisted kind IDs; an approved/logically safe legacy-row
revocation operation; and no RecoveryPasscode regression. The emergency endpoint stays inactive
until the commit-acknowledgement gate is met.

### Phase 8 — Base Dashboard, sign-out edit, and Preference navigation

1. Add named `GET /dashboard` routes/helpers for Base app/com/org that render the existing
   authenticated Dashboard through its canonical authorization/selected-actor boundary. Preserve
   current root behavior and use the new route helper for the explicitly requested Dashboard
   destinations.
2. On each Base `/sign/out/edit`, remove “Go to home” and show Back to the same surface's named
   Dashboard route. Keep Logout on the existing CSRF-protected sign-out mutation. Back performs no
   mutation and does not depend on history or Referer. Preserve `ri` using the current canonical
   mechanism.
3. On Base `/preference`, branch using the server's existing authoritative authentication state:
   authenticated returns to that surface's `/dashboard`; unauthenticated returns to that surface's
   `/`. Keep preference persistence separate from the return link. The unauthenticated home remains
   unchanged.
4. Share the smallest existing partial/helper/presenter structure that can later move from the
   Dashboard into the header `nav`; keep selection, authorization, route generation, and image
   delivery server-derived. Do not create a generic navigation framework.
5. Put the selected Persona identity at the head of Menu links, followed exactly by Preference,
   Switcher, and Logout. Preserve app/com/org surface-local session and selector/switcher authorities.
6. Render the selected surface Persona moniker and its Avatar through the existing active binding
   and image delivery path. The initial Avatar image uses the ordinary Avatar image contract. No
   URL parameter or client prop can choose an identity. A missing selected Persona or required active
   Avatar binding is an invariant failure; do not fall back to an ID, another Persona, another
   surface's Avatar, or a client-supplied image.
7. Keep the identity view read-only; it does not alter preference, session, selected Persona, or
   authentication state.

**Acceptance:** app/com/org sign-out edit has no “Go to home”, Back points to its named Dashboard,
and Back leaves the session unchanged; logout still submits the existing mutation. Preference tests
cover authenticated -> `/dashboard` and unauthenticated -> `/`. Dashboard tests verify Persona
moniker, associated Avatar image, exact order, app/com/org boundary isolation, URL-parameter
non-substitution, no sensitive identifier display, and unchanged primary links.

### Phase 9 — Conditional www/Warp anomaly re-audit

1. Reproduce the supplied anomaly list against the post-rename, post-authentication-refactor local
   source and permitted test runtime. Do not access production logs as part of this plan.
2. Treat the prior SSO 422 as a hypothesis to reproduce. The approved independent Warp Jump RT
   namespace and key configuration is not by itself evidence of the root cause. Inspect
   issuer/audience/key/JWKS/return-policy boundaries; do not add a namespace-only regex or reuse an
   OIDC key.
3. Recheck preference-refresh 401, development Vite HMR CSP, and query-count observations. Change
   only a currently reproducible in-scope defect. For query count, capture a baseline and measured
   result before optimizing.
4. Record non-reproducing findings as re-audited/stale with the command and environment, not as
   silently fixed. Preserve useful immutable incident history.

## 6. Source request to workstream map

| Input | Consolidated destination |
| --- | --- |
| 01. Critical blocker decisions | Approved mappings and regional target in Sections 3.4 and 5; no re-decision |
| 02. GroupAvatarMembership and Avatar authority | Phase 5 |
| 03. Org Auth sign-in/sign-up | Phase 1 |
| 04. Base → Auth → Base primary authentication | Phase 1, reconciled with current result-finalization amendment |
| 05. Cross-Surface asymmetry findings | Phase 4, findings F1–F9 and F11–F15; F10/F15 remain deferred |
| 06. Avatar moniker lifecycle | Phase 6 |
| 07. Secret Credential / RecoveryPasscodes | Phase 7 |
| 08. Palm → Base → Auth → Base → Palm sign-out | Phase 4 |
| 09. www-jp anomaly re-audit | Phase 9 |
| 10. Monotonic Auth ceremonies / Turnstile | Phase 1 |
| 11. Final Base/Auth architecture | Phase 1; accepted ADR governs older wording |
| 12. OAuth authorize rate limit | Phase 3 |
| Additional. Side/Wide to Warp and independent Jump RT keys | Phase 2 |
| Additional. Authenticated UI and return navigation | Phase 8 |

## 7. Cross-cutting verification and evidence

The original plan preparation did not run checks. During implementation, re-read the current worktree
and repository rules before each affected slice. Preserve the pre-existing worktree edits observed at
preparation time; do not reset, clean, stash, or restore them. Record checks actually run in
`evidence/`.

Implementation acceptance includes, at minimum:

- `bin/rails zeitwerk:check` and route enumeration for each affected surface.
- Targeted controller/request/integration/service tests for each phase, followed by the full Rails
  suite when the required repository test services are available.
- JavaScript tests/checks when frontend code changes.
- Route/host contracts for app/com/org, all three TLDs, JP/US context where configured, sign-in,
  sign-out, Preference, Dashboard, and OAuth authorize behavior.
- BVA/EP for 5-minute TTL, five mismatch limit, URL/host/input formats, lifecycle expiry, and any
  bounded or classified public contract. Tests exercise public interfaces and do not invoke
  private methods through reflection or `send`.
- Concurrency, replay, stale-generation, authorization-denial, backend-outage, and cross-surface
  negative tests wherever the phase introduces those boundaries.
- A final internal-name inventory that proves Side/Wide Rails namespaces, paths, helper names,
  and old environment keys are gone. The report separately lists protected `side-*` protocol IDs,
  persisted `origin_surface="side"`, externally consumed MCP identity, and immutable historical
  records; those values are not silently renamed.
- A short `evidence/` record for completed meaningful verification, with the full HEAD hash and
  whether uncommitted work affected the result. Do not write evidence for checks not run.

At initial plan preparation, no test, Zeitwerk check, route command, migration, or application code
change had been run. Subsequent execution results belong in `evidence/` and the local issue draft.

### 7.1 Execution status and evidence boundary

The integrated implementation was already in progress when the critical review was attached. The
review is planning input; it neither erases existing local authorization nor certifies code. Current
commands and outcomes are recorded in the dated execution evidence. The local Rails suite completed;
the six Valkey-gated tests are recorded as skipped, not passed. Issue registration, real-data cutover,
and deployment remain external work.

### 7.2 Local execution snapshot (2026-09-25)

- The latest complete Rails suite run passed with 11,686 runs, 74,825 assertions, zero failures,
  zero errors, and eight skips, including the adjusted Warp SSO test and new app/com RecoverySecret
  regressions. The focused SSO test passed with one run and 39 assertions; the combined RecoverySecret
  request run passed with 13 runs and 164 assertions. Exact commands, outcomes, HEAD, and worktree
  state are recorded in
  `evidence/2026-09-25-integrated-auth-avatar-warp-H7J4.md`.
- `bin/rails zeitwerk:check`, route contracts, object-placement checks, changed frontend tests,
  Avatar moniker tests, and targeted preference/authentication tests passed. The test database
  reports the Avatar moniker migration as applied; no populated or production database was changed.
- The 14-item source map above remains intact. F10 billing/billings naming and the F15
  redirect-only shims remain deferred; the F1 `session_nonce` and pre-reveal top-up questions also
  remain the explicitly deferred design items described in Phase 4.
- Base Dashboard Persona name and navigation are locally implemented and tested. The associated
  Avatar image remains unimplemented because no approved authenticated delivery interface or
  absence/error contract exists. The plan keeps this acceptance condition open; no storage URL,
  placeholder, or replacement route was invented.
- The org selected-Avatar token field is already implemented by
  `db/org_tickets_migrate/20260924177000_add_selected_avatar_public_id_to_operator_tokens.rb`;
  focused org selector/switcher tests confirm persistence. Keep the established asymmetry: app
  requires/default-provisions an Avatar, org permits an optional selected Avatar without
  auto-provisioning, and com has no Avatar capability. This resolves the baseline field blocker; it
  does not define image delivery or authorize making com Avatar-capable.
- The full suite reports eight skips: six Base/Auth admission tests because `AUTH_STATE_REDIS_URL`
  is unset, one Flipper UI check because the engine is not mounted in this environment, and one
  branch-coverage probe for a nonexistent single-use-token model.
- The read-only route invariant verifies that GET/HEAD do not write authentication or preference
  database state. It does not establish session-cookie-free HTML rendering; the existing legacy CSRF
  strategy currently requires session-backed token behavior, so that narrower condition remains an
  explicit design gate rather than a weakened CSRF implementation.
- Production provider calls, production keys, regional US activation, GitHub registration, and
  real-data application/cutover were not performed. Those operations remain separately gated and do
  not block the verified local slices.

### 7.3 Continuation review and current residual boundary (2026-09-25)

- At the earlier 2026-09-25 continuation inventory, HEAD was
  `2b027d5b38989d3068e4620262bfa6c6fde8df41` and the shared worktree had 658 status entries (384
  modified, 152 deleted, 122 untracked). The subsequent follow-on inventory is recorded in the
  execution evidence. The worktree was already broadly dirty before this continuation; suite results
  include that tree and are not attributable only to this plan.
- A public request regression test exercises `GET /sign` plus a Rails-CSRF-protected `POST /sign`
  for Warp app/com/org. It verifies the configured Jump Gateway origin, single `rt` query
  parameter, surface issuer and key id, retained `side-*` client id, registered callback, and
  `ri=jp`. The latest focused run passed (1 run, 39 assertions). This is local test evidence, not a
  production log or deployment claim.
- RecoverySecret request tests now exercise concurrent app/com GETs with only one disclosure and a
  simulated response drop after server-side receipt consumption, followed by a retry that reveals
  nothing. HEAD and OPTIONS remain non-consuming on both surfaces. The combined focused run passed
  with 13 runs and 164 assertions; the full suite includes these tests.
- The application-wide residual search finds no old Side/Wide Rails namespace, module, source
  directory, route helper, or `PUBLIC_SIDE_*`/`PUBLIC_WIDE_*` key. Remaining current code matches
  are the rendered `SIDE` family label, three OIDC client display labels `Side App RP`, `Side Com RP`,
  and `Side Org RP`, and the `SIDE_*` JWT namespace mapping. They remain unchanged because they are
  user-facing/protocol identifiers rather than Rails internal names; protocol IDs, persisted values,
  and immutable historical records remain protected as listed in Sections 2.2 and 7. The OpenAPI
  route-coverage test inventory and local settings comments now use `warp` instead of the retired
  Rails `side` service name.
- Existing read-only GET contracts keep a presented invalid or stale preference refresh cookie at
  401 without clearing the cookie or writing preference/authentication state. The historical UX
  anomaly is not claimed fixed; changing this response would conflict with the accepted fail-closed
  preference contract absent a new decision.
- Current local Vite configuration did not establish the historical localhost HMR host condition;
  no browser-level HMR run or production log was available. Section 7.5 classifies this as
  inconclusive rather than treating a static configuration read as a runtime fix.
- The complete residual gate list and per-gate evidence, missing input, resume condition, and
  independent work are in the execution evidence. Local tests and implementation continue wherever
  they do not assert an unproved cross-database, live-provider, populated-data, regional-registration,
  or production-key guarantee.

### 7.4 Architecture documentation reconciliation (2026-09-25)

- Current DDS/SRS/HLD now describe the implemented Shrine storage modes and private-object policy.
  The Avatar delivery URL/API remains explicitly undecided. The earlier intended-functionality
  audit remains a historical snapshot with a current-state note; its original findings were not
  rewritten. The exact files and residual scan are recorded in the execution evidence.

### 7.5 www/Warp anomaly re-audit (2026-09-25)

| Finding | Classification | Current evidence and disposition |
| --- | --- | --- |
| A. SSO/Jump RT 422 | RESOLVED locally | The Warp app/com/org SSO request test issues a signed Jump RT to the configured gateway and preserves each `side-*` OIDC client ID. Unauthenticated Dashboard requests also produce a gateway redirect on all three surfaces. Adversarial checks found a remaining configuration failure path: missing signing keys were converted to `nil`, and `CommonRedirect` rescued every `ArgumentError` into the same 422 used for rejected URLs. The issuer now raises `JumpRtConfigurationError` for a missing active key/private key or unsupported issuer namespace; the broad rescue is removed. Tests cover missing-key behavior on app/com/org, key ID and key material absence, unsupported controller/namespace, and malformed-query rejection. Production logs were unavailable, so this is a local result only. |
| B. Preference refresh on HTML GET | PARTIALLY_RESOLVED | A malformed refresh cookie on `www-jp.umaxica.com/` still returns 401, matching the current fail-closed, read-only GET contract. It is retained rather than silently cleared or used to create a Preference. The request test confirms no cookie clearing or Preference/authentication write. The historical clear-cookie-and-recover sequence is no longer the current behavior. |
| C. Vite HMR CSP | INCONCLUSIVE | Current development runtime reports Vite host `0.0.0.0`, origin `http://0.0.0.0:3036`, port `3036`, `skip_proxy=false`, and no asset host. `vite.config.ts` does not set `server.hmr.host`; development CSP still builds WebSocket sources from the request host. No browser/DevTools runtime or current production logs were available to determine the actual HMR WebSocket host. No configuration change was made. The CSP adds those WebSocket sources only when `Rails.env.development?`; test/production do not receive them from this branch. |
| Historical 84-query Preference creation after GET | NOT_REPRODUCIBLE | A local Rack request measurement to `www-jp.umaxica.com` used the isolated Rails test database and an in-process MemoryStore only for the unrelated rate limiter. Invalid refresh cookie: 401, 1 SQL query, 0 SQL writes. The clean follow-up GET: 200, 0 SQL queries, 0 SQL writes. Under the current contract, that GET does not create a Preference, so the former 84-query GET creation path is absent. This does not measure the cost of an explicit Preference write mutation. |

No production logs, live OIDC registrations, production key material, browser HMR session, or real
Valkey service was used for this re-audit. The invalid-cookie classification is separate from the
84-query observation: the 401 remains reproducible by design, while the subsequent GET-side
creation and its query count do not.

### 7.6 Avatar owner-membership revocation ordering (2026-09-25)

Adversarial review found a time-of-check/time-of-use gap: an app or org owner membership could be
revoked after an unlocked permission check but before the corresponding write to the separate Avatar
database. A second gap allowed Principal lifecycle changes to race the same mutation. The affected
code now opens one transaction on the surface's canonical Zenith connection owner, locks and
revalidates the authenticated Client/Operator row, then resolves the permission under `FOR UPDATE`
on its owner-membership row. It holds both locks until the Avatar-database mutation returns. The
verified Rails connection configuration places Client/PersonaMembership under `AppZenithRecord` and
Operator/AgentMembership under `OrgZenithRecord`, so each surface check uses one surface database
transaction. No authority database rows are written and no distributed write transaction is added.

The shared lock service is used by Avatar provisioning, owner moniker changes, Group create/update/
archive, Group Avatar attach/detach/reorder, and transfer request/accept/cancel. Mutations that depend
on an observed Avatar or Group owner also lock and revalidate the current ownership period inside the
Avatar transaction. App Avatar and Group/Group Avatar Membership controllers map a lock-time
authorization denial to HTTP 403.

Regression coverage now includes app and org Group creation racing independent connections that
downgrade owner Memberships or change Principal status, an admin-locked Principal denial, a public app
Avatar-create request that changes Membership after policy authorization, and a public Group-create
request that does the same. The request cases verify the locked recheck and the 403 response without
partial Avatar/Group rows. These PostgreSQL-backed tests are **written but not executed in this
continuation**: the configured test host `primary` has no DNS result or accepting server, no
PostgreSQL process is available, and Docker is absent. Ruby syntax, targeted RuboCop, and Zeitwerk
checks pass. The global Avatar-mutation gate remains open until these database-backed regressions
run; this local ordering contract does not claim distributed transaction atomicity under database
failure.

| Blocked operation | Concrete evidence | Missing input | Resume condition | Independent work |
| --- | --- | --- | --- | --- |
| Run the new Avatar owner/principal authorization regressions | `test/controllers/base/app/avatars_controller_test.rb`, `test/controllers/base/app/groups_controller_test.rb`, `test/services/group_management_test.rb`, and `test/operations/avatar_ownership_transfers_concurrency_test.rb`; the focused Rails command fails during `maintain_test_schema!` with `ActiveRecord::DatabaseConnectionError` for `primary`. `getent hosts primary` returns no address, `pg_isready -h primary` reports no response, no PostgreSQL process is present, and Docker is unavailable. | Reachable PostgreSQL test databases for the existing configured Rails test topology. | Restore that test service and rerun the exact focused command; report the resulting Minitest totals. | The principal/membership lock implementation, request/controller mapping, app/org cases, 484-file Ruby syntax check, targeted RuboCop, connection-owner inspection, Zeitwerk, and diff checks proceeded locally. |

## 8. Explicit non-goals and later gates

- No production deployment, production data access/change, provider/Cloudflare changes, external
  OIDC registration, secret/key generation, GitHub issue/PR creation, or external communication.
- No changes to the public `www-*` FQDNs, existing URL paths due to the Warp rename, OIDC client IDs,
  cookie/session contracts, token claims, or persisted `origin_surface` values.
- No regional client activation until every exact canonical host, audience, redirect/logout/
  backchannel URI, key namespace, and RP-session binding exists and passes the registration gate.
- No family-wide owner cutover until reviewed data disposition, all consumer switches, zero unresolved
  authority-required rows, and forward-only recovery evidence pass.
- No production data reset or irreversible schema/data operation without its explicit risk and
  recovery approval. Any local migration/data reset must have a bounded dataset and recorded recovery
  method.
- No unrelated route naming cleanup, redirect-shim retirement, authentication-policy redesign,
  generic UI framework, or cross-surface controller/concern consolidation.

## 9. Planning exit criteria

The plan is internally ordered for local implementation. It does **not** claim that every downstream
operation is unblocked: Section 3.5 names the gates and their exact scope. The implementation issue
derived from this plan MUST retain the named Base `/dashboard` route, because the requested return
contract distinguishes authenticated Dashboard from unauthenticated home and current Base has no
such route. The residual policy is fixed: Rails/internal names move to Warp while the explicitly
protected OIDC, MCP, and persisted `side` identifiers remain. No phase may bypass a gate by guessing
data, configuration, keys, or authorization state.
