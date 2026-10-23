# Authentication cycle delivery ledger

Status: implementing. See `spec.md` for scope and authority.

All rows remain open until their definitions, applicable gates and acceptance are reconciled.
Existing evidence names below locate prior work; they are not fresh completion claims.

| Work unit | Scope | Current disposition / next verification |
|---|---|---|
| 01 | Local sign-in removal | Existing L0R1; reconcile deviations and all A01 cases |
| 02 | Visa OP / Base RP separation | Missing; follows sign-up prerequisites |
| 03 | Legacy cookie endpoint removal | Existing E3C1; reconcile A03 |
| 04 | Telephone sign-up Turnstile | Existing T4P1; reconcile A04 |
| 05 | Six-path sign-up unification | Missing; follows 24; all 05a-g acceptance required |
| 06 | Curfew enforcement | Missing; follows 24/05 |
| 07 | Refusal classes | Missing; follows 06 |
| 08 | Social callback state matrix | Reconcile and implement after 05b |
| 09 | Browser allowlist | Existing B9A1; reconcile A09 |
| 10 | Standard refresh | Receipt implementation remains; replace after 02 coordination |
| 11 | JWKS verification/refetch | Existing J1K5; outstanding lease/TTL/request cases |
| 12 | Design D relays | Missing; follows 02 |
| 13 | OP Cancel/Switch | Reconcile after 12; end-to-end with 43 |
| 14 | RP-initiated logout | Reconcile after 02 |
| 15 | Back-channel logout | Receiver existing B5R7; sender follows 16 |
| 16 | Authority-stop primitive v2 | Missing; follows verified 44 |
| 17 | Activation/contract epoch removal | Existing K7E0; reconcile all A17 |
| 18 | OP-chain/runtime-role removal | Missing; follows 02/10/11 |
| 19 | One locale bundle per language | Reconcile D-113 texts and all A19 |
| 20 | Identifier-first Passkey | Existing P2F0; reconcile A20 with 30 |
| 21 | RP return lane | Merged into 43 by D-151/D-162 |
| 22 | Sign-out records | Implement authority-stop v2 requirements with 16 |
| 23 | Credentials/KMS docs | Existing A9D3; reconcile owning docs |
| 24 | Binding, intent, curfew, cleanup | 24b/c/d/e implemented (I4B6/A6C4/C7D4); 24g already delivered by WU-01 and reconciled. 24e request race and 24h E1 remain; global drift check open |
| 25 | Revocation authentication | Missing; follows 02 |
| 26 | Read-only diagnosis | Missing; follows 24 fields |
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
- Next work: 24h E1 required Flow-to-Binding FK, one-live-Flow index, explicit creation ownership,
  stale-locator refusal and child-first purge. Complete 24e's Passkey-save/termination request race
  and requirement-level gates. The other 44-unit ledger scope remains unchanged.
- Last checkpoint: no test process remains running. Broad output is
  `/tmp/two-wu24cd-regression.log`; final focused output is `/tmp/two-wu24cd-final-focused.log`.
  The original 48 unwaived broad outcomes remain indexed in `wu24-regressions.md`.
