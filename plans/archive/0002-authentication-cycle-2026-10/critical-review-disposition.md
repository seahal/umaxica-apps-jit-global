# six.md — Disposition of Critical Review R-19 … R-30

> Archived 2026-10-27 from the working file `six.md` (cycle archive 0002; frozen, not maintained).

> Status 2026-10-22: Q1–Q14 answered (see the status section below and one.md D-73 … D-83); the remaining proposals here are not decisions. See `one.md` "Resume here".

Working document (gitignored). Input: the owner + ChatGPT handoff "Critical Review R-19〜R-30
設計議論の引き継ぎ" (2026-10-22, here **H13**) and `four.md` R-19 … R-30. Written 2026-10-22 at
`febec3225cc9a0cfa53b9cbe817d20d366aba5a2` (dirty worktree, preserved). **No application code,
ADR or requirement was changed for this file.** Source facts below are from static reading of the
current worktree; no test was run for them.

Note on `four.md` R-29: it was written when `two.md` had WU-01 … WU-05 and `three.md` was empty.
Since then `two.md` Part 2 (WU-06 … WU-23) and `three.md` (Gates G-1 … G-7, cases, empty execution
record) exist. R-29's table is therefore partly out of date; §E re-checks it.

## Status after the owner's answers (2026-10-22, H14)

Q1, Q2, Q4, Q5, Q8, Q10, Q11, Q12, Q13, Q14 approved → one.md D-73 … D-82. Q3 direction only →
D-83 (detail X-24). Q6 pending with X-1 (X-25). Q7 not approved; investigation result recorded in
one.md ("Q7 investigation result"): the proof fails, with a candidate gap (telephone sign-up passkey)
→ X-26. Q9 principle approved, concrete order pending → X-27. Repair procedure → X-28. §B applied to
one.md (D-81). The rest of this file remains a proposal.

## A. Classification of what H13 conveys

| # | Item | Class | Basis |
|---|---|---|---|
| 1 | Sign In First kept; sign-in and sign-up state machines and authority stay separate; existing accounts are not weakened for sign-up | Accepted ADR + owner | `adr/sign-in-first-and-sign-up-handoff.md`; D-3 |
| 2 | Effective intent precedence (Switch `entry_intent` → `prompt=create` → sign-in; `authentication` = sign-in); server-side only | Owner | D-72 |
| 3 | Social Flow created at the sign-up entry, bound to the Binding (E1); callback never creates one; partially supersedes D-48 L1's creation wording | Owner | D-72 (R2-A); four.md R-19 notes D-48 L1 vs D-70 |
| 4 | No cross-DB atomicity claimed; no compensating transaction; partial durable rows are not deleted to tidy up; uncertainty → fail closed = **no authority issued** (Root Session, Grant, RP Session) | Owner (H13 §2.3, building on Sign In First ADR "no compensation") | H13; ADR |
| 5 | D-28 "no durable outbox" is BCL-only; it does not remove audit or other outboxes | Owner clarification (H13 §2.3) | H13 |
| 6 | No Saga / auto-recovery outbox for registration | Owner (H13) | H13 |
| 7 | Operator-led forward repair of partial registrations may be needed; **procedure undecided** | Open | H13 §2.3 |
| 8 | R23-INV-1 … INV-4 (a resend never adds expiry, authority, single-use reference or consumption; foreign-browser resend consumes nothing; no re-minting of a consumed next reference; lost response after COMMIT never reissues) | Owner (mandatory invariant) | H13 §2.4, §6; consistent with D-2 |
| 9 | Exact origin of D-46/D-49's 10-second window | Open | H13 §2.4; four.md R-23 |
| 10 | Curfew principles (30 min, sign-in and sign-up, one absolute deadline per attempt on the Binding, never recomputed, carried codes keep their TTLs, nothing new after 30:00, completed registrations not deleted for expiry) | Owner | D-45, REQ-CURFEW |
| 11 | Curfew boundaries: Switch, Finalization spanning 30:00, RP pending state, authoritative clock | Open | H13 §2.5, §5 |
| 12 | Keep subject lock, UNIQUE, release-history check through the move to the shared finalizer; cleanup never deletes confirmed Client/Identity on a stale decision | Owner (H13 §2.6) | H13; current `SocialAuthSignupFinalizer` |
| 13 | User-facing uniform error ≠ OIDC protocol errors (`prompt=none`/`login_required`, `access_denied`, Cancel, revocation, RP-Initiated Logout) | Owner (H13 §2.7) | H13; OIDC Core, RP-Initiated Logout |
| 14 | R-21 six refusal classes (ownership mismatch, retryable, definitive, dependency, internal inconsistency, protocol) | **ChatGPT proposal, not approved** | H13 §4 |
| 15 | Switch inherits the original deadline | **ChatGPT proposal, not approved** | H13 §5.1 |
| 16 | A Finalization formally started before the curfew may complete its durable registration after it, issuing no authority | **ChatGPT proposal, not approved** | H13 §5.2 |
| 17 | Clock authority = the PostgreSQL that owns the Admission Binding, read after the lock | **ChatGPT proposal, not approved** | H13 §5.3 |
| 18 | RP pending TTL 40 minutes | **Candidate value, not approved** | H13 §5.4 |
| 19 | Replay allowed only when within original expiry ∧ within the 10 s window ∧ same browser ∧ stored identical result ∧ no new authentication | **ChatGPT proposal, not approved** | H13 §6 |
| 20 | Registration order "evidence → durable Client/Identity → graph/OP → only then authenticable; unknown → stop" | **ChatGPT proposal (conceptual), not approved** | H13 §7 |
| 21 | Cleanup recheck under lock, lock order with Finalization, logical vs physical deletion | **ChatGPT proposal, not approved** | H13 §8 R-25 |
| 22 | D-70 provider-event residual risk | Owner (not reopened) | D-70 |
| 23 | Design D (GET relays, GET Root Session) | **Not approved** | one.md "Design D status"; X-1 |

## B. Proposed reconciliation of one.md §2–§5 (R-19)

Proposal only; one.md is not edited until the owner approves. Each topic row would gain four
fields: **Current contract**, **Authority** (Accepted ADR / Owner / Proposal / Open), **Supersedes**,
**Delivery** (Not implemented / In progress / Implemented / Verified).

| Target | Today in one.md | Proposed current statement | Supersedes / note | Delivery |
|---|---|---|---|---|
| §2 architecture | "Base is the sole OP"; component matrix names Base `/oauth/authorize` | OP/AS = **Visa** (`visa.umaxica.*`); Base = standard RP; Auth = ceremonies (D-59); Rails session host-only (D-58, implemented) | D-1's "Base issues admissions…" → "Visa issues…" after WU-02 | D-58 implemented; D-59 not implemented |
| T1 | three steps; "transport depends on X-1" | unchanged + "Design D not approved; WU-12 Blocked on X-1, X-18" | — | Not implemented |
| T2 | 60 s acceptance, min(ceremony, parent), restart page | **REQ-CURFEW** (30 min absolute, on the Binding) for the Sign-in path; acceptance code keeps 60 s (10 s only with automatic relays, D-46); refusal per §D Q1 (D-47 or its narrowed form), no restart page | Supersedes D-36 and D-41's restart page; REQ-CURFEW 6 replaced by D-47 | Not implemented (WU-06) |
| T3 | Cancel/Switch leave `/oauth/authorize`; transport X-1 | Routes and semantics decided (D-38/D-39); **transport separate and Blocked on X-1**; protocol return `access_denied` + `state` + `iss` is an OIDC contract, not the uniform error (H13 §2.7) | D-39's GET design is a proposal under X-1 | Not implemented (WU-13) |
| T5 | lists Local `/sign/handoff`, `/sign/completion` | OIDC result route only; Local routes **removed** (D-60, WU-01) | D-4's Local part | Not implemented (WU-01) |
| T6 | E1 + supersede-in-lock + "sign-up eligibility from effective Admission intent" | add D-72 effective-intent rule, Flow created at the sign-up entry and bound to the Binding (E1), callback never creates; X-13 migration choices listed as the remaining Open part | D-48 L1 "Sign-up Flow created only after the callback" → D-72 | Not implemented (WU-05) |
| T14 | `pt` not used; replacement undecided | D-55 ownership + X-5 input format Open | D-42 retained | Partly (WU-21) |
| T17 | "root fix specified in `two.md`" | "root fix **not defined**; WU-19 Blocked on X-11" | Correct the wording | Not implemented |
| T19 | OBS-1 restart page | reason-coded event per refusal; response per §D Q1 | OBS-1 restart wording | Not implemented (WU-07) |
| X-7 | open | **Resolved by D-53** (Accepted RP-scope ADR) — move to resolved list | — | ADR accepted |
| X-17 | open crossing policy | **Resolved** by D-47 P1, D-48, D-72; residual = implementation (WU-05, WU-08) | — | Not implemented |
| X-19, X-23 | resolved | keep in the resolved list | — | — |
| X-21 | "D-16 vs browser E2E" | WU-02 excludes browser E2E (H8); a separate browser E2E for the end-to-end journey (H7 Phase 5) remains **Open** and is not covered by any WU | Scoped, not blanket | Not planned |
| New X-24 … | — | the open items of §D | — | — |

## C. State and failure matrix (current code; R-24 … R-27)

### C.1 Commit boundaries today

**Shared finalizer** (`SignUpSequenceControllerSupport#finalize_sign_up_from_checkpoint!`, email and
telephone on app/com): runs inside `@sign_up_ticket.with_cycle_lock` = **one OP-DB transaction**
(`FlowBase#with_cycle_lock`: `transaction(requires_new: true)` + `lock!`). Inside it, in order:
1. `finalize_sign_up_side_effect!` — principal-DB writes (contact/credential finalizers) on their own
   connection → **commit immediately** (P-commit).
2. `perform_sign_up_event(:finalize)` — OP DB, pending in the cycle transaction.
3. `IdentityGraphProvisioner.call!` → `BaseSelectorBootstrapAuthority` — its own nested
   transactions per owner (principal, avatar, …) → **commit when it returns** (G-commit); every step
   is `ensure_*` (find-or-create), i.e. idempotent.
4. `perform_sign_up_event(:complete)` — OP DB, pending.
5. `handoff_to_sign_in_flow!` — canonical Sign In flow + OIDC evidence, OP DB, pending.
6. End of block → **OP commit** (O-commit) of 2, 4, 5.

**Social committer today** (`IdentitySocialCeremonyFinalCommitter#commit_signup_source!`, Base): the
**principal transaction is outer**, the OP transaction (`OpBaseAppRecord.transaction`: result
consumption, candidate `consume!`, graph, Flow `:finalize`/`:complete`) is **inner** → order is
G-commit (inside), **O-commit, then P-commit last**. The two paths commit in **opposite orders**.

**Candidate** (`IdentitySocialCeremonyCandidateStore`): PostgreSQL, model
`IdentitySocialCeremonyCandidate < OpBaseAppRecord`, encrypted `auth_hash` holds only the verified
principal; reconstruction sets `credential_candidate: nil`. `consume!` locks the row and sets
`consumed_at` inside **its connection's** transaction (joins an enclosing OP transaction). No Valkey.
`SignUpArtifactCleanup#revoke_pending_apple_credential` is a no-op, so no provider credential is
needed for cleanup today.

**Subject lock** (`SocialAuthSignupFinalizer`): principal transaction →
`ClientExternalIdentity.with_subject_lock(provider, issuer, subject)` → `released_since_ceremony?`
→ `find_by_subject(lock: true)` (only `active`) → create Client (`VERIFIED_WITH_SIGN_UP`) + identity
→ audit outbox row. All in one principal transaction.

**Cleanup** (`SignUpArtifactCleanup`): eligibility (`Client` `UNVERIFIED_WITH_SIGN_UP` + pending
contact) is decided in `client_dependent_records` **before** locking; `schedule_dependent_retention!`
then locks each record and acts **without re-checking** (four.md R-25 confirmed); Client/contacts are
discarded logically (`discard_now!` / status DELETED), passkeys and External Identities are
`destroy!`ed physically.

**Clock:** `ApplicationRecord.database_now` = `SELECT clock_timestamp()` on the calling model's
writer, uncached; the comment requires reading it after the decision's lock. Each database has its
own clock; nothing makes them one.

### C.2 Failure scenarios (as the code behaves today)

| Scenario | Rows left | Evidence left | Next access by the user | New authority possible? | Other flows | Operator needs |
|---|---|---|---|---|---|---|
| Shared path: P-commit done, graph fails | Verified contact/credential (principal) | OTP already consumed in its own commit | Flow still `CHECKPOINT_PENDING` (O rolled back); re-submit re-runs finalizers on an already-verified actor (behavior not established — may refuse); **ordinary sign-in with the verified contact works** and the Base selector later runs the idempotent bootstrap | Yes, through ordinary Sign In (account is durable) | None | Log `identity.graph_provisioning.failed` (principal id) |
| Shared path: P and G committed, OP commit fails | Verified principal + graph | — | Same as above; Flow not completed | Yes via ordinary Sign In | None | Flow id, principal id |
| Shared path: all committed, response lost | Everything | — | Sign In already recorded its OIDC evidence; a resend finds the Flow `COMPLETED` → refused | No new one (D-2) | None | — |
| Social today: O-commit done (candidate consumed, Flow `COMPLETED`), P-commit fails | Consumed candidate, completed Flow, **no Client/identity** | Provider evidence consumed | Retry with the same result refused (consumed); a fresh social sign-up starts clean (subject free) | No | None | Flow id with no principal |
| Social today: all committed, response lost | Everything | Result consumed | `committed_signup!` receipt path redirects to the OIDC result (Base) | Only the already issued result (no reissue) | None | — |
| WU-05 target (F3/F4 order = shared path) with social | Verified Client + identity, graph and Flow as above | Candidate consumed in O | Social sign-in finds the identity (L2) and signs in | Yes via ordinary Sign In | None | as above |
| Partial principal (identity row without Client) | — | — | L4: raise 5xx + FATAL (D-48) | No | None | FATAL event |

**The R-24 core question.** Today the authority to sign in after registration is the **principal
state** (`login_allowed?`, `access_enabled?`, verified contact or active identity); the OP Flow state
and the graph are not consulted by Sign In. A registration that committed its principal part is
therefore signable-in, graph or not. Whether that is acceptable is §D Q7.

## D. Open decisions for the owner

| ID | Question | Current behavior | Options | Recommendation and reason | Risk if left open | Links |
|---|---|---|---|---|---|---|
| Q1 | Refusal classes and D-47's scope (R-21) | Mixed statuses and messages | (a) adopt the six classes; D-47 applies only to "definitive refusal of the owner's own attempt"; (b) keep D-47 universal with listed exceptions (Turnstile retry, foreign browser, dependency, invariant, protocol) | (a): the exceptions are the majority; a closed class list is easier to test and audit | WU-04 retry and foreign-browser safety conflict with a literal D-47 | D-47, WU-04, WU-07, three.md A07 |
| Q2 | Switch and the curfew (R-22) | Switch binding expiry = min(parent transaction expiry, now + 60 s); new Binding | (a) inherit the original attempt's `curfew_at`; (b) new 30 min window | (a): one attempt, one absolute deadline (REQ-CURFEW 1); a Switch cannot extend authority | A Switch near 30:00 extends the attempt | D-45, D-39, WU-06 |
| Q3 | Finalization spanning 30:00 (R-22) | Not defined | (a) refuse at the decision point: finalization must **decide** before 30:00 under the Flow lock; durable writes started then may commit after; no evidence/session write after 30:00; (b) persistent `FINALIZING` state | (a) with an explicit decision record: the Flow transition to finalizing is the existing `:finalize` event, already persisted in the OP transaction — investigate whether it can carry the "decided at" time before adding a state | Registration committed after 30:00 with an unclear status | REQ-CURFEW 3/7, WU-05 F1–F4 |
| Q4 | Clock authority (R-22) | Each model's `database_now` | (a) the OP database that owns the Binding (`op_base_*`), `clock_timestamp()` after the Binding/Flow lock, passed through the decision; (b) per-model clocks | (a): the Binding is the deadline's owner; one read per decision unit is already the documented convention | Two clocks disagree at 30:00 | `ApplicationRecord.database_now`, WU-06 |
| Q5 | RP pending OIDC state lifetime (R-22) | `OIDC_PENDING_FLOW_TTL` 10 min from RP flow creation | (a) RP pending TTL = bounded pre-admission time + 30 min + bounded callback-return time; the RP refuses an authorization start older than the pre-admission bound; (b) a fixed number (e.g. 40 min) | (a) with explicit bounds proposed after measuring today's hops (the authorization code stays 10 s) | RP state expires before a valid curfew-bounded result | `OidcCallback`, WU-06, WU-21 |
| Q6 | 10-second origin (R-23) | Only relevant to automatic relays | Decide together with X-1 | Defer to X-1 (Design D not approved) | — | D-46, D-49, WU-12 |
| Q7 | What blocks sign-in after a partial registration (R-24) | Principal state alone | (a) principal state is the registration authority: write the verified status in the same principal transaction as the identity/contact (F3), make graph provisioning idempotent and allowed lazily (it already is, via the selector); no new marker; (b) add a durable "registration completed" fact that Sign In requires | (a): it uses an existing durable state, adds no cross-DB coupling, and matches Sign In First ("durable registration → later failures are Sign In failures"). Requires: one principal transaction for status + identity/contact, and the WU-05 order equal to the shared path | Divergent social/shared orders keep two failure models | WU-05 F3/F4, Sign In First ADR |
| Q8 | Pending Client reuse and cleanup (R-25) | Eligibility checked before the lock | New attempts always create new pending Clients (no adoption); cleanup re-checks status, Flow/operation ownership and absence of identity under the principal lock; logical retention for actors | as stated | Cleanup could discard a just-verified Client | WU-05 P5, D-70 R-3 |
| Q9 | Lock order (R-25/R-26) | Shared: OP Flow lock outer; social: principal outer | One order for all paths: OP Flow lock → principal subject lock → Client lock; cleanup takes the same order | as stated; keeps `with_subject_lock` + `released_since_ceremony?` inside the principal transaction (H13 §2.6) | Deadlocks or unserialized subject checks | WU-05 F3 |
| Q10 | Provider credential persistence (R-27) | Not stored (`credential_candidate: nil`) | Keep not storing; correct WU-05 C1/C3 (PostgreSQL, OP DB; no Valkey dependency for the Candidate) | as stated; cleanup's Apple revocation is a no-op today | Tests check an irrelevant dependency | WU-05 C1–C3 |
| Q11 | Revocation client authentication (R-30) | `client_id` + `client_secret` only on app/com/org; Discovery advertises `token_endpoint_auth_methods_supported` but no `revocation_endpoint_auth_methods_supported` (RFC 8414 default if omitted: `client_secret_basic`) | Revocation accepts each client's **registered** method (`private_key_jwt` for first-party RPs, as at the token endpoint); Discovery advertises `revocation_endpoint_auth_methods_supported` | as stated, per registration — not inferred from the token endpoint alone | Standard client cannot revoke as registered | WU-02 V4/V5, new WU |
| Q12 | RP handling of `login_required` / `access_denied` (R-30) | OP returns `login_required` for `prompt=none`; RP callback treats `access_denied` specially only for `tech-org-ww`, otherwise renders a plain failure | RP callbacks validate `state`/`iss` then: `login_required` → start an interactive authorization (D-25 recovery); `access_denied` → Cancel return (T3) | as stated | Refresh recovery and Cancel strand the user | WU-10, WU-13, WU-21 |
| Q13 | Apply §B to one.md | — | Approve / amend | Approve, so the implementer has one current statement per topic | Implementers resolve conflicts by position | R-19 |
| Q14 | Operator forward-repair procedure for partial registrations | Undecided | Document a read-only diagnosis first (which rows exist per C.2), repair actions later | Diagnosis document only for now | — | H13 §2.3 |

## E. Plan for two.md and three.md

- **New WU-24 "E1 binding, effective intent and curfew storage"** (R-20): split out of WU-05 so it
  precedes it: `auth_admission_binding_id` on Sign-up Flows (migration, X-13 choices), authoritative
  Binding lookup replacing `SignUpCycleLocator` authority, D-72 effective intent, `curfew_at` on the
  Binding (WU-06's storage step). WU-05 and WU-06 depend on it. Stage invariants stated per step.
- **WU-05 corrections:** C1/C3 per Q10; F3/F4 order and lock order per Q7/Q9; P5 per Q8; 5.J items
  marked "designed, not executed" (R-28).
- **WU-07** rewritten per Q1 outcome; protocol errors excluded (Q12).
- **WU-06** gains Q2–Q5 outcomes.
- **New WU-25 "Revocation client authentication and Discovery metadata"** (Q11), after WU-02.
- **WU-10/WU-13/WU-21** gain Q12.
- **WU-01 acceptance (R-28):** replace "same pass/fail set" with characterization of each surviving
  public behavior reached by re-pointed fixtures; record blocked assertions as unverified with a
  defect reference.
- **three.md:** add Gates — G-8 Cross-browser non-consumption (AUTH-19 at every hop), G-9 Curfew
  boundary (29:59/30:00/30:01 incl. Switch, lock wait, finalization spanning), G-10 Resend never
  increases expiry/authority/references (R23-INV-1…4), G-11 Subject concurrency on separate
  connections (both providers, unlink/relink race, ban at finalization), G-12 Cleanup vs
  finalization race, G-13 Candidate single consumption and OP-DB outage, G-14 Partial commit at each
  boundary with the next sign-in's observable result (real separate transactions, no single mocked
  exception), G-15 OIDC protocol outcomes (`prompt=none`, `access_denied`, revocation auth,
  RP-Initiated Logout GET/POST, expired `id_token_hint` vs expired ID Token). Mark three.md wording
  "designed / implemented / executed / passed" separately.
- **R-29 coverage:** a status column for every T1–T20 row (§B) and a one-to-one link to its WU or
  deferral; "five WUs done" must never read as "twenty topics passed".

## F. ADR alignment

| ADR | Conflict | Proposed handling |
|---|---|---|
| `adr/base-auth-ceremony-and-seven-rp-boundary.md` | "Base is the sole OP" (pre-D-59); 2026-09-21 "GET never consumes" (relevant only if X-1 grants an exception) | Amendment after WU-02 naming Visa; GET rule unchanged unless X-1 decides |
| `adr/base-authority-and-self-rp-separation.md` | Authority and self-RP on one FQDN | Partially superseded by the new Visa ADR (WU-02 V11) |
| `adr/sign-in-first-and-sign-up-handoff.md` | None; Google/Apple currently non-conforming in code | Unchanged; WU-05 brings code into conformance; record verification after implementation |
| `adr/sign-up-authentication-handoff-and-social-rt.md` | Social commit at Base | Partially superseded by the WU-05 ADR (written before implementation, U4) |
| `adr/sign-up-flow-admission-binding-and-cardinality.md` (E1) | Target not implemented; X-13 Pending items | WU-24 implements; Pending table resolved only by owner decisions |
| `adr/first-party-sign-out-op-commit-and-backchannel-logout-for-separated-rp-stores.md` | Durable outbox clause vs D-28 | Amend for BCL only; H13 clarifies D-28 does not remove audit outboxes |
| `adr/turnstile-visible-placement-policy.md` | None | Telephone OTP is a conformance fix (WU-04) |

No ADR is changed by this file; no proposal above is promoted to Accepted.
