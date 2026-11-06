# Implementation instruction: OP-mediated step-up (for Codex)

Status: approved by the owner on 2026-11-03 (recorded in `zero.md`). Codex may start with unit 0.
Author: Claude Code, 2026-11-03. Claude Code does not implement this change; Codex does.

## 1. Authority and inputs

- Accepted spec: `specs/op-mediated-step-up/spec.md` (accepted 2026-11-03, AC-1 to AC-22) and
  `plan.md`.
- Contract: `contracts/contract-draft.md` (revision 12, including the owner-accepted retention
  amendment, code vocabularies, `security` retention, the attempt-rejected rule, the attribution
  union and the Auth and Base split recorded in `zero.md`) is normative for shapes, outcomes,
  states, audit, routes.
- Inventory: `contracts/consumer-inventory.md` (revision 3) is the list of consumers to migrate or
  keep.
- ADR amendments applied on 2026-11-03 to
  `adr/op-auth-rp-authentication-responsibility-separation.md`,
  `adr/authentication-security-cycle-consolidation-2026-10-15.md`,
  `adr/authentication-security-mode.md`, `adr/step-up-authentication-redesign.md`.
- Reviews `review-1.md` to `review-8.md` explain the reasons; they are not additional requirements.
- When the contract and the code disagree, follow `AGENTS.md`: report the discrepancy in `zero.md`;
  do not choose silently. When a contract item cannot be implemented as written, stop that item and
  report; do not invent a substitute.

## 2. Rules for this work

- Read `AGENTS.md` and load the rules its Task Rule Index selects for each unit (controllers,
  routing, migrations, data shape, identifiers, value objects, lifecycle transition writers,
  testing, no-test-only-code, no silent fallback, fail fast, no compatibility layer, authentication
  boundaries, i18n, logging boundary, state machines and `docs/mermaid`).
- Preserve unrelated staged, unstaged and untracked work. Do not commit, push, stash or reset unless
  the owner asks.
- Migrations are additive only. No destructive or irreversible persistence operation, no backfill,
  no column or table drop, no data rewrite. The old `last_step_up_*` columns and old ceremony tables
  stay.
- No feature flag, no compatibility layer, no second runtime evidence authority. The units are local
  development slices of one change; nothing is activated before unit 7.
- No external or production action.
- Tests: public boundaries only; no skipped, placeholder or behavior-mocking tests; boundary values
  for every limit (300 seconds, 60 seconds, 15 minutes); missing, empty and malformed inputs. Run
  the narrowest tests first. Record a narrow failing baseline before unit 1 and classify
  pre-existing failures; do not fix unrelated failures.
- Record progress and results in `zero.md` after each unit (append-only, header format), with
  commands, counts and anything not verified. Write one evidence record in `evidence/` at the end
  (`AGENTS.md` "Evidence").

## 3. Units

Each unit ends with its own verification and a `zero.md` entry. Units 3 and 4 touch refresh and
logout ordering; do not run them in parallel with other work on those files.

0. Baseline. Run the existing tests of the affected areas (token exchange, refresh committer,
   refresh and logout concurrency, RP callback committer, step-up response shape, freshness E3,
   Chronicle record policy, the files of inventory families F1 to F4) and record the failing set
   before any change.
1. Persistence (contract section 7 and 8). Additive migrations per realm and cell: OP step-up
   contexts with states, transitions and commit facts; RP step-up states with statuses and
   transitions; the three audit outboxes with their attempt tables; reference rows inserted by the
   migrations. Constraints as written (NOT NULL, uniqueness, partial unique indexes, check on the
   class value). Run the migrations and the schema dump and record them; model and constraint tests
   at the public boundary.
2. Chronicle prerequisites and audit. Add the missing retention policy rows
   (`plans/backlog/2026-11-03-chronicle-retention-policy-reference-rows.md`), the explicit retention
   mapping in `ChronicleRecordPolicy`, the outbox writers and `StepUpAuditDeliveryJob` with its
   recurring sweep. Tests: lost enqueue, Chronicle write followed by a lost acknowledgement,
   concurrent jobs, retention selection, repeated delivery.
3. OP side, Visa app and Visa org. Request parsing (`claims`, `acr_values`, the conflict rule); the
   context bound at authorization; the result-returning client-assertion verification with
   `step_up_expectation`; the purpose-bound completion with locked preparation, DPoP rule, code
   consumption, event snapshot, rotation, commit fact and outboxes; exact class preservation outside
   `normalize_acr`; server-side method enforcement per Security Mode. Tests from contract sections
   4, 6 and 10 for both realms.
4. RP side, Base app and Base org. Shared verifier and `StepUpEvidence`; start action; callback with
   correlation, source-state check and one dispatch; recovery writer and recurring job; installer
   with deadlines and the generation protocol; the typed expectation in the RP token client;
   redirect URI registration in `OidcClientStoresStaticClientStore`; explicit step-up callback
   selection beside `AuthBoundaryAuthorityMap`. Tests: deadlines with delayed recovery, simultaneous
   callbacks and dispatch count, wrong-session and wrong-grant negatives, DBSC preservation on the
   next device-session refresh.
5. Challenge and front end. The RFC 9470 401 challenge for protected resources; the entry page;
   locale keys; one shared front-end handler distinct from sign-out recovery; audit of consumers
   that treat 401 or 302 as reload. Run the front-end build, Vitest and the i18n checks.
6. Migration of callers. Move every row of inventory families F1 to F4 to `step_up_evidence:` with
   write-boundary rechecks; remove the 22 consumption calls without removing each operation's own
   checks; apply contract section 9 (TOTP enforcement attribution at root level, the
   credential-activity policy change, Q-1 commit checks); keep the retained flows and their routes.
   Regression tests for each retained flow and for the enforcement set. For bootstrap, verify only
   that this change does not alter its behavior; the pre-existing Base RP-cell ownership issue is
   out of scope and must be listed as unresolved in the final evidence. 6b. Auth and Base split
   (contract section 12, O-11; owner decision 2026-11-04). Move social unlink, the social settings
   display and TOTP registration and management from Auth to Base, each reading `StepUpEvidence` at
   its own write boundary; remove the moved Auth endpoints without aliases; implement the accepted
   O-9 handoff for passkey registration and the social link start only; keep sign-in, sign-up,
   verification, the passkey ceremonies and the OAuth start and callback on Auth. Regression tests
   for each moved operation on its new surface, the removed Auth routes, and the two handoffs
   (missing, expired, replayed, wrong actor, wrong session, wrong purpose).
7. Activation and closure. Publish Discovery metadata per realm; update `docs/mermaid` diagrams and
   the transition inventory, `docs/security/step-up-operation-inventory.md` and affected checklists
   with the delivered behavior; run the wider authentication boundary and a full test run, classify
   failures against the unit 0 baseline; write the evidence record with the commit hash and the
   dirty-worktree note; list unverified acceptance explicitly.

## 4. Stop and report instead of proceeding when

- a contract item conflicts with code or another accepted ADR;
- a migration would need a backfill, a drop or a data rewrite;
- an existing guard (sign-in guards, enforcement revocation, retained flows) would have to be
  weakened;
- a DPoP-bound Base grant is found to exist in practice;
- a test can pass only by changing an existing expectation whose intent is unclear.

## 5. Done means

Every AC of `spec.md` has a passing public test or an explicit "not verified" entry with the reason;
the old ordinary step-up path has no remaining writer or reader in Base app and Base org; the
documents of unit 7 describe the delivered behavior; the evidence record exists. The spec moves to
`verified` only on that evidence.
