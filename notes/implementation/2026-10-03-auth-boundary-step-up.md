## OIDC effective result deadline and neutral-entry registration gap

OIDC result delivery is now bounded by both durable admission deadlines and requires typed generation/digest matching. Evidence: `evidence/2026-10-04-oidc-result-effective-deadline-2D8N.md` (146 tests, 1508 assertions).

The accepted `adr/sign-neutral-entry-and-logout-target-authorization.md` requires Base to open Auth on sign-in and offer registration inside Auth. `BaseNeutralSignEntry#create` issues `local_sign_in`, whereas `AppSignUpEntryPage` and APP/COM sign-in props expose ordinary links between sign-in and sign-up. `AuthCeremonyContext#auth_ceremony_matches_intent?` correctly refuses a local ceremony of the other purpose. A purpose-authorized transition for that same live neutral-entry transaction is therefore required; redirecting the links back to neutral Base would merely issue another sign-in admission and preserve the loop. No purpose fallback or Base sign-up selector was introduced.

The pending sign-up parent/child constraint proposal addresses the child linkage only. It does not, by itself, authorize purpose changes. Mode selection must preserve the Base authority, browser binding, original deadlines and one-shot phase, and refuse changes after principal/proof binding or on step-up/credential ceremonies. Its implementation and public transport contract still require design before editing that workflow.

## OIDC timestamp precision and sign-up authority binding proposal

OIDC admission expiry now compares stored timestamps directly. Tests cover PostgreSQL microsecond neighbors on all three surfaces and public authentication registration without retiming the event. Evidence: `evidence/2026-10-04-oidc-expiry-precision-9H4M.md`.

The current Auth ceremony constraint allows at most one reference across OIDC authority, local Base sign-in authority and sign-up flow. Existing local sign-up admission already points to Base's sign-in authority; attaching its Auth-owned sign-up child is prohibited by that constraint. The proposed distinction between one Base authority and its exact APP/COM sign-up child is recorded in `plans/analysis/sign-up-admission-child-binding-shape-proposal.md`. Explicit shape approval was requested; no implementation or migration for that proposal has been applied. ORG registration remains unavailable.

## OIDC result revocation and Base lock order

Credential transitions now expire actor-owned unfinished OIDC evidence and cancel APP capacity resolutions in the same ticket transaction as continuity revocation. Base OAuth completion on all three surfaces takes the actor lock before the authorization row; APP limit promotion executes inside finalization and rejects stale parents before selecting a session for revocation. Existing response shapes and completed history remain intact. Evidence: `evidence/2026-10-04-oidc-credential-revocation-5K9D.md`.

Initial sign-up continuity FK columns have no active call-site connection yet; that remains part of the full registration workflow work. Independent OIDC root-finalization races and late evidence recording across a credential change also remain outstanding.

## Local login revocation boundary and evidence race verification

All three surfaces now have expiry-neighbor coverage and an independent-writer race between Auth evidence recording and credential changes. APP has a real Base/Auth middleware test refusing the outstanding result after a credential change. The existing FAILED-flow policy redirects to Base root without issuing root credentials; no production authorization change was needed. Evidence: `evidence/2026-10-04-local-login-revocation-races-7Q2B.md`. Concurrent successful root issuance and broader OIDC/sign-up invalidation remain unverified.

## Local login evidence revocation after credential changes

Credential security transitions now end unfinished local admission-linked sign-in flows and their Auth continuity before token changes. Existing root-session policy flags and completed authentication history remain intact. Writer ticket-state rollback on an injected clock failure is covered on APP, COM, and ORG. Evidence: `evidence/2026-10-04-local-login-credential-revocation-4C8R.md`. OIDC/sign-up coverage and concurrent root-finalization races remain outstanding.

# Authentication boundary and step-up implementation context

On 2026-10-03 the user directed the OTP delivery-event/DEBUG disclosure to be escalated and
resolved comprehensively. The previously isolated logging proposal is deferred to the mandatory
[active remediation plan](../../plans/active/otp-observability-secret-exposure-remediation.md)
and [accepted handling ADR](../../adr/otp-observability-secret-exposure-remediation.md).
The user explicitly excluded OTP logging remediation from this implementation and will perform
browser verification separately. The remediation remains open; no logging format change is authorized.

The conversation's R01–R16 ledger is the implementation scope. Related decisions are `adr/root-login-establishment-boundary.md` and `adr/base-auth-ceremony-and-seven-rp-boundary.md`. The ledger is not complete.

The user approved additive actor-specific flow evidence/result fields, preserved sign-in authentication context, Auth admission purpose and exclusive transaction references, durable step-up result generation/state, exact verified credential references, and public challenge fields on existing step-up sessions. The user also approved reusing the existing PasskeyAuthenticationPanel transport and making Base verification GET a confirmation page followed by CSRF-protected POST admission. Do not request those approvals again.

Local sign-in now returns Auth evidence through an opaque result to Base's existing root issuance function. ORG Emergency evidence preserves Emergency context. Transport acceptance has a short deadline; a result already accepted by Base into the existing session-limit pending flow uses that flow's deadline and original authentication event during remediation. It does not promote a stale timestamp to the current time. This distinction is recorded in the root-login ADR.

Phase two has additive ticket storage and model/write boundaries in place. BaseStepUpAdmissionIssuer retains a specific transaction, deadline and attempt count across repeated starts. Opaque admission/result resolution uses the actor-specific step-up table and exact purpose instead of OIDC lookup. DB-backed Passkey challenge methods use session-to-transaction lock order, preserve the challenge deadline, and burn a matching reference before reporting an origin or expiry mismatch. Signature verification callers must perform this consumption as its own committed ticket operation before a later verification/finalization transaction; an enclosing transaction that rolls back could otherwise undo the burn.

Base confirmation/POST start, scoped Auth admission, Passkey POST options and real assertion verification, opaque result return, and atomic Base freshness completion are connected. An APP HTTP integration starts from an actual Base-issued root cookie, completes a signed Passkey assertion on Auth without root cookies, and returns to the protected birthdate page. Jump and Turnstile are stubbed; this is not a real-browser result. COM now has an independent complete HTTP journey; ORG remains outstanding. Legacy JWT and CookieStore callers outside this new path still require retirement; signup, MFA, settings, cancellations and invalidations remain incomplete.

The approved APP/COM Email OTP columns and encrypted Noticed job payload are implemented. Issuance uses the existing 60-second step-up resend interval. Verification uses the existing five-attempt, fifteen-minute lockout policy, with credential-scoped counters that survive resend and replacement transactions. Ticket proof is one-time and does not itself grant Base freshness. Delivery checks the exact transaction, recipient and code generation on writers before SMTP and records the current generation's outcome. SMTP runs outside database locks; cancellation or resend after that check can prevent proof acceptance but cannot recall an already-sent email. APP/COM display, issuance, verification and redelivery now use that admitted DB context. APP encrypted delivery through the test mail adapter and suspension rejection passed; external SMTP and the wider fault campaign remain unverified. OTP logging remediation is tracked separately as directed by the user.

The user deferred the proposed APP Email JSON success format change. Its current success renderer
expects token data and is not suitable for Auth evidence-only completion. Leave this as an explicit
unresolved contract; do not restore Auth root issuance or silently claim this path works. The full
Ruby regression run also exposed old admission-free Auth tests and continuation expectations. They
need purpose-correct setup and assertions, while real implementation failures still require fixes.

Tests must run sequentially at the command level because the repository test harness clones shared PostgreSQL databases. Concurrent Rails commands caused a source-database-in-use setup error; sequential rerun passed. Individual tests may still use the existing independent-connection concurrency harness. Do not change environment construction or global test helpers to hide preparation errors. Current retained observations are in `evidence/2026-10-03-auth-boundary-foundation-7P4K.md`.

The unrelated dirty TypeScript tests, group membership test and exploratory CloudFront memo predate this continuation and must remain intact. No commit, deployment, real browser or live provider verification is implied by local integration tests.

Cancellation now targets the stored transaction rather than the latest pending row. It serializes with Base completion through token/session/transaction locks, closes admitted Auth continuity, and preserves finalized success. Auth returns through Jump to a fixed Base dashboard. Base cancellation uses its stored browser transaction reference. Independent-connection cancellation races and all three complete browser journeys remain unverified.

APP TOTP assertion now uses scoped Auth admission and records the exact credential and original
verification time on the existing step-up transaction. TotpWindowConsumer retains credential locks,
replay rejection and durable failures, and obtains writer database time after locking by default.
The HTTP test exercises real TOTP verification without an Auth root session; Turnstile is stubbed.
TOTP enrollment and Base completion now have HTTP/UI coverage described below.

CredentialSecurityTransition now serializes with Base completion through the principal actor lock
and revokes pending/verified transactions and Auth continuity on the ticket writer even when no
freshness has yet been issued. The freshness revoker clears all canonical fields and locks the
token's unique step-up session. Direct token revocation and refresh rotation now invoke the same
model-owned authority revocation under the token lock. Selector lifecycle integration is now
implemented as described below. Actual APP encrypted Noticed delivery through the test mail adapter and
suspension rejection passed; no external SMTP or logging remediation is implied. The final narrow
run is recorded in `evidence/2026-10-03-step-up-totp-delivery-revocation-6F2A.md`.

The user approved registration transaction/candidate FKs, nullable pending TOTP confirmation time,
and three explicit admission/result purposes. Generated actor-specific migrations were applied
only to test ticket databases. Existing unbound rows remain historical; new enrollment requires
the exact parent permission. Rollback requires draining unconfirmed candidates and admissions
with new purposes before restoring the previous constraints. No destructive cleanup was performed.
IdentityTotpEnrollmentIssuer stores an encrypted pending candidate and reuses its original deadline.
IdentityTotpEnrollmentVerificationCommitter confirms its first real TOTP code exactly once, retains
failure counts, and records registration evidence with no assurance/freshness claim. Controller
connection is implemented for first APP TOTP registration; Base credential finalization is tested at both operation and HTTP boundaries. Registration evidence is separated
from ordinary step-up by actor-specific DB constraints, the normal proof API purpose guard, and
negative tests through the Base freshness committer.

The user explicitly approved rebuilding only the task-owned isolated APP principal copy
`codex_integrity_20261003auth6f3_app_zenith`. The other participant's Secret rebuild and the three
registration-evidence constraint migrations were applied in owned copies, not shared databases.
At that checkpoint, broad HTTP tests stopped at stale Secret fixtures referencing a removed table. The new focused
operation/model tests explicitly select their own fixtures through Rails class-local configuration,
without changing global setup or another participant's files. Their 17 tests / 294 assertions pass;
see `evidence/2026-10-03-registration-evidence-isolated-4R8C.md`. COM's extended HTTP journey was unverified at that checkpoint; its later result is recorded below. Browser verification remains user-owned, OTP logging
remediation remains excluded, and the held APP Email JSON response contract remains unresolved.


BaseStepUpAdmissionIssuer now supports registration-only bootstrap without assurance claims. It
checks writer credential history while holding the actor lock: confirmed/suspended/deleted Email
state and any Passkey/TOTP history prevent ordinary first-registration bootstrap. Temporary method
unavailability is not permission to bootstrap. Bootstrap keeps the original protected scope and
return target; its child transaction binds the chosen authenticator registration. Later TOTP
registration still requires `settings_totp`.

IdentityTotpEnrollmentFinalCommitter now creates the confirmed APP credential at Base, atomically
spends parent/child/candidate/continuity on the ticket connection, and leaves freshness unchanged.
The principal transaction holds the actor lock around that ticket commit. This is fail-closed
cross-database finalization, not a distributed atomic commit: a principal failure after ticket
commit may leave a terminal ticket without a credential. Such a result cannot recreate a credential;
the user must start a new Base ceremony. A failure before consumption retains verified proof for
retry. A bounded transport retry returns only the same existing active owned credential. Revoked,
deleted, or missing credentials are refused. Principal commit fault injection and independent
connection races remain outstanding; current tests cover a principal persistence exception and
simulate the missing-row outcome.

An operation-level journey completes Base bootstrap, real initial TOTP confirmation, Base creation,
then a separate TOTP assertion in a later window and ordinary Base freshness completion for the
original birthdate scope. Registration itself never satisfies that requirement. Auth context
readers keep normal verification purposes separate from registration purposes; negative HTTP tests
refuse bootstrap/registration/credential-change continuity at ordinary verification endpoints.

APP and COM now each complete a genuine local Email login on Base, a real-cryptography Passkey
assertion on Auth without Auth root cookies, and a return to the protected Base birthdate page.
COM's fixture uses the existing required verified contact and fixed Passkey status rows; production
contact/ownership validation was preserved. Browser and live provider checks remain unverified.
The concurrent Secret participant replaced its stale fixtures during this continuation; existing
freshness/cancellation/admission regression tests then passed with global fixture loading.

The APP first-TOTP registration slice now connects the protected-operation prerequisite to Base
confirmation and canonical bootstrap, scoped Auth setup and server candidate operations, opaque
registration return, and Base finalization through the exact browser marker/origin boundary.
A real local Base login HTTP journey verifies that registration does not satisfy the original
birthdate requirement: a separate subsequent TOTP assertion is required. Setup admission and
cancellation also work independently on COM and ORG, without Auth root cookies. This does not
establish completion of their Passkey registration flows.

Candidate display now names IdentityTotpEnrollmentQuery directly in the concrete controller.
Action Policy registration actions pass the scoped actor explicitly because earlier pipeline
evaluation can cache an anonymous default context. COM cancellation now uses the existing Jump
transport to its fixed Base dashboard; a direct cross-host redirect raised OpenRedirectError.
The real CSRF test uses HTTPS matching the configured origin and observes Rails' HTTP 422 refusal
before admission consumption, then redeems the same reference from the legitimate origin.

Settings management still needs purpose-specific credential-change authority. Passkey registration,
later registration, Base-owned initial contact registration and legacy
JWT/Cookie retirement remain outstanding. Registration audit and independent notification must be
attached to Base finalization; removing premature Auth credential creation does not establish
those records. The old Cookie-based TOTP controller tests still require purpose-correct migration
while retaining management coverage. Current HTTP and UI results are recorded in
`evidence/2026-10-04-totp-registration-http-boundary-5J8C.md`.

Selection persistence now compares the stored account/collective/unit/Avatar tuple under the token
writer lock. A changed tuple revokes freshness, pending/verified transactions and admitted Auth
continuity in that same ticket transaction. Revisiting the same selection preserves the original
authentication time. Invalid candidates are rejected before revocation or persistence. Explicit
selection clearing uses the same token primitive, with fixed model-owned columns so COM does not
attempt to write an unsupported Avatar column. Real model/service tests cover all three surfaces
and a COM switch between two authorized organizations with verified evidence. Independent-connection
switch/completion races remain outstanding. Results are in
`evidence/2026-10-04-selected-context-step-up-invalidation-7M2D.md`.

Registration route guards now pass after removing the unnecessary TOTP callback skip and documenting
the exact setup admission category. Session-limit cancellation returns to Base's neutral admission
entry rather than Auth without permission. Opaque admission `entry_ref` is explicitly filtered in
Rails parameters; other telemetry remains unproven and OTP logging remains excluded. The required
broader root-login selection is not green: the old admission-free Auth Email integration file
produces one failure and four errors and must retain its seven scenarios when migrated. Results
are recorded in `evidence/2026-10-04-auth-registration-entry-guards-3P7L.md`.

Passkey registration has no server-side candidate public-key record for Base finalization. The
existing child parent FK alone cannot replace Auth direct creation. The additive child candidate
fields and removal of premature passkey_id from Auth success are proposed in
`plans/analysis/passkey-registration-base-candidate-shape-proposal.md`; implementation awaits
explicit approval. Do not repurpose social candidates, mint a registration JWT, or label a
candidate reference as an already-created credential.

Three root-login integration scenarios now start at Base and traverse scoped Auth admission and
opaque Base completion: normal issuance, refusal at capacity, and refusal of identifier-only
session-limit access. They pass with actual cookie/audit/token checks. The remaining capacity
resolution, cancellation and cooldown cases still use old Auth entry and require migration;
none of the seven scenarios was removed. See
`evidence/2026-10-04-root-login-http-test-migration-8D4H.md`.

Capacity resolution and cancellation are now migrated too. The five Base-origin scenarios pass
109 assertions, including once-only root issuance/audit after revocation, original event time,
existing-token preservation on cancellation and old-result rejection. Cooldown remains the old
Auth-origin test and must be replaced before declaring the required root-login gate green.

Cooldown is now migrated to Base-origin HTTP and split into exact/one-microsecond-after acceptance
cases, each checking repeated refusal including the nearest pre-boundary timestamp. The old login
helpers are removed. The required issuance/cooldown/root-login selection passes 59 tests and 401
assertions (seed 19839), superseding its previous failure. The RESTRICTED negative test still uses
the existing authenticated-header harness and is not a genuine-session establishment proof.
Full R01–R16 remains incomplete; pending Passkey shape approval is unchanged.

The existing step-up parent purger now has a reproduced FK failure because the canonical Auth
continuity references are restrictive. Its no-dependents comment is obsolete. The new public
operation regression remains red pending coordinated child retention and writer-local cleanup;
do not remove FKs or swallow the failure. Observations and required correction are in
`evidence/2026-10-04-step-up-purge-reference-failure-4Q6R.md`.

The reference regression is now green. Parent purge uses fixed actor-specific dependents, retains
cohorts with retained children, and deletes eligible children before the parent on one writer
transaction. It preserves explicit StepUpSession purge eligibility and recent terminal/consumption
timestamps. Seven retention/job regressions pass 40 assertions. The evidence record contains the
remaining independent-connection race/fault and child-partition limits; this is not full R15 closure.

Expired admitted continuity previously caused TokenStatusManagement revocation to raise and roll
back because AuthCeremonySession#revoke! required active continuity. Explicit revocation now closes
nonterminal expired continuity; admission/evidence/completion/cancellation remain expiry guarded.
A microsecond boundary regression passes before/at/after expiry and refuses later evidence.
Parent cleanup also preserves recent canceled/revoked/consumed timestamps despite old expiry.
The combined 67-test selection passes 396 assertions; see
`evidence/2026-10-04-expired-continuity-revocation-retention-6F9A.md` for scope and unverified races.

Expiry revocation now has actor-specific before/at/after tests on APP, COM and ORG. The combined
root-login, token lifecycle, continuity, credential transition, retention and TOTP registration
selection passes 132 tests / 956 assertions (seed 1517). Browser logout, independent-connection
races and the remaining full ledger are still unverified or incomplete.

Independent committed-row tests now prove competing Auth continuity revocations on APP/COM/ORG.
Distinct PostgreSQL backend IDs are asserted; only one transition succeeds, the other refuses
terminal state, and subsequent authentication evidence is rejected. Three tests pass 21 assertions.
This closes only that model-owned race, not Base completion/logout/cancel/purge or credential races.
See `evidence/2026-10-04-auth-continuity-revocation-races-2N7C.md`.

APP purge-versus-revocation now has an independent-connection regression, and a controlled failure
after continuity deletion proves cohort rollback followed by successful cleanup retry. The combined
selection passes 11 tests / 76 assertions (seed 22536). This does not prove every scheduling order.

Base finalization now has controlled statement-failure coverage after each of its three ticket
writes: token freshness, parent consumption, and Auth completion. Every case rolls back all three
and accepts the same result on retry while preserving the authentication event time. The five-test
selection passes 54 assertions (seed 59483); see
`evidence/2026-10-04-base-step-up-finalization-write-faults-8W3N.md`. Actual connection/commit faults,
Base completion races, and the full remaining ledger are still open.

APP Base finalization versus token logout now has a committed-row race using two asserted-distinct
writer connections. Both possible outcomes leave a revoked token without freshness and reject the
same result retry. Deterministic operation cases fix both logout orderings and both cancellation
orderings; cancellation preserves the root session and refuses to rewrite already consumed
authority. The combined selection passes 14 tests / 131 assertions (seed 26753). Evidence and
the remaining surface, HTTP, scheduling and commit-fault limits are recorded in
`evidence/2026-10-04-base-finalization-logout-cancellation-4L7R.md`.

CredentialSecurityTransition now has APP/COM/ORG regressions for invocation inside a read-only
ticket connection context. SQL notifications prove that revocation-target enumeration and locks
use the writer, while preserving the current session and revoking another. The current principal
writer boundary already supplies this behavior; no application correction was needed. Six tests
pass 57 assertions (seed 6845). Physical replica lag and purpose-scoped management admission remain
unverified or incomplete; see `evidence/2026-10-04-credential-transition-writer-enumeration-9S4K.md`.

Email OTP verification now has separate committed-row APP and COM races. Two asserted-distinct
writer connections submit the same server-side generation; one succeeds and one refuses without
adding a failed attempt or issuing Base freshness. Replay preserves the original event and failure
count. The combined concurrency and Email verification selection passes 9 tests / 89 assertions
(seed 38706). This isolates verification from delivery and Base completion; the remaining race,
dependency and HTTP limits are recorded in
`evidence/2026-10-04-step-up-email-verification-races-6E8B.md`.

The unused APP/COM/ORG Auth verification BaseControllers are now removed. No current leaf or route
references these classes; canonical verification controllers already inherit the surface base and
use scoped admission. Their three sensitive-skip allowlist entries were removed with the code.
Security guards, admission boundaries and TOTP HTTP registration pass 41 tests / 402 assertions
(seed 65169). Remaining legacy concerns and tests require separate coverage migration; this is
not retirement of all primary challenge paths or completion of Auth credential management.
See `evidence/2026-10-04-legacy-auth-verification-base-retirement-3V9D.md`.

Four unused legacy action concerns are retired with their obsolete harness/seam references:
Cookie Email OTP redelivery, legacy entry, Passkey actions and TOTP actions. Replacement HTTP
coverage refuses missing admission on APP/COM/ORG and verifies APP Turnstile/malformed-TOTP
failure without consumption or authority. Admission plus remaining seams, security guards,
cryptographic verifier operations and Email issuance pass 30 tests / 279 assertions (seed 27253).
The public admission tests create token records directly and are not genuine-login evidence.
Remaining concerns, primary challenge storage and credential-management workflows are still open;
see `evidence/2026-10-04-legacy-verification-actions-retirement-7A2F.md`.

The unused shared Cookie Email OTP support and its COM inclusion harness are retired. The current
method policy now evaluates verified email lockout/discard state on the writer, while configured
methods and bootstrap history remain distinct. APP/COM microsecond boundaries prove that lockout
expires at equality; a locked registered email cannot activate bootstrap. Resend throttling stays
with the issuer so existing codes remain selectable. The combined policy/availability/admission/
verifier selection passes 34 tests / 207 assertions (seed 62361), with clean RuboCop and diff checks.
Remaining surface concerns and credential-management workflows are not closed; see
`evidence/2026-10-04-email-otp-availability-cookie-retirement-5C8M.md`.

APP/COM legacy verification surface concerns now have no definitions or remaining callers. Their
Cookie OTP, parameter restoration, old recovery redirects and COM prepend behavior are retired;
the obsolete APP private/inclusion harnesses were removed. The resend interval assertion now
targets the current issuer. Canonical admission, OTP state/verification, availability boundaries
and security guards pass 54 tests / 285 assertions (seed 63825), with clean lint and diff checks.
ORG's old inclusion file also tests the separate VerificationOperator contract, so whole-file
deletion would lose unrelated coverage. Its retirement requires preserving or migrating those
tests. See `evidence/2026-10-04-app-com-legacy-verification-surface-retirement-8B6Q.md`.

ORG's unused surface verification concern and inclusion-only test class are now retired. The
separate VerificationOperator tests retain their existing bodies and harness in the same file.
That selection plus canonical admission passes 18 tests / 152 assertions (seed 7194). The retained
private-method harness still needs public-boundary migration and is not ceremony/login evidence;
see `evidence/2026-10-04-org-legacy-verification-concern-retirement-2G5N.md`.

Unused SignVerificationTiming and SignVerificationCommonBase are retired. The divergent GET/POST
freshness shortcut and reflective Auth token lookup no longer exist in those concerns. Remaining
seams, admission and Base finalization pass 19 tests / 231 assertions (seed 3671); see
`evidence/2026-10-04-legacy-step-up-timing-retirement-4H8P.md`. Full protected-operation coverage and
the remaining legacy/management migration are still open.

Unused old cancellation and audit concerns are retired with their seam entries. Canonical
admission, Base finalization/cancellation ordering and TOTP HTTP registration pass 25 tests /
354 assertions (seed 33321); see
`evidence/2026-10-04-legacy-cancellation-audit-retirement-9D3J.md`. This does not close all audit,
legacy lifecycle or credential-management requirements.

Unused Passkey/TOTP verification-check concerns are retired with their seam entries. Current
admission and DB-bound cryptographic verifier operations pass 17 tests / 176 assertions (seed
16530); see `evidence/2026-10-04-legacy-step-up-verifier-retirement-6K2T.md`. Primary challenge,
management and remaining legacy lifecycle migration are still open.

Unused old step-up lifecycle and session-store concerns are retired with the lifecycle seam entry.
Canonical admission, Base finalization and independent writer races pass 26 tests / 302 assertions
(seed 6844); see `evidence/2026-10-04-legacy-step-up-lifecycle-retirement-1R7C.md`. Remaining legacy
grant/result primitives, primary challenge storage and management workflows are still incomplete.

The unused cooldown stamp/cache-value modules are retired. Availability tests keep their real
credential assertions; no-op calls and obsolete cache-contract assertions are removed. Stored
Email lockout and DB-backed resend issuance remain authoritative. The selected availability,
boundary and issuer checks pass 24 tests / 62 assertions (seed 41481); see
`evidence/2026-10-04-noop-step-up-cooldown-retirement-3F9S.md`. Full-ledger work remains incomplete.

VerificationBase's unused reflective method-policy and latest-pending transaction fallback are
retired. Base discovers surface-supported methods; canonical Auth intersects its exact admitted
transaction methods separately. Retained Operator verification, canonical admission and Base
admission checks pass 21 tests / 165 assertions (seed 40776); see
`evidence/2026-10-04-latest-pending-step-up-fallback-retirement-7N4D.md`. Legacy grant/result
primitive retirement and full protected-operation/management gates remain incomplete.

The assurance-floor hypothesis was disproved at the transaction boundary: AAL1 evidence cannot
verify a Base AAL2 permission, and no opaque result can be issued for that pending transaction.
The added regression uses public cancellation/admission/model/result APIs; no production change
was needed. The finalization selection passes 10 tests / 98 assertions (seed 38741); see
`evidence/2026-10-04-step-up-assurance-floor-refusal-5P8A.md`. This does not establish real AAL2
authentication or close the remaining ledger.
# Decision-clock correction (2026-10-04)

Base finalization now evaluates token usability with the locked writer decision time; StepUpResolver uses its supplied decision time. Actual-token boundary tests reproduced acceptance at/after expiry under clock disagreement and now pass. Evidence: `evidence/2026-10-04-step-up-decision-clock-6T2M.md`. Broader checks exposed five obsolete ORG Emergency tests; migrate their grant/root-login assumptions and old committer interface while preserving Emergency refusal coverage. The full plan remains incomplete.

## ORG Passkey and Emergency contract migration (2026-10-04)

Migrated the obsolete Emergency tests to Base admission and opaque result interfaces. Real ORG signature tests exposed shared assumptions about credential public IDs and expiry columns; use the existing operator external ID and active status while retaining APP/COM expiry checks. Auth options, verification and result form generation now pass without Auth root cookies. Base operation tests verify finalization, retry, replay and credential revocation. The combined gate passes 53 tests/435 assertions. Evidence: `evidence/2026-10-04-org-passkey-emergency-boundary-8J5R.md`. An independent ORG root-login-to-protected-operation journey, remaining registration/credential-management work and the full plan gates remain outstanding.

## Three-surface logout/finalization race (2026-10-04)

Extended the real independent-writer logout/finalization race to COM and ORG, retaining actor-specific models and credential references. All three require revoked tokens, cleared freshness and rejection of result reuse regardless of the winning transaction. COM uses a verified contact rather than bypassing credential prerequisites. The concurrency file passes 9 tests/99 assertions. Evidence: `evidence/2026-10-04-three-surface-finalization-logout-race-4C9Q.md`. Concurrent cancellation, credential revocation, account switching, last-method deletion and additional fault boundaries remain separate requirements.

## Cancellation serialization and writer clock (2026-10-04)

Added APP/COM/ORG independent-writer cancellation/finalization races. A consumed result refuses cancellation; a canceled parent refuses finalization and retains no freshness. Root login is preserved. Actual token deadline tests exposed cancellation using the application clock; usability now uses the locked parent writer decision time. Related 48 tests/462 assertions pass. Evidence: `evidence/2026-10-04-step-up-cancellation-race-clock-9M4B.md`. Credential revocation, account switching, last-method deletion, registration completion and other fault scenarios remain outstanding.

## Independent session-revocation flags (2026-10-04)

CredentialSecurityTransition previously revoked noncurrent tokens even when `revoke_other_sessions` was false. Corrected the selection and count without replacing its freshness invalidation path. All four flag combinations are covered on APP/COM/ORG; related transition/concurrency checks pass 30 tests/262 assertions. Evidence: `evidence/2026-10-04-credential-transition-revocation-flags-7V2D.md`. Existing Passkey controllers still require an atomic actor-owned removal boundary, preserved deletion history and admitted credential-management context; those are not solved by this correction.

## Credential transition current-session binding (2026-10-04)

CredentialSecurityTransition now rejects supplied current-session tokens from another actor or token surface before state changes. Exact identity includes the token model, while nil references retain the explicit other-session policy. APP/COM/ORG negative and nil cases plus existing concurrency checks pass 39 tests/306 assertions. Evidence: `evidence/2026-10-04-credential-transition-session-binding-2A6F.md`. This service correction does not complete admitted credential-management or removal work.

## Credential revocation/finalization race (2026-10-04)

Added three-surface independent-writer races for credential status revocation under actor/credential locks followed by CredentialSecurityTransition. Finalization-first and revocation-first outcomes both leave no usable freshness or reusable result, while the explicit policy retains the current root session. Retained revoked credentials do not qualify for bootstrap. Combined checks pass 42 tests/361 assertions. Evidence: `evidence/2026-10-04-credential-revocation-finalization-race-6R8W.md`. This tests the explicit public transition sequence; wiring every credential-management controller, atomic last-method deletion and deletion-history retention remain outstanding.

## Scope path segment boundaries (2026-10-04)

Existing catalog roots accepted adjacent paths such as `/settings/passkeys-extra`. Added explicit segment boundaries while preserving existing root/query/child matches. Base issuer negative tests on all three surfaces reject adjacent and invalid-type/empty/NUL targets without creating authority. Related 35 tests/929 assertions pass. Evidence: `evidence/2026-10-04-step-up-scope-path-boundaries-3H7N.md`. This correction does not replace the remaining full protected-route inventory or credential-management work.

## ORG Support mutation through opaque step-up (2026-10-04)

Migrated the administrative Support revocation success case to Base confirmation POST, opaque admission/result, separate Auth cookie jar, actual WebAuthn signature verification and Base completion before the protected POST/audit. A later capability revocation refuses another mutation despite retained freshness. The selected integration case passes 33 assertions. Evidence: `evidence/2026-10-04-org-support-opaque-step-up-mutation-5S9K.md`. Initial Base login is a fixture, Turnstile is stubbed and Jump is decoded rather than browser-executed; this does not establish ORG root login. Five other legacy cases in the same file still need migration.

## ORG administrative negative-contract migration (2026-10-04)

Completed all remaining cases in `org_admin_step_up_ceremony_test.rb`: different scope, Emergency refusal, foreign session/surface opaque results, transport retry without renewed freshness, exact microsecond freshness expiry, and forged/mixed return targets on GET/POST. Removed legacy JWT issuer and artificial Auth login/completion helper calls from that file while retaining its mutation/audit success case. The entire file passes 9 tests/96 assertions. Evidence: `evidence/2026-10-04-org-admin-canonical-negative-cases-4F8P.md`. This supersedes the earlier note that five cases in this file were awaiting migration; other files and full root-login/credential-management requirements remain outstanding.

## ORG administrative canonical CSRF checks (2026-10-04)

Migrated `org_admin_csrf_test.rb` from legacy grants/results and the test-session header to existing Base access-cookie authentication and canonical DB authority. Synthetic evidence is finalized through the public Base operation so the tests isolate real mutation CSRF. Support, IAM and enforcement rejection cases now assert 422 plus no mutation; same-origin and genuine-token success remain covered. Combined administrative ceremony/CSRF gate passes 11 tests/167 assertions. Evidence: `evidence/2026-10-04-org-admin-canonical-csrf-8D3L.md`. Root login, browsers and additional administrative operations remain separate requirements.

## ORG Normal root login and subsequent step-up (2026-10-04)

Added an independent integration journey from Base local sign-in admission through the real Entra strategy with token/JWKS HTTP adapters, actual ID-token signature and Passkey verification, and Base-only Normal root issuance. The same newly issued cookie completes another Passkey step-up and opens the protected birthdate page. No fixture root login or Auth root credential is injected. Completion retry preserves the root anchor and count; logged-in sign-in is refused. Related ORG gate passes 23 tests/299 assertions. Evidence: `evidence/2026-10-04-org-normal-root-and-step-up-5W8N.md`. Provider responses and Turnstile are stubbed; browsers and live Entra remain unverified. Registration/management and other full-plan items remain outstanding.

## APP Passkey controller migration and malformed signature (2026-10-04)

Migrated all six APP verification Passkey controller cases to admitted DB authority, existing panel/options and real assertions, removing local test-only Auth login and legacy grant helpers. An actual malformed signature exposed an unhandled OpenSSL PKeyError; the shared verifier now raises its explicit verification failure for that exception. The HTTP failure burns the challenge, replay is refused and Base freshness stays absent. Related gate passes 25 tests/196 assertions. Evidence: `evidence/2026-10-04-passkey-malformed-signature-2P7J.md`. Other legacy tests, registration/management and the full R01–R16 acceptance gates remain outstanding.

## COM contact lifecycle, history and exact expiry (2026-10-04)

Migrated COM Passkey controller tests to canonical admission/real signatures, fixed missing COM panel translations in the four existing bundles and exercised both regions/languages. Corrected deadline-equality acceptance in both remaining Cookie ChallengeStore APIs; their DB retirement is still required. Connected COM email confirmation to freshness/unfinished-ceremony invalidation while retaining root sessions. Its mutation tests now finalize synthetic evidence through the public Base operation instead of direct AAL2/token or verification-cookie injection. A revoked-history HTTP case exposed a shared bootstrap guard that checked only configured methods; it now also requires the existing writer history predicate. True initial contact remains permitted, verified Email ends the exception, and revoked history is refused. Related final gates pass 70 tests/368 assertions and 41 tests/355 assertions (overlapping). Evidence: `evidence/2026-10-04-com-contact-bootstrap-and-expiry-7K2R.md`. These changes do not finish admitted credential management, atomic removal, Passkey candidates or legacy retirement.

## APP contact history refusal (2026-10-04)

Migrated APP contact mutation tests to synthetic evidence finalized by the public Base operation, removing direct AAL2/freshness and legacy verification-cookie/test-header setup. Cookie-authenticated negative requests prove that revoked Passkey, inactive TOTP and revoked TOTP history cannot activate the initial-registration exception. The requests return 422 without email/ticket creation while preserving root sessions. APP/COM registration and bootstrap-issuer gate passes 33 tests/189 assertions. Evidence: `evidence/2026-10-04-app-contact-history-refusal-3J8V.md`. This extends the shared guard correction's HTTP coverage; no additional production change or full-plan completion is claimed.

## Step-up refusal transport and removal constraints (2026-10-04)

The real ORG root/step-up journey exposed a forbidden flash alert on Base verification redirects. Removed that write and the unavailable-method HTML alert shortcut; JSON/plain refusal and the existing verification page remain the feedback boundary. The related gate passes 40 tests/291 assertions; an extended COM revoked-history case confirms a no-write HTML return to Base verification without flash (15 assertions). Evidence: `evidence/2026-10-04-step-up-without-flash-6F9C.md`.

Static inspection for the pending removal slice found that the four Auth Passkey/TOTP destroy actions check inventory before an unlocked physical deletion. Retaining Passkey history alone would exhaust registration slots: AssociatedRecordLimitValidator counts all actor rows, including retained revoked/deleted records. APP/COM already have DELETED/REVOKED states; ORG has ACTIVE/REVOKED only. TOTP already excludes terminal states from its slot count. A coherent removal slice must connect actor-locked inventory/status change and freshness invalidation with insertion-locking and Passkey slot classification, preserving each surface's existing guard policy. It must also connect the purpose-limited Base permission; fixing the lock alone does not complete Auth credential management. No removal or slot behavior was changed in this inspection.

## Passkey registration capacity prerequisite (2026-10-04)

Replaced the three Passkey all-row association validators with writer queries excluding existing terminal states. Every INSERT repeats the four-slot bound under the owner lock, so stale loaded associations and competing writers cannot reserve a fifth slot. Existing uniqueness and COM recovery-contact checks remain. The model/concurrency gate passes 53 tests/319 assertions; root, step-up, TOTP bootstrap and admission coverage passes 18 tests/425 assertions. Evidence: `evidence/2026-10-04-passkey-slot-serialization-4S7K.md`. The old APP reference-deletion test now verifies FK protection instead of assuming an empty database; the ORG bound test uses real rows. No removal behavior changed yet. Actor-locked inventory/status change, invalidation, admitted management and Base Passkey candidates remain required.

## Actor-locked credential removal and retained history (2026-10-04)

The four Auth Passkey/TOTP removal actions now use IdentityCredentialRemovalCommitter with owner/credential/current-session locks, writer usability and binding checks, existing inventory guards and CredentialSecurityTransition. Existing terminal states retain history and free registration capacity; removed entries are excluded from settings lists. Independent APP/COM/ORG Passkey and APP TOTP deletion races preserve one compatible method. Pending ceremonies/freshness are invalidated while roots remain. Separate DBs are not represented as one atomic transaction; invalidation occurs before principal mutation and may conservatively survive a later principal failure. Emergency/missing/foreign bindings and ticket failure are covered. Evidence: `evidence/2026-10-04-credential-removal-serialization-9R2M.md`.

Targeted controller deletion cases pass 9 tests/64 assertions. The full four-file settings gate remains red: 103 tests/400 assertions, 18 legacy TOTP registration failures requiring canonical admission migration. Existing Auth login helpers remain in these files, so their removal successes are caller regression evidence only. Purpose-limited Base credential-change permission and Auth management context are still required; the removal primitive does not establish that boundary. The unrelated Secret redesign's deleted fixture families were not restored.

## TOTP registration test migration and preserved input/miss contracts (2026-10-04)

Replaced the failing legacy TOTP registration cases with inline Base-admission/Auth-continuity/DB-candidate requests. Successful Auth confirmation changes proof only; the public Base finalizer creates the credential once without freshness. Added code-length and malformed-input partitions, cancellation/restart/replay, candidate/deadline preservation, slot limits and correct Turnstile refusal. Removed unused copied enrollment/grant/social helper code. Preserved ASCII-space paste acceptance while retaining six-digit/letter/NUL checks, and restored private management 404 without changing registration 400. Explicit independent test identities avoid retained rows appearing under auto-allocated copied-fixture identities; no retained rows were erased. Evidence: `evidence/2026-10-04-totp-registration-test-migration-8T6Q.md`.

The settings/TOTP aggregate is now green: 122 tests/1,030 assertions, superseding the previous 18 legacy registration failures. Remaining Auth management helpers are still isolated caller evidence, not end-to-end proof. Purpose-limited management, Base Passkey candidate commitment, legacy retirement and full-plan acceptance remain required.

## Expired retained credentials and removal fallback (2026-10-04)

A new exact-expiry regression showed that AuthenticationCredentialInventory counted expired APP/COM Passkeys as available. Its existing credential reads now run on the surface writer with one database-clock decision instant; APP/COM Passkey/Email/Telephone and UV fallback counts require discard_at strictly after that instant. Existing app Secret availability uses the same instant. ORG status-only records retain their current schema semantics. Actual removal refuses an expired Passkey/Email fallback without changing the usable target, freshness or root. Boundary tests cover six credential partitions at writer time minus/equal/plus one microsecond. Evidence: `evidence/2026-10-04-credential-inventory-expiry-7V3A.md` (41 tests/400 assertions and related root/contact/bootstrap gate 48 tests/577 assertions). Temporary credential cooldown classification and purpose-limited management remain separate requirements; this does not complete the full plan.
# Email lock and removal compatibility (2026-10-04)

APP/COM temporarily locked Email remains configured and contactable, but cannot protect removal of the last compatible Passkey. Inventory evaluates the lock against its writer-clock snapshot; equality at the deadline unlocks it, matching the Email issuer/verifier. Public inventory boundary and removal refusal tests passed with the Email and concurrency regressions: 48 tests, 484 assertions. See `evidence/2026-10-04-email-lock-removal-5L8A.md`. This closes this removal predicate only; routine Auth credential-management admission and the remaining integrated plan are unfinished.
# Regular registration permission (2026-10-04)

Base admission issuance now supports the approved registration purpose only for an exact credential scope and method after existing Base step-up evidence is rechecked under writer locks. Registration keeps `required_aal=none` and no phishing-resistance claim; issuance preserves the authentication timestamp. Candidate method is separate from prior authentication method. The seven-file gate passed: 54 tests, 960 assertions, including freshness at one microsecond before/at/after expiry, purpose/session/scope/audience rejection and bootstrap regression. See `evidence/2026-10-04-registration-admission-authority-6A4P.md`. HTTP entry and credential management remain to be connected; this is not an end-to-end registration completion claim.
# Primary Passkey expiry and writer locking (2026-10-04)

The primary shared verifier now rechecks credential ownership/eligibility on the writer under actor then credential locks, verifies and updates the signature counter there, and records Auth evidence within that critical section. APP/COM reject the discard deadline inclusively. A real HTTP admission and WebAuthn regression covers one microsecond before/at/after expiry on both surfaces; no Auth root credentials are supplied or emitted. The relevant six-file gate passed with 46 tests and 688 assertions. See `evidence/2026-10-04-primary-passkey-writer-expiry-3W9C.md`. Independent primary verification/revocation concurrency remains unverified. Cookie challenge retirement requires the new proposal in `plans/analysis/passkey-challenge-db-shape-proposal.md`; no new fields were implemented without approval.
# MFA Passkey validity and legacy test migration (2026-10-04)

APP/COM MFA recheck scoped ownership, actor availability, ACTIVE credential status and discard time on the writer under actor/credential locks. UI options omit expired rows. Existing verifier timestamps supply last use and UV evidence. SQL expiry predicates also fix the primary verifier's handling of PostgreSQL infinity. MFA JSON null/scalar/array/NUL refusals preserve pending flow and absent root authority. The two legacy MFA files now redeem real Base admission and distinguish synthetic verifier branch coverage from the real-signature integration; unused copied authentication helpers were removed. Final gate: 65 tests, 1,098 assertions, all green; evidence is `evidence/2026-10-04-mfa-passkey-validity-2M7F.md`. Cookie challenge retirement, GET-issued MFA challenge replacement and independent primary/MFA races remain open.
# Local authentication evidence phase (2026-10-04)

The local evidence writer accepts only matching PRIMARY_PENDING/MFA_PENDING state and status under its row lock. APP/COM pending-MFA Cookie validation now checks the admitted Base flow's MFA phase and principal. Later-phase or actor-mismatched continuity produces no challenge or evidence. All configured flow phases are tested for all three actor models; the capacity-wait test records its synthetic evidence before advancing rather than introducing evidence after the credential phase. The seven-file gate passed with 50 tests and 1,050 assertions; see `evidence/2026-10-04-local-evidence-phase-8P2D.md`. Further work must still invalidate actor-bound unfinished local login flows during credential security transitions; the existing transition currently enumerates tokens/step-up authority only.
