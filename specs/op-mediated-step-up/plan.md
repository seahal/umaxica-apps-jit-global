# Plan: OP-mediated step-up (revision 3)

Status: accepted (owner, 2026-11-03) with `spec.md`. Implementation starts only from an
owner-approved instruction file. No unit authorizes an external or production action.

## Design in one view

1. A protected action's controller declares step-up. A shared RP verifier checks the exact class,
   the event time against the fixed deadline, and the live session, Identity and audience. Failure
   answers 401 with an RFC 9470 challenge.
2. The front end recognizes the challenge and offers an explicit entry. A CSRF-protected RP action
   starts the ceremony: it records a server-selected initiating context (the exact current RP
   session, Identity and the intended existing grant), validates a same-RP return target, and sends
   an OIDC authorization request to Visa with PKCE (S256), `state`, `nonce`, `prompt=login` and one
   canonical essential request (`acr` of the class, `auth_time`).
3. Visa validates the request, delegates the ceremony to Auth through the existing temporary
   admission, accepts only evidence allowed for the owner's current Security Mode, and in a
   purpose-bound completion updates the event of the exact initiating grant as one snapshot,
   consumes the code once, rotates the refresh token and issues the tokens. The OP commit is the
   point of no return.
4. The RP verifies the response, checks the initiating context again, and installs the credentials
   through a purpose-specific installer ordered with refresh and logout, preserving the DBSC
   binding.
5. Refresh keeps describing the same event; it cannot create or extend one.
6. Each outcome (refusal, commit, delivery, installation, cancellation, expiry) writes a durable
   Chronicle fact.

## Units (in order)

The OP and RP slices share one contract and form a single non-activatable change: nothing is
advertised or declared until the chain works. Activation is unit 7.

0. Contract, inventory and drafts (documents only; no behavior change)
   - Consumer inventory of the shared Base-mediated classes across Base app, Base org, bootstrap,
     registration, full reauthentication and the emergency and Secret refusals: what is replaced,
     what is retained and why.
   - Outcome table (RV-71): for every boundary (protected resource, start action, authorization
     response, callback, token exchange, installer) the response category and status for resource
     challenge, missing login, authorization denial, invalid provenance or CSRF, invalid callback,
     code or binding, terminal ceremony conflict and dependency failure. Preserve the existing
     distinct missing-login branches (`browser_rp_authentication.rb:414-433`) and never turn a CSRF,
     issuer, PKCE or proof-binding error into an instruction to resume that transaction.
   - Audit semantics (RV-72): one authoritative fact per issuance, installation or terminal
     transition, kept apart from a rejected-attempt observation; recording or deduplication,
     correlation and persistence-failure policy for rejected attempts; unknown delivery recorded as
     observed uncertainty.
   - Response ordering (RV-74): causal ordering by initiating installation generation or
     transaction, with the rotated-credential accounting, including how a late response is treated.
   - Contract document under `specs/op-mediated-step-up/contracts/`: the exact class string, the
     canonical essential request and the combined-form, unsupported and malformed behavior; the
     challenge parameters and the front-end handler; the skew rule (none); before/after request,
     persisted transaction, completion and audit shapes under `generic/data-shape-design.mdc` (NOT
     NULL, no meaning for NULL); the initiating-context carrier; the snapshot and installation
     ordering; the audit events and failure behavior; value-object placement
     (`project/value-object-boundaries.mdc`) and identifier classes (`project/identifiers.mdc`); the
     state-machine writer and diagrams.
   - Draft the ADR amendments (D3 and path C reversals, E2 amendment, D2 maxima) for the owner.
   - Record a narrow failing test baseline, separating assertion failures, fixture errors and
     tooling failures. Fixing the test-residue source is a separate task and not a gate here.
   - Verification: Codex review of the contract; owner acceptance of the spec and ADR amendments.

1. Persistence (additive migrations only, after unit 0 is accepted)
   - Add the request, initiating-context and audit columns or tables from the contract; no
     destructive or irreversible step, no backfill authorized.
   - Verification: run the migration and schema dump and record evidence; model and constraint tests
     at the public boundary.

2. Chronicle prerequisites and audit writers
   - Fix the missing retention policy rows
     (`plans/backlog/2026-11-03-chronicle-retention-policy-reference-rows.md`) and implement the
     durable facts and the audit-failure behavior before any new writer is activated.
   - Verification: forced-failure and duplicate tests for each outcome (AC-15).

3. OP side
   - Request parsing and validation (`claims`, `acr_values`, combined forms, errors, no premature
     Discovery); Auth method enforcement and evidence acceptance (AC-16); the purpose-bound
     completion with the snapshot, locking, rotation and exact class preservation, in both Visa app
     and Visa org (a required parity check: both allowlists omit `claims` and `acr_values` today);
     state-machine writer for the ceremony (AC-21).
   - Verification: authorize and token-exchange tests (success, replay, stale, duplicate, cancelled,
     conflicting), exact-case class, refresh after the deadline, concurrent refresh and logout, a
     lost response after commit, DBSC proof cases (AC-22).

4. RP side (Base app and Base org)
   - Shared verifier; start action; initiating-context binding and second verification; installer
     ordered with refresh and logout; DBSC continuity.
   - Verification: public tests of the deadline instants, cross-session and cross-RP isolation,
     malformed and future event times, both installation orderings, wrong-session negatives.

5. Challenge and front end
   - RFC 9470 401 challenge replacing the current plain 401, JSON 422 and GET redirect of the
     step-up gate; one shared handler distinct from sign-out recovery; the HTML entry; locale keys;
     audit of every consumer that treats 401 or 302 as reload (for example the passkey ceremony
     controller); the front-end build.
   - Verification: request tests for the challenge shape and refusal cases, Vitest tests for the
     handler, a test that the mutation is not replayed, the i18n checks, the real build run.

6. Migration of callers (about thirty final writers and gates, `contracts/consumer-inventory.md`
   section 3)
   - Declare step-up in the inventoried controllers of Base app and Base org; delete only what the
     inventory shows to be without a retained consumer; passkey deletion with any allowed method
     plus the no-lockout check. Existing step-up tests are migrated or removed with a stated reason.
   - Verification: regression tests for each retained flow, and a search showing no other writer of
     the event for the two surfaces.

7. Activation and closure
   - Enable Discovery metadata for the enabled realms, update the current diagrams and inventories
     with the delivered behavior, run the wider authentication boundary and a full run, write
     evidence with the commit hash and the dirty-worktree note, promote lasting behavior to
     `docs/checklists/` and `docs/`, and list unverified acceptance explicitly (`specs/README.md`).

## Dependencies

0 precedes everything and ends with owner acceptance. 1 needs 0. 2 needs 1. 3 and 4 need 1 and 2 and
share the contract; 5 needs 4; 6 needs 3 to 5; 7 is last. Units 3 and 4 touch refresh and logout
ordering and should not run in parallel with other work on those files.

## Not decided here

The window-closing mechanism; other RPs; a Security Mode change inside the window; real browser DBSC
behavior (unverified).
