# Authentication cycle delivery ledger

Status: implementing. See `spec.md` for scope and authority.

Execution paused at the owner's request on 2026-10-24. Preserve this whole ledger on resume;
the pause does not close any remaining work unit or gate.

Resumed on 2026-10-25 for the owner's bounded request to finish clearly implementable portions.
This delivery addresses WU-11 concurrent cold-cache refetches; other rows retain their gates.

The owner subsequently requested Visa controller completion. The 2026-10-25 controller refinement
extracts realm-local protocol bases, removes concrete-endpoint inheritance and makes action
visibility explicit. The WU-02 row now reflects the implemented Rails host split; full acceptance
reconciliation remains open.

The subsequent Visa OP delivery rejects mixed continuation parameters and HEAD at authorization
start and migrates the four stale result-receiver cases to Design D. Current evidence is V4O9;
this closes those four test errors, not every cycle-wide acceptance gate.

Resumed on 2026-10-25 for WU-15, WU-16 and WU-22. The 5.8 v2 design and D-173 caller mapping are
accepted. WU-44, WU-30 and WU-38 remain excluded from this implementation request.

All rows remain open until their definitions, applicable gates and acceptance are reconciled.
Existing evidence names below locate prior work; they are not fresh completion claims.

| Work unit | Scope | Current disposition / next verification |
|---|---|---|
| 01 | Local sign-in removal | Existing L0R1; reconcile deviations and all A01 cases |
| 02 | Visa OP / Base RP separation | Rails host split implemented (V2F1); controller boundary/visibility refined (V8C2); A02/G gates and external Jump acceptance remain open |
| 03 | Legacy cookie endpoint removal | Existing E3C1; reconcile A03 |
| 04 | Telephone sign-up Turnstile | Existing T4P1; reconcile A04 |
| 05 | Six-path sign-up unification | Missing; follows 24; all 05a-g acceptance required |
| 06 | Curfew enforcement | Missing; follows 24/05 |
| 07 | Refusal classes | Missing; follows 06 |
| 08 | Social callback state matrix | A08-1 through A08-4 verified locally in M8C4: full provider/intent/state matrix, L8 link guard, L4 HTML/JSON 500. Cycle-wide G gates remain separate |
| 09 | Browser allowlist | Existing B9A1; reconcile A09 |
| 10 | Standard refresh | Receipt implementation remains; replace after 02 coordination |
| 11 | JWKS verification/refetch | Existing J1K5; concurrent successful cold-cache self-fetches coalesced in C1J8; outstanding lease/TTL/request cases |
| 12 | Design D relays | Missing; follows 02 |
| 13 | OP Cancel/Switch | Reconcile after 12; end-to-end with 43 |
| 14 | RP-initiated logout | Reconcile after 02 |
| 15 | Back-channel logout | Sender, recurring sweep and twelve RP receivers implemented locally; current WU-15 evidence below |
| 16 | Authority-stop primitive v2 | Nine cause/scope paths, single writer, realm tables, restrictive children and retention integration implemented locally |
| 17 | Activation/contract epoch removal | Existing K7E0; reconcile all A17 |
| 18 | OP-chain/runtime-role removal | Missing; follows 02/10/11 |
| 19 | One locale bundle per language | Reconcile D-113 texts and all A19 |
| 20 | Identifier-first Passkey | Existing P2F0; reconcile A20 with 30 |
| 21 | RP return lane | Merged into 43 by D-151/D-162 |
| 22 | Sign-out records | Method C declarations, authority/evidence split, retention contract and child-first purge implemented locally with 16 |
| 23 | Credentials/KMS docs | Existing A9D3; reconcile owning docs |
| 24 | Binding, intent, curfew, cleanup | 24b/c/d/e implemented (I4B6/A6C4/C7D4); actual 24e HTTP race/deadline fencing verified in P4R1. 24g already delivered by WU-01. 24h ownership/cardinality/collection verified in H8P2/S2E1. Remaining acceptance reconciliation and global drift check stay open |
| 25 | Revocation authentication | Missing; follows 02 |
| 26 | Read-only diagnosis | Lookup inputs and safe OP/audit references implemented locally (2026-10-26); reconcile remaining D-82 inventory and acceptance |
| 27 | Post-containment journey | Missing; follows 12 |
| 28 | Seed Operator | Excluded by D-170; preserve backlog |
| 29 | Sign-in Sentry | Missing; follows 02/12/13 |
| 30 | Security mode | Existing migrations/code; reconcile all A30 |
| 31 | Email OTP behavior | Existing O3R1; reconcile A31 and fix observed defects |
| 32 | ORG halt audit | Existing H2C9; reconcile A32 |
| 33 | Failure convergence | Existing research; complete A33 and required fixes |
| 34 | Unfinished registration refusal | Reproduce AX26, implement APP/COM predicates/statuses |
| 35 | Lock inventory | Existing 6.2; execute F-1/F-2 repairs in 24e, F-3 with 41 |
| 36 | Host-only cookies | Existing C6H1; reconcile all A36 |
| 37 | Puma sizing | Existing D4P7; reconcile A37 |
| 38 | Curfew cleanup | Missing; follows 24/05/34 |
| 39 | ADRs/current docs | Existing A9D3; update continuously and close discrepancies |
| 40 | Recovery-send Turnstile | Existing R4T0; reconcile A40 |
| 41 | Effective DB timeouts | Existing D4P7; reconcile per-connection/job checks |
| 42 | OIDC request conformance | Existing R2U4 plus C8M2 correction; open negative boot/Jump cases |
| 43 | JWS state/target/interruption | Existing S6T2; open Base-host and request/end-to-end/log cases |
| 44 | Root issuance/epoch/credential lock | Existing E4R4; D-167 credential recheck missing; verify A44 before 16 |

## Runs in this delivery

- Initial full baseline completed before production edits: 18422 runs, 158064 assertions,
  146 failures, 24 errors, 0 skips. Evidence `authentication-cycle-baseline-F6B2` and
  `baseline.md` retain the result and all failure/error identities.
- WU-24e initial Red: 4 expected atomicity/nonterminal failures; lock-order test corrected its
  observation by clearing PostgreSQL's statistics snapshot, then failed on principal lock ownership.
- WU-24e first regression run: 93 runs, 1328 assertions, no failures/errors/skips. Additional
  principal-lock and HTTP tests: 20 runs, 413 assertions, no failures/errors/skips. Selected
  invariant guards: 25 runs, 137 assertions, no failures/errors/skips. Seven-file RuboCop clean.
- WU-24b Red: 8 HTTP failures; focused Green: 12 runs, 101 assertions. Updated fixture
  regression: 130 runs, 2812 assertions, no failures/errors/skips. Final combined 24b/e run:
  1602 runs, 19796 assertions, 47 failures and 1 error, all identities in the baseline.
  Remaining failures are unwaived; zero new identities is not G-1 closure. See I4B6.
- WU-24c/d: six generated migrations add immutable NOT NULL curfew and required purpose-constrained
  intent. Development/test OP databases rebuilt, migrations rolled back/reapplied, six live OP dump
  comparisons passed. Evidence C7D4 records the approved local OP data loss and empty-table rollback
  limits. WU-24g references/constraints were already removed by WU-01; no duplicate drop added.
- Latest broad run: 1598 runs, 19582 assertions, 47 failures and 1 error (all baseline identities).
  Final deadline/intent, model, purger and admission-boundary run: 111 runs, 1067 assertions,
  no failures/errors/skips. Fourteen changed/new Ruby files and scoped whitespace checks pass.
- Global `db:verify_no_schema_drift` remains FAILED: development COM Zenith HMAC definer role has
  a database-name mismatch; test has drift in all three Zenith dumps. OP comparisons passed, but
  they do not waive this gate. Investigate through the ordinary migration/environment workflow;
  do not weaken the verifier or normalize away an unexplained difference.
- WU-24h (H8P2): generated APP/COM FK/index migrations and dumps reconciled; both development/test
  pairs rolled back/reapplied on observed empty Flow tables. The collector now retains incomplete
  cleanup and in-progress children, deletes eligible Flow rows first, and leaves registered
  principals intact. Separate-connection insert races claim one slot per Binding. Real encrypted
  UI cookies plus an admitted Auth SID exercise foreign hints, foreign URLs and wrong nonces over
  GET/POST/PATCH/DELETE with CSRF enabled. Owner-assignment and lifecycle guards pass.
- Latest WU-24h regression: 592 runs, 5662 assertions, no failures/errors/skips; ten-file RuboCop
  and scoped whitespace checks pass. The original cycle-wide failures remain unwaived; this is
  not a full-suite run. Global drift still fails on Zenith state and uncommitted OP dumps; scoped
  live OP comparisons do not waive it. See H8P2 for commands and rollback limits.
- Base Social follow-up (S2E1): the public committer refuses fresh and committed results whose
  signed session reference does not identify the Flow's redeemed sign-up Binding. The Base receiver
  scopes completion-reference reads/writes to that same FK. Four initial mismatched/missing-owner
  cases were Red despite valid signatures; focused final verification is 45 runs/501 assertions,
  all green. The broader run is 642/6191 with four failures, no errors/skips: the existing Google/
  Apple sign-up callback redirect and sign-in RP-cookie identities. Their reconciliation stays
  open; this is not G-1 or six-path completion. Four-file RuboCop passes.
- WU-24e HTTP race follow-up (P4R1): a real verified WebAuthn request waits on its locked Flow
  without holding the principal; termination winning causes 409 and no credential/allocation.
  Post-wait deadline checks cover one microsecond before/at/after; concurrent verified saves return
  the existing success and allocate once. Final related run: 34/604, all green; three-file RuboCop
  passes. A35-2 stays partial pending exact cleanup-job/replayed-termination reconciliation.
- Next work: reconcile remaining WU-24/A35-2 acceptance and the global schema gate,
  then execute AX26 and WU-34 before sign-up unification. The other 44-unit ledger scope remains
  unchanged, including WU-05/06, Visa separation, refresh and authority-stop v2.
- Last checkpoint: no test process remains running. Current Passkey-race output is
  `/tmp/two-wu24e-stop-checkpoint.log` (34/604, all green); current Base Social output is
  `/tmp/two-e1-social-owner-final.log` (45/501, all green), with broader output
  `/tmp/two-e1-social-owner-broad-final.log` (642/6191, four failures). Prior WU-24h output is
  `/tmp/two-e1-final-suite.log` (592/5662, all green); HTTP-only output is
  `/tmp/two-e1-request-mutations.log` (6/216, all green). Earlier broad output remains
  `/tmp/two-wu24cd-regression.log`; its 48 unwaived outcomes are indexed in `wu24-regressions.md`.
