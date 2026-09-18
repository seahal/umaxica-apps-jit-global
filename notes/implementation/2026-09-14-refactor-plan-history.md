> **CURRENT AUTHORITY — V2 RE-AUDIT (2026-09-14)**
>
> **Overall verdict: NO-GO for freezing or authorizing autonomous implementation of all 95 items.**
> This is a planning/read-only run. It is not a NO-GO for the Base/Auth architecture or for every
> independent workstream. Static evidence shows security-correctness risks that need boundary
> tests, the Base-local/direct-entry UX remains explicitly undecided, and Rails/Valkey test
> isolation is not established. Independent planning can proceed; implementation must wait for a
> separate explicit request and for each phase's preconditions.
>
> This notice and the final section titled “V2 evidence-based re-audit and revised execution plan”
> supersede earlier statements in this file that call the plan GO, select D-ENTRY, claim the source
> attachments were recovered and hashed in this workspace, or authorize implementation. Those
> statements remain historical records only. No application source, persistent test, migration, route,
> configuration, ADR, Git state, database, external service, or GitHub state was changed by this
> V2 work. Safe JavaScript/static checks are recorded below; Rails/service tests were not run.
> Only this requested plan file was updated in the V2 file-writing pass; misc.md is preserved.
>
> Evidence boundary: current working HEAD is 430ac354ba06c9d22885e1e69d027a7a1b1d5280 on feature,
> a descendant of review HEAD 08fc1eeb6d2f354078787ab6f3f4e6890c774def. Original source attachments
> identified by the supplied SHA-256 values and the Sol report file were not present in the workspace
> search; their bytes were not re-hashed here. Appendix A below is therefore a normalized index,
> not a substitute for P00–P17 verbatim text. REQ-095 remains source-truncated.

---

## Historical content begins below; use the V2 addendum at the end as the active plan.

ライブラリ/
UMAXICA NOT-IMPLEMENTED
/
refactor.md
UMAXICA — Final Local Implementation Plan

Cycle: 2026-09-15 / final execution revision
Repository: seahal/umaxica-apps-jit-global
Reference branch / HEAD: feature / 430ac354ba06c9d22885e1e69d027a7a1b1d5280
Decision: GO for bounded local implementation. This is not deployment approval.
Execution mode: Implement the in-scope work, verify it, and record remaining findings in misc.md. Do not return another planning-only NO-GO report merely because some investigation remains.
1. What this revision decides

This plan answers the user's latest instruction to finish the plan, proceed with implementation in Goal, and retain newly discovered architectural, security, and performance concerns for the next cycle. It replaces the execution instructions and phase numbering of the earlier planning-only reports. Those reports remain evidence. They do not prohibit the separately authorized local implementation run.

The accompanying Goal instruction authorizes local application/test/configuration/ADR/document changes within this scope. GitHub remains READ ONLY. No push, PR, issue/comment, release, tag, remote setting, deployment, external account change, or live-provider write is authorized. Preserve unrelated local changes. Local commits are permitted only for verified, isolated steps under the repository rules; they are not permission to publish.

The original 95-row ledger is recovered, not guessed. Appendix A restates every row in English and gives it one primary owner. Original source files are included in the distribution as historical input; the implementer does not need to find them again to begin. The genuinely truncated content behind REQ-095 is still unknown and is explicitly deferred, not reconstructed.

Completion is evidence-based. A discovered question is not a whole-project stop. A required control that remains broken is not silently renamed “next-cycle work,” either. Complete all safe, in-scope slices; contain or isolate an unsafe slice; continue independent work; report exact residual status without calling incomplete verification a pass.
1.1 File placement and preservation

Determine paths once at startup and record them as PLAN_PATH and MEMO_PATH:

    If repository-root refactor.md is a regular file, use it as PLAN_PATH. Retain the old report in a dated, English implementation note before replacing it; do not discard user content.

    If refactor.md is actually a directory, leave it a directory and use refactor.md/implementation-plan.md. Do not delete or convert it to obtain a preferred name.

    Use repository-root misc.md as MEMO_PATH. Create it if absent; append/merge by finding ID if it already exists. Never truncate it. If that path is also a directory, use misc.md/implementation-notes.md and record the resolved path.

    Do not follow a symlink outside the workspace or overwrite an unexplained non-regular target. Use a non-conflicting regular Markdown file inside the workspace and record that technical placement decision.

    Preserve the full requirement ledger while updating progress. Do not replace this plan with a terse completion claim or a new 95-row BLOCKED_SOURCE table.

    The ZIP's sources/ files are reference inputs, not instructions to commit historical Japanese reports into the English repository. Do not place the ZIP, raw logs, JSON dumps, or source copies in evidence/.

1.2 Scope of investigation versus implementation

This artifact was prepared from the recovered attachments and a narrow fresh GitHub read. No application code, tests, databases, or GitHub state were changed by the authoring pass. Current dynamic test health, local worktree state, and effective runtime endpoints must be measured in the implementation environment.

Do not reset to the reference SHA if local HEAD has moved. Record actual HEAD and existing diffs, inspect only relevant intervening changes, and implement on the current authorized worktree. Previously completed behavior must be verified and retained, not implemented twice.
2. Resolved NO-GO reasons
Previous reason	Final disposition for this cycle
Original plan / Sol artifacts missing	Resolved here: both SHA-256 values match the originals; complete normalized ledger embedded below. No repeated filesystem scavenger hunt. [S1, S2]
Unknown refactor.md file/directory or existing misc.md	Use the non-destructive path resolution in §1.1. No user clarification required.
Direct Auth entry product decision	Adopt D-ENTRY in §3. It is this cycle's explicit implementation choice, not a claim that the old report had already decided it.
Test URLs may point at development services	E0 must prove or construct safe, disposable test targets before any mutating runtime command. This is enabling implementation work, not a reason to stop static or independent work. [S3 §2.8]
Replay, partial failure, expiry not dynamically reproduced	Reproduction and negative tests belong inside E1/E7. Lack of a pre-existing proof is not a separate approval gate.
GUID net OpenAPI ownership unclear	Describe the existing GUID host/route as a separate public identifier surface in the current contract registry. Do not invent a new deployment or host. A genuinely missing persistence owner blocks only that persistence slice, not all route work.
DPoP/DBSC physical interoperability absent	Complete current protocol/runtime automation; keep real-device and deployment validation explicit in misc.md. No unsupported rollout claims.
Full suite / coverage not yet green	Capture attributable baseline and repair necessary in-scope failures. Only broad private-test deletion/visibility cleanup requires a green baseline first.
Unexpected abstract design or performance question	Record evidence, containment, and next-cycle investigation in misc.md; continue unless the current slice would cross a hard safety boundary.

Mapping correction: REQ-064 is the one-Valkey/six-logical-DB, structured-access, hiredis, and test-namespace requirement. Its primary owner here is E0, with E4/E5 regression checks as applicable. It is not a DPoP requirement. REQ-020 is owned for closure by E10 and applies horizontally to every phase. REQ-055/056 stay with ORG authentication in E3. These corrections follow the recovered ledger, not the repeated mapping error in the latest report. [S1 §3; S3 §9]
3. Decisions fixed for this execution cycle
D-ENTRY — Base-admitted local sign-in, without a fake RP

The source shows an admission-less Auth entry bridging to Base root, while the anonymous Base root points back to admission-less Auth links. This is a static navigation finding, not a newly reproduced browser incident. Merely retaining both links does not implement Base-local authentication. [H2, H3]

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

This decision fixes the functional entry/completion contract for this cycle. Further visual polish, provider-order preferences, and alternative entry UX belong in misc.md; they do not reopen the authority boundary mid-run.
D-AUTHORITY — Preserve established trust boundaries

Base is the sole physical IdP/AS. Auth is not an RP. Keep exactly core-app, core-com, core-org, side-app, side-com, side-org, edit-org as the seven first-party browser RPs; Palm's native/API contract is separate. Keep app/com/org state and policy isolated. Shared primitives do not mean shared identities, credentials, client keys, cookie scope, or mutable configuration. [S1 REQ-007–009, 028–032, 057–065]

Retain the Auth JWKS endpoint and signing dependencies needed by Jump. Remove only proven legacy RP dependencies, not every JWKS reference. Do not modify the Jump application, its deployment, or its protocol. For cross-host navigation changed in this cycle, use the existing supported caller/return-verification contract; do not invent new Jump capabilities.
D-ASSURANCE — Honest timestamps and context, not a new assurance policy

Record a server-observed credential-verification event once, bind it to the admitted transaction, and have Base explicitly accept that evidence. Preserve its event time as auth_time; do not substitute result-consumption time. Base session start, code issued_at, JWT iat, and AR metadata remain distinct. Missing trustworthy history requires explicit reauthentication or a non-authenticating failure, not a now/created_at compatibility fallback.

Base derives the accepted acr, actual amr, and explicit normal/emergency context. Do not set AAL2 merely because the method is named MFA, SecretKey, SMS, or Step-Up. Preserve existing SMS acceptance and fresh Step-Up for existing-account Google/Apple linking and unlinking. Deep AAL/FAL design remains follow-up work. [S1 REQ-011–015, 070–072]
D-REVOCATION — No new online JWT lookup

Keep the accepted residual lifetime of already-issued short-lived Access JWTs after revocation. Stop future refresh/new issuance at the correct session/family boundary. Do not add per-request RP-session DB lookup, introspection, denylist dependency, or a new blanket revocation policy. Planned absolute expiry still bounds issued token lifetimes; an earlier revoke does not retroactively alter signed exp. Keep existing skew/leeway handling explicit. [S1 REQ-015, 062, 081]
D-DPOP — Conservative compatible rollout

Preserve existing per-client Bearer/DPoP policy while fixing protocol defects. Do not newly require DPoP for every browser/native client based only on server unit tests. AS nonce is optional; if elected, its challenge and retry contract must work. DBSC remains progressive enhancement with an explicit unsupported-browser path. Do not disable an established sender constraint as a fallback for a failed proof. Device validation debt is not deployment approval. [S1 REQ-016–019; N3]
D-GUID — Minimal existing-surface resolver

Keep the current configured GUID host and /api/v0/resources/<opaque-id> surface; no DNS/hostname renaming in this cycle. eid is the stored opaque business key. Default Rails :id may carry that value without exposing a numeric PK or changing the URL shape; update controller/helpers/OpenAPI together. HTML and JSON use one exact lookup. Add only the specified persistence and safe representation, not another generator, public registration API, redirect, or duplicate top-level route. Document the existing net identifier surface explicitly rather than exempting it. [S1 REQ-021–027, 033–040]
D-QUALITY — Measure without moving the gates

Keep current SimpleCov/Vitest configuration and thresholds. Historical failed-run 98.56% line coverage is not an adopted new minimum. Capture the current successful baseline using actual coverage commands; evaluate configured global/file/group/max-drop gates and explain measurement-population changes. Never claim an ordinary test run proves coverage. Do not weaken assertions, exclusions, skips, architecture rules, or protocol checks to obtain green. [S1 §13; S3 §13]
D-DEBT — Finish the bounded cycle, retain new questions

New abstract design, performance, potential-vulnerability and validation issues are first-class findings in misc.md, not invitations to expand this run indefinitely. “Potential” remains potential until supported; “known required fix” stays required. Deferral is not risk acceptance and is never evidence that a route is safe to deploy.
4. Execution workflow and dependencies

Read AGENTS.md and only the applicable indexed rules. Use the actual repository entry points; do not invent test commands or install speculative infrastructure. Repository prose, comments, test names and memos are English; localization remains in the relevant locales. No new included do/prepended do, broad rescue, silent environment fallback, or test-only application behavior. [H4]
Phase	Goal	Dependency for final runtime verification
E0	Safe execution environment, source/state snapshot, attributable baseline	None
E1	Authorization-code ownership, atomic consumption, cross-store failure safety	E0
E2	Base/Auth admission and authority cutover, including local entry	E0
E3	Auth event/freshness/assurance and ORG methods	E1, E2
E4	Shared seven-RP mechanics, session hierarchy and administration	E1, E2, E3
E5	DPoP/DBSC automation and explicit validation debt	E1, E3, E4
E6	OTP/Turnstile/email, social Step-Up, sign-out cookies, inert Create UI	E0 for local UI/verification work; E2/E3 for final auth flows
E7	/sessions, Activities, preferences and absolute expiry	E3, E4
E8	Routes/root/API/OpenAPI/GUID convergence	E0 for inventory/GUID; E2/E4/E6/E7 for final integrated inventory
E9	Repository-wide semantic timestamp/private-test/visibility cleanup	E0 green-baseline gate; targeted edits use completed affected boundaries
E10	Final verification, documentation, ledger and memo closure	All attempted phases and explicit residual dispositions

Suggested single-writer order: E0 → E1 → E2 → E3 → E4 → E5 → E6 → E7 → E8 → E9 → E10. Small E6 work may run earlier when independent. Dependencies concern semantic integration and validation, not a prohibition on independent static work. Do not let concurrent agents write the same files, index, migrations or worktree. Do not require another agent or another full planning cycle to close a phase.

Per slice: inspect current behavior → add a public/contract RED test → make the smallest coherent change → GREEN → refactor → affected regression checks → record evidence and findings → isolate local commit when authorized. If a required behavior already exists, prove it instead of changing it. If runtime tests are unavailable, label the slice IMPLEMENTED_UNVERIFIED and do not claim GREEN.

Use these progress states only: PENDING, IN_PROGRESS, VERIFIED, IMPLEMENTED_UNVERIFIED, ALREADY_SATISFIED_VERIFIED, DEFERRED_VALIDATION, DEFERRED_FINDING, BLOCKED_SLICE, SUPERSEDED_PROCESS. A current requirement may be deferred only under the bounded rules below and with its reason, owner, containment and next action visible. Report it as incomplete, not satisfied.
5. Phase specifications and acceptance tests
E0 — Safe environment and baseline

Inspect first: config/database.yml, all multi-DB ancestors/roles, config/ci.rb, test/test_helper.rb, Valkey connection/bootstrap code, test namespace/cleanup, .simplecov, vitest.config.ts, package scripts and the accepted non-production topology ADR. The previous report's environment observation is historical; re-evaluate effective test configuration after all environment-loading rules. [S3 §§2, 12, 13]

E0-T1 — Isolation proof. Before Rails boot that can touch services, fixtures, db:prepare, CI, a server, or failure injection, identify every PostgreSQL database/role/credential target and every Valkey database/namespace/connection used by test, including jobs, cache, rate limits and auth state. Resolve explicit test settings; inspect safe target identity without printing secrets. /5 instead of /2, a host containing “test,” or RAILS_ENV=test alone is not proof. Logical DB indexes are not access-control boundaries. Prove that the run cannot mutate shared development/production state; use a dedicated disposable instance, or test-only databases/credentials plus strictly scoped cleanup on the accepted isolated test service. Verify all relevant background work and HTTP egress are stubbed/disabled by the existing test harness.

Create or initialize new disposable test-only resources through the existing supported local setup when available, without publishing datastore ports to the host, changing shared .env, editing external infrastructure, or dropping/resetting an existing database. This authorizes setup of an empty isolated test target, not destruction of existing data. No shared-service fallback, FLUSHDB, FLUSHALL, or broad key deletion. Keep one-Valkey/six-logical-DB topology as the accepted non-production configuration; do not redesign deployments to obtain a green test. Fix an actual test-configuration defect explicitly and add a configuration contract regression.

E0-T2 — Baseline. Record HEAD, staged/unstaged/untracked paths, resolved plan/memo paths, command/exit status, Rails counts/skips/reasons, ordinary JS results, explicit Ruby/JS coverage, static/security results. Protect unrelated user changes. Inspect bin/ci before it prepares databases. Capture the current suite once as attributable baseline; do not keep repeating the same environmental failure.

E0-T3 — Driver/concurrency. Verify selected hiredis transport through the actual connection layer, per-worker/per-run namespace isolation, and bounded cleanup on real isolated Valkey. Do not substitute an in-memory mock for Lua/concurrency guarantees. PostgreSQL constraint/race tests use the real disposable database. Use repository-selected worker settings; do not copy arbitrary concurrency values from an old report.

If isolation cannot be established, record precise missing capability and prohibited target, stop only mutating runtime operations, and continue safe static work, source/test preparation and documentation. Do not remove security tests or broaden test-only production branches. Broad destructive test cleanup in E9 remains gated; no “all tests passed” claim is allowed.
E1 — Authorization-code exchange and cross-store failure safety

Likely touchpoints: app/services/oidc_token_exchange_coordinator.rb, app/services/valkey/auth_state/authorization_code_store.rb, the public token endpoint concern, corresponding service/store/request tests and existing revokers. [S2 B/C; S3 ADV-003–005]

E1-T1 — Binding before side effects. With valid same-realm client A and client B, exchange A's code successfully. Present A's consumed code using B's independently valid client authentication. Assert failure and unchanged A/B/unrelated RP Sessions, refresh families and Base session. Also test wrong redirect, wrong/missing PKCE, wrong realm, expired/corrupt code and valid same-owner replay. Use fresh client-assertion JTIs and fresh DPoP proofs unless that exact replay is under test, so an earlier unrelated guard cannot make the test vacuously pass. Revocation must target the correctly linked issuance/session/family, not a broad “current session for this client” lookup.

Fix both Ruby and Lua binding/order checks, including an issued→consumed race between read and atomic consume. Retain sufficient non-secret tombstone binding metadata to evaluate the contract. Never remove valid same-owner replay denial/revocation merely to stop a cross-client side effect. RFC 6749 requires code reuse denial and binds the code to client/redirect; the tighter side-effect assertions here are project tests. [N2]

E1-T2 — One-time and pending-replay races. Concurrent valid consumption has one successful authorization-code redemption. Test replay while the first exchange is between consume, DB mutation, family link and commit. A replay revocation request must not disappear because a family reference has not yet been linked, nor let an in-flight issuer later produce success after it should have been fenced. Existing protocol errors and owner-scoped revocation semantics remain explicit. Do not introduce code reuse grace; this is not the separate refresh-token race policy.

E1-T3 — Required family-link outcome. Handle the actual linked/missing/invalid_state outcomes and Valkey exceptions explicitly. Only a positively established required link permits issuance success. Record an owner- and generation-bound operation correlation using the smallest existing compatible mechanism. PostgreSQL transactions and Valkey scripts do not form a distributed transaction; do not claim exactly-once end-to-end delivery. Avoid broad rescue-and-continue.
Failure injection	Required outcome / observation
Before code consume	No new token/session mutation; follow the specific proof/client-error retry contract.
Consume timeout or ambiguous result	Never restore the code to issued. No success without confirmed state; a new authorization is the safe restart.
Consumed; link exception / missing / invalid_state	No successful token response. Inspect DB session/generation and tombstone; apply explicit forward repair/containment, not invisible rollback assumptions.
Link acknowledged; signing or DB commit fails	No success. Stale link is harmless, owner/generation-bound and accounted for. A delayed repair cannot revoke a later unrelated successful generation.
Same-owner replay during pending issuance	Retain/fence the revocation decision until linkage/commit resolution; no missing-reference no-op that loses security state.
DB committed; HTTP response lost	Do not resend tokens under an already-consumed code or reopen it. Follow the documented fresh-authorization restart; contain superseded/orphaned issuance at its own boundary.
Cleanup/compensation also fails	Preserve durable correlation where possible, fail closed, produce a sanitized actionable failure, and leave a high-priority deployment-blocking finding. Logs alone are not the authoritative security record.

Use per-operation/generation fencing and existing store/DB primitives where sufficient. If a small durable exchange record or outbox is necessary, keep it narrowly typed and actor/DB-owned; do not build a general distributed-workflow framework. Failure recovery may reduce availability; it must not authenticate an unbound client or make an uncertain consumed code reusable. Unavailable real-cluster failover/load validation is a follow-up finding, not evidence that injected tests cover all outages.

E1-T4 — DPoP preflight boundary. Establish client and request/proof validity before irreversible consumption when compatible with the protocol. If nonce is required, return the correct challenge before consumption so a valid nonce retry can succeed; verify the actual response headers/error. Ordinary invalid proofs may require a fresh authorization according to the explicit contract; do not promise unrestricted retries. Keep proof-JTI consumption distinct from authorization-code consumption. Full DPoP work continues in E5.

Done: Public endpoint and real-store tests prove binding, one-use behavior and explicit partial-failure outcomes. A source reorder alone is insufficient.
E2 — Base/Auth authority and local-entry completion

Likely touchpoints: Auth admission/controller inheritance, AuthenticationSessionCommitter, current AuthenticationBase callers, Base admission/authorization coordinators and transaction models, Base/Auth roots, per-surface request/ceremony tests. [H2/H3; S2 D; S3 ADV-006]

Implement D-ENTRY and D-AUTHORITY. First enumerate all reachable app/com/org credential and continuation paths, including direct and RP-originated sign-in, signup, social callbacks/linking, Step-Up, Entra, SecretKey, Emergency and sign-out. Inspect inherited callbacks, not just leaf includes. Do not globally rewrite every log_in call without classifying its actual surface and purpose.

E2-T1 — Admission matrix. For each relevant surface/purpose, test absent, valid, expired, replayed, wrong-purpose, wrong-actor, wrong-browser and wrong-realm handoff/continuation/result. Inspect emitted cookies, root and RP-session rows, ceremony records and authorization side effects. Mutating credential endpoints cannot be reached just by bypassing the selector or carrying a stale login-challenge string.

E2-T2 — Two complete flows. (a) Anonymous Base local entry → Auth ceremony → Base acceptance → Base root, with no fake RP artifacts. (b) actual RP → Base → Auth → Base → validated RP callback. Test no-admission Auth navigation and prove it no longer produces a Base↔Auth link loop. Test signup policy and local/actual-RP distinction. Base performs final identity/account/session acceptance; Auth temporary registration/evidence is not independent account authority.

E2-T3 — Session ownership and concurrency. Preserve session fixation prevention, host-only cookie scope, lifetime/idle/session-limit checks, actor lock and first-completed-wins browser concurrency. No unconditional bootstrap_actor: true to bypass limits for ordinary sign-in. Preserve only deliberate transaction continuity across rotation. An already-authenticated normal entry does not create another session. Reauth/link/Step-Up is explicitly bound to the current actor and authorized purpose.

E2-T4 — Legacy retirement. Remove directly dependent Auth RP callback/config/state-exchange/logout paths and stale tests only after replacement boundary tests exist. Keep allowed ceremony state, social-provider callback contracts, active Jump signing/JWKS/return verification and valid credential-management continuations. Separate cookie detachment from server authority revocation. Update the affected ADR/route map instead of leaving contradictory active claims.

Done: Auth has no independent Base/RP identity-session/token/final-assurance authority, local sign-in is usable, and each realm's request tests demonstrate the distinction. New UX alternatives go into misc.md, not another entry-policy gate.
E3 — Authentication event, freshness and ORG methods

Likely touchpoints: OidcAuthorizationCodeIssuer, ConsumedCode, exchange/refresh issuers, Base authorization parameter allow-lists and transactions, RP request builders/validators, event/session fields, ORG selector/SecretKey/Entra/Emergency concerns and tests. [S2 A; S3 ADV-001/002; S1 REQ-051–056]

E3-T1 — T0/T1/T2. Authenticate at T0, issue code at T1, exchange at T2 with T0<T1<T2. The accepted authentication event remains T0 in the ID Token and the project's Access JWT contract; issuance iat is separate. Test refresh and repeated authorization without fresh authentication, actual reauthentication with a new accepted event, absent/untrustworthy history and clock-boundary handling. Remove the ConsumedCode#created_at detour and the issuance-time fallback rather than merely fixing one assignment.

E3-T2 — Freshness end to end. Preserve max_age/prompt from RP construction through Base parsing, transaction persistence, resumed authorization, final claim and RP validation. OIDC defines auth_time as authentication time, requires it in an ID Token when max_age is used, treats max_age=0 like prompt=login, and forbids UI under prompt=none. Apply these as protocol constraints, not as product Step-Up equivalence. [N1]

Test: sufficiently recent and stale sessions; boundary age; max_age=0; prompt=login; prompt=none with/without a sufficient session; incompatible prompt combination; malformed/non-scalar/negative maximum age; parameter loss across Auth return. Return the appropriate OIDC error only to a validated client redirect; no redirect to an unvalidated URI. A guest-only ordinary login guard must not accidentally prevent legitimate Base-authorized same-actor reauthentication.

E3-T3 — Assurance and mode survive all boundaries. Trace acr, full actual amr, accepted event time and explicit authentication context through evidence, Base, code, RP issue/refresh and DBSC renewal. Test Emergency→Base→RP→refresh stays Emergency and cannot Step-Up or gain normal write authority. Missing/unknown context in newly issued org credentials is not silently normal. Distinguish session-limit restriction from Emergency context. Do not auto-upgrade assurance from an event name or change accepted SMS policy.

E3-T4 — Three ORG entries actually work. Keep Entra single-tenant/pre-provisioned/no-JIT controls. Implement the explicitly requested independent normal SecretKey entry, not just a link to an Entra-only second stage. Use the existing canonical Operator public identifier as locator when the credential has no self-contained owner locator; normalize it once and bind verification to that owner. Do not expose numeric IDs, weaken the verifier, fake an Entra-completed transaction, or let a submitted identity overwrite a server-bound actor. Preserve CSRF/Turnstile/rate limits/lockout/enumeration defenses. Preserve the existing genuine Entra second-stage flow where used.

Emergency remains the separate identifier+Passkey restricted path, not an automatic normal fallback. Block normal↔emergency conversion within an existing session; require proper sign-out and a new sign-in. Show signup only where the actual org provisioning policy permits it. Locale, branding, host and policy tests cover all visible controls and targets.

Done: Timestamp and freshness assertions are values/behavior assertions, not mere claim-presence checks; ORG method entries complete the right admitted flow without weakening existing safeguards.
E4 — Shared RP/session hierarchy

Reuse existing RP/session/store abstractions. The source already reports ClientRpSession/VisitorRpSession/OperatorRpSession; do not repeat a completed TokenUsage rename. Keep seven independent client IDs/keys/registry entries; shared Edit/Core/Side mechanics accept explicit immutable boundary configuration and support multiple Core/Side deployments. [S1 §§2, 11.G3]

E4-T1: A reusable request/contract suite covers state, nonce, PKCE S256, exact redirect, issuer/audience/type/signature/ES384, wrong realm, callback replay/error, session fixation/rotation and logout. Run it for all seven identities, including Edit. Host-only short-lived encrypted RP browser transactions support competing tabs without silent overwrite; return targets are validated local targets. Do not send provider traffic live.

E4-T2: PostgreSQL assertion-JTI uniqueness and active (Base session, RP client) uniqueness survive races. Test Identity → Base Browser Session → RP Session ownership and selective versus parent revocation. Regular Access-JWT requests must not gain RP-session DB queries; normal identity/policy queries are not falsely described as “zero database access.”

E4-T3: Admin UI/API distinguishes registered client configuration from an individual's active RP session. Owner/realm authorization and stable public identifiers remain; user-facing pages need not expose internal registry/Binding fields.

Done: Edit uses the same protocol primitives; Core/Side regressions pass; no Auth RP is restored. Native/Palm policy not inferable from the browser registry is classified, not invented.
E5 — DPoP/DBSC automation and bounded validation

E5-T1: Audit actual token endpoint, refresh and Resource Server use of DPoP: accepted algorithm/key, embedded public JWK, thumbprint/cnf.jkt, htm, canonical htu, time window, fresh jti, key mismatch, and ath where an Access Token is presented. DPoP and client authentication remain different controls. Keep per-client Bearer/DPoP and metadata consistent. Do not add ath requirements to a code-exchange proof that presents no Access Token.

E5-T2: RFC 9449 nonce is optional. If current policy elects it, test use_dpop_nonce/DPoP-Nonce, valid challenge retry and wrong/stale/replayed proofs against E1's consume boundary. If it is not elected, state that explicitly instead of claiming a defect solely from header absence. [N3]

E5-T3: Trace DBSC registration → device/key association → proof → renewal → expiry → logout/revoke, including replay and unsupported-client fallback. Device binding is not Emergency mode, authentication assurance, or immediate JWT revocation. Use runtime-path tests, not just object-existence tests.

Document supported automated contracts, unsupported/unverified client paths, required representative browser/device matrix, and deployment prerequisites in the normal plans structure plus linked misc.md entries. Do not manufacture browser-version support claims or enforce a new global policy without interoperability evidence.

Done: Automated protocol/runtime gaps are fixed and tested; physical validation is explicitly DEFERRED_VALIDATION, not a whole-project NO-GO and not marked passed.
E6 — OTP/Turnstile/email, social links, sign-out and inert UI

HEAD already contains reported signup-email retention, signin reset, disabled Create and social-link Step-Up work. Inspect the existing implementation and tests first; retain verified changes and fill only genuine gaps. [S3 §§2.9, 13]

E6-T1: app/com × signup/signin normal email flows. Initial email form GET is empty; an allowed 422 restores the submitted email only in response props, not logs or server session. OTP may exist transiently while being entered/submitted, but never persists in remembered React/Inertia state, session/flash, re-rendered props/HTML or later history after failure. Clear on invalid/blank/rate-limited/locked/error/resend paths; inspect reused components and browser back behavior. Never set a non-empty OTP input value from a previous response.

E6-T2: Require visible and server-validated Turnstile for the specified OTP checkpoints, before OTP verification/attempt decrement/session creation. Missing/invalid challenge leaves OTP attempt and domain lockout/session state unchanged; ordinary request-rate-limiting may still apply. Enforce configured hostname/action/context expectations. A browser widget alone is insufficient; Turnstile tokens are single-use and expire after 300 seconds. Obtain a fresh challenge after failures; timeout/unavailable service must not fall through to OTP. [N4]

Keep enumeration/dummy-account paths observably equivalent. Reconcile the earlier “no extra checkpoint challenge” ADR with the explicit current requirement, rather than deleting the new requirement as stale. Do not replace state machines or bypass admission to simplify tests.

E6-T3: Scope the Visitor recovery identity preload to the actual top-up operation, preserve validators and Client behavior, and compare query counts for email, telephone and absent recovery identity cases (including multiple recovery credentials). Avoid cache tricks that hide a changed authorization decision.

E6-T4: Purpose-specific localized branded mail subjects for app/com share the existing mailer/i18n path. No OTP, raw identity/secret/token in subject; preserve required message body and existing provider behavior. Test locale × purpose without sending real mail/SMS.

E6-T5: Preserve fresh Step-Up for linking/unlinking Google/Apple to an existing account; signup enrollment is distinct. Do not treat a fresh ordinary sign-in as an automatic replacement for the adopted linking requirement. Keep the existing STAY ADR if already correct, and test callback bypass/last-method guards.

E6-T6: Reproduce sign-out through browser-visible completion. Verify complete Set-Cookie scope and CookieJar effects for both access/refresh cookie names, including prefixed variants and formerly used scopes that current code actually issued. Cookie deletion is not server revocation and vice versa. Verify immediate new sign-in and app/com/org isolation. Change shared deletion logic only if a mismatch is demonstrated. Do not make a sign-out GET mutate session authority.

E6-T7: Shared Create controls remain disabled buttons without href, event-based navigation, submit behavior or write requests. Account/Organization/Avatar mocks add no provisioning route or policy. Avatar Up uses the currently valid authenticated home helper and preserves ri; do not point Base back at a retired /dashboard. Existing real Avatar creation stays unchanged.

Done: Four OTP flows, challenge failures, non-retention, cookies and mocked actions are verified. A no-op is an acceptable production diff where current behavior already passes the requirement.
E7 — Sessions, Activities, preferences and expiry

E7-T1: Move user session management to owner-scoped resourceful /sessions across app/com/org, including helper/navigation/Step-Up-scope catalog/React/OpenAPI callers. Keep /sign/out independent and Core /api/v0/session as its different BFF contract. Reject foreign IDs/realms, preserve CSRF and action authorization, and perform no GET revocation. Current-session and other-session actions respect Base/RP ownership without added normal-request session queries.

E7-T2: Activity event type, risk rank and visibility stay independent; reuse existing presenters/static metadata. Exclude internal events in SQL before pagination, counts or grouping, not only in React. Normalize user descriptions. Test props and rendered output for absence of internal IDs, raw context, full/private IP information, credentials, tokens and internal enums; HTML escaping and authorization remain intact.

E7-T3: Show actual Device or localized Unknown, current label, last activity and proven session expiry. Hide Kind/Binding/internal IDs/refresh TTL from ordinary user UI. Administrative technical data remains behind its appropriate authorization. Emergency derives only from explicit context, never from DBSC/device presence.

E7-T4: Prove discarded_at semantics for Client, Visitor and Operator along creation, refresh rotation, Access/ID/Refresh issue, DBSC renewal, lookup and termination. Reuse it if it is truly the non-sliding absolute ceiling. Rotation and repeated authorization cannot extend the ceiling; no issued expiration exceeds it. Test exact and leeway-aware boundaries. No refresh/renewal resurrects expired or revoked state. Do not confuse planned absolute expiry with an earlier revoke under D-REVOCATION.

If evidence disproves the field's meaning, introduce only the minimal explicit semantic timestamp within the owning DB/model contract, with non-destructive schema verification on disposable data. Never infer a historical event from created_at just to fill a new NOT NULL field. Unknown old authentication history requires reauthentication; unknown optional UI history is unknown, not fabricated.

E7-T5: Reuse SessionTimestampHelper or the actual established equivalent. Apply preference timezone/date/clock consistently and sort/paginate by stored instants. Test day/year/timezone/DST boundaries where supported, 12h/24h and locale, all three surfaces, and bounded query counts. Do not create another formatting layer or risk/visibility tables.

Done: /sessions works as its own resource, only safe user fields appear, expiry is enforced rather than merely relabeled, and formatting/sorting are consistent.
E8 — Routes, roots, GUID and OpenAPI

Inventory config/routes* and config/routing* if present, controller ownership, URL helpers, active proxy/client references, actual JSON endpoints and protocol exceptions. After E0 isolation, obtain runtime routes/notes; static inventory remains useful when boot is unavailable. Do not treat route existence alone as an implementation. [S1 §§2, 11.G8; S3 §§2.10–11]

E8-T1: Prefer resource(s) plus namespace; default :id carries existing opaque identifiers, not database PKs. Avoid unnecessary as, controller, custom params, imperative get/match and route loops. Preserve justified CSP and /.well-known path: mappings and explicitly classified OAuth/OIDC/WebAuthn/DBSC/operational contracts. Do not mechanically force protocol paths under /api/v0.

Migrate valuable application /web/vN//edge/vN APIs to the established /api/v0/Api::V0 organization with all callers/tests/contracts in one coherent slice. Remove dead routes only with call-site and contract evidence. This project is not asking for compatibility shims for an undeployed design; do not invent dual stacks. That permission does not authorize deleting real data or breaking an externally configured provider callback. A valuable unresolved endpoint gets a narrow actionable FIXME linked to misc.md, never a broad exclusion.

E8-T2: Verify the actual 14-surface inventory: Auth/Base/Core/Side × app/com/org, Palm app, Edit org. Base authenticated root keeps its existing guarded dashboard content; anonymous Base root follows D-ENTRY. Do not restore retired Auth/Base /dashboard or Base /lobby. Auth is public ceremony entry. Side/Core/Edit use their real current contracts; Core/Palm do not gain fictitious dashboards or redirects to JSON profiles. Temporary auth-dependent redirects preserve validated ri and correct host; private content stays protected.

E8-T3: Implement the minimal GUID record in the existing identifier-owned persistence boundary, with unique NOT NULL opaque eid, required bounded kind/status and nullable safely represented canonical URL. Check length/encoding/one-time decoding, exact-match semantics, parameterization and escaping. Unknown ID is 404; store outage is 5xx; canonical URL never becomes an automatic redirect. No new ID algorithm/gem, catch-all or registration endpoint. Test actual DB uniqueness, HTML/JSON parity, malformed ID, wrong host, null URL and no Location header. No hard deletion/reuse path is added; long-term tombstone governance can be a next-cycle finding.

If the repository has no established identifier persistence owner and creating one would require new external infrastructure or arbitrary attachment to an authentication DB, isolate only that persistence decision as BLOCKED_SLICE, retain non-redirecting safe behavior, and document the exact missing owner. Do not claim a 404-only placeholder satisfies resolver success.

E8-T4: Extend the existing OpenAPI registry/generation conventions to the real public GUID net and Edit scopes; this is a documentation/contract ownership decision, not permission to add a new deployed surface. Cover every actual application JSON route, parameters, statuses, security and content negotiation. Keep protocol exemptions narrow, enumerated and justified. Update source and generated bundles; run lint, bundle, idempotence and contract coverage. Generated output matching an obsolete source is not sufficient.

Done: Known routes and callers converge, valid protocol exceptions remain, GUID has evidence-backed success/failure behavior or an explicitly isolated residual, and API documentation matches actual reachable contracts.
E9 — Semantic timestamps and private-test/visibility cleanup

Perform broad cleanup only after an attributable green baseline; necessary E1–E8 repairs are not held hostage to that gate. Inventory production callers and tests before deleting or changing visibility. [S1 REQ-045–050, 066–069]

E9-T1: Classify all meaningful created_at/updated_at uses as legitimate persistence metadata versus domain time. Audit queries/order/periods/expiry/serialization/views and fixtures, not just obvious labels. Preserve metadata itself when useful. Introduce actual event fields only where lifecycle evidence supports them; unrelated updates must not alter domain events. No mechanical renaming to inserted_at, fabricated backfill, or alias that masks missing semantics. Test actual alias reads/writes/query/update paths when a justified alias exists.

E9-T2: Classify direct private-method tests into public-behavior replacement, already-covered behavior, proven dead code, or genuine protected extension contract. Add meaningful public/framework-boundary tests before removing coupling. Do not “fix” tests by making helpers public, calling them through reflection in renamed helpers, or deleting negative coverage. Keep Rails actions, callbacks and framework-used methods at the visibility their real contract requires.

E9-T3: Reduce unjustified public APIs; use protected only for real extension contracts, private for internal helpers. Reuse the repository's existing static harness/custom-cop locations, with narrow justified exceptions and false-positive tests. Do not add an alternative harness directory, test-only production branch or new concern inclusion hooks.

Run narrow and periodic full coverage against unchanged gates. Legitimate removal of dead code may change the coverage population; document it rather than manipulating exclusions. If the full baseline cannot safely become green within current authorized scope, record the exact remaining batch and keep replacement tests; do not perform unverified mass deletion or mark cleanup complete.
E10 — Final verification and next-cycle handoff

Perform one bounded reverse-direction self-check: final routes/code/state transitions → actual tests/results → Appendix A → affected ADR/docs → misc.md. An independent second model is not a mandatory gate in this run. The next cycle may commission a separate review.

E10-T1: Run the actual affected-to-full verification path on isolated targets: focused public/store/integration tests; cross-surface tests; full Rails with explicit coverage; ordinary JS tests and JS coverage; repository format/lint/type/security checks; route/OpenAPI checks; canonical CI once its DB preparation is safe. A full explicit-coverage Rails run may also supply ordinary full-suite results; needless duplicate full runs are not required. Record every command/exit, counts/skips/reasons and coverage dimensions. Unavailable checks remain unavailable, not silently omitted.

E10-T2: Every REQ ID has one primary owner and final disposition with current evidence. REQ-020 is checked horizontally. Process-only requirements carry explicit supersession; REQ-095 carries the actual missing-fragment limitation. No number of passing tests cancels a known authority violation. Update only affected ADR/docs/plans and keep required follow-up exit criteria; do not perform a repository-wide prose purge.

E10-T3: Preserve and update misc.md with deduplicated, source-linked findings and current containment. Keep a flat dated Markdown evidence summary under the established evidence/ rules for work actually performed. Stop local test servers/owned processes and report remaining staged/unstaged/untracked files and verified local commits. No GitHub/external write or deployment.

Report separately: implementation outcome, verification outcome, and deployment prerequisites. Valid outcomes include “implemented and verified with deferred physical validation” and “completed independent slices; X blocked/unverified.” Do not write “all 95 requirements implemented” when process supersessions, a missing fragment, or unresolved slices remain.
6. misc.md recording and deferral contract

misc.md is the next-cycle analysis register, not a second execution plan and not a repository of secrets. Record a finding when first discovered; refine it as evidence improves. Use stable IDs and merge duplicates by root cause. Do not overwrite old observations when resolving them; add the resolution and evidence.

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

Examples of valuable abstractions: a one-time code and revocation metadata split across stores; authentication evidence losing mode/freshness at a service boundary; two presentation layers reinterpreting persistence timestamps; a growing number of network round trips per credential exchange; a callback test that passes because a different earlier guard rejects the request.

Record p50/p95/p99, lock waits, query count, allocations or Valkey round trips only when actually measured, with workload/environment/sample size. Do not invent latency budgets or observed vulnerability severity. Do not store raw tokens, codes, OTPs, cookies, email/phone lists, credentials, full production URLs containing secrets, or exploit materials for live systems. Keep reproduction in disposable tests.
7. Local stop rules — not a blanket project veto
Finding / condition	Required action
Hypothesis, abstract debt, missing performance measurement, unverified device support	Record in misc.md, keep established boundaries, continue current tasks.
Required behavior fails a current isolated test	Fix the smallest in-scope cause, rerun, continue. This is implementation, not a demand for another full plan.
A new change would create an auth bypass, cross-realm access, secret disclosure, wrong-owner revoke or silent corruption	Do not enable that unsafe slice. Repair within scope or contain at that boundary; preserve evidence and continue independent work.
Test/CI could touch shared development/production DB/Valkey or send live provider traffic	Stop that runtime command; establish isolation or mark it unavailable. Continue safe work.
New external write, production deploy, deleting existing data, material new product/authority policy outside §3	Not authorized. Do not perform it; record exact next-cycle decision.
Existing blocker cannot be fixed safely	Record BLOCKED_SLICE and deployment restriction. Never suppress a test or claim the blocker was solved by deferral.

No unattended risky command is justified by “the user is asleep.” No routine question is needed for choices already fixed in §3 or for ordinary bounded implementation details. Do not expand the run into unrelated redesign merely to remove every entry from misc.md.
8. Final run report template

    Actual starting/ending HEAD and protected pre-existing changes; resolved plan/memo paths.

    Phase/REQ completion table with exact VERIFIED, ALREADY_SATISFIED_VERIFIED, deferred, blocked and unverified distinctions.

    Important decisions implemented: D-ENTRY, authority, event time, owner-bound replay and partial-failure behavior.

    Commands/exit statuses, Rails and JS ordinary/coverage results, skips and reasons, current failures and attribution.

    Files/verified local commits; no unstated external state change.

    misc.md finding IDs grouped by current deployment blockers versus next-cycle analysis/validation.

    Remaining runnable work and precise restart points, without a new planning-only veto over completed independent work.

Appendix A — Recovered 95-requirement ledger and primary ownership

This is an English execution restatement of the exact recovered S1 ledger, not a claim that the original P00–P17 prompt bodies beyond it have been recovered. Parenthetical cycle adjustments are explicit. The original Japanese ledger is available in the supplied historical source file. The acceptance references below point to concrete tests in §5 or the file/progress rules above. There is exactly one primary owner per ID; secondary regression checks do not create duplicate ownership.
Requirement	Primary owner	Execution requirement / explicit disposition	Acceptance evidence
REQ-001	E0	Prior planning run is read-only; in this new Goal run local implementation is authorized, while GitHub/external writes remain prohibited. (Planning-only scope superseded; remote boundary retained.)	§1; E0-T2; E10-T3
REQ-002	E0	Preserve source precedence and record conflicts; the latest user-authorized cycle decisions explicitly resolve earlier ambiguity.	§§1–3; E0-T2
REQ-003	E0	Prior 18-section planning/audit deliverable is historical; do not repeat it as an implementation gate. (Process supersession.)	§§1, 4, 8
REQ-004	E0	Retain the executable plan at resolved refactor.md path without destroying a directory or user content.	§1.1
REQ-005	E0	Use isolated local commits only for verified steps; preserve all unrelated Git changes; never publish them.	§1; E0-T2; E10-T3
REQ-006	E0	Stop owned local verification servers/processes when no longer needed.	E10-T3
REQ-007	E2	Base is the sole physical IdP/Authorization Server authority.	E2-T1–T4
REQ-008	E2	Auth is credential ceremony only, with no independent identity/Base/RP-session/final-AAL/token authority; allowed ceremony continuity remains.	E2-T1–T4
REQ-009	E2	Actual RP flows follow RP → Base admission → Auth → Base → code/result → actual RP.	E2-T2; E4-T1
REQ-010	E2	No admission bypass or fabricated RP transaction; standalone entry/completion is fixed by D-ENTRY for this cycle. (Earlier undecided UX resolved explicitly.)	D-ENTRY; E2-T1–T3
REQ-011	E3	auth_time is the accepted authentication event, never refreshed by code/token issue, exchange, callback or ordinary refresh.	E3-T1/T2
REQ-012	E3	Base accepts acr; amr represents methods actually used and survives reissuance.	E3-T3
REQ-013	E3	Separate sign-in, Step-Up, achieved AAL, phishing resistance, freshness and FAL; bound this cycle and record deeper follow-up.	E3-T3; §6
REQ-014	E3	Keep explicit SMS risk acceptance without calling SMS phishing-resistant or automatically AAL2.	D-ASSURANCE; E3-T3
REQ-015	E3	Retain natural expiry of already-issued short-lived Access JWTs after revocation; no new immediate revocation lookup.	D-REVOCATION; E4-T2
REQ-016	E5	Audit/fix DPoP to RFC 9449 and strengthen only appropriate compatible clients.	E5-T1/T2
REQ-017	E5	DBSC remains progressive enhancement with usable fallback and tested runtime lifecycle.	E5-T3
REQ-018	E5	Never call unperformed physical/client interoperability validated; record specific validation debt.	E5; §6
REQ-019	E5	Maintain concrete follow-up analysis/plans for local-entry refinements, AAL/FAL and DPoP/DBSC validation.	E5; §6; E10-T2/T3
REQ-020	E10	Never weaken authentication security controls, coverage or negative tests. Horizontal invariant for every phase.	All E*-T*; E10-T1/T2
REQ-021	E8	Resolver is opaque lookup only; no ID generator, new scheme or new gem.	D-GUID; E8-T3
REQ-022	E8	Persistent eid is unique/non-null; kind/status required; canonical URL nullable; validate bounded input.	E8-T3
REQ-023	E8	Use a scoped resource lookup route, not a top-level catch-all; retain existing API/host contract.	E8-T1/T3
REQ-024	E8	HTML/JSON share exact lookup; unknown identifier is 404 and backend failure is 5xx.	E8-T3
REQ-025	E8	Canonical URL never triggers automatic redirection.	E8-T3
REQ-026	E8	Do not add ID reuse or public registration; preserve uniqueness/no hard-delete path in the PoC.	E8-T3; §6
REQ-027	E8	Test injection, escaping, decoding, input length and identifier-surface isolation.	E8-T3
REQ-028	E4	Core/Side/Edit reuse equivalent RP protocol mechanics.	E4-T1
REQ-029	E4	Edit specificity is boundary configuration; shared code has no singleton deployment assumption.	E4-T1
REQ-030	E4	Preserve state/nonce/PKCE/issuer/audience/exact-redirect/JWT-profile/session/logout safety.	E4-T1/T2
REQ-031	E4	Test observable RP callback failures, replay, exchange, rotation and logout without live IdP traffic.	E4-T1
REQ-032	E4	Never restore Auth as an RP; preserve Base ownership and multi-instance RP support.	E2-T4; E4-T1
REQ-033	E8	Retain justified CSP and .well-known path mappings rather than blindly removing overrides.	E8-T1
REQ-034	E8	Inventory actual route files and api/web/edge prefixes using source and safe runtime evidence.	E8-T1/T4
REQ-035	E8	Converge valuable application APIs on resourceful /api/v0 and Api::V0 while preserving service/realm boundaries.	E8-T1/T4
REQ-036	E8	Remove only evidence-backed dead routes; retain narrow actionable FIXME for valuable unresolved contracts.	E8-T1; §6
REQ-037	E8	Prefer default opaque when callers/URL/security remain safe; never expose database PKs.	E8-T1/T3/T4
REQ-038	E8	Describe all actual application JSON APIs, including Edit/GUID, in the correct OpenAPI scope.	E8-T4
REQ-039	E8	Keep OpenAPI source/bundle aligned and run lint/bundle/idempotence/contract verification.	E8-T4
REQ-040	E8	Keep protocol exemptions narrow and retain auth/CSRF/cache/content/error contracts.	E8-T1/T4
REQ-041	E8	Verify each actual surface root and its authenticated/anonymous meaning.	E8-T2
REQ-042	E8	Preserve validated ri, temporary auth-dependent redirects and private-home authorization.	E8-T2
REQ-043	E8	Do not invent Core/Palm dashboards or redirect native/API entry to inappropriate JSON/browser pages.	E8-T2
REQ-044	E8	Follow current Base/Auth root architecture; do not restore retired dashboards/lobby.	D-ENTRY; E8-T2
REQ-045	E9	created_at/updated_at are persistence metadata, not inferred domain-event timestamps.	E9-T1
REQ-046	E9	Any timestamp alias must have proven read/write/query semantics; avoid updated_at aliases.	E9-T1
REQ-047	E9	Backfill or remove relationship timestamps only with lifecycle/history/use-site evidence.	E9-T1; §7
REQ-048	E9	Add narrow semantic/visibility guards in the existing harness with justified exceptions and false-positive tests.	E9-T1–T3
REQ-049	E9	Domain times update at the right transition and not on unrelated persistence updates.	E9-T1
REQ-050	E9	Private-test cleanup preserves unchanged SimpleCov gates and replacement behavior coverage.	E9-T2/T3; E10-T1
REQ-051	E3	ORG sign-in presents Entra, independent normal SecretKey and restricted Emergency entries.	E3-T4
REQ-052	E3	Keep Entra single-tenant/pre-provisioned/no-JIT and its PKCE/state/nonce contracts.	E3-T4
REQ-053	E3	SecretKey normal sign-in can start independently while preserving owner binding and existing security controls.	E3-T4
REQ-054	E3	Emergency stays identifier+Passkey restricted access, not normal fallback or in-session mode conversion.	E3-T3/T4
REQ-055	E3	Show ORG signup only if existing self-service/provisioning policy permits it.	E3-T4
REQ-056	E3	Preserve ORG UI/i18n/host isolation; do not present Emergency as the recommended normal method.	E3-T4
REQ-057	E4	Seven browser RP clients have independent client IDs/keys with PKCE S256 and private_key_jwt.	E4-T1
REQ-058	E4	RP browser transactions are short-lived encrypted host-only state with safe multi-tab and return-target behavior.	E4-T1
REQ-059	E1	Valkey authorization codes are digest-keyed, short-lived, atomically one-use and fail closed.	E1-T1–T4
REQ-060	E1	Client-assertion JTI replay remains PostgreSQL-backed, unique and fail closed.	E1-T1; E4-T2
REQ-061	E4	Identity → Base session → RP session; one active RP session per Base-session/client is DB-enforced.	E4-T2
REQ-062	E4	Preserve selective/parent revoke hierarchy without ordinary-request RP-session DB lookup.	E4-T2
REQ-063	E4	Administration distinguishes client registry configuration from individual RP Sessions.	E4-T3
REQ-064	E0	Keep one-Valkey/six-logical-DB topology, structured access, selected hiredis transport and per-run/worker test namespace/no flush.	E0-T1/T3; E4/E5 regressions
REQ-065	E2	Remove legacy Auth RP dependencies while preserving ceremony responsibilities and Jump JWKS.	E2-T4
REQ-066	E0	Obtain an attributable green baseline before broad private-test/visibility cleanup, not before necessary baseline repairs.	E0-T2; E9 gate
REQ-067	E9	Classify direct private-helper tests and replace with public/framework behavior before removal.	E9-T2
REQ-068	E9	Reduce unnecessary public methods; private for internals and protected only for genuine extension contracts.	E9-T3
REQ-069	E10	Do not weaken skips/assertions/thresholds/linters/exclusions; execute and report current full gates truthfully.	E10-T1/T2
REQ-070	E6	Existing-account Google/Apple linking retains fresh Step-Up.	E6-T5
REQ-071	E6	Signup enrollment is distinct; unlink also needs Step-Up; do not automatically reuse ordinary recent login as approval.	E6-T5
REQ-072	E6	Preserve/update the STAY ADR; no production change where implementation already matches.	E6-T5; E10-T2
REQ-073	E6	Completed sign-out detaches access/refresh cookies at their actual issuance scope; fix only a reproduced mismatch.	E6-T6
REQ-074	E6	Test immediate re-sign-in, app/com/org isolation, CSRF and secure cookie attributes after sign-out.	E6-T6
REQ-075	E7	Move user session management to /sessions while retaining the separate /sign/out ceremony.	E7-T1
REQ-076	E7	Session actions are owner-scoped, CSRF-protected and non-mutating on GET; no new normal-request session lookup.	E7-T1
REQ-077	E7	Home navigation, current label and other-session termination work without internal user-facing IDs.	E7-T1/T3
REQ-078	E7	Event type/risk/visibility are independent; filter internal activity in SQL before pagination/counts.	E7-T2
REQ-079	E7	User activity excludes raw context/IP/secrets/technical enums and uses normalized safe descriptions.	E7-T2
REQ-080	E7	Show actual Device or Unknown and hide Kind/Binding/IDs/refresh TTL in ordinary session UI.	E7-T3
REQ-081	E7	Show a proven non-sliding session ceiling; issuance/renewal stay bounded and expired/revoked state cannot revive.	E7-T4
REQ-082	E7	Emergency mode comes from explicit authentication context, never DBSC binding inference.	E7-T3/T4; E3-T3
REQ-083	E7	User timestamps honor preference timezone/date/clock; sorting uses stored instants.	E7-T5
REQ-084	E7	Keep i18n, bounded queries, actor ownership and cross-surface isolation in Activity/Session pages.	E7-T1–T5
REQ-085	E6	Rails props drive inert disabled Account/Organization/Avatar Create buttons; Avatar Up reaches the valid home.	E6-T7
REQ-086	E6	Create mock has no route/write/provisioning/policy connection; real Avatar creation is unchanged.	E6-T7
REQ-087	E6	app/com signup email 422 restores permitted email value; fresh GET is empty and session/logs do not retain it.	E6-T1
REQ-088	E6	Signup OTP checkpoints require visible/server Turnstile before OTP verification or state changes.	E6-T2
REQ-089	E6	Signin OTP also requires server Turnstile before OTP verification while preserving enumeration defenses.	E6-T2
REQ-090	E6	Never retain/replay OTP after failure in props, session, flash, HTML or remembered React/Inertia state.	E6-T1/T2
REQ-091	E6	Do not reuse failed/submitted Turnstile challenge state; obtain a fresh challenge for retry.	E6-T2
REQ-092	E6	Visitor recovery top-up preloads required identity associations without weakening validators or Client behavior.	E6-T3
REQ-093	E6	Integration tests cover four normal app/com signup/signin flows; Jump is unchanged and no live provider calls occur.	E6-T1/T2
REQ-094	E6	Purpose-specific localized branded OTP mail subjects share the existing path, omit secrets and preserve body.	E6-T4
REQ-095	E10	Original ORG fragment was truncated; do not invent missing wording. Record the precise source limitation for the next cycle. (Explicit deferral.)	E10-T2; MISC-0006
Appendix B — Provenance and scope of fresh verification
Supplied primary project material

    [S1] Original 18-section plan, 貼り付けたマークダウン（1）(3).md, original-plan HEAD d7b053813bdbdafa54a77b16074804981d9355b1; SHA-256 2ae07102f486fd13c64fc45acfca65b990cc438db1098610dcb09415b52a92c8. Its §3 contains 95 unique REQ IDs. Its §9 maps only 94 unique IDs, omitting REQ-020. Historical context, not an instruction to remain planning-only.

    [S2] Sol static review, 貼り付けたマークダウン（1）(4).md, review HEAD 08fc1eeb6d2f354078787ab6f3f4e6890c774def; SHA-256 3052638bea18ef029798632f068402333638eeacd222de23bad1af05e91b8533. Source/call-path evidence; no dynamic tests performed there.

    [S3] Latest re-audit / provisional NO-GO report, 貼り付けたマークダウン（1）(5).md, reported HEAD 430ac354ba06c9d22885e1e69d027a7a1b1d5280; SHA-256 58e1db696bf72f241dd6d7d9a8dedcb5cb6baef28d4c325243a295321ca53070. Source and environment observations from that run; no current runtime health proof.

All three bytes were available to the authoring run and hashed. The first two match the values whose absence blocked S3. Appendix A is deliberately self-contained; losing the bundled source copies in a later workspace is not permission to invent new wording, nor a reason to discard the recovered ledger.
Narrow fresh GitHub reads, 2026-09-15 Japan time

All GitHub reads are GET-only and at the pinned SHA where relevant.

    [H1] feature branch returned 430ac354ba06c9d22885e1e69d027a7a1b1d5280 (commit message [CheckPoint] no-go.). This matches S3. Branch resource: https://api.github.com/repos/seahal/umaxica-apps-jit-global/branches/feature.

    [H2] app/controllers/concerns/auth_ceremony_admission.rb at that SHA: bridge_to_base_admission! sends an admission-less entry to Base /; protected flow handling uses oidc_authorization_login_challenge and allowed ceremony SID state.

    [H3] app/controllers/base/app/roots_controller.rb at that SHA: authenticated root renders the guarded former dashboard; anonymous root's ceremony_sign_in_href/ceremony_sign_up_href point at raw Auth URLs without admission.

    [H4] AGENTS.md at that SHA: scope distinguishes planning from local implementation; repository prose is English, no unrelated destructive work, no host-published datastores, no security bypasses or test-only production behavior, and evidence files are flat dated Markdown.

Pinned-file URL form for H2–H4: https://github.com/seahal/umaxica-apps-jit-global/blob/430ac354ba06c9d22885e1e69d027a7a1b1d5280/<path>.

This is not a claim of a second complete repository audit, a clean local worktree, test success, exploit reproduction, or physical device validation. Other implementation findings are attributed to S1–S3 until the executing agent verifies them.
Normative references checked

    [N1] OpenID Connect Core 1.0 incorporating errata set 2, §§2, 3.1.2.1–3 and 15.1; https://openid.net/specs/openid-connect-core-1_0.html. Normative authentication-time/freshness rules are distinguished from the project's Access JWT claim and local-entry policy.

    [N2] RFC 6749, §§4.1.2–3 and 10.6; https://www.rfc-editor.org/rfc/rfc6749.html. Authorization-code binding, single-use, reuse denial and attempted revocation. Project owner/generation/failure-injection assertions are implementation design, not claimed verbatim RFC requirements.

    [N3] RFC 9449, especially §§4–5 and 8; https://datatracker.ietf.org/doc/html/rfc9449. DPoP proof and optional AS nonce challenge contracts. Per-client rollout and pending device validation are project decisions.

    [N4] Cloudflare Turnstile server-side validation; https://developers.cloudflare.com/turnstile/get-started/server-side-validation/. Server verification, single use and five-minute token lifetime. OTP-attempt ordering and enumeration assertions are the project's stronger application contract.

No unverified model speed, model pricing, browser support matrix or implementation-duration estimate is a premise of this plan.

Addendum — Earlier provisional NO-GO assessment

This record preserves the NO-GO assessment discussed before this final execution revision. It was not saved as a separate repository file at the time. The assessment applied to freezing an autonomous implementation plan on the then-available evidence; it did not establish that every reported issue was exploitable or that the entire project must stop. The active execution authority is the bounded GO decision at the top of this document and the E0–E10 plan above.

The provisional NO-GO was based on these unresolved gates:

| Gate | Evidence available at the time | Required resolution in this plan |
| --- | --- | --- |
| Authentication-event time | The static review reported that the authorization-code issuer used `Time.current` and that exchange could derive `auth_time` from code issuance metadata. No T0/T1/T2 boundary test had established the end-to-end claim value. | E3-T1 traces accepted authentication evidence through Base, code, exchanged tokens, and refresh; use separated event, issue, and exchange times. |
| Authorization-code replay ownership | The static review reported that replay classification preceded client/redirect/PKCE binding checks in both Ruby and Lua. Cross-client revocation effects had not been exercised at the token endpoint. | E1-T1/T2 tests valid same-owner replay and wrong-client, redirect, PKCE, corrupt, expired, and concurrent exchanges while observing owner-scoped state. |
| Cross-store partial failure | The static review reported that family-link outcomes and Valkey failures might not prevent token response construction. Failure injection had not established the resulting Valkey, PostgreSQL, and response states. | E1-T3 injects explicit negative outcomes, exceptions, ambiguous timeouts, signing/commit failures, and response loss; success requires a positively established required link. |
| DPoP after code consumption | The review reported code consumption before DPoP verification and did not establish whether a nonce challenge was required on the relevant path. This alone did not prove a protocol defect because AS nonce use is optional. | E1-T4 and E5-T2 inspect the active client policy and actual endpoint error/header contract; if nonce is elected, verify challenge and valid retry before irreversible consumption. |
| Base/Auth local entry | Static route/controller evidence indicated that an admission-less Auth entry could return to Base while Base linked back to an admission-less Auth entry. No browser-visible authority transition had been reproduced. | D-ENTRY and E2 define a Base-owned local admission, keep Auth ceremony-only, and require tests for local and genuine RP flows without fabricated RP artifacts. |
| Safe test baseline | Existing notes reported green runs, but no current coverage-enabled run or complete effective test-service isolation proof had been recorded. | E0 proves dedicated disposable PostgreSQL/Valkey targets and stubbed egress before mutating test/CI commands, then captures ordinary and coverage runs separately. |
| Requirement traceability | The earlier mapping omitted REQ-020 and misassigned some requirements between phases; the full original wording and recovered source artifacts were not yet part of the working plan. | Appendix A now contains all 95 available requirement rows; REQ-020 is a horizontal invariant owned for closure by E10, and REQ-095 remains explicitly limited to the truncated source fragment. |

The first five items were unverified security or correctness risks, not claims of reproduced exploitation. The sixth was an execution-safety blocker for mutating runtime checks, not a reason to stop static work. The seventh prevented approval of the earlier plan as a complete execution specification. This revision resolves plan-input and mapping gaps and chooses D-ENTRY for this bounded cycle; it does not mark any runtime control verified. E0 remains a prerequisite for service-touching tests, and E1–E3 remain required security gates. “GO” here authorizes bounded local implementation and verification only; it is not deployment approval.

E0 execution record — 2026-09-14 UTC, HEAD 430ac354ba06c9d22885e1e69d027a7a1b1d5280

Initial and ending Git state: branch `feature`; no tracked or staged changes; `misc.md` and `refactor.md` were pre-existing untracked files. This run appended the NO-GO record and E0 results to `refactor.md`, at the user's request, and added the corresponding findings to the end of `misc.md`. No checkout, staging, commit, database connection, Valkey connection, server, provider request, or GitHub operation was performed.

Safe frontend checks: `bun run test` exited 0 (85 files, 1,054 tests). `bun run format:check`, `bun run lint`, `bun run typecheck:verify`, `bun run typecheck`, `bun run deadcode`, and `bun run openapi:lint` exited 0. Knip reported two configuration hints (`@inertiajs/core` in `knip.json` and compiled `.css` imports); no check failed. `bin/rubocop` exited 0 (4,790 files, no offenses). `bundle exec erb_lint --lint-all` exited 0 (599 files, no ERB errors) with a parser compatibility warning: parser/ruby33 was running under Ruby 4.0.6. `bundle exec brakeman --quiet --no-pager --exit-on-warn --exit-on-error` exited 0 with zero warnings (Brakeman 8.0.6, Rails 8.2.0.alpha). The repository wrapper `bin/brakeman ...` could not create `/home/global/.cache/gem` in the read-only sandbox; the direct bundled command performed the scan without its network-oriented latest-version precheck.

Coverage is not a single green result: the prescribed Bun-runtime coverage command (`bun --bun vitest run --coverage`, with its report redirected to `/tmp`) exited 1 with `RangeError: Maximum call stack size exceeded` in `@bcoe/v8-coverage` 1.0.2 while merging coverage ranges. The same locked Vitest suite run directly under Node 24.20.0 exited 0 (85 files, 1,054 tests; statements 100%, branches 99.7% (1,343/1,347), functions 100%, lines 100%). This is a successful diagnostic measurement, not proof that the repository's canonical Bun coverage entry point or full CI is green. No coverage settings were changed.

Rails/service isolation is not established in this shell, so `bin/rails test`, `COVERAGE=true bin/rails test test/`, `bin/ci`, route boot, and service-touching tests remain unrun. The active process has `POSTGRESQL_HOST=primary` and `POSTGRESQL_TEST_HOST=primary`; test databases are named `test_*`, but `config/database.yml` uses the shared default PostgreSQL user and `compose.yaml` describes a persistent primary volume. More critically, the active `AUTH_STATE_REDIS_URL` is `redis://valkey:6379/2`, the documented development auth-state DB. `config/environments/test.rb` does not redirect that URL. Application default auth-state stores use fixed namespaces without suite/worker IDs, although direct store tests construct their own test namespaces. The Turnstile verifier is stubbed suite-wide; outbound HTTP stubbing is opt-in, and a suite-wide network-deny control was not established. Docker, Podman, Valkey/Redis server, and PostgreSQL server binaries were unavailable; the shared endpoints were not probed. These facts block mutating Rails/CI commands until E0 isolation is established.

Current E0 state: `IN_PROGRESS`; Rails baseline and canonical JavaScript coverage are `BLOCKED_BY_ENVIRONMENT`/`UNVERIFIED` as described above. Static inventory and independent frontend checks may continue. Do not use `/2`, do not infer safe Valkey isolation from a logical DB number, and do not claim the current Rails baseline or full `bin/ci` result.

# V2 evidence-based re-audit and revised execution plan

Audit date: 2026-09-14 UTC  
Repository: seahal/umaxica-apps-jit-global  
Observed branch / HEAD: feature / 430ac354ba06c9d22885e1e69d027a7a1b1d5280  
Review reference: 08fc1eeb6d2f354078787ab6f3f4e6890c774def  
Mode: read-only repository investigation, safe non-mutating checks, planning only.

## 1. Executive verdict

**NO-GO for freezing and authorizing autonomous implementation of all 95 requirements as one plan.** This is not a rejection of the accepted Base/Auth authority boundary, and it does not stop independent work. Direct-entry product UX remains undecided; high-impact paths have static evidence but no safe public-boundary reproduction; and this shell cannot prove that Rails tests would touch isolated PostgreSQL, Valkey and outbound-network dependencies.

The plan can still be decomposed. P0 is environment-blocked for Rails baseline and request tests. P1, P2a and most independent UI/API work are plan-ready with explicit preconditions. P2b direct-entry completion is blocked only by the user’s product choice. The GUID public URL / OpenAPI ownership decision blocks only that contract slice. DPoP/DBSC physical-device validation remains deferred; protocol-level automation is not blocked by the lack of a physical device.

Do not implement after this plan. A later implementation run needs a separate explicit request. The old D-ENTRY decision below is withdrawn for current planning; it may not be used to choose local sign-in behavior.

## 2. Scope, evidence provenance and worktree record

The current user instruction is planning-only and overrides earlier implementation prompts for this run. No application source, persistent test, migration, route, setting, ADR, Git index/history, database, Valkey, external provider, GitHub, or server was modified. Safe JavaScript/static checks were run as listed in §12; Rails/service checks were not executed. The user expressly authorized writing this plan to refactor.md. misc.md was left untouched in this V2 update.

At the start of this V2 file update, the worktree showed branch feature at 430ac354ba06c9d22885e1e69d027a7a1b1d5280, with no tracked/staged diff and two untracked paths: misc.md and refactor.md. Both existed before this update. At the end, status still showed only those two untracked paths and no tracked/staged diff; misc.md retained SHA-256 fc7a614880319ee1b5ed9ecf086db2ca8ddeddc5f2e29d39e5501c11d8dacdfd, while refactor.md was updated. No checkout, reset, clean, stash, stage, commit, push, PR, issue, or GitHub operation was performed.

The current HEAD is a descendant of review HEAD 08fc1eeb6d2f354078787ab6f3f4e6890c774def. The intervening diff is 21 files, +307/-6. It adds the existing Social Login link Step-Up ADR and tests, changes app/com signup email form-value props and React state handling, and adds disabled Create UI plus tests for Accounts, Organizations and Avatars. These changes do not touch the reviewed OIDC code issuer, exchange coordinator, authorization-code store, or Auth admission path. They are relevant partial progress, not evidence that those security findings were repaired.

The supplied source hashes are retained as input identifiers only. The files named 貼り付けたマークダウン（1）(3).md, 貼り付けたマークダウン（1）(4).md, and umaxica_feature_plan_review.md were not found in the available workspace search. I cannot re-hash their bytes or verify their exact P00–P17 wording from this run. The 95 rows in Appendix A of this file are a normalized plan index, not the source prompts. Do not claim otherwise, fill in missing P00–P17 attribution, or reconstruct the truncated ORG material behind REQ-095. This revision maps every existing REQ ID but labels exact source provenance as limited. Restore the originals before an implementation agent treats a normalized row as the complete acceptance wording.

## 3. Repository facts and evidence map

| Topic | Current code/document fact | Status and consequence |
| --- | --- | --- |
| Authority | adr/base-auth-ceremony-and-seven-rp-boundary.md says Base is the only physical IdP/AS; Auth is a credential ceremony; actor-specific ceremony sessions and random-only __Host-auth_sid may exist but do not prove a Base login. The seven browser clients are core-app/com/org, side-app/com/org and edit-org. | Accepted architectural boundary. Do not delete every Auth cookie/session/model, and do not make Auth the final AAL or RP authority. |
| Authenticated RP flow | Base authorization controllers create Base transactions and issue admission to the Auth ceremony. The Auth selector includes AuthCeremonyAdmission. | Static flow supports the intended RP-originated direction; public request verification is still required across all realms. |
| Auth direct/nested flow | Auth app/com application controllers have before-actions including actor resolution and sign-in gating. The gate is not itself a Base admission check for an anonymous nested email endpoint. Auth::App::Sign::InsController and Auth::Com::Sign::InsController include AuthCeremonyAdmission; leaf email controllers do not. Routes expose nested email POSTs. | Static reachability concern only. Inherited callbacks, all org entry modes, valid/invalid admissions and actual persistence must be measured before calling this a reproduced bypass. |
| Auth sign-in side effects | Auth::App::Sign::In::EmailsController#verify_existing_email_otp calls AuthenticationSessionCommitter.call; Auth::Com::Sign::In::EmailsController#update does too. AuthenticationSessionCommitter#call invokes the controller’s establish_signed_in_session!; AuthenticationBase owns log_in and writes token/cookie state. Auth app/com email flow therefore has a code path that establishes Auth-side session/token state before a Base result is accepted. | Conflicts with the accepted authority boundary if reachable as a successful sign-in. Test the complete observable state transition; keep temporary ceremony continuity distinct from a login credential. Do not generalize this app/com finding to org without tracing Entra, SecretKey and Emergency separately. |
| Auth root/navigation | Auth admission-less selectors bridge to same-realm Base root; Base anonymous root links have been observed pointing to raw Auth selectors. | Static loop/navigation finding. Root behavior and direct-entry UX need a product decision and public browser test; no redirect destination is selected here. |
| auth_time | OidcAuthorizationCodeIssuer#call passes Time.current as auth_time. AuthorizationCodeStore sets issued_at separately. OidcTokenExchangeCoordinator::ConsumedCode#created_at prefers issued_at; issue_exchanged_token_result uses authorization_code.created_at || now for both Access JWT and ID Token auth_time. | Static semantic defect: code issue time is not authentication-event time. No T0/T1/T2 public claim test was run. |
| Freshness request | OidcAuthorizationTransactionable#authorize_params (lines 95–106) returns a fixed set without prompt or max_age; register_authentication! (lines 108–127) sets authenticated_at to its now argument. The app/com/org Base authorize_params methods use explicit allowlists. No max_age implementation was found by the scoped app/config/test search. | Strong static OIDC conformance candidate, not proof that no middleware or unsearched integration handles it. Trace RP request generation, Rails params, transaction/handoff, Base policy and RP ID Token validation independently. OIDC Core §§3.1.2.1, 3.1.2.3 and 15.1 apply to those endpoints. |
| Authorization-code replay | OidcTokenExchangeCoordinator#prevalidate_payload (lines 136–158) tests payload lifecycle state before client_id, redirect_uri and PKCE checks. The token endpoint then calls revoke_linked_family! on replay. CONSUME_SCRIPT (authorization_code_store.rb lines 33–64) also returns replay before expected-field checks. | Static owner-binding defect candidate in both Ruby and Lua. A valid, authenticated client B that supplies a known consumed client-A code may reach a revocation side effect against A’s linked RP session/family. No public token endpoint reproduction exists; do not call this an exploited vulnerability. |
| Replay revoke scope | revoke_linked_family! resolves an RP Session or refresh family and invokes RpSessionRevoker. It does not revoke the Base root session. RpSessionRevoker stops future refresh/new issuance; already-issued short-lived Access JWTs remain usable until their signed expiration under the accepted project risk. | Keep the explicit immediate-revocation risk. Do not add online session lookups to normal Access JWT requests. Distinguish child RP revocation from Base-session termination in tests and docs. |
| Multi-store exchange | The coordinator consumes the Valkey code before DPoP verification, then opens a surface-specific PostgreSQL transaction, records connection/usage, issues or rotates refresh, links the consumed code to RP usage/family, and constructs the token response. link_consumed_family! ignores the link result and catches Valkey errors as warning-only. LINK_FAMILY_SCRIPT can return linked, missing, invalid_state or corrupt. | Static partial-failure hazard. PostgreSQL and Valkey are not one ACID transaction. A positive link result must be distinguished from all other outcomes. No fault injection was run. |
| DPoP | DpopProofVerifier supports ES256/ES384 and checks typ, public JWK, signature, htm/htu, iat, jti, ath when a token is supplied, and JTI/nonce state. DPoP is optional at token exchange; Bearer exchange remains. DPoP validation occurs after code consumption and a bad proof is mapped through current application error handling. DpopNonceService exists, but no token-endpoint use_dpop_nonce challenge was found. | RFC 9449 §8 makes nonce use optional. Missing challenge is not itself a defect. If a challenge is enabled, test its retry before irreversible code consumption. RFC 9449 §5 error mapping and invalid-proof code consumption need explicit acceptance. |
| DBSC | DBSC services and routes exist. SignDbscRegistrationEndpoint#create performs registration or bound-cookie refresh; check controllers advertise DBSC state/registration, and refresh endpoints include DBSC data. | Server implementation is wired at some paths, not thereby proven end-to-end or device-valid. Keep unsupported-device fallback. Physical browser validation remains pending. |
| GUID route | config/routes/guid.rb constrains the dedicated guid.umaxica.net surface and currently declares /api/v0/resources/:guid; health/revision and CSP paths are separate. | Verified static route, not runtime route output. Earlier resolver requirement says /resources/:eid while later API consolidation says /api/v0 where appropriate. OpenAPI’s historical app/com/org-only structure leaves net ownership unclear. Do not quietly select or duplicate a public contract. |
| Activity/session UI | Base ActivityLogPresenter already maps event types to risk labels/ranks and visibility and filters internal event IDs before rendering; it omits raw context. Current mapping is code-level, not a Risk parent FK. Chronicle level_id is logging severity, not security risk. /identity/sessions remains the user session route. | Reuse the presenter/rank/visibility mapping unless tests expose a real semantic gap. Do not add a duplicate risk table or reuse severity. Route/UI migration to /sessions still needs owner-scoped tests. |
| Session expiry | refresh-token docs and source describe root discarded_at as a fixed session absolute ceiling; refresh rotation preserves/caps it. RP refresh_token_expires_at is a separate token lifetime; session expiry code also caps Access/ID token expiration. | ALREADY_SATISFIED by current source/docs with focused existing tests, but Rails tests were not run in this environment. Do not add a duplicate expiry column unless a safe boundary test disproves the existing contract. |
| Existing UI changes | At this HEAD, disabled Create actions and app/com signup email value retention have code/tests; social identity link Step-Up STAY ADR/tests exist. | Bun tests passed. Treat as partial satisfaction until relevant Rails tests run; no duplicate implementation planned unless focused assertions fail. |
| Rails test environment | POSTGRESQL_TEST_HOST and POSTGRESQL_HOST both resolve to primary in this environment; AUTH_STATE_REDIS_URL resolves to redis://valkey:6379/2, the documented development auth-state DB; config/environments/test.rb does not override it. Other fixed logical DBs are also not isolation. Compose describes persistent service volumes. Docker/Podman/PG/Valkey service binaries were unavailable; shared endpoints were not probed. | BLOCKED_BY_ENVIRONMENT for Rails tests, routes boot, CI and any service-mutating request. Do not probe the shared services or infer isolation from test_ DB naming or Redis DB index. |
| Canonical route inventory | Static route files can be read, but bin/rails routes and bin/rails notes were not run because Rails boot may touch the unisolated services. | Runtime route set remains UNVERIFIED. Do not claim the static search equals generated route output. |

### Adversarial findings

The following review lenses were applied independently as self-review. No independent reviewer agents were run.

| Finding | Reviewer lens | Severity | REQ | Evidence / plausible failure | Disposition |
| --- | --- | --- | --- | --- | --- |
| ADV-001 | Security / protocol | HIGH | 011, 012, 030, 093 | Auth event time is replaced by code issued_at on exchange; T0/T1/T2 tokens can misstate when the user authenticated. | Accept. Carry an immutable Base-accepted authentication event time; never substitute issue time or Rails timestamps. |
| ADV-002 | Security / architecture | HIGH | 020, 059, 060 | A known consumed code can be classified as replay and revoke a linked child session before caller ownership is checked in both Ruby and Lua. | Accept as reachable static side-effect candidate, not reproduced vulnerability. Bind the side effect to rightful client/redirect owner in both layers; prove with A/B HTTP tests. |
| ADV-003 | Operations / security | HIGH | 020, 059, 061, 062 | Code consumption is irreversible before separate Valkey link and PostgreSQL commit; link missing/invalid_state/exception/ambiguous timeout is not positively handled. | Accept. Define failure state and recovery per injection point; do not claim cross-store atomicity. |
| ADV-004 | Protocol / availability | MEDIUM | 016, 020, 059 | DPoP proof is checked after one-use code consumption; invalid proof can consume a known code. Token-endpoint nonce challenge was not found; bad proof response mapping needs checking. | Partially accept. Order validation only after proving replay/retry safety. Nonce is optional; no nonce defect is asserted if none is required. |
| ADV-005 | Architecture / security | BLOCKER for authority cutover | 007–010, 020, 032, 065 | Auth email OTP path reaches Auth session/token commit before Base acceptance; Base/Auth root links appear to bounce. | Accept statically. Public boundary tests and a Base-owned result/commit are required. Keep legal ceremony state. |
| ADV-006 | Requirement / protocol | HIGH | 009–013, 030 | max_age/prompt are absent from known allowlists/transaction model and no code hit was found. If request handling truly drops them, OP freshness contract is not met. | Accept as conformance candidate; confirm through negative public requests and complete source trace before implementation. |
| ADV-007 | Testability / operations | BLOCKER for dynamic Rails baseline | 020, 064, 066, 069, 093 | Test DB/auth Valkey URLs can target shared development services; outbound deny is not demonstrated. | Accept. Establish disposable isolated endpoints and egress stubs before Rails tests/CI. |
| ADV-008 | Requirement traceability | HIGH for full-plan freeze | 001–006, 019, 020, 095 | Original P00–P17 and Sol files are not locally available; prior plan claims recovered/hash-verified sources and fixes a direct-entry design contrary to latest prompt. | Accept. Mark source limitation, reject old D-ENTRY, map normalized IDs without claiming exact provenance. |
| ADV-009 | Architecture / standards | HIGH for GUID contract slice | 021–027, 034–040 | Current public host route is /api/v0/resources/:guid, while an earlier resolver request names /resources/:eid; net OpenAPI ownership is unresolved. | Accept only for this GUID contract subphase. Inventory and other API migrations can proceed independently. |
| ADV-010 | Complexity / regression | MEDIUM | 045–050, 078–084 | Existing Activity code already has risk rank/visibility mapping, safe redaction and a shared date helper; duplicating a risk framework would add state without evidence. | Accept. Preserve proven primitives; add only a narrowly required independent concept. |
| ADV-011 | Regression / protocol | MEDIUM | 017–019 | DBSC code has runtime routes/services, but physical browser support and lifecycle behavior are not established. | Accept. Automated protocol tests and device debt are separate deliverables. |
| ADV-012 | Regression / behavior | MEDIUM | 041–044, 075–086 | Auth/Base/Side roots, Core and Palm have different browser/BFF/native semantics; a uniform redirect would create behavior not supported by route architecture. | Accept. Keep the surface matrix and test each public root; direct Auth completion waits for the user decision. |

## 4. OIDC flow and time model

### 4.1 Observed current path

Current static path for ordinary RP authorization is:

RP authorization request → Base surface authorization controller and explicit param allowlist → Base OIDC authorization transaction/handoff → Auth ceremony selector → credential ceremony → Base callback/result consumption → OidcAuthorizationCodeIssuer#call → Valkey code payload → token endpoint / OidcTokenExchangeCoordinator → Access JWT and ID Token; refresh issuance/rotation then operates on the stored session/family.

Source anchors:
- app/operations/oidc_authorization_code_issuer.rb, #call, lines 17–43: code payload auth_time is Time.current.
- app/services/valkey/auth_state/authorization_code_store.rb, #issue!, lines 93–127: issued_at is independently assigned from now.
- app/services/oidc_token_exchange_coordinator.rb, ConsumedCode#created_at around lines 18–22, #wrap_payload around lines 241–261, and #issue_exchanged_token_result around lines 387–411: code issued_at is preferred and used as auth_time for both exchanged tokens.
- app/models/concerns/oidc_authorization_transactionable.rb, #authorize_params lines 95–106 and #register_authentication! lines 108–127: allowlisted fields omit prompt/max_age; authenticated_at is recorded at Base result registration.
- app/controllers/base/app/oauth/authorizations_controller.rb#authorize_params and the equivalent com/org methods: explicit request filtering.

This shows an implementation-path defect by static data flow. It does not prove what every deployed or alternate path returns, and no token HTTP flow was run.

### 4.2 Required event-time contract

| Operation | Authentication event time | Code issue / JWT iat | Required result |
| --- | --- | --- | --- |
| New interactive authentication | T0: credential evidence time, accepted and recorded by Base | T1 for authorization code; T2 for exchanged JWT | Access/ID auth_time remains T0; issued_at/iat remain T1/T2. |
| Existing Base SSO session | Original accepted event time | New code/token issue times | Reuse original auth_time; ordinary SSO, callback or consent does not refresh it. |
| prompt=login or max_age-triggered fresh authentication | New actual credential event T0' accepted by Base | Later T1'/T2' | auth_time changes only for the accepted reauthentication result. |
| Step-Up | Separate fresh evidence/freshness event | Token issuance time remains independent | Preserve explicit step-up/freshness. Update authentication event time only if policy defines successful step-up as reauthentication; it never implies AAL2 by itself. |
| Google/Apple identity link or unlink | Existing fresh Step-Up event is evidence for credential management | Link operation time is not authentication time | Linking itself never advances auth_time. Existing STAY decision remains. |
| Refresh | No new authentication event | Refresh issue/iat time | Preserve original auth_time, acr/amr policy and session ceiling; do not call refresh an authentication. |
| Persistence mutation | AR created_at/updated_at describe row persistence | Not an OIDC time source | Never infer auth_time from these columns. |

If existing Base result has no trustworthy event time, do not use Time.current at code issue, Base result consumption time, session creation time, authorization_code.created_at or AR created_at as a compatibility substitute. The follow-up design must identify a credential-event value that Auth can attest as evidence and Base can validate/accept without allowing Auth to decide identity, session or final assurance. Persist that event value in Base-owned state only if the current transaction/session schema cannot safely carry it. Inspect backfill and deployed-row implications before proposing a destructive or nullable/non-null migration; deployment status alone is not evidence that existing rows can be discarded.

### 4.3 max_age / prompt audit requirement

OpenID Connect Core §2 distinguishes auth_time (when End-User authentication occurred) from iat (when the JWT was issued). §§3.1.2.1 and 3.1.2.3 describe max_age freshness, max_age=0, prompt=login and prompt=none failure when interaction is required. §15.1 lists OP support for prompt and max_age/auth_time among OP requirements. Apply these requirements to the Base authorization endpoint and its ID Token path; the project’s Access JWT auth_time claim is a separate local contract.

The implementation phase must independently test:
1. RP builder sends prompt/max_age when requested.
2. Route/controller permits and validates allowed prompt values and numeric max_age.
3. Transaction and handoff preserve the validated request without letting Auth set final assurance.
4. Base compares max_age against the accepted authentication-event time and forces actual reauthentication when stale.
5. max_age=0 behaves as immediate reauthentication; prompt=login requires reauthentication even with an apparently recent session.
6. prompt=none returns the protocol-defined error if silent completion cannot satisfy freshness; it does not silently weaken max_age.
7. ID Token includes the correct auth_time when max_age was used and RP callback validates the relevant returned claim.
8. No ordinary callback, refresh or code exchange advances auth_time.

Normative reference: OpenID Connect Core 1.0 incorporating errata set 2, §§2, 3.1.2.1, 3.1.2.3 and 15.1, https://openid.net/specs/openid-connect-core-1_0.html.

## 5. Authorization-code ownership, replay and partial-failure contract

### 5.1 Owner-bound replay test matrix

The eventual public token endpoint tests must use two valid, separately registered clients A and B in the same resource realm. Authenticate every client assertion with a fresh JTI, valid audience and signature. Use fresh DPoP proofs except in the specific proof-replay case. A test rejected at client authentication, realm routing, rate limiting, fixture parsing or a different replay guard has not tested the authorization-code owner branch.

| Case | Request | Expected response/state assertion |
| --- | --- | --- |
| A first exchange | A’s code, exact redirect, correct PKCE, valid DPoP if required | One successful exchange; one expected RP usage/family; code consumed and linked. |
| Valid same-owner replay | A repeats A’s consumed code as an otherwise valid request | Denied; only linked A RP Session/refresh family revoked per existing policy; Base root and other RP clients unchanged. |
| Cross-client replay | B presents known consumed code issued to A | Denied before any A revoke; A’s RP Session/family, Base root session and unrelated RP sessions remain unchanged. |
| Wrong redirect | Correct owner but redirect differs from code binding | Denied; no family revocation from wrong binding. |
| Wrong PKCE | Correct owner/redirect but verifier is incorrect | Denied; no ownership-independent revoke. |
| Expired code | Test time past expiry; separately distinguish expired-issued and expired-consumed | Denied; no unintended owner side effect. |
| Corrupt payload | Known key contains malformed payload in isolated store | Fail closed; no guessed owner revocation. |
| Concurrent same request | Two requests race on the same code | At most one consume succeeds; other is denied; one usage/family transition only. |
| Competing client/config | Same Base session/client concurrently authorize twice | DB uniqueness/serialization gives one active usage under current contract; no unbounded retry or partial PG transaction reuse. |
| Read/consume race | A’s code is read issued, then another request consumes it before this request reaches Lua | Lua re-checks binding before returning replay; wrong owner cannot create a side effect. |

Observation is not limited to HTTP status. Capture before/after owner RP Session, refresh-token family, Base Browser Session, and unrelated RP sessions. Normal audit/rate-limit counters are not prohibited side effects. RFC 6749 §§4.1.2–4.1.3 bind code to client and redirect and require one-use; §4.1.2 recommends revoking tokens derived from a code reused by its legitimate flow. Preserve that protection while preventing a non-owner request from destroying the owner’s state. Reference: https://www.rfc-editor.org/rfc/rfc6749.html.

### 5.2 Two-store failure injection

No PostgreSQL transaction can atomically include Valkey. Execute the following matrix in isolated services before choosing compensation:

| Failure point | Current ordering / possible residue | Required test and forward-recovery decision |
| --- | --- | --- |
| Code read or prevalidation | No consume should happen; Valkey outage is surfaced by store wrapper. | Inject unavailable/read/corrupt outcomes; assert no DB session/family or response credential. |
| Atomic code consume | One-use Valkey transition happens before downstream work. | Race requests; prove exactly one consume. Never blanket-reset consumed code to issued. Restart through a fresh authorization if later work cannot complete. |
| DPoP validation | Currently after consume. | Inject missing/invalid proof, key mismatch, JTI replay and any required nonce error; record endpoint error/headers and code state. A future fix must choose fresh-authorization recovery or pre-consume validation with safe owner/code binding. |
| RP Session/usage DB creation | Happens after consume in a surface-specific PG transaction. | Inject DB failure; assert transaction rolls back, no token response, no live refresh family/partial session, code remains consumed. |
| Refresh rotation | May rotate an existing usage family in the PG transaction. | Fail before/after rotation; verify old/new digest, previous-token semantics, discarded_at ceiling and whether any credential was returned. |
| Tombstone family link exception | Current rescue warns and returns, so result construction continues. | Inject exception and assert no success credential unless required link is positively proven; observe PG commit/rollback. |
| Tombstone missing/invalid_state/corrupt result | Current caller ignores non-exception result; link is unproven. | Return each status; assert every non-linked outcome fails exchange and leaves no usable orphan family/session. |
| Link timeout with unknown outcome | Valkey may have applied the script but response may be lost. | Inject post-write response loss. Do not infer no link. If PG rolls back, verify replay cleanup can locate family when RP ref points to no committed row. |
| Link succeeded then token signing/response construction fails | Tombstone can refer to a session/family whose PG transaction rolls back. | Inject failure; verify no credential response and safe cleanup for ambiguous family link. Existing replay code returns early when rp_session_ref exists but DB session lookup misses; test whether family fallback is needed. |
| Link succeeded then PG commit fails | Valkey tombstone can outlive rolled-back PG state. | Inject commit failure and inspect both stores; prove replay cannot leave active credential or miss family cleanup. |
| PG commit succeeds then HTTP response is lost | DB usage/family and code are committed but client may not receive token. | Simulate dropped response. Do not reopen code; define recovery by new authorization and prove old refresh credential was not exposed/logged. |
| RecordNotUnique/concurrent active usage | create_or_resolve_active_usage! has a RecordNotUnique retry path. | Race same Base session/client; assert no retry loop, no retry in an aborted PG transaction, one active session and deterministic response. |

Minimal resolution preference: keep one-use consumption, require a positive Valkey link result before issuing a response if link is part of the accepted replay-revocation guarantee, roll back local DB transaction on non-positive link, and restart authentication rather than minting credentials from ambiguous state. Add only cleanup/fallback necessary to reconcile a tombstone that may reference rolled-back DB state. Do not introduce distributed transaction products or a generic idempotency framework. If this cannot preserve replay revocation and recover from ambiguous timeout, stop this phase and request an explicit residual-risk decision.

### 5.3 DPoP code-consumption boundary

RFC 9449 §5 defines invalid_dpop_proof for an invalid DPoP proof. §8 says an AS MAY use a server nonce; no nonce requirement is inferred from an absent header alone. Current static evidence places proof validation after one-use code consumption. If the server does not elect to require a nonce, invalid proof currently means a failed code attempt and likely requires fresh authorization; test this availability cost and exact error. If the server requires a nonce, test that use_dpop_nonce and DPoP-Nonce are followed by a valid fresh proof and do not become false authorization-code replay. Source: https://www.rfc-editor.org/rfc/rfc9449.html, §§5 and 8.

## 6. Conflict matrix and adjudication

| ID | Conflict | Classification | Resolution |
| --- | --- | --- | --- |
| C-01 | Earlier implementation prompts authorize source changes and commits; latest V2 says planning-only, no Git state or persistent test changes, and do not continue to implementation afterward. | REAL_CONFLICT | Latest explicit scope wins for this run. Only refactor.md may be written because the user explicitly asked for that file. |
| C-02 | Existing refactor.md says GO and chooses D-ENTRY; latest prompt says direct-entry UX is unresolved and must not be finalized. | REAL_CONFLICT | Reject old D-ENTRY as an unapproved plan decision. Keep it only as historical; P2b blocks until user chooses. |
| C-03 | Existing refactor.md says original and Sol artifacts were recovered and hashed locally; current workspace search did not find those files. | STALE/UNVERIFIED CLAIM | Supersede it. Supplied digests identify inputs but are not current byte verification. Appendix A is a normalized index only. |
| C-04 | REQ-016–019 or 064 previously mapped to the wrong group. | STALE PLAN MAPPING | Map DPoP/DBSC to P5 and Valkey topology/test namespace REQ-064 to P0. |
| C-05 | REQ-055/056 grouped with RP work. | STALE PLAN MAPPING | ORG sign-in policy/UI is owned by P3; only shared RP protocol is P4. |
| C-06 | REQ-020 omitted from prior mapping or attached only to final E10. | STALE PLAN MAPPING | P10 owns final closure, but REQ-020 is a horizontal invariant applied to every phase/test. |
| C-07 | No DPoP nonce challenge was found; RFC 9449 might require it. | APPARENT_CONFLICT | RFC 9449 §8 makes AS nonce use optional. Test actual configured policy; absence alone is not a violation. |
| C-08 | Existing optional DPoP/Bearer paths versus requested sender-constrained rollout for compatible clients. | IMPLEMENTATION CHOICE / possible policy conflict | Preserve current policy during correctness repair. Decide enforcement per client only after key ownership and client/device evidence; do not change all clients at once. |
| C-09 | Current GUID route /api/v0/resources/:guid versus earlier PoC /resources/:eid and net OpenAPI omission. | REAL_CONTRACT_DECISION / MISSING_INFORMATION | Preserve current route during planning; inventory callers and deployment contract. Ask whether lookup is root /resources/:eid, API-prefixed, or both through one implementation. Do not silently add alias or claim OpenAPI-complete. |
| C-10 | Risk parent FK presumed by earlier prose, while schema/model search found no risk table; Chronicle level_id is severity. | STALE REQUIREMENT / implementation fact | Reuse current presenter mapping. Add persistent risk data only if a concrete event model needs independent stored risk and a real migration/backfill contract exists. |
| C-11 | Immediate JWT revocation looks weaker than a stronger online alternative. | Explicit accepted risk | Keep issued short Access JWT valid to exp; stop future refresh/new issuance. DPoP may reduce replay value but is not revocation; DBSC does not replace revocation. |
| C-12 | Session expiry could be interpreted as refresh expiry. | APPARENT_CONFLICT | Source distinguishes root discarded_at fixed session ceiling from per-RP refresh_token_expires_at. Validate existing tests; do not add duplicate expiry storage based on names. |
| C-13 | Earlier Auth root UX asks for local dashboard while authority decision leaves direct sign-in unresolved. | REAL_CONFLICT | Do not turn root behavior into an authority decision. Inventory all 13 candidate surfaces, preserve Core/Palm differences, and block only direct-entry-dependent behavior. |

### Adjudication of BLOCKER and HIGH findings

- ADV-005 — ACCEPTED. The Base/Auth invariant outranks implementation. Auth ceremony continuity may remain, but successful authentication must be accepted and committed by Base.
- ADV-002 — ACCEPTED as a high-risk static side-effect path, not a reproduced exploit. Lua and Ruby both need owner-binding proof; same-owner reuse revocation remains mandatory.
- ADV-003 — ACCEPTED. Warning-only and ignored link results are not evidence of fail-closed semantics. A cross-store state matrix is required.
- ADV-001 — ACCEPTED. Current code timestamps code/token output, not the accepted authentication event. Correct only with a trusted event value.
- ADV-006 — ACCEPTED as a high OIDC conformance candidate. Confirm through endpoint behavior; no implementation success until freshness is enforced.
- ADV-007 — ACCEPTED. Unsafe/unproven test targets block service-touching tests, not static work or independent planning.
- ADV-008 — ACCEPTED. The prior source-recovery claim is withdrawn for this run; do not treat a normalized ledger as verbatim.
- ADV-009 — ACCEPTED only for the GUID path/schema decision. It does not block API inventory or unrelated route migration.
- ADV-004 — PARTIALLY_ACCEPTED. Code burn on invalid proof is statically present; absence of optional nonce is not a defect. Record error contract and recovery after a public boundary test.
- ADV-011 — ACCEPTED. Server DBSC code does not establish real-browser/device interoperability.
- ADV-010 / ADV-012 — ACCEPTED. Reuse current presentation abstractions and preserve surface-specific root semantics.

## 7. Revised target architecture

1. Base remains the only IdP/Authorization Server authority. It creates/owns identity, Base Browser Session, authorization transaction, accepted authentication time, final acr, access policy and RP-facing result.
2. Auth verifies credentials and returns bounded evidence to Base. Auth may use actor-specific opaque short-lived ceremony continuity state and a random-only host cookie. Those do not assert Base login. No successful flow may depend on Auth issuing an independent identity/session token or final RP assurance.
3. RP authorization remains RP → Base admission → Auth ceremony → Base result/code → actual RP. Local/direct entry cannot fabricate a client, code, redirect, assertion, RP Session or RP result.
4. Store three different times: accepted authentication event time, authorization-code issue time, and each JWT iat. Refresh retains accepted auth_time. Persistence timestamps are not semantic substitutes.
5. OAuth code one-use/replay semantics remain. Both Ruby and Lua classify ownership before replay-driven revocation. Revoke only the child RP Session/family bound to a legitimately reused code; never revoke another client or Base root due to a non-owner presentation.
6. Valkey code state and PostgreSQL session/family state have compensation/restart semantics, not fictional cross-store ACID. Ambiguous/failed link cannot produce an unqualified success.
7. RP mechanics stay shared across Core, Side and Edit; configuration remains per client/deployment. Edit remains singleton only at its boundary. Auth is never an RP.
8. DPoP and DBSC are possession/binding mechanisms, not AAL or immediate revocation. Keep per-client compatibility policy until explicitly decided and validated. Unsupported DBSC clients have a safe non-DBSC path.
9. Activities use event type, risk and visibility as separate dimensions. Keep the safe current user-facing projection and SQL-filter visibility. Do not repurpose Chronicle severity as risk.
10. User session resource /sessions stays distinct from Base Core API /api/v0/session and normal /sign/out ceremony. Owner scope and CSRF are server-enforced.
11. Session absolute expiry is the existing fixed root session ceiling only if boundary tests prove it. Source strongly indicates discarded_at already has this meaning; RP refresh_token_expires_at remains technical token lifetime.
12. Existing documented fixed routes such as CSP report and .well-known remain justified exceptions. Internal APIs use resourceful /api/v0 routes only after contract/dependency inventory.
13. The API/OpenAPI owner for the GUID net surface and its canonical public lookup path is a bounded contract decision, not an invented assumption.

## 8. Requirement traceability audit and corrected 95-row map

### 8.1 Provenance, classification and status legend

The 95 concise requirement descriptions remain in Appendix A. The rows below assign each existing ID one primary phase, dependency, fail-first test/evidence hook, documentation impact, observable acceptance statement and current status. All rows have source marker IDX: wording is the local normalized Appendix A description; exact P00–P17 mapping is unavailable in this workspace. A daggered MUST means the normalized index/current explicit V2 direction requires it; it does not certify identical wording in a missing source prompt.

Classification abbreviations: INV invariant, AD architecture decision, FUNC functional, SEC security, DATA data contract, API API contract, ROUTE routing, NFR non-functional, TEST test requirement, DOC documentation, PREF implementation preference, CLEAN cleanup, INVEST investigation.

Status abbreviations: OPEN work not proven; PARTIAL static implementation exists but required boundary tests are unrun; SAT-SOURCE static behavior appears implemented and must be checked before adding duplicate work; ENV-BLOCKED requires isolated services; DECISION-BLOCKED requires user choice; SOURCE-LIMITED exact source text is unavailable; CURRENT-SCOPE means explicitly overridden for this read-only run. Test/evidence codes are defined in §9. Document targets are D1 Base/Auth ADR, D2 OIDC/claims/assurance docs, D3 RP/security ADR and shared RP docs, D4 routing-consolidation ADR and OpenAPI sources/bundles, D5 root/surface contracts, D6 activity/session/preferences docs, D7 timestamp/method-visibility ADR/harness, D8 OTP/Turnstile/mail docs, D9 follow-up plans, and this plan for process/traceability. This is a planning trace, not a claim that those documents changed.

| ID | Class / strength | Source | Primary phase; dependency | Test / evidence | Docs | Acceptance criterion / current status |
| --- | --- | --- | --- | --- | --- | --- |
| REQ-001 | INV / MUST† | IDX | P0; none | P0-T0 scope/status | This plan | This run is plan-only; no application change. CURRENT-SCOPE |
| REQ-002 | INVEST / MUST† | IDX | P0; none | P0-T0 input/code comparison | This plan | Conflicts and evidence levels explicit. PARTIAL |
| REQ-003 | DOC / MUST† | IDX | P10; P1–P9 | P10-T1 requirement audit | This plan | One corrected plan delivered; exact source limited. SOURCE-LIMITED |
| REQ-004 | DOC / MUST† | IDX | P0; explicit user request | P0-T0 path/status | This plan | Root refactor.md updated without truncating history. CURRENT-SCOPE |
| REQ-005 | INV / MUST† | IDX | P0; none | P0-T0 Git status | This plan | No Git mutation or remote write. CURRENT-SCOPE |
| REQ-006 | NFR / MUST† | IDX | P10; any later server check | P10-T3 process check | This plan | Later local server is stopped after check; none started now. CURRENT-SCOPE |
| REQ-007 | AD / MUST† | IDX | P2a; P0 | P2-T1/T2 Base result/session owner | D1 | Base alone accepts authentication authority. OPEN |
| REQ-008 | AD / MUST† | IDX | P2a; P0 | P2-T1/T4 Auth DB/cookie/token diff | D1 | Auth stores only permitted ceremony continuity/evidence. OPEN |
| REQ-009 | INV / MUST† | IDX | P2a/P4; P0 | P2-T2 admitted RP flow | D1/D3 | RP result returns through Base to the real RP. OPEN |
| REQ-010 | AD / MUST† | IDX | P2b; user decision | P2-T3 local entry contract | D1/D5/D9 | No fake RP transaction; direct-entry outcome follows explicit choice. DECISION-BLOCKED |
| REQ-011 | DATA / MUST† | IDX | P3; P1/P2a | P3-T1/T2 T0/T1/T2 claims | D2 | auth_time equals accepted event and stays through refresh. PARTIAL: current code uses code time. |
| REQ-012 | DATA / MUST† | IDX | P3; P2a | P3-T3 sign-in/step-up/reissue claims | D2 | Base accepts acr; amr lists methods actually used. OPEN |
| REQ-013 | DOC / MUST† | IDX | P3; P2a | P3-T3 dimension matrix | D2/D9 | Sign-in, step-up, AAL, phishing resistance, freshness and FAL stay distinct. PARTIAL |
| REQ-014 | SEC / MUST† | IDX | P3; none | P3-T3 SMS risk/claim tests | D2 | SMS accepted risk explicit; not phishing-resistant or automatic AAL2. PARTIAL |
| REQ-015 | SEC / MUST† | IDX | P4; P1 | P4-T2 child/root revoke and Access JWT | D3/D6 | Revoke stops future issuance; existing short Access JWT expires naturally; no online lookup. SAT-SOURCE, Rails test unrun. |
| REQ-016 | SEC / MUST† | IDX | P5a; P0/P1 | P5-T1/T2 | D3/D9 | RFC 9449 verifier/endpoint contract correct; per-client rollout separate. PARTIAL |
| REQ-017 | SEC / MUST† | IDX | P5a; P2a/P4 | P5-T3 | DBSC docs/D9 | Registration, proof, refresh, failure and fallback work without lockout. PARTIAL |
| REQ-018 | TEST / MUST† | IDX | P5b; P5a | P5-T4 | D9 | No physical validation claim without evidence. DEFERRED_VALIDATION |
| REQ-019 | DOC / MUST† | IDX | P10; decisions in §11 | P10-T2 | D9 | Follow-up plans state prerequisites/exit criteria. PARTIAL |
| REQ-020 | INV / MUST† | IDX | P10 primary; ALL phases | Every P*-T*, security review | This plan / affected docs | Never weaken security controls, tests or coverage in any phase. HORIZONTAL invariant. |
| REQ-021 | PREF / MUST† | IDX | P8 GUID; contract decision | P8-T3 | D4 | Opaque lookup only; no generator or new gem. URL decision remains blocked. |
| REQ-022 | DATA / MUST† | IDX | P8 GUID; P8-T3 | Model/index/invalid-input test | D4 | eid unique/non-null/bounded; kind/status required; canonical URL nullable. OPEN |
| REQ-023 | ROUTE / MUST† | IDX | P8 GUID; user decision | P8-T1/T3 | D4 | No top-level catch-all; one accepted scoped resource path. URL decision blocked. |
| REQ-024 | API / MUST† | IDX | P8 GUID; P8-T3 | HTML/JSON/404/5xx | D4 | Exact lookup; unknown 404 and backend failure 5xx. OPEN |
| REQ-025 | SEC / MUST† | IDX | P8 GUID; none | canonical_url non-redirect test | D4 | Lookup never auto-redirects to canonical_url. OPEN |
| REQ-026 | DATA / MUST† | IDX | P8 GUID; none | duplicate/reuse lifecycle test | D4 | No public registration or identifier reuse path. OPEN |
| REQ-027 | TEST / MUST† | IDX | P8 GUID; P8-T3 | injection/escaping/encoding/length | D4 | Opaque IDs are safely bounded and escaped. OPEN |
| REQ-028 | AD / MUST† | IDX | P4; P0/P1/P3 | P4-T1 shared RP contract | D3 | Core, Side and Edit share equal protocol mechanics. OPEN |
| REQ-029 | AD / MUST† | IDX | P4; P4-T1 | multi-config RP tests | D3 | Edit singleton policy does not leak into shared code. OPEN |
| REQ-030 | SEC / MUST† | IDX | P4; P1/P3 | P4-T1/T2 negative callback | D3 | State, nonce, PKCE, issuer, audience, redirect, JWT profile and session safety hold. OPEN |
| REQ-031 | TEST / MUST† | IDX | P4; P0/P1 | P4-T1 callback failure matrix | D3 | Public callback errors/replay/logout recover safely without live IdP. OPEN |
| REQ-032 | AD / MUST† | IDX | P2a/P4; P0 | P2-T4/P4-T1 | D1/D3 | Auth is not RP; Base and N-instance Core/Side remain. OPEN |
| REQ-033 | ROUTE / MUST† | IDX | P8; P8-T1 | classify CSP and .well-known paths | D4 | Documented fixed-path exceptions remain; internal indirection removed. OPEN |
| REQ-034 | INVEST / MUST† | IDX | P8; safe Rails boot | P8-T1 static plus bin/rails routes | D4 | All route files/runtime routes inventoried separately. Runtime ENV-BLOCKED. |
| REQ-035 | ROUTE / MUST† | IDX | P8; inventory | P8-T2 | D4 | Valuable application APIs use /api/v0 where appropriate. OPEN |
| REQ-036 | CLEAN / MUST† | IDX | P8; caller evidence | P8-T1/T2 dead endpoint audit | D4 | Delete only proven dead routes; valuable unresolved contracts have bounded decisions. OPEN |
| REQ-037 | ROUTE / MUST† | IDX | P8; inventory | P8-T2/T3 | D4 | Use :id when URL/client/security unchanged; never expose DB PK. OPEN |
| REQ-038 | API / MUST† | IDX | P8; route inventory | P8-T4 route/schema cross-check | D4 | Every app JSON /api/vN route described or narrowly exempted. OPEN |
| REQ-039 | TEST / MUST† | IDX | P8; safe tooling | P8-T4 lint/bundle/idempotence/verify | D4 | OpenAPI sources and bundles match. OPEN |
| REQ-040 | API / MUST† | IDX | P8; P8-T4 | P8-T2/T4 contracts | D4 | Exemptions narrow; content/auth/CSRF/cache/errors accurate. OPEN |
| REQ-041 | FUNC / MUST† | IDX | P8 roots; route inventory | P8-T1 root matrix | D5 | All Auth/Base/Core/Side/Palm roots behavior-observed. PARTIAL: 13 static candidates. |
| REQ-042 | SEC / MUST† | IDX | P8 roots; P8-T1 | root ri and unsafe return test | D5 | Valid ri preserved; auth redirects temporary; private home protected. OPEN |
| REQ-043 | AD / MUST† | IDX | P8 roots; P8-T1 | Core/Palm request contract | D5 | No invented dashboard or browser redirect to native JSON. OPEN |
| REQ-044 | AD / MUST† | IDX | P2b/P8; direct-entry choice | P2-T3/P8-T1 | D1/D5 | Roots align with chosen entry flow; no retired flow revival. Direct entry blocked. |
| REQ-045 | INV / MUST† | IDX | P9; green baseline | P9-T1 timestamp semantics | D7 | created_at/updated_at are persistence metadata only. OPEN |
| REQ-046 | DATA / MUST† | IDX | P9; P9-T1 | query/write/serialization audit | D7 | No generic alias substitutes for domain time. OPEN |
| REQ-047 | DATA / MUST† | IDX | P9; data history | P9-T1/backfill rehearsal | D7 | Relationship timestamps change only on proven lifecycle. OPEN |
| REQ-048 | TEST / MUST† | IDX | P9; green baseline | P9-T2 harness controls | D7 | Narrow guard catches violations without unjustified false positives. OPEN |
| REQ-049 | FUNC / MUST† | IDX | P9; affected domain owners | P9-T1 lifecycle tests | D7 | Domain event time changes only at named transition. OPEN |
| REQ-050 | TEST / MUST† | IDX | P9; P0 GREEN | P9-T2/T3 coverage | D7 | Private-test cleanup retains baseline and behavioral coverage. ENV-BLOCKED until baseline. |
| REQ-051 | FUNC / MUST† | IDX | P3 ORG; P0 | P3-T4 ORG entry tests | D1/D2 | Entra, independent normal SecretKey and restricted Emergency per policy. PARTIAL; full trace pending. |
| REQ-052 | SEC / MUST† | IDX | P3 ORG; P3-T4 | Entra single-tenant/PKCE/state/nonce | D1/D2 | No JIT; provisioning and protocol guards preserved. OPEN |
| REQ-053 | SEC / MUST† | IDX | P3 ORG; P3-T4 | SecretKey owner-binding tests | D1/D2 | SecretKey cannot switch owner or bypass Entra/session policy. OPEN |
| REQ-054 | SEC / MUST† | IDX | P3 ORG; P3-T4 | Emergency attempt/success/mode | D1/D2 | Emergency stays restricted; no normal fallback or in-session conversion. OPEN |
| REQ-055 | FUNC / MUST† | IDX | P3 ORG; signup policy | P3-T4 signup visibility | D1/D2 | Signup shown only when provisioning policy permits. OPEN |
| REQ-056 | FUNC / MUST† | IDX | P3 ORG; P3-T4 | locale/host/copy contract | D1/D2 | Org host/i18n isolation holds; Emergency not recommended as normal. OPEN |
| REQ-057 | SEC / MUST† | IDX | P4; P0/P1 | P4-T1 seven-client registry | D3 | Seven IDs, separate keys, PKCE S256/private_key_jwt hold. OPEN |
| REQ-058 | SEC / MUST† | IDX | P4; P4-T1 | multi-tab/cookie/return target | D3 | Browser RP state short-lived, protected and RP-scoped. OPEN |
| REQ-059 | SEC / MUST† | IDX | P1; P0 | P1-T1/T2 | D3 | Digest-keyed Valkey code is short-lived, atomic, one-use and fail-closed. OPEN |
| REQ-060 | DATA / MUST† | IDX | P1; P0 | assertion JTI duplicate/DB failure | D3 | JTI replay remains unique and fail-closed. OPEN |
| REQ-061 | DATA / MUST† | IDX | P4; P1/P2a | P4-T2 uniqueness/concurrency | D3 | Identity → Base session → RP session; one active usage per session/client. OPEN |
| REQ-062 | SEC / MUST† | IDX | P4; P1 | P4-T2 selective and parent revoke | D3/D6 | Revoke hierarchy works without ordinary-request RP Session DB lookup. PARTIAL; Rails unrun. |
| REQ-063 | FUNC / MUST† | IDX | P4; P4-T3 | admin registry/session request | D3 | Client registry configuration and user RP Sessions stay distinct. OPEN |
| REQ-064 | NFR / MUST† | IDX | P0; test isolation | P0-T1/T3 Valkey proof | This plan / later ops note | One-Valkey roles, structured access/hiredis and unique run/worker namespace; no shared flush. ENV-BLOCKED. |
| REQ-065 | CLEAN / MUST† | IDX | P2a; P2-T4 | Auth RP caller/dependency audit | D1 | Remove only proven Auth RP work; preserve ceremony and Jump JWKS. OPEN |
| REQ-066 | TEST / MUST† | IDX | P0; isolated services | P0-T2 baselines | This plan | Green attributable baseline before broad cleanup; necessary security fixes not delayed. ENV-BLOCKED. |
| REQ-067 | CLEAN / MUST† | IDX | P9; P0 GREEN | P9-T2 private-test inventory | D7 | Each test classified/replaced, or dead code proven. ENV-BLOCKED for deletion. |
| REQ-068 | CLEAN / MUST† | IDX | P9; production callers | P9-T3 visibility behavior | D7 | Public only for real collaborator contract; protected only genuine extension point. OPEN |
| REQ-069 | INV / MUST† | IDX | P10; all checks | P10-T2 diff/gate review | This plan | No thresholds/assertions/skips/linter/security weakening. HORIZONTAL. |
| REQ-070 | SEC / MUST† | IDX | P6; Step-Up contract | P6-T5 Google/Apple link | D2 and adr/social-identity-linking-requires-step-up.md | Fresh Step-Up for both providers. SAT-SOURCE; Rails unrun. |
| REQ-071 | SEC / MUST† | IDX | P6; P6-T5 | signup/link/unlink matrix | D2 and existing ADR | Signup distinct; unlink Step-Up/no-lockout; no automatic fresh-login reuse. SAT-SOURCE; verify Rails. |
| REQ-072 | DOC / MUST† | IDX | P6; P6-T5 | ADR/source/test alignment | adr/social-identity-linking-requires-step-up.md | STAY is clear and authority-compatible. SAT-SOURCE; tests unrun. |
| REQ-073 | SEC / MUST† | IDX | P6; cookie scope audit | P6-T6 browser cookie jar | D8/security docs | Successful sign-out deletes both credentials at matching scope if reproduced. OPEN |
| REQ-074 | TEST / MUST† | IDX | P6; P6-T6 | immediate sign-in/surface/CSRF | D8 | Old cookies cannot block/login; app/com/org remain isolated. OPEN |
| REQ-075 | ROUTE / MUST† | IDX | P7; session inventory | P7-T1 routes/helpers | D6 | User session resource /sessions; /sign/out stays a separate ceremony. OPEN |
| REQ-076 | SEC / MUST† | IDX | P7; P7-T1 | owner tampering/CSRF/GET | D6 | Only own session may be revoked; no ordinary token request lookup. OPEN |
| REQ-077 | FUNC / MUST† | IDX | P7; P7-T1 | dashboard/current/action | D6 | Current versus other sessions clear; no internal IDs exposed. OPEN |
| REQ-078 | DATA / MUST† | IDX | P7; current presenter | P7-T2 mixed visibility/risk | D6 | Event/risk/visibility separate; internal rows SQL-filtered. PARTIAL. |
| REQ-079 | SEC / MUST† | IDX | P7; P7-T2 | props/DOM/raw/private-IP | D6 | No raw context/secrets/private IP/technical enum. PARTIAL; presenter redacts now. |
| REQ-080 | FUNC / MUST† | IDX | P7; session inventory | P7-T3 session props | D6 | Safe Device/Unknown shown; internal Kind/Binding/IDs/refresh expiry hidden. PARTIAL. |
| REQ-081 | SEC / MUST† | IDX | P7; current expiry source | P7-T4 refresh/Access/absolute | D6 and docs/security/refresh-token-rotation.md | Fixed root ceiling; rotation cannot extend; expiry/revoke cannot revive. SAT-SOURCE; Rails unrun. |
| REQ-082 | SEC / MUST† | IDX | P7; P3-T4 | P7-T3 org mode/DBSC cross-test | D6/D1 | Emergency uses explicit context, independent of DBSC. PARTIAL; verify tests. |
| REQ-083 | FUNC / MUST† | IDX | P7; preference source | P7-T5 formatter boundaries | D6 | Preferences render timezone/date/clock; sort uses instant. PARTIAL; shared helper exists. |
| REQ-084 | NFR / MUST† | IDX | P7; P7-T1–T5 | query/owner/locale/surface | D6 | No N+1, secrets or cross-principal reads; i18n and query bounds hold. OPEN |
| REQ-085 | FUNC / MUST† | IDX | P6; current controllers | P6-T7 React/Inertia | UI docs | Server props drive disabled Create and Avatar Up. SAT-SOURCE; Bun passed, Rails unrun. |
| REQ-086 | SEC / MUST† | IDX | P6; P6-T7 | route/write diff | UI docs | No create route/write/provisioning; existing Avatar create unchanged. SAT-SOURCE; route test pending. |
| REQ-087 | FUNC / MUST† | IDX | P6; current UI change | P6-T1 app/com 422/fresh GET | D8 | Entered email returns on eligible error; fresh GET empty; no session/log copy. PARTIAL; Rails unrun. |
| REQ-088 | SEC / MUST† | IDX | P6; Turnstile boundary | P6-T2 signup OTP POST | D8 | Fresh visible Turnstile verified before OTP/state mutation. OPEN; no call found in inspected update path. |
| REQ-089 | SEC / MUST† | IDX | P6; Turnstile boundary | P6-T2 sign-in OTP POST | D8 | Server verifies before OTP/attempt/session; dummy/real behavior stays comparable. OPEN; no call found in inspected update path. |
| REQ-090 | SEC / MUST† | IDX | P6; P6-T1/T2 | props/session/flash/DOM/Inertia | D8 | Failed OTP never repopulates or persists. OPEN |
| REQ-091 | SEC / MUST† | IDX | P6; P6-T2 | Turnstile single-use/retry | D8 | Each retry has fresh challenge/token; no stale replay. OPEN |
| REQ-092 | NFR / MUST† | IDX | P6; isolated query test | P6-T3 Visitor/Client query count | D8 | Validators preserved; repeated recovery identity SELECTs eliminated. OPEN |
| REQ-093 | TEST / MUST† | IDX | P6; P0/P2a | P6-T1/T2 four normal flows | D8 | app/com signup/sign-in reaches expected next step without live Jump/provider. OPEN |
| REQ-094 | FUNC / MUST† | IDX | P6; locale/mailer inventory | P6-T4 subject/body | D8 | Japanese/English purpose subject; no OTP in subject; body unchanged. OPEN |
| REQ-095 | INVEST / MUST† | IDX, truncated | P10; original source | P10-T2 restore ORG fragment | D9 | Missing text not invented; source gap explicit. SOURCE-LIMITED |

Known conflict/finding links for the row-level ledger: REQ-001–006 → C-01 (current planning-only scope versus earlier execution prompts); REQ-007–010, 032, 041–044, 065 → C-02/C-13/ADV-005/ADV-012 (authority boundary and unresolved direct-entry UX); REQ-009, 011–013, 030 → ADV-001/ADV-006 (event time and OIDC freshness); REQ-016–019 → C-07/C-08/ADV-004/ADV-011 (nonce policy, per-client DPoP and unvalidated devices); REQ-020, 059–062 → C-06/C-11/ADV-002/ADV-003 (horizontal invariant, accepted revocation risk, owner-bound replay and cross-store failure); REQ-021–027, 034–040 → C-09/ADV-009 (GUID route and net OpenAPI ownership); REQ-064, 066, 069 → ADV-007 (safe baseline and invariant protection); REQ-070–072 → current accepted STAY ADR; REQ-073–094 → P6/P7 findings as listed above; REQ-081 → C-12 (absolute session ceiling versus refresh lifetime); REQ-095 and exact P00–P17 attribution → C-03/ADV-008. Rows not listed have no additional conflict identified in the normalized ledger; that is not evidence that missing original wording contains no conflict.

Audit result: IDs 001–095 appear exactly once in this traceability table, including REQ-020. There is one primary phase per row. Horizontal conditions, especially REQ-020, apply everywhere and are not extra owners. REQ-016–019 map to P5, REQ-064 to P0, and REQ-055/056 to P3 ORG. Other phases can cross-test a requirement without changing its primary owner. Original P00–P17 attribution for each ID remains unverified.

## 9. Revised implementation sequence and phase requirements

### P0 — Evidence lock, safe harness and attributable baseline

Status: BLOCKED_BY_ENVIRONMENT for Rails/service tests; planning/static checks may continue.

Objective: Prove an isolated test environment before touching Rails routes, tests, database or Valkey. Capture comparable baseline before any code change.

Preconditions and investigation references: current branch/HEAD/status; config/database.yml; config/environments/test.rb; Valkey connection builder/namespaces; .simplecov; bin/rails; test/test_helper.rb; package.json; vitest.config.ts; bin/ci; Docker/Compose service declarations.

Tests first / sequence:
1. Record baseline Git status, tracked diff, unknown paths, tool/runtime versions without mutation.
2. Provision or verify a disposable PostgreSQL endpoint/user/database and separate Valkey endpoint or truly unique namespace per run/worker. Confirm every app Valkey client, including AUTH_STATE_REDIS_URL and fixed default namespaces, resolves there. Logical DB number alone is not isolation.
3. Demonstrate outbound HTTP is stubbed or denied for all Rails services; verify OTP mail/SMS, Turnstile, provider IdP, Jump and webhook adapters use test fixtures/fakes.
4. Only after steps 2–3 succeed, run targeted baseline, full Rails baseline, coverage-enabled Rails baseline, ordinary Vitest, Vitest coverage, static checks and bin/ci as separate recorded results.
5. Preserve line/branch/method totals, per-file/per-group values, max-drop comparison, skips, errors, JS statements/branches/functions/lines and tool versions. A red run never becomes the green baseline.

Non-change scope: no shared endpoint probe, no DB reset/drop/recreate, no production fallback, no security-control disable, no coverage threshold/exclusion change.

Verification after isolation proof: bin/rails test; COVERAGE=true bin/rails test test/; bun run test; bun run test:coverage; package scripts for lint/typecheck/build; bin/ci; bin/rails routes; bin/rails notes. Run only when the relevant services are isolated.

Completion: all targets demonstrably disposable/stubbed; baseline and coverage reports attributable; skips/failures identified. Current status does not meet this.

Recovery/stop: if any service URL is shared or unknown, stop that command and continue static work. Do not point at Valkey DB 2 or infer safety from test_ names. Forward repair is an isolated test target, not weakened auth behavior.

### P1 — Authorization-code owner binding, replay and store-failure closure

Status: READY_WITH_PRECONDITIONS; execution depends on P0 isolation.

Objective: Preserve one-use code/replay protection while only the rightful client/binding can trigger replay revocation and no unlinked or ambiguous cross-store exchange returns credentials.

Investigation references: app/services/oidc_token_exchange_coordinator.rb; app/services/valkey/auth_state/authorization_code_store.rb; app/controllers/concerns/base_oauth_token_endpoint.rb; app/operations/rp_session_revoker.rb; token endpoint request tests; RFC 6749 §§4.1.2–4.1.3.

Tests first: P1-T1 A/B endpoint matrix; P1-T2 Lua/read-consume concurrency; P1-T3 failure injection; P1-T4 same-owner replay and child-only revocation. Public request tests are primary; store-unit tests are complementary.

Implementation order after authorization: bind client_id and redirect_uri in Ruby prevalidation and atomically in Lua before replay classification; maintain PKCE/expiry checks; allow only valid same-owner replay to revoke its linked family; positively check link status; define safe rollback/restart for missing/invalid_state/exception/ambiguous outcomes; add only the family cleanup fallback needed when a tombstone references rolled-back DB state; bound RecordNotUnique retry and prove PG transaction state; then adjust DPoP consume ordering only if retry remains safe.

Non-change scope: do not remove replay revocation, reissue consumed codes, revoke Base sessions because of child-code replay, add per-request DB lookup, or change accepted short Access JWT residual lifetime.

Acceptance: all owner/replay cases in §5.1 pass with Valkey and PostgreSQL observations; every §5.2 failure returns no successful token unless required links and DB state are positively established; concurrency yields at most one live result; recovery is fresh authorization, never code resurrection.

Verification: focused store/coordinator tests; token endpoint integration; same-session/client concurrency; PostgreSQL/Valkey suite; Rails and unchanged security/static gates.

Recovery/stop: correct a bad comparison rather than relaxing assertions. If ambiguous residue remains, suppress only unsafe token issuance and recover with fresh authorization. Stop if non-owner behavior or bounded recovery cannot be demonstrated.

### P2a — Base-owned admission and accepted result for RP-originated authentication

Status: READY_WITH_PRECONDITIONS; coordinate with P1/P3 and require P0 before request tests.

Objective: Make successful RP-originated sign-in commit authority only at Base while retaining permitted Auth credential-ceremony continuity.

Investigation references: adr/base-auth-ceremony-and-seven-rp-boundary.md; app/controllers/concerns/auth_ceremony_admission.rb; app/controllers/auth/{app,com,org}/application_controller.rb; sign-in leaves; app/operations/authentication_session_committer.rb; app/controllers/concerns/authentication_base.rb; BaseAuthAdmissionCoordinator; Base authorization/callback controllers; OidcSsoInitiator and sign-rp callers.

Tests first: P2-T1 requests with absent, valid, expired, replayed, wrong-purpose, wrong-actor and wrong-surface admission; P2-T2 admitted RP success per realm; P2-T4 before/after rows, Set-Cookie, DBSC headers, Auth/Base client/visitor/operator token records and final Base acceptance.

Sequence: enumerate route → inherited before_actions → leaf action → credential proof → committer → cookies/DB → Base result. Make a Base-originated one-time result the sole authority transition. Auth returns bounded evidence; Base validates actor/realm/intent/expiry/replay/browser binding, decides identity/session/acr and commits. Remove only Auth-side identity/token writes on proven paths. Keep ceremony-local opaque sessions/cookies and required provider verification. Preserve Jump signing/JWKS dependencies; remove stale Auth-as-RP calls only after call-graph proof.

Non-change scope: no blanket Auth cookie/model/session deletion, no weakening CSRF/PKCE/state/nonce, no Base authority in Auth claims, no fabricated RP client/code/assertion, no Jump repository/service change.

Acceptance: for app/com/org separately, absent/invalid admission creates no Base identity/session/RP result; a valid admitted ceremony yields Base-accepted result and only Base-owned durable login; Auth ceremony state is opaque continuity and not sufficient proof. Entra, SecretKey, Emergency, Step-Up, social link and sign-out are traced separately. Do not infer org from app/com.

Verification: focused request tests per surface; result replay/owner tests; full RP auth integration; cookie scope assertions; policy and route tests.

Recovery/stop: preserve data until read/write owners and row impact are known. Do not migrate/drop Auth token tables solely due namespace. If dual authority is observed, stop destructive work and produce an ownership migration proposal. Any changed invariant is PLAN_DEVIATION.

### P2b — Direct Auth entry and Base-local sign-in product decision

Status: BLOCKED_BY_DECISION.

Objective: Implement no local/direct-entry UX until the user selects product behavior. Investigation and options are ready; direct-entry completion is not.

Current behavior evidence: admission-less Auth selector bridges to same-realm Base root. Base anonymous root links appear to return to raw Auth selector. Static only; not browser-reproduced. Candidate root surfaces: Auth/Base/Core/Side each app/com/org and Palm app, 13 total. Runtime route set remains unverified.

Choices requiring the user:
A. Support a Base-local sign-in/signup UX. Specify which Base root/entry offers it, where success ends, how step-up/social link returns, and whether the result is a local Base session with no RP code.
B. Make direct Auth entry non-authenticating and RP-only; specify whether the root is landing-only, returns to Base entry or is retired. No RP transaction is synthesized.
C. Retain Auth as a visual front door but create a Base-owned local-purpose admission and Base-local completion. This remains a product flow decision; Auth still does not own login.

The choice must specify initial URL, anonymous result, already-authenticated result, success target, cancellation/error/retry, ri propagation, host transition and whether Base creates a local authenticated session. No selection is made here.

Tests after decision: P2-T3 and P8-T1 verify navigation, login state, ri=jp, temporary status, no arbitrary return URL, no root loop, private dashboard, and no Core API/Palm bearer effect. Stop only this direct-entry slice until answered; continue independent work.

### P3 — OIDC freshness, auth_time, AAL/ACR/AMR and ORG entry

Status: READY_WITH_PRECONDITIONS for protocol design/tests; direct-entry decision blocks only local-flow integration.

Objective: Preserve actual credential-event time and correctly enforce OIDC freshness without turning Auth into assurance authority.

Investigation references: §4; Base app/com/org authorize_params; transaction model/coordinator; Auth result evidence; authorization-code payload; exchanged Access/ID/refresh issuers; all RP callback validators; docs/security/authentication-assurance-levels.md; adr/authentication-assurance-level-boundaries.md; OIDC claims/step-up/WebAuthn docs; ORG Entra/SecretKey/Emergency routes and policies.

Tests first: P3-T1 time travel with event T0, code issue T1 and exchange T2 separated; ID/Access auth_time must be T0 and iat T2. A later refresh keeps auth_time and gets a new iat. Real accepted reauthentication at T3 updates auth_time to T3. P3-T2 tests recent/stale max_age, max_age=0, prompt=login, prompt=none. P3-T3 tests acr/amr and sign-in/step-up/AAL dimensions. P3-T4 separately tests org owner/policy behavior.

Sequence: establish event evidence source; extend existing Base transaction/result only as needed; carry prompt/max_age; enforce Base freshness; issue immutable auth_time; keep iat/code issued_at/persistence times separate; validate returned claims in RP callbacks; preserve actual AMR and Base-selected ACR; reconcile docs and NIST-inspired product language; record SMS risk acceptance and actual controls; trace ORG Entra, independent SecretKey, Emergency restrictions and signup policy.

Acceptance: stale session cannot satisfy max_age; prompt=login triggers genuine reauthentication; prompt=none errors if it cannot; ID Token returns the correct auth_time; refresh/consent/callback do not advance it; Step-Up does not automatically mean NIST AAL2; signup/social link/Emergency have independent contracts.

Non-change scope: no invented timestamp fallback, formal NIST/FAL claim, SMS removal, unsupported provider assurance escalation or direct-entry decision.

Verification: focused OIDC transaction/controller/token/RP tests; ceremony/assurance tests; app/com/org owner isolation; API contracts only where changed; affected docs.

Recovery/stop: if no authoritative event time exists, do not substitute now/created_at; require valid reauthentication or explicit non-authenticating failure for freshness-required requests. Before new storage, document backfill/nullability/deployment/rollback. No destructive migration without a data plan.

### P4 — Shared Core/Side/Edit RP and session hierarchy

Status: READY_WITH_PRECONDITIONS; depends on P0, P1 and P2a; P3 callback claim contract required before final token acceptance.

Objective: Use one semantically shared RP protocol boundary for Core, Side and Edit; preserve N-instance Core/Side and boundary-only singleton Edit policy.

Investigation references: RP controllers/services/routes, state/nonce/PKCE, RFC 9068 validation, client registry, logout, sessions and callback tests; accepted seven-RP ADR.

Tests first: P4-T1 shared start/callback contract and failure paths; P4-T2 hierarchy, active-usage constraint, concurrent exchange and revoke; P4-T3 registry/admin policy. Isolate two hypothetical Core/Side deployments and Edit.

Sequence: compare actual code/tests; extract only same-semantic protocol mechanics; make Edit policy/client/redirect/cookie namespace configuration; remove hostname conditionals from shared code; validate issuer/audience/signature/temporal/type/usage/redirect/replay; rotate session safely; preserve logout cleanup.

Non-change scope: no Auth RP, no host case tree in common code, no single Core/Side deployment assumption, no invented Edit dashboard, no normal Access request session lookup.

Acceptance: Edit completes a Base RP flow through shared code; Core/Side remain compatible; clients/deployments cannot share state, keys, redirects, sessions or audiences; callbacks fail closed and recover.

Verification: shared contract, Edit integration, Core/Side regression, browser/session/logout, route and full Rails suites.

Recovery/stop: if the registry cannot represent Edit without changing Base contract, report a plan deviation. Do not copy protocol logic or weaken a common check.

### P5a — DPoP / DBSC protocol-level audit and automation

Status: READY_WITH_PRECONDITIONS for automated tests and server fixes; client enforcement is a separate decision.

Objective: Compare runtime paths with RFC 9449 and current DBSC contract; improve safe server behavior while preserving supported clients.

Investigation references: app/lib/dpop_proof_verifier.rb; DpopNonceService/JTI store; AccessTokenAuthenticator; token endpoint; Resource Server endpoints; authorization metadata; client policy/ADR; app/services/dbsc_registration_service.rb and dbsc_verification_service.rb; SignDbscRegistrationEndpoint; Base/Auth app/com/org DBSC routes; refresh/session/logout.

Tests first: P5-T1 proof typ/alg/JWK/thumbprint/htm/htu/iat/jti/ath/binding, wrong key and replay; P5-T2 token endpoint error/order and actual nonce policy; P5-T3 DBSC registration/challenge/proof/refresh/expiry/replay/logout/revoke/unsupported browser/fallback.

Sequence: establish each endpoint/current client policy; determine whether proof is required per client; verify DPoP cnf.jkt and Resource Server enforcement; correct bad-proof error; design code-consumption order with P1; inspect AS metadata; trace DBSC request header → record → cookie → refresh → revocation. Never echo secrets.

Non-change scope: no universal Bearer removal, no policy based only on native suitability, no immediate revocation claim, no device-validity assertion, no client-only security.

Acceptance: automated protocol tests and unsupported-device fallback pass; existing Bearer behavior matches current policy; DPoP tokens cannot be replayed without the key; DBSC is marked provisional/device-validation-pending.

Verification: focused DPoP/DBSC tests, token endpoint and resource request integration, per-surface routes, security/static checks. Physical hardware is unnecessary for protocol unit/contract tests.

### P5b — Real-client and physical-device validation debt

Status: DEFERRED_VALIDATION.

Objective: Keep a named validation debt until representative clients/devices/browser versions can be exercised. Unit tests never close it.

DBSC matrix: supported browser registration, key creation/persistence, restart, bound-session refresh, stolen-cookie rejection, invalid proof, logout, session revoke and unsupported-browser fallback.

DPoP matrix: native secure-key storage, proof generation, AS and Resource Server verification, wrong-key/token replay, process restart/key persistence, real browser/BFF/native interoperability for each client choosing DPoP.

Completion requires dated environment, device/browser/client versions, observed result and artifacts with no secrets. Current status is validation pending.

### P6 — Independent UI, email OTP, mail, social link and sign-out slices

Status: READY_WITH_PRECONDITIONS. React-only checks are available; Rails work depends on P0.

Objective: Complete independent UI/authentication changes without coupling them to unresolved direct-entry UX.

Fail-first test catalogue:
- P6-T1 signup email preservation and OTP clearing after app/com 422.
- P6-T2 app/com signup and sign-in OTP submissions with missing/invalid/single-use Turnstile; prove verification precedes OTP and attempt/session commit.
- P6-T3 visitor/client recovery-identity query count from birthdate/top-up public flow.
- P6-T4 locale-specific mail subject/body contract.
- P6-T5 Google and Apple existing-account link Step-Up, signup distinction, callback direct request and unlink no-lockout.
- P6-T6 successful sign-out cookie jar, Set-Cookie deletion scope and immediate sign-in.
- P6-T7 disabled Create buttons and Avatar Up navigation.

Sequence: retain UI/mock work already implemented; inspect exact POST boundary; add public behavior tests; enforce server Turnstile before OTP verification; clear OTP after recoverable failure and require fresh widget challenge; preserve dummy-account timing/enumeration; preload Visitor recovery identity associations inside top-up; update only shared mail subject path; compare cookie write/delete name/domain/path/secure/httponly/same_site; retain Step-Up policy. A submitted value can exist in transient request/DOM memory while the user types; the rule prohibits persistence/repopulation after failure.

Current evidence: sign-in email-entry create actions call server Turnstile, but inspected app/com sign-in update paths show no Turnstile verification before OTP validation. Signup email OTP app/com update actions likewise proceed through gate/session checks and OTP verification without a Turnstile call in the searched controller/support paths. This is static evidence; confirm inherited callback order and actual browser form. Current HEAD already contains signup email prop and disabled Create changes; Bun tests pass, relevant Rails checks are unrun. Social-link Step-Up ADR/tests exist but Rails verification is pending.

Non-change scope: no Jump change, validation bypass, Prosopite suppression, OTP/passcode in logs/session/props, fake Create route/write, change to unrelated Avatar provisioning, or cookie fix unless scope mismatch is reproduced.

Acceptance: P6 tests pass; Turnstile failure consumes neither OTP attempt nor login/session state; retry has empty OTP and fresh challenge; account-enumeration behavior is unchanged; top-up query count does not grow per credential; subject has no OTP; normal logout removes both cookies at exact scope if reproduced; Create remains disabled and route-free.

Verification: Bun feature tests; Rails app/com controller, integration, model/service and mailer tests; query regression; security checks; full suite only after P0 proof.

### P7 — User Activities, Sign-in Sessions, preferences and expiry presentation

Status: READY_WITH_PRECONDITIONS; Rails/data assertions depend on P0.

Objective: Keep account self-service safe and preference-correct without duplicate domain models.

Investigation references: app/presenters/base/identity/activity_log_presenter.rb; app/controllers/base/{app,com,org}/identity/{activities,sessions}_controllers.rb; Chronicle/event-type/visibility schema; SessionPresenter; SessionTimestampHelper; Preference path; RefreshTokenable; SessionAbsoluteExpiryValue; root/RP session models; docs/security/refresh-token-rotation.md.

Tests first: P7-T1 /sessions auth, owner-scope spoofing, CSRF, GET non-mutation and current-session restriction; P7-T2 mixed visibility/risk, raw context/provider/private-IP exclusion; P7-T3 safe device fallback/current/active/Emergency versus DBSC; P7-T4 creation ceiling, repeated refresh, Access/refresh cap, absolute expiry reject, revoke/no revival; P7-T5 timezone/date boundaries, ISO/US/UK, 24h/12h, midnight/noon and sort by instant.

Sequence: reuse current risk/visibility map and stable rank unless tests show it cannot represent separate dimensions; filter visibility in SQL before pagination; keep database errors distinct from empty activity (investigate current ActiveRecord rescue); use owner-scoped session relation; trace forms/helpers before changing route; preserve /sign/out and Core /api/v0/session; use actual device metadata or localized Unknown; org Emergency comes from explicit authentication context; format via shared preference helper.

Non-change scope: no duplicate risk FK/table, no Chronicle severity repurpose, no internal ID/secret in UI, no cross-realm reads, no normal-request DB lookup, no expiry column while existing ceiling contract holds.

Acceptance: app/com/org request/DOM tests show only safe facts; own-only revoke/current-session guard; preference output correct; sorting by stored instant; refresh cannot extend absolute session ceiling; already-issued Access JWT revocation stays natural expiry.

Verification: targeted Rails request/model tests, React tests, query budget, accessibility/i18n, all surfaces, then suite after P0.

Recovery/stop: preserve unclear timestamp/device semantics rather than guessing. If discarded_at fails boundary tests, first trace all writers/readers and migration history before proposing another field.

### P8 — Routes, roots, API/OpenAPI inventory and GUID resolver decision

Status: READY_WITH_PRECONDITIONS for inventory and unambiguous APIs; BLOCKED_BY_DECISION for GUID public path/OpenAPI ownership and direct-entry-dependent roots; generated Rails route output is ENV-BLOCKED until P0.

Objective: Remove proven obsolete entrypoints, converge valuable APIs without guessing external contracts, accurately cover application JSON operations.

Investigation references: every config/routes/*.rb; bin/rails routes; controller/caller/helper/JS/docs/ADR search; proxy/deployment maps; adr/api-route-vocabulary-consolidation.md; OpenAPI app/com/org sources, redocly.yaml, route coverage tests/public bundles; config/routes/guid.rb; Auth/Base/Core/Side/Palm roots.

Tests first: P8-T1 generated route inventory and public root matrix; P8-T2 each API success/invalid/unauthorized/CSRF/content negotiation/Problem Details/cache/header; P8-T3 GUID exact lookup, nil canonical URL, unknown 404, DB failure 5xx, escaping/injection/encoding/long ID/no redirect/host isolation; P8-T4 route/schema cross-check, Committee, lint, deterministic bundle and verify.

Sequence: read every route file statically; after safe boot, run bin/rails routes and notes; classify /api/vN, /web/vN and /edge/vN using callers/tests/runtime/deployment evidence; delete only proven dead surfaces; migrate valuable application APIs to resourceful /api/v0 and Api::V0; preserve protocol, CSP, .well-known, OmniAuth and operational paths; retain custom :guid only if :id change is not demonstrably URL-safe; update OpenAPI sources then generate bundles; ensure route discovery includes Edit and every actual service; keep external protocol exemptions narrow; resolve GUID path/net schema before declaring complete.

GUID options: (1) preserve existing /api/v0/resources/:guid and add net OpenAPI only if the API owner confirms; (2) use earlier explicit /resources/:eid outside api/v0 as a public non-versioned resolver contract with specific rationale; (3) expose both only if both are explicitly accepted and share one implementation. No option is selected here.

Root inventory candidates: Auth app/com/org; Base app/com/org; Core app/com/org; Side app/com/org; Palm app. Measure anonymous/authenticated behavior for each. Auth local-dashboard expectations do not resolve the direct-entry question. Base anonymous-to-Auth must not loop. Core is BFF/service; Palm is native/bearer. Do not invent dashboards or redirect native root to JSON.

Non-change scope: preserve documented CSP/.well-known path mappings; do not redirect machine requests through browser auth; do not expose numeric PK; no compatibility aliases for unresolved contracts; no broad protocol exemptions.

Acceptance: no duplicate routes/helper/verb expansion; remaining legacy routes have evidence-backed purpose; every app JSON /api/vN route has OpenAPI coverage or a narrow tested external-protocol reason; sources and generated artifacts match; host/surface root behavior holds. A permanent FIXME is not coverage closure.

Verification: bin/rails routes, bin/rails notes, route/request tests, coverage and contract tests, bun run openapi:lint, bun run openapi:bundle, deterministic rerun, bun run openapi:verify in clean/staged-equivalent state. No staging in this planning run.

Recovery/stop: retain a route when actual consumers/protocol require it. If GUID surface decision remains open, stop only that contract slice and present alternatives.

### P9 — Timestamp semantics, private-method tests and public API cleanup

Status: BLOCKED_BY_ENVIRONMENT for broad cleanup until P0 has an attributable green Rails baseline; static inventory is independent.

Objective: Audit created_at/updated_at semantics and reduce unnecessary public methods/direct private-method testing without losing behavioral coverage.

Investigation references: all app/lib Ruby reads/writes/queries/serialization of created_at/updated_at; migrations/history; domain transitions; test helper/SimpleCov; architecture baselines; tests using send, __send__, instance_eval, instance_exec, private_methods, private_method, public, respond_to?(..., true), internal-method stubs.

Tests first: P9-T1 characterize each suspected domain-time use through public behavior; P9-T2 classify private-helper test A/B/C/D and add public behavior coverage; P9-T3 visibility architecture without per-helper reflection tests.

Sequence only after P0 GREEN: capture per-file/group coverage; inspect production callers/framework hooks; work one class at a time; add public test first; change visibility or remove proven dead method; remove redundant private test after replacement; run focused tests/coverage; periodically full Rails/architecture/RuboCop.

Non-change scope: no SimpleCov threshold/exclusion/group changes, no nocov regions, no skipped/pending tests, no baseline increase for new violation, no private method made public for test convenience, no semantic timestamp replacement by name alone, no broad cleanup.

Acceptance: final Rails line/branch/method/file/group gates meet current rules and no-drop baselines; suite has zero failures/errors; no semantic use of persistence timestamps remains without a persistence-only rationale; private methods are covered only via public/framework behavior or genuinely dead code is removed.

Verification: focused tests, architecture harness, RuboCop, coverage-enabled Rails suite and full suite. No green Rails baseline exists yet.

Recovery/stop: if a method may be metaprogramming/framework invoked, do not delete based on rg alone. If event semantics are unclear, preserve and request a specific domain decision.

### P10 — Final independent reverse audit and completion gate

Status: READY_WITH_PRECONDITIONS; only after separately authorized implementation and P0/P1–P9 completion.

Objective: Infer actual behavior from final code and public contracts rather than check whether filenames resemble this plan.

Procedure: (1) start from public routes; (2) trace authority/event time from credential evidence through Base transaction, code, JWT/ID Token and refresh; (3) falsify owner/replay/concurrency/partial-store guarantees over HTTP with controlled clients A/B; (4) inspect Auth/Base rows and cookies; (5) test current/other-session owner boundaries; (6) test DPoP/DBSC protocol and separately report device status; (7) inspect props/HTML for secrets/raw audit data; (8) compare every JSON route with OpenAPI; (9) review tests for weakened assertions, skips, bypass mocks and exclusions; (10) compare inferred behavior against all 95 IDs and restored source text; (11) run isolated Rails, canonical JS coverage, static/security and bin/ci; (12) report implemented/validated, validation pending, planned, unresolved, accepted risk and superseded separately.

No independent reviewer was used in this plan run. Future independent review should receive final diff and acceptance matrix. Unit tests cannot close physical-device validation.

Completion: no unresolved blocker in selected scope; no silent architecture choice; no orphan mandatory requirement; every selected phase has passing checks; exact source limitation stays disclosed; coverage gates pass; no invariant is weakened; physical/client/browser checks remain pending unless observed.

## 10. Dependency DAG and phase disposition

The dependency graph is:

    P0 safe isolation / attributable current baseline
    ├── P1 code replay ownership and Valkey/PostgreSQL failure
    ├── P2a admitted RP ceremony / Base-owned commit
    ├── P6 independent UI, OTP, mail, social-link, sign-out and disabled actions
    ├── P7 activity/session/preferences
    └── P8 route/API inventory and unrelated migrations
    P1 + P2a ──> P3 auth_time, max_age/prompt, assurance and ORG
    P1 + P2a + P3 ──> P4 shared Core/Side/Edit RP integration
    P1 + P2a + P3 ──> P5a DPoP/DBSC automated protocol work
    P5a ──> P5b real client/device validation
    P0 GREEN ──> P9 broad private-test/visibility cleanup
    P2b user decision ──> only local/direct Auth entry and dependent root completion
    GUID contract decision ──> only GUID canonical path/net OpenAPI scope
    P1–P9 selected and verified ──> P10 final reverse audit

There is no dependency from P2b to independent P1, P6, P7, P8 inventory or P9 static work. Device availability does not block protocol unit/request tests. No cycle is present.

| Phase | Status | Work that can proceed |
| --- | --- | --- |
| P0 | BLOCKED_BY_ENVIRONMENT for Rails/service checks | Static analysis and safe frontend/static checks only. |
| P1 | READY_WITH_PRECONDITIONS | Design/test plan ready; run after P0. |
| P2a | READY_WITH_PRECONDITIONS | Trace surfaces and define Base result; request tests after P0. |
| P2b | BLOCKED_BY_DECISION | Present choices; do not implement local entry. |
| P3 | READY_WITH_PRECONDITIONS | Freshness contract/tests; issuance depends on P1/P2a. |
| P4 | READY_WITH_PRECONDITIONS | Shared RP contract; feature integration after P1/P2a/P3. |
| P5a | READY_WITH_PRECONDITIONS | Automated protocol audit after P0/P1/P2a. |
| P5b | DEFERRED_VALIDATION | Real client/device/browser only. |
| P6 | READY_WITH_PRECONDITIONS | Independent UI can be retained; Rails security/query work after P0. |
| P7 | READY_WITH_PRECONDITIONS | Reuse presenter/expiry source; Rails checks after P0. |
| P8 | READY_WITH_PRECONDITIONS, decisions split | Static inventory now; GUID and direct-entry roots decision-gated. |
| P9 | BLOCKED_BY_ENVIRONMENT for broad cleanup | Static inventory now; removals wait for green baseline. |
| P10 | READY_WITH_PRECONDITIONS | Future reverse review after implementation. |

## 11. Decisions required from the user

1. Direct Auth entry: choose whether to retain a Base-local sign-in/signup UX, retire direct Auth entry in favor of RP-only flow, or keep Auth as visual front door while Base owns a local-purpose admission/result. Specify anonymous landing, success destination, cancel/error/retry, already-authenticated behavior, ri/host and session semantics. Base remains authority; no option may create an RP code without an RP request.
2. GUID contract: confirm canonical lookup path (existing /api/v0/resources/:guid or earlier /resources/:eid) and whether the public net host gets an OpenAPI document or another explicit contract. A generic indefinite FIXME is not resolution.
3. DPoP rollout: after key ownership/client capability evidence, decide which controlled client IDs must reject Bearer for new token issuance. Preserve current optional policy until then. Nonce is a separate optional AS decision.
4. Source provenance: restore the two files named in the task or provide authoritative REQ-to-P00–P17 mapping before claiming exact traceability. Do not invent REQ-095’s missing ORG text.

No user decision is required to continue static inspection, owner-binding design, auth_time tests, OTP security audit or activity/session planning. Derivable implementation details should not be escalated as product questions.

## 12. Baseline and regression strategy

### Results recorded from the current working HEAD

| Command | Exit / observation |
| --- | --- |
| bun run test | 0; 85 files, 1,054 tests passed. |
| bun run format:check | 0; 571 files checked. |
| bun run lint | 0. |
| bun run typecheck:verify | 0. |
| bun run typecheck | 0. |
| bun run deadcode | 0; two Knip configuration hints only. |
| bun run openapi:lint | 0. |
| bin/rubocop | 0; 4,790 files, no offenses. |
| bundle exec erb_lint --lint-all | 0; 599 files, no ERB errors; parser/ruby33 compatibility warning under Ruby 4.0.6. |
| bundle exec brakeman --quiet --no-pager --exit-on-warn --exit-on-error | 0; Brakeman 8.0.6 / Rails 8.2.0.alpha, zero warnings. |
| bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error | Failed before scan; could not create /home/global/.cache/gem in read-only location. Direct bundled command above completed the scan. |
| bun run test:coverage | 1; RangeError: Maximum call stack size exceeded inside @bcoe/v8-coverage 1.0.2 while merging coverage. |
| node node_modules/vitest/vitest.mjs run --coverage --coverage.reportsDirectory=/tmp/... | 0; 85 files, 1,054 tests, statements 100%, branches 99.7% (1,343/1,347), functions 100%, lines 100%, under Node 24.20. This diagnostic is not canonical Bun coverage or CI proof. |

### Not run

- bin/rails test and targeted Rails suites
- COVERAGE=true bin/rails test test/
- bin/rails routes and bin/rails notes
- bin/ci
- Rails public-boundary reproduction for OIDC, Auth admission, OTP, DBSC, sessions or roots
- Database/Valkey probes, server, live email/SMS, provider IdP, Jump or other external service
- Physical DPoP or DBSC client/browser/device validation

Reason: test DB host variables point to primary, AUTH_STATE_REDIS_URL points to Redis DB 2 without test override, application namespaces are not demonstrated unique, global outbound denial was not established, and service binaries were unavailable. A Rails command could mutate a shared development service. These tests are BLOCKED_BY_ENVIRONMENT, not failed and not passed.

### Coverage criteria kept distinct

- Current .simplecov gates: overall line 97; line per file 70; policy/model files 95; values/services files 90; Models/Policies/Values groups 99; Services/Controllers groups 98; branch 90 with implicit_else ignored and maximum_drop 0.5; method 95; line maximum_drop 0.2. Preserve per-file/group and last-green maximum-drop evidence.
- Vitest configuration has 99% statement, branch, function and line thresholds. Canonical Bun coverage has not passed due runtime exception.
- Historical failed Rails run at 98.56% line is an observed failed-run diagnostic, not a green baseline. Do not silently promote it to a new threshold. A higher aspiration is a separate proposal requiring rationale and adoption.
- Current green Rails baseline is NOT ESTABLISHED. The future run must isolate services, run ordinary suite, repair verified failures without weakening tests, then run coverage suite. Only a fully successful gate establishes GREEN_BASELINE_LINE/BRANCH/METHOD plus per-file/per-group values and skip inventory.
- Report Rails assertions, Rails coverage gate, ordinary Vitest, Vitest coverage, static/lint and bin/ci separately.

## 13. Plan deviation and anti-cheating rules

This plan is frozen only after the user resolves decision-blocked contracts and separately authorizes implementation. A later agent may choose local naming/object placement when repository evidence supports it. It may not silently change Base/Auth authority, client/realm/session ownership, security boundaries, external OIDC/API contracts, auth_time/ACR/AMR semantics, accepted Access JWT revocation risk, GUID URL policy, or per-client DPoP policy.

A necessary architectural change is a PLAN_DEVIATION report containing original assumption, exact new evidence/path/method/reproduction, affected REQ IDs, invariant/contract impact, alternatives, tests/migration/rollback impact and requested decision. Continue unrelated independent work. Time elapsed is not approval.

Do not get green status by deleting legitimate tests, weakening assertions, skipping/pending failures, changing thresholds/exclusions/baselines, disabling linters/security checks, swallowing exceptions, relaxing validation, disabling PKCE/state/nonce/redirect/CSRF/host checks, loosening token expiry, bypassing Base, making required config optional, or removing difficult-to-test production behavior. If a test is obsolete, document the superseding requirement and add replacement behavioral coverage.

## 14. Final independent audit procedure

A future independent review begins from behavior, not filenames:
1. Start at public routes and infer anonymous/authenticated/machine behavior.
2. Trace authority/event time from credential evidence through Base transaction, code, JWT/ID Token and refresh.
3. Falsify owner/replay/concurrency/partial-store guarantees over HTTP with controlled clients A/B.
4. Inspect Auth/Base rows and cookies after each ceremony.
5. Test current/other-session owner boundaries.
6. Test DPoP/DBSC protocol and separately report device status.
7. Inspect props/HTML for secrets and raw audit data.
8. Compare every JSON route with OpenAPI.
9. Review tests for weakened assertions, skips, bypass mocks and exclusions.
10. Compare inferred behavior against all 95 IDs and restored source text.
11. Run isolated Rails, canonical JS coverage, static/security and bin/ci.
12. Report implemented/validated, validation pending, planned, unresolved, accepted risk and superseded separately.

No independent reviewer was used in this plan run. Future independent review should receive final diff and acceptance matrix. Unit tests cannot close physical-device validation.

## 15. Explicitly rejected approaches

- Do not apply old D-ENTRY before user choice.
- Do not treat prior source-recovery/hash claim as current proof.
- Do not change only OidcAuthorizationCodeIssuer and declare auth_time fixed.
- Do not permit a non-owner to trigger replay revocation and do not remove replay revocation.
- Do not call raising on Valkey exception sufficient for cross-store consistency or silently accept missing/invalid link status.
- Do not reopen consumed codes or promise same-code retry after ambiguous failure without protocol proof.
- Do not call absent DPoP nonce a violation; do not ignore nonce if AS elects to require it.
- Do not force DPoP across clients before key ownership and compatibility decision.
- Do not call DBSC class presence end-to-end implementation or physical validation.
- Do not add a Risk table merely because an earlier summary presumed an FK; do not repurpose logging severity.
- Do not add expiry storage if discarded_at passes boundary tests.
- Do not infer Emergency from DBSC.
- Do not redirect Core/Palm to invented browser dashboards.
- Do not use broad FIXME/protocol exemptions to claim OpenAPI coverage.
- Do not rewrite project history or lower quality/security gates.

## 16. Remaining risks and follow-up plans

| Follow-up | Problem/current state | Why deferred/security impact | Prerequisites and validation / exit |
| --- | --- | --- | --- |
| Deeper AAL/FAL/acr/amr normalization | Existing assurance docs are substantial but partly superseded; full federation/provider model exceeds bounded cleanup. | Avoid false NIST conformance or merging step-up with AAL. | New focused plans/ document later; define method-specific assurance, Passkey/upstream IdP, freshness, RP requested acr, Emergency and SMS; exit when authoritative contract and tests are adopted. |
| Base-local/direct sign-in architecture | Base/Auth links appear cyclic and local UX is undecided. | Guessing can create another authority or fabricate RP transaction. | User chooses option in §11; then route/UI/state/result/security matrix passes. |
| DBSC real-device/browser validation | Server registration/challenge/refresh paths exist; compatibility is not established. | Device-binding claim unsafe without browser key persistence and fallback evidence. | New plans/ validation item; run full P5b matrix on named supported/unsupported clients; exit on actual observations. |
| DPoP real-client/device validation and enforcement | Server verifier exists; clients and per-client policy are not fully validated. | Wrong key ownership/fallback can break clients or falsely claim sender constraint. | New plans/ item and per-client policy decision; test key storage, proof, AS/RS, replay, wrong key and restart; exit on representative client evidence. |
| OIDC exchange cross-store recovery, only if P1 cannot close it | Owner replay/link partial failures are static risks, not yet reproduced. | A lingering issue could revoke another client or issue untracked credentials. | Resolve in P1 where possible. If not, create a specific plans/ item with accepted residual risk, exact failure boundary, owner, prerequisites, validation and exit; no indefinite FIXME. |
| Original P00–P17 provenance | The two requested source files were not in this workspace. | Normalized summaries may omit/distort source wording, especially REQ-095. | Restore source/hash evidence and map IDs before claiming verbatim coverage. |

## 17. Final readiness statement

The revised plan is evidence-based for inspected paths and marks unverified behavior explicitly. It is not a complete autonomous execution authorization. Overall decision remains **NO-GO for freezing all 95 requirements into one self-executing implementation run**. Continue only READY_WITH_PRECONDITIONS slices after isolation; execute BLOCKED_BY_DECISION slices only after required user choices. This planning task ends here; implementation does not begin.
