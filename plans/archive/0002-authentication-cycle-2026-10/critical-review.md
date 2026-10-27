# Critical Review of the Integrated Authentication Requirements

> Archived 2026-10-27 from the working file `four.md` (cycle archive 0002; frozen, not maintained).

> Note added 2026-10-22 (not part of the review): R-19 … R-30 are dispositioned in `six.md`; resulting owner decisions are one.md D-73 … D-83. See `one.md` "Resume here".

> Current review: see **2026-10-21 follow-up review** below. Sections before that heading preserve
> the earlier review of snapshot `3ca0e08a…`. Its findings, priorities and execution limits describe
> that earlier snapshot; the follow-up explicitly reassesses them against the newer documents.

## Purpose and review limits

This is supporting material for writing detailed definitions, not an accepted design, an
implementation plan approved for execution, or evidence of passing tests. It critically reviews
`one.md` without editing that document or `two.md` / `three.md`. Only `four.md` is changed by this
review. The requested root working-file location is intentional; durable requirements belong in
their owning ADR/spec/checklist when accepted, and this working material should follow the cycle's
archive policy at closure.

- Reviewed on 2026-10-21, local branch `feature`.
- HEAD: `febec3225cc9a0cfa53b9cbe817d20d366aba5a2`.
- The worktree already contains uncommitted application, test, documentation and ADR changes,
  including the untracked Accepted Passkey identifier-first ADR. Observations below describe that
  worktree, not a clean checkout of HEAD. Line numbers are navigation hints for this snapshot.
- `one.md` snapshot SHA-256:
  `3ca0e08a4275d5c9ea58d88e5277ef59d7b65e53eef303d9607edb8d9f441870`.
- Method: read the requirement set; inspect selected implementing paths, checked-in database
  definitions, related Accepted ADRs and representative tests. No application test, browser
  reproduction, network probe, database query, migration or load test was run. This is a scoped
  source review, not an exhaustive security or standards-conformance audit. `two.md` and `three.md`
  were neither read nor changed.
- Evidence labels: **Confirmed** = visible in the inspected source/document; **Risk** = a concrete
  failure scenario requiring reproduction; **Decision gap** = the intended contract is unresolved
  or conflicts with another governing record; **Proposal** = a recommended definition, not a new
  approval. P0 = settle before dependent implementation; P1 = necessary implementation acceptance;
  P2 = follow-up clarification/maintainability.

## Overall assessment

The requirement set identifies important boundaries correctly: Base owns establishment; Auth owns
ceremony evidence; effective admission intent controls entry; OP revocation and RP delivery are
different facts; terminal registration does not justify deleting a durable Identity. Its strongest
existing analysis concerns cross-browser reuse, stale Flow evidence and late callbacks.

It is not yet a coherent input to detailed definitions. Later decisions reverse earlier decisions
without consistently updating the requirements, unresolved-decision table or Gates. An implementer
could comply with one section while violating another. The first task is to establish one current
contract projection, not to implement all numbered requirements literally. Preserve historical
entries and explicitly mark their replacements rather than silently using “last paragraph wins.”

## 1. Requirement and authority conflicts

### R-01 — P0 / Confirmed: later decisions have not reached the requirements

The following are contradictions inside `one.md`, not inferred runtime defects:

| Subject | Older instruction still present | Later direction | Definition needed |
| --- | --- | --- | --- |
| Refresh | RP-2 requires bounded lost-response recovery; Q-R1 leaves reuse scope blocked; section 5 still calls scope Pending | D-25 removes receipt recovery and chooses grant-family-only reuse revocation | Retire the recovery requirements explicitly, fix the reuse scope and enumerate all receipt consumers to remove. |
| BCL delivery | D-12/D-26 and RP-6 require durable outbox, sweep and lease recovery | D-28/D-30 accept volatile delivery in a Puma thread pool | Identify which old delivery guarantees are withdrawn and keep Zenith identity-stop durability separate. |
| Runtime | D-20 removes cell DBs and first-party OIDC; ISO-1 requires process isolation | D-23/D-24 retain standard OIDC and 12 RP DBs; D-19/D-21 retain one Puma | Write the final retained/removed component matrix. Do not delete RP DBs following D-20. |
| Activation | D-18 blocks activation pending KMS/co-location | D-35 withdraws activation and removes the gate | Explain what now authorizes the retained RP paths to become the live default. Removing the gate alone does not prove readiness. |
| Cancel/Switch | ADM-1/ADM-3 require POST consumption; ADM-2 calls the change transport-only | D-39 proposes consuming GETs with no JavaScript or relay page | Obtain scoped normative reconciliation, including the existing CSRF/GET rules, before coding it. |
| Deadlines | ADM-5 and Q-3 remain Blocked; section 5 leaves continuation expiry Pending | D-36 chooses a continuation bound; D-41 applies it to the page and every action | Project the chosen bound into each action and mark only remaining expiry questions Pending. |
| Flow status set | Q-E7 says canonical predicate is undecided | The E1 ADR names both surface-specific in-progress sets and treats the historical statuses as terminal | Use that accepted mapping; separate any new dispute about a writer from the already recorded mapping. |
| Return target | D-39 describes consuming RP `pt` after cancel | D-42 rejects RP `pt`, replacement undecided | Make cancel-return behavior depend on the replacement decision. |
| Passkey | Final Open entry says usernameless is still the Accepted target | `adr/passkey-identifier-first-sign-in.md` is now Accepted in this worktree | Treat identifier-first as decided but implementation unverified; decide whether this cycle includes implementation. |
| Gates | Q-1, ISO-1 and GATE-1 use the old process-isolation/independent-E2E baseline | D-16/D-19/D-21 change that scope | Define which Gates are impossible under the chosen architecture and which are merely not executed. |

**Proposal:** build a current-decision table with original ID, successor ID, governing ADR clause,
status, implementation obligation and acceptance obligation. Preserve the historical ID as a
reference. A detailed work unit should depend on the projected current requirement, not every
historical paragraph carrying “Decided.” Claimed owner handoffs in `one.md` are provenance claims;
this review cannot independently authenticate conversation history absent from this session.

### R-02 — P0 / Confirmed: observed behavior and normative authority are conflated

Section 1 places working-tree code above Accepted ADRs, while the introduction says code and
Accepted ADRs win. These answer different questions. Code establishes observed implementation;
ADRs establish intended contracts. The repository knowledge policy explicitly distinguishes them
(`docs/reference/repository-knowledge-architecture.md`, “Facts and contracts”).

For example, the old POST-only admission rule remains in
`adr/base-auth-ceremony-and-seven-rp-boundary.md:213`, and
`generic/authentication-boundaries.mdc` forbids GET creation of ceremony state. The old shared-DB
sign-out ADR still rejects first-party BCL (`adr/first-party-sign-out-shared-database-without-backchannel-logout.md:134`).
The runtime-secret ADR's recorded all-environment target has not been replaced just because D-15
claims a later owner decision. This review did not locate an Accepted successor establishing the
whole D-19..D-39 architecture.

**Proposal:** classify each conflict as (a) code defect against an accepted contract, (b) accepted
but not implemented target, (c) owner-reported decision awaiting ADR reconciliation, or (d) proposal.
Create explicit scoped amendments in the later authorized documentation task. Do not call a
conflicting proposal “implemented” because the old code happens to resemble it.

## 2. Implementation findings and missing safety definitions

### R-03 — P1 / Confirmed: a JWKS dependency failure becomes an invalid-token response

**Evidence:** `OidcOpJwksClient#refresh` rescues network/document failures and returns nil
(`app/adapters/oidc_op_jwks_client.rb:105`). `OidcOpLogoutTokenVerifier#call` returns an undifferentiated
failure when no key is returned (`app/adapters/oidc_op_logout_token_verifier.rb:40`).
`RpBackchannelLogoutEndpoint#create` maps that failure to 400
(`app/controllers/concerns/rp_backchannel_logout_endpoint.rb:22`). The receiver creates a new JWKS
client per request and constructs its URL directly instead of resolving Discovery metadata.

**Trigger/impact:** with an empty cache and an unavailable OP JWKS endpoint, an otherwise valid
Logout Token is rejected as invalid. Under the proposed permanent-400 delivery policy this drops
the notification. The current sender retries every non-200, so the permanent-drop consequence is
a future integration risk, not a claim about today's sender.

**Minimum direction:** typed verification outcomes for invalid evidence versus unavailable
verification prerequisites; a bounded shared per-issuer cache with explicit concurrency and
unknown-key refresh behavior; 503 for unavailable validation, without accepting an unverified token.
After a successful refresh still lacks the key, specify the retry policy and abuse budget rather
than allowing arbitrary `kid` values to force unlimited fetches/retries. Preserve fixed configured
issuers and forbid token-supplied metadata URLs.

**Tests to define:** cold/warm cache; known/unknown `kid`; rotation; unreachable JWKS; malformed
JWKS; invalid signature; invalid issuer/audience; simultaneous cold misses. Assert response and
fetch-count bounds separately. The inspected receiver integration suite covers valid, duplicate,
malformed and foreign-audience tokens, not this dependency distinction
(`test/integration/rp_backchannel_logout_receiver_test.rb:27`). No suite was run.

### R-04 — P0 / Risk: one Puma can exhaust its own request capacity through HTTP self-calls

**Evidence:** `OidcOpTokenClient#call` performs synchronous HTTP to the OP token endpoint
(`app/adapters/oidc_op_token_client.rb:70`); BCL verification may synchronously fetch OP JWKS.
Puma uses a bounded request pool (`config/puma.rb:31`). D-19/D-23/D-30 combine one Puma, ordinary
RP-to-OP HTTP and a separate BCL sender pool.

**Failure scenario:** all request workers are occupied by RP requests waiting for OP requests routed
back to the same Puma. Those OP requests cannot run until a worker becomes available; timeouts
cause failures and retries. A separate outbound BCL pool does not reserve inbound OP/JWKS capacity.
Adding delivery threads can worsen network and connection pressure.

**Definition needed:** per-request call graph, admitted concurrent blocking calls, queue bounds,
total HTTP deadline, per-issuer fetch coalescing and capacity behavior at saturation. Preserve the
accepted standard HTTP boundary; do not “fix” this by silently restoring in-process token exchange
or proposing an unauthorized service split. Establish a viable concurrency/admission strategy and
verify it in the actual one-Puma topology before claiming readiness.

**Tests/checks:** real HTTP with cold JWKS at below/at/above configured capacity, delayed OP replies,
BCL bursts and process shutdown. Record starvation/timeouts and resource bounds. In-process OP
transport cannot establish these properties. D-16 may defer independent-RP E2E, but does not turn
this topology-specific check into evidence already obtained.

### R-05 — P0 / Decision gap: best-effort BCL and “every RP is notified” are incompatible

**Evidence:** current `OpLogoutCommitter#call` records revocation, participants and outbox rows in
one OP transaction (`app/operations/op_logout_committer.rb:70`).
`OpOutboxDispatchJob#perform` leases and retries persistent rows
(`app/jobs/op_outbox_dispatch_job.rb:21`). D-28/D-30 intentionally replace that guarantee with
volatile work and accepted restart loss. RP-8 still says every required RP is notified after commit.

**Proposal:** specify three separate facts: OP authority durably stopped; notification submission
attempted/bounded; RP local closure acknowledged or unknown. A lost volatile item cannot produce
a delivery acknowledgment. Accepted loss must cover the commit-to-enqueue gap, queue overflow,
worker exception, token-signing failure, deployment restart and retry exhaustion, not only restart
during a POST. Retain security/audit facts independently of the delivery mechanism.

**Definition needed:** finite queue and worker counts, nonblocking enqueue behavior after commit,
per-destination fairness, retry schedule/deadline, executor startup after Puma fork, shutdown policy,
Rails executor/current-context cleanup and database checkout/release. Never hold OP locks or
connections while doing HTTP. A failed after-commit callback must not report the already committed
logout as if it rolled back. D-27's “no compensation” does not remove this response-consistency duty.

**Acceptance:** rollback enqueues nothing; commit remains stopped when enqueue fails; one failed
destination cannot starve others; failures are observable without raw tokens; restart loss is
reported as unknown, not successful delivery. Preserve the separately durable Zenith→OP stop path.

### R-06 — P1 / Confirmed gap: identity stops and refresh reuse do not share BCL emission

**Evidence:** `OpIdentityEventInvalidator.call` writes its inbound receipt and invokes
`AuthenticationLogoutCurrentSession.call` without `within_commit`
(`app/operations/op_identity_event_invalidator.rb:41`). That class only invokes the supplied hook
when present (`app/controllers/concerns/authentication_logout_current_session.rb:60`). Refresh reuse
directly calls `usage.revoke!` (`app/operations/oidc_refresh_token_issuer.rb:444`). Neither inspected
path invokes `OpLogoutCommitter` to create BCL participants. Existing identity-stop tests assert root
revocation and durable retry, not RP BCL delivery.

**Impact:** a participating RP may retain local authority until its local/token checks expire even
though OP authority has stopped. This is material to D-26/D-34's intended coverage.

**Minimum direction:** one explicit stop owner accepting cause, realm and scope, with browser-only
confirmation/receipt concerns kept outside it. Do not reuse a root-logout operation indiscriminately:
reuse of one grant's refresh token must stop that grant/family and notify that RP, while preserving
the root and other grants under D-25. Identity stop/revoke-all has a different scope. Map all writers
and their owning transactions before choosing lock boundaries; do not merge independent DB commits.

**Tests:** table-driven stop causes across APP/COM/ORG; grant-only reuse leaves root/siblings usable;
identity stop closes old authority; delayed identity events preserve newly issued authority; failed
or duplicate apply cannot acknowledge an uncommitted revocation. Stop versus refresh/code exchange
must never leave new authority derived from a stopped parent.

### R-07 — P0 / Decision gap: a JWT expiry bound is not a complete single-logout guarantee

**Evidence:** `RpRequestAuthenticator#call` verifies the Access JWT and local state rather than OP
revocation on every request (`app/services/rp_request_authenticator.rb:42`).
`RpCellSessionRevoker` installs an absorbing per-sid tombstone and revokes local rows
(`app/operations/rp_cell_session_revoker.rb:32`); `RpCallbackCommitter` rejects a revoked anchor
(`app/operations/rp_callback_committer.rb:53`). These are useful properties to retain.

D-28/D-33 accept missing BCL and describe 5–10 minute residual access. Those numbers are targets
to verify across every token issuer, client and refresh path, not measured results of this review.
The actual bound includes allowed skew and the handling of requests already authorized before
expiry. Long-lived streams/jobs and mutations committing after expiry require an explicit scope.

**Definition needed:** whether logout promises immediate OP stop, best-effort RP closure or bounded
future-request rejection. “All RPs signed out” cannot mean immediate local closure when notification
loss is accepted. Define how old local sessions/cookies are replaced after grant-only reuse and a
fresh Authorization Code flow, including a delayed old-sid BCL arriving after the new session.

**Tests:** drop every notification; verify rejection immediately around the real expiry/skew bound;
reject old refresh; preserve new sid after delayed BCL; logout-before-callback and concurrent
callback/logout remain absorbing. Define minimum tombstone/receipt retention from the latest
possible callback/refresh/token acceptance time, not an arbitrary job age. Purging a tombstone too
early can remove the late-callback protection.

### R-08 — P1 / Confirmed: outbound HTTPS enforcement is not connection-time SSRF protection

**Evidence:** `OutboundHttp::Connection.build` checks HTTPS and configures Faraday timeouts but
does not validate DNS results or pin the socket destination (`app/lib/outbound_http/connection.rb:29`).
`OidcBackchannelLogoutClient.call` uses a registered endpoint through that connection
(`app/adapters/oidc_backchannel_logout_client.rb:14`). This is a missing D-30 target, not proof that
an unauthenticated caller currently controls endpoint registration.

**Definition needed:** trusted endpoint registration/update authority, scheme/port/userinfo rules,
all IPv4/IPv6 results including mapped addresses, mixed public/private answers, DNS rebinding,
proxy resolution, connection pinning while preserving TLS hostname/SNI validation, redirect refusal,
DNS/connect/read/write/total deadlines and streaming response-size limits. An IP check before a
second independent hostname resolution is insufficient. The JWKS client currently checks response
size after full body retrieval (`app/adapters/oidc_op_jwks_client.rb:164`), which does not bound
network buffering.

**Minimum direction:** an explicit transport policy for RP-selected endpoints with audited adapter
behavior; preserve existing trusted-provider callers unless their contract also changes. Fail closed
when the configured proxy/adapter cannot prove the checked address is the connected address.

**Tests/checks:** forbidden literal/encoded/mapped addresses, mixed DNS, rebind between calls,
redirects, invalid TLS host, oversized/chunked/slow response and bounded retries. Verify actual
socket/proxy behavior with controlled endpoints; mocked DNS alone does not demonstrate pinning.

### R-09 — P0 / Decision gap: BareController inheritance can reintroduce browser dependencies

**Evidence:** current `Core::App::Oidc::BackchannelLogoutsController` inherits `ActionController::API`
(`app/controllers/core/app/oidc/backchannel_logouts_controller.rb:8`). Its proposed replacement
parent carries `allow_browser`, forgery protection, FQDN gating and rate limiting
(`app/controllers/core/app/bare_controller.rb:8`). D-32 says no cookies/session and allows arbitrary
external RP/OP HTTP clients, but does not enumerate these inherited behaviors.

**Impact:** changing the parent is not a mechanical rename. A server client with an absent/old User
Agent may fail browser gating before token verification; inherited forgery/session behavior can
contradict the signed server-to-server contract. The repository currently forbids skipped forgery
protection and browser-bound CSRF substitution; D-32 requires an explicit scoped policy exception,
not merely editing a guard allow-list until tests pass.

**Definition needed:** callback/middleware inventory for each participating surface and region,
fixed receiver ownership and rate-limit keys, strict body/media-type/parameter bounds, `no-store`
on every refusal including middleware responses, and no browser-cookie side effects. Decide the
canonical surface-local bare parent and its sanctioned server-to-server behavior without weakening
ordinary browser endpoints.

**Tests:** no Cookie/Origin/CSRF token, absent and server User Agents, attacker browser POST,
oversized/malformed/duplicate parameters, foreign issuer/client and dependency failure. Signature
verification remains mandatory; browser independence is not unauthenticated revocation authority.

### R-10 — P0 / Decision gap: cookie-bound GET is still a state-changing navigation

**Evidence:** current cancel/switch processing is POST-based and checks browser binding
(`app/controllers/concerns/oidc_authorization_result_post.rb:135` and `:160`). D-39 would consume
references, cancel an authorization or issue a fresh Admission on GET. The application rules
currently require Rails CSRF on browser mutations and prohibit GET ceremony-state creation.

A matching host-only cookie proves browser continuity, not intent to cancel or switch. An
attacker-induced top-level navigation or browser prefetch may carry that cookie. A secret reference
reduces attacker feasibility but needs a stated leakage/issuance model; reference possession and
cookie continuity do not automatically substitute for CSRF or user activation.

**Definition needed before implementation:** exact exception scope and normative amendment,
reference issuer/holder/entropy/TTL/purpose, Fetch Metadata and prefetch handling, HEAD behavior,
cookie SameSite behavior across the real host/TLD graph, referrer/cache/history leakage controls,
and order of binding validation versus one-time consumption. A forged-browser attempt must not
burn the legitimate browser's reference. A successful switch keeps the original RP request,
PKCE/state/nonce and target intent; it does not transfer old authentication evidence.

**Tests:** no-JS browser navigation, cross-browser and cross-site navigation, missing/wrong cookie,
HEAD/prefetch/scanner, expired/refused/replayed references and concurrent cancel/switch/finalize.
One winner must establish a terminal or successor state; a late result must never restore cancelled
authority. HTTP redirects alone are not proof that these races are safe.

### R-11 — P1 / Confirmed: continuation checks disagree; the replacement deadline needs one owner

**Evidence:** `AuthCeremonyContext#auth_social_admission_binding!` still requires `!binding.expired?`
(`app/controllers/concerns/auth_ceremony_context.rb:33`). Binding issuance caps expiry by
`OpaqueAdmissionStore::CODE_TTL` (`app/services/base_auth_admission_coordinator.rb:764`). Other
intent checks resolve the active ceremony and parent through different methods. This supports the
reported Social deadline mismatch at source level; no timed browser reproduction was performed.

**Minimum direction:** a named public continuation decision with one database-time comparison
and explicit accepted binding, current ceremony, effective intent and parent checks. The page and
every action consume the same decision. A new challenge must expire no later than its parent;
asynchronous Social callbacks and WebAuthn completion recheck the deadline before committing
evidence. Acceptance expiry remains separate and cannot be extended by continuation.

**Definition needed:** behavior exactly at deadline; whether cancel after expiry is cleanup or an
authenticating action; terminal-state precedence; handling of a stale tab and parent expiry during
an external provider redirect. D-41's restart link says RP `/sign`, while OBS-1 says configured
surface `/sign`: specify which RP is retained and how it is selected from trusted server state.

**Tests:** before/at/after deadline across methods and parent types; parent shortened/stopped during
ceremony; visible page followed by late POST/callback; no evidence/session issuance after expiry;
deterministic no-JS restart without client-controlled redirect targets.

### R-12 — P1 / Confirmed: the Flow locator does not supply Admission ownership

**Evidence:** `SignUpCycleLocator#current` checks session locator, nonce and selected terminal
statuses, with no admitted Binding argument (`app/services/sign_up_cycle_locator.rb:25`).
`SignUpFlowEntry#supersede_active_sign_up_flow!` starts from that locator
(`app/controllers/concerns/sign_up_flow_entry.rb:28`). Social determines entry separately and creates
a Flow (`app/controllers/concerns/app_social_ceremony_entry.rb:86`). The checked-in APP/COM OP
schema snapshots do not contain the target `auth_admission_binding_id`.

**Minimum direction:** resolve the server-authoritative admitted Binding first, then its eligible
Flow; validate locator agreement as UI continuity. One Binding lock must cover old-Flow termination
and new-Flow insertion for every supported entry method. Keep a status-scoped database UNIQUE;
use the accepted per-surface predicate rather than time in the index.

**Additional issue:** `SignUpCycleLocator#terminal?` lists fewer terminal names than
`FlowSignUp.sign_up_terminal_status_ids` (`app/services/sign_up_cycle_locator.rb:70`,
`app/models/concerns/flow_sign_up.rb:34`). Historical `FINALIZED` and
`SIGN_IN_HANDOFF_PENDING` can therefore be classified inconsistently. This establishes divergent
helpers, not that such rows are currently reachable through a live writer. Define one public
classification owner and test actual reachable transitions; a static text guard alone is insufficient.

**Tests:** independent parents in two tabs, stale page under a newer ceremony, all entry methods,
same-Binding concurrent INSERTs, expiry freeing the slot through a terminal transition, finalization
versus restart and old evidence submitted to a successor Flow. Terminal history must remain
preserved. Do not turn “can lead to a later sign-in handoff” into a blanket requirement to classify
completed registration as in-progress; handoff/issuance idempotency is a separate invariant.

### R-13 — P1 / Risk: uniqueness retry can run inside an aborted PostgreSQL transaction

**Evidence:** `BaseAuthAdmissionCoordinator.issue_binding_and_transport!` acquires the parent lock;
`create_or_reuse_binding!` rescues `RecordNotUnique` and retries the method without its own
savepoint (`app/services/base_auth_admission_coordinator.rb:714`, `:780`). A normal cooperative
parent lock may avoid the collision, so this is not a reproduced normal-request failure.

**Trigger/impact:** a uniqueness collision from another writer or another constrained field can
leave the outer transaction aborted; retrying queries inside that transaction may raise rather
than converge. A broad retry also fails to distinguish the intended live-parent conflict from an
unrelated integrity failure.

**Minimum direction:** identify the exact expected index, recover at a valid transaction/savepoint
boundary and reread the winner with matching parent/intent/browser checks. Bound retry; propagate
unrelated violations. Preserve any already committed transport fact and do not issue a second
usable admission merely because a response was lost.

**Tests:** public coordinator calls on separate DB connections for the same parent and for
different parents; intentional collision on the intended index versus an unrelated constraint;
assert one live binding and a usable transaction afterwards. Do not stub a `RecordNotUnique` alone
and call that a PostgreSQL concurrency test.

### R-14 — P0 / Decision gap: Bootstrap safety needs a verifiable deployment boundary

**Evidence:** D-13/BOOT-3 require an independent final refusal while staging's Rails environment is
unknown. Q-6 proposes a development-only credential; D-15 shares the one credential set across
roles. A credential called “development-only” does not prove that it cannot reach a deployment
running development settings. `AuthenticationContextValue.from_claim` currently treats blank
claims as Normal (`app/values/authentication_context_value.rb:107`); its policy permit logic only
recognizes Normal and Standby (`:67`).

**Definition needed:** enumerate what makes a runtime local-only, the authoritative signal, how it
is provisioned and verified independently at finalization, and the refusal when missing/unknown.
Adding a Bootstrap context must preserve it through root/grant/refresh/access claims and every
authorization boundary; no omission may turn it into Normal. A static policy-entry inventory is
useful but cannot replace end-to-end authorization refusals.

**Minimum direction:** keep this work unit blocked on the deployment discriminator and exact
permitted resource/actions. Do not widen existing Operator roles to make Bootstrap useful.
Distinguish seed idempotency, callback identity verification and session authority. Normal Entra
callbacks must retain their Passkey stage. An idempotent seed must refuse foreign ownership and
stopped identities rather than silently rebinding or reactivating them.

**Tests/checks:** run seed setup and record observations in `evidence/`; do not create Minitest or
Vitest cases whose subject is environment construction. Behavioral tests should cover forged
Bootstrap callback/context, missing deployment proof, normal callback isolation, refresh context
retention and refusal of every non-allowlisted operation. No production-like setup was inspected.

### R-15 — P1 / Decision gap: epoch removal is a consumer migration, not a column cleanup

**Evidence:** `RpRequestAuthenticator#bound?` compares session and JWT contract epochs
(`app/services/rp_request_authenticator.rb:76`). Callback constructors and checked-in RP schema
CHECKs also depend on `contract_epoch`. Identity-stop code separately interprets a missing
`authentication_epoch` as older than a cutoff
(`app/operations/op_identity_event_invalidator.rb:63`); OP schema columns remain nullable.

**Definition needed:** separate protocol-epoch removal from identity-epoch preservation. Inventory
every issuer, verifier, constructor, query, DB CHECK, configuration, fixture, client and in-flight
code/refresh/session that carries each value. Define the replacement realm-wide stop so code
exchange and refresh cannot create new grants from old roots after a supposedly completed stop.
“Revoke all existing grants” alone does not establish that concurrency property.

**Minimum direction:** retain identity epochs at authoritative issuance and recheck them under the
relevant stop/issuance serialization. Prove the claimed NULL→0 equivalence against all cutoff
writers and issuance paths before approving a backfill. Prepare exact aggregate inventory, recovery
plan and migration ordering; bulk update, dropping columns or DBs requires separate explicit
authorization. No data operation is authorized by this review.

### R-16 — P1 / Confirmed: cancel-return and logout standards work have hidden dependencies

**Evidence:** after validating state and response issuer, `OidcCallback#show` treats every OAuth
error as the same callback failure (`app/controllers/concerns/oidc_callback.rb:24`, `:35`). The
existing RP logout launcher reads OP models (`app/controllers/concerns/oidc_rp_logout_launcher.rb:417`,
`:471`). The checked-in RP session definition has no stored ID Token column
(`db/rp_core_app_structure.sql`, `rp_sessions`). D-33's stored ID Token and OP-only logout state are
therefore new work, not simple route changes.

**Definition needed:** complete Cancel's valid `access_denied` path only after state/issuer checks,
consume that flow's return state once, preserve unrelated pending flows and separate malformed or
foreign errors. D-42's return-location decision precedes its final redirect design. A normalized
same-origin path is not automatically an open redirect; the finding is caller influence over a
destination whose authorized provenance is undecided. Signing arbitrary caller input alone does
not establish that provenance.

For logout, define server-side ID Token storage/retention and sensitive-data handling, local RP
revocation/cookie deletion before OP navigation, cancellation at OP, and distinct request versus
confirmation resources. Preserve the OP's CSRF-protected confirmation and ownership checks.
Verify standards claims against primary specifications in the implementation-definition phase;
this review did not perform an external standards audit.

**Tests:** valid/invalid `state` and `iss`, replayed error callback, multiple pending flows,
return-location tampering, expired-but-verifiable hint versus invalid hint, foreign `sid`/client,
GET/POST logout request rendering without confirmation mutation, confirmed logout, OP cancellation
and partial cookie deletion. APP tests alone do not prove all realm/client mappings.

### R-17 — P1 / Confirmed: accepted identifier-first is absent from the cycle projection

**Evidence:** the final Open Passkey item predates the new Accepted
`adr/passkey-identifier-first-sign-in.md`. Current `PasskeySignInFlow#options` still selects no actor
for discoverable direct sign-in (`app/controllers/concerns/passkey_sign_in_flow.rb:25`), confirming
that the accepted target is not implemented in that entry path.

**Definition needed:** either explicitly exclude Passkey migration from this cycle while recording
the target, or define a separate scoped work unit. It must bind an effective surface-local Email or
Telephone to the server transaction, compare selected Identity with verified credential owner, keep
APP/COM `allowCredentials` empty/omitted and preserve immutable handles, UV and RP/Origin. ORG
Normal remains Entra-bound; Standby depends on the Employee Number authority audit and privacy /
non-discoverable compatibility prerequisites. Identifier-first adds no authentication factor.

The capacity history also matters: the new ADR expressly replaces the 2026-10-19 ten-per-owner
target with four slots. Do not treat that as evidence of a four-slot implementation or delete
excess credentials. Capacity investigation and safe transition are distinct from sign-in owner
binding. The `ADVANCED` two-active-Passkey holding requirement remains independent of using one
credential during authentication.

### R-18 — P2 / Confirmed design gap: locale correction must choose its actual product contract

**Evidence:** `config/initializers/locale.rb` loads the four region/language bundles into the same
`:en` and `:ja` locale keys, with US files later in the load path. It does not supply region-scoped
lookup. D-40's overlap counts were not recomputed here; they are inherited claims, not new results.

**Definition needed:** does region change translation content, or does only language select text?
Making overlapping keys identical does not by itself stop a JP-only key from being used in the US
or a US-only key from appearing in JP. If regional differences are required, choose an explicit
region-aware lookup contract, missing-key behavior and request-context propagation for views,
Inertia, jobs and mailers without mutating a shared global backend per request. If differences are
forbidden, define both overlap equality and missing-key parity intentionally.

**Minimum direction:** separate incorrect sign-in copy from architectural region selection. Future
behavior tests should assert visible key resolution across region/language combinations; boot and
bundle-construction checks are run-and-record setup verification under the repository's absolute
no-environment-test rule. Do not add a new initializer test merely to pin the current construction.

## 3. Definition packages to write next

These are proposed writing units, not approval to implement, modify ADRs, create migrations or
change tests. Each package needs inputs, authoritative state, public interface, lock/commit owner,
refusal table, concurrency cases, affected paths and measurable exit criteria.

| Order | Package | Required output | Dependencies |
| --- | --- | --- | --- |
| 1 | Current contract projection | Resolve R-01/R-02; list superseded clauses, actual cycle scope and current Gate definitions | Existing ADRs and authenticated owner decisions |
| 2 | Retained RP topology | One-Puma route/DB/client matrix; default path after role/activation removal; HTTP call/capacity graph | 1; R-04/R-15 |
| 3 | OP authority-stop contract | Cause × scope × realm matrix; root/grant/identity ownership and lock order; code/refresh races | 1; R-06/R-15 |
| 4 | BCL delivery and receiver | Explicit loss acceptance; finite executor contract; SSRF-safe transport; JWKS outcomes; sid retention | 2–3; R-03..R-09 |
| 5 | Admission and continuation | Single deadline decision; GET exception disposition; Cancel/Switch transitions and late-result rules | 1; R-10/R-11 |
| 6 | E1 Flow authority | Binding-based lookup, predicate, immutable FK mechanism, restart matrix and safe migration policy | 5; R-12/R-13 |
| 7 | RP navigation/logout | Trusted return-location replacement; valid cancel error callback; request/confirmation split; ID Token retention | 2, 4–5; R-16 |
| 8 | Bootstrap | Local-runtime proof and least-privilege context propagation, or explicit deferral | 2, 5; R-14 |
| 9 | Passkey and translations | Explicit in/out-of-cycle Passkey scope; independent locale product decision | 1, 5; R-17/R-18 |

For a migration package, identify legacy readers/writers, live/in-flight data, coexistence and
recovery before defining a drop or backfill. For a replacement route, inventory all forms,
redirect builders, registered client endpoints, WAF rules and tests. Refusing old in-flight forms
is an intentional transition consequence to document, not a reason to retain an unapproved alias.

## 4. Test-design material for Red → Green → Refactor

Start each accepted package with a failing public-contract test for one concrete behavior, then
make the smallest coherent change and refactor after that behavior passes. A code branch or private
method does not warrant a matching test; exercise its owning public boundary. Keep real
cryptographic validation for token/assertion tests and real independent connections for races.

| Boundary | First Red case | Green objective | Broader regression before closure |
| --- | --- | --- | --- |
| JWKS / BCL | Valid Logout Token + unreachable JWKS returns retryable dependency refusal, with no local mutation | Typed dependency result and shared bounded verification client | Invalid signature, issuer/client, unknown key, cold-cache concurrency and fetch bounds |
| Stop scope | Refresh reuse stops its family and schedules only its participant; root and sibling remain | Scoped authority-stop owner | Logout-all, identity stop, code/refresh races, delayed identity event and new-sid preservation |
| Delivery | OP commit survives executor rejection; rollback sends nothing | Post-commit bounded submission with accepted-loss semantics | Overflow, restart, per-destination failures, signing failure, shutdown and retry deadline |
| Receiver | Browserless signed POST reaches verification without cookies or browser UA | Explicit bare endpoint pipeline | Body/media limits, no Set-Cookie, dependency/no-store refusal, duplicate/late tokens |
| Admission | A redeemed ceremony continues after the 60-second acceptance deadline but before its parent bound | One continuation decision used by page and actions | Before/at/after bound, wrong browser/intent, stale tabs, asynchronous callback and expired parent |
| Cancel/Switch | Foreign browser cannot mutate or burn a valid reference | Accepted transport policy with ordered checks | HEAD/prefetch, replay, cancel/switch/finalize race, valid error callback and trusted return target |
| Flow authority | Flow A submitted under admitted Binding B refuses even in one Rails session | Binding-owned lookup and immutable association | All entry methods, concurrent insert/restart, terminal states, stale evidence and retained history |
| Bootstrap | Unproven deployment context cannot finalize Bootstrap authentication | Independent final refusal and narrow context | Normal Entra remains Passkey-bound, unknown context denies, refresh/authorization propagation |

Candidate suites already inspected include
`test/integration/rp_backchannel_logout_receiver_test.rb`,
`test/operations/op_identity_event_invalidator_test.rb`,
`test/operations/op_logout_committer_test.rb`,
`test/integration/oidc_rp_logout_sibling_scope_test.rb`,
`test/services/base_auth_admission_coordinator_test.rb` and
`test/services/sign_up_cycle_locator_test.rb`. They are starting locations, not complete coverage
or proof that the target contracts pass. Old shared-path sibling tests must not be relabeled as
proof that BCL delivery and isolated local RP state work.

For every deadline/count/size boundary, define immediately below, exactly at and immediately above
values, plus missing/empty/malformed/reachable sentinel inputs. Negative tests must assert both
refusal and absence of unauthorized state changes; concurrency tests must assert the winner remains
valid after the loser returns. Environment/tooling construction is verified by running it and
recording actual observations, not by adding Minitest/Vitest setup tests.

## 5. Questions the detailed definitions must answer

1. Which later owner decisions have accepted ADR coverage, and which require explicit amendment?
2. What Gate replaces the impossible process-isolation claim in a one-Puma, shared-credentials app?
3. After removal of RuntimeRole and activation gating, what selects the retained local-RP path,
   and what prevents unintended simultaneous old/shared and new/local authority?
4. What is the exact acknowledged logout promise when BCL notification loss is accepted, and what
   are the measured bounds for every token/client class?
5. What bounded request-admission/capacity policy prevents same-Puma OP HTTP starvation?
6. Is GET consumption actually accepted as an exception to the current browser CSRF/GET rules,
   with a stated user-intent and reference-leakage threat model?
7. Which failures are permanent versus retryable, and what limits an attacker-induced JWKS/503
   retry storm without treating unverifiable tokens as verified?
8. What resource/action set can Bootstrap access, and what proves the runtime cannot be deployed?
9. Which immutable-FK, legacy-row, retention and purge decisions remain genuinely Pending after
   projecting D-36 and the E1 ADR?
10. What trusted RP return mechanism replaces plain `pt`, including Cancel and no-JS restart?
11. Is identifier-first implementation in this cycle or explicitly deferred under its new ADR?
12. Does locale content intentionally vary by region, and what happens for region-only keys?

## Review disposition

The draft is useful investigative material, but dependent implementation is **Conditional** until
the current-contract projection and scoped normative conflicts are resolved. Bootstrap deployment
proof, the GET/CSRF exception and unresolved transport compatibility must remain **Blocked** for
their dependent work; unrelated definition work can proceed. Source-confirmed gaps are not
execution evidence. No application behavior has been certified or changed by this review.

---

# 2026-10-21 follow-up review

## Scope, provenance and disposition

The updated requirements still need reconciliation before dependent implementation. The earlier
review prompted a useful current-contract projection, but later decisions have again diverged from
that projection. WU-05 also assumes prerequisites and cross-database outcomes that its execution
sequence does not yet establish. These are actionable definition gaps, not a certification that an
exploit or production outage occurred.

This review was requested after `three.md` was created. Only `four.md` is edited. Application,
ADRs, requirements, detailed definitions and acceptance remain unchanged by this review.

- Date: 2026-10-21; HEAD: `febec3225cc9a0cfa53b9cbe817d20d366aba5a2`, branch `feature`.
- The worktree contains pre-existing uncommitted code, tests, ADRs and documentation. Source
  observations refer to that worktree, not a clean checkout of HEAD.
- Reviewed inputs (SHA-256):
  - `one.md`, 1233 lines: `d6110e3f9e85d6dbaf2b13e39e15868b25ed73303b53a85b6ec14d0325ed4e37`.
  - `two.md`, 691 lines: `b6a732d52e8f098bbff9e75a1ebc53f760d36b9c425fd3971c411e16c015a7df`.
  - `three.md`, empty: `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`.
  - Earlier `four.md`, 550 lines: `413003c166f094ea5aedced4fbd41bbb778bd3144ae1616bea05888017d099bf`.
- `two.md` grew from 638 to 671 lines between the initial reading and this review. Its added
  section 5.J-2 was read. During final verification, `one.md` gained D-71 and `two.md` gained its
  dead-code decision and effective-intent investigation (1233/691 lines). Those additions were
  read and checked against the named source; removing only those additions reconstructs the
  previously reviewed hashes (`dfaf7597…` / `9d235a9b…`) exactly. R-20 includes this prerequisite.
  R2-A/R2-B remain options, not an owner decision.
- Method: document reconciliation, selected current source and test-body inspection, and a narrow
  check of primary OIDC specifications. No Rails/Vitest tests, database queries, migrations,
  browser reproduction, real HTTP capacity checks or deployment checks were run. Earlier test
  totals in `one.md` are attributed historical claims, not results obtained by this review.
- `three.md` is a valid place for future acceptance material, but contains no cases, Gates or
  execution results yet. Acceptance completeness cannot be established from an empty file.
- Finding labels and P0/P1/P2 retain the meanings in the original review. P0 blocks the dependent
  work, not unrelated investigation or an independently scoped fix such as WU-04.

The review uses the code-review-and-quality and security-and-hardening skills. Repository
constraints and Accepted ADRs are evaluated separately from reported owner decisions. This review
neither authenticates absent conversation history nor selects a new policy for the owner.

## Reassessment of R-01 through R-18

“Carried forward” means the newer documents have not demonstrated closure; it is not a claim that
all old source evidence was independently reproduced. No item is closed by a test run here.

| Earlier finding | Current disposition | Current basis / remaining work |
| --- | --- | --- |
| R-01, conflicting requirements | Partly addressed, recurrence confirmed | Sections 2–5 and history separation exist; newer conflicts remain (R-19). |
| R-02, facts versus contracts | Partly addressed | Introduction now distinguishes code and ADR authority. Section 2 still mixes intended removal with observed state; ADR reconciliation remains open. |
| R-03, JWKS failure versus invalid token | Source rechecked; unresolved | `OidcOpJwksClient#refresh` returns nil on fetch failure; Logout verifier returns failure and receiver answers 400. T8 records the target, no implementing WU defines it. |
| R-04, Puma HTTP self-call capacity | Risk carried forward | Synchronous token HTTP and bounded Puma request threads remain. X-8 is open; Visa is another host in the same process, so host separation does not establish capacity. No load test performed. |
| R-05, volatile BCL guarantees | Partly clarified; not closed | T10 separates stopped/attempted/acknowledged. X-3 still lacks executor bounds and post-commit failure behavior. |
| R-06, stop writers and BCL | Source rechecked; unresolved | Identity invalidator still omits `within_commit`; refresh reuse directly revokes the grant. T11/X-4 do not yet define the common owner. |
| R-07, residual access and retention | Carried forward | X-9 still open; `CoreBrowserCredentialContract::ACCESS_TTL` is 10 minutes. No measured all-client bound or tombstone retention proof. |
| R-08, connection-time SSRF | Source rechecked; unresolved | `OutboundHttp::Connection.build` enforces HTTPS/timeouts, with no checked-address connection pinning. T10 specifies a future target. |
| R-09, receiver inheritance | Source rechecked; unresolved | Core App Bare parent still declares browser gating and forgery protection. T10 explicitly reopens parent choice; no receiver definition closes it. |
| R-10, GET mutations | Carried forward as a decision gap | Design D is explicitly unapproved. D-46–D-52 are conditional; X-1 remains open. No CSRF exception is approved by this review. |
| R-11, deadline owner | Better target, unresolved projection | REQ-CURFEW defines one clock and boundary; T2 contradicts it and D-47 (R-19/R-22). |
| R-12, Flow authority | Source rechecked; unresolved | `SignUpCycleLocator#current` still has no admitted Binding input; E1 is a target. WU-05 needs its prerequisites (R-20). |
| R-13, aborted-transaction retry | Source rechecked; risk remains | Coordinator still rescues `RecordNotUnique` and retries inside the enclosing transaction, without a local savepoint. Collision not reproduced. |
| R-14, Bootstrap deployment proof | Carried forward | X-12 is open. `AuthenticationContextValue.from_claim` still maps blank claims to Normal. No deployment discriminator inspected or tested. |
| R-15, epoch consumer migration | Carried forward | RP authenticator still compares `umx_contract_epoch`; identity invalidator still handles NULL epochs. X-2/X-4/X-13 do not provide migration closure. |
| R-16, navigation/logout dependencies | Partly addressed in requirements | T9/T14 describe ownership and ID Token storage; WU-02 inventories host ownership, but callback/storage/logout changes and acceptance remain undefined. |
| R-17, Passkey target missing | Requirement omission addressed; implementation open | T16 records Accepted identifier-first; X-10 leaves cycle scope open. Direct Passkey options still select `actor = nil`. |
| R-18, regional translation semantics | Carried forward | Initializer still merges bundles; X-11 remains open. D-68 fixes surface namespaces, a different issue. No locale-root-fix WU exists in `two.md`. |

## Additional findings

### R-19 — P0 / Confirmed: the current projection again contradicts later decisions

**Evidence:** `one.md:101` (T2) retains min(parent, ceremony), 60-second acceptance and a restart
page. D-45/REQ-CURFEW require a fixed 30-minute window; D-46 conditionally shortens carried codes;
D-47 replaces the restart page with a uniform plain error. `one.md:104` (T5) keeps Local routes;
D-60 and WU-01 remove them. Section 2 still names Base as OP after D-59 moves the OP to Visa.
X-7 remains open despite D-53 and the Accepted RP-scope ADR. X-17 asks for a crossing policy already
chosen in D-47/D-48. X-21 asks about browser E2E while D-59 excludes it for WU-02. D-48 L1 fixes
Flow creation at callback, whereas D-70 and `two.md` 5.J-2 explicitly leave the location undecided.
T17 says a root locale fix is specified in `two.md`, but WU-01–05 contain no such definition.

**Trigger/impact:** an implementer using the advertised current sections can implement incompatible
deadlines, errors, host ownership or Flow creation timing. D-70 must not be treated as an approval
of either R2 option. The E2E statements need scoped reconciliation, not a blanket conclusion that
all browser checks are included or excluded.

**Required definition:** refresh the topic table and open-decision register, with explicit successor
IDs and conditional requirements. Distinguish intended end state, observed code and work already
delivered. Keep one canonical current statement per requirement; preserve history separately.

**Exit:** a reader can determine the chosen behavior without resolving conflicting paragraphs by
position. Link each accepted topic to its definition or explicit deferral.

### R-20 — P0 / Confirmed definition gap: WU-05 depends on unassigned E1 and curfew work

**Evidence:** WU-05 P1/P4, C1 and the R2 options require a Flow owned by the admitted Binding and
bounded by the curfew. `two.md` section 5.K sequences WU-04, WU-05, then WU-02, but assigns no preceding
unit for E1 schema/lookup/immutability or the shared deadline. `one.md` X-13 still reserves migration
choices. Current `ClientSignUpFlow` has no E1 association; `SignUpCycleLocator#current` resolves a
session locator; `BaseAuthAdmissionCoordinator#create_or_reuse_binding!` caps binding expiry by the
short acceptance TTL. The E1 ADR explicitly says the target is not implemented.

D-71 and the new 5.J-2 investigation now identify another prerequisite: ordinary first-party
Admission intent is neutral. Source inspection confirms `authorization_intent` returns
`authentication`, `issue_handoff!` supplies no `entry_intent`, and
`validate_entry_parent_intent!` accepts either sign-in or sign-up for that neutral parent.
`issue_switch_admission!` supplies an explicit target. The finding is now acknowledged in the
documents, but its effective-intent rule, initial sign-up entry and refusal behavior still need
an executable definition. The investigation's proposed precedence is not treated as an additional
owner-approved decision here.

**Trigger/impact:** implementing social pending accounts first can leave the existing cross-tab
locator authority in place, invent a second Flow-to-Binding mechanism, or truncate a candidate to
the 60-second acceptance deadline. Calling P1/P4 invariants does not construct their prerequisites.

**Required definition:** assign prerequisite ownership and acceptance for effective intent, authoritative Binding
lookup, Flow construction/cardinality, immutable association, deadline storage/consumption and safe
schema ordering. Settle or explicitly block the required X-13 decisions. A staged implementation
must state which invariants hold after each stage. The independent telephone Turnstile fix need
not wait for these decisions.

**Acceptance:** cross-Binding stale tabs, concurrent same-Binding creation, each surface's predicate,
all six entries and callbacks beyond acceptance but before curfew. Include missing/mismatched E1
ownership and missing deadline refusal. No private-method or text-only test substitutes for these.

### R-21 — P1 / Confirmed definition conflict: “every refusal ends the attempt” has no safe scope

**Evidence:** D-47 covers every ceremony refusal and clears continuity. WU-04 requires Turnstile
refusal to preserve OTP/Flow state, render a new challenge and allow retry. D-49 requires another
browser's request to fail without consuming the victim's reference. D-48 L4 separately requires a
5xx for a broken invariant. Current social confirmation renders a retryable 422 after Turnstile
failure (`Auth::App::Sign::Up::Check::Google::ConfirmationsController#update`); lifecycle rules
require a named transition and absorbing terminal states, rather than arbitrary FAILED writes.

**Trigger/impact:** a literal D-47 implementation can break WU-04's required retry, terminate a
victim's server-side attempt on a forged request, or hide a dependency/integrity failure behind an
ordinary credential refusal. Clearing only a Rails locator does not end the durable Flow or free
its partial-UNIQUE slot. This is an ambiguity in the target, not proof of such a new mutation today.

**Required definition:** a refusal table by boundary and cause, including externally visible
status/body, retry permission, request-local cleanup, owned durable transitions, OTP/evidence
consumption and dependency/invariant handling. Explicitly preserve foreign-browser non-consumption
and unrelated tabs. Choose whether WU-04 is an exception to D-47 or D-47 is narrower. Keep the
existing browser-RP distinction between credential and dependency failures.

**Acceptance:** retry after failed Turnstile; wrong browser cannot terminate another attempt;
failed cleanup is observable; terminal attempts cannot later issue authority; dependency failure
preserves credentials as required. Uniform account-facing copy alone is not a complete outcome table.

### R-22 — P1 / Decision gap: the 30-minute anchor does not define Switch and completion ordering

**Evidence:** REQ-CURFEW stores an immutable deadline on each Binding and says parents and RP
pending state cannot expire earlier. T3/D-39 keep the OIDC parent on Switch while issuing a new
Binding. The RP pending flow starts before OP Admission issuance; current
`OidcCallback::OIDC_PENDING_FLOW_TTL` is 10 minutes, measured from RP flow creation.
REQ-CURFEW 3 refuses every sign-up action at the deadline, while clause 7 preserves registration
completing after it.

**Trigger/impact:** a Switch near minute 30 may get a new deadline beyond its retained parent and
RP state, or inadvertently extend the original attempt. Simply setting every TTL to 30 minutes
still allows an earlier RP-start timestamp to expire first. A registration starting before and
committing after the boundary also needs a defined durable-write decision.

**Required definition:** choose whether Switch inherits the original attempt deadline or starts a
new window and define every affected parent/child obligation. Bound the RP-to-OP pre-admission
interval and accepted callback completion interval. Name the authoritative database/clock for the
curfew decision; `database_now` is model-local and does not itself establish one clock across all
RP/principal/OP databases. State precisely which durable registration write may finish after the
cutoff and which evidence/session writes must refuse.

**Acceptance:** Switch just before/at/after cutoff, delayed initial OP arrival, callback arriving
near the RP-state deadline, lock wait spanning expiry, and registration principal commit spanning
the cutoff. Assert both preserved registration and absent unauthorized session issuance.

### R-23 — P1 / Confirmed ambiguity: relay replay has two incompatible 10-second origins

**Evidence:** D-46 counts the Admission's entire attach-confirm-redeem lifetime from issuance.
D-49's table says repeats are accepted within 10 seconds of issuance, but its following text counts
the replay limit from `redeemed_at`. It also requires the same next redirect without another effect.
Design D remains conditional, so this is a defect in its conditional definition, not an approved
implementation to repair now.

**Trigger/impact:** redemption near the original deadline could create another replay window if
only `redeemed_at` is used. Returning the original next URL can also return an already-consumed or
expired next-hop reference. “Same outcome” does not establish that the response remains usable.

**Required definition:** per-hop issuance, expiry and replay predicates; whether replay is bounded
by original expiry, post-redemption expiry or both; the stored response identity and handling when
the next hop has already completed. A replay must neither mint a new credential nor renew authority.
Preserve the current-generation and originating-browser checks after session rotation.

**Acceptance:** a repeat just before/at/after original expiry, redemption close to expiry, the next
reference already consumed, response loss after commit, concurrent repeated hops and different
browser. Verify resulting state and returned destination, not merely a 303 status.

### R-24 — P0 / Definition gap: durable registration is not yet a demonstrated recovery point

**Evidence:** WU-05 F3 commits the External Identity and verified Client in the principal database;
F4 then provisions the graph and completes the OP Flow, saying the next attempt is ordinary
sign-in. Current shared completion actually does principal side effects → `:finalize` →
`IdentityGraphProvisioner` → `:complete` → sign-in handoff
(`sign_up_sequence_controller_support.rb:240`). The provisioner calls
`BaseSelectorBootstrapAuthority` and re-raises failure. The Flow and Candidate are in `op_base_app`;
the Client/External Identity are in the separate principal database. Candidate consumption joins
its own connection's transaction (`IdentityCeremonyCandidateRecord#consume!`).

**Trigger/impact:** after a committed principal write, a graph or OP transaction failure can leave
an identity that callback lookup recognizes but whose Flow, graph or candidate state differs from
the claimed completed outcome. The durable-Identity preservation rule correctly forbids deletion;
it does not prove ordinary sign-in can finish or that consumed evidence cannot be retried against
a rolled-back Flow.

**Required definition:** a failure matrix at candidate consume, principal commit, graph commit,
Flow transition, evidence handoff and response delivery. Name each transaction and commit owner,
which consumed facts survive each failure, how the original registration operation is recognized,
and what subsequent ordinary sign-in actually does. Reconcile F4's stated order with the shared
finalizer. If recovery is intentionally refusal/manual repair, say so rather than promising an
unverified working sign-in; no compensating deletion or unapproved reissue is requested.

**Acceptance:** fail at each boundary through public entry points and real separate DB
transactions; assert remaining rows and the next sign-in's observable result. A single mocked
exception or a code-revert plan cannot prove these cross-database properties.

### R-25 — P1 / Risk: cleanup eligibility must be rechecked under the principal lock

**Evidence:** WU-05 P5/D-70 extend cleanup to contact-less social pending Clients; F3 promotes that
Client during finalization. Current `SignUpArtifactCleanup#client_dependent_records` tests
UNVERIFIED status before returning records; `schedule_dependent_retention!` later locks each
record and discards it without repeating that eligibility decision. A same-Flow lock helps, but
U5 also permits fresh-provider retry and the design has not fixed whether it ever reuses a pending
Client across attempts.

**Trigger/impact:** if a permitted new flow/other writer promotes a previously selected pending
Client before cleanup obtains its principal lock, the cleanup could act on a durable registered
Client. This interleaving is a risk to exclude, not a reproduced current-request failure.

**Required definition:** choose whether new attempts always get new pending Clients or can adopt an
old one with explicit ownership. At cleanup's mutation boundary, recheck pending status, exact
Flow/operation ownership, absence of completed identity/graph authority and retention eligibility
under the relevant locks. Define the lock order with finalization. Preserve already durable
identities and other attempts' artifacts. Existing cleanup uses logical retention for the actor;
P5's word “removed” must not silently authorize physical deletion.

**Acceptance:** cleanup versus confirmation/finalization, old Flow cleanup versus newly authenticated
retry, cleanup failure/retry, and completed or foreign actors. Demonstrate that a verified Client
and its identity remain usable after a losing cleanup operation.

### R-26 — P1 / Missing detail: Flow locks do not serialize different social subjects' owners

**Evidence:** WU-05 F3 names the Flow lock and subject uniqueness; 5.J marks the two-flow race
resolved. Existing `SocialAuthSignupFinalizer` additionally uses
`ClientExternalIdentity.with_subject_lock` inside the principal transaction and checks release
history there. Different Flows have different row locks. WU-05 proposes moving this logic into a
shared finalizer that currently only promotes an already supplied actor for `social_identity`.

**Trigger/impact:** a unique index determines who inserts first, but does not itself serialize the
release-history check with unlink/relink, or keep subject-specific security checks and pending
actor promotion in one decision. Losing uniqueness after promotion must not leave a verified
orphan. Existing source behavior must not be reduced to “Flow lock plus UNIQUE is enough.”

**Required definition:** retain or explicitly replace the principal-DB subject lock and its order
relative to Flow/Client locks. Define exact-subject checks for all existing states, including L7,
release history, registered ownership and enforcement bans at the final boundary. Keep D-70's
accepted provider-event interval risk distinct; this review does not reopen that accepted choice.

**Acceptance:** two different Flows finalizing the same subject, unlink/relink racing finalization,
a ban visible at finalization, and a pre-existing revoked/deleted subject. One winner only; the
loser neither adopts the winner's Client nor commits verified orphan state. Test both providers.

### R-27 — P1 / Confirmed: Candidate dependency and expiry definitions describe the wrong mechanism

**Evidence:** WU-05 C3 says Valkey unavailable means fail closed, while
`IdentitySocialCeremonyCandidateStore` persists encrypted `auth_hash` in
`IdentitySocialCeremonyCandidate < OpBaseAppRecord`. `fetch!`/`consume!` use PostgreSQL.
`payload_for` stores only the verified principal; reconstruction sets `credential_candidate: nil`.
C1 instead says it holds a credential candidate and caps expiry by “Admission” without distinguishing
acceptance expiry from continuation. D-36/D-45 explicitly separate those deadlines.

**Trigger/impact:** an implementation or test could check an irrelevant outage, assume an Apple
credential survives storage, or shorten a 30-minute candidate to the 60-second/conditional
10-second acceptance lifetime. Valkey can still matter to other protocol components; it is not the
storage dependency shown by this Candidate API.

**Required definition:** identify the actual Candidate store, persisted fields, bindings, encryption,
consumption transaction and dependency outcomes. Specify the exact continuation/curfew field used
for its cap and separately any provider-evidence expiry. If a provider credential is required,
assign its storage and lifecycle explicitly; do not imply the current store retains it.

**Acceptance:** OP DB outage, consumed/expired/mismatched Candidate, delayed confirmation beyond
acceptance within curfew, and round-trip evidence fields. Keep Valkey outage tests at boundaries
that actually depend on Valkey. These are behavior checks, not environment-construction tests.

### R-28 — P1 / Confirmed: unchanged failure counts are an inadequate deletion acceptance oracle

**Evidence:** WU-01 dead-code check 3 and exit criteria accept the same OIDC pass/fail set as the
baseline. `one.md` TR says G1 already prevents self-RP completion, while G2/G5 include intentionally
stale expectations. WU-01 also anticipates additional failures from re-pointing local fixtures and
asks that they be classified as pre-existing. WU-02 remains Phase 1, expressly not an executable
implementation definition. WU-05 5.J uses “Resolved” for design reasoning without executed tests.

**Trigger/impact:** an earlier failure can mask a new regression later in the same journey; equal
counts or equal failing names do not prove preserved behavior. Conversely a correctly re-pointed
test can fail for a known upstream defect without proving the code deletion unsafe. Deleting
unreachable production code is still not permission to weaken surviving OIDC contracts.

**Required definition:** characterize each surviving public behavior reached by converted fixtures,
record known blockers by cause, and assign end-to-end completion to its fixing unit. Keep
“designed,” “implemented,” “executed,” and “passed” separate. Report blocked assertions as
unverified; use a concrete defect reference for intentional expectation changes. Full-suite reruns
need a reason beyond unchanged totals.

**Acceptance:** affected surviving OIDC tests prove the behavior beneath their intended boundary;
removed-route tests prove each method/realm is gone; no new failures remain unexplained. A
baseline can support comparison, but cannot establish closure on its own.

### R-29 — P1 / Confirmed coverage gap: most projected topics have no executable definition or Gate

**Evidence:** `one.md` covers T1–T20; `two.md` defines only five WUs; `three.md` is empty.
Several topics deliberately remain X decisions. This is acceptable preparation, but does not make
WU-01–05 a plan to complete the whole requirement set.

| Requirement area | Present definition / missing owner |
| --- | --- |
| T1–T5, relays, deadlines, cancellation and result transport | X-1/X-18/X-20 remain; no complete implementation unit. WU-02 host inventory is partial coverage. |
| T6, E1 ownership/cardinality | Accepted target and X-13; no complete migration/lookup unit. WU-05 depends on it. |
| T7–T8, refresh and JWT verification | Current contracts and open capacity/recovery questions; no complete implementation unit. |
| T9–T13, logout/BCL/stop/sign-out | Host inventory in WU-02; stop matrix, executor, receiver, ID Token storage and migration definitions missing. |
| T14, RP return target | Ownership chosen, input/cancel-return mechanism still open; no complete unit. |
| T15–T16, Bootstrap and Passkey | Scope/decision blockers X-10/X-12; no executable unit. |
| T17–T18, locale and credentials/KMS documentation | Namespace fix recorded; locale-root definition and documentation work unassigned. KMS implementation explicitly deferred. |
| T19–T20, refusal telemetry and Gates | Outcome scope conflicts and X-15; no acceptance register. |
| Local flow, legacy cookie endpoint, telephone Turnstile, social unification | WU-01/03/04/05 cover explicit subsets, subject to their blockers and acceptance gaps. |

**Required definition:** a bounded cycle scope with included/deferred/blocked status, owning WU,
prerequisites and acceptance for each topic. Preserve explicit exclusions for Edge/Jump changes,
production key provisioning, destructive data operations and browser E2E where applicable. Record
handoff checks as pending external integration, never as Rails-only proof of the browser graph.

**Acceptance:** three.md eventually lists concrete cases and truthful results per included
boundary. Its current empty state is “not defined/not executed,” rather than a failing application
test. Completing five WUs must not imply all twenty topics passed.

### R-30 — P1 / Confirmed omission and protocol ambiguity: standards-first obligations were lost

**Evidence:** historical RP-4 requires revocation endpoint client authentication including
`private_key_jwt`; sections 2–5 retire the historical draft as implementation input but have no
explicit projected equivalent for that endpoint. Current COM `RevocationsController#create` still
passes only `client_id`/`client_secret` to `OidcTokenRevoker`. WU-02 moves the endpoint without
assigning this behavior. D-25 requires recovery by `prompt=none`; D-47 broadly makes every refusal
a fixed local response; T3 separately requires a correlated OIDC `access_denied` callback.

**Trigger/impact:** a standard-shaped client can authenticate token exchange yet lack its intended
revocation method. A blanket local-error implementation can also strand an RP transaction rather
than return a validated protocol error. This does not assert that current source already applies
the new D-47 rule to every endpoint.

**Required definition:** restore explicit disposition of RP-4, and name which boundaries use local
uniform errors versus OIDC authorization, token, revocation and logout error contracts. Preserve
exact registered redirect validation and state/issuer correlation before any protocol return.
Scope privacy copy without silently replacing machine-readable protocol outcomes. For RP logout,
keep expired-hint validation distinct from accepting an expired ID Token for authentication.

**Primary checks:** [OIDC Core 1.0, prompt and error response rules](https://openid.net/specs/openid-connect-core-1_0.html#AuthRequest)
requires noninteractive behavior for `prompt=none` with protocol errors when interaction is needed.
[RP-Initiated Logout 1.0, section 2](https://openid.net/specs/openid-connect-rpinitiated-1_0.html#RPLogout)
requires GET and POST request support and permits the specified expired-hint handling. These narrow
checks support boundary separation, not a full standards-conformance judgment.

**Acceptance:** per-realm revocation with the intended registered authentication method, wrong
client/realm/audience and assertion replay; silent recovery success and interaction-required
response; valid Cancel callback versus invalid redirect/state/issuer; expired logout hint versus
expired authentication token. No external client operation is approved by these design checks.

## Recommended disposition and next definitions

1. Reconcile the current projection first (R-19), with an explicit bounded cycle scope (R-29).
2. Define E1/curfew prerequisites and social Flow creation ownership before dependent WU-05
   implementation (R-20/R-22). R2-A versus R2-B remains an owner decision; no choice is made here.
3. Settle refusal/retry semantics, relay replay and protocol outcomes together (R-21/R-23/R-30).
   Design D remains conditional; it is not authorized by this review.
4. Complete the social finalization failure, subject-lock and cleanup contracts (R-24–R-27), then
   turn those into public-boundary acceptance cases. Keep the accepted provider-event residual
   risk, durable-registration preservation and Sign In First boundaries intact.
5. Write the missing retained-RP, authority-stop, BCL, migration and navigation definitions or
   explicitly defer them. Replace the impossible isolation Gates with scoped, measurable criteria.
6. Populate `three.md` with the accepted cases and, only after execution, actual results. Include
   AUTH-19 foreign-browser tests, concurrency on separate connections, boundary values and absence
   of forbidden mutations. Keep real-browser/Jump/WAF/capacity checks visibly unverified where
   outside this cycle. Setup is run-and-record work, never a Minitest/Vitest environment test.

WU-04 is a candidate for independent progress after its retry semantics are reconciled. The
remaining definitions may be developed without treating unresolved dependencies as implemented.
No implementation, data mutation, deployment or security-policy exception is authorized by this
report. The review does not establish that the system is defect-free; it identifies concrete gaps
in the inspected scope and the evidence needed to close them.
