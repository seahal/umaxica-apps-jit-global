# three.md — Acceptance (Gates, acceptance cases, execution record)

> Archived 2026-10-27 from the working file `three.md` (cycle archive 0002; frozen, not maintained).

> Status 2026-10-25: WU-15/16/22 have local implementation and focused checks recorded in §4 and `evidence/2026-10-25-wu15-16-22-op-authority-stop-6B3Q.md`; this is not unit acceptance. The G-1 baseline remains 18448 runs, 77 failures and 2 errors (`evidence/2026-10-22-g1-full-test-baseline-B7G1.md`). WU-16/22 still require G-16 and D-166/A44 prerequisites before acceptance. Start from `one.md` "Resume here". Gates G-1 … G-22 are the cycle's Gates (D-124).

Working document (gitignored). Role in the cycle: `one.md` holds requirements and decisions,
`two.md` defines the Work Units, **this file states how each unit is accepted**. Opened 2026-10-21
at `febec3225cc9a0cfa53b9cbe817d20d366aba5a2`. Implementation and acceptance are recorded separately
in this file; a local implementation does not by itself close an acceptance gate.

Rules:

- A case passes only on evidence produced after the change: a named test that runs green, a
  recorded command output, or a document diff. A description of intent is not evidence.
- "Request test" means a Rails integration/controller test through HTTP; per-host cookie jars where
  hosts matter. It does not prove real-browser behavior (no browser E2E in this cycle, H8).
- Configuration is verified by running it and recording the result in `evidence/`, never by a
  Minitest case about configuration (`project/no-environment-tests.mdc`).
- A case that cannot be run is recorded as **Not run** with the reason; never as passed.
- Decision IDs refer to `one.md`; WU and step IDs to `two.md`.
- Status words are distinct and never merged (R-28): **Defined** (case written) → **Implemented**
  (test or procedure exists) → **Executed** (run, result recorded) → **Passed** / **Failed** /
  **Not run (reason)** / **Unverified (blocked by …)**. Only an Executed case can be Passed.

## 1. Gate register

Every Work Unit must pass the Gates that **apply to it** plus its own cases (§2). Applicability
(added 2026-10-22 per seven.md #8): G-1 … G-7 apply to every unit. A Gate tied to a later unit's
behavior **does not apply to units that finish before that behavior exists**; it applies from the
unit that introduces it and is **re-checked** by every later unit that touches the same area:

| Gate | Introduced by | Re-checked by |
|---|---|---|
| G-8 | first unit touching a reference hop (WU-02 or WU-24) | WU-05, WU-06, WU-12, WU-13, WU-29 |
| G-9 | WU-06 (enforcement); WU-24 only stores `curfew_at` | WU-05, WU-12, WU-13 |
| G-10 … G-14 | WU-05 | WU-08, WU-38 |
| G-15 | WU-02 realm units | WU-10, WU-12, WU-13, WU-14 |
| G-16 | first logout unit (WU-02-APP, V9) | WU-14, WU-15, WU-16, WU-22 |
| G-17 | WU-29 | units after WU-29 touching Sign-in path entries or POSTs |
| G-18 | WU-12 | WU-13, WU-27, WU-29 |
| G-19 | WU-16 (outbox row per participant in the stop transaction); delivery part by WU-15 sender | WU-15 sender, WU-22 |
| G-20 | WU-16 | WU-22 |
| G-21 | WU-30 | WU-20 and later sign-in units |
| G-22 | WU-36 | units adding cookies |

| Gate | Condition | Evidence |
|---|---|---|
| G-1 Baseline | Before the first unit starts, a fresh full `bin/rails test` baseline is taken at the starting commit **including the uncommitted worktree**, and its failure list recorded; the 2026-10-21 TR numbers (59/1) are history, not the baseline. A unit passes only when it adds no failure **and** every baseline failure in the unit's own area is fixed or explicitly reassigned with a reason ("no new failures" alone is not completion; seven.md) | Before/after failure lists in the unit's `evidence/` record |
| G-2 Guards | Static invariant guards pass (`project/static-invariant-guards.mdc`), including `test/security/invariants/auth_surface_translation_namespace_invariant_test.rb` | Test run |
| G-3 No weakening | No test deleted or weakened to pass; every rewritten test has a stated reason; no compatibility route, alias or fallback added | Diff review |
| G-4 Lint | RuboCop clean on changed Ruby; oxfmt/oxlint/`tsc --build` clean on changed TypeScript | Command output |
| G-5 Docs | ADRs, `docs/`, checklists and `docs/mermaid` match the code for the touched area | Diff |
| G-6 Evidence | One `evidence/` record with the full commit hash, uncommitted-change note, commands, results, and Not-run items | File |
| G-7 Secrets | No key, token, cookie, code or contact value in logs, evidence, tests' printed output or docs | Review |
| G-8 Cross-browser non-consumption | At every hop that takes a reference: a foreign browser can never **advance** a flow — no confirm, redeem, result acceptance, Root Session, callback success, Switch or Cancel — and ends no Flow, Candidate or ceremony other than through D-51. **Exception (D-51, accepted residual risk):** a stolen live reference may be attached first by a foreign browser before the victim (denial of the victim's attempt only); the test asserts the attacker then cannot confirm, redeem, be accepted or get a Root Session, and that a repeat attach after the first is refused (AUTH-19, D-73). Corrected 2026-10-22 per seven.md #4 | Request tests with two sessions |
| G-9 Curfew boundary | 29:59 / 30:00 / 30:01 for every consumer, Switch near the deadline (inherits it, D-74), lock wait spanning the deadline, Finalization whose deadline check under the lock runs at 29:59 → registered (kept even if the principal commit lands after 30:00, D-131) with the Sign-in handoff judged on its own, and whose check runs at 30:00 / 30:01 → nothing registered, fail closed (D-105 read by D-131), Auth-side in time but OP-side receipt late; after the curfew the owner's own attempt returns to the RP as `access_denied`, a foreign request ends nothing (D-160 (3)). The RP `state` deadline is a separate check on the Rails clock (D-160 (1)), accepted in A43-6 / A43-20, not here | Tests on the OP DB clock (`ApplicationRecord.database_now`, D-75) |
| G-10 Resend never increases | R23-INV-1 … 4: resend adds no expiry, authority, single-use reference or consumption; no re-minting of a consumed next reference; lost response after COMMIT yields nothing new | Tests asserting state and returned destination, not just status |
| G-11 Subject concurrency | Two Flows finalizing one provider subject (both providers), unlink/relink racing Finalization, ban visible at Finalization, pre-existing revoked/deleted subject: one winner, loser adopts nothing and leaves no verified orphan | Concurrency tests on separate DB connections |
| G-12 Cleanup race | Cleanup vs confirmation/Finalization, old-Flow cleanup vs a new attempt: a confirmed Client/Identity stays usable (D-77) | Concurrency tests |
| G-13 Candidate | Single consumption, expiry (≤ curfew, never the 60 s acceptance), mismatch refusal, OP DB outage → fail closed (D-78) | Tests |
| G-14 Partial commit | Failure at each boundary (Candidate consume, principal commit, graph commit, Flow transition, evidence handoff, response delivery) through public entry points with real separate transactions; assert remaining rows and the next sign-in's observable result; no single mocked exception as proof | Tests + WU-26 diagnosis output |
| G-15 OIDC protocol outcomes | `prompt=none` → `login_required` and one new interactive transaction (no loop); `access_denied` Cancel return after `state`/`iss`; revocation with the registered method; RP-Initiated Logout GET/POST; expired `id_token_hint` accepted for logout only, never for authentication | Request tests |
| G-16 Sign-out safety (H5 SO-6) | Sign-in / Sign-up intact; realms separate; the RP writes no OP authority and clears only itself; `id_token_hint` identifies, the current OP session is the target; GET changes no authority; POSTs verify CSRF; delivery never decides the result; nothing unconfirmed is reported as signed out and nothing committed is reported as failed; an old return never breaks a new login; completion pages are read-only GETs shown once. Covered by A14-*, A15-3, A44-6, A44-10. | Request and concurrency tests |
| G-17 Sentry fail closed (D-84, D-93, D-99) | For WU-29 and every unit touching a Sign-in path entry or POST: unset flag and flag-store error refuse; no Sign-in path entry, POST or callback reaches evidence, registration or root login while BLOCKED; Re-verification path, Refresh, Sign Out and `prompt=none` unaffected | Request tests (A29-*) |
| G-18 Continuation GET conditions (D-100, D-101) | For every Design D continuation endpoint: Fetch Metadata required, HEAD refused, binding checked before consumption, CAS, same-browser repeat only within issuance + 10 s, `no-store` + `no-referrer`, clean final URL | Request tests per endpoint (A12-*) |
| G-19 Durable BCL (D-117, D-121) | Every stop writes one outbox row per participant in its transaction; every row reaches a final state or the BX-10 deadline through Solid Queue and the sweep | Job and request tests (A15-*); browser receipt is no longer part of a stop |
| G-20 Strict stop records (D-119, D-123) | Every stop record has principal and cause NOT NULL; token references in the OP database `ON DELETE RESTRICT`, the principal referenced by public id and protected by the purge order (cross-DB); a re-run is answered from the stored record. **Authority per cause** (corrected 2026-10-22 per seven.md #5; D-123's "no valid OP session → no authoritative stop" applies to **browser sign-out only**): browser sign-out — a valid OP session and the person's own request; identity stop — a committed identity-stop event; refresh reuse — a verified used token and its grant; token revocation — the authenticated client per D-79; administrative or risk stop — the operator's authorization and scope. A stop without its cause's authority is refused | Request tests per cause + schema check; browser receipt is no longer part of a stop |
| G-21 Security Mode fail closed (D-88) | Only `3`/`7` admit authentication; `0`, unknown and `NULL` refuse both authentication and authorization | Request tests (A30-3) |
| G-22 Host-only cookies (D-115, D-58) | No cookie set with `Domain` or `Partitioned` by any unit | Request tests (A36-1) |

## 2. Acceptance cases

Status column: **Not run** until §4 records a run.

### WU-01 — Remove the Local Sign-in Flow

| ID | Case | Expected | Verification | Status |
|---|---|---|---|---|
| A01-1 | Request Base `/sign/completion` and Auth `/sign/handoff` on app/com/org | Not routable | Request tests | Passed (retired_local_sign_in_route_test) |
| A01-2 | Admit a ceremony with purpose `local_sign_in` / `local_sign_up` | Refused, not mapped to another purpose | Unit/request test | Passed (model + DB refusal tests) |
| A01-3 | Dead-code check before each deletion | Callers, reachability, unchanged OIDC results recorded per part | Evidence | Passed with deviations (evidence L0R1; Red after removal) |
| A01-4 | `grep -rn "local_sign_in\|local_sign_up\|issue_local_entry\|sign/completion\|sign_handoff\|continue_selector_sequence" app lib config` | Only items listed as intentionally kept | Command output | Passed (empty) |
| A01-5 | Re-pointed fixture tests | Same assertions as before where the OIDC path behaves like Local; where it differs, the assertion states the OIDC behavior (owner, 2026-10-27) | Diff review | Passed — accepted by the owner 2026-10-27: assertions follow the OIDC path (list in `evidence/2026-10-23-wu01-local-sign-in-flow-removal-L0R1.md`); the Local-only case "credential change after Auth completion rejects the outstanding result" has no OIDC test yet and is tracked with `nine.md` BL-21 |
| A01-6 | `local_sign_in_flow_ref` column | Still present; follow-up recorded | Schema check | Superseded: column dropped under D-168 (migrations 2026102312000x) |

### WU-02 — Visa OP / Base RP

| ID | Case | Expected | Verification | Status |
|---|---|---|---|---|
| A02-1 | Each OP route on `visa.umaxica.{app,com,org}` | Answers; not routable on `www` or `auth` | Request tests | Passed — tests mapped in `seven.md` stage 2 all green on 2026-10-27 (`evidence/2026-10-27-mapped-cases-run-M5Q8.md`) |
| A02-2 | Look-alike host (e.g. `visa.umaxica.app.example`) | Refused | Request test | Passed — tests mapped in `seven.md` stage 2 all green on 2026-10-27 (`evidence/2026-10-27-mapped-cases-run-M5Q8.md`) |
| A02-3 | Boot without a `VISA_*` setting | Fails; no fallback to Base | Evidence (run) | Passed — production host configuration without each `VISA_*`/`PUBLIC_VISA_*` key raises `Missing required ENV key` and an empty value raises `invalid origin`; no Base fallback (`evidence/2026-10-27-command-acceptance-group-2-C6G3.md`) |
| A02-4 | Discovery `issuer`, ID Token `iss`, authorization response `iss`, logout token `iss` | All equal the Visa origin of the realm | Request/unit tests | Passed — builder and verified-token checks; `evidence/2026-10-27-cycle-partial-boundaries-C4S9.md` |
| A02-5 | Token with the old `www` issuer; client assertion with the old audience | Refused | Unit tests | Passed — tests mapped in `seven.md` stage 2 all green on 2026-10-27 (`evidence/2026-10-27-mapped-cases-run-M5Q8.md`) |
| A02-6 | Visa JWKS vs Base JWKS | Disjoint key sets (`VISA_*` vs `BASE_*`) | Request tests | Passed — tests mapped in `seven.md` stage 2 all green on 2026-10-27 (`evidence/2026-10-27-mapped-cases-run-M5Q8.md`) |
| A02-7 | Base self-RP sign-in end to end with per-host cookie jars (G1 regression) | Visa `reset_session` leaves the Base pending OIDC flow; callback succeeds; TR G1 tests pass | Request tests | Not run |
| A02-8 | Auth result targets (R2) per realm | Sign-in and sign-up results → Visa; Re-verification completion → Base; dashboard/identity links → Base; missing Visa setting does not fall back | Request tests | Not run |
| A02-9 | Ceremony binding confirmation purpose ↔ host | Visa accepts only Sign-in path purposes, `www` only Re-verification; the other is refused before any state change | Request tests | Passed — tests mapped in `seven.md` stage 2 all green on 2026-10-27 (`evidence/2026-10-27-mapped-cases-run-M5Q8.md`) |
| A02-10 | Jump edge table vs signed RTs | Table equals what Rails signs; handoff document exists | Unit test + doc | Passed — `evidence/2026-10-27-cycle-partial-boundaries-C4S9.md` |
| A02-11 | Logout across hosts | Base clears its cookies, Visa never writes Base cookies, receipt bound to the Visa session; double execution, retry, timeout, revoked session handled | Request tests | Not run |
| A02-12 | No Base page reads OP-written Rails-session state | Static search + `/welcome`, `/selector` request tests with RP state only | Tests + command | Passed — tests mapped in `seven.md` stage 2 all green on 2026-10-27 (`evidence/2026-10-27-mapped-cases-run-M5Q8.md`) |
| A02-13 | Old Base OP paths | Not routable; no redirect. **Exceptions kept on Base (`www`)**: Base RP endpoints, its own JWKS if Base still signs anything, and the Re-verification path's binding confirmation (D-61); each exception listed in the test (seven.md) | Request tests | Not run |
| A02-14 | Jump integration | **Not in scope** — must be recorded as Not run with reason "Jump change pending (H8, D-161 (2))" | Evidence | Not run — the Jump change for APP/ORG landed 2026-10-27 (`tmp/jump-edge-visa-app-org.md`) and the owner's APP Google sign-in/sign-up passed through Jump (`three.md` manual acceptance); a recorded Jump integration check is still to be run (next cycle) (`evidence/2026-10-27-non-test-acceptance-T2F6.md`) |
| A02-15 | Provider callback URLs after each realm unit (D-161 (4)) | `OmniAuth.config.full_host` and `/social/{google,apple,entra}/callback` unchanged; the authorize request sent to each provider carries the same `redirect_uri` as before the unit; no provider callback routes on Visa | Request tests (provider redirect captured) | Not run |
| A02-16 | After 02-APP, before 02-COM | COM and ORG sign-in, result, logout and issuer unchanged (existing suites green); APP has no OP route on `www` | Test run | Not run |

### WU-03 — Remove `/edge/v0/cookie`

| ID | Case | Expected | Verification | Status |
|---|---|---|---|---|
| A03-1 | `/edge/v0/cookie` on app/com/org | Not routable | Request tests | Not run |
| A03-2 | `/api/v0/preferences/cookie` | Behavior unchanged; anything only the old endpoint provided is reported | Existing tests + comparison note | Not run |
| A03-3 | `grep -rn "edge/v0/cookie" app config src` | Empty | Command output | Passed — no match (`evidence/2026-10-27-command-acceptance-group-2-C6G3.md`) |

### WU-04 — Telephone SMS OTP Turnstile (app, com)

| ID | Case | Expected | Verification | Status |
|---|---|---|---|---|
| A04-1 | OTP page props (app, com) | Contain visible Turnstile props with a fresh challenge per render | Request tests | Not run |
| A04-2 | Valid Turnstile + valid code | Proceeds to the existing Passkey registration path | Request tests | Not run |
| A04-3 | Missing token / invalid token / verification failure | Refused with the error page | Request tests | Not run |
| A04-4 | After each refusal | OTP not consumed (attempts and lock unchanged), Flow not advanced, telephone not verified | Request tests with DB assertions | Not run |
| A04-5 | Retry with a new challenge and the valid code | Succeeds | Request test | Not run |
| A04-6 | Email OTP regression | Existing tests unchanged and green | Test run | Not run |
| A04-7 | `docs/security/turnstile.md` table | Lists the OTP check rows for email and telephone, app and com | Diff | Passed — the table lists the email and telephone OTP check rows for app and com (`evidence/2026-10-27-document-acceptance-group-3-D8R4.md`) |

### WU-05 — Sign-up six-path unification

| ID | Case | Expected | Verification | Status |
|---|---|---|---|---|
| A05-1 | New ADR exists **before** implementation commits (U4) | Accepted ADR with supersession notes | Doc + commit order | Passed — `adr/sign-up-finalization-in-auth.md` is Accepted with a Supersedes section and records it was written before implementation (WU-05a); in git the ADR and the implementation landed in the same checkpoint commit `58c52567e`, so the order is shown by the ADR's record, not by commit order (`evidence/2026-10-27-non-test-acceptance-T2F6.md`) |
| A05-2 | Effective intent (EI-1/EI-2) | `authentication` Admission opens only sign-in pages; sign-up needs Switch or `prompt=create`; params/Referer ignored | Request tests (app, com) | Not run |
| A05-3 | One social Flow per attempt (R2-A) | Created only at the entry under a sign-up intent, bound to the Admission, expiring at the curfew; callback never creates one | Request tests | Not run |
| A05-4 | Unknown identity under a sign-in Admission / registered identity under a sign-up Admission | Errors (L1 / L2) | Request tests per provider | Passed — tests mapped in `seven.md` stage 2 all green on 2026-10-27 (`evidence/2026-10-27-mapped-cases-run-M5Q8.md`) |
| A05-5 | Existing social user signing in | Never treated as sign-up | Request tests per provider | Not run |
| A05-6 | Pending social Client (P1–P5) | Created after evidence + confirmation Turnstile; one per Flow; cannot sign in; no identity before Finalization; cleaned on expiry/cancel/halt | Request + unit tests | Not run |
| A05-7 | Candidate (C1–C3, corrected per D-78) | Stored in the OP DB without provider credential; expired or consumed candidate refused, never revived; OP DB down → fail closed (no Valkey test for the Candidate) | Unit tests | Not run |
| A05-8 | Finalization (F1–F6) for all six paths — **Waits for WU-35's lock order (D-107); D-105 and D-106 apply** | Shared finalizer; identity + verified status in one principal transaction; idempotent second run; entry method recorded | Unit/request tests | Not run |
| A05-9 | Concurrent sign-ups for one provider subject | See G-11 | Concurrency test on separate connections | Not run |
| A05-10 | Sign In First for Google/Apple (S1–S4) | Canonical Sign In applied (guardrail, checkpoint, MFA, cooldown, session limit); no direct result issuance from sign-up | Request tests | Not run |
| A05-11 | Old social sign-up transport removed | Base social completion sign-up branches, committer `commit_signup!`/`committed_signup!`/`commit_login!`/`commit_link!`, C2 callback path gone after dead-code checks | Command + tests | Not run |
| A05-12 | Social confirmation Turnstile | Still ceremony-bound (action, hostname, cdata) | Existing tests | Passed; `evidence/2026-10-27-social-turnstile-binding-K3V5.md` |
| A05-13 | Com email/telephone | Same EI rules; shared Finalization; no Com social | Request tests | Not run |

### WU-06 — Curfew

| ID | Case | Expected | Verification | Status |
|---|---|---|---|---|
| A06-1 | Each REQ-CURFEW 3 consumer at 29:59, 30:00, 30:01 | 29:59 allowed; 30:00 and later refused (WU-07 response) | Tests with the DB clock helper | Not run |
| A06-2 | Result issued before the curfew, presented after | Refused | Test | Passed — tests mapped in `seven.md` stage 2 all green on 2026-10-27 (`evidence/2026-10-27-mapped-cases-run-M5Q8.md`) |
| A06-3 | Social after 60 s within the curfew | Allowed (F5 fixed) | Test | Not run |
| A06-4 | Auth ceremony expiry at an APP/COM/ORG admission handoff | `expires_at` equals the stored Binding `curfew_at`; active 1 µs before and expired at/after it. The OIDC transaction and login challenge remain retained through the curfew; the 60-second Binding expiry owns redemption only (D-36, D-160 (3)). RP `state` is not a parent (A43-6, A43-20) | `test/integration/admission_curfew_test.rb` | Passed |
| A06-7 | Own browser acts at 30:00 / 30:01 (one Auth action, one provider callback, Cancel) | OP ends the authorization transaction; 303 to the registered `redirect_uri` with only `error=access_denied`, the unchanged `state` and `iss`; no evidence, session or code | Request tests | Not run |
| A06-8 | Foreign browser (no or another cookie binding) presents the same references after the curfew | Uniform error; transaction, Flow and ceremony unchanged; no redirect to the RP | Request tests | Not run |
| A06-9 | Own browser after the curfew with the authorization transaction row removed | Uniform error on Auth (D-47); nothing else changes | Request test | Not run |
| A06-5 | Carried codes | Keep their own TTLs, capped by the curfew | Tests | Not run |
| A06-6a | Finalization whose deadline check (OP clock, under the Flow/Binding lock) runs at 29:59 | Principal committed in the registered status; kept (D-131) | Test | Not run |
| A06-6b | Same, with the principal commit and the Sign-in handoff landing at or after 30:00 (lock wait / delay injected through a real separate transaction) | Registration kept; the handoff is refused as a curfew consumer — no Root Session, Grant or RP session; a later ordinary sign-in succeeds | Test | Passed — tests mapped in `seven.md` stage 2 all green on 2026-10-27 (`evidence/2026-10-27-mapped-cases-run-M5Q8.md`) |
| A06-6c | Deadline check at 30:00 / 30:01 | Refused, fail closed; no registered status, no authority; unfinished data left for cleanup (D-105) | Test | Not run |

### WU-07 — Refusal classes (D-73)

| ID | Case | Expected | Verification | Status |
|---|---|---|---|---|
| A07-0 | Each refusal cause mapped to exactly one of the six classes | Mapping table in code matches two.md WU-07 | Unit test | Passed — tests mapped in `seven.md` stage 2 all green on 2026-10-27 (`evidence/2026-10-27-mapped-cases-run-M5Q8.md`) |
| A07-1 | Every definitive refusal of the owner's own attempt | Identical status and body; attempt ended through a named transition | Parameterized request tests | Not run |
| A07-1b | Ownership mismatch | Uniform error; victim's Flow/Candidate untouched (G-8) | Request tests | Not run |
| A07-1c | Retryable (Turnstile) | Same page, new challenge, Flow kept, OTP not consumed | Request tests | Passed — tests mapped in `seven.md` stage 2 all green on 2026-10-27 (`evidence/2026-10-27-mapped-cases-run-M5Q8.md`) |
| A07-1d | Dependency failure | 503-class response; no authority; nothing needlessly consumed | Request tests | Not run |
| A07-1e | Internal inconsistency | 5xx and auditable record | Request tests | Passed — tests mapped in `seven.md` stage 2 all green on 2026-10-27 (`evidence/2026-10-27-mapped-cases-run-M5Q8.md`) |
| A07-1f | Protocol refusal | Standard OIDC response (G-15) | Request tests | Not run |
| A07-2 | After a refusal, per D-73 class | Definitive refusal: social intent, Flow locators and ceremony continuity removed from the Rails session; retryable: Flow, locators and continuity kept (A07-1c); ownership mismatch: nothing of the victim's touched; dependency failure: nothing needlessly consumed (corrected per seven.md #10) | Tests per class | Passed — tests mapped in `seven.md` stage 2 all green on 2026-10-27 (`evidence/2026-10-27-mapped-cases-run-M5Q8.md`) |
| A07-3 | Log event per refusal | Exactly one event with the reason code; no reference, token, code or contact value | Tests on the formatted event | Passed — tests mapped in `seven.md` stage 2 all green on 2026-10-27 (`evidence/2026-10-27-mapped-cases-run-M5Q8.md`) |
| A07-4 | Re-verification path and BCL receiver | Unchanged | Existing tests | Not run |

### WU-08 — Social callback matrix

| ID | Case | Expected | Verification | Status |
|---|---|---|---|---|
| A08-1 | Intent × L1–L8 × provider | Outcomes per D-48 | Request tests | Passed — tests mapped in `seven.md` stage 2 all green on 2026-10-27 (`evidence/2026-10-27-mapped-cases-run-M5Q8.md`) |
| A08-2 | L8 ban present together with any other state | Ban wins; checked before identity lookup | Request tests | Not run |
| A08-3 | L4 (identity without Client) | Raise, 5xx, FATAL log | Test | Not run |
| A08-4 | Any refusal | No Flow, no pending Client created | DB assertions | Not run |

### WU-09 — Browser allowlist

| ID | Case | Expected | Verification | Status |
|---|---|---|---|---|
| A09-1 | Outdated browser UA on a browser page | 406 | Request test | Not run |
| A09-2 | BCL receiver, token endpoint, health | Not affected | Request tests | Not run |

### WU-10 — Standard refresh

| ID | Case | Expected | Verification | Status |
|---|---|---|---|---|
| A10-1 | Refresh | Rotates every use | Test | Passed — tests mapped in `seven.md` stage 2 all green on 2026-10-27 (`evidence/2026-10-27-mapped-cases-run-M5Q8.md`) |
| A10-2 | Reuse of a consumed token | `invalid_grant`; only that grant's family revoked; Root Session intact | Test | Not run |
| A10-3 | Unknown token | Nothing revoked | Test | Not run |
| A10-4 | Receipt endpoint and recovery code | Removed; not routable | Request test + command | Passed — `evidence/2026-10-27-cycle-partial-boundaries-C4S9.md` |
| A10-5 | RP recovery | New Code flow with `prompt=none` | Request test | Passed — tests mapped in `seven.md` stage 2 all green on 2026-10-27 (`evidence/2026-10-27-mapped-cases-run-M5Q8.md`) |
| A10-6 | `rp_refresh_attempts` removal migration | Not a gate (D-168); migration runs in the ordinary workflow | — | Not applicable (D-168) |

### WU-11 — RP JWT verification

| ID | Case | Expected | Verification | Status |
|---|---|---|---|---|
| A11-1 | Repeated verification, including the BCL receiver | One cached client per issuer; Discovery `jwks_uri` used (BX-6) | Test | Not run |
| A11-2 | Unknown `kid`, fetch succeeds with / without it | found / **invalid** (400/401 per caller) | Test | Not run |
| A11-3 | Unknown `kid`, fetch fails | **unavailable** (503, never 400) | Test | Not run |
| A11-4 | Known `kid` while the rate-limit Valkey is down | Verified with the held key; Valkey not consulted (D-136) | Test with a failing connection | Not run |
| A11-5 | Many random `kid`s for one issuer inside one window, two workers | At most one JWKS fetch per issuer per window across workers; no key per `kid` written | Concurrency test on the test rate-limit Valkey (separate threads) | Not run |
| A11-6 | Window active: last fetch ok and `kid` absent / last fetch failed / lease held without a result | invalid / unavailable / unavailable — never "invalid" when uncertain | Test | Not run |
| A11-7 | Valkey down and unknown `kid` | Process-local limit applies (not unlimited); refused fetch → unavailable | Test | Not run |
| A11-8 | Lease holder dies before writing a result | Another worker may fetch after the lease TTL | Test with the injected clock | Not run |
| A11-10 | Non-ES384 token | Refused | Test | Not run |
| A11-11 | Unknown `kid` with a non-ES384 `alg`, a malformed `kid`, or another issuer | invalid; no lease taken, no JWKS fetch | Test asserting zero fetches and no Valkey write | Not run |
| A11-12 | Window value 30 s: unknown `kid` at 29 s / 30 s / 31 s after the last fetch | Limited / new fetch allowed per key expiry / new fetch allowed (boundary taken from the Valkey TTL semantics) | Test with controlled TTL | Not run |

### WU-14 — RP-Initiated Logout

| ID | Case | Expected | Verification | Status |
|---|---|---|---|---|
| A14-1 | GET and POST `/oidc/logout` | Confirmation or refusal only; no authority change | Request and boundary tests | Passed (see `evidence/2026-10-26-sign-out-so5-acceptance-G5P8.md`) |
| A14-2 | Confirmation | Separate CSRF-protected POST; bad or missing token refused, nothing stopped | Request and boundary tests | Passed (see `evidence/2026-10-26-sign-out-so5-acceptance-G5P8.md`) |
| A14-3 | Hint expired / foreign issuer / `client_id` not audience / bad signature | Accepted / refused / refused / refused; no refusal renders a signed-out page | Request and boundary tests | Passed (see `evidence/2026-10-26-sign-out-so5-acceptance-G5P8.md`) |
| A14-4 | Unregistered `post_logout_redirect_uri` | Refused; never redirected to | Request and boundary tests | Passed (see `evidence/2026-10-26-sign-out-so5-acceptance-G5P8.md`) |
| A14-5a | Two first-party RPs in one browser, sign out at one, hint `sid` = grant id (F-5); the device session holds two root rows (after a rotation) | After confirmation: both root rows stopped (one stop record each), every grant under them stopped, device session revoked; both RPs refuse the browser next request; another device of the same person untouched; 303 to the RP completion with `state` | Request and boundary tests | Passed — `test/integration/oidc_current_device_logout_test.rb:656`; all three realms stop the device lineage, originating RP next POST refuses with 401 and sibling RP next dashboard refuses |
| A14-5b | Same; receiver answers 200 or 204 | Job marks the participants done | Request and boundary tests | Passed (stubbed delivery) (see `evidence/2026-10-26-sign-out-so5-acceptance-G5P8.md`) |
| A14-5c | Same; receiver fails | Job retries per BX-4; OP authority stays stopped; the redirect did not wait | Request and boundary tests | Passed (stubbed delivery) (see `evidence/2026-10-26-sign-out-so5-acceptance-G5P8.md`) |
| A14-6 | Cancel or no answer at the OP | Initiating RP signed out; OP session, other RPs and that RP's grant still valid (S-6 gap, asserted) | Request and boundary tests | Passed — `test/integration/oidc_current_device_logout_test.rb:510`; leaving confirmation keeps OP roots/grants live, originating RP next POST returns 401 and sibling dashboard returns 200 in each realm |
| A14-7 | RP sign-out side effects | No OP authority row, no OP endpoint call; the RP completion writes nothing | Request and boundary tests | Passed — `test/integration/oidc_rp_logout_registered_rp_matrix_test.rb:16`; all twelve launchers make no outbound OP connection or authority stop and completion emits no INSERT/UPDATE/DELETE |
| A14-8 | Verified hint + no OP session; hint `sid` of another device's grant (same person); hint `sid` of an unrelated grant | 403, plain text en/ja; nothing stored, stopped or redirected | Request and boundary tests | Passed (see `evidence/2026-10-26-sign-out-so5-acceptance-G5P8.md`) |
| A14-9a | No hint, OP session present | Confirmation → stop → OP signed-out page; once; reload 404 | Request and boundary tests | Passed (see `evidence/2026-10-26-sign-out-so5-acceptance-G5P8.md`) |
| A14-9b | No hint, no OP session | "already signed out" page; no confirmation; no state change | Request and boundary tests | Passed (see `evidence/2026-10-26-sign-out-so5-acceptance-G5P8.md`) |
| A14-9c | Hint without registered URI | Refused per A14-4 (never a redirect) | Request and boundary tests | Passed (see `evidence/2026-10-26-sign-out-so5-acceptance-G5P8.md`) |
| A14-10a | Stop raises before commit | 5xx; Visa cookies, session and pending request kept; root live; no redirect | Request and boundary tests | Passed (see `evidence/2026-10-26-sign-out-so5-acceptance-G5P8.md`) |
| A14-10b | `CommitOutcomeUnknown` | 503 result-unknown; no redirect; retry ends on "already signed out" if the stop committed, or stops the same session if it did not | Request and boundary tests | Passed (see `evidence/2026-10-26-sign-out-so5-acceptance-G5P8.md`) |
| A14-10c | Stop committed, then (a) notice storage or redirect construction raises, or (b) the after-commit enqueue fails | (a) OP signed-out page rendered; (b) normal 303 to the RP (owner, 2026-10-27; `ten.md` §4 aligned with §3.3); both: Visa cookies cleared; stop and participants durable; the sweep later enqueues delivery | Request and boundary tests | Passed — (a) post-commit ticket/gateway/configuration failures render the signed-out page and (b) an enqueue failure keeps the 303 to the RP (`evidence/2026-10-27-sign-out-quality-fixes-H8M2.md`, `evidence/2026-10-26-sign-out-so5-acceptance-G5P8.md`) |
| A14-11 | Two confirmation POSTs for one pending request | One stop; the second answers "already signed out" | Request and boundary tests | Passed (see `evidence/2026-10-26-sign-out-so5-acceptance-G5P8.md`) |
| A14-12 | Stored device session is no longer the browser's current one | 403; nothing stopped | Request and boundary tests | Passed (see `evidence/2026-10-26-sign-out-so5-acceptance-G5P8.md`) |
| A14-13 | Discovery and `sid` | Both BCL flags true; ID Token `sid` = grant `public_id` = Logout Token `sid`; encoding without `sid` raises | Request and boundary tests | Passed (see `evidence/2026-10-26-sign-out-so5-acceptance-G5P8.md`) |
| A14-14 | Removals | `/sign/bye`, `/sign/out/purge`, Auth `logout_challenge` not routed or refused; tables absent from the three `structure.sql`; no reference to removed constants (command check in evidence) | Request and boundary tests | Passed (see `evidence/2026-10-26-sign-out-so5-acceptance-G5P8.md`) |
| A14-15 | Realm isolation | APP sign-out leaves COM and ORG sessions; a COM hint at the APP OP refused | Request and boundary tests | Passed — `test/integration/oidc_current_device_logout_test.rb:63`; authenticated COM and ORG Warp dashboard requests return 200 before and after APP RP logout and Visa confirmation |
| A14-16 | RP completion | Once; reload 404; 404 while a session is active; `state` mismatch refused | Request and boundary tests | Passed (see `evidence/2026-10-26-sign-out-so5-acceptance-G5P8.md`) |
| A14-17 | Refresh or rotation racing the stop | Refresh after COMMIT refused; a rotation committed first is stopped with the device session (A14-5a lineage) | Request and boundary tests | Passed — `test/concurrency/oidc_logout_rotation_acceptance_test.rb:87`; each realm rotates on one database connection, stops on a distinct connection, then refuses refresh after commit and stops both roots/device/grant |
| A14-18 | Old sign-out's return after a new sign-in at that RP | 404; nothing destroyed | Request and boundary tests | Passed — `test/integration/oidc_rp_logout_registered_rp_matrix_test.rb:169`; real APP authorization-code issuance/exchange and RP callback establish new cookies; old completion returns 404 preserving cookies and root |

### WU-17 — Activation and `contract_epoch` removal

| ID | Case | Expected | Verification | Status |
|---|---|---|---|---|
| A17-1 | Code exchange, refresh, identity stop | Work without epochs | Tests | Passed (token exchange and identity-stop tests in full suite) |
| A17-2 | Root with `authentication_epoch` 0 and a cutoff ≥ 1 | Refused by the identity stop | Test | Passed (existing identity-stop Refresh test) |
| A17-3 | `umx_contract_epoch` claim, `OpClientAdmissionGate`, activations | Absent | Command + tests | Passed (grep app/lib/config empty; verifier and exchange tests) |
| A17-4 | Bulk update NULL → 0 and column drops | Owner approval recorded before execution | Evidence | Not applicable (D-159: database reset) |

### WU-24 — E1, effective intent, curfew storage

| ID | Case | Expected | Verification | Status |
|---|---|---|---|---|
| A24-0 | WU-24a classification | Counts per query and the cross-DB matrix recorded per environment, with read times; no write | Evidence | Not applicable (D-159: database reset) |
| A24-1 | `authentication` Admission on a sign-up page or action | Refused (ownership/definitive per class); sign-up only via Switch or `prompt=create` | Request tests (app, com) | Passed (I4B6; unit gates remain open) |
| A24-2 | Binding issuance | `curfew_at` = OP DB issuance time + 30 min, immutable; Switch Binding copies it. **Storage only:** consumers still use the old checks until WU-06, so "continues after 60 s within the curfew" is accepted in A06-*, not here | Tests | Passed, storage only (C7D4; consumer enforcement is WU-06) |
| A24-3 | Flow ↔ Binding | Every new Sign-up Flow has its Binding; second in-progress Flow for one Binding refused (separate connections) | Tests | Passed scoped ownership/DB/insert-race verification (H8P2) |
| A24-4 | Stale tab with another attempt's locator | Ownership mismatch; nothing consumed | Request test | Passed APP/COM HTTP hints, URLs and nonces over four verbs with CSRF enabled (H8P2) |
| A24-5 | Migrations WU-24c/d | Rollback tested in development and recorded | Evidence | Passed on empty development tables (C7D4; global drift check failed) |
| A24-5a | Before WU-24f | Owner approval with counts, expected effect, zero registered principals affected, backup location + SHA-256 | Evidence | Not applicable (D-159: database reset) |
| A24-5b | Before WU-24g | Owner approval; Q3 = 0 | Evidence | Not applicable (D-159: database reset) |
| A24-5c | Before WU-24h | Owner approval with the remaining Flow count and the backup | Evidence | Not applicable (D-159: database reset) |
| A24-6 | `entry_intent` after WU-24d (D-157, D-159) | No NULL; Sign-in path rows `sign_in`/`sign_up` per the parent's `prompt`; Re-verification rows `not_applicable`; `sign_in` on a Re-verification purpose and `not_applicable` on a Sign-in path purpose rejected by the CHECK | Schema check + model test | Passed (C7D4; APP/COM/ORG model and database checks) |
| A24-7 | Cleanup decision (WU-24e) | A Flow whose principal reached the registered status between selection and lock is not touched; the decision is re-read under the principal lock | Concurrency test on separate connections | Passed (A6C4; real APP/COM principal-lock races) |
| A24-8 | After WU-24f | Re-run of WU-24a: no Flow with an unfinished principal remains; registered principal count unchanged | Evidence | Not applicable (D-159: database reset) |
| A24-9 | After WU-24g | Column, FK and both CHECK references gone on APP/COM/ORG; ceremony admission still works | Schema check + request tests | Passed (C7D4; WU-01 retirement reconciled with schemas and requests) |
| A24-10 | Binding purge with a Flow present | Refused by RESTRICT; the Purger deletes the Flow first | Test | Passed FK, retention/cleanup gates and child-first deletion without principal deletion (H8P2) |

### WU-25 — Revocation client authentication

| ID | Case | Expected | Verification | Status |
|---|---|---|---|---|
| A25-1 | Registered method per client (app, com, org) | Revocation works with it; other methods refused | Request tests | Not run |
| A25-2 | Wrong client / realm / audience / replayed assertion | Refused | Request tests | Not run |
| A25-3 | Discovery `revocation_endpoint_auth_methods_supported` | Equals the implemented set | Request test | Passed — tests mapped in `seven.md` stage 2 all green on 2026-10-27 (`evidence/2026-10-27-mapped-cases-run-M5Q8.md`) |

### WU-26 — Partial-registration diagnosis

| ID | Case | Expected | Verification | Status |
|---|---|---|---|---|
| A26-1 | Run against constructed partial states (six.md C.2 scenarios) | Correct classification per scenario; no secret value printed | Evidence (run) | Withdrawn (D-196) |
| A26-2 | Run with a writing role | Refuses to run | Evidence (run) | Withdrawn (D-196) |

### X-26 Red test (before any WU-05 Finalization work; then WU-34, D-106)

| ID | Case | Expected (target) | Verification | Status |
|---|---|---|---|---|
| AX26-1 | App and Com telephone sign-up abandoned after the passkey step (before birthdate); discoverable Passkey sign-in with that passkey | Refused; no Root Session, Grant or RP Session | Request test — expected to fail today (static reading), result recorded either way | Not run |
| AX26-2 | Email sign-up abandoned after OTP verification; email sign-in with that address | Refused | Request test (trace first) | Not run |

### WU-23 — Credentials / KMS docs

| ID | Case | Expected | Verification | Status |
|---|---|---|---|---|
| A23-1 | Listed ADR/docs | State D-15 and D-17; per-role design marked withdrawn | Diff | Passed — the three WU-23 documents state D-15/D-17 and mark the per-role design withdrawn (`evidence/2026-10-27-document-acceptance-group-3-D8R4.md`) |

### WU-12 — Automatic relays (Design D, D-100/D-101)

| ID | Case | Expected | Verification | Status |
|---|---|---|---|---|
| A12-1 | Happy path RP `POST /sign` → … → RP `/oidc/callback` on app/com/org | No Continue page rendered; only 303/GET between user steps | Request test with request-count assertion | Passed — tests mapped in `seven.md` stage 2 all green on 2026-10-27 (`evidence/2026-10-27-mapped-cases-run-M5Q8.md`) |
| A12-2 | Each continuation GET from another browser (no or foreign cookie binding) | Refused, nothing consumed (G-8) | Request tests per hop | Not run |
| A12-3 | Same bound browser repeats a **relay** hop (attach, confirm, redeem) at 9 s / 10 s / 11 s after issuance | At 9 s, same next redirect; at 10 s and 11 s, refused with 400 and no second effect or state change (D-101 absolute boundary). Does not apply to the final result GET (A12-6) | `test/integration/acceptance_wu12_relay_repeat_test.rb` | Passed |
| A12-4 | Repeat whose stored next-hop reference is consumed or expired | Refused, never re-minted | `acceptance_wu12_relay_repeat_test.rb`; `test/controllers/auth/ceremony_admission_boundary_test.rb` | Passed |
| A12-5 | HEAD, iframe (`Sec-Fetch-Dest: iframe`), missing Fetch Metadata | Refused before consumption for HEAD and a framed destination; a request without Fetch Metadata gets the non-consuming confirmation form (owner, 2026-10-27) | Request tests | Passed — HEAD and framed requests refused before consumption on Auth `/ceremony_bindings` (fixed 2026-10-27, `acceptance_wu12_relay_repeat_test.rb` A12-3), the Visa confirmation and Visa result/cancel/switch (evidence V8M2, D4K8); missing Fetch Metadata renders the non-consuming form (D-197) |
| A12-6 | Final result GET repeated after the Root Session exists | Error, no second Root Session (D-104) | `test/integration/oidc_initiated_sign_in_completion_test.rb` | Passed |

### WU-13 — Cancel and Switch (D-38, D-39, D-100)

| ID | Case | Expected | Verification | Status |
|---|---|---|---|---|
| A13-1 | Cancel from a Sign-in page and a Sign-up page on app/com/org, end to end through `/oidc/cancellation` | OP ends ceremony and parent and redirects to the registered `redirect_uri` with `access_denied` + the unchanged `state` + `iss`; the RP (WU-43) lands on `GET /sign/interruption`; no session; Sign-up Flow cancelled | Request tests (after WU-43) | Not run |
| A13-5 | OP Cancel response | No other parameter added; `state` byte-identical to the request; nothing read from `state` | Request test | Passed — `evidence/2026-10-27-cycle-partial-boundaries-C4S9.md` |
| A13-2 | Switch Sign In → Sign Up on app/com | Fresh Admission, same parent, original deadline kept (D-74), lands on the target entry; **after WU-29** on the target's Sentry path (re-checked by A29) | Request tests | Passed — tests mapped in `seven.md` stage 2 all green on 2026-10-27 (`evidence/2026-10-27-mapped-cases-run-M5Q8.md`) |
| A13-3 | ORG Switch | Not routable | Request test | Not run |
| A13-4 | `/oauth/authorize` with `cancellation_ref` / `switch_handoff` | Rejected with 400 before any transaction or binding is allocated (D-38) | `test/integration/acceptance_wu13_authorize_unrelated_params_test.rb` | Passed |

### WU-15 — Back-Channel Logout (D-117, D-118, D-121)

| ID | Case | Expected | Verification | Status |
|---|---|---|---|---|
| A15-1 | Stop with N participants | N outbox rows committed with the revocation in one transaction | `OpAuthorityStopCommitterTest` | Passed (see `evidence/2026-10-26-sign-out-so5-acceptance-G5P8.md`) |
| A15-2 | Enqueue fails or the process restarts after COMMIT | The sweep re-enqueues; every row reaches 200, 400 or the BX-10 deadline | `OpAuthorityStopConcurrencyTest`, `OpOutboxDispatchJobTest` | Passed — `test/integration/oidc_logout_enqueue_failure_test.rb:65`; after enqueue failure the recurring task enqueues OpOutboxDispatchJob, which delivers the durable participant sid and acknowledges it |
| A15-3 | Receiver answers 200 / 204 / 400 / 5xx / timeout | done / done / permanent / retry / retry | Adapter and outbox job tests | Passed (see `evidence/2026-10-26-sign-out-so5-acceptance-G5P8.md`) |
| A15-4 | `POST /oidc/closures` from a server client with no browser User-Agent and no cookies | Accepted on a valid Logout Token; no `allow_browser`, CSRF or session involved | `RpBackchannelLogoutReceiverTest` | Passed — `test/integration/rp_backchannel_logout_receiver_test.rb:38`; valid Logout Token with no User-Agent or request cookies returns 200, writes one receipt and revokes the named local session and binding |
| A15-5 | Invalid signature, wrong `aud`, `nonce` present, missing `events` | 400; JWKS/key unavailable → 503 (BX-7) | `RpBackchannelLogoutReceiverTest`, `RpBackchannelLogoutJwksOutageTest` | Passed — `test/integration/rp_backchannel_logout_receiver_test.rb:103`; nonce, missing/wrong events and absent sid/sub return 400 without receipt or revocation; APP/COM/ORG share RpBackchannelLogoutEndpoint and OidcOpLogoutTokenVerifier |
| A15-6 | RP answers 401/403 (WAF challenge) / 404/405/410 / 413 / 429 (BX-4) | transient + alert / permanent misconfiguration + alert / per BX-4 table / transient | `OpOutboxDispatchJobTest` | Passed — `test/jobs/op_outbox_dispatch_job_test.rb:105`; each 401/403/404/405/410/413 outcome emits exactly one error-level delivery event naming client and outcome |
| A15-7 | RP URL resolving to private, loopback, link-local or metadata addresses; redirect from the RP | Refused at connection time; no redirect followed (D-30 requirements) | Connection adapter and dispatch tests | Passed — `test/lib/outbound_http/connection_adapter_port_test.rb:40`, `test/adapters/oidc_backchannel_logout_client_test.rb:24`; non-public addresses refused, public IPv6 pinned, redirects not followed |
| A15-8 | Late BCL arriving after a new sign-in at that RP | Only the session with the token's `sid` closes; the new session survives | `RpBackchannelLogoutReceiverTest` | Passed (see `evidence/2026-10-26-sign-out-so5-acceptance-G5P8.md`) |
| A15-9 | BCL arriving before the RP's callback for that `sid` completed | No session created afterwards for that `sid` (receipt recorded and checked at callback) | `RpBackchannelLogoutReceiverTest` | Passed (see `evidence/2026-10-26-sign-out-so5-acceptance-G5P8.md`) |
| A15-10 | Two workers lease the same outbox row | One delivery attempt per lease; no double send counted as two acknowledgments | `OpAuthorityStopConcurrencyTest`, `OpOutboxDispatchJobTest` | Passed (see `evidence/2026-10-26-sign-out-so5-acceptance-G5P8.md`) |
| A15-11 | Row past the BX-10 deadline; retention of finished rows | Marked expired, not retried; finished rows purged per retention, never before a final state | `OpOutboxDispatchJobTest`, `OpAuthorityStopPurgerTest` | Passed (see `evidence/2026-10-26-sign-out-so5-acceptance-G5P8.md`) |

### WU-16 — One OP authority-stop primitive

| ID | Case | Expected | Verification | Status |
|---|---|---|---|---|
| A16-1 | Root, grant and principal stops in APP | Cause/scope rules hold; a grant stop preserves its root and sibling grant; a principal stop records cutoff and target roots; missing authority is refused | `OpAuthorityStopCommitterTest` | Passed (see `evidence/2026-10-26-sign-out-so5-acceptance-G5P8.md`) |
| A16-2 | Same idempotency key and simultaneous root stops | One durable stop; replay writes no targets or participants again | `OpAuthorityStopCommitterTest`, `OpAuthorityStopConcurrencyTest` | Passed (see `evidence/2026-10-26-sign-out-so5-acceptance-G5P8.md`) |
| A16-3 | Stop writers across the touched code | The committer is the sole OP root/grant revocation writer; actor-side Zenith risk event remains before OP stop | `OpAuthorityStopSingleWriterInvariantTest`, logout/risk tests | Passed — `test/controllers/concerns/authentication/logout_current_session_test.rb:135`; observed SQL inserts Zenith identity event before OP stop during real principal risk revocation; sole-writer invariant also passes |
| A16-4 | Identity stop encounters a legacy-revoked root with live grants | Live grants are repaired and have durable stop targets and participants | `OpIdentityEventInvalidatorTest` | Passed (see `evidence/2026-10-26-sign-out-so5-acceptance-G5P8.md`) |
| A16-5 | Three-realm foreign keys and schema contract | Each realm has restrictive target FKs and required stop fields; no dangling target survives fixture loading | Schema dump and focused DB tests | Passed — `db/op_base_app_structure.sql:4341` (and COM/ORG equivalents); live test catalog matches all 30 restrictive validated FKs, no dangling targets; every stop/child field NOT NULL and matches the dumps |

### WU-22 — Sign-out records, bindings, model rules, deletion contract

| ID | Case | Expected | Verification | Status |
|---|---|---|---|---|
| A22-1 | — | Retired (models removed) | — | Retired |
| A22-2 | Stop retention and participant completion | Pending participants or ineligible roots prevent purge; eligible final stops purge children before the stop | `OpAuthorityStopPurgerTest` | Passed (see `evidence/2026-10-26-sign-out-so5-acceptance-G5P8.md`) |
| A22-3 | Delayed or early BCL around callback and a newer sign-in | Old `sid` logout preserves a newer session; early logout tombstone prevents late callback enrollment | `RpBackchannelLogoutReceiverTest` | Passed (see `evidence/2026-10-26-sign-out-so5-acceptance-G5P8.md`) |
| A22-4 | Full sign-out safety across WU-14, browser completion and concurrent login/logout | G-16 invariants remain true across all paths and three realms | G-16 request/browser acceptance | Passed at the request/concurrency level — every G-16 case (A14-1 … A14-18, A15-3, A44-6, A44-10) is Passed and the sign-out set re-ran green after the 2026-10-27 changes (21 files, 261 runs, 0 failures); the browser part is the owner's manual check, deferred (`nine.md` BL-14) (`evidence/2026-10-27-a22-4-sign-out-safety-S9K5.md`) |

### WU-18 — Pre-R5 OP-chain removal (D-108)

| ID | Case | Expected | Verification | Status |
|---|---|---|---|---|
| A18-1 | Inventory | Every caller, route, table and test listed before deletion | Evidence | Deferred — WU-18c … 18f are held for a later cycle (D-175, D-195) |
| A18-2 | After removal per surface | Standard-RP path tests green; no flag or switch selects between two authorities | Test run + grep | Deferred — WU-18c … 18f are held for a later cycle (D-175, D-195) |
| A18-3 | Table drops | Not a gate (D-168) | — | Not applicable (D-159, D-168) |

### WU-19 — One bundle per language (D-113)

| ID | Case | Expected | Verification | Status |
|---|---|---|---|---|
| A19-1 | Duplicate key with different text | Test fails | Locale test | Passed — `test/initializers/locale_bundle_integrity_test.rb`, `locale_test.rb` (18 runs, 0 failures; `evidence/2026-10-27-cycle-records-reconciliation-R2D5.md`) |
| A19-2 | Key present in `en` but missing in `ja` (and the reverse) | Test fails | Locale test | Passed — `test/initializers/locale_bundle_integrity_test.rb`, `locale_test.rb` (18 runs, 0 failures; `evidence/2026-10-27-cycle-records-reconciliation-R2D5.md`) |
| A19-3 | Same page with `ri=jp` and `ri=us` | Same text for the same language | Request tests | Not run |

### WU-20 — Passkey identifier-first (D-112, D-116)

| ID | Case | Expected | Verification | Status |
|---|---|---|---|---|
| A20-1 | APP/COM sign-in: identifier → Passkey of the same Identity | Success; `allowCredentials` empty or omitted | Request test | Passed (request tests) |
| A20-2 | Passkey of another Identity after identifier selection | Refused; no session | Request test | Passed (COM request test) |
| A20-3 | Register the 9th / 10th / 11th Passkey | Accepted / accepted / refused | Request tests (boundary) | Passed (existing operation test) |
| A20-4 | Two concurrent registrations at 9 existing | At most one succeeds | Separate-connection test | Passed (existing concurrency test) |
| A20-5 | ADR-PK V1: missing, empty, malformed identifier; unknown, unverified, released, expired, ambiguous binding | Refused before any credential is accepted; cannot authenticate later (added per seven.md #17) | APP/COM request tests + resolver test | Passed for reachable partitions; mixed email/telephone ambiguity is unreachable under current normalizers and effective-binding uniqueness; resolver fails closed for multiple owners (evidence W20A) |
| A20-6 | ADR-PK V2: disabled, revoked, deleted, unknown and foreign-surface credentials; each valid Passkey of A alone | Refused / each succeeds | APP/COM request tests | Passed (evidence W20A) |
| A20-7 | ADR-PK V3: existing vs unknown identifier | Indistinguishable status, shape, size, redirects and cookie behavior; no real descriptors disclosed | APP/COM request tests + 200 alternating timing samples per case | Passed; local timing sample recorded in evidence W20A |
| A20-8 | ADR-PK V4: reuse, expiry boundary, wrong purpose, RP ID, Origin, userHandle, signature, UP, UV; concurrent resubmission | Refused; at most one sign-in; loser keeps the winner's session | APP/COM request tests, WebAuthn unit tests, two-connection HTTP concurrency test | Passed (evidence W20A) |
| A20-9 | ADR-PK V5: ORG Normal unchanged; Standby by Employee Number, cannot Step-Up or become Normal | As stated | ORG Normal, Emergency and Step-Up request tests | Passed: Normal/Standby separation and Step-Up refusal pass (evidence W20A); the Employee Number is `Operator.public_id` (owner decision, 2026-10-26), which is what the selection uses |
| A20-10 | Contact owner changes between identifier selection and verification | Refused; transaction fixed to the selected Identity | APP/COM request tests | Passed (evidence W20A) |
| A20-11 | Registration options on APP, COM and ORG (every registration entry: sign-up telephone, registration for a signed-in Identity, Base management) | `user.name` and `user.displayName` contain no Email, Telephone, Employee Number, Entra identifier or user handle; `residentKey` required (D-171) | Request tests per entry and surface + Base management integration test | Passed (evidence W20A) |
| A20-12 | ORG registration with a non-discoverable credential or without UV | Refused; nothing stored | ORG registration request test | Passed, including missing/false `rk`, UV=false and positive `rk=true`/UV=true control (evidence W20A) |
| A20-13 | `docs/security/passkeys.md` | Exists with sections (a) … (f) of `two.md` WU-20; every route of `bin/rails routes` matching `passkey` appears in section (a); the older WebAuthn pages are merged or point to it | Command output + document review | Passed (docs/security/passkeys.md) |

### WU-21 — RP return target — retired (D-162)

WU-21 is merged into WU-43 (D-151). Cases A21-1 … A21-8 are retired; the behavior is accepted by
A43-6, A43-8, A43-9, A43-12 … A43-15 and A43-18 … A43-21. Do not implement tests for A21 IDs.

### WU-27 — Post-containment journey (D-104)

| ID | Case | Expected | Verification | Status |
|---|---|---|---|---|
| A27-1a | Lost response after the auth cookies arrived, then repeat | Error; no reissue | Request test | Not run |
| A27-1b | Lost response before the auth cookies arrived (D-130) | Browser not signed in; a new sign-in succeeds; the orphan Root Session is not reused and is removable through session-limit remediation | `test/controllers/base/oidc_result_browser_binding_test.rb:151` | Passed — real `GET /oauth/authorize` setup (`evidence/2026-10-26-acceptance-a27-a34-test-repairs-K4T7.md`); re-run 2026-10-27: 3 runs, 0 failures |
| A27-2 | Then RP 続行 | SSO code from the existing Root Session; no new Root Session | Request test | Passed — tests mapped in `seven.md` stage 2 all green on 2026-10-27 (`evidence/2026-10-27-mapped-cases-run-M5Q8.md`) |
| A27-3 | Two tabs started in one browser | OP side: each completes or errors on its own bindings; at most one Root Session. RP side (D-155): only the last-started tab completes | OP `oidc_result_browser_binding_test.rb:270`; RP `oidc/sso_initiator_test.rb:161` | Passed |
| A27-4 | TR G2/G5 tests and G3 Sign-in path cases | Each rewritten with a stated reason or fixed; none deleted silently (G-3) | Diff + test run | Not run |

### WU-29 — Sign entry Sentry (D-84 … D-99)

| ID | Case | Expected | Verification | Status |
|---|---|---|---|---|
| A29-1 | Resolver: each of six pairs × `true` / `false` / unwritten | ALLOWED / BLOCKED / BLOCKED | Unit test | Passed — tests mapped in `seven.md` stage 2 all green on 2026-10-27 (`evidence/2026-10-27-mapped-cases-run-M5Q8.md`) |
| A29-2 | Resolver: unknown surface or flow | `ArgumentError` | Unit test | Not run |
| A29-3 | Sentry GET ALLOWED / BLOCKED | 303 to the fixed entry with only the Admission reference / 503 + `no-store`, no flow created | Request tests per surface × flow | Passed — tests mapped in `seven.md` stage 2 all green on 2026-10-27 (`evidence/2026-10-27-mapped-cases-run-M5Q8.md`) |
| A29-4 | Direct admitted-entry GET, `POST /sign/in`, `POST /ceremony_bindings`, one continuation POST per method, one provider callback (Google, Entra) while BLOCKED | Refused with 503; at most one redirect hop that creates and changes nothing may precede the refusal; no evidence, Flow, binding or registration | `test/integration/acceptance_wu29_sign_entry_sentry_blocked_test.rb` | Passed |
| A29-5 | Root-login commit while Sign In BLOCKED | Refusal status; no token, cookie or login audit; flow not HALTED | Request test | Passed — tests mapped in `seven.md` stage 2 all green on 2026-10-27 (`evidence/2026-10-27-mapped-cases-run-M5Q8.md`) |
| A29-6 | Sign Up completes while Sign In BLOCKED | Identity persists; no session | Request test | Passed — tests mapped in `seven.md` stage 2 all green on 2026-10-27 (`evidence/2026-10-27-mapped-cases-run-M5Q8.md`) |
| A29-7 | Flag flipped between two requests of one flow | Second request observes the new state | Request test | Passed — tests mapped in `seven.md` stage 2 all green on 2026-10-27 (`evidence/2026-10-27-mapped-cases-run-M5Q8.md`) |
| A29-8 | While BLOCKED: authenticated page, Refresh, Step-Up ticket, `prompt=none`, SSO code | Unaffected | Welcome and Step-Up targeted tests passed; Sign Out remains excluded by the task constraint | Passed — `test/integration/acceptance_wu29_sentry_toggle_test.rb:63`; both APP Sentries blocked while authenticated page, real Refresh and Passkey Step-Up completion succeed; Sign Out excluded |
| A29-9 | ORG Emergency while `sign_in_available_org=false`; ORG invitation while `sign_up_available_org=false` | Emergency works; invitation refused | Emergency Passkey and invitation controller tests | Passed |
| A29-10 | `grep -rn "sign_up_suspended\|SignUpSuspension" app config test` after the change | No match (D-97) | Command output | Passed — no code reference; unused frontend `suspended_notice` prop reported (`evidence/2026-10-27-command-acceptance-group-2-C6G3.md`) |
| A29-11 | Six flags written `true` per environment before enforcement | `feature_flags:status` recorded | Evidence | Passed for development — `bin/rails feature_flags:status`: all six `sign_{in,up}_available_{app,com,org}` on (2026-10-27); production belongs to `docs/backlog/2026-10-26-pre-deployment-checks.md` (`evidence/2026-10-27-non-test-acceptance-T2F6.md`) |
| A29-12 | BLOCKED response content (D-169) | 503, `Cache-Control: no-store`, no `Retry-After`; ja/en text per D-169 for Sign In and Sign Up; no reason; exactly one reason-coded log event with surface, flow and state and no reference value; no audit or telemetry record written | Request tests + formatted log assertion | Passed — the refusal text follows `lx` (fixed 2026-10-27); `test/integration/sign_entry_sentry_test.rb` A29-12 cases pass |

### WU-30 — Security Mode migration (D-88, D-92)

| ID | Case | Expected | Verification | Status |
|---|---|---|---|---|
| A30-1 | Approval | Row counts per realm, risk and recovery plan approved before migrating | Evidence | Not applicable (D-159: database reset) |
| A30-2 | After migration | APP/COM all `NORMAL=3`; ORG all `ADVANCED=7`; no other value | Query output | Passed — development after `db:migrate:reset` + seed: APP `Client` security_mode_id {3: 2}, ORG `Operator` {7: 1}, COM no rows; no other value (`evidence/2026-10-27-non-test-acceptance-T2F6.md`) |
| A30-3 | Actor with mode `0`, `5`, unknown or `NULL` (constructed) | Neither authentication nor authorization | Request tests | Not run |
| A30-4 | APP/COM `ADVANCED` sign-in by email OTP, TOTP, social without passkey | Refused; passkey succeeds | Request tests | Not run |
| A30-5 | `ADVANCED` passkey deletion 3 → 2 / 2 → 1 | Allowed after required auth / refused | Request tests | Not run |
| A30-6 | ORG Operator with one passkey after migration (D-132) | Signs in; every action except passkey registration and sign-out refused until a second passkey exists | Request tests | Not run |
| A30-7 | ORG Operator with zero passkeys | Ordinary sign-in impossible; no bypass | Request test | Not run |

### WU-31 — Email OTP `already_verified` (D-89)

| ID | Case | Expected | Verification | Status |
|---|---|---|---|---|
| A31-1 | Same ceremony, second `update` with a different code in the result window (APP, COM) | Result recorded either way | Request test | Not run |
| A31-2 | Another admitted ceremony submits for the same account | Refused (ADR A); result recorded either way | Request test | Not run |
| A31-3 | Two concurrent correct submissions | ≤ 1 evidence record, no second session; result recorded either way | Separate-connection test | Not run |

### WU-32 — ORG halt audit (D-90)

| ID | Case | Expected | Verification | Status |
|---|---|---|---|---|
| A32-1 | Stale-generation binding POST (C6R2 reproduction) | 409, HALT, exactly one `SIGN_FLOW_HALTED`, no token/challenge | Request test | Not run |
| A32-2 | Replay of the same POST | No second record | Request test | Not run |
| A32-5 | Two concurrent halting requests; a lost response after the Chronicle commit, then a repeat | Exactly one `SIGN_FLOW_HALTED`; the duplicate insert is rejected by the partial unique index and treated as recorded (D-134) | Separate-connection request tests | Not run |
| A32-3 | Chronicle write fails | No success reported; failure observable | Request test with failing write | Not run |
| A32-4 | Record content | No secret, token, code or contact value | Test assertion | Not run |

### WU-33, WU-35 — Investigations (D-91, D-107)

| ID | Case | Expected | Verification | Status |
|---|---|---|---|---|
| A33-1 | Failure convergence table | Every surface × method × outcome cell filled with file/line, D-73 class and HTTP result | Document review | Passed — `two.md` §5.4.1 lists every APP/COM/ORG sign-in method with file:line, result path, HTTP status and D-73 class; gaps recorded there (APP Secret and ORG Entra collapse to 422, COM/ORG Passkey bypass the committer) (`evidence/2026-10-27-a33-a39-completion-W5B1.md`) |
| A35-1 | Lock inventory | Every Sign-up/Sign-in/Finalization/Cleanup acquisition listed with file, DB, order and classification (two.md 6.2) | Document review | Passed — `two.md` §6.2 lists the in-scope acquisitions with file, DB, order and classification; refresh, logout, revocation and avatar paths are outside its stated scope (`evidence/2026-10-27-document-acceptance-group-3-D8R4.md`) |
| A35-2 | F-1 (if approved): replayed termination vs cleanup job on one Flow; APP telephone passkey save vs termination | Both complete without a cross-DB wait cycle (both take the Flow first); Red before the fix | Concurrency test on separate connections with a bounded wait | Passed — `test/concurrency/sign_up_secret_lock_order_test.rb:83`; real retention job holds Flow while waiting on principal and replay waits on Flow; both complete after release, terminal state retained and cleanup runs once |
| A35-3 | F-2 (WU-24e): cleanup fails after deleting the contact, then retries | The retry removes the remaining pending passkey and principal; cleanup is not marked completed early; a registered principal is never touched | Job test with a real failing write | Passed (A6C4; APP/COM real retention failure, rollback and retry) |

### WU-34 — Unfinished registrations refused (D-106)

| ID | Case | Expected | Verification | Status |
|---|---|---|---|---|
| A34-1 | AX26-1 / AX26-2 after the change | Refused; no Root Session, Grant or RP Session | Request tests | Not run |
| A34-2 | Each method (OTP, Passkey, Secret, social, TOTP) for a pre-Finalization Client/Visitor | Refused | APP email/social and TOTP cases passed; APP Secret fixed and passing (A-7, `evidence/2026-10-27-a7-secret-claim-unfinished-registration-T5W8.md`); APP Email OTP and Passkey also refused before any write (A-7 follow-up); COM cases out of cycle (D-194) | Passed for APP (Secret, Email OTP, Passkey fixed and tested 2026-10-27, evidence T5W8; social and TOTP passed earlier); COM out of cycle (D-194) (`evidence/2026-10-27-a38-a34-mapping-J4P2.md`) |
| A34-3 | A Finalized Identity | Signs in as before | Request tests | Not run |
| A34-4 | COM candidate creation and Finalization (D-128) | Visitor created `UNVERIFIED_WITH_SIGN_UP`, promoted at Finalization; existing COM data migrated with recorded counts | Request tests + evidence | Not run |
| A34-5 | Failure after the principal's registered commit (graph or OP Flow completion fails, D-131) | Registered: Sign In admits; graph completed at the next sign-in; not deleted by cleanup | Request/job tests | Passed — tests mapped in `seven.md` stage 2 all green on 2026-10-27 (`evidence/2026-10-27-mapped-cases-run-M5Q8.md`) |

### WU-36 — Host-only cookies (D-115)

| ID | Case | Expected | Verification | Status |
|---|---|---|---|---|
| A36-1 | Every `Set-Cookie` and every cookie deletion from authentication, preference, withdrawal and enforcement-recovery paths | No `Domain`, no `Partitioned` (P-141: no legacy Domain-cookie deletion exception; if the owner rejects P-141 this case gains the enumerated exception) | Request tests | Moved to `docs/backlog/2026-10-26-pre-deployment-checks.md` (D-194) |
| A36-2 | `grep -rn "CoreCookieDomain" app lib config` | No match | Command output | Moved to `docs/backlog/2026-10-26-pre-deployment-checks.md` (D-194) |

### WU-37 — Puma (D-120)

| ID | Case | Expected | Verification | Status |
|---|---|---|---|---|
| A37-1 | Load estimate and chosen workers/threads/DB pool | Recorded with the reasoning | Evidence | Moved to `docs/backlog/2026-10-26-pre-deployment-checks.md` (D-194) |
| A37-2 | Under the estimated concurrent sign-in load | Measured concurrent requests, RP→OP self-call latency/timeouts and DB connection use recorded; saturation is not claimed to be impossible (D-120) | Evidence | Moved to `docs/backlog/2026-10-26-pre-deployment-checks.md` (D-194) |

### WU-38 — Partial registrations (D-126 (2), D-135)

| ID | Case | Expected | Verification | Status |
|---|---|---|---|---|
| A38-1 | New sign-up with a contact held by an unfinished registration before its cleanup | Refused; old data untouched (D-135) | Request test | Passed — `test/integration/sign_up_contact_hold_refusal_test.rb` (APP/COM email and telephone: 422, no Client/contact created, held contact and owner unchanged) (`evidence/2026-10-27-a38-a34-mapping-J4P2.md`) |
| A38-2 | Same after the deadline and the cleanup run | Accepted as a new registration | Request + job test | Passed by composition — `test/jobs/sign_up_curfew_cleanup_test.rb` (cleanup at/after the curfew sets the contact DELETED and releases the hold) + `sign_up_contact_hold_refusal_test.rb` "starts once cleanup has retired the held address" (new registration accepted); no single end-to-end journey (`evidence/2026-10-27-a38-a34-mapping-J4P2.md`) |
| A38-3 | Flow past its deadline without Finalization | Cleanup deletes its unfinished data | Job test | Passed — `test/jobs/sign_up_curfew_cleanup_test.rb` (one second before: held; at/after the curfew: Flow EXPIRED, cleanup completed, contact DELETED, owner discarded; APP and COM) (`evidence/2026-10-27-a38-a34-mapping-J4P2.md`) |
| A38-4 | Finalized Identity with the same contact | Never deleted by either path | Request/job tests | Passed — curfew path: `sign_up_curfew_cleanup_test.rb` "a registered identity behind an expired Flow is never touched"; terminal-Flow cleanup path: `sign_up_artifact_cleanup_atomicity_test.rb` "APP active and verified registrations survive" / "COM verified contact survives" (`evidence/2026-10-27-a38-a34-mapping-J4P2.md`) |

### WU-42 — `redirect_uri` conformance (D-145)

| ID | Case | Expected | Verification | Status |
|---|---|---|---|---|
| A42-1 | Authorize with the registered `redirect_uri` per realm | Code issued; response URL equals the registered string + response parameters | Request test | Not run |
| A42-2 | Unregistered URI; differing scheme / host / port (`:443` written explicitly, `:3001`) / path (trailing slash, case) / added query / fragment; URI of another realm; missing | 400 rendered locally; no `Location` header; nothing issued | Request tests (one per partition) | Not run |
| A42-3 | Invalid `redirect_uri` together with another error (bad scope, missing `state`) | Still no redirect to the URI | Request test | Not run |
| A42-4 | Token request: code exchanged by another client; `redirect_uri` differing in one character; `redirect_uri` omitted | `invalid_grant`, HTTP 400 (N-3, RFC 6749 §5.2); code not usable afterwards per the existing single-use rule | Request tests | Not run |
| A42-4b | Token request with a wrong `code_verifier` / without `code_verifier` | `invalid_grant` (RFC 7636 §4.6) / `invalid_request` | Request tests | Not run |
| A42-5 | Client store with a registered URI carrying a fragment, `http` in production, or a reserved query key | Boot fails | Evidence (run), not Minitest | Not run |
| A42-6 | Jump-forwarded authorize request (D-146: accepted risk until then) | `redirect_uri` byte-identical at `/oauth/authorize`; authorization succeeds through Jump | **Jump integration test** (with A02-14); not part of WU-42's acceptance — WU-42 records it as Not run (reason: Jump integration pending) | Not run |
| A42-7 | PKCE, realm separation, code single use, `state`/`nonce`, OIDC session | Existing suites green | Test run | Not run |
| A42-8 | Valid client and `redirect_uri`, then one representative per row of the N-1 table | 302/303 to the registered `redirect_uri` with the listed `error`, `iss`, and `state` only when sent | Request tests (one per row) | Not run |
| A42-9 | Unknown `client_id`; valid client with an unregistered `redirect_uri`; either combined with a later error | Local HTML 400, no `Location` | Request tests | Not run |
| A42-10 | Registered URI with a query (constructed client) | Response keeps the registered query unchanged and appends `code`, `state`, `iss` | Unit test of the public builder | Not run |
| A42-13 | `code_challenge` of 42 / 43 / 44 characters, with `=` padding, with a `+` or `/` | 43 base64url characters accepted; every other shape `invalid_request` (N-6) | Request tests (boundary) | Not run |
| A42-11 | Discovery per realm (D-148) | APP/COM `prompt_values_supported` = `none`, `login`, `create`; ORG = `none`, `login`; equal to the resolver's accepted set | Request test | Not run |
| A42-12 | `prompt=consent`, `select_account`, an unknown value, ORG `create`, and combinations (`none login`, `login create`) | `invalid_request` with an `error_description` naming `prompt`, direct HTTP 400 from the OP, no `Location` (D-148) | Request tests | Not run |

### WU-43 — ES384 JWS `state` (D-149)

| ID | Case | Expected | Verification | Status |
|---|---|---|---|---|
| A43-1 | `state` issued and verified by the same RP | Valid | Unit test | Not run |
| A43-2 | `alg` `none`, HS256, RS256, ES256; header `alg` ES384 with a payload signed otherwise | Refused | Unit tests (one per algorithm) | Not run |
| A43-3 | Tampered payload or signature; unknown `kid`; `kid` of another RP's key | Refused | Unit tests | Not run |
| A43-4 | Wrong `typ`, `iss`, `aud`; missing `jti`/`iat`/`exp`/`v` | Refused | Unit tests | Not run |
| A43-5 | Client assertion presented as `state`; `state` presented as a client assertion at the token endpoint | Refused both ways | Unit + request tests | Not run |
| A43-6 | `exp` = `iat` + 30 min (D-150, D-160): 29:59 / 30:00 / 30:01 after `POST /sign` on the Rails clock; `iat` in the future beyond the leeway | Valid / refused / refused; refused | Unit tests with the injected Rails clock | Not run |
| A43-20 | RP `state` expired while the OP curfew is still open: the OP issues a code for a Sign In, and for a Sign Up | RP callback refused → `/sign/interruption`; no RP session or token. Sign Up: the Identity stays registered (D-131); a later 続行 signs in (SSO when a Root Session exists, D-104) | Request tests | Not run |
| A43-7 | Key rotated after issue, old public key retained / removed | Valid / refused | Unit tests | Not run |
| A43-8 | Valid `state` in another browser (no pending entry) | Refused; nothing consumed | Request test | Not run |
| A43-9 | **Intended behavior (D-155):** tab A `POST /sign`, then tab B `POST /sign`; B completes; then A completes every Auth step and the OP issues A's code | B accepted (RP session, target once). A's callback refused → 303 `/sign/interruption`; no RP session or token for A; no second Root Session; the test name and a comment state that A's late rejection is the designed outcome, not a defect | Request test | Not run |
| A43-9b | Same start order, but A completes first, then B | A refused at the callback (its entry was replaced at B's start); B accepted afterwards | Request test | Not run |
| A43-9d | **Best effort (owner: implement if feasible):** tab A Sign Up, then tab B Sign In with another existing account; B completes; A completes its Sign Up | B accepted; A's new Identity saved as registered; no session for A (refused at the OP or the RP); a later ordinary sign-in with A's account succeeds | Request test (Not run with a reason if not feasible) | Not run |
| A43-9e | Two **browsers** (separate cookie jars), same APP account with no active session, both sign in | Both accepted (APP limit 2); a third browser gets the session-limit flow; COM/ORG (limit 1): the second gets the session-limit flow | Request test with two jars | Not run |
| A43-9c | After `POST /sign` in two tabs | The RP cookie session holds exactly one pending entry (B's) | Request test asserting the session content | Not run |
| A43-10 | ID Token `nonce` mismatch; code reuse; PKCE mismatch | Refused (`nonce` at the RP; `invalid_grant` at the OP) | Request tests | Not run |
| A43-11 | CSRF enabled inside the test: `POST /sign` without / with a valid token; callback GET | Refused / accepted; callback unaffected | Request tests (CSRF switched on in the test only, per the ADR) | Not run |
| A43-12 | Target restored once after callback validation, code exchange and RP session; an external, protocol-relative or nested target refused → RP default page | As stated | Request tests | Not run |
| A43-13 | `target_link_uri` with a query, a fragment, `//host`, a dot segment, `%2f`, under `/sign` or `/oidc`; missing | Ignored → RP default page after sign-in; sign-in itself proceeds | Request tests (one per partition) | Not run |
| A43-15 | Cancel during Sign In and during Sign Up, per RP (D-152) | `error=access_denied` with the same `state`; RP consumes the pending entry, ignores `target_link_uri`, 303 to `GET /sign/interruption` (D-153); no session; Sign-up Flow cancelled | Request tests (RP side with a constructed callback; end to end after WU-13) | Not run |
| A43-16 | Each D-153 case per RP: other OP error, unknown/expired/foreign `state`, missing pending entry, failed code exchange, bad ID Token or `nonce` | 303 to `/sign/interruption`; pending entry consumed when it existed; one reason-coded log event without token, code or state values; `login_required` instead starts a new interactive authorization | Request tests | Not run |
| A43-17 | `GET /sign/interruption` signed out / signed in / with any query | Same page, 200, `no-store`, no redirect, no session or DB write, no reason shown; text ja 「ログインできませんでした。再度ログインしてください。」 / en "Sign-in could not be completed. Please sign in again." (D-160 (4)) | Request tests per RP | Not run |
| A43-18 | Replay after success: the same callback (`state` + code), or the old RP session cookie re-sent (D-154) | No second redirect to the target; the code exchange fails; no second RP session | Request test | Not run |
| A43-19 | Logs and headers | No `state`, `target_link_uri`, code or token value in any log event; `GET /sign` answers with `Referrer-Policy: no-referrer` | Test on the formatted log event + response header | Not run |
| A43-21 | Auth's own `pt` lane after the RP `pt` removal (D-162 (3)) | Existing `AuthenticationRedirects` / Auth `sign_in_url_with_pt` tests unchanged and green; `grep -rn "oidc_pt" app` empty; the RP helper is `sign_in_url_with_target` | Test run + command output | Not run |
| A43-14 | Protected page with a query string | `target_link_uri` = path only; after sign-in the page opens without the query | Request test | Not run |

### WU-44 — Root issuance re-check and authoritative epoch (D-163, D-165)

| ID | Case | Expected | Verification | Status |
|---|---|---|---|---|
| A44-1 (R4-1) | Connection 1: `log_in` passes the early checks and is held before the actor lock; connection 2 commits an administrative lock (then a withdrawal suspend, then an operator stop); connection 1 continues | Today expected Red: a root with the new epoch is created and survives the invalidator. After the fix: refused, no root, no cookie, no audit of success | Separate-connection request/service test | Not run |
| A44-2 | Same, but the stop commits after the root insert | Root carries the old epoch; the invalidator revokes it and browser/Access authentication refuses it | `test/controllers/concerns/root_issuance_recheck_test.rb:63` | Passed — writer epoch and stop verified; evidence `evidence/2026-10-26-wu44-writer-check-N6K3.md` |
| A44-3 | Root and Access JWT issued; stop committed with the OP apply failing (queued); account restored before the apply | Old Access JWT, refresh, token exchange and browser root authentication refused (epoch); a root issued after the restore works; the delayed stop event does not revoke it | Service + request tests | Not run |
| A44-4 | Epoch read on the authentication boundary while the reading replica lags (constructed: replica shows the old epoch) | Decision uses the writer; refused | `test/services/oidc_access_token_authenticator_test.rb:77` | Passed — `test/services/oidc_access_token_authenticator_test.rb:77`; reading-role lookup returns epoch 0 while the writer holds 1; access and browser tokens are refused |
| A44-5 | Writer unavailable during the epoch read | Fail closed (dependency failure), no authentication | Test with an actual writer failure | Passed — `test/services/oidc_access_token_authenticator_test.rb:154`; writer failure propagates without a reader fallback, and `/oauth/userinfo` returns 503 |
| A44-6 | Single-root sign-out, token revocation and refresh reuse | Epoch unchanged; other browsers' roots unaffected (D-164) | `test/operations/wu44_root_epoch_revocation_contract_test.rb:8, 52, 108` | Passed — evidence `evidence/2026-10-26-wu44-writer-check-N6K3.md` |
| A44-7 | Static guard | Root tokens are created only in `create_login_token_record` | `test/security/invariants/root_token_creation_invariant_test.rb:15` | Passed — see `evidence/2026-10-26-wu44-remaining-acceptance-X9R2.md` |
| A44-8 | Epoch equality (D-165): root epoch equal / one lower / one higher than the actor's | Accepted / refused / refused (higher = corruption) | Unit test of the public predicate + one request test | Not run |
| A44-9 | Credential change (password/secret change, passkey removal) committing while a login with the old credential is held before the actor lock (D-167) | The login is refused under the lock, or its root is revoked by the transition; no surviving root from the old credential | Backlog: `docs/backlog/2026-10-26-credential-version-recheck-at-root-issuance.md` | Deferred — backlog |
| A44-10 | "Sign out other sessions" while another browser's login commits | The new session survives (point-in-time, D-167); sessions existing at the request are revoked | `test/concurrency/root_revoke_others_concurrent_login_test.rb:84` | Passed — fixed 2026-10-27: the revoker only revokes sessions created at or before its request time (`authentication_other_sessions_revoker_test.rb` "a session created after the revocation request survives"); the concurrency test `root_revoke_others_concurrent_login_test.rb:84` still has a setup defect (its two roots already fill the session limit) (`evidence/2026-10-27-codex-followups-review-N3C9.md`) |

### WU-41 — Effective database timeouts (D-142)

| ID | Case | Expected | Verification | Status |
|---|---|---|---|---|
| A41-1 | `SHOW lock_timeout` / `SHOW statement_timeout` on every connection (development, test) | The configured values, not 0 | Evidence (run) | Moved to `docs/backlog/2026-10-26-pre-deployment-checks.md` (D-194) |
| A41-2 | Full test run after the change | No new failure vs G-1, or each new one triaged and fixed with a reason | Evidence | Moved to `docs/backlog/2026-10-26-pre-deployment-checks.md` (D-194) |
| A41-3 | Retention, expiry and secret-lifecycle jobs once in development | Complete; durations recorded; no statement cancelled | Evidence | Moved to `docs/backlog/2026-10-26-pre-deployment-checks.md` (D-194) |

### WU-40 — Recovery OTP Turnstile (D-141)

| ID | Case | Expected | Verification | Status |
|---|---|---|---|---|
| A40-1 | APP and COM recovery send without a Turnstile token / with a failed token | Same page with an error and a new challenge; no OTP issued, no email sent, cooldown not consumed | Request tests per surface | Not run |
| A40-2 | Valid token, registered verified address / unknown address | OTP issued / dummy path; same response shape and timing protection as today | Request tests | Not run |
| A40-3 | Turnstile unreachable with degradation off / on | Refused / passes only under `TurnstileDegradation` rules; a missing or failed token still refused | Request tests | Not run |
| A40-4 | Verify branch (`pass_code`) without a Turnstile token | Behavior unchanged; no Turnstile required (D-156) | Request test | Not run |
| A40-5 | Recovery page render (APP, COM) | Visible Turnstile widget present on the address form only | Request test | Not run |

### WU-39 — ADR and documentation amendments

| ID | Case | Expected | Verification | Status |
|---|---|---|---|---|
| A39-1 | Each item in two.md WU-39 | Written, linked from `adr/README.md`, consistent with one.md decisions | Diff | Passed — each WU-39 item is written, linked from `adr/README.md`, and its decision values match one.md (18 checks: D-100/101, D-111, D-116/117/121, D-92, D-105, D-144 … D-155) (`evidence/2026-10-27-a33-a39-completion-W5B1.md`) |

### Sub-unit mapping (D-133)

Case IDs are unchanged; a sub-unit passes when its listed cases pass (two.md Part 4).

| Sub-unit | Cases |
|---|---|
| WU-01a / 01b | A01-5 (classification and re-pointing) |
| WU-01c | A01-1 |
| WU-01d | A01-2, A01-4 |
| WU-01e / 01f | A01-3, A01-6 |
| WU-02a | A02-3 |
| WU-02b | A02-2 |
| WU-02-APP / -COM / -ORG | per realm: A02-1, A02-4 … A02-9, A02-11, A02-13, A02-15, A02-16 (after 02-APP), G-15, G-16 |
| WU-02i | A02-10, A02-12, A02-14 (Not run), G-5 |
| WU-05a | A05-1, A05-5 |
| WU-42 | A42-1 … A42-7 |
| WU-43 | A43-1 … A43-21 |
| WU-06 | A06-1 … A06-9, G-9 |
| WU-44 | A44-1 … A44-10 |
| WU-41 | A41-1 … A41-3 |
| WU-40 | A40-1 … A40-4 |
| WU-24a | A24-0 |
| WU-24b | A24-1 |
| WU-24c | A24-2, A24-5 |
| WU-24d | A24-6, A24-5 |
| WU-24e | A24-7, A35-2, A35-3 |
| WU-24f | A24-5a, A24-8 |
| WU-24g | A24-5b, A24-9 |
| WU-24h | A24-5c, A24-3, A24-4, A24-10 |
| WU-05b | A05-2, A05-13 (intent) |
| WU-05c | A05-3, A05-4 |
| WU-05d | A05-6, A05-7, A05-12 |
| WU-05e | A05-8, A05-9, A34-5 |
| WU-05f | A05-10 |
| WU-05g | A05-11 |
| WU-18a | A18-1 |
| WU-18c / d / e | A18-2 per surface |
| WU-18f | A18-3 |

### Units not yet accepted for implementation

WU-28 is out of this cycle (D-170). WU-30 is authorized (D-168); A30-1 is no longer a gate.
WU-16 and WU-22 SO-3 follow `two.md` 5.8 v2 (accepted, D-172). The user explicitly directed local
implementation on 2026-10-25 before A44-1/A44-2 passed (D-166); the implementation is recorded in
§4, but this does not waive G-16 or close either prerequisite. The WU-16/22 cases below were added
as part of that scoped implementation; full acceptance remains open until the gates pass.

## 3. Standing checks

| ID | Check | When |
|---|---|---|
| S-1 | AUTH-19 with D-51: a foreign browser presenting an admission or result reference cannot confirm, redeem, be accepted or get a Root Session; a first attach before the victim is the accepted D-51 denial and is asserted to go no further | Every unit touching Admission, relays or result receipt (WU-02, WU-05, WU-06, WU-12, WU-13, WU-29) |
| S-2 | Sign In First: no Sign-up path issues a session directly; no Sign-in failure or Sentry refusal deletes a Finalized Identity | WU-02, WU-05, WU-29, WU-34, WU-38 |
| S-3 | Surface separation: no controller/route/session sharing across app/com/org; Auth com/org translation guard green | Every unit |
| S-4 | No database NULL with meaning introduced | Every unit with a migration |

## 4. Execution record

| Date | Commit | WU | Cases run | Passed | Failed | Not run (reason) | Evidence file |
|---|---|---|---|---|---|---|---|
| 2026-10-23 | `6e4d70d0b` | G-1 | full `bin/rails test` (18448 runs) | 18369 | 77 failures, 2 errors (baseline) | — | `evidence/2026-10-22-g1-full-test-baseline-B7G1.md` |
| 2026-10-23 | `6e4d70d0b` + uncommitted | WU-03 | A03-1 … A03-3 | A03-1, A03-2, A03-3 | — | — | `evidence/2026-10-23-wu03-edge-cookie-removal-E3C1.md` |
| 2026-10-23 | `6e4d70d0b` + uncommitted | WU-04 | A04-1 … A04-7 | all | — | — | `evidence/2026-10-23-wu04-telephone-otp-turnstile-T4P1.md` |
| 2026-10-23 | `6e4d70d0b` + uncommitted | WU-40 | A40-1 … A40-5 | A40-1, A40-4, A40-5 | — | A40-2, A40-3 (unchanged paths, not re-measured) | `evidence/2026-10-23-wu40-recovery-otp-turnstile-R4T0.md` |
| 2026-10-23 | `6e4d70d0b` + uncommitted | WU-41 | A41-1 … A41-3 | all (production values pending deploy) | — | — | `evidence/2026-10-23-wu41-wu37-db-timeouts-puma-D4P7.md` |
| 2026-10-23 | `6e4d70d0b` + uncommitted | WU-37 | A37-1, A37-2 | A37-1 (provisional estimate) | — | A37-2 (no load test); production values are a deployment input | same |
| 2026-10-23 | `6e4d70d0b` + uncommitted | WU-09 | A09-1, A09-2 | both | — | — | `evidence/2026-10-23-wu09-browser-allowlist-B9A1.md` |
| 2026-10-23 | `6e4d70d0b` + uncommitted | WU-31 | A31-1 … A31-3 | A31-1, A31-2, A31-3 (sequential) | — | A31-3 two-connection form | `evidence/2026-10-23-wu31-email-otp-retained-result-O3R1.md` |
| 2026-10-23 | `6e4d70d0b` + uncommitted | WU-32 | A32-1 … A32-5 | A32-1, A32-2, A32-4, A32-5 | — | A32-3 (no non-mocked failing write) | `evidence/2026-10-23-wu32-org-halt-audit-H2C9.md` |
| 2026-10-23 | `6e4d70d0b` + uncommitted | WU-23, WU-39 | A23-1, A39-1 | both (WU-05a ADR pending with WU-05) | — | — | `evidence/2026-10-23-wu23-wu39-decision-records-A9D3.md` |
| 2026-10-23 | `6e4d70d0b` + uncommitted | full suite after the batch | G-1 comparison | no new failure; 16 fixed | 61 failures, 2 errors (all in G-1) | — | `evidence/2026-10-23-wu41-wu37-db-timeouts-puma-D4P7.md` |
| 2026-10-23 | `6e4d70d0b` + uncommitted | WU-36 | A36-1, A36-2 | both (option level) | — | per-endpoint Set-Cookie sweep | `evidence/2026-10-23-wu36-host-only-cookies-C6H1.md` |
| 2026-10-23 | `6e4d70d0b` + uncommitted | WU-11 | A11-1 … A11-12 | A11-1, A11-3 … A11-7, A11-10 … A11-12 (local window) | — | A11-8, request-level BCL 503 | `evidence/2026-10-23-wu11-jwks-refetch-limit-J1K5.md` |
| 2026-10-23 | `6e4d70d0b` + uncommitted | WU-42 | A42-1 … A42-13 | A42-1 … A42-4b, A42-7 … A42-13 | — | A42-5 negative boot, A42-6 (Jump) | `evidence/2026-10-23-wu42-redirect-uri-conformance-R2U4.md` |
| 2026-10-23 | `6e4d70d0b` + uncommitted | WU-43 | A43-1 … A43-21 | A43-1 … A43-8, A43-12 … A43-14, A43-16, A43-17 | — | A43-9 (request form), 9d, 9e, 11, 15 e2e, 18 … 21; RP helper rename not done | `evidence/2026-10-23-wu43-rp-signed-state-S6T2.md` |
| 2026-10-23 | `6e4d70d0b` + uncommitted | WU-44 | A44-1 … A44-10 | A44-1 (deterministic, Red verified), A44-3, A44-8 | — | A44-2, 4 … 7, 9, 10; D-167 credential re-check not built | `evidence/2026-10-23-wu44-root-issuance-epoch-E4R4.md` |
| 2026-10-26 | `aeb09ca9f` + uncommitted | WU-44 remaining acceptance | A44-4, A44-7 | A44-7 | A44-4: stale epoch authenticated | A44-2, A44-5, A44-6, A44-10 (stopped after A44-4 failed); A44-9 deferred | `evidence/2026-10-26-wu44-remaining-acceptance-X9R2.md` |
| 2026-10-23 | `6e4d70d0b` + uncommitted | full suite after batch 2 | G-1 comparison | 2 regressions found and fixed; `SignUpExpiryJobTest` flaky (passes alone) | 62 failures, 3 errors before those fixes | — | this row |
| 2026-10-23 | `6e4d70d0b` + uncommitted | WU-01 | A01-1 … A01-6 | A01-1, A01-2, A01-4 | — | A01-3/5/6 deviations (see evidence) | `evidence/2026-10-23-wu01-local-sign-in-flow-removal-L0R1.md` |
| 2026-10-23 | `6e4d70d0b` + uncommitted | WU-20 | A20-1 … A20-13 | A20-1…4, A20-13 | — | A20-6…10 not run; A20-5/11/12 partial (see evidence) | `evidence/2026-10-23-wu20-passkey-identifier-first-P2F0.md` |
| 2026-10-23 | `6e4d70d0b` + uncommitted | WU-17 | A17-1 … A17-3 | all | — | A17-4 n/a (D-159/D-168) | `evidence/2026-10-23-wu17-contract-epoch-removal-K7E0.md` |
| 2026-10-23 | `6e4d70d0b` + uncommitted | Goal intake G-1 | full suite, 18422 runs | No cycle acceptance inferred | 146 failures, 24 errors; all identities retained | Subsequent all-cycle verification remains open | `evidence/2026-10-23-authentication-cycle-baseline-F6B2.md` |
| 2026-10-23 | `6e4d70d0b` + uncommitted | WU-24b | A24-1, focused and broad regression | A24-1; 130 focused runs green | Broad run retains 47 baseline failures and 1 baseline error | Unit gates remain open | `evidence/2026-10-23-wu24b-effective-entry-intent-I4B6.md` |
| 2026-10-23 | `6e4d70d0b` + uncommitted | WU-24e | A24-7, A35-2, A35-3 | A24-7, A35-3; real failure/lock evidence | — | A35-2 Passkey-save/termination request race | `evidence/2026-10-23-wu24e-atomic-cleanup-lock-order-A6C4.md` |
| 2026-10-23 | `6e4d70d0b` + uncommitted | WU-24c/d/g | A24-2, A24-5, A24-6, A24-9; migration/dump checks | Those cases; 111 focused runs green; six OP schema comparisons true | Global schema verification failed in Zenith; broad 1598 runs retain 47 baseline failures and 1 error | WU-24h and WU-06 consumers remain; no whole-unit acceptance | `evidence/2026-10-23-wu24cd-binding-storage-C7D4.md` |
| 2026-10-25 | `bde2346c17e2aa911acc95de1f6035f80498f2da` + uncommitted | WU-15/16/22 | A15-1 … A15-11; A16-1 … A16-4; A22-1 … A22-3 | 199 focused runs / 1055 assertions; 59 supplementary runs / 324 assertions; 20 latest receiver/callback runs / 80 assertions; three OP schema dumps; 78-file RuboCop run before the final test-helper edits | Cause-writer run: 63 runs, 5 failures, 45 errors; later session-limit retry: 19 setup errors caused by stale FK target in `test_op_base_app_db` | A15-7 redirect-hop simulation; A16-5 schema/fixture check; A22-4/G-16 and D-166/A44 acceptance; re-run of the changed parent sign-out expectations (test DB reset requires approval) | `evidence/2026-10-25-wu15-16-22-op-authority-stop-6B3Q.md` |
| 2026-10-26 | `bde2346c17e2aa911acc95de1f6035f80498f2da` + uncommitted | WU-20 | A20-5 … A20-8, A20-10 … A20-13 | Focused groups: 95/670, 52/645, 34/308; integration files: 7/224; WebAuthn invariant: 9/20; RuboCop 23 files clean; timing 200 known + 200 unknown | Broad `test/controllers/auth`: 52 failures, 95 errors; A20-9 Employee Number selection remains open | A20-9 authoritative Employee Number source/contract audit | `evidence/2026-10-26-wu20-passkey-acceptance-W20A.md` |

## Owner manual acceptance, 2026-10-27 (APP Google)

Observed by the owner in the browser; Claude read `log/development.log` for each step. Base
`aeb09ca9fb97ef1ca24c0195b2fa1d28d21245df` with the uncommitted cycle changes, after D-198.

| Step | Result | Log evidence |
|---|---|---|
| Registered Google subject, Sign In | Signed in, dashboard shown | `callback_processed` `existing_account: true` |
| Registered subject, Sign Up | Refused (D-48 L2), uniform 400 | `sign.refused` `intent_crossing` |
| Unknown subject (after `db:migrate:reset` + seed), Sign In | Refused (D-48 L1), uniform 400 | `sign.refused` `intent_crossing` |
| Unknown subject, Sign Up | Registered and signed in | sign-up handoff, dashboard |
| Registered subject after sign-out, Sign Up | Refused (L2) | `sign.refused` `intent_crossing` |
| Sign Out (one APP RP) | Visible sign-out completed; BCL `invalid_endpoint` in development | `LOGGED_OUT`; `oidc.backchannel_logout.delivery` |

Not run, deferred to the next cycle (owner, 2026-10-27): every other manual sign-up, sign-in and
sign-out check (email, telephone, Passkey, Secret, ORG, other RPs, `ten.md` §5). Open items from this
session: `nine.md` BL-11, BL-12; `docs/backlog/2026-10-27-backchannel-logout-unverifiable-in-development.md`;
ORG Entra distinct refusal texts (D-198 note).
