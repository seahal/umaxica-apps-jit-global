# UMAXICA — Feature Re-audit and Revised Plan

## Current verdict — NO-GO / planning only

This is the operative status for the current request. The available evidence does **not** justify
freezing or authorizing one autonomous implementation run across all 95 requirements. This is not a
rejection of the accepted Base/Auth authority boundary, and it does not claim every static risk has
been reproduced at a public boundary.

The blocking gates are: unverified end-to-end `auth_time` and `max_age` behavior; unverified
authorization-code replay owner-binding in Ruby and Lua; unverified cross-store partial-failure
outcomes; unverified DPoP consumption/retry behavior under the actual client policy; unresolved
Base-local/direct-entry UX and authority flow; unproven isolation of Rails test PostgreSQL, Valkey
and outbound provider traffic; and incomplete confidence in the REQ-to-step mapping until checked
mechanically against the full source requirements. Independent phases may be planned and
investigated; only dependent execution slices are blocked. The detailed evidence, counter-tests,
95-row traceability report and proposed gated sequence are preserved in
[the full re-audit record](notes/implementation/2026-09-14-refactor-plan-history.md#1-executive-verdict).

This run is **planning only**. Do not implement, migrate, change routes/configuration/ADRs/tests, or
continue into the preserved execution draft below. In particular, its former D-ENTRY selection is
not the current decision: direct-entry UX remains unresolved. The draft remains below for provenance
and must not be treated as current execution authority. Any implementation requires a separate
explicit authorization after the stated decisions and environment gates are resolved.

## Preserved bounded-execution draft — inactive under the current NO-GO

The following E0–E10 text records a prior proposed execution cycle. Its recorded GO and D-ENTRY
choice are superseded by the current planning-only instruction and the NO-GO decision above. Any
“Done” or “implemented” wording within that draft is historical text, not verification performed for
this re-audit. Preserve it as historical material; do not execute it in this run.

Cycle: 2026-09-15 / prior execution revision Repository: seahal/umaxica-apps-jit-global Reference
branch / HEAD: feature / 430ac354ba06c9d22885e1e69d027a7a1b1d5280 Decision recorded at that time: GO
for bounded local implementation; inactive under the current planning-only NO-GO. Execution mode
recorded at that time: Implement the in-scope work, verify it, and record remaining findings in
misc.md.

1. What that prior draft decided

That revision was written in response to a separate instruction to finish the plan and proceed with
bounded implementation. The current explicit planning-only request replaces that execution
authority. The details below are retained as a prior proposed plan, not current instructions.

The accompanying Goal instruction authorizes local application/test/configuration/ADR/document
changes within this scope. GitHub remains READ ONLY. No push, PR, issue/comment, release, tag,
remote setting, deployment, external account change, or live-provider write is authorized. Preserve
unrelated local changes. Local commits are permitted only for verified, isolated steps under the
repository rules; they are not permission to publish.

The 95-row ledger in Appendix A is the accepted execution ledger for this cycle under the latest
user instruction. It supplies the operative requirement text, primary owners and acceptance
references for REQ-001–094; missing earlier attachment files do not return those rows to
BLOCKED_SOURCE. The unavailable original ORG fragment behind REQ-095 alone remains unguessed and
deferred. Supplied digests are input identifiers and were not independently re-hashed in this
workspace.

Completion is evidence-based. A discovered question is not a whole-project stop. A required control
that remains broken is not silently renamed “next-cycle work,” either. Complete all safe, in-scope
slices; contain or isolate an unsafe slice; continue independent work; report exact residual status
without calling incomplete verification a pass. 1.1 File placement and preservation

Determine paths once at startup and record them as PLAN_PATH and MEMO_PATH:

    If repository-root refactor.md is a regular file, use it as PLAN_PATH. Retain the old report in a dated, English implementation note before replacing it; do not discard user content.

    If refactor.md is actually a directory, leave it a directory and use refactor.md/implementation-plan.md. Do not delete or convert it to obtain a preferred name.

    Use repository-root misc.md as MEMO_PATH. Create it if absent; append/merge by finding ID if it already exists. Never truncate it. If that path is also a directory, use misc.md/implementation-notes.md and record the resolved path.

    Do not follow a symlink outside the workspace or overwrite an unexplained non-regular target. Use a non-conflicting regular Markdown file inside the workspace and record that technical placement decision.

    Preserve the full requirement ledger while updating progress. Do not replace this plan with a terse completion claim or a new 95-row BLOCKED_SOURCE table.

    The ZIP's sources/ files are reference inputs, not instructions to commit historical Japanese reports into the English repository. Do not place the ZIP, raw logs, JSON dumps, or source copies in evidence/.

1.2 Scope of investigation versus implementation

The earlier authoring and read-only audit records are preserved in
notes/implementation/2026-09-14-refactor-plan-history.md. They are provenance only, not current
runtime proof. This implementation run must recheck current HEAD, worktree and service targets.
GitHub remains read-only.

Do not reset to the reference SHA if local HEAD has moved. Record actual HEAD and existing diffs,
inspect only relevant intervening changes, and implement on the current authorized worktree.
Previously completed behavior must be verified and retained, not implemented twice. 2. Resolved
NO-GO reasons Previous reason Final disposition for this cycle Original plan / Sol attachment files
unavailable in this workspace The latest user instruction adopts the 95-row Appendix A as the
operative ledger for REQ-001–094; do not block those rows on the missing files. The REQ-095 ORG
fragment remains deferred. Supplied SHA-256 strings are not treated as re-verified bytes. Unknown
refactor.md file/directory or existing misc.md Use the non-destructive path resolution in §1.1. No
user clarification required. Direct Auth entry product decision Adopt D-ENTRY in §3. It is this
cycle's explicit implementation choice, not a claim that the old report had already decided it. Test
URLs may point at development services E0 must prove or construct safe, disposable test targets
before any mutating runtime command. This is enabling implementation work, not a reason to stop
static or independent work. [S3 §2.8] Replay, partial failure, expiry not dynamically reproduced
Reproduction and negative tests belong inside E1/E7. Lack of a pre-existing proof is not a separate
approval gate. GUID net OpenAPI ownership unclear Describe the existing GUID host/route as a
separate public identifier surface in the current contract registry. Do not invent a new deployment
or host. A genuinely missing persistence owner blocks only that persistence slice, not all route
work. DPoP/DBSC physical interoperability absent Complete current protocol/runtime automation; keep
real-device and deployment validation explicit in misc.md. No unsupported rollout claims. Full suite
/ coverage not yet green Capture attributable baseline and repair necessary in-scope failures. Only
broad private-test deletion/visibility cleanup requires a green baseline first. Unexpected abstract
design or performance question Record evidence, containment, and next-cycle investigation in
misc.md; continue unless the current slice would cross a hard safety boundary.

Mapping correction: REQ-064 is the one-Valkey/six-logical-DB, structured-access, hiredis, and
test-namespace requirement. Its primary owner here is E0, with E4/E5 regression checks as
applicable. It is not a DPoP requirement. REQ-020 is owned for closure by E10 and applies
horizontally to every phase. REQ-055/056 stay with ORG authentication in E3. These corrections
follow the recovered ledger, not the repeated mapping error in the latest report. [S1 §3; S3 §9] 3.
Decisions fixed for this execution cycle D-ENTRY — Base-admitted local sign-in, without a fake RP

The source shows an admission-less Auth entry bridging to Base root, while the anonymous Base root
points back to admission-less Auth links. This is a static navigation finding, not a newly
reproduced browser incident. Merely retaining both links does not implement Base-local
authentication. [H2, H3]

Use this complete contract:

    Base owns admission and final authentication. Auth root remains a public ceremony entry, not an authenticated dashboard or an RP. An admission-less Auth sign-in/sign-up selector navigates to the same realm's Base root/entry using existing Jump caller helpers. Only an allowlisted sign_in/sign_up display intent and validated ri may be carried; arbitrary return URLs are not accepted.

    Base root starts the local flow. For an anonymous browser, its sign-in/sign-up controls target a Base-owned admission entry, not the raw Auth selector again. Reuse an existing suitable Base-local admission resource. If none exists, add a minimal Base::<App|Com|Org>::Sign::AdmissionsController with namespace :sign / singular resource :admission, using standard actions (new, create, and the narrowly scoped result action required by the chosen existing return transport). Do not reuse retired Base RP callback endpoints.

    The ordinary entry GET renders the choice/form. Admission initiation uses the normal CSRF-protected form/PRG contract. Base checks current login state, allowed purpose, realm, signup policy and browser continuity, records a local transaction, and issues the existing type of short-lived opaque handoff. It reaches Auth through the existing Jump integration. Do not implement a GET that directly creates a logged-in identity session.

    A valid RP request keeps its actual client, exact redirect URI, state, nonce, PKCE, requested freshness and purpose in its Base transaction. A local request has no fabricated client ID, redirect URI, state/nonce for a fictitious RP, authorization code, ID Token for a fictitious RP, or RP Session. Do not relax OIDC transaction validation merely to fit local requests. Use explicit local/RP transaction types within the existing actor-separated design; no generic polymorphic/STI auth_flows framework.

    Auth accepts only a valid purpose/realm/browser-bound handoff or continuation tied to it. It may keep actor-specific opaque ceremony state and __Host-auth_sid, verify credentials, and record evidence. Those artifacts never constitute Base login proof. A raw login-challenge string or ceremony cookie by itself is not sufficient admission.

    Auth returns a one-time evidence result. Base validates the originating browser binding as well as the result, expected actor for reauthentication/linking, realm, intent, mode, expiration, unused state, and policy. Only Base accepts account/session creation and final assurance. Result possession alone must not support login CSRF or account substitution. Preserve legitimate credential-verification side effects such as counters without turning them into authority grants.

    Reuse the safe existing Base result transport where it fits. A protocol return action is a narrowly documented authentication callback, not a generic state-changing GET exemption. If a new local return cannot safely use that contract, its GET renders a same-origin confirmation and a CSRF-protected POST/PATCH performs consumption and session establishment. Never solve cross-origin submission by disabling CSRF checks. No arbitrary authenticated action is performed merely by following a GET link.

    Local success ends at the same realm's Base root, preserving validated ri; the existing authenticated root/selection/authorization guards apply. RP success resumes only the stored, validated RP transaction and returns through its exact callback/Jump path. Step-Up/linking returns to its specific Base-authorized operation, not an arbitrary destination.

    An already-authenticated browser does not start another ordinary sign-in/sign-up. Its direct entry resolves to Base root without another session; crafted initiation is rejected through the existing explicit conflict/error contract. A Base-authorized reauthentication requested by valid prompt/max_age is a different purpose, bound to the current actor/session, not a back door around this rule. Normal/Emergency context cannot be switched within one session.

    Admission/result/callback pages are non-cacheable, avoid referrer leakage, and never log raw codes, OTPs, cookies or tokens. Invalid/expired/replayed/wrong-purpose/wrong-realm material has no new identity/session/token side effect. Offer an explicit restart from Base; do not silently fall back to a different workflow.

This decision fixes the functional entry/completion contract for this cycle. Further visual polish,
provider-order preferences, and alternative entry UX belong in misc.md; they do not reopen the
authority boundary mid-run. D-AUTHORITY — Preserve established trust boundaries

Base is the sole physical IdP/AS. Auth is not an RP. Keep exactly core-app, core-com, core-org,
side-app, side-com, side-org, edit-org as the seven first-party browser RPs; Palm's native/API
contract is separate. Keep app/com/org state and policy isolated. Shared primitives do not mean
shared identities, credentials, client keys, cookie scope, or mutable configuration. [S1
REQ-007–009, 028–032, 057–065]

Retain the Auth JWKS endpoint and signing dependencies needed by Jump. Remove only proven legacy RP
dependencies, not every JWKS reference. Do not modify the Jump application, its deployment, or its
protocol. For cross-host navigation changed in this cycle, use the existing supported
caller/return-verification contract; do not invent new Jump capabilities. D-ASSURANCE — Honest
timestamps and context, not a new assurance policy

Record a server-observed credential-verification event once, bind it to the admitted transaction,
and have Base explicitly accept that evidence. Preserve its event time as auth_time; do not
substitute result-consumption time. Base session start, code issued_at, JWT iat, and AR metadata
remain distinct. Missing trustworthy history requires explicit reauthentication or a
non-authenticating failure, not a now/created_at compatibility fallback.

Base derives the accepted acr, actual amr, and explicit normal/emergency context. Do not set AAL2
merely because the method is named MFA, SecretKey, SMS, or Step-Up. Preserve existing SMS acceptance
and fresh Step-Up for existing-account Google/Apple linking and unlinking. Deep AAL/FAL design
remains follow-up work. [S1 REQ-011–015, 070–072] D-REVOCATION — No new online JWT lookup

Keep the accepted residual lifetime of already-issued short-lived Access JWTs after revocation. Stop
future refresh/new issuance at the correct session/family boundary. Do not add per-request
RP-session DB lookup, introspection, denylist dependency, or a new blanket revocation policy.
Planned absolute expiry still bounds issued token lifetimes; an earlier revoke does not
retroactively alter signed exp. Keep existing skew/leeway handling explicit. [S1 REQ-015, 062, 081]
D-DPOP — Conservative compatible rollout

Preserve existing per-client Bearer/DPoP policy while fixing protocol defects. Do not newly require
DPoP for every browser/native client based only on server unit tests. AS nonce is optional; if
elected, its challenge and retry contract must work. DBSC remains progressive enhancement with an
explicit unsupported-browser path. Do not disable an established sender constraint as a fallback for
a failed proof. Device validation debt is not deployment approval. [S1 REQ-016–019; N3] D-GUID —
Minimal existing-surface resolver

Keep the current configured GUID host and /api/v0/resources/<opaque-id> surface; no DNS/hostname
renaming in this cycle. eid is the stored opaque business key. Default Rails :id may carry that
value without exposing a numeric PK or changing the URL shape; update controller/helpers/OpenAPI
together. HTML and JSON use one exact lookup. Add only the specified persistence and safe
representation, not another generator, public registration API, redirect, or duplicate top-level
route. Document the existing net identifier surface explicitly rather than exempting it. [S1
REQ-021–027, 033–040] D-QUALITY — Measure without moving the gates

Keep current SimpleCov/Vitest configuration and thresholds. Historical failed-run 98.56% line
coverage is not an adopted new minimum. Capture the current successful baseline using actual
coverage commands; evaluate configured global/file/group/max-drop gates and explain
measurement-population changes. Never claim an ordinary test run proves coverage. Do not weaken
assertions, exclusions, skips, architecture rules, or protocol checks to obtain green. [S1 §13; S3
§13] D-DEBT — Finish the bounded cycle, retain new questions

New abstract design, performance, potential-vulnerability and validation issues are first-class
findings in misc.md, not invitations to expand this run indefinitely. “Potential” remains potential
until supported; “known required fix” stays required. Deferral is not risk acceptance and is never
evidence that a route is safe to deploy. 4. Execution workflow and dependencies

Read AGENTS.md and only the applicable indexed rules. Use the actual repository entry points; do not
invent test commands or install speculative infrastructure. Repository prose, comments, test names
and memos are English; localization remains in the relevant locales. No new included do/prepended
do, broad rescue, silent environment fallback, or test-only application behavior. [H4] Phase Goal
Dependency for final runtime verification E0 Safe execution environment, source/state snapshot,
attributable baseline None E1 Authorization-code ownership, atomic consumption, cross-store failure
safety E0 E2 Base/Auth admission and authority cutover, including local entry E0 E3 Auth
event/freshness/assurance and ORG methods E1, E2 E4 Shared seven-RP mechanics, session hierarchy and
administration E1, E2, E3 E5 DPoP/DBSC automation and explicit validation debt E1, E3, E4 E6
OTP/Turnstile/email, social Step-Up, sign-out cookies, inert Create UI E0 for local UI/verification
work; E2/E3 for final auth flows E7 /sessions, Activities, preferences and absolute expiry E3, E4 E8
Routes/root/API/OpenAPI/GUID convergence E0 for inventory/GUID; E2/E4/E6/E7 for final integrated
inventory E9 Repository-wide semantic timestamp/private-test/visibility cleanup E0 green-baseline
gate; targeted edits use completed affected boundaries E10 Final verification, documentation, ledger
and memo closure All attempted phases and explicit residual dispositions

Suggested single-writer order: E0 → E1 → E2 → E3 → E4 → E5 → E6 → E7 → E8 → E9 → E10. Small E6 work
may run earlier when independent. Dependencies concern semantic integration and validation, not a
prohibition on independent static work. Do not let concurrent agents write the same files, index,
migrations or worktree. Do not require another agent or another full planning cycle to close a
phase.

Per slice: inspect current behavior → add a public/contract RED test → make the smallest coherent
change → GREEN → refactor → affected regression checks → record evidence and findings → isolate
local commit when authorized. If a required behavior already exists, prove it instead of changing
it. If runtime tests are unavailable, label the slice IMPLEMENTED_UNVERIFIED and do not claim GREEN.

Use these progress states only: PENDING, IN_PROGRESS, VERIFIED, IMPLEMENTED_UNVERIFIED,
ALREADY_SATISFIED_VERIFIED, DEFERRED_VALIDATION, DEFERRED_FINDING, BLOCKED_SLICE,
SUPERSEDED_PROCESS. A current requirement may be deferred only under the bounded rules below and
with its reason, owner, containment and next action visible. Report it as incomplete, not
satisfied. 5. Phase specifications and acceptance tests E0 — Safe environment and baseline

Inspect first: config/database.yml, all multi-DB ancestors/roles, config/ci.rb, test/test_helper.rb,
Valkey connection/bootstrap code, test namespace/cleanup, .simplecov, vitest.config.ts, package
scripts and the accepted non-production topology ADR. The previous report's environment observation
is historical; re-evaluate effective test configuration after all environment-loading rules. [S3
§§2, 12, 13]

E0-T1 — Isolation proof. Before Rails boot that can touch services, fixtures, db:prepare, CI, a
server, or failure injection, identify every PostgreSQL database/role/credential target and every
Valkey database/namespace/connection used by test, including jobs, cache, rate limits and auth
state. Resolve explicit test settings; inspect safe target identity without printing secrets. /5
instead of /2, a host containing “test,” or RAILS_ENV=test alone is not proof. Logical DB indexes
are not access-control boundaries. Prove that the run cannot mutate shared development/production
state; use a dedicated disposable instance, or test-only databases/credentials plus strictly scoped
cleanup on the accepted isolated test service. Verify all relevant background work and HTTP egress
are stubbed/disabled by the existing test harness.

Create or initialize new disposable test-only resources through the existing supported local setup
when available, without publishing datastore ports to the host, changing shared .env, editing
external infrastructure, or dropping/resetting an existing database. This authorizes setup of an
empty isolated test target, not destruction of existing data. No shared-service fallback, FLUSHDB,
FLUSHALL, or broad key deletion. Keep one-Valkey/six-logical-DB topology as the accepted
non-production configuration; do not redesign deployments to obtain a green test. Fix an actual
test-configuration defect explicitly and add a configuration contract regression.

E0-T2 — Baseline. Record HEAD, staged/unstaged/untracked paths, resolved plan/memo paths,
command/exit status, Rails counts/skips/reasons, ordinary JS results, explicit Ruby/JS coverage,
static/security results. Protect unrelated user changes. Inspect bin/ci before it prepares
databases. Capture the current suite once as attributable baseline; do not keep repeating the same
environmental failure.

E0-T3 — Driver/concurrency. Verify selected hiredis transport through the actual connection layer,
per-worker/per-run namespace isolation, and bounded cleanup on real isolated Valkey. Do not
substitute an in-memory mock for Lua/concurrency guarantees. PostgreSQL constraint/race tests use
the real disposable database. Use repository-selected worker settings; do not copy arbitrary
concurrency values from an old report.

If isolation cannot be established, record precise missing capability and prohibited target, stop
only mutating runtime operations, and continue safe static work, source/test preparation and
documentation. Do not remove security tests or broaden test-only production branches. Broad
destructive test cleanup in E9 remains gated; no “all tests passed” claim is allowed. E1 —
Authorization-code exchange and cross-store failure safety

Likely touchpoints: app/services/oidc_token_exchange_coordinator.rb,
app/services/valkey/auth_state/authorization_code_store.rb, the public token endpoint concern,
corresponding service/store/request tests and existing revokers. [S2 B/C; S3 ADV-003–005]

E1-T1 — Binding before side effects. With valid same-realm client A and client B, exchange A's code
successfully. Present A's consumed code using B's independently valid client authentication. Assert
failure and unchanged A/B/unrelated RP Sessions, refresh families and Base session. Also test wrong
redirect, wrong/missing PKCE, wrong realm, expired/corrupt code and valid same-owner replay. Use
fresh client-assertion JTIs and fresh DPoP proofs unless that exact replay is under test, so an
earlier unrelated guard cannot make the test vacuously pass. Revocation must target the correctly
linked issuance/session/family, not a broad “current session for this client” lookup.

Fix both Ruby and Lua binding/order checks, including an issued→consumed race between read and
atomic consume. Retain sufficient non-secret tombstone binding metadata to evaluate the contract.
Never remove valid same-owner replay denial/revocation merely to stop a cross-client side effect.
RFC 6749 requires code reuse denial and binds the code to client/redirect; the tighter side-effect
assertions here are project tests. [N2]

E1-T2 — One-time and pending-replay races. Concurrent valid consumption has one successful
authorization-code redemption. Test replay while the first exchange is between consume, DB mutation,
family link and commit. A replay revocation request must not disappear because a family reference
has not yet been linked, nor let an in-flight issuer later produce success after it should have been
fenced. Existing protocol errors and owner-scoped revocation semantics remain explicit. Do not
introduce code reuse grace; this is not the separate refresh-token race policy.

E1-T3 — Required family-link outcome. Handle the actual linked/missing/invalid_state outcomes and
Valkey exceptions explicitly. Only a positively established required link permits issuance success.
Record an owner- and generation-bound operation correlation using the smallest existing compatible
mechanism. PostgreSQL transactions and Valkey scripts do not form a distributed transaction; do not
claim exactly-once end-to-end delivery. Avoid broad rescue-and-continue. Failure injection Required
outcome / observation Before code consume No new token/session mutation; follow the specific
proof/client-error retry contract. Consume timeout or ambiguous result Never restore the code to
issued. No success without confirmed state; a new authorization is the safe restart. Consumed; link
exception / missing / invalid_state No successful token response. Inspect DB session/generation and
tombstone; apply explicit forward repair/containment, not invisible rollback assumptions. Link
acknowledged; signing or DB commit fails No success. Stale link is harmless, owner/generation-bound
and accounted for. A delayed repair cannot revoke a later unrelated successful generation.
Same-owner replay during pending issuance Retain/fence the revocation decision until linkage/commit
resolution; no missing-reference no-op that loses security state. DB committed; HTTP response lost
Do not resend tokens under an already-consumed code or reopen it. Follow the documented
fresh-authorization restart; contain superseded/orphaned issuance at its own boundary.
Cleanup/compensation also fails Preserve durable correlation where possible, fail closed, produce a
sanitized actionable failure, and leave a high-priority deployment-blocking finding. Logs alone are
not the authoritative security record.

Use per-operation/generation fencing and existing store/DB primitives where sufficient. If a small
durable exchange record or outbox is necessary, keep it narrowly typed and actor/DB-owned; do not
build a general distributed-workflow framework. Failure recovery may reduce availability; it must
not authenticate an unbound client or make an uncertain consumed code reusable. Unavailable
real-cluster failover/load validation is a follow-up finding, not evidence that injected tests cover
all outages.

E1-T4 — DPoP preflight boundary. Establish client and request/proof validity before irreversible
consumption when compatible with the protocol. If nonce is required, return the correct challenge
before consumption so a valid nonce retry can succeed; verify the actual response headers/error.
Ordinary invalid proofs may require a fresh authorization according to the explicit contract; do not
promise unrestricted retries. Keep proof-JTI consumption distinct from authorization-code
consumption. Full DPoP work continues in E5.

Done: Public endpoint and real-store tests prove binding, one-use behavior and explicit
partial-failure outcomes. A source reorder alone is insufficient. E2 — Base/Auth authority and
local-entry completion

Likely touchpoints: Auth admission/controller inheritance, AuthenticationSessionCommitter, current
AuthenticationBase callers, Base admission/authorization coordinators and transaction models,
Base/Auth roots, per-surface request/ceremony tests. [H2/H3; S2 D; S3 ADV-006]

Implement D-ENTRY and D-AUTHORITY. First enumerate all reachable app/com/org credential and
continuation paths, including direct and RP-originated sign-in, signup, social callbacks/linking,
Step-Up, Entra, SecretKey, Emergency and sign-out. Inspect inherited callbacks, not just leaf
includes. Do not globally rewrite every log_in call without classifying its actual surface and
purpose.

E2-T1 — Admission matrix. For each relevant surface/purpose, test absent, valid, expired, replayed,
wrong-purpose, wrong-actor, wrong-browser and wrong-realm handoff/continuation/result. Inspect
emitted cookies, root and RP-session rows, ceremony records and authorization side effects. Mutating
credential endpoints cannot be reached just by bypassing the selector or carrying a stale
login-challenge string.

E2-T2 — Two complete flows. (a) Anonymous Base local entry → Auth ceremony → Base acceptance → Base
root, with no fake RP artifacts. (b) actual RP → Base → Auth → Base → validated RP callback. Test
no-admission Auth navigation and prove it no longer produces a Base↔Auth link loop. Test signup
policy and local/actual-RP distinction. Base performs final identity/account/session acceptance;
Auth temporary registration/evidence is not independent account authority.

E2-T3 — Session ownership and concurrency. Preserve session fixation prevention, host-only cookie
scope, lifetime/idle/session-limit checks, actor lock and first-completed-wins browser concurrency.
No unconditional bootstrap_actor: true to bypass limits for ordinary sign-in. Preserve only
deliberate transaction continuity across rotation. An already-authenticated normal entry does not
create another session. Reauth/link/Step-Up is explicitly bound to the current actor and authorized
purpose.

E2-T4 — Legacy retirement. Remove directly dependent Auth RP callback/config/state-exchange/logout
paths and stale tests only after replacement boundary tests exist. Keep allowed ceremony state,
social-provider callback contracts, active Jump signing/JWKS/return verification and valid
credential-management continuations. Separate cookie detachment from server authority revocation.
Update the affected ADR/route map instead of leaving contradictory active claims.

Done: Auth has no independent Base/RP identity-session/token/final-assurance authority, local
sign-in is usable, and each realm's request tests demonstrate the distinction. New UX alternatives
go into misc.md, not another entry-policy gate. E3 — Authentication event, freshness and ORG methods

Likely touchpoints: OidcAuthorizationCodeIssuer, ConsumedCode, exchange/refresh issuers, Base
authorization parameter allow-lists and transactions, RP request builders/validators, event/session
fields, ORG selector/SecretKey/Entra/Emergency concerns and tests. [S2 A; S3 ADV-001/002; S1
REQ-051–056]

E3-T1 — T0/T1/T2. Authenticate at T0, issue code at T1, exchange at T2 with T0<T1<T2. The accepted
authentication event remains T0 in the ID Token and the project's Access JWT contract; issuance iat
is separate. Test refresh and repeated authorization without fresh authentication, actual
reauthentication with a new accepted event, absent/untrustworthy history and clock-boundary
handling. Remove the ConsumedCode#created_at detour and the issuance-time fallback rather than
merely fixing one assignment.

E3-T2 — Freshness end to end. Preserve max_age/prompt from RP construction through Base parsing,
transaction persistence, resumed authorization, final claim and RP validation. OIDC defines
auth_time as authentication time, requires it in an ID Token when max_age is used, treats max_age=0
like prompt=login, and forbids UI under prompt=none. Apply these as protocol constraints, not as
product Step-Up equivalence. [N1]

Test: sufficiently recent and stale sessions; boundary age; max_age=0; prompt=login; prompt=none
with/without a sufficient session; incompatible prompt combination; malformed/non-scalar/negative
maximum age; parameter loss across Auth return. Return the appropriate OIDC error only to a
validated client redirect; no redirect to an unvalidated URI. A guest-only ordinary login guard must
not accidentally prevent legitimate Base-authorized same-actor reauthentication.

E3-T3 — Assurance and mode survive all boundaries. Trace acr, full actual amr, accepted event time
and explicit authentication context through evidence, Base, code, RP issue/refresh and DBSC renewal.
Test Emergency→Base→RP→refresh stays Emergency and cannot Step-Up or gain normal write authority.
Missing/unknown context in newly issued org credentials is not silently normal. Distinguish
session-limit restriction from Emergency context. Do not auto-upgrade assurance from an event name
or change accepted SMS policy.

E3-T4 — Three ORG entries actually work. Keep Entra single-tenant/pre-provisioned/no-JIT controls.
Implement the explicitly requested independent normal SecretKey entry, not just a link to an
Entra-only second stage. Use the existing canonical Operator public identifier as locator when the
credential has no self-contained owner locator; normalize it once and bind verification to that
owner. Do not expose numeric IDs, weaken the verifier, fake an Entra-completed transaction, or let a
submitted identity overwrite a server-bound actor. Preserve CSRF/Turnstile/rate
limits/lockout/enumeration defenses. Preserve the existing genuine Entra second-stage flow where
used.

Emergency remains the separate identifier+Passkey restricted path, not an automatic normal fallback.
Block normal↔emergency conversion within an existing session; require proper sign-out and a new
sign-in. Show signup only where the actual org provisioning policy permits it. Locale, branding,
host and policy tests cover all visible controls and targets.

Done: Timestamp and freshness assertions are values/behavior assertions, not mere claim-presence
checks; ORG method entries complete the right admitted flow without weakening existing safeguards.
E4 — Shared RP/session hierarchy

Reuse existing RP/session/store abstractions. The source already reports
ClientRpSession/VisitorRpSession/OperatorRpSession; do not repeat a completed TokenUsage rename.
Keep seven independent client IDs/keys/registry entries; shared Edit/Core/Side mechanics accept
explicit immutable boundary configuration and support multiple Core/Side deployments. [S1 §§2,
11.G3]

E4-T1: A reusable request/contract suite covers state, nonce, PKCE S256, exact redirect,
issuer/audience/type/signature/ES384, wrong realm, callback replay/error, session fixation/rotation
and logout. Run it for all seven identities, including Edit. Host-only short-lived encrypted RP
browser transactions support competing tabs without silent overwrite; return targets are validated
local targets. Do not send provider traffic live.

E4-T2: PostgreSQL assertion-JTI uniqueness and active (Base session, RP client) uniqueness survive
races. Test Identity → Base Browser Session → RP Session ownership and selective versus parent
revocation. Regular Access-JWT requests must not gain RP-session DB queries; normal identity/policy
queries are not falsely described as “zero database access.”

E4-T3: Admin UI/API distinguishes registered client configuration from an individual's active RP
session. Owner/realm authorization and stable public identifiers remain; user-facing pages need not
expose internal registry/Binding fields.

Done: Edit uses the same protocol primitives; Core/Side regressions pass; no Auth RP is restored.
Native/Palm policy not inferable from the browser registry is classified, not invented. E5 —
DPoP/DBSC automation and bounded validation

E5-T1: Audit actual token endpoint, refresh and Resource Server use of DPoP: accepted algorithm/key,
embedded public JWK, thumbprint/cnf.jkt, htm, canonical htu, time window, fresh jti, key mismatch,
and ath where an Access Token is presented. DPoP and client authentication remain different
controls. Keep per-client Bearer/DPoP and metadata consistent. Do not add ath requirements to a
code-exchange proof that presents no Access Token.

E5-T2: RFC 9449 nonce is optional. If current policy elects it, test use_dpop_nonce/DPoP-Nonce,
valid challenge retry and wrong/stale/replayed proofs against E1's consume boundary. If it is not
elected, state that explicitly instead of claiming a defect solely from header absence. [N3]

E5-T3: Trace DBSC registration → device/key association → proof → renewal → expiry → logout/revoke,
including replay and unsupported-client fallback. Device binding is not Emergency mode,
authentication assurance, or immediate JWT revocation. Use runtime-path tests, not just
object-existence tests.

Document supported automated contracts, unsupported/unverified client paths, required representative
browser/device matrix, and deployment prerequisites in the normal plans structure plus linked
misc.md entries. Do not manufacture browser-version support claims or enforce a new global policy
without interoperability evidence.

Done: Automated protocol/runtime gaps are fixed and tested; physical validation is explicitly
DEFERRED_VALIDATION, not a whole-project NO-GO and not marked passed. E6 — OTP/Turnstile/email,
social links, sign-out and inert UI

HEAD already contains reported signup-email retention, signin reset, disabled Create and social-link
Step-Up work. Inspect the existing implementation and tests first; retain verified changes and fill
only genuine gaps. [S3 §§2.9, 13]

E6-T1: app/com × signup/signin normal email flows. Initial email form GET is empty; an allowed 422
restores the submitted email only in response props, not logs or server session. OTP may exist
transiently while being entered/submitted, but never persists in remembered React/Inertia state,
session/flash, re-rendered props/HTML or later history after failure. Clear on
invalid/blank/rate-limited/locked/error/resend paths; inspect reused components and browser back
behavior. Never set a non-empty OTP input value from a previous response.

E6-T2: Require visible and server-validated Turnstile for the specified OTP checkpoints, before OTP
verification/attempt decrement/session creation. Missing/invalid challenge leaves OTP attempt and
domain lockout/session state unchanged; ordinary request-rate-limiting may still apply. Enforce
configured hostname/action/context expectations. A browser widget alone is insufficient; Turnstile
tokens are single-use and expire after 300 seconds. Obtain a fresh challenge after failures;
timeout/unavailable service must not fall through to OTP. [N4]

Keep enumeration/dummy-account paths observably equivalent. Reconcile the earlier “no extra
checkpoint challenge” ADR with the explicit current requirement, rather than deleting the new
requirement as stale. Do not replace state machines or bypass admission to simplify tests.

E6-T3: Scope the Visitor recovery identity preload to the actual top-up operation, preserve
validators and Client behavior, and compare query counts for email, telephone and absent recovery
identity cases (including multiple recovery credentials). Avoid cache tricks that hide a changed
authorization decision.

E6-T4: Purpose-specific localized branded mail subjects for app/com share the existing mailer/i18n
path. No OTP, raw identity/secret/token in subject; preserve required message body and existing
provider behavior. Test locale × purpose without sending real mail/SMS.

E6-T5: Preserve fresh Step-Up for linking/unlinking Google/Apple to an existing account; signup
enrollment is distinct. Do not treat a fresh ordinary sign-in as an automatic replacement for the
adopted linking requirement. Keep the existing STAY ADR if already correct, and test callback
bypass/last-method guards.

E6-T6: Reproduce sign-out through browser-visible completion. Verify complete Set-Cookie scope and
CookieJar effects for both access/refresh cookie names, including prefixed variants and formerly
used scopes that current code actually issued. Cookie deletion is not server revocation and vice
versa. Verify immediate new sign-in and app/com/org isolation. Change shared deletion logic only if
a mismatch is demonstrated. Do not make a sign-out GET mutate session authority.

E6-T7: Shared Create controls remain disabled buttons without href, event-based navigation, submit
behavior or write requests. Account/Organization/Avatar mocks add no provisioning route or policy.
Avatar Up uses the currently valid authenticated home helper and preserves ri; do not point Base
back at a retired /dashboard. Existing real Avatar creation stays unchanged.

Done: Four OTP flows, challenge failures, non-retention, cookies and mocked actions are verified. A
no-op is an acceptable production diff where current behavior already passes the requirement. E7 —
Sessions, Activities, preferences and expiry

E7-T1: Move user session management to owner-scoped resourceful /sessions across app/com/org,
including helper/navigation/Step-Up-scope catalog/React/OpenAPI callers. Keep /sign/out independent
and Core /api/v0/session as its different BFF contract. Reject foreign IDs/realms, preserve CSRF and
action authorization, and perform no GET revocation. Current-session and other-session actions
respect Base/RP ownership without added normal-request session queries.

E7-T2: Activity event type, risk rank and visibility stay independent; reuse existing
presenters/static metadata. Exclude internal events in SQL before pagination, counts or grouping,
not only in React. Normalize user descriptions. Test props and rendered output for absence of
internal IDs, raw context, full/private IP information, credentials, tokens and internal enums; HTML
escaping and authorization remain intact.

E7-T3: Show actual Device or localized Unknown, current label, last activity and proven session
expiry. Hide Kind/Binding/internal IDs/refresh TTL from ordinary user UI. Administrative technical
data remains behind its appropriate authorization. Emergency derives only from explicit context,
never from DBSC/device presence.

E7-T4: Prove discarded_at semantics for Client, Visitor and Operator along creation, refresh
rotation, Access/ID/Refresh issue, DBSC renewal, lookup and termination. Reuse it if it is truly the
non-sliding absolute ceiling. Rotation and repeated authorization cannot extend the ceiling; no
issued expiration exceeds it. Test exact and leeway-aware boundaries. No refresh/renewal resurrects
expired or revoked state. Do not confuse planned absolute expiry with an earlier revoke under
D-REVOCATION.

If evidence disproves the field's meaning, introduce only the minimal explicit semantic timestamp
within the owning DB/model contract, with non-destructive schema verification on disposable data.
Never infer a historical event from created_at just to fill a new NOT NULL field. Unknown old
authentication history requires reauthentication; unknown optional UI history is unknown, not
fabricated.

E7-T5: Reuse SessionTimestampHelper or the actual established equivalent. Apply preference
timezone/date/clock consistently and sort/paginate by stored instants. Test day/year/timezone/DST
boundaries where supported, 12h/24h and locale, all three surfaces, and bounded query counts. Do not
create another formatting layer or risk/visibility tables.

Done: /sessions works as its own resource, only safe user fields appear, expiry is enforced rather
than merely relabeled, and formatting/sorting are consistent. E8 — Routes, roots, GUID and OpenAPI

Inventory config/routes* and config/routing* if present, controller ownership, URL helpers, active
proxy/client references, actual JSON endpoints and protocol exceptions. After E0 isolation, obtain
runtime routes/notes; static inventory remains useful when boot is unavailable. Do not treat route
existence alone as an implementation. [S1 §§2, 11.G8; S3 §§2.10–11]

E8-T1: Prefer resource(s) plus namespace; default :id carries existing opaque identifiers, not
database PKs. Avoid unnecessary as, controller, custom params, imperative get/match and route loops.
Preserve justified CSP and /.well-known path: mappings and explicitly classified
OAuth/OIDC/WebAuthn/DBSC/operational contracts. Do not mechanically force protocol paths under
/api/v0.

Migrate valuable application /web/vN//edge/vN APIs to the established /api/v0/Api::V0 organization
with all callers/tests/contracts in one coherent slice. Remove dead routes only with call-site and
contract evidence. This project is not asking for compatibility shims for an undeployed design; do
not invent dual stacks. That permission does not authorize deleting real data or breaking an
externally configured provider callback. A valuable unresolved endpoint gets a narrow actionable
FIXME linked to misc.md, never a broad exclusion.

E8-T2: Verify the actual 14-surface inventory: Auth/Base/Core/Side × app/com/org, Palm app, Edit
org. Base authenticated root keeps its existing guarded dashboard content; anonymous Base root
follows D-ENTRY. Do not restore retired Auth/Base /dashboard or Base /lobby. Auth is public ceremony
entry. Side/Core/Edit use their real current contracts; Core/Palm do not gain fictitious dashboards
or redirects to JSON profiles. Temporary auth-dependent redirects preserve validated ri and correct
host; private content stays protected.

E8-T3: Implement the minimal GUID record in the existing identifier-owned persistence boundary, with
unique NOT NULL opaque eid, required bounded kind/status and nullable safely represented canonical
URL. Check length/encoding/one-time decoding, exact-match semantics, parameterization and escaping.
Unknown ID is 404; store outage is 5xx; canonical URL never becomes an automatic redirect. No new ID
algorithm/gem, catch-all or registration endpoint. Test actual DB uniqueness, HTML/JSON parity,
malformed ID, wrong host, null URL and no Location header. No hard deletion/reuse path is added;
long-term tombstone governance can be a next-cycle finding.

If the repository has no established identifier persistence owner and creating one would require new
external infrastructure or arbitrary attachment to an authentication DB, isolate only that
persistence decision as BLOCKED_SLICE, retain non-redirecting safe behavior, and document the exact
missing owner. Do not claim a 404-only placeholder satisfies resolver success.

E8-T4: Extend the existing OpenAPI registry/generation conventions to the real public GUID net and
Edit scopes; this is a documentation/contract ownership decision, not permission to add a new
deployed surface. Cover every actual application JSON route, parameters, statuses, security and
content negotiation. Keep protocol exemptions narrow, enumerated and justified. Update source and
generated bundles; run lint, bundle, idempotence and contract coverage. Generated output matching an
obsolete source is not sufficient.

Done: Known routes and callers converge, valid protocol exceptions remain, GUID has evidence-backed
success/failure behavior or an explicitly isolated residual, and API documentation matches actual
reachable contracts. E9 — Semantic timestamps and private-test/visibility cleanup

Perform broad cleanup only after an attributable green baseline; necessary E1–E8 repairs are not
held hostage to that gate. Inventory production callers and tests before deleting or changing
visibility. [S1 REQ-045–050, 066–069]

E9-T1: Classify all meaningful created_at/updated_at uses as legitimate persistence metadata versus
domain time. Audit queries/order/periods/expiry/serialization/views and fixtures, not just obvious
labels. Preserve metadata itself when useful. Introduce actual event fields only where lifecycle
evidence supports them; unrelated updates must not alter domain events. No mechanical renaming to
inserted_at, fabricated backfill, or alias that masks missing semantics. Test actual alias
reads/writes/query/update paths when a justified alias exists.

E9-T2: Classify direct private-method tests into public-behavior replacement, already-covered
behavior, proven dead code, or genuine protected extension contract. Add meaningful
public/framework-boundary tests before removing coupling. Do not “fix” tests by making helpers
public, calling them through reflection in renamed helpers, or deleting negative coverage. Keep
Rails actions, callbacks and framework-used methods at the visibility their real contract requires.

E9-T3: Reduce unjustified public APIs; use protected only for real extension contracts, private for
internal helpers. Reuse the repository's existing static harness/custom-cop locations, with narrow
justified exceptions and false-positive tests. Do not add an alternative harness directory,
test-only production branch or new concern inclusion hooks.

Run narrow and periodic full coverage against unchanged gates. Legitimate removal of dead code may
change the coverage population; document it rather than manipulating exclusions. If the full
baseline cannot safely become green within current authorized scope, record the exact remaining
batch and keep replacement tests; do not perform unverified mass deletion or mark cleanup complete.
E10 — Final verification and next-cycle handoff

Perform one bounded reverse-direction self-check: final routes/code/state transitions → actual
tests/results → Appendix A → affected ADR/docs → misc.md. An independent second model is not a
mandatory gate in this run. The next cycle may commission a separate review.

E10-T1: Run the actual affected-to-full verification path on isolated targets: focused
public/store/integration tests; cross-surface tests; full Rails with explicit coverage; ordinary JS
tests and JS coverage; repository format/lint/type/security checks; route/OpenAPI checks; canonical
CI once its DB preparation is safe. A full explicit-coverage Rails run may also supply ordinary
full-suite results; needless duplicate full runs are not required. Record every command/exit,
counts/skips/reasons and coverage dimensions. Unavailable checks remain unavailable, not silently
omitted.

E10-T2: Every REQ ID has one primary owner and final disposition with current evidence. REQ-020 is
checked horizontally. Process-only requirements carry explicit supersession; REQ-095 carries the
actual missing-fragment limitation. No number of passing tests cancels a known authority violation.
Update only affected ADR/docs/plans and keep required follow-up exit criteria; do not perform a
repository-wide prose purge.

E10-T3: Preserve and update misc.md with deduplicated, source-linked findings and current
containment. Keep a flat dated Markdown evidence summary under the established evidence/ rules for
work actually performed. Stop local test servers/owned processes and report remaining
staged/unstaged/untracked files and verified local commits. No GitHub/external write or deployment.

Report separately: implementation outcome, verification outcome, and deployment prerequisites. Valid
outcomes include “implemented and verified with deferred physical validation” and “completed
independent slices; X blocked/unverified.” Do not write “all 95 requirements implemented” when
process supersessions, a missing fragment, or unresolved slices remain. 6. misc.md recording and
deferral contract

misc.md is the next-cycle analysis register, not a second execution plan and not a repository of
secrets. Record a finding when first discovered; refine it as evidence improves. Use stable IDs and
merge duplicates by root cause. Do not overwrite old observations when resolving them; add the
resolution and evidence.

Each finding must contain:

    Status / evidence level: open, mitigated, resolved or superseded; source observation, reproduced test, hypothesis, measurement gap or device-validation gap.

    Concrete evidence: phase, actual HEAD, file/symbol/line or current test/measurement. Distinguish supplied-report evidence from a current-run reproduction.

    Abstract problem: the architectural invariant or repeated design weakness, not only the symptom or exception string.

    Affected scope and preconditions: actor/realm/component and what must happen for the issue to matter.

    Impact and likelihood separately: qualitative magnitude and confidence; use “unknown” where probability is not measured. A severe potential impact is not proof of high occurrence probability.

    Current containment and residual: what prevents harm now, what remains unverified, and whether the affected slice is deployment-blocking. Deferral does not itself provide containment.

    Reason for deferral: out-of-scope redesign, missing measurement, real-device validation, missing source fragment, unavailable safe environment, or a narrowly named external decision.

    Next-cycle question, falsifier/test and exit criterion: what evidence would confirm/refute the concern and how completion will be recognized.

    Related requirement/ADR/finding: traceable references without duplicating the requirement list as a vague todo list.

Examples of valuable abstractions: a one-time code and revocation metadata split across stores;
authentication evidence losing mode/freshness at a service boundary; two presentation layers
reinterpreting persistence timestamps; a growing number of network round trips per credential
exchange; a callback test that passes because a different earlier guard rejects the request.

Record p50/p95/p99, lock waits, query count, allocations or Valkey round trips only when actually
measured, with workload/environment/sample size. Do not invent latency budgets or observed
vulnerability severity. Do not store raw tokens, codes, OTPs, cookies, email/phone lists,
credentials, full production URLs containing secrets, or exploit materials for live systems. Keep
reproduction in disposable tests. 7. Local stop rules — not a blanket project veto Finding /
condition Required action Hypothesis, abstract debt, missing performance measurement, unverified
device support Record in misc.md, keep established boundaries, continue current tasks. Required
behavior fails a current isolated test Fix the smallest in-scope cause, rerun, continue. This is
implementation, not a demand for another full plan. A new change would create an auth bypass,
cross-realm access, secret disclosure, wrong-owner revoke or silent corruption Do not enable that
unsafe slice. Repair within scope or contain at that boundary; preserve evidence and continue
independent work. Test/CI could touch shared development/production DB/Valkey or send live provider
traffic Stop that runtime command; establish isolation or mark it unavailable. Continue safe work.
New external write, production deploy, deleting existing data, material new product/authority policy
outside §3 Not authorized. Do not perform it; record exact next-cycle decision. Existing blocker
cannot be fixed safely Record BLOCKED_SLICE and deployment restriction. Never suppress a test or
claim the blocker was solved by deferral.

No unattended risky command is justified by “the user is asleep.” No routine question is needed for
choices already fixed in §3 or for ordinary bounded implementation details. Do not expand the run
into unrelated redesign merely to remove every entry from misc.md. 8. Final run report template

    Actual starting/ending HEAD and protected pre-existing changes; resolved plan/memo paths.

    Phase/REQ completion table with exact VERIFIED, ALREADY_SATISFIED_VERIFIED, deferred, blocked and unverified distinctions.

    Important decisions implemented: D-ENTRY, authority, event time, owner-bound replay and partial-failure behavior.

    Commands/exit statuses, Rails and JS ordinary/coverage results, skips and reasons, current failures and attribution.

    Files/verified local commits; no unstated external state change.

    misc.md finding IDs grouped by current deployment blockers versus next-cycle analysis/validation.

    Remaining runnable work and precise restart points, without a new planning-only veto over completed independent work.

Appendix A — Accepted 95-requirement execution ledger and primary ownership

This is the accepted English execution ledger supplied in the final plan for REQ-001–094; the
missing original prompt attachments are not a reason to mark these requirements BLOCKED_SOURCE.
Parenthetical cycle adjustments are explicit. REQ-095 records only the known truncated ORG fragment
and must not be reconstructed. The acceptance references below point to concrete tests in §5 or the
file/progress rules above. There is exactly one primary owner per ID; secondary regression checks do
not create duplicate ownership. Requirement Primary owner Execution requirement / explicit
disposition Acceptance evidence REQ-001 E0 Prior planning run is read-only; in this new Goal run
local implementation is authorized, while GitHub/external writes remain prohibited. (Planning-only
scope superseded; remote boundary retained.) §1; E0-T2; E10-T3 REQ-002 E0 Preserve source precedence
and record conflicts; the latest user-authorized cycle decisions explicitly resolve earlier
ambiguity. §§1–3; E0-T2 REQ-003 E0 Prior 18-section planning/audit deliverable is historical; do not
repeat it as an implementation gate. (Process supersession.) §§1, 4, 8 REQ-004 E0 Retain the
executable plan at resolved refactor.md path without destroying a directory or user content. §1.1
REQ-005 E0 Use isolated local commits only for verified steps; preserve all unrelated Git changes;
never publish them. §1; E0-T2; E10-T3 REQ-006 E0 Stop owned local verification servers/processes
when no longer needed. E10-T3 REQ-007 E2 Base is the sole physical IdP/Authorization Server
authority. E2-T1–T4 REQ-008 E2 Auth is credential ceremony only, with no independent
identity/Base/RP-session/final-AAL/token authority; allowed ceremony continuity remains. E2-T1–T4
REQ-009 E2 Actual RP flows follow RP → Base admission → Auth → Base → code/result → actual RP.
E2-T2; E4-T1 REQ-010 E2 No admission bypass or fabricated RP transaction; standalone
entry/completion is fixed by D-ENTRY for this cycle. (Earlier undecided UX resolved explicitly.)
D-ENTRY; E2-T1–T3 REQ-011 E3 auth_time is the accepted authentication event, never refreshed by
code/token issue, exchange, callback or ordinary refresh. E3-T1/T2 REQ-012 E3 Base accepts acr; amr
represents methods actually used and survives reissuance. E3-T3 REQ-013 E3 Separate sign-in,
Step-Up, achieved AAL, phishing resistance, freshness and FAL; bound this cycle and record deeper
follow-up. E3-T3; §6 REQ-014 E3 Keep explicit SMS risk acceptance without calling SMS
phishing-resistant or automatically AAL2. D-ASSURANCE; E3-T3 REQ-015 E3 Retain natural expiry of
already-issued short-lived Access JWTs after revocation; no new immediate revocation lookup.
D-REVOCATION; E4-T2 REQ-016 E5 Audit/fix DPoP to RFC 9449 and strengthen only appropriate compatible
clients. E5-T1/T2 REQ-017 E5 DBSC remains progressive enhancement with usable fallback and tested
runtime lifecycle. E5-T3 REQ-018 E5 Never call unperformed physical/client interoperability
validated; record specific validation debt. E5; §6 REQ-019 E5 Maintain concrete follow-up
analysis/plans for local-entry refinements, AAL/FAL and DPoP/DBSC validation. E5; §6; E10-T2/T3
REQ-020 E10 Never weaken authentication security controls, coverage or negative tests. Horizontal
invariant for every phase. All E*-T*; E10-T1/T2 REQ-021 E8 Resolver is opaque lookup only; no ID
generator, new scheme or new gem. D-GUID; E8-T3 REQ-022 E8 Persistent eid is unique/non-null;
kind/status required; canonical URL nullable; validate bounded input. E8-T3 REQ-023 E8 Use a scoped
resource lookup route, not a top-level catch-all; retain existing API/host contract. E8-T1/T3
REQ-024 E8 HTML/JSON share exact lookup; unknown identifier is 404 and backend failure is 5xx. E8-T3
REQ-025 E8 Canonical URL never triggers automatic redirection. E8-T3 REQ-026 E8 Do not add ID reuse
or public registration; preserve uniqueness/no hard-delete path in the PoC. E8-T3; §6 REQ-027 E8
Test injection, escaping, decoding, input length and identifier-surface isolation. E8-T3 REQ-028 E4
Core/Side/Edit reuse equivalent RP protocol mechanics. E4-T1 REQ-029 E4 Edit specificity is boundary
configuration; shared code has no singleton deployment assumption. E4-T1 REQ-030 E4 Preserve
state/nonce/PKCE/issuer/audience/exact-redirect/JWT-profile/session/logout safety. E4-T1/T2 REQ-031
E4 Test observable RP callback failures, replay, exchange, rotation and logout without live IdP
traffic. E4-T1 REQ-032 E4 Never restore Auth as an RP; preserve Base ownership and multi-instance RP
support. E2-T4; E4-T1 REQ-033 E8 Retain justified CSP and .well-known path mappings rather than
blindly removing overrides. E8-T1 REQ-034 E8 Inventory actual route files and api/web/edge prefixes
using source and safe runtime evidence. E8-T1/T4 REQ-035 E8 Converge valuable application APIs on
resourceful /api/v0 and Api::V0 while preserving service/realm boundaries. E8-T1/T4 REQ-036 E8
Remove only evidence-backed dead routes; retain narrow actionable FIXME for valuable unresolved
contracts. E8-T1; §6 REQ-037 E8 Prefer default opaque when callers/URL/security remain safe; never
expose database PKs. E8-T1/T3/T4 REQ-038 E8 Describe all actual application JSON APIs, including
Edit/GUID, in the correct OpenAPI scope. E8-T4 REQ-039 E8 Keep OpenAPI source/bundle aligned and run
lint/bundle/idempotence/contract verification. E8-T4 REQ-040 E8 Keep protocol exemptions narrow and
retain auth/CSRF/cache/content/error contracts. E8-T1/T4 REQ-041 E8 Verify each actual surface root
and its authenticated/anonymous meaning. E8-T2 REQ-042 E8 Preserve validated ri, temporary
auth-dependent redirects and private-home authorization. E8-T2 REQ-043 E8 Do not invent Core/Palm
dashboards or redirect native/API entry to inappropriate JSON/browser pages. E8-T2 REQ-044 E8 Follow
current Base/Auth root architecture; do not restore retired dashboards/lobby. D-ENTRY; E8-T2 REQ-045
E9 created_at/updated_at are persistence metadata, not inferred domain-event timestamps. E9-T1
REQ-046 E9 Any timestamp alias must have proven read/write/query semantics; avoid updated_at
aliases. E9-T1 REQ-047 E9 Backfill or remove relationship timestamps only with
lifecycle/history/use-site evidence. E9-T1; §7 REQ-048 E9 Add narrow semantic/visibility guards in
the existing harness with justified exceptions and false-positive tests. E9-T1–T3 REQ-049 E9 Domain
times update at the right transition and not on unrelated persistence updates. E9-T1 REQ-050 E9
Private-test cleanup preserves unchanged SimpleCov gates and replacement behavior coverage.
E9-T2/T3; E10-T1 REQ-051 E3 ORG sign-in presents Entra, independent normal SecretKey and restricted
Emergency entries. E3-T4 REQ-052 E3 Keep Entra single-tenant/pre-provisioned/no-JIT and its
PKCE/state/nonce contracts. E3-T4 REQ-053 E3 SecretKey normal sign-in can start independently while
preserving owner binding and existing security controls. E3-T4 REQ-054 E3 Emergency stays
identifier+Passkey restricted access, not normal fallback or in-session mode conversion. E3-T3/T4
REQ-055 E3 Show ORG signup only if existing self-service/provisioning policy permits it. E3-T4
REQ-056 E3 Preserve ORG UI/i18n/host isolation; do not present Emergency as the recommended normal
method. E3-T4 REQ-057 E4 Seven browser RP clients have independent client IDs/keys with PKCE S256
and private_key_jwt. E4-T1 REQ-058 E4 RP browser transactions are short-lived encrypted host-only
state with safe multi-tab and return-target behavior. E4-T1 REQ-059 E1 Valkey authorization codes
are digest-keyed, short-lived, atomically one-use and fail closed. E1-T1–T4 REQ-060 E1
Client-assertion JTI replay remains PostgreSQL-backed, unique and fail closed. E1-T1; E4-T2 REQ-061
E4 Identity → Base session → RP session; one active RP session per Base-session/client is
DB-enforced. E4-T2 REQ-062 E4 Preserve selective/parent revoke hierarchy without ordinary-request
RP-session DB lookup. E4-T2 REQ-063 E4 Administration distinguishes client registry configuration
from individual RP Sessions. E4-T3 REQ-064 E0 Keep one-Valkey/six-logical-DB topology, structured
access, selected hiredis transport and per-run/worker test namespace/no flush. E0-T1/T3; E4/E5
regressions REQ-065 E2 Remove legacy Auth RP dependencies while preserving ceremony responsibilities
and Jump JWKS. E2-T4 REQ-066 E0 Obtain an attributable green baseline before broad
private-test/visibility cleanup, not before necessary baseline repairs. E0-T2; E9 gate REQ-067 E9
Classify direct private-helper tests and replace with public/framework behavior before removal.
E9-T2 REQ-068 E9 Reduce unnecessary public methods; private for internals and protected only for
genuine extension contracts. E9-T3 REQ-069 E10 Do not weaken
skips/assertions/thresholds/linters/exclusions; execute and report current full gates truthfully.
E10-T1/T2 REQ-070 E6 Existing-account Google/Apple linking retains fresh Step-Up. E6-T5 REQ-071 E6
Signup enrollment is distinct; unlink also needs Step-Up; do not automatically reuse ordinary recent
login as approval. E6-T5 REQ-072 E6 Preserve/update the STAY ADR; no production change where
implementation already matches. E6-T5; E10-T2 REQ-073 E6 Completed sign-out detaches access/refresh
cookies at their actual issuance scope; fix only a reproduced mismatch. E6-T6 REQ-074 E6 Test
immediate re-sign-in, app/com/org isolation, CSRF and secure cookie attributes after sign-out. E6-T6
REQ-075 E7 Move user session management to /sessions while retaining the separate /sign/out
ceremony. E7-T1 REQ-076 E7 Session actions are owner-scoped, CSRF-protected and non-mutating on GET;
no new normal-request session lookup. E7-T1 REQ-077 E7 Home navigation, current label and
other-session termination work without internal user-facing IDs. E7-T1/T3 REQ-078 E7 Event
type/risk/visibility are independent; filter internal activity in SQL before pagination/counts.
E7-T2 REQ-079 E7 User activity excludes raw context/IP/secrets/technical enums and uses normalized
safe descriptions. E7-T2 REQ-080 E7 Show actual Device or Unknown and hide Kind/Binding/IDs/refresh
TTL in ordinary session UI. E7-T3 REQ-081 E7 Show a proven non-sliding session ceiling;
issuance/renewal stay bounded and expired/revoked state cannot revive. E7-T4 REQ-082 E7 Emergency
mode comes from explicit authentication context, never DBSC binding inference. E7-T3/T4; E3-T3
REQ-083 E7 User timestamps honor preference timezone/date/clock; sorting uses stored instants. E7-T5
REQ-084 E7 Keep i18n, bounded queries, actor ownership and cross-surface isolation in
Activity/Session pages. E7-T1–T5 REQ-085 E6 Rails props drive inert disabled
Account/Organization/Avatar Create buttons; Avatar Up reaches the valid home. E6-T7 REQ-086 E6
Create mock has no route/write/provisioning/policy connection; real Avatar creation is unchanged.
E6-T7 REQ-087 E6 app/com signup email 422 restores permitted email value; fresh GET is empty and
session/logs do not retain it. E6-T1 REQ-088 E6 Signup OTP checkpoints require visible/server
Turnstile before OTP verification or state changes. E6-T2 REQ-089 E6 Signin OTP also requires server
Turnstile before OTP verification while preserving enumeration defenses. E6-T2 REQ-090 E6 Never
retain/replay OTP after failure in props, session, flash, HTML or remembered React/Inertia state.
E6-T1/T2 REQ-091 E6 Do not reuse failed/submitted Turnstile challenge state; obtain a fresh
challenge for retry. E6-T2 REQ-092 E6 Visitor recovery top-up preloads required identity
associations without weakening validators or Client behavior. E6-T3 REQ-093 E6 Integration tests
cover four normal app/com signup/signin flows; Jump is unchanged and no live provider calls occur.
E6-T1/T2 REQ-094 E6 Purpose-specific localized branded OTP mail subjects share the existing path,
omit secrets and preserve body. E6-T4 REQ-095 E10 Original ORG fragment was truncated; do not invent
missing wording. Record the precise source limitation for the next cycle. (Explicit deferral.)
E10-T2; MISC-0006 Appendix B — Provenance and scope of verification

Execution authority and requirement provenance (recorded by the prior draft)

At the time this draft was prepared, a separate instruction was read as authorizing a bounded local
implementation run, adopting D-ENTRY and E0–E10, and treating Appendix A as the execution ledger for
REQ-001–094. That interpretation is not the current authority: the present request is planning-only
and retains the NO-GO decision above. The omitted ORG wording described by REQ-095 remains unknown
and is not reconstructed.

The following digests were supplied as input identifiers; the corresponding source files were not
found in the current workspace search and their bytes were not independently re-hashed during this
run:

- [S1] Original 18-section plan identifier; reported HEAD d7b053813bdbdafa54a77b16074804981d9355b1;
  supplied SHA-256 2ae07102f486fd13c64fc45acfca65b990cc438db1098610dcb09415b52a92c8.
- [S2] Sol static review identifier; reported HEAD 08fc1eeb6d2f354078787ab6f3f4e6890c774def;
  supplied SHA-256 3052638bea18ef029798632f068402333638eeacd222de23bad1af05e91b8533.
- [S3] Prior V2 re-audit identifier; reported HEAD 430ac354ba06c9d22885e1e69d027a7a1b1d5280;
  supplied SHA-256 58e1db696bf72f241dd6d7d9a8dedcb5cb6baef28d4c325243a295321ca53070.

The prior V2 planning-only report is preserved in
notes/implementation/2026-09-14-refactor-plan-history.md. The old draft recorded that report's NO-GO
conclusion as superseded by a then-assumed implementation authorization. Under the current
planning-only request, NO-GO is the operative verdict again; its code observations remain hypotheses
or static facts unless a public-boundary test reproduced them.

Earlier read-only GitHub observations H1–H4 are retained as historical citations only; they are not
current-state evidence and were not repeated in this implementation run. No GitHub write is
authorized or performed.

Normative references checked

    [N1] OpenID Connect Core 1.0 incorporating errata set 2, §§2, 3.1.2.1–3 and 15.1; https://openid.net/specs/openid-connect-core-1_0.html. Normative authentication-time/freshness rules are distinguished from the project's Access JWT claim and local-entry policy.

    [N2] RFC 6749, §§4.1.2–3 and 10.6; https://www.rfc-editor.org/rfc/rfc6749.html. Authorization-code binding, single-use, reuse denial and attempted revocation. Project owner/generation/failure-injection assertions are implementation design, not claimed verbatim RFC requirements.

    [N3] RFC 9449, especially §§4–5 and 8; https://datatracker.ietf.org/doc/html/rfc9449. DPoP proof and optional AS nonce challenge contracts. Per-client rollout and pending device validation are project decisions.

    [N4] Cloudflare Turnstile server-side validation; https://developers.cloudflare.com/turnstile/get-started/server-side-validation/. Server verification, single use and five-minute token lifetime. OTP-attempt ordering and enumeration assertions are the project's stronger application contract.

No unverified model speed, model pricing, browser support matrix or implementation-duration estimate
is a premise of this plan.

Current NO-GO basis for this planning run

This section records the current readiness decision for the read-only re-audit. It applies to
freezing one autonomous implementation run across all 95 requirements. It does not establish that
every reported issue is exploitable or require stopping independent investigation and planning. The
detailed report is preserved in
[the full re-audit record](notes/implementation/2026-09-14-refactor-plan-history.md#1-executive-verdict).

The NO-GO is based on these unresolved gates:

| Gate                                | Evidence available to this planning run                                                                                                                                                                                         | Requirement before freezing the dependent execution slice                                                                                                                                               |
| ----------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Authentication-event time           | The static review reported that the authorization-code issuer used `Time.current` and that exchange could derive `auth_time` from code issuance metadata. No T0/T1/T2 boundary test had established the end-to-end claim value. | E3-T1 traces accepted authentication evidence through Base, code, exchanged tokens, and refresh; use separated event, issue, and exchange times.                                                        |
| Authorization-code replay ownership | The static review reported that replay classification preceded client/redirect/PKCE binding checks in both Ruby and Lua. Cross-client revocation effects had not been exercised at the token endpoint.                          | E1-T1/T2 tests valid same-owner replay and wrong-client, redirect, PKCE, corrupt, expired, and concurrent exchanges while observing owner-scoped state.                                                 |
| Cross-store partial failure         | The static review reported that family-link outcomes and Valkey failures might not prevent token response construction. Failure injection had not established the resulting Valkey, PostgreSQL, and response states.            | E1-T3 injects explicit negative outcomes, exceptions, ambiguous timeouts, signing/commit failures, and response loss; success requires a positively established required link.                          |
| DPoP after code consumption         | The review reported code consumption before DPoP verification and did not establish whether a nonce challenge was required on the relevant path. This alone did not prove a protocol defect because AS nonce use is optional.   | E1-T4 and E5-T2 inspect the active client policy and actual endpoint error/header contract; if nonce is elected, verify challenge and valid retry before irreversible consumption.                      |
| Base/Auth local entry               | Static route/controller evidence indicates a possible admission-less navigation loop; no browser-visible authority transition has been reproduced. Direct-entry UX remains undecided.                                           | Present evidence-based choices and obtain the user's decision. Keep Auth ceremony-only and Base as the sole authority. Do not synthesize RP artifacts.                                                  |
| Safe test baseline                  | Earlier notes are historical results, not a current green baseline. Test PostgreSQL/Valkey isolation and provider egress denial are not proven for this execution environment.                                                  | Inspect runner and service configuration. Do not run mutating tests until every target is isolated; distinguish test success, coverage and CI results.                                                  |
| Requirement traceability            | The supplied review identifies a missing REQ-020 row in the earlier mapping and G3/G4/ORG ownership inconsistencies. The original P00–P17 prompt texts are not present as verified source files here.                           | Reconcile each available requirement to one primary phase, tests, evidence, docs and criterion; apply REQ-020 horizontally; do not invent missing ORG wording; mechanically validate IDs and DAG edges. |

The authentication, replay, cross-store and DPoP items are unverified security/correctness concerns,
not claims of reproduced exploitation. Test isolation blocks unsafe dynamic verification but does
not stop read-only source investigation. The direct-entry product decision remains user-dependent.
The current verdict is **NO-GO for freezing all 95 requirements into one autonomous implementation
run**. Continue planning and safe investigation only; do not begin implementation when this planning
task ends.

E0 execution record — 2026-09-14 UTC, HEAD 430ac354ba06c9d22885e1e69d027a7a1b1d5280

Initial and ending Git state: branch `feature`; no tracked or staged changes; `misc.md` and
`refactor.md` were pre-existing untracked files. This run appended the NO-GO record and E0 results
to `refactor.md`, at the user's request, and added the corresponding findings to the end of
`misc.md`. No checkout, staging, commit, database connection, Valkey connection, server, provider
request, or GitHub operation was performed.

Safe frontend checks: `bun run test` exited 0 (85 files, 1,054 tests). `bun run format:check`,
`bun run lint`, `bun run typecheck:verify`, `bun run typecheck`, `bun run deadcode`, and
`bun run openapi:lint` exited 0. Knip reported two configuration hints (`@inertiajs/core` in
`knip.json` and compiled `.css` imports); no check failed. `bin/rubocop` exited 0 (4,790 files, no
offenses). `bundle exec erb_lint --lint-all` exited 0 (599 files, no ERB errors) with a parser
compatibility warning: parser/ruby33 was running under Ruby 4.0.6.
`bundle exec brakeman --quiet --no-pager --exit-on-warn --exit-on-error` exited 0 with zero warnings
(Brakeman 8.0.6, Rails 8.2.0.alpha). The repository wrapper `bin/brakeman ...` could not create
`/home/global/.cache/gem` in the read-only sandbox; the direct bundled command performed the scan
without its network-oriented latest-version precheck.

Coverage is not a single green result: the prescribed Bun-runtime coverage command
(`bun --bun vitest run --coverage`, with its report redirected to `/tmp`) exited 1 with
`RangeError: Maximum call stack size exceeded` in `@bcoe/v8-coverage` 1.0.2 while merging coverage
ranges. The same locked Vitest suite run directly under Node 24.20.0 exited 0 (85 files, 1,054
tests; statements 100%, branches 99.7% (1,343/1,347), functions 100%, lines 100%). This is a
successful diagnostic measurement, not proof that the repository's canonical Bun coverage entry
point or full CI is green. No coverage settings were changed.

Rails/service isolation is not established in this shell, so `bin/rails test`,
`COVERAGE=true bin/rails test test/`, `bin/ci`, route boot, and service-touching tests remain unrun.
The active process has `POSTGRESQL_HOST=primary` and `POSTGRESQL_TEST_HOST=primary`; test databases
are named `test_*`, but `config/database.yml` uses the shared default PostgreSQL user and
`compose.yaml` describes a persistent primary volume. More critically, the active
`AUTH_STATE_REDIS_URL` is `redis://valkey:6379/2`, the documented development auth-state DB.
`config/environments/test.rb` does not redirect that URL. Application default auth-state stores use
fixed namespaces without suite/worker IDs, although direct store tests construct their own test
namespaces. The Turnstile verifier is stubbed suite-wide; outbound HTTP stubbing is opt-in, and a
suite-wide network-deny control was not established. Docker, Podman, Valkey/Redis server, and
PostgreSQL server binaries were unavailable; the shared endpoints were not probed. These facts block
mutating Rails/CI commands until E0 isolation is established.

Current E0 state: `IN_PROGRESS`; Rails baseline and canonical JavaScript coverage are
`BLOCKED_BY_ENVIRONMENT`/`UNVERIFIED` as described above. Static inventory and independent frontend
checks may continue. Do not use `/2`, do not infer safe Valkey isolation from a logical DB number,
and do not claim the current Rails baseline or full `bin/ci` result.
