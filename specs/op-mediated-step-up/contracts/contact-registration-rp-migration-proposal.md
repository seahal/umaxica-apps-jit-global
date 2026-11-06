# RP contact-registration owner boundary proposal

Status: implementation design accepted by the owner on 2026-11-05. Date: 2026-11-04. Scope: APP and
ORG Email and Telephone registration from a Base RP-local session. The current localized 503 remains
until the owner APIs, receipts, recovery and verification gates below are complete. Bootstrap
remains out of scope.

## Observed problem

Base has a verified local RP session and access event, not a `ClientToken` or `OperatorToken`. The
four registration controllers, OTP issuance/verification, form queries and finalizers currently
require that root token. APP email and telephone finalizers consume the OP ceremony in an OP
transaction and only afterwards finalize the Zenith binding. Their Step-Up verification locks
therefore end before Zenith commit
(`app/operations/email_credential_registration_otp_finalizer.rb:29–54,97–140`;
`app/operations/telephone_credential_registration_otp_finalizer.rb:29–52,63–96`). If the Zenith
write fails after OP consumption, a consumed receipt does not prove that source finalization
committed. ORG finalizers place the source commit inside an OP transaction and then write the
consumed state on OP (`app/operations/operator_email_registration_otp_finalizer.rb:26–41,54–75`;
telephone equivalent). These different cross-store outcomes do not establish the read-only OP
transaction and recoverable source outcome required by revision 13 O-10. Opening a transaction or
adding a session lookup around the existing calls does not repair that gap.

## Proposed boundaries

1. Base checks its own authenticated session, CSRF, existing policy and browser-bound admission
   nonce. It forwards only through a mutually authenticated, realm-specific owner API: its
   registered client assertion, the verified access token, a server-generated operation reference
   and the ceremony reference/generation, candidate reference and browser-bound proof. The client
   cannot select an actor, root, grant or other RP session. Exact request encoding, nonce proof and
   limits remain to be specified and accepted; neither OTP nor bearer credentials enter logs.
2. The owner verifies issuer, audience, client, subject, `sid`, event and realm, resolves the actor
   and OP grant/root from that authenticated evidence, and resolves the OTP ceremony and candidate
   from owner records. It rechecks actual relationships, nonce, purpose, generation, candidate,
   verification result, current contact policy, rate limits, expiry and actor status; untrusted
   references are selectors only. On missing, stale, cross-actor, cross-realm, replayed, mismatched
   or unavailable authority, refuse without a source write. Verification/issuance and delivery
   remain distinct events; preserve code attempt limits, generation supersession and after-commit
   delivery. No bootstrap behavior is enabled by this proposal.
3. A finalization first locks the actor on its Zenith writer. An OP **read-only** transaction then
   locks device → root → grant, and the relevant OTP ceremony in the independently audited
   compatible order. Validate the live Step-Up event and the verified, unconsumed OTP ceremony with
   the OP database clock after lock acquisition. Hold those locks while one Zenith transaction locks
   the candidate and any affected current contact bindings, applies the authorized
   replacement/finalization and writes source audit plus the durable committed-operation fact. The
   Step-Up verifier cannot commit or mutate the OTP. No external HTTP, email or SMS call is made
   under either database lock.
4. The unique durable operation fact is the source authority for whether this OTP ceremony has
   caused a source change. A uniqueness constraint on realm plus the owner-generated OTP ceremony
   reference prevents the same ceremony being used twice, including different browser operation
   references or OTP generations. Retrying the same request must also match actor, candidate,
   operation kind, session/grant and accepted OTP generation; a different tuple is refused. The fact
   and all binding/audit writes commit atomically. A source rollback leaves no fact and no source
   effect; no OP consumption is inferred. Expiration and revocation before the protected commit
   refuse. The complete reverse-lock graph, including contact-binding callbacks, must be established
   before implementing this order.
5. If the Zenith COMMIT acknowledgement is lost, discard the suspect connection and resolve using
   the unique operation fact from a fresh writer connection. Return the recorded result only when an
   exact matching committed fact is found; a conflicting fact is a refusal. If the writer cannot
   establish the outcome, return an indeterminate/unavailable result and do not repeat a
   non-idempotent source mutation. If Zenith commits but releasing the read-only OP transaction
   fails, close that OP connection and report the confirmed source result with a secret-free
   diagnostic. Only after the confirmed source outcome may a separate OP transaction mark the
   ceremony consumed or enqueue its cleanup. Failure or lost acknowledgement of this post-commit
   work must not make a committed source operation appear uncommitted; replay reads the source fact
   and reconciles the same ceremony idempotently. Source-fact retention must outlive ceremony retry
   and recovery windows.

The existing Email and Telephone OTP concerns generate `otp_generation` as a UUID string and persist
a verified receipt; `email_otp_verified_evidence?` and `telephone_otp_verified_evidence?` bind their
evidence to code, purpose, actor, session, operation and candidate. Those predicates are necessary
but do not themselves establish the proposed cross-store source commit or a complete caller
inventory. This is a proposed resolution, not proof that the existing OTP states expose every
required predicate. In particular, establish whether a verified OTP result is durable and bound to
the same actor, browser nonce and generation, whether its code attempts can race a resend, and
whether every contact-binding callback can execute while the actor and OP evidence locks are held.
Where an OP-side mutable consumption reservation is necessary, specify its separate transaction,
crash recovery and relationship to the source fact; it cannot silently mutate the read-only O-10
transaction. A source-only uniqueness fact is insufficient if another existing caller can bypass it,
so inventory and migrate every writer before activation.

## Shape proposal for review

Before: OP ceremony and Zenith contact/audit exist; there is no demonstrated authoritative,
operation-specific cross-store completion fact for these four workflows. Existing OP `consumed` is
not evidence that the Zenith transaction committed.

After (candidate, illustrative relational shape):

```text
contact_registration_commits:
  ceremony_ref: string NOT NULL       # owner-generated OP reference; unique with realm
  realm: enum NOT NULL                # app or org; fixed by owner endpoint
  actor_ref: string NOT NULL          # canonical owner public reference
  candidate_ref: string NOT NULL      # owner contact public reference
  kind: enum NOT NULL                 # email or telephone
  generation: string NOT NULL         # OP-verified OTP generation UUID snapshot
  grant_ref: string NOT NULL          # OP grant sid observed at commit
  rp_session_ref: string NOT NULL     # originating RP-local session reference
  operation_ref: string NOT NULL      # server-generated correlation, not authority
  committed_at: timestamp NOT NULL    # source writer commit event time
```

Uniqueness: `(realm, ceremony_ref)` identifies a one-time source effect; an independent unique
operation reference may be required for recovery, with realm namespace and exact tuple comparisons.
`kind` and `realm` are separate axes, not combined enums. The tuple is a historical snapshot needed
for conflict and lost-acknowledgement checks, not an identity lookup authority. The actual source
model owner, source audit relationship, allowed result semantics, NOT NULL constraints, storage
minimization, indexes, retention and recovery policy require review. The RP-to-owner request and
response shapes require their own Before/After samples and authority mapping. New source storage and
any API/migration changes need the explicit shape approval required by
`generic/data-shape-design.mdc`; any bulk or irreversible migration also needs the applicable
recovery-plan approval. No backfill is presumed.

## Required verification before lifting 503

- Both realms and both contact types: legitimate first issuance, resend, OTP verification and
  finalization; source policy, existing authorization, delivery and audit are preserved.
- Wrong actor, realm, client, session, browser, candidate, ceremony, generation, code, event and
  purpose; missing, expired, replayed and superseded input; no source mutation or sensitive logging.
- Independent connections: Step-Up revocation wins versus source commit wins; actor disablement,
  ceremony expiry or resend while waiting; two concurrent finalizations of one ceremony; verify lock
  and commit ordering rather than only response status.
- Source rollback, duplicate identical retry, conflicting retry, source COMMIT lost acknowledgement,
  OP read-only transaction close failure, post-commit OP cleanup failure/lost acknowledgement, and
  unavailable writer during recovery. Assert the exact source fact, audit and user-visible outcome.
- Test delivery outside locks, OTP attempt/rate limits, browser CSRF and return navigation, actual
  client assertion and surface isolation. Test the pre-existing bootstrap path separately; it
  remains excluded here.
- Prove no legacy caller can finalize a contact without the source uniqueness fact and required live
  evidence, and audit the complete reverse-lock inventory before changing the refusal.

## Concrete shape and authorization gate (working draft)

The existing API shape for these four owner workflows is **none**: Base controllers invoke internal
Ruby operations directly with a root-token object. The existing
`EmailCredentialRegistrationOtpIssuer.call` receives
`{actor, token, email, browser_nonce, bootstrap_transaction}`; the verification committer receives
`{actor, token, email, transaction, browser_nonce, code}`. Telephone and ORG use their corresponding
model types. These are in-process Ruby arguments, not remotely authenticated contracts. The RP
currently returns 503 before invoking these workflows.

A candidate owner interface needs distinct issue, resend, verify and finalize operations, with no
batch request and no client-selected actor or root. The following are **proposed wire examples**,
not established endpoints; placeholders represent opaque values and not literal credentials:

```json
{"candidate_ref":"<owner-contact-ref>","browser_proof":"<browser-bound-proof>","operation_ref":"<rp-operation-ref>"}
{"ceremony_ref":"<op-ceremony-ref>","candidate_ref":"<owner-contact-ref>","browser_proof":"<browser-bound-proof>","code":"<submitted-otp>","operation_ref":"<rp-operation-ref>"}
{"ceremony_ref":"<op-ceremony-ref>","candidate_ref":"<owner-contact-ref>","browser_proof":"<browser-bound-proof>","code":"<submitted-otp>","operation_ref":"<rp-operation-ref>"}
```

The first example is issuance; resend has the same shape plus `ceremony_ref`; the second is OTP
verification; the third is finalization. A finalization receives the OTP again because the existing
verified-receipt predicates require the code. A response shape would distinguish the action being
called and return a fixed outcome, for example
`{"outcome":"issued","ceremony_ref":"<op-ceremony-ref>"}`, `{"outcome":"verified"}`,
`{"outcome":"committed"}`, or `{"outcome":"unavailable"}`. These are examples of mutually exclusive
operation results, not persisted lifecycle states. OTP values, browser proof, access tokens and
client assertions are secrets and must not be included in responses, URLs, logs, audit records or
error bodies. Delivery stays with the owner-controlled delivery path; a code is never returned to
the Base RP. Prove this is compatible with current mail/SMS delivery and retry before implementing
it.

Each operation must authenticate its expected Base RP client assertion and the bearer event; `realm`
and channel are fixed by the route and owner and cannot be selected by request body. Actor, grant,
root and device come from the verified subject and grant binding. `candidate_ref` and `ceremony_ref`
are untrusted lookup keys, checked against those owner records. `browser_proof` must be derived from
the authenticated Base session plus a session-bound browser secret; the exact protocol for the owner
to authenticate that binding has **not** been established. The operation reference is a
server-generated idempotency selector, not proof or authority. OTP verification and finalization
must match the owner-recorded current generation; any generation included in a request is an
untrusted comparison, not a way to choose an earlier receipt.

The proposal's source receipt is inserted **only in the same Zenith transaction as the completed
binding and source audit**. No row means no committed receipt; it does not mean an attempted source
COMMIT definitely failed when acknowledgement was lost. `realm` is encoded by the database/table
owner if APP and ORG use separate tables rather than persisted redundantly; the decision must be
consistent across schema, uniqueness and recovery queries. `kind` (`email` or `telephone`) is an
independent enum; a committed fact has no pending/failed boolean or nullable completion state.
`ceremony_ref` uniqueness is database-wide within a realm and covers both kinds; `operation_ref`
must also be unique within that realm, with exact actor/candidate/kind/generation/grant/session
matching before replay. The grant and RP-session values are historical snapshots, never current
authority. The source database clock supplies `committed_at`; the OP database clock supplies
ceremony/evidence expiry decisions. A response must distinguish confirmed commit, definite denial
and unavailable/indeterminate results without inferring success from OP consumption.

Migration is additive: one receipt table in each realm's Zenith database, NOT NULL values and unique
constraints, no backfill of historical consumed ceremonies, no rewrite of existing records, and no
change to the already persisted OTP ceremony fields or their existing consumers until all four paths
have been migrated. Previously issued in-flight ceremonies need an explicit expiry or transition
decision; do not silently treat them as having a source receipt. Existing clients receive the same
interim 503 until the owner endpoints, delivery, replay recovery, authorization and tests are
complete. Rollback must preserve any committed receipt and audit fact; a migration rollback that
drops such data is not an acceptable recovery procedure.

This remains a review proposal, not permission to publish these wire shapes or write new persistent
formats. The 15:00 owner instruction approves revision 13 implementation but does not specify these
new Before/After shapes, particularly the browser-proof protocol and cross-store result semantics.
The `generic/data-shape-design.mdc` review gate requires an explicit approval of the concrete shape
before implementation. The exact endpoint design also depends on proving the current RP can supply
an authenticated browser/session binding to the owner without weakening CSRF or surface isolation.
