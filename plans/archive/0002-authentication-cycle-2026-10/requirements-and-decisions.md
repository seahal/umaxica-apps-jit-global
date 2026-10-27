# one.md — Requirements (current contract projection)

> Archived 2026-10-27 from the working file `one.md` (cycle archive 0002; frozen, not maintained).

Working document (gitignored). Cycle roles:

| File | Role |
|---|---|
| `one.md` | **Requirements**: the current contract projection (§2–§5), open decisions, ADR amendments needed |
| `two.md` | Detailed definitions: definition packages / Work Units, design, files, Red tests, exit criteria |
| `three.md` | Acceptance: Gate register, acceptance cases, execution record |
| `four.md` | Codex critical review of the previous `one.md` (2026-10-21, snapshot SHA-256 `3ca0e08a…`); supporting material, not a decision |

- Opened 2026-10-21 at `febec3225cc9a0cfa53b9cbe817d20d366aba5a2`; **refreshed 2026-10-21** after the
  Codex review (`four.md` R-01/R-02: later decisions had not reached the requirements). The worktree
  is dirty with work that is not ours; preserve it (no `git reset/clean/restore`).
- **Reading rule.** §2–§5 are the only implementation input. Appendix D (decision log, verbatim) and
  Appendix E (the earlier requirement draft) are history: they explain how §2–§5 were reached and are
  **not** to be implemented paragraph by paragraph. Where an appendix paragraph contradicts §2–§5,
  §2–§5 wins.
- Not normative and not evidence. **Code shows observed behavior; Accepted ADRs state intended
  contracts** (`docs/reference/repository-knowledge-architecture.md`, "Facts and contracts"). Owner
  decisions recorded here bind this cycle but most are **not yet ADRs** — see §4.
- Content comes from source, ADR, dev-log and live-browser reading in this session. Tests were run only
  where §6 says so.
- On closure archive as `plans/archive/0002-<slug>/` after moving lasting content to `adr/`, `docs/`,
  `docs/checklists/`, `plans/backlog/` or `evidence/`.

## Resume here (session end 2026-10-22)

Read this block first when picking the work up again. HEAD `6e4d70d0b` (`[CHECKPOINT] .`,
2026-10-23 03:37 +0900), branch `feature`, worktree clean at the 2026-10-23 drift check. The
checkpoint committed everything that was uncommitted on top of `febec3225` (399 files: this
cycle's changes listed below and parallel work outside the cycle, see "Drift check"). Still never
`git reset`, `git clean` or unapproved `git restore`. No Work Unit of `two.md` is implemented.

**Drift check (2026-10-23, static reading of `febec3225..6e4d70d0b`).** `6e4d70d0b` is the only
commit since this cycle opened; it changes no `db/`, migration or route file. Code facts cited in
§3 (T22, T23, T24, Q7, the constants and line references) were re-read and still hold. Parallel
work outside this cycle that touches the units:
- `adr/credential-response-nondisclosure.md` (Accepted 2026-10-22) requires discoverable + UV for
  ORG Passkey registration; this contradicts `adr/passkey-identifier-first-sign-in.md` (§ORG
  non-discoverable compatibility: "Neither exposing descriptors nor silently requiring
  discoverable ORG credentials is an approved resolution"). **Needs the owner before WU-20 (ORG).**
  The same ADR unifies the Passkey refusal message (`errors.webauthn.verification_failed`) and
  makes APP Secret account-budget exhaustion the ordinary 422 refusal: re-read `two.md` 5.4 (WU-33).
- ORG invitation acceptance (`Auth::Org::Sign::Up::InvitationsController#create`) refuses every code
  before lookup during the Bureau migration hold (`specs/org-organization-consolidation/`,
  implementing). The D-96 gate site stays; its success path is not reachable for acceptance cases.
- `adr/jwt-validation-and-key-risk-decisions.md` (Accepted): supported `jwt` option names
  (`verify_expiration`, `verify_not_before`) and `verify_iat: { leeway: 30 }`; the WU-43 `state`
  verifier and WU-11 follow it. Apple RS256/RS512 acceptance is accepted upstream behavior and does
  not touch D-9 (UMAXICA-issued tokens).
- `config.active_support.message_serializer = JSON`; the Cancel/Switch handoff encryptors use
  `serializer: JSON` (WU-13); Marshal payloads are refused.
- APP/COM email and telephone sign-up `create` call `supersede_active_sign_up_flow!` after Turnstile
  and input validation (`evidence/2026-10-22-sign-up-contact-admission-H7Q2.md`); re-check
  `two.md` 6.2 (WU-35 / WU-24e) against the new order.
- Email OTP sign-in refuses unbound candidates, VERIFIED status included
  (`evidence/2026-10-22-authentication-boundary-regressions-P6R4.md`, AUTH-22 … AUTH-25): the email
  half of Q7 item 5 has tests now; the Passkey half (AX26-1) is still open.
- New `docs/backlog/2026-10-22-identity-stop-missing-separated-rp-logout-notification.md` and
  `…-pre-stop-jwt-accepted-after-operator-restore.md` overlap BX-1 / D-34 / D-119 / D-111 (WU-16).
  Backlog entries of that work live in `docs/backlog/`, not `plans/backlog/`.

**Documents (all gitignored except where noted):**

| File | Role | State |
|---|---|---|
| `one.md` | Requirements: §2 architecture, §3 topic table (Current contract / Authority / Supersedes / Delivery), decisions D-44 … D-135, §4 ADR amendments, §5 open register X-1 … X-48; Appendix D/E history | Current |
| `two.md` | Work Units WU-01 … WU-05 (detailed), Part 2 WU-06 … WU-26, Part 3 WU-27 … WU-39 (2026-10-22), order across units | Defined, nothing implemented |
| `three.md` | Acceptance: status vocabulary, Gates G-1 … G-22, cases per Ready unit, X-26 Red test, standing checks S-1 … S-4, empty execution record | Defined, nothing executed |
| `four.md` | Codex critical review R-01 … R-30 (input, not decisions) | R-19 … R-30 dispositioned in `six.md` |
| `five.md` | Re-evaluation of the Sign-in path admission protocol (Design D) | Design D **adopted** (D-100, 2026-10-22); its §6/§10 are the implementation reference for WU-12 |
| `six.md` | Disposition of R-19 … R-30: classification, proposed reconciliation (applied), failure matrix, owner Q1 … Q14 and their answers | Q-answers recorded as D-73 … D-83 |

**Decided recently (see the decision blocks in §3):** D-58 host-only session cookie (implemented),
D-59 Visa OP host, D-60 Local flow removal, D-61 two confirmation endpoints, D-62 WU-02 resolutions,
D-63 `/edge/v0/cookie` removal, D-64/D-71 dead code removal, D-65 Visa keys in the current style,
D-66/D-67 telephone OTP Turnstile (app + com), D-68 Auth COM/ORG translation namespace
(implemented), D-69/D-70/D-72 sign-up unification (effective intent, one social Flow at the entry),
D-73 … D-83 (refusal classes, Switch inherits the deadline, OP-DB clock, RP pending bounds, no
pending-Client reuse, Candidate in PostgreSQL, revocation by registered method, RP protocol-error
handling, projection refresh, read-only diagnosis, Finalization-after-deadline direction),
D-84 … D-86 (Sign entry Sentry: six availability flags, Auth-hosted `/sign/{in,up}/sentry`,
request context through existing concerns; T21), D-87 … D-91 (login audit H16: scope; Security
Mode migration this cycle; OTP Red tests first; ORG halt audit by direct Chronicle write; failure
table now; T22 … T25), D-92 (Security Mode value mapping), D-93 … D-99 (Sentry X-29 … X-35), D-100 … D-103 (Design D adopted, 10 s from issuance, F1 closed, `GET /sign` kept), D-104 … D-107 (no reissue / SSO recovery, Finalization refused after the deadline, AX26-1 then status gate, lock-order inventory), D-108 … D-111 (OP-chain removal, RP-stored return target, silent re-authorization scope, 10 min + 30 s bound), D-112 … D-115 (Passkey identifier-first this cycle, language-only i18n, no E2E, host-only cookies), D-116 (Passkey capacity ten), D-117 … D-119 (durable BCL outbox restored, `ActionController::API` receiver, stop record as authority), D-120 (more Puma workers/threads, no cap), D-121 (BCL via Solid Queue), D-122 … D-124 (Bootstrap rebuilt, strict sign-out, `three.md` Gates), D-125 (E1 binding: `attr_readonly`, delete-then-NOT NULL, RESTRICT), D-126 (partial registrations: automatic deletion; its user reset is superseded by D-135), D-127 (`entry_intent` NOT NULL; wording replaced by D-129), D-128 … D-135 (`seven.md` answers), D-136 … D-139 (H18: Valkey JWKS limit, RP-signed `pt`, WU-24 reissue, lock investigation policy; ledger after D-135).
Naming: "System A/B" are now **Sign-in path** (サインイン系) and **Re-verification path** (再確認系).

**State after H18 … H21 (2026-10-22).** Decided since H18: D-136 … D-153 — WU-11 JWKS Valkey
limit and details (D-136, D-144); WU-24 reissued and split 24a … 24h (D-138, D-140); lock policy and
fixes F-1/F-2 (D-139, D-143); effective DB timeouts WU-41 (D-142); recovery OTP Turnstile WU-40
(D-141); OIDC conformance WU-42 — `redirect_uri` (D-145), Jump forwarding accepted risk (D-146),
N-1 … N-4 incl. PKCE `invalid_grant` (D-147), `prompt_values_supported` and direct 400 (D-148);
WU-43 — ES384 JWS `state` (D-149), 30 min (D-150), `pt` abolished / `target_link_uri` path only with
WU-21 merged (D-151), Cancel handled on the RP (D-152), `GET /sign/interruption` (D-153). The
decision ledger (after D-135) lists every row with its authority and next actor. Implementation is
done by another AI from `two.md` + `three.md`; this session edits only `one.md`/`two.md`/`three.md`.

**Open, needs the owner (2026-10-23):** none. 5.8 v2 accepted (D-172); the ORG discoverable
Passkey conflict is resolved by D-171. The owner excluded the separate implementation brief (R-7):
the implementer works from `two.md` + `three.md` directly. Decided since: WU-28 out of cycle (D-170),
destructive changes authorized (D-168), Sentry copy and logging (D-169). X-26 waits for AX26-1 (a
test run, not a decision). Data-migration work is dropped: the owner resets the databases (D-159).

**Next steps agreed:** implementation is done by another AI from `two.md` + `three.md`, in the order of
`two.md` 6.6 (replaces "Order across all units" from H18 on; WU-43 for Base RPs only after WU-02f). Nothing starts before the owner's go on
the item in question; destructive migrations need their own approval.
Production `JWT_VISA_*` keys and the credentials key-name mismatch are owner tasks (backlog).

**Test baseline (G-1, 2026-10-23):** 18448 runs, 77 failures, 2 errors at `6e4d70d0b`, after an owner-approved rebuild of the test databases from migrations only (`evidence/2026-10-22-g1-full-test-baseline-B7G1.md`, with the failure list). A first run on structure-loaded test databases (119 failures, 250 errors, reference rows missing) is not a baseline. Earlier history: the checkpoint
changed tests by +2302/-1753 lines and deleted 13 test files (test value audit), none referenced by
`two.md`/`three.md`. Earlier: full run after the test-DB rebuild: 18420 runs, 59 failures, 1 error
(TR groups G1–G6, all from the 2026-10-20 session fixation containment); D-58 and D-68 added no
failures (cookie tests updated). The test DBs were rebuilt on 2026-10-21 (1022 clone DBs dropped, `db:drop
db:create` + migrations; the 30 replica base DBs were deleted by mistake and recreated empty).
Equal failure counts are not proof of no regression (R-28).

**Changes made in this cycle** (committed in `6e4d70d0b` together with work that is not ours):
- Code: FIXME comments in `app/controllers/base/{app,com,org}/oauth/authorizations_controller.rb`
  and `app/controllers/concerns/oidc_authorization_result_post.rb`; Secret sign-in back link
  (`app/controllers/auth/app/sign/in/secrets_controller.rb`, `src/pages/auth/app/sign/in/secrets/new.tsx`,
  tests in `test/controllers/auth/app/in/secrets_controller_test.rb`,
  `gait/pages/auth/app/secret_sign_in_presentation.test.tsx`); host-only session cookie
  (`lib/jit_session_cookie_config.rb`, `test/unit/jit/session_cookie_config_test.rb`,
  `test/security/invariants/cookie_security_invariant_test.rb`); Auth COM/ORG translation namespace
  (`config/locales/{jp,us}/{ja,en}.yml`, 14 files under `app/controllers/auth/{com,org}/`,
  `test/security/invariants/auth_surface_translation_namespace_invariant_test.rb`).
- Docs: `adr/oidc-rp-scope-umaxica-tlds-only.md` (new, Accepted) + `adr/README.md`; `docs/dds.md`
  (browser allowlist, naming); `docs/checklists/authentication.md` (AUTH-19);
  `docs/vendor/identity/13_normative-baseline.md`, `docs/security/authentication-boundary-audit.md`
  (session cookie attributes).
- Sentry (H15, docs only): `adr/sign-entry-sentry.md` (new) + `adr/README.md` entry,
  `research/2026-10-22-sign-entry-sentry-investigation.md`,
  `plans/backlog/2026-10-22-sign-entry-sentry-implementation.md`. No code, route, flag or test.
- Backlog: `plans/backlog/2026-10-21-social-provider-account-event-notifications.md`,
  `…-production-credentials-key-name-mismatch.md` (high priority), `…-base-com-org-translation-namespace.md`.
- Evidence: `evidence/2026-10-21-oidc-browser-flow-log-review-R3N7.md`,
  `…-session-cookie-host-only-K4P2.md`, `…-auth-com-org-translation-namespace-Q8T4.md`.

Authority class used in §3 (from `four.md` R-02):

| Class | Meaning |
|---|---|
| **A** | Accepted ADR contract; code may or may not conform |
| **O** | Owner decision in this cycle, awaiting ADR reconciliation (§4) |
| **P** | Proposal from this document, not yet approved |
| **X** | Open — needs an owner decision (§5) |

## 1. Sources

| ID | Source | Subject |
|---|---|---|
| H1 | This session's dev-log and live-browser review (`evidence/2026-10-21-oidc-browser-flow-log-review-R3N7.md`) | Base↔Auth browser flow defects |
| H2 | Owner handoff "UMAXICA Org Bootstrap" | Dev-only ORG Bootstrap Operator |
| H3 | Owner handoff "Sign-up / Sign-in 再設計" + `adr/sign-up-flow-admission-binding-and-cardinality.md` | E1, `/sign/result` |
| H4 | Owner handoff "OP/IdP 最終品質保証・標準化サイクル" | R5 completion, final QA, Gates (largely re-scoped by D-15…D-35) |
| H5 | Owner handoff "Sign-out 設計・実装の移管依頼" | Sign-out (SO-1 … SO-7, method C) |
| H6 | Owner + ChatGPT draft "Browser RP Sign-In UX 改善" | At most three user steps |
| CR | `four.md` (Codex review) | R-01 … R-18, definition packages |
| ADR-PK | `adr/passkey-identifier-first-sign-in.md` (Accepted 2026-10-21) | Passkey identifier-first |
| H7 | Owner + ChatGPT handoff "Sign-in path — Sign up / Sign in 全経路の調査・設計・改善の引き継ぎ" (2026-10-21) | Decisions D-54 … D-57, investigation Phases 1–5, deliverables A–F (§7.1). Its route descriptions are design-level from a GitHub snapshot, **not** log-verified facts |
| H13 | Owner + ChatGPT handoff "Critical Review R-19〜R-30 設計議論の引き継ぎ" (2026-10-22) | Disposition in `six.md` (classification, proposed §2–§5 reconciliation, failure matrix, open Q1–Q14); nothing applied to this file's contract yet |
| H15 | Owner handoff "UMAXICA 認証入口制御「Sentry」設計引き継ぎ・調査依頼" (2026-10-22) and the owner's follow-up answers in the same session | D-84 … D-86, T21, X-29 … X-35; investigation `research/2026-10-22-sign-entry-sentry-investigation.md` (static reading at `febec3225`, not executed) |
| H17 | Codex review `seven.md` (2026-10-22): static read of one/two/three.md against code, schema, ADRs and tests; 8 blocking findings, 12 further gaps, acceptance fixes | Disposition below ("seven.md disposition"); X-42 … X-47; errata on D-104, D-106, D-123 (scope), D-127 |
| H16 | ChatGPT audit "UMAXICA ログイン実装の不足調査" (2026-10-22, static reading of GitHub `feature` at `2b23e9d20c61`, one commit behind the then HEAD `febec3225`, without the uncommitted work or `one.md` … `six.md`), relayed by the owner | D-87, T22 … T25, X-36 … X-39; each finding re-read against the local tree in this session (static, not executed) |
| H18 | Owner + ChatGPT handoff "UMAXICA NOW — 認証基盤改修サイクル引き継ぎ・Owner 決定反映・実装計画再構成指示" (2026-10-22) | D-136 … D-139, decision ledger, `two.md` Part 6; findings re-read against the local tree (static, plus one read-only `SHOW lock_timeout` run) |
| H19 | Owner answers on H18 (2026-10-22) and a relayed security review of sign-up / sign-in / email confirmation / recovery ("Turnstile を通さず直接呼べる送信系エンドポイント") | D-140, D-141; the review's finding re-read in this session (static) |
| H20 | Owner design decision "OAuth 2.0／OIDC `redirect_uri` の規格準拠" (2026-10-22) | D-145; conformance read in this session (static), WU-42 |
| H21 | Owner + ChatGPT handoff "UMAXICA OIDC Authorization Code Flow — 設計決定の引き継ぎ・監査・実装依頼" (2026-10-22) | D-149, X-52, X-53; WU-43; Phases 1–3 recorded in `two.md` 6.12 (static reading); Phases 4–5 belong to the implementer |
| H12 | ChatGPT answer to WU-05 U1–U6 (2026-10-21), relayed by the owner | D-69 |
| H11 | Owner + ChatGPT handoff "Sign-up 6経路統一リファクタリング：設計決定事項の引き継ぎ" (2026-10-21) | `two.md` WU-05; U1–U6 decided as D-69 |
| H10 | ChatGPT review "App Sign-up — Telephone SMS OTP の Turnstile 実装修正" (2026-10-21), relayed by the owner | D-66; `two.md` WU-04 |
| H9 | ChatGPT reply to WU-02 Phase 1 (2026-10-21), relayed by the owner | D-62 |
| H8 | Owner + ChatGPT handoff "UMAXICA Global — Visa OP / Base RP ホスト分離リファクタリング実装依頼" (2026-10-21) | D-59; R1–R8; Phases 1–7; deliverables A–G; WU-02 in `two.md` |
| TR | Full `bin/rails test` run 3 after the test-DB rebuild (2026-10-21, HEAD `febec3225`; this session) | 18420 runs, 59 failures, 1 error; groups G1–G6 (§3, "Test-run findings") |

## 2. Current architecture (what exists after this cycle's decisions)

- **One Rails monolith, one Puma, every FQDN, split only by subdomain, Rails Way** (D-19, D-21).
  Removed: non-`shared` `RuntimeRole` roles, `RuntimeRoleRouteGuard`, `rp_cell_process?` branches
  (D-20 layer 1). One Rails credentials set per environment (D-15). Consequence: an RP compromise equals
  an OP compromise; surface boundaries are code discipline (D-20). Production on AWS; OP signing
  direction AWS KMS, `global`-pod co-location Pending (D-17, implementation not this cycle).
- **Every RP, first-party included, is a standard OIDC RP** usable with ordinary libraries plus a thin
  adapter where UMAXICA is stricter (ES384 only) (D-23). Deviations from the standards are kept only
  with a written rationale.
- **The OP/AS is Visa** (`visa.umaxica.{app,com,org}`, D-59; not yet implemented): Base is a standard
  RP, Auth runs ceremonies. Until WU-02 lands the code still serves the OP from `www`; statements
  below that say "Base OP" describe that interim code.
- **Base is a standard RP of its own OP, with no internal shortcut** (D-54, H7 decision A): the
  logical route is `Base RP → Base OP → Auth → Base OP → Base RP`, the same as
  `Warp RP → Base OP → Auth → Base OP → Warp RP`. This matches the Accepted
  `adr/base-authority-and-self-rp-separation.md` (Authority and self-RP controller roles on one FQDN;
  clients `base-{app,com,org}-ww`). **Broken today (TR G1):** both roles share one Rails session, so
  the OP's login `reset_session` erases the self-RP's pending `state`/`nonce`/PKCE verifier and every
  Base self-RP sign-in ends in `/oidc/callback` 422 `state_invalid` (**X-19**).

Component matrix:

| Component | Status | Decision |
|---|---|---|
| OIDC Authorization Code + PKCE (RP `/sign` → Base `/oauth/authorize` → Auth → `/oidc/callback`) | Kept | D-22 #1 |
| Token Endpoint over HTTP with `private_key_jwt` (`OidcOpTokenClient`) | Kept | D-22 #2 |
| Access/Refresh in `__Host-` host-only cookies | Kept (exception to H4 §3.3, class O) | D-22 #3 |
| ID Token / Access JWT verification via Discovery → `jwks_uri` over HTTP, per issuer, ES384 pinned, bounded unknown-`kid` refetch, fail closed | Kept, to become the only path | D-23 #4 |
| 12 `rp_*` DBs: `rp_callback_states`, `rp_principals`, `rp_identity_bindings`, `rp_op_session_bindings`, `rp_sessions`, `rp_event_receipts` | Kept | D-24 |
| `rp_refresh_attempts`, delivery-receipt query endpoint, receipt replay | Removed | D-25 |
| `op_client_activations`, `OpClientAdmissionGate`, cell activation | Removed | D-35 (D-18 withdrawn) |
| `contract_epoch` (protocol epoch: columns, `umx_contract_epoch`, `UMAXICA_RP_CONTRACT_EPOCH`, AUTH-16) | Removed (consumer migration, CR R-15) | D-35 |
| `authentication_epoch` (identity stop) | Kept, made NOT NULL (bulk update needs approval) | D-35 |
| Zenith → OP identity stop (event + direct apply + retry job + sweep) | Kept, durable | D-34 |
| Back-Channel Logout (OP sender, RP receiver) | Kept and redefined | D-26 … D-32 |
| Durable OP outbox for BCL | Kept (every participant notified) | D-117 (supersedes D-28) |
| RP-Initiated Logout / `logout_challenge` | Kept, reshaped to the spec | D-33 |

**Open (X-2):** with process roles gone, what selects the retained standard-RP path (local session,
JWKS, BCL) over today's live pre-R5 OP-chain path for each RP, and what prevents both authorities
running for one client at once (CR question 3)?

## 3. Current contract by topic

| # | Topic | Current contract | Authority | Supersedes | Delivery |
|---|---|---|---|---|---|
| T1 | Sign-in UX | At most three user steps (first page, OIDC start page, authentication page); no relay page, click or JavaScript between them; HTTP redirects only; method-intrinsic steps (OTP, Passkey, provider) counted separately. Design D adopted (D-100); `GET /sign` kept for every entry (D-103) | Owner (H6, H7) | ADM-3 auto-submit | Not implemented — `two.md` WU-12 (Blocked) |
| T2 | Sign-in path deadline | **REQ-CURFEW**: one absolute deadline per attempt = Admission issuance (OP database time) + 30 min, stored once on the Binding, never recomputed; every Sign-in path consumer refuses at ≥ 30:00; Switch **inherits** the original deadline (D-74); clock = the OP database owning the Binding, `clock_timestamp()` after the Binding/Flow lock (D-75); the RP `state` has its own 30 minutes on the Rails clock and may end a few seconds earlier (D-160, superseding D-76); after the curfew the owner's attempt returns to the RP as `access_denied` (D-160); carried codes keep their own TTLs (acceptance 60 s; 10 s only with automatic relays, D-46). Finalization completes before the deadline or is refused (D-105, superseding D-83) | Owner (D-45, D-74 … D-76, D-83) | D-36 (min(parent, ceremony)), D-41 restart page, REQ-CURFEW 6 | Not implemented — WU-24, WU-06 |
| T3 | Cancel / Switch | Routes and semantics decided: OP-host `/oidc/cancellation` (APP/COM/ORG) and `/oidc/switch` (APP/COM); Cancel ends ceremony and parent and returns `access_denied` + `state` + `iss` to the RP (an OIDC protocol response, not the uniform error, D-80); Switch keeps the parent, issues a fresh Admission with the target `entry_intent` and inherits the deadline (D-74). Transport: Design D continuation GET (D-100) | Owner (D-38, D-39 semantics) | — | Not implemented — WU-13 (Blocked on transport) |
| T4 | `/oauth/authorize` | Long-term only the standard authorization request (D-37); this cycle only Cancel/Switch leave; FIXME markers placed | Owner | — | Markers only |
| T5 | OIDC result route | Auth `/sign/oidc/handoff` → the OP's result receiver (`/oauth/authorize` today, on Visa after WU-02). The Local Sign-in Flow routes (`/sign/handoff`, `/sign/completion`) are **removed** (D-60) | Accepted (H3) + Owner | D-4's Local part | Not implemented — WU-01, WU-02 |
| T6 | Sign-up Flow ↔ Admission | Effective intent per D-72 (Switch `entry_intent` → `prompt=create` → sign-in; `authentication` = sign-in; server-side only); one Sign-up Flow per attempt, created at the sign-up entry and bound to the Binding (E1 `auth_admission_binding_id`); the social callback never creates one; no pending Client is reused across Flows (D-77); E1 cardinality and immutability per the E1 ADR; X-13 migration choices remain | Accepted (E1 ADR) + Owner (D-72, D-77) | D-48 L1 "Flow created only after the callback" | Not implemented — WU-24, WU-05 |
| T7 | Refresh | RFC 6749 §6 / RFC 9700 §4.14; rotation; reuse → `invalid_grant`, revoke only that grant's family; unknown tokens revoke nothing; no grace; receipt machinery removed; RP recovery via a new Code flow with `prompt=none` and, on `login_required`, a new interactive authorization without silent-retry loops (D-80). X-6 open | Owner (D-25, D-80) | AUTH-10 … 12 receipt contract | Not implemented — WU-10 |
| T8 | JWT verification | Discovery → `jwks_uri`, per issuer, ES384 pinned, bounded unknown-`kid` refetch, fail closed; JWKS/key unavailable → 503, never 400 | Owner (D-23, BX-7) | — | Not implemented — WU-11 |
| T9 | RP-Initiated Logout | OpenID Connect RP-Initiated Logout 1.0 per D-33 (single logout, RP clears itself first, GET and POST as request, separate confirmation POST, `id_token_hint` stored by the RP; expired hint validation ≠ authentication) | Owner (D-33) | 2026-09-20 RP logout amendment text | Not implemented — WU-14 |
| T10 | BCL | Back-Channel Logout 1.0 per D-26 … D-32; promise wording, executor contract and receiver parent Pending (X-3) | Owner + Open | Shared-DB logout ADR for first-party RPs | Not implemented — WU-15 (partly blocked) |
| T11 | OP authority stop | One stop primitive for every OP stop (BX-1); matrix, lock order and stop-event parent Pending (X-4) | Owner + Open | — | Not implemented — WU-16 (Blocked) |
| T12 | Sign-out | H5 method C; SO-1/2/7 Pending (X-14) | Owner + Open | — | Not implemented — WU-22 (Blocked) |
| T13 | Identity stop | Durable propagation kept (D-34), through T11 so RPs get BCL | Owner | — | Not implemented — WU-16 |
| T14 | RP return target | The RP owns it (D-55). Carried as `target_link_uri`, a relative path with no query or fragment, on `GET /sign` and the `POST /sign` hidden field, then as a claim of the RP's ES384 JWS `state` (D-149, D-151); used once after a successful callback and RP session; signed, not encrypted, so the path is readable to the OP, Visa and Jump (accepted, D-162; concern in `docs/backlog/2026-10-23-rp-target-link-uri-path-exposure.md`). The RP `pt` is abolished; Auth's own signed `pt` lane is unchanged (D-86) | Owner | D-42, D-109, D-137 (carrier) | Not implemented — WU-43 (WU-21 merged) |
| T15 | Bootstrap | Out of this cycle (D-170); plan in `docs/backlog/2026-10-23-org-seed-operator-bootstrap.md` | Owner | — | Backlog |
| T16 | Passkey | Identifier-first per ADR-PK, implemented this cycle (D-112); capacity ten per Identity (D-116, superseding ADR-PK's four slots) | Accepted ADR | `webauthn-discoverable-direct-sign-in` (partial) | Not implemented — WU-20 (Blocked) |
| T17 | i18n | Region root fix **not defined** (WU-19 Blocked on X-11); surface namespaces for Auth COM/ORG fixed (D-68); Base COM/ORG in backlog | Owner (D-40, D-68) + Open | — | D-68 implemented (unverified beyond its tests); root fix not defined |
| T18 | Credentials / KMS | One credentials set per environment (D-15); AWS KMS direction, co-location Pending (D-17); production key names mismatch the code (backlog) | Owner | Per-role secret design | Docs only — WU-23 |
| T19 | Refusals and observability | Six refusal classes (D-73): ownership mismatch (consume nothing, change nobody else's state), retryable (keep the Flow within its rules, e.g. Turnstile), definitive refusal of the owner's own attempt (D-47 uniform error + attempt end), dependency failure (no authority issued, no needless consumption), internal inconsistency (fail closed + auditable record), OIDC protocol refusal (standard response). One reason-coded event per refusal, no references, tokens, codes or contact data | Owner (D-73, D-47 narrowed) | D-47 "every refusal", OBS-1 restart page | Not implemented — WU-07 |
| T21 | Sign entry Sentry | Flipper-controlled admission of **new** Sign In / Sign Up per surface (D-84): six `:availability` flags `sign_{in,up}_available_{app,com,org}`, explicit `true` only, unset or store failure = `BLOCKED`; two states `ALLOWED`/`BLOCKED`; Sentry is not Admission, Guardrail, Checkpoint or Waiting Room and grants nothing. Auth-hosted `GET /sign/in/sentry` → `/sign/in` and `GET /sign/up/sentry` → `/sign/up`, 503 + `no-store` when blocked (D-85); request context via existing concerns, only the Admission reference passed explicitly (D-86). Sign-in path only (D-44): the Re-verification path, existing sessions, Refresh, Sign Out and `prompt=none` are outside. Enforcement at every point through `SignEntrySentryResolver` (D-93, D-94), callbacks refused (D-95), ORG Emergency outside and invitations gated (D-96), one-change replacement of `sign_up_suspended_*` (D-97), no OP pre-check (D-98), `BLOCKED` retryable and store failure a dependency failure (D-99) | Accepted ADR `adr/sign-entry-sentry.md` (Owner decisions only) | `sign_up_suspended_*` (replaced in one change, D-97) | Not implemented — WU-29 |
| T22 | Security Mode | Accepted target: `security_mode_id` with `NORMAL=3`/`ADVANCED=7`; APP/COM `ADVANCED` ordinary sign-in requires a passkey (C1); `ADVANCED` minimum two active passkeys (consolidation ADR). **Today (local tree):** `mfa_level_id` with `NOTHING/WEAK/MEDIUM/FULL` = 0/1/5/9; `AuthenticationBase#mfa_required_for?` = level ≠ `NOTHING`; `mfa_bypassed_for_auth_method?` = passkey; so a non-`NOTHING` account may sign in by email OTP + TOTP, which `ADVANCED` C1 would refuse. Gap to an unimplemented contract, not a proven bypass of a current one | Accepted ADRs `authentication-security-mode.md`, `…-cycle-consolidation-2026-10-15.md` (+ their Open decisions) | — | Not implemented — this-cycle scope X-36 |
| T23 | Email Sign-In OTP retained result | Accepted target (ADR 2026-10-11): A — an OTP is accepted only by its originating ceremony and continuity context; B — a consumed OTP is never accepted again, at most one success under concurrency; reconciliation of `already_verified` is TBC in that ADR. **Today (local tree):** `AuthEmailOtpChallenge#verify_email_otp!` returns `already_verified` without comparing the submitted code once `verified_at` is set and `result_expires_at` has not passed (after the scope, cancellation, parent, binding and contact-lock checks); `AuthEmailOtpVerificationResult#verified_evidence?` treats it as `verified`, and `Auth::Com::Sign::In::EmailsController#update` then calls `AuthenticationSessionCommitter` again. Not shown to be exploitable; the retry is reachable at least while the browser still holds `user_email_authentication_id` (e.g. a lost response) | Accepted ADR `email-sign-in-otp-ceremony-binding-and-risk-acceptance.md` (A target, B invariant) | — | Not implemented — X-37 (the ADR's Auth/Xper freeze note applies) |
| T24 | ORG normal sign-in halt audit | FLOW-6: an attributable halt writes exactly one durable `SIGN_FLOW_HALTED` Chronicle record. **Today (local tree, unchanged since the audit):** `OrgNormalSignInTransaction#halt_org_normal_sign_in_transaction!` only updates the Rails session; 409, HALT and no new token/challenge hold, but zero Chronicle records (reproduced 2026-10-13, C6R2). Known defect deferred on 2026-10-13 without a target cycle | Backlog `org-normal-sign-in-durable-halt-audit.md` (FLOW-6 contract) | — | Not fixed — X-38 |
| T25 | Sign-in failure convergence | Durable Sign Up is never undone by a Sign-in failure (Sign In First). `SignInResult` separates evidence recorded, MFA pending, session-limit pending and issued; `AuthenticationSessionCommitter` delegates to the existing issuer and each controller still maps the result to HTTP. Per-method convergence after a successful credential (issuance failure, limit, MFA pending, OIDC handoff failure) is not proven. Overlaps T19 (D-73 classes) and X-20 | Backlog `sign-in-failure-handling-plan.md` + Owner (D-73) | — | Not done — X-39 |
| T20 | Gates | `three.md` G-1 … G-22 (D-124); H4 Gates replaced; G-1 baseline taken 2026-10-23 (`evidence/2026-10-22-g1-full-test-baseline-B7G1.md`) | Owner | H4 §8 Gates | G-1 executed; others defined |

**D-45** (owner, 2026-10-21) **Sign-in path curfew: 30 minutes from Base → Auth.** t = 0 is the moment
Base hands the browser to Auth (admission issuance for the ceremony); the Auth → Base result must be
**accepted by Base before t + 30 min**, otherwise it is rejected. This single absolute deadline
refines D-36/D-41: the Auth sign-in page, every action on it, provider callbacks (Google/Apple),
evidence recording, result issuance and Base's result receipt all compare against the same stored
deadline. Source finding behind it (2026-10-21): today Social uses the 60 s acceptance deadline
(`auth_social_admission_binding!`), Email/Passkey/Secret under an OIDC parent check only the 30 min
ceremony session (`auth_ceremony_matches_intent?` ignores the parent's expiry), and result issuance
checks the OIDC `login_challenge` (10 min) (`base_auth_admission_coordinator.rb:1036, 1110`) — so
Social refuses too early and the others can fail after the user has authenticated. Implementation
obligations: anchor one deadline at t = 0 and carry it to the ceremony session; parents that today
expire earlier (OIDC `login_challenge` 10 min, OIDC transaction 15 min, Local Sign-in Flow 15 min,
Sign-up Flow 15 min) must not cut the window short; ~~the RP's own pending OIDC state must outlive it~~
*(superseded by D-160: the RP `state` has its own 30 minutes and may end a few seconds earlier)*;
short-lived **carried values stay short** (60 s acceptance, 10 s authorization code); after the
curfew every action yields the recoverable restart page (D-41). **Sign-up is included**
(owner, 2026-10-21): sign-in and sign-up share the same 30-minute curfew; a sign-up exceeding it
completes registration but its Sign-in handoff is refused (user signs in again).

**REQ-CURFEW — Sign-in path ceremony curfew** (owner-approved wording, 2026-10-21; normative text for the
later ADR)

1. **Anchor.** When Base issues the Admission that hands the browser to Auth for a Sign-in path sign-in
   or sign-up, Base MUST record one curfew instant `deadline = t0 + 30 minutes`, where `t0` is the
   database time of that issuance. The curfew MUST be stored once, on the Admission Binding, and
   MUST NOT be recomputed or extended afterwards.
2. **Single source.** The Auth ceremony session, the Sign-in Flow, the Sign-up Flow and the
   Auth → Base result MUST obtain the curfew from that Binding. No other expiry MAY permit an action
   after the curfew, and no parent expiry (OIDC transaction, `login_challenge`, Sign-in Flow,
   Sign-up Flow) MAY end the window before the curfew. The RP `state` is not an OP parent: it has
   its own 30 minutes on the Rails clock and may end a few seconds before the curfew (D-160).
3. **Consumers.** Each of the following MUST refuse when `database_now >= deadline` (30:00 and later
   is out; anything earlier is in): rendering the Auth sign-in or sign-up pages; every Auth action
   (method selection, Email, Telephone, Passkey, Secret, Google, Apple, Cancel, Switch, each sign-up
   step); provider callbacks returning to Auth; recording authentication evidence; issuing the
   Auth → Base result; and Base's acceptance of that result. A result issued before the curfew but
   presented to Base at or after it MUST be refused.
4. **One decision, one clock.** These checks MUST use one shared decision comparing the stored
   curfew with PostgreSQL time (`database_now`), so Base and Auth compare against the same clock.
   Ordinary server time precision is sufficient; no sub-second guarantee or external time source is
   required (owner).
5. **Carried values stay short.** The curfew MUST NOT lengthen any value the browser carries: the
   Admission acceptance code (60 s), the Base → RP authorization code (10 s) and every other
   single-use reference keep their own shorter lifetimes, each also capped by the curfew.
6. **After the curfew** (rewritten by D-160). A refused action whose browser binding proves it is the
   owner's own attempt ends the authorization transaction through the Cancel route and returns to
   the registered `redirect_uri` with `error=access_denied`, the unchanged `state` and `iss`; the RP
   lands on `GET /sign/interruption`. A Cancel pressed after the curfew has the same outcome. A
   request whose ownership is not proven ends nothing and gets the local uniform error (D-73). When
   the transaction row no longer exists, Auth shows the uniform error (D-47). Never reuse of the
   expired ceremony.
7. **Registration outcome.** A sign-up completing registration at or after the curfew keeps the
   durable registration; only its Sign-in handoff is refused and the user signs in again. No
   compensating deletion.
8. **Scope.** Sign-in path only. Re-verification path keeps its own lifetimes (D-44).
9. **Tests.** Each consumer in 3 is tested just before, exactly at and just after the curfew, plus a
   result issued before and presented after it.

Note on REQ-CURFEW 2 (owner, 2026-10-21): the earlier 15-minute Sign-in/Sign-up Flow default
(`SignFlow.default_ttl`, introduced 2026-05-30 in `3471d9edea`), the 30-minute ceremony continuity
(`AuthCeremonySession::DEFAULT_TTL`, 2026-09-13 `54fea648ef`) and the OIDC 10/15-minute defaults have
no recorded rationale; they were independent component defaults. Flows are server-side state, not
carried values, so aligning them to the curfew (valid while elapsed < 30:00) weakens nothing; the
short carried values keep their own lifetimes (REQ-CURFEW 5).

**D-46** (owner, 2026-10-21) **Carried Sign-in path codes: 10 seconds, together with the automatic relays.**
Once the path from the RP "続行" (e.g. `https://www-jp.umaxica.app/sign?ri=jp`) to
`https://auth.umaxica.app/sign/in?ri=jp` runs entirely by redirects (five.md Design D), the Admission
acceptance code (`OpaqueAdmissionStore::CODE_TTL`, today 60 s, which also caps the binding's whole
attach → confirm → redeem life) becomes **10 s**, counted from Base's issuance at `/oauth/authorize`;
the Auth → Base result code becomes **10 s**, counted from Auth's issuance. The RP → Base hop before
issuance is not counted. Must not ship before the relays are automatic (with today's three Continue
clicks inside the window, 10 s would refuse ordinary users). Expiry leads to the REQ-CURFEW 6 restart
page. Shortening also narrows the F-2 stolen-reference lock-out window. Revisit with measured
redirect latency if slow networks fail.

**D-47** (owner, 2026-10-21) **Sign-in path errors: end the attempt and return a plain error.** Every
Sign-in path refusal — social crossings (sign-in entry + unknown identity, sign-up entry + registered
identity, unavailable account, identity released during the ceremony, provider cancel/error,
invalid `state`), curfew expiry and every other ceremony refusal — ends the attempt, clears the
related Rails-session state (social intent, Sign-up/Sign-in Flow locators, ceremony continuity) and
returns one uniform error response (same status and body for every cause). No suggested next action,
no switch offer, no restart page, no link back to `/sign`; reason codes go only to server logs
(OBS-1). **REQ-CURFEW 6 and OBS-1 / D-41's "recoverable restart page" are rewritten accordingly.**
Rationale (owner): a live Rails session carried into a recovery step can cause accidents in sign-in
/ sign-up; a uniform error also hides whether a provider account is registered. Social policy P1
(owner): sign-in accepts only the sign-in path, sign-up only the sign-up path, decided by the
Admission's `entry_intent` (never params/Referer); a Sign-up Flow is created only after the callback
under a sign-up Admission. Provider email is never stored (contact existence is proven by UMAXICA's
own OTP), so provider-email verification and email-collision cases do not exist.

**D-48** (owner, 2026-10-21) **Social callback state matrix (APP Google/Apple; ORG deferred until APP is
done).** Axis 1 = Admission `entry_intent` (sign_in / sign_up); axis 2 = provider outcome; axis 3 =
local state of `(issuer, subject)`.
- L1 unknown: sign-in → error (D-47); sign-up → create the Sign-up Flow only now (E1 FK) and continue.
- L2 registered and usable: sign-in → sign in; sign-up → error.
- L3 linked Client unusable: error in both.
- **L4 identity without a Client**: impossible by schema (`client_external_identities.client_id` NOT
  NULL + FK to `clients`); **raise, return 5xx, log at FATAL, never proceed**; remove the
  "treat as unknown" branch (`SocialAuthLoginHandler#login_existing_identity` `user.blank?`).
- L5 released during the ceremony (`released_since_ceremony?`): error in both.
- **L6 linked Client still `UNVERIFIED_WITH_SIGN_UP`** (an abandoned sign-up left Zenith rows): never
  pass; render a fixed message and end (D-47) in both.
- **L7 provider-side revocation** (`consent_revoked` / `account_deleted`, set by Apple server
  notifications, the user's own action, not a UMAXICA ban; the notification changes `state` but not
  `released_at`): sign-in → error; must be detected explicitly (today `find_by_subject` returns only
  `active`, so these look unknown and a sign-up fails late on the `(issuer, subject)` unique index).
  **Sign-up → error as well** (owner, 2026-10-21, chosen for safety while the provider-event
  behavior is investigated): render the fixed message and stop (not a raise / 5xx). Whether a
  revoked or deleted identity may later be re-registered or re-linked is in
  `plans/backlog/2026-10-21-social-provider-account-event-notifications.md`.
- **L8 UMAXICA ban on the provider subject** (`AppEnforcementIdentifierEffect` kinds `google_subject` /
  `apple_subject`): sign-in, sign-up and identity linking all render a fixed message and stop.
  **Gap found**: no social path consults these effects today; the check must run first in the
  callback, before identity lookup.
- Provider cancel / error / `login_required`, invalid `state`, curfew: error (D-47).

**D-49** (owner, 2026-10-21; **provisional — revisit after implementation, may be loosened or improved**)
**Repeated requests on the Design D path (five.md §9 Q4).** Principle: an effect happens once; a
repeat either returns the first outcome or errors. Not decided by HTTP method.

| Hop (Design D, warp jp example) | Repeat sources | Rule |
|---|---|---|
| `POST https://www-jp.umaxica.app/sign` | double click, resubmission | RP's ordinary handling (new pending OIDC flow, limit 2) |
| `GET https://www.umaxica.app/oauth/authorize?…` | auto-retry, double click | standard; each request is a new transaction, old ones die at the curfew |
| `GET https://jump.umaxica.net/?rt=…` and the Jump return | auto-retry | `rt` is **reusable within its ≤ 30 s life by design** (`rpl = "reuse"`, ADR `jump-directed-rails-handoff-contract.md`; `JumpRtReturnVerifier` records no consumed `jti`); it carries no authority, the next hop's one-time consumption is the guard |
| Auth attach / Base confirm / Auth redeem continuation GETs | auto-retry, double click | same bound browser and ≤ 10 s from issuance (D-46) → the same next redirect, no second effect; otherwise error (D-47) |
| `GET https://auth.umaxica.app/sign/in?ri=jp` | reload | clean URL, harmless within the curfew |
| Credential POSTs (OTP, Passkey, Secret) | resubmission | each method's own single-use verification |
| Base result receipt GET (creates the Root Session, issues the RP code) | auto-retry, double click | **always error** — returning "the same outcome" would mean reissuing (D-2). Recovery: the user presses "続行" again and the existing Root Session yields a fresh code through the standard SSO path |
| `GET https://www-jp.umaxica.app/oidc/callback?code=…&state=…&iss=…` | reload | standard single use of code and `state` |
| Any hop from **another browser** (leaked URL) | — | error without consuming (binding checked first) |

Single-use mechanisms relied on (existing): Valkey Lua CAS `issued → consumed` on digest keys with
expected-binding comparison before consumption and TTL (`OpaqueAdmissionStore`, `AuthorizationCodeStore`);
PostgreSQL row locks with state columns, CHECK constraints and live-binding partial UNIQUE (Binding);
transaction row lock + `base_finalized_at` + `result_generation` (Root Session finalization);
`OpSessionBinding` row lock + `rp_callback_states.consumed_at` (RP callback); no reissue (D-2).
Obligations for Design D: fixed order — cookie binding check (PostgreSQL) → Valkey CAS → PostgreSQL
state transition under lock; a Valkey-consumed/PostgreSQL-failed split ends in error (no
compensation); "same next redirect" is decided from PostgreSQL state (redeemed and admitted session
== the cookie's session, as `AuthCeremonyAdmission#redeemed_binding_matches_cookie?` does today), never
from Valkey payloads; the 10 s replay limit counts from `redeemed_at`; Valkey unavailable → fail
closed; concurrency tests on separate DB connections. **Tunable after measurement**: the 10 s
codes/replay window, which hops tolerate a same-browser repeat, the error-vs-same-redirect choice for
the result hop's lost-response case. Correction recorded: an earlier table wrongly called the Jump
`rt` single-use.

**D-50** (owner, 2026-10-21; five.md §9 Q5) **Old browsers and missing Fetch Metadata — two layers.**
(1) `allow_browser versions: :modern` (Rails 7.2+;
<https://api.rubyonrails.org/v8.0/classes/ActionController/AllowBrowser/ClassMethods.html>) stops
outdated real browsers with 406; every admitted browser (Safari 17.2+, Chrome 120+, Firefox 121+,
Opera 106+) supports Fetch Metadata. (2) Because `allow_browser` trusts the `User-Agent` and lets
unlisted or UA-less clients through, every Sign-in path relay continuation GET refuses (D-47 uniform
error), before binding checks or consumption, a request without `Sec-Fetch-Mode: navigate` and
`Sec-Fetch-Dest: document`. The BCL receiver `POST /oidc/closures` is excluded from `allow_browser`
(CR R-09). Documented in `docs/dds.md` (Browser allowlist).

**D-51** (owner, 2026-10-21; five.md §9 Q2) **F-2 accepted as a residual risk, with a standing check.**
A stolen live admission reference can let a thief attach first and deny the victim's attempt; it
cannot take the sign-in over (Base confirmation and result receipt check the originating
browser). Accepted because the effect is nuisance only, the window becomes 10 s (D-46) and the user
can restart. Condition (owner): because today's defects entered exactly where sign-in components
were rearranged, "takeover is impossible" is a standing acceptance item — added as
`docs/checklists/authentication.md` AUTH-19 and re-verified with foreign-browser refusal tests at
attach, confirmation, redemption and result receipt whenever those components change (to be carried
into `three.md`).

**D-52** (owner, 2026-10-21; five.md §9 Q3) **Every cross-surface browser navigation uses Jump — kept as
a rule for accident prevention** (reaffirms `adr/jump-directed-rails-handoff-contract.md`).
`jump.umaxica.net` (and the future `away.umaxica.net`) are security choke points kept in a separate
repository on a separate registrable domain so that a Rails-side defect is still stopped outside
Rails and cookies cannot mix; the signed `rt` and `JumpRtReturnPolicy::ALLOWED_EDGES` block
unpermitted destinations even if Rails builds a wrong URL. Base ↔ Auth keeps Jump. Consequence:
because a Jump hop makes `Sec-Fetch-Site` `cross-site` for legitimate and hostile navigations alike,
**relay continuation GETs do not check `Sec-Fetch-Site`**; they rely on cookie binding, single use
and the 10 s life, `Sec-Fetch-Mode: navigate` + `Sec-Fetch-Dest: document` (D-50) and Jump's `rt`.
`Sec-Fetch-Site` remains useful for user-action POSTs (CSRF), which do not traverse Jump. External
RPs are not UMAXICA surfaces: their arrival at `/oauth/authorize` and the OP's return to their
exactly registered `redirect_uri` / `post_logout_redirect_uri` are direct protocol redirects, not
through Jump or Away (proposal for X-7). Away remains a future, separately designed gateway for
user-initiated external navigation (`plans/backlog/xt-away-external-navigation-gateway.md`).

**D-53** (owner, 2026-10-21; resolves X-7) **RP scope = the three UMAXICA TLDs only**, recorded as
`adr/oidc-rp-scope-umaxica-tlds-only.md` (Accepted, decision only). `umaxica.app` / `.com` / `.org`
are the only RPs; every other domain, including `umaxica.dev` and `umaxica.net`, is external; no
external RP is connected now (contracts stay standards-shaped for extensibility only); other systems
integrate through `tech.umaxica.org` (e.g. a `umaxica.dev` SSO goes through Tech).

**D-54** (owner, H7 decision A, 2026-10-21) **Every first-party RP starts on one common method.**
Warp, Base, Palm, Core and the others first follow the same standard OIDC Authorization Code Flow +
PKCE; platform constraints (e.g. Palm on iOS/Android) are handled inside that method, never by a
separate protocol. Base is no exception: it is treated as a standard RP of its own OP, with no
internal OIDC shortcut. Optimizing Base later is a separate future decision, taken only after
stability is verified and the need is clear; it is not a reason to skip the common implementation
now. Existing ADRs and code that contradict this must be listed and reported (Phase 3). Consistent
with D-23 and `adr/base-authority-and-self-rp-separation.md`. **To verify (Phase 3):** whether Base's
Local Sign-in Flow (`/sign/handoff`, `/sign/completion`, `BaseLocalAuthenticationCompletion`) is
such a shortcut, and what consumes it today.

**D-55** (owner, H7 decision B, 2026-10-21) **The RP owns the return target.** Two entries exist:
(i) an explicit Sign in / Sign up chosen on an RP page (e.g. `GET https://www-jp.umaxica.app/`);
(ii) an unauthenticated request for a protected page (e.g.
`GET https://www-jp.umaxica.app/<protected-path>?ri=jp`), which keeps the original path and the
permitted query. The RP validates and fixes the target, stores it in its own authentication
transaction tied to the OIDC `state`, returns to it only after callback validation and RP session
establishment, and never reuses it after a normal completion. Only the RP's own permitted internal
paths are allowed; dangerous URLs, nested redirects and queries carrying secrets are refused. Base
OP, Auth and Jump do not manage or overwrite it. Today's mechanism to evaluate (H7 §3.4, not yet
verified in this worktree): `OidcSsoInitiator#remember_oidc_pending_flow!` stores `pt` in the
pending flow keyed by `state`; `OidcCallback` restores it; Warp App maps `/` to the dashboard;
`BrowserRpAuthentication` builds `sign_in_url_with_pt(encoded_pt(request.fullpath))` and, for
Inertia, answers 409 + `X-Inertia-Location`. Narrows X-5 to the entry input format (D-42 still
rules out plain `pt` as the carrier).

**D-56** (owner, H7 decision C, 2026-10-21) **RP responsibilities and the Admission protocol stay
separate.** Route: first page → RP sign entry → Base OP `/oauth/authorize` → Base OP ↔ Auth
(Admission) → RP `/oidc/callback` → the target fixed before authentication. The RP's entry and
return-target handling and the Base ↔ Auth Admission are separate responsibilities. The Sign-up
and Sign-in state machines are not merged (reaffirms D-3).

**D-57** (owner, H7 decision D, 2026-10-21) **ADRs are revised when needed, after a consistency
check.** No ADR is written now. When implementation needs one, Claude Code or Codex revises it;
existing ADR meaning is checked first, never bypassed.

**Design D status (H7 §4).** five.md Design D (CSRF POST for user decisions, redirects for the
relays after it, Base ↔ Auth Continue pages replaced by continuation GETs) was **not approved** on
2026-10-21; **superseded: adopted by D-100 (2026-10-22)**, so D-46 … D-52 now apply. Safety properties any variant must keep (H7 §4.1):
browser binding checked at both Base and Auth; Admission cookie/binding comparison before
consumption; atomic CAS and state transitions; current generation, evidence and subject checked on
the result; foreign-browser takeover refused; replay and double finalization prevented; relay
responses `no-store` and `no-referrer`; final URL cleanup; separate Sign-up and Sign-in state
machines. Rejected by Codex and not to be proposed again: removing the Base ↔ Auth confirmation
round trip, an extra server-side PKCE-like secret, and JavaScript auto POST. The central open
question is whether Base may establish a Root Session on a GET (**X-1**, with H7's five questions).

**Test-run findings** (TR, 2026-10-21; HEAD `febec3225`, worktree dirty; the failures reproduce
when each test runs alone, and this session's uncommitted changes, comments and the Secret back
link, do not cause them). All six groups trace to the 2026-10-20 session fixation containment in
`febec3225` (`evidence/2026-10-20-session-fixation-result-retry-S7F3.md`), which removed behavior
without changing tests and recorded the redesign of lost responses, finalized-result retries,
sign-up → sign-in continuity and concurrent tabs as **mandatory follow-up** (**X-20**). G1 was
confirmed from the logs of every listed test; G2–G6 were classified from representative logs and
status codes.

| Group | Cause | Tests (≈) | Effect |
|---|---|---|---|
| G1 | `bind_committed_login!` no longer preserves the RP session keys (`oidc_code_verifier`, `oidc_state`, `oidc_nonce`, `oidc_pt`, `oidc_pending_flows`) across `reset_session`. On the shared Base host the OP login wipes the self-RP's pending flow; `/oidc/callback` returns 422 `state_invalid` | 25: Google/Apple, dashboard Passkey, ORG Entra + Passkey, Secret journey | **Every Base self-RP sign-in and sign-up fails at the last hop** (D-54 route broken). **X-19** |
| G2 | Finalized-result reissue removed; a second result GET/POST returns 400 | 10: result CSRF transport, `oauth_oidc_authority` retry, surfaces "reuses a finalized session", email sign-up root completion, ORG handoff | Intended (D-2); the tests are stale. The lost-response journey is undesigned (X-20) |
| G3 | The browser nonce is reissued on every initiation, so a second initiation in one browser replaces the first binding's nonce: `transaction_conflict` 400 instead of 409 | 9 Step-Up, 1 Passkey Step-Up, 2 Secret parallel/concurrency | Step-Up is Re-verification path (out of scope, D-44). The parallel/concurrency tests are Sign-in path multi-tab behavior (X-20) |
| G4 | The pre-login sign-in locator is no longer written back after `log_in`; `/sign/completion` returns 400 and `RecordNotFound` | 2: `local_authentication_boundary` | The Base local email sign-in likely fails at its first completion. Cause not yet proven |
| G5 | A committed but uncompleted social sign-up is refused instead of re-entering `log_in` (422) | 2: `base/app/social/authentications_controller` | Intended; the tests are stale |
| G6 | 422 on contact registration with OTP bootstrap and on `verification/setups` | 7 | Cause not identified |

**D-58** (owner, 2026-10-21) **The Rails session cookie is host-only in every environment.** Sharing
a session across subdomains is a design UMAXICA must not use. The old development/test `Domain`
apex (`.umaxica.app` via `CoreCookieDomain`) was wrong and is removed, so this is a migration, not a
compatibility option. The production `Partitioned` attribute on the session cookie is also removed.
Basis: the Rails and Rack default is no `Domain` (`Rack::Session::Abstract::Persisted::DEFAULT_OPTIONS`
`domain: nil`; Rails cookies documentation "Does not set cookie domain. (default)"); the default
SameSite is Lax (Rails 6.1+ `cookies_same_site_protection`); RFC 6265bis draft-20 §4.1.2.3 (no
`Domain` means the origin host only), §4.1.3.2 (`__Host-`), §8.6 (no integrity between sibling
domains). Motivation (owner): after the planned repository split each application has its own
credentials (`secret_key_base`), and a shared-domain cookie of the same name would be overwritten
and wiped by each other. Kept: `SameSite=Lax`, `HttpOnly`, production `Secure` + `__Host-session`.
Implemented in `lib/jit_session_cookie_config.rb` (§6). Other cookies that still share by domain
(`CoreCookieOptions` default `domain: true`, `CoreCookieDomain`) and their production `Partitioned`
are outside this change (**X-22**).

**Naming (owner, 2026-10-21):** "System A" and "System B" are renamed because the letters were hard
to follow. **Sign-in path** (サインイン系) = a person who is not signed in signs in or signs up.
**Re-verification path** (再確認系) = a person who is already signed in proves themselves again
(Step-Up, reauthentication, credential registration or change, bootstrap tickets). Older records and
`five.md` before this date use the letters.

**D-59** (owner, H8, 2026-10-21) **The OP moves to Visa.** Visa OP `visa.umaxica.{app,com,org}`; Base RP
stays on `www.umaxica.{app,com,org}`; Auth ceremony on `auth.umaxica.{app,com,org}` is unchanged.
Same Rails, Puma and databases; no separate process. OP controllers move to the
`Visa::{App,Com,Org}` namespace and `config/routes/visa.rb`, following the existing per-service
route files. Logical host names `visa-app-ww`, `visa-com-ww`, `visa-org-ww` follow the
eleven-character `<family>-<realm>-<scope>` rule (`RpDeploymentBindingValue`); Jump issuer
namespaces `VISA_APP`/`VISA_COM`/`VISA_ORG`. Base RP client IDs `base-*-ww` stay. Not apex, not an
Auth redesign. Scope limits from H8: no Playwright/browser E2E, no Jump/Edge repository change, no
compatibility code; the Rails-side Jump contract and a handoff specification for Jump are
delivered. Resolves X-19. Definition: `two.md` WU-02.

**D-60** (owner, 2026-10-21) **Remove the entry-less Local Sign-in Flow, through `two.md` WU-01.** Its
entry was deleted on 2026-10-08 (`48ff7040de`); the receivers and local branches remain. Not deleted
in this conversation: the implementer runs WU-01 with a dead-code check (callers, reachability,
unchanged OIDC test results) before each deletion. The `*SignInFlow` models, session limit and
social completion stay (shared with OIDC).

**D-61** (owner, 2026-10-21; resolves X-23) **Two ceremony-binding confirmation endpoints after the Visa
split.** The Sign-in path (sign-in and sign-up: `authentication_handoff`, and `invitation_handoff`
if it is confirmed to belong here) issues its Admission on Visa, so its confirmation lives on Visa
and checks the browser nonce in the Visa session. The Re-verification path (`step_up`,
`reauthentication`, `credential_registration`, `credential_change`, `bootstrap`) starts on Base
`www` pages, so its confirmation stays on `www`, unchanged. Reason (owner): Step-Up is a different
thing from sign-in. Consistent with D-44 (the two paths are implemented separately; the
Re-verification path is out of scope now). Each endpoint refuses the other path's purposes.

**D-62** (owner, adopting ChatGPT review H9, 2026-10-21) **WU-02 Phase 1 approved, with resolutions**
recorded in `two.md` §2.4a: independent Visa JWT namespaces/keys/JWKS with issuer and signers moved
together (D-K); Welcome stays on Base RP and decides from the verified callback and RP state, the
Selector is classified by reachability before ownership, and no Rails session is shared between
Visa and Base (D-S); cookie consent belongs to Base RP (D-E); `visa-*-ww` are logical host
identities, not client IDs; ceremony binding checks purpose ↔ host fail-closed; R2 approved
(separate `PUBLIC_VISA_*` / `PUBLIC_BASE_*`, no fallback, return target by requester and receiver,
every reader classified).

**D-63** (owner, 2026-10-21) **Remove `/edge/v0/cookie`.** The frontend is being rebuilt and nothing in
this repository calls it; `/api/v0/preferences/cookie` is the browser endpoint. Implemented through
`two.md` WU-03.

**D-64** (owner, 2026-10-21) **Remove `AuthenticationSequenceGate#continue_selector_sequence!`** (dead
since 2026-10-08), through `two.md` WU-01.

**D-65** (owner, 2026-10-21) **Visa keys follow the current key handling, as is.** Although the
credentials/key-name mismatch is known (`plans/backlog/2026-10-21-production-credentials-key-name-mismatch.md`,
to be fixed later), WU-02 adds `VISA_{APP,COM,ORG}` in the same style as the existing namespaces:
listed in `JitSecurityJwtRegistry` (namespaces and issuer origins), development/test keys generated
by `JitSecurityJwtLocalKeysetInstaller`, production read as `JWT_VISA_*_{ACTIVE_KID,PRIVATE_KEY,PUBLIC_KEYSET}`
through `Rails.app.creds`. Reason (owner): diverging from the current style now would conflict with
other work and add design questions. WU-02 does not fix the mismatch, rename other namespaces or
remove `ACME_*`; writing production credentials stays an owner task under that backlog item.

**D-66** (owner, H10, 2026-10-21) **Fix the missing visible Turnstile on the app sign-up telephone SMS OTP
check** as a security-audit inconsistency, through `two.md` WU-04. Email already validates Turnstile
before the OTP check; telephone does not. Not implemented in this conversation. H10 also refers to
an earlier "Sign-up unification" policy and a "Sign-up Finalization" commonization that are **not
recorded in one.md or two.md**; their content must be supplied before they are treated as agreed.
Observed, not in scope: the same gap exists on COM.

**D-67** (owner, 2026-10-21) **COM telephone SMS OTP gets the same visible Turnstile fix** (same gap as
app; COM email already has it). WU-04 now covers app and com. The "Sign-up unification" and "Sign-up
Finalization" policies referred to by H10 are still being decided by the owner and will be supplied
later.

**D-68** (owner, 2026-10-21) **Auth COM/ORG copy moved to its own namespace (implemented in this
conversation).** 69 COM keys and 1 ORG key that borrowed `sign.app.*` now resolve to `sign.com.*` /
`sign.org.*`; where a COM key already existed with different text, the COM text was chosen (option
A). Guarded by `test/security/invariants/auth_surface_translation_namespace_invariant_test.rb`.
Evidence: `evidence/2026-10-21-auth-com-org-translation-namespace-Q8T4.md`. Base COM/ORG
controllers (81 app keys) are not done.

**D-69** (owner, H12, 2026-10-21) **WU-05 decisions U1–U6** as recorded in `two.md` §5.F: social pending
Client in Auth after evidence and confirmation, External Identity only at Finalization with
uniqueness re-check; candidate store reused with lifetime ≤ curfew and no revival; order WU-04 →
WU-05 → WU-02 without new Base host/session dependencies; the new ADR before implementation;
resume/re-registration only on proven authority over the own Flow or a fresh provider
authentication; full canonical Sign In First for Google/Apple; classify every use of the Base social
completion before removing it. Invariants and the second adversarial review: `two.md` §5.G–§5.J.
Still open: R-1 (provider revocation between confirmation and Finalization) and R-2 (the two
`ClientSignUpFlow.create!` sites, investigation).

**D-70** (owner, 2026-10-21) **WU-05 R-1/R-2/R-3.** R-1 (a): a provider revocation between confirmation
and Finalization (≤ 30 min) is an accepted residual risk. R-3: extend sign-up cleanup to
contact-less social pending Clients. R-2: one `ClientSignUpFlow` per social sign-up attempt is
approved, but moving its creation to the callback is **not** decided; both current creation sites
are investigated first and options are brought back.

**D-71** (owner, 2026-10-21) **Remove the dead social sign-up callback path** (`handle_social_sign_up_intent`,
`create_social_sign_up_flow!`, `bind_social_sign_up_flow!`, `social_sign_up_required?`) in WU-05.
Finding recorded with it (`two.md` §5.J-2): the ordinary Admission carries no sign-in/sign-up intent
for first-party RPs (`authentication`), so D-47 P1 needs an explicit effective intent first.

**D-72** (owner delegated to the recommendation, 2026-10-21) **Explicit effective intent + one social Flow
at the entry (R2-A).** Effective intent = Switch `entry_intent`, else `prompt=create` → sign-up, else
sign-in (`authentication` counts as sign-in); computed once from server state, never from params,
Referer or the page; sign-up pages require sign-up, sign-in pages require sign-in. The social
sign-up Flow is created only at the entry under a sign-up effective intent, bound to the Admission
(E1), expiring at the curfew; the callback never creates one. Makes D-47 P1 enforceable. Details:
`two.md` §5.J-3.

**Owner decisions on `six.md` Q1–Q14 (2026-10-22, H14).** Only the items below are decisions; the
rest of `six.md` stays a proposal.

- **D-73 (Q1)** Six refusal classes adopted (T19). D-47's uniform error and attempt end apply to a
  definitive refusal whose ownership is confirmed; ownership mismatch, retryable failures,
  dependency failures, internal inconsistency and OIDC protocol refusals are distinct. A forged or
  foreign request never consumes or ends a third party's Flow or Candidate.
- **D-74 (Q2)** Switch inherits the original attempt's absolute deadline; no reset or extension;
  nothing new is authorized after it.
- **D-75 (Q4)** Curfew clock = the OP database that owns the Admission Binding, `clock_timestamp()`
  read after the required Binding/Flow locks; no independent re-decision on another database's
  clock.
- **D-76 (Q5)** *(Superseded by D-150 and D-160: the RP `state` and pending entry live 30 minutes from
  `POST /sign`.)* RP pending OIDC state lifetime is derived from three bounds (RP pending creation →
  Admission issuance; the 30-minute curfew; the legitimate callback's return to the RP); no fixed
  value adopted before the bounds are defined; the authorization code's own short TTL is not
  extended.
- **D-77 (Q8)** A pending Client created in one Flow is never reused by another. Cleanup, after its
  locks, re-checks at least: the Client is still unconfirmed; Flow ownership matches; no other Flow
  confirmed it; no External Identity that forbids deletion exists. A confirmed Client/Identity is
  never removed on a stale decision.
- **D-78 (Q10)** The Candidate contract is the current PostgreSQL store (`IdentitySocialCeremonyCandidate`,
  OP DB, encrypted `auth_hash`); WU-05 C1/C3's Valkey assumption is corrected; the provider
  credential is not stored, provided it is verified to be unnecessary for registration; single
  consumption, expiry, encryption and fail-closed on outage stay mandatory; Valkey-backed Admission
  references keep fail-closed on Valkey outage.
- **D-79 (Q11)** The revocation endpoint supports each client's **registered** authentication method
  (`private_key_jwt` where registered for first-party RPs); Discovery metadata matches the
  implementation and registrations; not inferred from the token endpoint alone.
- **D-80 (Q12)** RP callbacks validate `state` / `iss` etc. first, then: `login_required` → may move
  to an interactive authorization by starting a new, legitimate transaction (old `state` and
  deadlines are not prolonged); `access_denied` → Cancel/refusal; other errors classified per the
  standard; no silent-authorization retry loop.
- **D-81 (Q13)** The `six.md` §B reconciliation is applied to §2–§5 (topic table with Current
  contract / Authority / Supersedes / Delivery; done 2026-10-22). Unapproved items stay Pending;
  Design D stays unaccepted (2026-10-22: superseded, adopted by D-100).
- **D-82 (Q14)** Only a read-only operational diagnosis for partial registrations is designed now
  (`two.md` WU-26). Automatic repair, compensating deletion and operator write procedures are a
  separate future decision.
- **D-83 (Q3, direction only; superseded by D-105)** A Finalization formally started before the deadline may complete its
  required durable writes after it, on conditions: the start is verified and committed on the
  authoritative database before the deadline; no new authentication evidence is accepted after the
  deadline; no new authority is issued after it; fail closed on partial commit; a lost COMMIT
  response never reissues authority. The existing `:finalize` inside the OP transaction is **not**
  a durable start record. Detail Pending (X-24).
- **Pending:** Q6 (10-second origin, with X-1; R23-INV-1 … 4 apply everywhere now), Q7 (X-26),
  Q9 concrete lock order (X-27; consistent order in principle approved, subject lock and
  `released_since_ceremony?` kept, no distributed atomicity implied).
- **R23-INV-1 … 4** (H13, mandatory): a resend never increases expiry, authority, single-use
  references or consumption chances; a foreign-browser resend consumes or ends nothing; a consumed
  or expired next-hop reference is never re-minted; a lost response after COMMIT never yields a new
  authentication result.

**Q7 investigation result (2026-10-22, static reading, not executed) — the proof fails today.**
1. Sign-in requires, per method, a matching credential (email/telephone OTP: the contact;
   social: an `active` External Identity; Passkey: an `ACTIVE`, non-discarded passkey) and the
   actor's `login_allowed?` (= `Withdrawable#active?` and status ≠ `RESERVED`) and `access_enabled?`,
   plus enforcement, cooldown and session limit. **`login_allowed?` does not refuse
   `UNVERIFIED_WITH_SIGN_UP`** (`Client::LOGIN_BLOCKED_STATUS_IDS = [ClientStatus::RESERVED]`).
2. The identity graph is not read by Sign In; it is created idempotently (`BaseSelectorBootstrapAuthority`
   `ensure_*`) at Finalization and lazily by the Base selectors — derived data, not an authentication
   precondition (authorization after login was not analysed).
3. Sign-up Flow status is not read by Sign In; it is progress management (and the record of the
   entry method).
4. Social: Client (`VERIFIED_WITH_SIGN_UP`) and External Identity are written in one principal
   transaction (`SocialAuthSignupFinalizer`). Email: the contact reaches `VERIFIED_WITH_SIGN_UP` at OTP
   verification, the Client is promoted later at Finalization (`Client#finalize_email_sign_up!`) — two
   moments, not one transaction.
5. **No single durable state guarantees that a stopped registration yields no authority.** Concrete
   candidate gap: the App/Com telephone sign-up registers its passkey before the birthdate step;
   `ClientPasskeyStatus` has no pending state (the row is `ACTIVE`), and discoverable Passkey sign-in
   (`PasskeySignInFlow#passkey_eligible_for_sign_in?`) checks the passkey status, discard and
   `actor.active?`, not the Client's sign-up status. An abandoned telephone sign-up may therefore
   allow a Passkey sign-in that skips birthdate eligibility and Finalization. **Unverified — needs a
   Red test first** (X-26). Email sign-in with a `VERIFIED_WITH_SIGN_UP` contact of an unverified
   Client is the same question, not yet traced.

**Sign entry Sentry (owner, H15, 2026-10-22).** Recorded in `adr/sign-entry-sentry.md` (Accepted,
Owner decisions only; not implemented). Investigation and adversarial review:
`research/2026-10-22-sign-entry-sentry-investigation.md`; proposals:
`plans/backlog/2026-10-22-sign-entry-sentry-implementation.md`.

- **D-84** **Sentry, the entry control for new Sign In and Sign Up.** Name Sentry (not Breaker,
  Circuit Breaker, Gate, Daemon or Interlock; unrelated to the `sentry-ruby` SDK, whose `::Sentry`
  constant must not be shadowed). States `ALLOWED`/`BLOCKED` only. Flipper is the only source; no
  per-user Sentry record. Flags (all `:availability`, registered explicitly per surface × flow, never
  derived from request input): `sign_in_available_{app,com,org}`, `sign_up_available_{app,com,org}`;
  only explicit `true` allows. Separate from Admission, Guardrail, Checkpoint and the future Waiting
  Room; passing it is not authentication, authorization, session issuance or Admission validity. A
  direct GET, POST, callback or resume must not get past `BLOCKED`. Existing sessions, Refresh, Sign
  Out, Step-Up and OIDC requests completing without new authentication are outside; `prompt=none`
  keeps its protocol contract. A blocked Sign In after a durable Sign Up never undoes the Identity
  (Sign In First). `BLOCKED` does not by itself halt a flow or delete data; it is a surface
  availability condition, not a lifecycle state. No claim of atomic stop across processes.
  `sign_up_suspended_*` is neither deleted nor reinterpreted; the six flags are written `true` and
  verified before Sentry is enforced in production.
- **D-85** **Sentry GET on the Auth host.** `GET /sign/in/sentry` redirects to `/sign/in` and
  `GET /sign/up/sentry` to `/sign/up`, on the same Auth host of each surface; the target is fixed
  by the server. Consequence: the OP's ceremony-start and Switch redirects target the Sentry paths,
  and the Sentry forwards the Admission reference unchanged without consuming it; redemption stays
  in `AuthCeremonyAdmission`.
- **D-86** **Request context by the existing concerns.** `ri` and overlay keys such as `lx` come from
  `PreferenceGlobal#default_url_options` (included by every Auth surface `ApplicationController`;
  only values present and valid in the request); `pt` from `AuthenticationRedirects#signed_pt_param`
  (verified signed targets only). The Admission reference is the only parameter the Sentry passes
  explicitly. *(Note 2026-10-22: this `pt` is Auth's own signed path-target lane
  (`AuthenticationRedirects`), not the RP target. D-151 abolishes only the RP `pt`; the RP target
  (`target_link_uri`) never reaches Auth or the Sentry, so D-86 is unaffected.)*

**Reconciliation of Sentry with this cycle's decisions (static reading, not executed).** The
investigation read the current code; these decisions change where Sentry attaches:

1. **Five redirect sites, on the OP.** Today the sites that send a browser to the Auth entry with an
   Admission reference are `start_authorization_ceremony!` in
   `Base::{App,Com,Org}::Oauth::AuthorizationsController` (3) and `authorization_switch_url` in
   `Base::{App,Com}::…` (2; ORG has no Switch). After D-59 the ceremony start moves to
   `Visa::{App,Com,Org}`, and after D-38 Switch moves to OP-host `/oidc/switch` (APP/COM). Sentry
   changes the target of these five, in whichever controllers own them when it is implemented. The
   return from the Sign-in path binding confirmation (D-61, on Visa) continues a ceremony that
   already passed the Sentry and is not a sixth site; it is covered by the check at redemption.
2. **Flag selection uses D-72 effective intent.** The investigation found that `authentication`
   leaves Sign In vs Sign Up undecided at the OP. D-72 settles it: effective intent = Switch
   `entry_intent`, else `prompt=create` → sign-up, else sign-in, computed from server state. Sentry
   reads `sign_up_available_*` for sign-up and `sign_in_available_*` otherwise, at the OP redirect
   and in Auth, from that same value. Under D-72 the Auth Sign In page's local link to `/sign/up`
   (`registration_link`) cannot enter a sign-up page and is not a Sentry site; Sign Up is reached
   only through `prompt=create` or Switch.
3. **Social bypass.** Today an APP social "login" callback for an unknown identity creates a
   `ClientSignUpFlow` with no sign-up suspension check (investigation §3). D-71 removes the dead
   callback path and D-72 forbids the callback from creating a Flow; once WU-05 lands, the sign-up
   entry is the only creation point and the Sentry check there covers social sign-up. Until then
   the gap is current behavior.
4. **Fewer root-login commit points.** D-60 removes the Local Sign-in Flow receivers; the Sentry
   backstop at the OP root-login commit (proposal P4.6) then covers the OIDC result receipt, session
   limit and selector paths only.
5. **Sign-in path only.** D-44 separates the Re-verification path; Sentry applies to the Sign-in
   path purposes (`authentication_handoff`, and `invitation_handoff` if confirmed to belong there)
   and never to `TICKET_CEREMONY_PURPOSES`.
6. **Refusal class and deadline.** A Sentry refusal is not a definitive refusal of the owner's own
   attempt (D-73) and does not end the attempt; the attempt still ends at the D-45 curfew. Which of
   the D-73 classes it belongs to (retryable versus dependency failure for a flag-store error) is
   X-35.

**Login implementation audit (owner, H16, 2026-10-22).** A separate subject from Sentry.

- **D-87** (owner, H16, 2026-10-22) **Scope of the login implementation audit.** Taken up in this
  cycle as topics: Security Mode (T22), Email OTP retained result (T23), ORG normal sign-in halt
  audit (T24), Sign-in failure convergence (T25). **Not taken up in this cycle:** the audit's P2
  "end-to-end acceptance across all APP/COM/ORG paths with independent DB connections"
  (`docs/checklists/authentication-flow-integrity.md`; X-15/X-21 stay as they are) and P2 "JWT
  configuration fixed at boot vs `ENV` reads in `AuthenticationJwtConfiguration`" (it uses
  one-argument `ENV.fetch`; no change). Taking a topic up records it; it does not decide the
  contract or authorize implementation.

**Owner decisions on X-36 … X-39 (2026-10-22).**

- **D-88 (X-36)** **Security Mode: implement the migration in this cycle** — `mfa_level_id` →
  `security_mode_id`, reference values `1/5/9` → `3/7`, the `0` default retired (A3, A5 fail
  closed), ORG `7`, `mfa_level_enabled` meaning retired, the `docs/mermaid/` axis updated, and the
  effective sign-in policy per C1 (APP/COM `ADVANCED` ordinary sign-in requires a passkey). Not
  started until the destructive data migration is explicitly approved with a recovery plan (the
  value mapping is D-92; see X-36 for which ADR Open decisions do and do not block it).
- **D-89 (X-37)** **Email OTP `already_verified`: Red tests first.** (1) a second `update` in the same
  admitted ceremony with a different code inside the result window; (2) the same submission from
  another admitted ceremony for the same account (ADR A expects refusal); (3) two concurrent
  `update`s produce at most one evidence record and no second session (ADR B, R23-INV-4). APP and
  COM both. The reconciliation is decided after the results are recorded; no production change
  before that.
- **D-90 (X-38)** **ORG halt audit: fixed in this cycle by a direct Chronicle write.** An attributable
  halt writes exactly one `OperatorChronicle` `SIGN_FLOW_HALTED` record (safe surface, flow
  correlation, reason, request/time facts; no secrets); replay writes none; a Chronicle write
  failure is not swallowed and the request does not report success; 409, HALT, safe GET/HEAD
  refusal and no new token/challenge are preserved. No outbox. The removed durable-audit
  assertion is restored. Closes `plans/backlog/org-normal-sign-in-durable-halt-audit.md` when done.
- **D-91 (X-39)** **Sign-in failure convergence: build the table now, implement after X-20.** One table
  per surface × method (email OTP, telephone, passkey, TOTP, secret, Google, Apple, Entra) ×
  outcome (credential failure, actor not allowed, issuance failure, MFA pending, session-limit
  pending, OIDC handoff failure) → D-73 class and HTTP result, from static reading; no code change.
- **D-92 (X-40)** **Security Mode value mapping.** APP and COM: every existing value (`0`, `WEAK=1`,
  `MEDIUM=5`, `FULL=9`) becomes `NORMAL=3`; `ADVANCED` is entered only by the owner's own action
  (B1). Consequence accepted: an account at `MEDIUM`/`FULL` today loses its MFA requirement until
  the owner moves to `ADVANCED`. ORG: every Operator becomes `ADVANCED=7` (B2); an Operator with
  fewer than two active passkeys keeps signing in with the passkeys it has and is required to
  register a second one; deleting a passkey from two to one is refused (consolidation ADR). How the
  "required to register" is presented and enforced is an implementation detail of D-88. Data at
  stake is development/staging data (never deployed, X-2); the destructive-migration approval gate
  of D-88 still applies.

**Owner decisions on X-29 … X-35, Sign entry Sentry (2026-10-22).**

- **D-93 (X-29)** **Enforcement at every point, through one resolver.** (1) the OP's ceremony-start
  and Switch redirects, by D-72 effective intent; (2) Auth Admission redemption (`POST /sign/in`,
  `POST /sign/up`, `POST /ceremony_bindings`) and the admitted-entry `show`; (3) every Sign-in path
  evidence-recording and registration POST (Email OTP, Passkey options/verification, Secret,
  challenge, `sign/up/check/**`, `sign/up/guard/**`, social start, ORG Entra start, invitations);
  (4) provider callbacks (D-95); (5) the OP root-login commit, `log_in(establishment: :root_login)`
  only, returning a refusal status before the commit, never a success and never a raise inside a
  caller's transaction. `:rp_session`, Refresh, Sign Out, SSO code issuance, `prompt=none` and the
  Re-verification path (`TICKET_CEREMONY_PURPOSES`) are untouched. Not merged into
  `AuthCeremonyAdmission`, `SignUpSuspensionGuard`, Guardrail or Checkpoint; each point only calls
  the resolver. The Sign Up → Sign In First handoff is not checked inside `with_cycle_lock`; point
  (5) refuses its session and the Identity stays.
- **D-94 (X-30)** **Names.** `SignEntrySentryResolver` (`app/resolvers/sign_entry_sentry_resolver.rb`)
  derives the state from Flipper through `FeatureFlags` and holds the explicit six-entry
  (surface, flow) table, raising `ArgumentError` for any other pair; it returns
  `SignEntrySentryStateValue` (`app/values/sign_entry_sentry_state_value.rb`; `ALLOWED`/`BLOCKED`,
  surface, flow). Controllers `Auth::{App,Com,Org}::Sign::In::SentriesController` and
  `Auth::{App,Com,Org}::Sign::Up::SentriesController`; routes `resource :sentry, only: :show` under
  `namespace :in` / `:up` (`/sign/in/sentry`, `/sign/up/sentry`, helpers such as
  `auth_app_sign_in_sentry_path`). `ALLOWED` answers 303. No constant named `Sentry` anywhere.
- **D-95 (X-31)** **Provider callbacks are refused under `BLOCKED`** (Google, Apple, Entra): no new
  evidence, no registration, no Flow; unlike the provider switch, no draining.
- **D-96 (X-32)** **ORG.** Emergency Access is outside `sign_in_available_org` (break-glass).
  `sign_up_available_org` gates invitation acceptance (`sign/up/invitations`) and the recruit page
  (`Auth::Org::Sign::UpsController`).
- **D-97 (X-33)** **Replace in one change** (supersedes H15's "do not delete the old flags
  abruptly", because the project has never been deployed, X-2). Before the change: register the six
  rows, write them `true` in every environment and record `feature_flags:status` in `evidence/`.
  The same change then removes `sign_up_suspended_*`, `SignUpSuspension`, `SignUpSuspensionGuard`
  and their tests, and moves every current guard site to the resolver; no period with both flags
  read. Rollback is a code rollback; the old Flipper records stay until an operator removes them.
- **D-98 (X-34)** **No OP pre-check.** A blocked OIDC-initiated attempt stops at the Auth Sentry 503;
  the OP does not return `temporarily_unavailable`. The RP's pending state ends at its D-76 bounds.
  (The OP redirect of D-93 (1) only chooses the Sentry path by effective intent; it does not refuse.)
- **D-99 (X-35)** **Refusal classes.** `BLOCKED` is *retryable* in D-73 terms: it does not end the
  attempt, which still ends at the D-45 curfew. A flag-store error is a *dependency failure*: no
  authority issued, nothing consumed needlessly. With Flipper `preload = true` a store failure
  surfaces as a 500 from the Flipper middleware before any Sentry code runs; this is accepted and
  needs no Sentry-specific handling (the request is refused either way).

**Owner decisions on the Sign-in path protocol (2026-10-22).**

- **D-100 (X-1, X-1′)** **Design D is adopted in full** (`five.md` §6 Design D, §8): every user action
  is a CSRF-protected POST (RP 続行, credential submission, Cancel, Switch); every system hop after it
  is a 303 + GET continuation endpoint, including the final Base/Visa result GET that creates the
  Root Session. The deviation from RFC 9110 §9.2.1 is accepted and recorded in a new ADR with its six
  conditions: (1) `Sec-Fetch-Mode: navigate` and `Sec-Fetch-Dest: document` required, HEAD refused
  (D-50); (2) the host-only cookie binding is verified before the one-time record is touched;
  (3) atomic consumption (existing CAS); (4) a repeat from the same bound browser returns the same
  next redirect (D-49, D-101), anything else is refused without consuming; (5) `Cache-Control:
  no-store`, `Referrer-Policy: no-referrer`; (6) a clean URL at the end. The Auth → Base → Auth
  binding confirmation stays and becomes automatic. It is a UMAXICA protocol borrowing named
  properties of RFC 6749/9126/9700, not a conformance claim. Replaces the Continue pages listed in
  `five.md` §10; amends the 2026-09-21 "GET never consumes" and 2026-09-20 "result POST-only" ADR
  text, AUTH-1/AUTH-2 and `generic/authentication-boundaries.mdc` (§4). The Sentry GET (D-85) is one
  more redirect hop on this path. Unblocks WU-12 and WU-13 (Cancel/Switch transport, T3).
- **D-101 (X-25)** **The 10 seconds count from issuance only.** Redemption and every same-browser
  repeat are bounded by one absolute limit, issuance + 10 s (D-46); `redeemed_at` opens no new
  window. A repeat whose stored next-hop reference is already consumed or expired is refused, never
  re-minted (R23-INV-3).
- **D-102 (X-16)** **F1 is not investigated.** Under D-100 no cross-origin relay POST remains, so
  the null-Origin 422 class disappears; the FIXME in `oidc_authorization_result_post.rb` is resolved
  by removing the POST, not by relaxing the Origin check.
- **D-103 (X-18)** **The RP `GET /sign` page is kept for every entry**, including an explicit
  Sign in on an RP page; the CSRF-protected `POST /sign` remains the user's intent action and is one
  of T1's three steps. No other page is added.

**Owner decisions on post-containment and Finalization (2026-10-22).**

- **D-104 (X-20)** *(Erratum 2026-10-22, H17 #3: SSO recovery holds only when the browser received the
  auth cookies; a response lost before them is X-44.)* **No reissue; recovery through SSO.** D-49's result-hop rule applies to every
  Sign-in path journey: a repeat of a finalized result (lost response, back, reload, second tab)
  always errors and never reissues (D-2); the person restarts from the RP 続行 and the existing Root
  Session yields a fresh code through the standard SSO branch of `/oauth/authorize`. Sign Up → Sign
  In continuity follows the same rule after the durable registration. Concurrent tabs: the later
  attempt's Admission replaces nothing it does not own (R23-INV-2); each tab's attempt succeeds or
  errors on its own bindings, and a second Root Session is never created for a browser that already
  has one. TR G2 and G5 tests are rewritten to this contract; TR G3's Sign-in path multi-tab cases
  are judged by it (its Step-Up cases stay with the Re-verification path, D-44).
- **D-105 (X-24)** **A Finalization is valid only if it completes before the deadline; after it, it
  is refused.** Supersedes D-83. The completing commit compares the D-45 deadline with the OP
  database clock under the Binding/Flow lock (D-75); at or after the deadline the Finalization fails
  closed, issues no authority and no session, and accepts no evidence. Durable principal writes
  already made by a Finalization that then misses the deadline are a partial registration handled by
  cleanup (R-3) and the read-only diagnosis (D-82, X-28), never by completing it late. Consequence
  accepted: a person who reaches Finalization seconds before the deadline may have to start again.
- **D-106 (X-26)** *(Erratum 2026-10-22, H17 #1: verified — COM creates the Visitor `ACTIVE` at
  candidate creation and `VisitorStatus` has no pre-Finalization value, so this decision holds for APP
  only; COM is X-42.)* **Run AX26-1 first; if it fails as expected, close the gap with the existing Client
  status.** Sign In refuses, on every method (OTP, Passkey, Secret, social, TOTP), a Client or
  Visitor whose status is an unfinished registration (`UNVERIFIED_WITH_SIGN_UP` and any other
  pre-Finalization status), in `login_allowed?` or the equivalent single predicate; no new durable
  fact is added. Fail closed; no weakening of other checks. The exact status list is fixed from the
  model during implementation.
- **D-107 (X-27)** **Inventory first, then fix the order.** Target is the Q9 order (OP Flow lock →
  principal subject lock → Client lock; cleanup the same), keeping `with_subject_lock` and
  `released_since_ceremony?` inside the principal transaction. The inventory of current lock
  acquisitions adds the positions of the Admission Binding, the identity graph, link/unlink and the
  existing sign-in; the final order is decided from it.

**Owner decisions on RP topology and tokens (2026-10-22).**

- **D-108 (X-2)** **Inventory, then remove the pre-R5 OP-chain path in one change per surface.** The
  inventory lists every caller, route, table and test of the OP-chain path; removal lands only with
  the standard-RP path's tests green, without a switch or flag selecting between the two (so the two
  authorities can never run for one client). Table drops are destructive migrations and need
  explicit approval with a recovery plan.
- **D-109 (X-5)** **The RP stores the return target server-side.** A protected page that sends an
  unauthenticated request to `GET /sign` first validates its own path and permitted query (D-55
  rules) and stores it in the RP's Rails session (the `store_location` convention); `POST /sign`
  moves it into the authentication transaction keyed by `state`. Nothing is carried in the URL
  (D-42). After Cancel (`access_denied`) the RP sends the person to its own top page and drops the
  stored target.
- **D-110 (X-6)** **Silent re-authorization only continues an existing RP session.** Refresh recovery
  may use `prompt=none` without a click; `login_required` leads to a new interactive authorization
  per D-80, which starts at the RP 続行. A sign-in without an existing RP session always needs the
  explicit `POST /sign` (D-103).
- **D-111 (X-9)** **The residual Access JWT bound becomes 10 minutes + 30 seconds.** The ADR text
  (`adr/first-party-sign-out-op-commit-and-backchannel-logout-for-separated-rp-stores.md`) is
  amended to `CoreBrowserCredentialContract::ACCESS_TTL` (10 min) plus 30 s; the TTL is not
  shortened. Consequence accepted: after sign-out or an OP authority stop, an already issued Access
  JWT may stay valid at an RP for up to about ten and a half minutes unless BCL closes the RP
  session first.

**Owner decisions on Passkey, i18n, E2E and cookies (2026-10-22).**

- **D-112 (X-10)** **Passkey identifier-first is implemented in this cycle** (ADR-PK), as its own
  Work Unit next to the Security Mode migration (D-88). Capacity per D-116.
- **D-113 (X-11)** **Region does not change translation content; language alone selects text.** The
  region bundles are merged into one bundle per language; duplicate keys with different text and
  keys missing in one language are refused by a test. Region-specific legal or product copy, if ever
  needed, is a separate decision.
- **D-114 (X-21)** **No browser E2E in this cycle** (consistent with D-16). The end-to-end journey in a
  real browser is recorded as unverified; Rails tests are never reported as an E2E pass.
- **D-115 (X-22)** **Every cookie becomes host-only.** `CoreCookieOptions.for` no longer sets
  `Domain` (`CoreCookieDomain` retired) for authentication, preference, withdrawal and
  enforcement-recovery cookies, and the production `Partitioned` attribute is removed. A cookie
  found to need sharing across subdomains is reported and decided individually, not kept by
  default.
- **D-116** (owner, 2026-10-22) **Passkey capacity returns to ten per Identity** on APP, COM and ORG;
  the eleventh registration is refused (2026-10-19 decision restored). Supersedes ADR-PK's four-slot
  capacity (its §"maximum of four slots" and the matching lines in the identity-resolution ADR and
  `adr/README.md`); ADR-PK's identifier-first selection, the `ADVANCED` two-active-Passkey minimum,
  owner serialization and the "slot number never selects the only usable credential" rule are
  unchanged. Enforcement mechanism and concurrent last-slot registration follow the 2026-10-19 ADR
  (owner-locked registration); the existing enforcement gap is
  `plans/backlog/2026-10-19-passkey-limit-enforcement-gap.md`.

**Owner decisions on Back-Channel Logout and the stop primitive (2026-10-22).**

- **D-117 (X-3, promise)** **Every participating RP is notified: the durable BCL outbox is kept.**
  Supersedes D-28 (no durable outbox, accepted loss) and the loss acceptance in D-30. The stop
  transaction writes one outbox row per participant together with the revocation (D-26 (2)); after
  COMMIT, dispatch is attempted, and a sweep re-dispatches rows left behind by a restart, a queue
  overflow or a failed enqueue, until each row reaches 200 (done), 400 (permanent, observable) or the
  BX-10 retry deadline. The promise is stated as three separate facts: OP authority is durably
  stopped; every participant has a durable notification row; RP closure is acknowledged, permanently
  refused or expired, never assumed. The existing `OpLogoutCommitter` outbox write and
  `OpOutboxDispatchJob` leasing are the starting point. Which component dispatches is X-41.
- **D-118 (X-3, receiver)** **`POST /oidc/closures` keeps `ActionController::API` as its parent**
  (no `allow_browser`, forgery protection or session), adding FQDN gating and rate limiting
  explicitly; only the Logout Token signature and claims are trusted (D-32). Recorded as a scoped
  exception in an ADR, not by editing a guard allow-list. Amends D-32's "surface `BareController`".
- **D-119 (X-4)** **A new, browser-independent OP authority-stop record is the authority** for every
  stop cause (browser logout, identity stop, token revocation, revoke-all, refresh reuse, risk),
  carrying cause, scope and realm, written by the one stop primitive (BX-1) in the same transaction
  as the revocation and the D-117 outbox rows. `Op*LogoutFlow` and the legacy `*SignOutFlow` become
  evidence of the browser interaction, children of a stop record where one exists. No nullable
  column carries meaning. The matrix, lock order and table design are drafted in `two.md` (WU-16,
  WU-22 SO-3) for the owner's review.
- **D-120 (X-8)** **Self-call capacity: increase Puma workers and threads; no concurrency cap.**
  Today `config/puma.rb` runs one process with `RAILS_MAX_THREADS` (default 3) threads, so three
  concurrent RP callbacks waiting on the OP token/JWKS endpoints of the same Puma can stall it
  (CR R-04). Workers and threads are raised (values from a load estimate; the database pool sized
  to match). Risk accepted: when concurrent RP→OP waits reach the total thread count, requests stall
  until their timeouts; more workers lower the probability but cannot remove it, because a self-call
  through the public URL may land on any worker. D-19 (one Rails) and D-23 (standard RP) are kept.
- **D-121 (X-41)** **BCL is delivered through Solid Queue.** Supersedes D-28's "Solid Queue is not to
  be used for delivery" and D-30's in-process thread pool. The outbox row (D-117) is the source of
  truth; after COMMIT, `OpOutboxDispatchJob` is enqueued on Solid Queue (already the production
  ActiveJob adapter); because the queue database is separate from the OP database, enqueue is not
  atomic with the stop, so a Solid Queue recurring task sweeps and re-enqueues rows left without a
  final state. D-30's `OutboundHttp::Connection` requirements (HTTPS only, no redirects, explicit
  timeouts, connection-time SSRF protection) and D-26's response classes apply to the job.

**Owner decisions on Bootstrap, Sign-out and Gates (2026-10-22).**

- **D-122 (X-12)** **The dev-only ORG Bootstrap is rebuilt from scratch; destructive changes are
  allowed.** The current Bootstrap code, routes, seeds and data may be removed and replaced rather
  than adapted. D-13's policy and R-14's requirements stay as the review criteria: a deployment
  discriminator independent of `Rails.env`, verified again at finalization, refusing when missing or
  unknown; a Bootstrap authentication context preserved through root, grant, refresh and access
  claims, never collapsing into Normal (today `AuthenticationContextValue.from_claim` maps a blank
  claim to Normal); no widening of existing Operator roles. Entry and discriminator are redesigned in
  `two.md` for the owner's review. Any destructive database migration still lists its risk and
  recovery plan before it runs.
- **D-123 (X-14)** *(Correction 2026-10-22, two.md 5.8: principals live in another database, so "`ON
  DELETE RESTRICT` to principals" is a public-id reference protected by the purge order, not an FK;
  token references in the same OP database keep `ON DELETE RESTRICT`.)* *(Clarification 2026-10-22, H17 #5: the "no valid OP session → no authoritative stop"
  rule is for browser sign-out only; other stop causes have their own authority, see `three.md` G-20.)*
  **Sign-out SO-1/SO-2/SO-7, strict.** SO-1: without a valid OP session there is no
  authoritative sign-out — no stop record, no revocation, no BCL, no Flow; the response says the
  browser is not signed in, and an RP clears only itself (D-33). An `id_token_hint`, a `sid` or a
  `principal_id` is never authority on its own. A re-run after commit, or a commit whose outcome is
  unknown, is answered from the durable stop record (D-119) and never revokes or notifies twice; when
  the record cannot be read, the request fails closed and reports no success. SO-2: every stop record
  carries its principal and cause NOT NULL; a stop whose principal cannot be established is refused,
  not recorded with a missing principal. SO-7: history is kept on the stop record side; references
  to tokens and principals use `ON DELETE RESTRICT` (no `CASCADE` erasing history), and physical
  deletion happens only through the retention purge in a defined order. Table design with X-4 in
  `two.md`.
- **D-124 (X-15)** **The cycle's Gates are `three.md` G-1 … G-16.** Gates for the decisions recorded
  on 2026-10-22 (D-84 … D-123: Sentry, Security Mode, Design D, durable BCL, Passkey capacity,
  host-only cookies, Bootstrap, Sign-out) are added to `three.md` before their units are accepted.
- **D-125 (X-13 ①②③)** **E1 binding column.** ① Immutability of `*SignUpFlow.auth_admission_binding_id`
  is enforced by Rails `attr_readonly` only; no trigger and no column privilege. Accepted residual
  risk: `update_all` or raw SQL can still change it, so a static guard should forbid such writes to
  that column. ② Existing Flows without a binding (development/staging data; never deployed) are
  deleted, not backfilled by inference, and the column then becomes NOT NULL; the deletion lists the
  affected row counts and the recovery path before it runs. ③ The FK is `ON DELETE RESTRICT`; the
  Purger deletes Flows before their Binding.
- **D-126 (X-28)** *(Part (1) superseded by D-135: no user-initiated reset.)* **Partial registrations are cleared by the person's own restart and by automatic
  deletion after expiry; there is no operator write procedure.** (1) Reset: when someone starts a new
  sign-up with the same email or telephone and passes that contact's OTP, the old unfinished
  principal data (pending Client, contact, Passkey) is deleted and a new registration begins (D-77:
  nothing is reused). (2) Automatic: a Flow past its D-45 deadline without a completed Finalization
  is cleaned up by the sign-up cleanup axis (R-3), deleting its unfinished principal data. A
  Finalized Identity is never touched by either path (Sign In First). Diagnosis stays read-only
  (D-82). Extends D-82, which deferred automatic deletion.
- **D-127 (X-13 ④)** *(Erratum 2026-10-22, H17 #7: verified — `entry_intent` is a nullable column of
  the Admission Binding, whose table also holds Re-verification rows; the question was asked as if it
  were a Flow column. Application is X-43.)* **`entry_intent` is NOT NULL.** It is written at creation from the D-72 effective
  intent; an empty value carries no meaning. Existing rows without it are deleted together with ②.

**Owner decisions on the `seven.md` findings (2026-10-22).**

- **D-128 (X-42)** **COM gets the same registration states as APP.** `VisitorStatus` gains the
  pre-Finalization statuses mirroring `ClientStatus` (`UNVERIFIED_WITH_SIGN_UP`,
  `VERIFIED_WITH_SIGN_UP`); COM email and telephone candidate creation creates the Visitor in the
  unfinished status and Finalization promotes it to `ACTIVE`. D-106 then applies to APP and COM with
  one predicate. Existing COM data is migrated (destructive-migration rules apply).
- **D-129 (X-43)** **`entry_intent` on the Admission Binding is NOT NULL with an explicit value for
  every row.** Sign-in path rows carry `sign_in` or `sign_up` (D-72 effective intent); Re-verification
  rows carry an explicit "not applicable" value; a CHECK ties the allowed values to `purpose`. NULL
  carries no meaning. Replaces D-127's Flow wording.
- **D-130 (X-44)** **A response lost before the auth cookies arrive is a sign-in failure.** The person
  signs in again from the start; nothing is reissued (D-2). The orphan Root Session stays until it
  expires; if it makes the session limit apply, the existing session-limit remediation lets the
  person remove it. D-104's SSO recovery covers only a response lost after the cookies arrived.
- **D-131 (X-48)** **The principal's registered status is the decisive commit of a Finalization.**
  Under the OP Flow/Binding lock, the deadline is checked on the OP database clock (D-75); then the
  principal database commits the Identity with its registered status. Before that commit the
  registration is unfinished: Sign In refuses it (D-106/D-128) and reset or cleanup may delete it
  (D-126). After it the registration is complete: Sign In admits it and nothing deletes it as
  registration cleanup. A later failure of the graph or of the OP Flow completion does not undo it;
  the graph is completed idempotently at the next sign-in, and the OP Flow is completed or retired
  by the next attempt or cleanup. D-105's "completes before the deadline" means this commit starts
  after a successful deadline check under the lock; the residual window between that check and the
  principal commit is accepted and bounded by the lock wait.

- **D-132 (X-47)** **An ORG Operator with one passkey is restricted until the second is registered.**
  Ordinary sign-in works; until a second active passkey exists, every action except registering a
  passkey and signing out is refused. An Operator with zero passkeys cannot complete ordinary
  sign-in (Entra + passkey); getting back in is the Pending recovery decision, not a bypass.
  Emergency Access keeps its existing restricted mode. Existing Re-verification readers of
  `mfa_level_id` change only their reference to `security_mode_id`, not their behavior.
- **D-133** (owner, 2026-10-22, H17) **Large Work Units are split** into units an implementer can take
  one at a time: WU-01, WU-02, WU-05 and WU-18 first. Each sub-unit states its changed files,
  prerequisite units, database commit points, data left behind on failure, tests to run and stop
  conditions; `three.md` cases are re-mapped to the sub-units.

- **D-134 (X-45)** **ORG halt exactly-once by a partial unique index on `operator_chronicles`.** The
  halt row's `context` carries the ORG normal sign-in transaction public id and the halt generation;
  a unique index over those two values restricted to `event_id = SIGN_FLOW_HALTED`, plus a CHECK that
  both keys are present for that event, makes a second insert fail; the application treats that
  failure as "already recorded". No new table or column; other events unaffected. The migration runs
  under the chronicle migration role (`adr/chronicle-tamper-resistance.md`).
- **D-135 (X-46)** **No user-initiated reset.** Supersedes D-126 (1). A partial registration is
  removed only by the automatic cleanup after its Flow's deadline (D-126 (2)). Consequence accepted:
  someone who abandons a sign-up and starts again with the same email or telephone is refused until
  the old attempt's deadline has passed and cleanup has run (today `cleanup_pending_signup!` is
  empty and the second attempt is refused — static reading).

**Owner decisions of the H18 handoff (2026-10-22).** H18 states which parts are approved; everything
else in it, and every implementation detail added here, is a proposal (class P) recorded in `two.md`
Part 6 for the owner's review.

- **D-136 (WU-11)** **The unknown-`kid` refetch limit is a distributed control in the rate-limit
  Valkey.** One control per issuer and environment, in a feature-specific namespace of the existing
  rate-limit Valkey (the cache / rate-limit separation stays); the unknown `kid` is never part of a
  key; the issuer is normalized to a fixed-length digest; the right to refetch is taken with an
  atomic command (`SET NX EX` or equivalent) shared by every Puma worker, so one issuer gets at most
  one refetch per window. A JWT verifiable with a key already held is never refused because Valkey is
  unavailable; a token whose key cannot be verified is never accepted; a Valkey failure never turns
  the limit off; "JWKS fetch failed" and "fetched JWKS lacks the `kid`" are distinguished. The
  verifier returns a typed result with at least *key found*, *token invalid* and *key unavailable*;
  invalid maps to the caller's 400/401 contract, unavailable to 503. While the limit refuses a
  refetch, the outcome of the latest fetch decides between invalid and unavailable; an uncertain
  state is not called invalid. **Supersedes** `two.md` 5.5's "one refetch per issuer per 30 s per
  process". **Not decided:** the window length (30 s is provisional), the key layout, the failure
  details (proposal in `two.md` 6.3).
- **D-137 (WU-21)** **The RP return target is carried as an RP-signed `pt`.** The RP validates the
  target (its own permitted relative path and permitted query keys only), signs it and issues it as
  `pt`; `pt` travels as a GET parameter up to the start of authentication and as a hidden field where
  a POST is needed; it is tied to the authentication transaction and its OIDC `state`; after the
  callback and the RP session succeed, the RP verifies `pt` and restores the target, which can be
  used once. Cancel, expiry, a bad signature or an ownership mismatch never lead to the target. Tabs
  keep independent targets. The target itself is **not** held in a single shared Rails-session slot
  and is **not** stored in a new database table; storing the OIDC `state`, `nonce` and their
  single-use consumption is a separate responsibility and allowed. A signature alone does not make
  `pt` single-use: single use comes from the transaction's existing one-time consumption. A signed
  `pt` never authorizes an external redirect; internal/external lanes and the Jump/Away rules stay.
  **Partially supersedes** D-42 (the "RP target will not use `pt`" clause), D-109 (Rails-session
  `store_location` slot and "nothing in the URL"), and D-55's mechanism sentence; D-55's ownership
  rules and D-109's Cancel rule stay. **Not decided:** the token format, reuse of the existing signed
  target code, per-RP query allow lists, the final lifetime (proposal in `two.md` 6.4).
- **D-138 (WU-24)** **WU-24 is reissued.** The old WU-24 / WU-38 / WU-05 dependency cycle is removed by
  redefining WU-24; D-72, D-74, D-75, D-125, D-129, D-131 and D-135 are unchanged. **Not decided:** the
  new sub-units, the data-migration order and the pre-deletion cleanup (proposal in `two.md` 6.1).
  No destructive migration is authorized by this decision.
- **D-139 (WU-35)** **Lock work is investigation first, then the smallest fix.** The lock order of the
  whole authentication base is not changed in one sweep. Sign-up, Sign-in, Finalization and Cleanup
  are inventoried; only paths that can actually form a wait cycle, or that lack a needed ordering, are
  fixed; Sign-up Finalization vs Sign-up Artifact Cleanup is investigated first. Refines D-107: the Q9
  order and `two.md` 5.2's two-family proposal are **not** an approved final order. **Not decided:**
  the final order and the fix targets (report in `two.md` 6.2).

**Decision ledger (H18, 2026-10-22).** Authority: O = owner decision, A = Accepted ADR,
P = proposal awaiting the owner, X = open. "Next" is who acts next.

| ID | WU | Content | Authority | State | Supersedes | Next |
|---|---|---|---|---|---|---|
| D-136 | WU-11 | Distributed unknown-`kid` refetch limit in rate-limit Valkey; typed result | O | Decided (principles) | 5.5 per-process limit | — |
| D-144 | WU-11 | 6.3 details approved + header pre-check before refetch; key pre-publication ≥ 1 h 5 min | O | Decided | P-136a | Implementer |
| P-136a | WU-11 | → D-144 | — | Adopted | — | — |
| D-137 | WU-21 | RP-signed `pt`; once; tabs independent; no single session slot; no new table — **superseded by D-151** except: once, tabs independent, no single slot, no new table | O | Partly superseded | D-42 (part), D-109 (part), D-55 (mechanism) | Owner is investigating; details stay open (6.4) |
| P-137a | WU-21 | AEAD-encrypted token (`MessageEncryptor`) with a new purpose, session-nonce bound; kept in the state-keyed pending OIDC entry; once = OP authorization-code single use | P | Proposed | — | Owner review |
| D-138 | WU-24 | Reissue WU-24 without the cycle | O | Decided (direction) | old WU-24 order, 5.3 step 3 | — |
| D-140 | WU-24 | Split into WU-24a … WU-24h; 24f/g/h approved one by one with counts and backup | O | Decided | — | Implementer (24a first); owner at A24-5a/b/c |
| D-141 | WU-40 | Turnstile on the APP/COM recovery OTP send | O | Decided | — | — |
| D-158 | WU-02, WU-36, WU-16/22 | P-140, P-141, P-142 adopted | O | Decided | see rows | Implementer (WU-16/22 still design first) |
| D-173 | WU-16 | Cause mapping for seven existing root-revocation callers; only the nine 5.8 v2 causes; all inside the static guard | O | Decided | — | Implementer (WU-16) |
| D-172 | WU-16, WU-22 | 5.8 v2 accepted; S-1 risk = all roots with epoch; S-2 retention as logout records; S-3 separate logout causes | O | Decided | 5.8 v1 | Implementer (after A44-1/A44-2) |
| D-171 | WU-20, WU-39 | Discoverable kept; non-identifying authenticator label; ORG discoverable; ten per Identity; passkey overview page | O | Decided | ADR-PK ORG compatibility paragraph and four-slot capacity | Implementer (WU-20) |
| D-168 … D-170 | all; WU-29; WU-28 | Destructive changes authorized (data may be lost); Sentry copy and logging; Bootstrap to backlog | O | Decided | per-unit destructive approvals; D-UX/D-OBS open; WU-28 in scope | Implementer |
| D-163 … D-167 | WU-16, WU-22, WU-17, WU-44 | Re-check under the principal lock; scope-dependent epoch; authoritative epoch, `==`; credential-change revocation on the principal lock; lock inventory first | O | Decided | `two.md` 5.8 "principal is not locked" | Implementer for D-163/D-165 (after R4-1); owner for 6.14 open items |
| D-162 | WU-43 (WU-21 merged) | JWS path exposure accepted (backlog); A21 retired into A43; RP `pt` helper renamed, Auth `pt` untouched | O | Decided | A21-1 … A21-8, T14 `pt` wording | Implementer |
| D-161 | WU-02 | One realm per commit (V4–V10); Jump unchanged and accepted broken in development; provider callback URLs fixed | O | Decided | WU-02c … 02h split, P-140 scope | Implementer |
| D-160 | WU-06, WU-43, WU-13 | Final 30-minute model: two deadlines, two clocks; post-curfew exit to the RP; interruption text | O | Decided | REQ-CURFEW 2 (RP part) and 6, D-45 (RP clause), D-76, `two.md` 5.6 #4 | Implementer |
| D-159 | all | DB reset by the owner: no data migration, backfill, settlement, row-count approval or backup work | O | Decided | data steps of WU-24, WU-17, WU-18f, WU-30, WU-34, D-125 ②, D-157 backfill | Owner: performs the reset |
| D-157 | WU-24d | Backfill (no deletion); Re-verification value `not_applicable` | O | Decided | D-127 deletion wording | Implementer |
| D-156 | WU-40 | Visible mode, send branch only | O | Decided | — | Implementer |
| D-139 | WU-35 | Investigate, fix only proven or under-ordered paths | O | Decided (policy) | refines D-107 | Owner: fixes F-1 … F-3 (6.2) |
| P-139a | WU-35 | → D-143 (F-1, F-2) and D-142 (timeouts) | — | Adopted | 5.2 proposal (not adopted) | — |
| P-140 | WU-02 | → D-158 | — | Adopted | Part 4 WU-02c/d/e split | — |
| P-141 | WU-36 | → D-158 | — | Adopted | A36-1 deletion clause | — |
| P-142 | WU-16/22 | → D-158 | — | Adopted | 5.8 column | — |
| D-142 | WU-41 | Make `lock_timeout` / `statement_timeout` effective (`variables:`); fix what breaks | O | Decided (was X-49) | — | Implementer |
| D-143 | WU-24e | F-1 and F-2 fixed as proposed | O | Decided (was P-139a) | — | Implementer |
| D-155 | WU-43 | One pending entry per browser and RP; last start wins; earlier tab rejected at the RP callback by design (was X-50) | O | Decided | D-137 tab clause | Implementer |
| D-147 | WU-42 | N-1 … N-4 conform to RFC 6749 / OIDC Core / RFC 9207 / RFC 7636 (PKCE mismatch → `invalid_grant`); N-4 fails the boot | O | Decided | — | Implementer |
| D-149 | WU-43 | ES384 JWS `state`, eight required parameters, CSRF unchanged, browser binding in the RP cookie session | O | Decided | WU-21 storage (see X-52) | Owner: X-52, X-53; then implementer |
| D-152 | WU-43, WU-13 | Cancel: OP returns `access_denied` per spec; RP shared concern discards the target and lands on `GET /sign/interruption` | O | Decided | WU-13 RP part | Implementer |
| D-154 | WU-43 | Pending entry stays in the RP cookie session; Valkey storage not adopted; replay/size/`reset_session` limits accepted | O | Decided | — | Implementer |
| D-153 | WU-43 | `GET /sign/interruption` on every RP: one generic page for expected abnormal endings; reason in server logs only (was X-54) | O | Decided | RP root proposal | Implementer |
| D-151 | WU-43 (WU-21 merged) | `pt` abolished; `target_link_uri` path only on `GET`/`POST /sign` and as a `state` claim | O | Decided (was X-52, X-52a) | D-137, D-145 §7 (part) | Implementer |
| D-150 | WU-43 | `state` 30 min, no grace; effective window under 30 min (was X-53) | O | Decided | D-149 31-min candidate | Implementer |
| D-148 | WU-42 | N-5: per-realm `prompt_values_supported`; unsupported or combined `prompt` → direct 400 `invalid_request` (was X-51) | O | Decided | — | Implementer |
| D-146 | WU-42 | U-1 accepted; judged in the Jump integration test | O | Decided | — | Jump integration (A42-6) |
| D-145 | WU-42 | `redirect_uri` per RFC/OIDC: exact match, code binding, no error to an invalid URI, `state` for the RP target | O | Decided | — | Implementer (WU-42); owner for the deviations in 6.11 |
| D-84 … D-135 | various | Unchanged by H18 except as listed | O | Decided | — | — |


**Owner decisions of H19 (2026-10-22).**

- **D-140 (WU-24)** **WU-24 is split into WU-24a … WU-24h** as defined in `two.md` 6.1. Each of the
  destructive sub-units WU-24f, WU-24g and WU-24h still needs its own approval after its counts and
  backup are shown (A24-5a/b/c). The `entry_intent` backfill rule and the `not_applicable` name stay
  proposals inside WU-24d.
- **D-141 (WU-40)** **Account recovery OTP sending gets Turnstile.** Verified in this session: the
  APP and COM recovery entry (`Base::{App,Com}::Identity::Recovery::SessionsController#create` →
  `EnforcementRecoveryCeremonyFlow#start_recovery_otp`) sends an email OTP through
  `EmailReentryOtpIssuer` with no Turnstile anywhere in the controller or concern; its only
  throttles are 5 requests per minute per IP (shared by the send and verify branches) and the
  per-address cooldown. Sign-in and sign-up sends verify Turnstile before sending. ORG has no recovery
  entry. Mode and whether the verify branch also requires it are proposals (`two.md` 6.9).

- **D-142 (X-49)** **Make the database timeouts effective.** `lock_timeout` and `statement_timeout`
  move under `variables:` in `config/database.yml` so PostgreSQL applies them; values stay as written
  (2 s / 15 s) unless the implementation shows a path that needs a different bound, which is then
  fixed or raised with a recorded reason (owner: implement, then improve what breaks). Work Unit
  WU-41.
- **D-143 (WU-35 F-1, F-2)** **Fix both as proposed.** F-1: the Sign-up paths in
  `ClientSecretPasskeyReservationIssuer` and the APP telephone passkey save take the Flow lock before
  the Client lock. F-2: the cleanup decision is the principal's unfinished status re-read under the
  principal lock, and a retry after a partial failure finishes the remaining rows. Both in WU-24e.

- **D-144 (WU-11 details)** **The JWKS refetch design of `two.md` 6.3 is approved, with an added
  pre-check.** Window 30 s per issuer and environment; lease key (10 s) and last-result key (30 s,
  with the fetched `kid` list) in the rate-limit Valkey; an unknown `kid` absent from a recent
  successful fetch is invalid without a fetch; a `kid` present in that list lets the process fetch
  once for itself; a failed or unknown recent result → unavailable (503); Valkey unavailable → a
  per-process limiter with the same window, never unlimited; keys held locally keep verifying during
  a Valkey outage. Added: before any refetch the header must pass cheap checks (`alg` ES384, `kid`
  format, the token issuer equal to the RP's configured issuer); a token failing them is invalid and
  never triggers a fetch. Operational requirement: a new signing key is published in the JWKS at
  least `CACHE_TTL` + `MAX_STALE_TTL` (1 h 5 min) before it signs anything.

- **D-145 (H20)** **`redirect_uri` follows the OAuth 2.0 / OIDC specifications.** Normative sources:
  OIDC Core 1.0 §3.1.2.1, §3.1.3; RFC 6749 §3.1.2, §4.1; RFC 9700 §2.1, §4.1, §4.11; RFC 3986
  §6.2.1 (where specifications update each other, the currently effective requirement wins;
  MUST/SHOULD/MAY kept apart from UMAXICA hardening). `redirect_uri` is the RP's OIDC callback taken
  from the client registry, never a post-login destination; the OP compares it with the URIs
  registered for the `client_id` by simple string comparison (scheme, host, port, path, query; no
  prefix, suffix, wildcard, partial host, normalization, or added query); the authorization code is
  bound to its `client_id` and `redirect_uri`, and the token endpoint requires the same value. URIs
  are validated at registration (no fragment; HTTPS for production web RPs); the native-app loopback
  port exception is not extended to web RPs. A missing, invalid, unregistered or mismatched
  `redirect_uri` is refused fail-closed and **no error is redirected to it** (RFC 6749 §3.1.2.4);
  errors after a valid client and `redirect_uri` follow the ordinary OAuth/OIDC error response.
  `state` (random, bound to the RP browser session and authentication transaction, expiring,
  verified once) keeps the RP's internal target on the RP side; the OP never decides it. **Not part
  of this decision:** abolishing or renaming `pt`/`nt`/`xt`. Consistent with D-55 and D-137 (the
  RP-signed `pt` reaches `POST /sign`, then lives in the `state`-keyed pending entry); no conflict
  found.
- **D-147 (WU-42 N-1 … N-4)** **The four deviations are brought into conformance with the
  specifications** (behavior in `two.md` 6.11, "Conforming behavior"). N-1: once `client_id` and its
  realm's `redirect_uri` are valid, every other authorization-request error is returned to that
  `redirect_uri` with `error`, optional `error_description`, `state` when the request carried one,
  and `iss` (RFC 6749 §4.1.2.1, OIDC Core §3.1.2.6, RFC 9207); errors about `client_id` or
  `redirect_uri` stay local (§4.1.2.1 MUST NOT redirect). N-2: the registered URI is kept as is and
  response parameters are appended, keeping any registered query (RFC 6749 §3.1.2). N-3:
  `invalid_grant` at the token endpoint for a `redirect_uri` or client mismatch (RFC 6749 §5.2) and
  for a `code_verifier` that does not match the stored PKCE challenge (RFC 7636 §4.6; owner-confirmed
  2026-10-22; a missing `code_verifier` stays `invalid_request`).
  N-4: registration-time validation (absolute URI, no fragment — RFC 6749 §3.1.2 MUST; TLS for web
  RPs — §3.1.2.1, RFC 9700 §2.1), with the reserved-query-key ban recorded as UMAXICA hardening.
  Requiring `state` and `nonce` stays a UMAXICA rule (the specifications make them RECOMMENDED /
  OPTIONAL for the code flow); its error is redirected like the others. Owner confirmation
  (2026-10-22): N-1 … N-4 as written in `two.md` 6.11; requiring `state`/`nonce` is a profile
  restriction the specifications permit (an OP may refuse requests its policy does not accept; only
  third-party RPs omitting them would be affected, and every RP here is first-party); N-4 fails the
  boot on any doubtful registration ("when in doubt, stop"). The ORG `prompt=create` row of the N-1
  table is decided by D-148 (direct 400).
- **D-158 (P-140 … P-142)** **Adopted as recommended.** P-140: WU-02 moves one realm per change with
  V4 (endpoints), V5 (that realm's issuer) and V6 (that realm's Auth result target) together, APP then
  COM then ORG, so no commit leaves a realm half old and half new. P-141: no legacy Domain-cookie
  deletion exception in WU-36. P-142: the authority-stop design (5.8) drops `target_root_ref` and uses
  `op_authority_stop_root_targets` / `op_authority_stop_grant_targets` with the
  `all_roots_of_principal` selector on the stop row; the "exactly one target" rules are enforced in
  the primitive and by tests.
- **D-159 (database reset)** **The owner will reset the databases; no data-migration handling is
  needed.** Every environment — development, test, staging and production — is rebuilt from
  scratch (owner, 2026-10-22: "全ての環境を all new"); no existing data survives anywhere. Schema
  changes are still Rails migrations (and stay reversible where Rails allows), but no unit plans or
  performs backfills, data classification, settlement of existing rows, row-count approvals, backups
  or recovery of existing data. New constraints are created directly in their final form (NOT NULL,
  CHECK, FK) on empty tables. Effects per unit in `two.md` 6.13. D-157's backfill rule therefore has no
  rows to act on; its value set (`sign_in`/`sign_up`/`not_applicable` tied to `purpose`) stays.
- **D-157 (WU-24d)** **`entry_intent`: backfill existing rows, value `not_applicable`.** Existing
  Admission Binding rows are backfilled, not deleted: Sign-in path rows from their parent
  authorization transaction (`prompt` containing `create` → `sign_up`, otherwise `sign_in`; while
  WU-01 has not removed them, `local_sign_up` → `sign_up`, `local_sign_in` → `sign_in`);
  Re-verification rows → `not_applicable`. Then a CHECK ties `purpose` to its allowed values and the
  column becomes NOT NULL. Non-destructive and reversible; no deletion approval needed. Replaces
  D-127's "rows without it are deleted" wording; D-129 unchanged.
- **D-156 (WU-40)** **Visible Turnstile on the recovery OTP send only.** APP and COM
  `Identity::Recovery::SessionsController#create`, send branch (`start_recovery_otp`): visible
  Turnstile verified before the address is resolved or anything is sent, as on sign-up. The verify
  branch (`pass_code`) keeps its OTP attempt budget and IP rate limit without Turnstile, so a locked-out
  person is not burdened further. Added now although the recovery flow as a whole is not finished
  (owner: worth having regardless).
- **D-155 (X-50)** **One sign-in at a time per browser and RP; the last start wins; an earlier tab
  is rejected only at the end, and that is the correct behavior.** The RP cookie session holds at
  most one pending entry. `POST /sign` replaces any existing entry. An earlier tab is invalid from
  that moment but is not told: it can continue through Auth and the OP (OTP mails, passkey, even an
  issued authorization code) and is refused only when it reaches the RP callback (its `state` does
  not match the entry, or the entry is already consumed) → `GET /sign/interruption` (D-153). The order
  of completion does not matter; only the last-started tab can complete. Starting two sign-ins at
  once is the person's own doing; no early cancellation, no RP→OP notification and no OP change are
  built for it (implementation kept simple). Nothing is issued for the rejected tab, and the OP never
  creates a second Root Session (D-104). Supersedes D-137's "tabs keep independent targets" clause
  (and with it the earlier "tabs independent" wording carried by D-151). The behavior is written into
  the docs (WU-39) and asserted by tests (A43-9, A21-4, A27-3). **Sign Up in the earlier tab
  (owner, 2026-10-22):** if tab A was a Sign Up and B a Sign In, A's Finalization still commits the new
  Identity as registered (D-131) and it is kept (D-135); only A's sign-in handoff is refused — at the
  OP (the browser already has B's Root Session, D-104) or at the RP callback. The person later signs
  in with the new account normally. Also intended behavior. The rule is per browser: separate browsers
  (e.g. Firefox and Chromium) have separate cookies and are independent; there the account's session
  limit applies (`ClientToken::MAX_SESSIONS_PER_USER` 2, `VisitorToken` 1, `OperatorToken` 1).
- **D-154 (pending entry storage)** **The RP pending entry stays in the RP's cookie session
  (D-149 confirmed).** The server-side Valkey alternative (atomic single consumption, no size limit,
  untouched by `reset_session`) was considered and not adopted. Accepted consequences, recorded as
  such: a re-sent old cookie can bring back a consumed entry — no authority results because the OP's
  authorization code is single-use and the RP redirects only after a successful exchange; the entry
  count is bounded by the cookie size (X-50); on the Base host the entry is lost at the sign-in
  `reset_session` until WU-02f. No Valkey dependency is added to the RP sign-in start.
- **D-153 (X-54)** **Expected abnormal endings of the RP sign flow land on `GET /sign/interruption`.**
  Every first-party RP gets `resource :interruption, only: :show` under its `sign` scope. It covers:
  Cancel (`access_denied`), every other OP error response except `login_required` (D-80 keeps
  starting a new interactive authorization), an invalid, expired or unknown `state` or a missing
  pending entry (foreign browser, expired tab, evicted entry), a failed code exchange, and a failed ID
  Token or `nonce` check. Unexpected internal inconsistencies stay 5xx. The callback finishes its own
  cleanup first (consume the pending entry, discard `target_link_uri`), then 303 to the page. The
  page is one generic page for every reason (no `reason` parameter, no reason shown; text per D-160 (4):
  「ログインできませんでした。再度ログインしてください。」), with links the person chooses (`/sign`, the service top); it never redirects
  on its own, needs no sign-in, branches on nothing, writes nothing, and is `no-store`. The reason is
  logged server-side only as a reason code (D-73, T19). Replaces the RP root proposal.
- **D-152 (Cancel on the RP)** **After Cancel the OP returns to the RP by the specification; the RP
  decides the landing.** The OP (Visa) ends the authorization transaction and redirects to the
  registered `redirect_uri` with `error=access_denied`, the unchanged `state` and `iss` (RFC 6749
  §4.1.2.1, OIDC Core §3.1.2.6; D-147); the OP never reads `state` claims. The RP, in the shared
  `OidcCallback` concern for every RP, verifies `state`, consumes the pending entry, discards
  `target_link_uri`, and redirects to `GET /sign/interruption` (D-153). Implemented in WU-43; WU-13 keeps only
  the OP-side route move (`/oidc/cancellation`) and an end-to-end re-check. Applies to Sign In and
  Sign Up (a Sign-up Flow ends as cancelled and its unfinished data goes to cleanup).
- **D-151 (X-52, X-52a)** **`pt` is abolished on the RP; the target is `target_link_uri`, path
  only.** Proposal (D) of `two.md` 6.12: a protected page redirects to
  `GET /sign?target_link_uri=<relative path>`; the `/sign` page keeps it as a hidden field;
  `POST /sign` receives it (OIDC Core 1.0 §4's GET/POST convention); the RP verifies it on both
  requests (OIDC Core §4 MUST: no open redirect) — a relative path on the RP's own host, **no query
  and no fragment** (the system is designed to work without a query; the protected page builds the
  value from its own path), no dot segments or double encoding, not under `/sign` or `/oidc`. An
  invalid value is ignored and the RP default page is used after sign-in (D-55 / A21-2 behavior).
  `POST /sign` mints the JWS `state` (D-149) with the claim `target_link_uri` (replacing
  `return_path`; naming from draft-bradley-oauth-jwt-encoded-state, an expired draft used as prior
  art), and the cookie pending entry keyed by `jti` is the browser binding (the draft's stateful
  `rfp`). After callback validation, code exchange and RP session establishment, the RP redirects
  once to it. **Supersedes** D-137 (signed `pt` carrier) and D-42/D-109 remnants; **partially
  supersedes** D-145 §7 (the path is readable to Jump/Visa/OP — accepted by the owner; no query is
  carried, so nothing beyond the path is exposed). D-55's ownership rules stay. WU-21 is merged into
  WU-43.
- **D-150 (X-53)** **`state` lifetime is 30 minutes, no extra grace.** `exp = iat + 30 min` (RP clock
  at minting); the RP pending entry TTL is the same 30 min; clock leeway only for a future `iat`, never
  added to `exp`. Because the RP mints `state` before the OP's curfew starts, the RP limit ends a few
  seconds earlier than the OP curfew: the effective window is under 30 minutes (owner: "30 min 未満で
  切る"). Supersedes D-149's 31-minute candidate and the 1-minute callback grace. Until WU-06 aligns
  the OP's authorization transaction (15 min) and `login_challenge` (10 min) with the curfew, the
  shorter OP bound applies; "30 minutes" is claimed only after WU-06. After an RP key rotation the
  old public key stays verifiable for ≥ 30 min + `CLOCK_SKEW_LEEWAY_SECONDS`.
- **Owner direction on X-52 (2026-10-22, not yet final):** abolish the RP `pt`; the RP's internal
  target is a relative path held as a `return_path` claim of the JWS `state`. This would partially
  supersede D-137 (carrier) and D-145 §7 (the target becomes readable to Jump/OP/Visa in the
  authorize URL and the OP's stored transaction). Open sub-item X-52a: how the target crosses
  `GET /sign` → `POST /sign` without `pt` (`two.md` 6.12, "X-52 direction").
- **D-149 (H21)** **OIDC Authorization Code Flow profile and a signed `state`.** Eight request
  parameters are required: `response_type` (`code` only; no implicit or hybrid), `client_id`,
  `redirect_uri`, `scope` (with `openid`), `state`, `nonce`, `code_challenge`,
  `code_challenge_method` (`S256` only); `prompt`/`max_age` unchanged. Spec keywords and UMAXICA
  requirements are recorded separately (`two.md` 6.12). The RP's `state` becomes an ES384 JWS signed
  with the RP's existing `oidc_client:<namespace>` key (no new key; no key material distributed to a
  new boundary; the shared-key impact is an accepted trade-off), header `typ`
  `umaxica-oidc-state+jwt`, `alg` exactly ES384 in the header and in the verifier's allow list, `none`
  and every other algorithm refused, signature verification mandatory, `kid` resolved only in the
  RP's own key set; claims at least `iss`, `aud` (state-specific), `jti` (flow id), `iat`, `exp`, `v`;
  never `sid`, `code_verifier` or session secrets. The browser binding stays in the RP cookie session
  (`jti` → pending entry with `code_verifier`, `nonce`); no PostgreSQL state; no per-`state`
  revocation (accepted risk), while PKCE, single-use codes, `nonce` and callback consumption stay.
  Rails CSRF (`header_or_legacy_token`, Fetch Metadata, `Origin`, `reset_session`) is unchanged and
  never replaced by `state`; the test-environment CSRF ADR is kept and CSRF-enabled boundary tests
  are added. `nonce` stays a separate parameter checked in the ID Token. `response_type` errors and
  PKCE error codes follow D-147; a malformed `code_challenge` is refused (N-6). `state` lifetime:
  31 min first candidate (30 min business deadline + ≤ 1 min callback transfer, clock leeway
  separate), never extending the business deadline. **Open:** X-52 (`return_path` claim), X-53
  (lifetime anchoring).
- **D-148 (X-51, WU-42 N-5)** **`prompt_values_supported` per realm and a direct 400 for unsupported
  `prompt` values.** Discovery advertises APP/COM `["none", "login", "create"]` and ORG
  `["none", "login"]`, derived from the resolver's per-realm table (Prompt Create 1.0 §4.2 MUST for an
  OP supporting `create`). An unsupported value (`consent`, `select_account`, unknown, ORG `create`)
  and any combination of values get a direct HTTP 400 `invalid_request` from the OP with an
  `error_description` naming `prompt`, not a redirect (Prompt Create 1.0 §4.1, reading (a);
  "when in doubt, stop"). This is the one exception to N-1's redirect rule.
- **D-146 (WU-42 U-1)** **Jump forwarding of `redirect_uri` is an accepted risk for this cycle.**
  Whether a Jump-forwarded authorize request keeps `redirect_uri` byte-identical is not traced or
  fixed now; it is judged in the integration test with Jump (with WU-02g / A02-14, which is Not run
  until the Jump change, H8). Until then the OP's exact match (C-1) refuses any altered value, so the
  residual is failed sign-ins through Jump, not a wrong delivery.

**Owner decision on the 30-minute constraint (2026-10-23, final review BLOCKER-1).**

- **D-160** **Final 30-minute model.**
  1. All times are UTC. There are two deadlines. The RP `state` (JWT) expires 30 minutes after
     `POST /sign` and is judged by the clock of the Rails instance that checks it (skew between
     instances is accepted; no NTP or other external time source). The OP curfew is Admission
     issuance + 30 minutes, stored in the database and judged by the database clock
     (`ApplicationRecord.database_now`, i.e. `clock_timestamp()`; never `CURRENT_TIMESTAMP` or
     `now()`, which return the transaction start). The two are never compared with each other or
     extended. The RP deadline ending a few seconds earlier is intended.
  2. Supersedes: the RP clause of REQ-CURFEW 2 and of D-45, D-76, and the 35-minute proposal in
     `two.md` 5.6 #4. Unchanged: D-46, D-74, D-75, D-105, D-131, D-150.
  3. After the OP curfew: when the browser binding proves the request is the owner's own attempt,
     the OP ends the authorization transaction through the Cancel route and redirects to the
     registered `redirect_uri` with `error=access_denied`, the unchanged `state` and `iss` (the same
     shape as Cancel, so the reason is not revealed). Otherwise nothing is ended and the local
     uniform error is shown (D-73). Without the transaction row, Auth shows the uniform error (D-47).
     The OP keeps the authorization transaction row at least until the curfew (WU-06).
  4. The RP lands on `GET /sign/interruption` (D-153). Text, no reason shown: ja
     「ログインできませんでした。再度ログインしてください。」; en "Sign-in could not be completed. Please
     sign in again." One text for every reason, sign-up included.
  5. A failure at the boundary restarts from the RP 続行: with a Root Session the SSO path issues a
     code without re-authentication and no new session (D-104); without one the person signs in or
     signs up again; a registration already committed signs in (D-131). Beyond the session limit
     (APP 2, COM/ORG 1) the existing session-limit remediation asks the person to remove a session.

**Owner decision on the Visa migration units (2026-10-23, final review BLOCKER-2).**

- **D-161** **WU-02 moves one realm per commit.**
  1. Order: 02a (hosts, `VISA_*` keys) → 02b (empty Visa surface) → **02-APP → 02-COM → 02-ORG** →
     02i (Base page check, docs, ADR, Jump handoff document). Each realm unit moves V4–V10 (OP
     endpoints, issuer, Auth result target, ceremony binding confirmation, Rails-side Jump edges,
     logout, root issuance steps) in one commit; the earlier 02c … 02h split is withdrawn. Rollback
     is the revert of that realm's commit. Implementer effort medium or higher for the realm units.
     Makes D-158 / P-140 final and extends it to V7–V10 (verified: the Admission browser nonce is in
     the host-only Rails session, and `JumpRtReturnPolicy::ALLOWED_EDGES` lists no `VISA_*` edge).
  2. The Jump/Edge repository is not changed now. After a realm moves, sign-in through the deployed
     Jump stops working for that realm in development; accepted. The Jump change is designed after
     this implementation. Acceptance is by Rails tests only; A02-14 and A42-6 are Not run (Jump
     change pending); later units on a migrated realm are also accepted by Rails tests only.
  3. Preconditions unchanged: WU-04, WU-05 through WU-05g, WU-01, WU-03.
  4. **Invariant:** the redirect URIs registered at Google, Apple and Microsoft Entra
     (`OmniAuth.config.full_host` = `PUBLIC_AUTH_SERVICE_URL`; `/social/{google,apple,entra}/callback`)
     never change in any unit. WU-02 moves no provider callback to Visa and leaves the duplicate
     google/apple callback routes on `www` untouched. `/social/authentication/completion` on `www`
     is an internal receiver, not registered at a provider; WU-05 replaces it.

**Owner decision on the RP return target acceptance (2026-10-23, final review BLOCKER-3).**

- **D-162** **`target_link_uri` in the JWS `state`, as decided; acceptance moves to WU-43.**
  1. The path in the signed (not encrypted) `state` is readable to the OP, Visa and Jump, including
     any value inside a path segment. Accepted for this implementation; no extra path restriction
     beyond D-151. Recorded as a concern in `docs/backlog/2026-10-23-rp-target-link-uri-path-exposure.md`;
     another mechanism is considered after the JWS approach works.
  2. The A21 cases are retired: their behavior is accepted by A43 (A21-5 → A43-18, A21-8 → A43-19);
     no case asserts a query, a `pt` signature or lifetime, or that the target is invisible to the OP.
  3. D-151 removes the **RP** `pt` only (`OidcSsoInitiator`, `oidc_pt`, the RP callbacks, the RP
     `sign_in_url_with_pt(pt)` overrides). The RP helper is renamed (`sign_in_url_with_target`) so
     it cannot be confused with Auth's same-named method. Auth's signed `pt` lane
     (`AuthenticationRedirects`, `AuthenticationVisitor#sign_in_url_with_pt`) is not touched.

**Owner decisions on stop vs issuance (2026-10-23, final review BLOCKER-4; D-B4-1 … D-B4-4).**

Finding behind them (static reading, needs Red test R4-1): `log_in` checks `administratively_locked_resource?`
and `login_allowed?` once **before** the actor lock (`authentication_base.rb:332-333`) and not again
after `resource.lock!` (`with_actor_session_lock`, l.412-421). A login that passed the checks, then
waited while an identity stop committed (status changed, epoch E+1), creates a root carrying E+1
that `OpIdentityEventInvalidator` (cutoff E+1, `epoch < cutoff`) does not revoke; it becomes usable
again when the account is restored. Related, already reproduced:
`docs/backlog/2026-10-22-pre-stop-jwt-accepted-after-operator-restore.md`.

- **D-163 (D-B4-1) Final eligibility check at Root issuance.** After the principal row lock, the
  latest account state is re-read and every Root-issuance condition is checked again
  (`login_allowed?`, administrative lock, withdrawal/suspension, unfinished registration per
  D-106/D-128); a refusal issues no authority. The early check before the lock stays for fast
  refusal; only the check under the lock decides. It lives at the common Root-issuance boundary,
  not in controllers: today the only Root creator is `create_login_token_record`
  (`authentication_base.rb:2474`), reached only through `with_actor_session_lock`; any future Root
  creator must pass the same boundary (static guard).
- **D-164 (D-B4-2) Stop scopes stay distinct.** WU-16 keeps one common stop primitive, but
  locking and the epoch update depend on the scope:

  | Stop | Principal lock | `authentication_epoch` update |
  |---|---|---|
  | Account stop, withdrawal, Identity Stop | Required | Required |
  | All roots of a principal (revoke-all) | Intended; fixed by the inventory (`two.md` 6.14) | Per the stop contract; open |
  | One root (browser sign-out, RP-Initiated Logout) | Fixed by the inventory | Never |
  | One grant (token revocation) | Fixed by the inventory | Never |
  | Refresh reuse (that grant's family only, D-25) | Fixed by the inventory | Never |

  An implementation that updates the epoch on every stop is forbidden (one browser's sign-out
  must not end other browsers' roots). Zenith and OP are separate databases: Identity Stop keeps
  the durable event, direct apply, retry and sweep (D-34); until the OP side has revoked, old
  authority must still be refused by D-165. Principal → OP is the default order, but it is not
  applied to every path before the inventory (WU-35 found reversed orders).
- **D-165 (D-B4-3) Old authority is refused by epoch.** A Root issued before a stop never becomes
  valid again by restoring the account. Authentication and every re-issuance boundary (Access
  JWT authentication, browser root authentication, token exchange, refresh, issuance from a root)
  compare the root's epoch with the **authoritative** current epoch, read from the Zenith writer,
  not the `:reading` replica (development and production configure asynchronous replicas:
  `app_zenith_replica` etc. in `config/database.yml`; `OidcAccessTokenAuthenticator#find_resource`
  reads with `role: :reading` today). If the epoch cannot be read, fail closed. **Rule (owner,
  2026-10-23, O-1): `root_epoch == actor_epoch`.** After D-163 a root always records the epoch read
  under the lock and the actor's epoch only grows, so a larger root epoch can only be corruption and
  is refused. The legacy `nil` branch of `AuthenticationEpochValue.root_current?` is removed with
  WU-17's NOT NULL (D-159: no existing rows). RP local sessions still end through BCL and Access JWT
  expiry (D-111); this decision does not change that.
- **D-167 (O-2) Credential-change revocation serializes on the principal lock.** Revocation caused
  by a credential change (password/secret, contact, passkey removal through
  `CredentialSecurityTransition` / `IdentityCredentialRemovalCommitter`) takes the principal row
  lock and re-checks the credential under it, so a login that used the old credential and commits
  concurrently is refused (D-163's re-check sees the changed credential state) or is revoked by the
  same transition. Plain "sign out other sessions" (`AuthenticationOtherSessionsRevoker`) stays a
  point-in-time snapshot: a login committing during it is the person's own new session.
- **D-166 (D-B4-4) Lock inventory first.** Logout, refresh reuse, token revocation, revoke-all,
  Identity Stop, Root issuance and token exchange are inventoried (`two.md` 6.14, first pass done
  2026-10-23). WU-16 and WU-22 stay Design First until concurrency safety is shown.

**Owner decisions on the remaining items (2026-10-23).**

- **D-168 (R-1) Destructive changes are authorized for this cycle's implementation.** The owner
  allows destructive schema and data changes needed to implement the Work Units (table, column and
  constraint drops or replacements, reference-value changes, removal of code and routes). Database
  contents and anything entered through the Rails screens may be lost. This replaces the per-unit
  approvals (WU-10, WU-16 `logout_flows`, WU-17, WU-18f, WU-24f/g/h, WU-30, WU-34 COM; A10-6, A18-3,
  A24-5a/b/c, A30-1): they are no longer gates. Migrations stay ordinary Rails migrations and are
  run through the normal workflow; nothing outside this cycle's units is covered.
- **D-169 (R-3) Sentry D-UX / D-OBS.** The 503 while blocked shows no reason: ja
  「現在、ログインを受け付けていません。時間をおいて再度お試しください。」 (Sign In) /
  「現在、新規登録を受け付けていません。時間をおいて再度お試しください。」 (Sign Up); en "Sign-in is not
  available right now. Please try again later." / "Registration is not available right now. Please
  try again later."; no `Retry-After` header (the reopening time is unknown); `Cache-Control:
  no-store`. Observability: exactly one reason-coded log event per refusal (surface, flow, state;
  no Admission reference or other value); no audit record and no telemetry record.
- **D-170 (R-4) WU-28 leaves this cycle.** The dev-only ORG Bootstrap (Seed Operator) is moved with
  its full plan to `docs/backlog/2026-10-23-org-seed-operator-bootstrap.md`; T15 and X-12 are
  closed for this cycle. Nothing in the other units depends on it.

**Owner decision on the lost-authenticator threat (2026-10-23).**

- **D-171** **Passkeys stay discoverable; the authenticator stores no identifying account name.**
  Verified: every surface already registers discoverable credentials, and the authenticator's
  `user.name` / `displayName` is the account's Email today, so a found authenticator plus its PIN
  reveals the identifier that identifier-first relies on. Decision (option a): keep discoverable
  (non-discoverable would require sending credential IDs before authentication, an enumeration leak
  forbidden by the nondisclosure ADR), and register a fixed non-identifying label instead. Recorded
  as `adr/passkey-authenticator-account-label.md` (Accepted), which also amends ADR-PK: ORG requires
  discoverable credentials (no existing credentials after D-159) and the capacity is ten (D-116).
  Documentation: the usage inventory is `research/2026-10-23-passkey-usage-inventory.md`; the
  current-behavior overview `docs/security/passkeys.md` is part of WU-20's exit.

- **D-172 (S-1 … S-3) `two.md` 5.8 v2 is accepted as proposed.** S-1: a `risk` stop is an
  `all_roots_of_principal` stop with an epoch cutoff, applied through the identity-stop path. S-2:
  stop records and their children use the same retention as the OP logout records they replace,
  purged children-first and never before every participant reached a final state. S-3:
  `browser_logout` and `rp_initiated_logout` stay separate causes (audit), with the same scope and
  behavior. WU-16 and WU-22 now wait only on A44-1/A44-2 (D-166).

- **D-173 (owner, 2026-10-25) Cause mapping for the remaining root-revocation callers (WU-16).** Only
  the nine `two.md` 5.8 v2 causes are used; no new cause (finer causes may be added later).
  `SessionLimitResolutionTransactionable` (both sites), `AuthenticationSelectedSessionRevoker` and
  `AuthenticationSessionRevoker` → `revoke_others`; `AccountSessionRevocation` → `browser_logout`;
  `EnforcementCaseApplicable` → `administrative`; `AuthenticationBase` DBSC refresh failure and root
  refresh invalidated → `risk`. All seven are inside the 5.8 v2 static guard.

**Owner decisions of 2026-10-25 ("keep it simple now, improve later").**

- **D-174 (WU-11) Failed self-fetch retries: process-local negative cache.** When the coordinator's
  recent successful fetch lists the `kid` and this process's own fetch for it fails, the same process
  does not fetch that `kid` again for 30 seconds and answers unavailable (`recent_self_fetch_failed`,
  503 to callers) — unless an allowed-stale cached key exists, which keeps verifying. At 30 seconds
  the next request fetches again; a success clears the entry. The entry is per process, per JWKS
  client and per `kid`; it is not shared through Valkey. Improvement later (a shared or adaptive bound
  is not part of this cycle). Closes the open point of `evidence/2026-10-25-wu11-jwks-limits-W7Q3.md`.
- **D-175 (WU-18) WU-18c … WU-18f leave this cycle.** The OP-chain/RuntimeRole removal per surface
  (18c app, 18d com, 18e org) and the table drops (18f) are deferred to a later cycle. The WU-18a
  inventory and the WU-18b plan stay as written in `two.md`; Q18-1 … Q18-4 stay open for that cycle.
  Recorded in `docs/backlog/2026-10-25-op-chain-runtime-role-removal.md`.
- **D-176 (WU-38) Refusal copy and cleanup schedule.** (1) A new APP/COM sign-up whose email or
  telephone is still held by an unfinished registration (D-131, D-135) is refused with option A, which
  says nothing about registration state:
  - ja: 「このメールアドレスでは、いま登録を始められません。しばらくしてからもう一度お試しください。」
  - en: "You can't start a registration with this email address right now. Please try again later."
  - telephone: 「この電話番号では、いま登録を始められません。しばらくしてからもう一度お試しください。」 /
    "You can't start a registration with this phone number right now. Please try again later."
  (2) Cleanup schedule: the existing `SignUpExpiryJob` every 15 minutes (`config/recurring.yml`); the
  wait after an abandoned attempt is therefore bounded by its Flow deadline (the Admission Binding
  curfew) plus at most 15 minutes. Improvement later.
- **D-177 (owner, 2026-10-25) (WU-38) Sign-up entry is fail-closed.** Controllers never clean up or
  supersede an earlier sign-up attempt inline to admit a new one (removing the refused attempt's own
  artifacts as part of a refusal is allowed, D-178); only the background job (`SignUpExpiryJob` and the
  existing artifact cleanup on Solid Queue) releases it. While this browser's attempt is nonterminal
  (including past its deadline) or terminal with cleanup pending, failed or past its retry cap, a new
  entry submit is refused and creates nothing; if the job is broken the refusal stays. No time-based
  release. A session hint naming an earlier admission's attempt is dropped only after that attempt is
  terminal with completed cleanup; the new attempt needs a new Base admission. The late Passkey save
  (`auth/app/sign/up/check/telephone/passkeys_controller.rb`) and the Email/Telephone sign-up OTP
  issuers, verification committers and delivery guards only refuse an overdue Flow; the job expires it.
- **D-178 (owner, 2026-10-25) (WU-38) Underage birthdate refusal.** The age is decided on the
  validated, unsaved birthdate; a birthdate below the minimum age is never written. The refusal halts
  the attempt through `SignUpTermination` with same-request cleanup; on cleanup failure the existing
  cleanup-pending state, contact hold (D-177) and retention retry apply, and nothing new is added.
  Calendar-impossible dates stay accepted by design and count as the first of the next month for age.
  One shared check covers APP email/telephone/Google/Apple and COM email/telephone; ORG collects no
  sign-up birthdate.
- **D-179 (owner, 2026-10-25) Retire the POST admission attachment and the legacy sign-out records;
  widen two cause scopes.** (1) Auth admission attachment is the Design D GET `/ceremony_bindings`
  only: `POST /ceremony_bindings` and the Auth continuation form that posted to it are removed, with
  tests whose only subject was that POST (CSRF on the attachment POST included); CSRF and transport
  protections are asserted on the remaining GET/confirmation POST. (2) The `op_*_authority_stops`
  records are the only sign-out authority: `ClientSignOutFlow`, `VisitorSignOutFlow`,
  `OperatorSignOutFlow`, their kind/status tables, the `SignOutFlow` concern and every writer are
  removed (destructive, authorized by D-168/D-159). (3) Supplement to D-173: `administrative` and
  `risk` allow scope `root` as well as `all_roots_of_principal`, because method-protection
  enforcement, DBSC refresh failure and root refresh invalidation stop one root.
- **D-180 (owner, 2026-10-25) (WU-38 follow-up) Detect stuck registrations and narrowly permit
  reviewed cleanup retries.** APP/COM stuck-registration detection is read-only and runs from
  `RetentionPurgeJob` after its cleanup and retention work; it emits one structured application-log
  event per run with surface, case, counts and public identifiers only. A report failure is logged
  and does not interrupt the job. No stuck case is released automatically. After diagnosis, an
  operator may invoke the existing `SignUpArtifactCleanup.call(cycle:)` once for a terminal Flow
  whose cleanup is still pending or failed at/above the ten-attempt cap; D-177's background-only
  release rule has this narrow exception. Retention preserves a non-completed terminal Flow until
  artifact cleanup completes, so the capped case remains diagnosable. A missing-Flow
  principal/contact has no safe existing cleanup entry point, so it remains held and is escalated;
  operators do not delete it directly. ORG has no equivalent unfinished status or retry fields and
  is not reported as zero.

**Sign-out suite redesign and WU-18 (owner, 2026-10-26).** Audit, rationale and the decision log:
`ten.md`. The logout suite withdrawn on 2026-10-25 returns to this cycle under these decisions.

- **D-181 WU-18c … 18e return to this cycle.** Every first-party RP becomes a standard OIDC RP now:
  the OP-chain path and the RuntimeRole switch are removed (supersedes D-175 for 18c … 18e). WU-18
  may change the Sign-in code it needs (`OidcCallback`, `BrowserRpAuthentication` and the RP
  authentication boundaries); this is the only exception to "Sign-in / Sign-up are not changed" in
  the sign-out redesign. Q18-1 … Q18-4 are answered before 18b/18c start. 18f (table drops) is
  decided separately. **Same day:** the owner judges Q18-1 … Q18-4 after the sign-out implementation is
  finished; until then 18c … 18e do not start and sign-out is built on the path each client runs
  today (OP-chain for all twelve). Groundwork: `docs/backlog/2026-10-25-op-chain-runtime-role-removal.md`.
- **D-182 Sign-out shape.** RP → OP → RP by RP-Initiated Logout 1.0. The originating RP clears its own
  session and cookies before redirecting (D-33 (2) kept); the return changes no authority and deletes
  nothing. The OP authority stop is the truth; normal sign-out ends the browser's current root and
  its grants only; APP/COM/ORG never propagate to each other. Forward-only: no compensation, no
  cascade, no guessed target, no new "indeterminate" database state (recover from the root and stop
  records); an unconfirmed outcome is never reported as success. The completion page belongs to the
  originating RP and is shown once (one-time notice; a reload answers 404, kept).
- **D-183 Back-Channel Logout timing.** After COMMIT the request makes one bounded first delivery
  attempt to the stop's participants (parallel, one total deadline, leases shared with
  `OpOutboxDispatchJob`), then redirects; the job owns every retry. HTTP 204 counts as an
  acknowledgement. ADR amended 2026-10-26.
- **D-184 End-session target and refusal.** The OP stops the browser's current root; an
  `id_token_hint` must identify a grant of that root. With a verified hint and no current OP session,
  or a hint that does not match the current root: HTTP 403, plain text "This action is not
  allowed." / 「禁止された振る舞いです」 (i18n keys), no state change, no redirect. The suspected
  defect that the confirmation stops nothing when the hint's `sid` is a grant id (`ten.md` F-5) is
  proven by a failing test first, then fixed in the Visa sign-out code.
- **D-185 Removals.** `AcmeLogoutTransaction` with its concern, coordinator, readers and table; the
  OP `/sign/bye`, `OpLogoutReceiptSession`, the browser receipt and the
  `*_authority_stop_browser_logouts` tables (new migration; migration work approved by the owner).
  The authority-stop records, targets and participants stay.
- **D-186 RP token revocation before redirect.** ~~The originating RP revokes its refresh token at the
  OP revocation endpoint (RFC 7009, `private_key_jwt`) before clearing itself and redirecting;
  bounded; a failure is logged and does not stop the sign-out. Replaces the RP's direct OP grant
  stop, which WU-18 removes.~~ **Withdrawn the same day by D-188.**
- **D-187 WU-44 split.** A44-2, 4, 5, 6, 7, 10 are added as tests this cycle (A44-6 and A44-10 also
  count for sign-out acceptance); A44-9 (credential version re-check) goes to backlog
  `2026-10-26-credential-version-recheck-at-root-issuance.md`.
- **D-188 The RP discards its own tokens; the OP stops authority (replaces D-186 and D-5 (a)).** The
  originating RP clears its own cookies and session and redirects to `end_session_endpoint`; it does
  not write OP authority and does not call the revocation endpoint during sign-out. The OP stops the
  root and its grants when the person confirms. Basis: RP-Initiated Logout 1.0 sets no RP token
  revocation; RFC 9700 §4.14.2 places refresh-token revocation on logout with the authorization
  server; Spring Security's OIDC logout handler only redirects. Known gap: a cancel at the OP leaves
  that RP's grant alive until it expires, usable only with the already deleted cookie; backlog
  `docs/backlog/2026-10-26-rp-grant-alive-after-cancelled-op-logout.md`, revisited with WU-18.
  Owner: "implement and change it if it does not work".
- **D-189 `POST /sign/out/purge` removed** (`RpCookiePurgeEndpoint` and every route and test); no
  caller, not part of any OpenID logout specification.
- **D-190 Discovery advertises Back-Channel Logout.** `backchannel_logout_supported` and
  `backchannel_logout_session_supported` are `true` (Back-Channel Logout 1.0 §2.1). The `sid` in the
  ID Token must be the `sid` the Logout Token carries; the random `sid` fallback of
  `SecurityJwtOidcIdTokenCodec` (`ten.md` F-8d) is replaced by a fail-fast error (exception to S-9,
  owner 2026-10-26).
- **D-191 Logout without a usable redirect ends on the OP's own page.** Without `id_token_hint`, or
  without a registered `post_logout_redirect_uri`, the OP never redirects (RP-Initiated Logout 1.0
  §3) and, after the confirmation, shows its own signed-out page once (303 to a GET; a reload answers
  404). This replaces `/sign/bye`.
- **D-192 Auth `/sign/out` stays as an entry** that clears Auth ceremony state and redirects to the
  Base sign-out; only its `logout_challenge` branch goes with D-185.
- **D-193 No Back-Channel Logout delivery from the sign-out request this cycle (P-A; changes D-183).**
  Participants are committed with the stop and `OpOutboxDispatchJob` delivers them right after
  commit, as today; 204 still counts as an acknowledgement. The bounded in-request attempt returns
  with WU-18, when first-party receivers have an effect, and only with a process-wide bounded
  executor, a DNS timeout and a deadline that covers preparation and recording (Codex review CR-1,
  CR-2; `ten.md` §6). `ten.md` is the single current sign-out text.
- **D-194 Remaining-work decisions (owner, 2026-10-26).** (1) A34-2 APP Secret: a refused sign-in of
  an unfinished registration must not consume the Secret (its `claimed_at` stays
  unchanged) — fix this cycle. (2) COM sign-in retirement is decided but outside this cycle; COM
  OP/RP stays as is, and the COM A34-2 cases are dropped from this cycle's acceptance. (3) WU-36,
  WU-37 and WU-41 deployment checks move to `docs/backlog/2026-10-26-pre-deployment-checks.md`.
  (4) The owner's sign-out browser check (`ten.md` §5) runs after the implementation.
- **D-195 Out of this cycle (owner, 2026-10-26).** WU-30 follow-ups (per-record Step-Up binding,
  cross-database atomicity, TOTP registration boundary failures) →
  `docs/backlog/2026-10-26-step-up-evidence-binding-and-atomicity.md`. WU-28 is not implemented and
  left exactly as it is (the owner has a new approach). `database_consistency` findings →
  `docs/backlog/2026-10-26-database-consistency-findings.md`. WU-18 Q18-1 … Q18-4 are judged after the
  implementation completes. WU-26 remainder: see D-196.
- **D-196 No hand-run diagnosis or cleanup in production (owner, 2026-10-26; withdraws D-82 and
  the WU-26 delivery).** Running Ruby on a production host to inspect or repair sign-up attempts is
  too dangerous. Remove `SignUpAttemptDiagnosisInventory`, its tests, the `sign_up:diagnose` rake task,
  and the manual diagnosis and manual `SignUpArtifactCleanup` sections of
  `docs/operations/stuck-sign-up-registration-runbook.md`. Keep the automatic WU-38 stuck-registration
  report (one event at 10 or more failed cleanups).
- **D-197 Visa confirmation refuses framed requests (owner, 2026-10-27; A12-5).** The Visa
  ceremony binding confirmation (APP/COM/ORG) refuses a request whose `Sec-Fetch-Dest` is present
  and is not `document` (for example `iframe`) with 400 before reading or consuming the binding, and
  sends `Content-Security-Policy: frame-ancestors 'none'` like the other relay hops. Rendering a
  non-consuming form in a frame was the observed behavior (`evidence/2026-10-27-cycle-relay-boundaries-P7Q3.md`)
  and is withdrawn; no first-party flow embeds this page. A request without Fetch Metadata keeps
  the non-consuming confirmation form (owner, 2026-10-27); A12-5 is amended to match.
- **D-198 APP social callback refusals follow D-47 (owner, 2026-10-27; implementation after the
  owner's manual model-layer check).** The model layer (`SocialAuthLoginHandler`) matches D-48 and
  stays. The Auth APP controller layer changes:
  1. `SocialAuth#handle_social_auth_error` and `#handle_record_not_unique` stop redirecting to
     `/sign/in` and call `refuse_sign_in_path!` (one uniform response, continuity cleared), with
     `intent_crossing` (L1/L2), `subject_enforced` (L8), `credential_failed` (L3/L6/L7),
     `state_invalid` / `state_expired`, `provider_failed`.
  2. The OmniAuth failure endpoint ends the attempt with `refuse_sign_in_path!("provider_failed")`
     instead of returning to `/sign/up` or `/sign/in`.
  3. A second social start inside one attempt (a Sign-up Flow already issued for the admission) is
     refused before the insert with reason `phase_violation` (option A; no new catalogue reason). The
     unique index stays as the last guard and its `RecordNotUnique` gets the same uniform response.
  Wedge tests first: `evidence/2026-10-27-social-crossing-wedge-tests-X7K2.md`; add "provider failure
  ends the attempt" and "second start is refused without a new Flow" before the change. ORG Entra
  shows distinct messages for an unprovisioned and a locked subject (D-47 gap); not decided.
- **Pending, not decided:** receiver and revocation-endpoint rate limits keyed on `remote_ip`
  (60/min and 20/min; all OP and RP self-calls share one address) — revisit in the audit. No
  automated browser E2E (D-114 stands); the owner verifies the browser flow by hand.

**Prepared material (2026-10-22, `two.md` Part 5, static reading).** Written so that Codex can
audit a complete package. New findings, not yet decisions:

- WU-11: `OidcOpJwksClient` refetches on every unknown `kid` with no per-issuer limit, and returns
  `nil` for both "unknown kid" and "fetch failed", so BX-7's 503-vs-400 cannot be honored (5.5).
- WU-33: APP Secret sign-in renders every non-evidence result (cooldown, guardrail,
  `login_forbidden`) as "invalid secret" 422; COM Passkey bypasses `AuthenticationSessionCommitter`;
  ORG Entra shows one generic error page; `render_sign_in_refusal`'s default message names the
  session limit for every refusal (5.4).
- WU-35: four paths take the principal lock before an OP lock; the social commit nests an OP lock
  inside a principal lock (5.2).
- WU-01: 72 test files call `issue_local_entry!` (not 71) (5.7).
- Outside scope: the Admission Binding's nullable parent columns and state timestamps encode state
  through NULL (5.3), to be reviewed separately.

Proposals awaiting the owner's review (after the audit): X-27 two lock orders by path family (5.2);
WU-24 migration order and the `not_applicable` value (5.3); WU-11 result table and a 30 s per-issuer
refetch limit (5.5); WU-21 return-target rules and a 35 min pending bound (5.6); WU-16/22 stop-record
tables and lock order (5.8); WU-28 Seed Operator design with a loopback-peer discriminator (5.9).

**`seven.md` disposition (H17, 2026-10-22).** Every finding was checked against the code or the
documents before acting; nothing was implemented.

| # | Finding | Verified | Disposition |
|---|---|---|---|
| 1 | COM cannot be gated by existing status | Yes (`VisitorStatus`, `EmailSignUpCandidateCreator`) | D-128 |
| 2 | Finalization: complete / expired / undeletable undefined per commit point | Yes (WU-05 F3/F4 vs D-105; A06-6) | A06-6 corrected to D-105; decided D-131 |
| 3 | SSO recovery fails if the cookie response is lost | Yes (`bind_committed_login!` sets cookies after commit) | D-104 erratum; D-130 |
| 4 | G-8/S-1 contradict D-51 | Yes | G-8 and S-1 corrected to D-51 |
| 5 | G-20 blocks non-browser stops | Yes (my generalization of D-123) | G-20 rewritten with authority per cause; D-123 clarified |
| 6 | ORG halt exactly-once not guaranteed by a plain insert | Yes (session vs Chronicle DB) | D-134 |
| 7 | `entry_intent` is a Binding column | Yes (`db/op_base_app_structure.sql:160`) | D-127 erratum; D-129; migration table required in WU-24 |
| 8 | Order/Gate conflicts | Yes | Gate applicability table in `three.md`; A13-2, A24-2 split |
| 9 | Stale text | Yes | Design D status lines and U1–U6 reference updated; history kept, marked superseded |
| 10 | A07-2 vs retryable | Yes | A07-2 per D-73 class |
| 11 | RuntimeRole removal missing | Yes (`rp_cell_local_session.rb:29`, `oidc_client_registry.rb:127`) | Added to WU-18 with split instruction |
| 12 | `local_sign_up_flow_ref` retirement missing | Yes (ceremony session tables) | Added to WU-24 |
| 13 | Reset OTP flow undefined | Yes | D-135: no reset; automatic cleanup only |
| 14 | BCL acceptance thin | Yes | A15-6 … A15-11 |
| 15 | JWKS cache failure rule ambiguous | Yes | WU-11 result-table requirement |
| 16 | Sentry list by verbs | Yes | WU-29 step 7 uses the final route/action table |
| 17 | Passkey ADR criteria missing | Yes | A20-5 … A20-10 |
| 18 | Security Mode ORG table missing | Yes | D-132 |
| 19 | RP return target tabs/lifetime | Yes | WU-21 definition requirements |
| 20 | Three files not self-contained; WU-26 timing | Partly (five.md/six.md are referenced) | WU-26 after WU-24; five.md named as WU-12 reference |
| — | A02-13, A12-3, A14-5, G-1, WU-36, WU-37 | Yes | Corrected in `three.md` |
| — | Split large units (WU-01, 02, 05, 18) | Agreed | D-133 |

**D-44** (owner, 2026-10-21): **Sign-in path** — anonymous sign-in / sign-up (and a future "sign out, then
sign in again" path) — and **Re-verification path** — two-step ceremonies for an already authenticated subject
(Step-Up, reauthentication, credential registration/change, bootstrap tickets) — are to be
**implemented completely separately**. Today both share `BaseAuthAdmissionCoordinator`,
`AuthCeremonyAdmission` and `*_auth_admission_bindings`, split only by `purpose`/parent
(`TICKET_CEREMONY_PURPOSES`). **Re-verification path is out of scope now**; only Sign-in path is redesigned. Sign-in path
is pre-authentication, so it is not an extension of authorization (no subject, no grant); Re-verification path is
authorization for a known subject and may later be designed as an OAuth extension.

Observed defects and their owner topic: F1 (Cancel/Switch 422 null Origin) → T3; F2 (silent 400s) →
T19; F3/F4 (relay clicks, double submit) → T1; F5 (Social 60 s) → T2; F6 closed (bot).

## 4. ADR and contract amendments this projection requires

These are class-O decisions that conflict with, or are absent from, Accepted records. None is written
yet; writing them is a later authorized documentation task.

| Record | Amendment |
|---|---|
| `adr/runtime-secret-isolation-deferred.md` | D-15 one credentials set in every environment; D-17 AWS KMS direction and Pending co-location; production exposure stated as an accepted consequence of D-19/D-20 |
| `adr/first-party-sign-out-op-commit-and-backchannel-logout-for-separated-rp-stores.md` | Applies to all first-party RPs (no activation); outbox persisted-in-transaction clause **kept** (D-117 supersedes D-28/D-30's accepted loss); residual Access JWT bound amended to 10 min + 30 s (D-111) |
| `adr/first-party-sign-out-shared-database-without-backchannel-logout.md` | Superseded for first-party RPs |
| `adr/base-auth-ceremony-and-seven-rp-boundary.md` | RP logout amendment text (sibling RP sessions remain) is outdated (D-33); RP credential amendment keeps cookies as a recorded exception (D-22 #3); Cancel/Switch leave `/oauth/authorize` (D-38); 2026-09-21 "GET never consumes" and 2026-09-20 "result POST-only" only if X-1 accepts an exception |
| `adr/jump-directed-rails-handoff-contract.md` | External RPs reach `/oauth/authorize` by direct redirect (**X-7**) |
| `docs/checklists/authentication.md` | AUTH-1/AUTH-2 (BCL CSRF exception; GET exception if X-1); AUTH-8 "NULL means Normal"; AUTH-10…AUTH-12 receipt contract removed; AUTH-14 reissue wording vs D-2; AUTH-16 removed |
| `docs/security/role-secret-isolation.md`, `plans/backlog/2026-10-18-production-runtime-secret-isolation.md` | Per-role design withdrawn |
| `adr/webauthn-discoverable-direct-sign-in.md` | Already partially superseded by ADR-PK (done) |
| New Visa OP ADR (WU-02 V11) | Partially supersedes the same-FQDN parts of `adr/base-authority-and-self-rp-separation.md` and "Base is the sole OP" in `adr/base-auth-ceremony-and-seven-rp-boundary.md` (D-59) |
| New Sign-up Finalization ADR (WU-05, before implementation) | Partially supersedes the social-commit-at-Base design of `adr/sign-up-authentication-handoff-and-social-rt.md`; states Auth-side pending accounts and shared Finalization, Sign In First for all six paths, D-72, D-77, D-83 (+ X-24/X-26 outcomes) |
| `adr/sign-up-flow-admission-binding-and-cardinality.md` (E1) | Implementation through WU-24; Pending table resolved only by owner decisions (X-13) |
| `adr/first-party-sign-out-op-commit-and-backchannel-logout-for-separated-rp-stores.md` | ~~D-28 removes the durable outbox for BCL only~~ — superseded by D-117: the BCL outbox stays; audit and other outboxes were never affected (H13) |
| `adr/sign-entry-sentry.md` (new, Accepted 2026-10-22, written) | Records D-84 … D-86 with current-code names (Base redirects); when D-59/D-38 land, read "Base" as the OP host owning ceremony start and Switch. D-93 … D-99 are written into it (2026-10-22). `docs/security/authentication-capacity-admission.md` (control table), `docs/security/idp-flow-lifecycle.md` (availability row), `docs/security/sign-{in,up}-sequence.md` and `docs/checklists/authentication.md` are updated only when Sentry is implemented |
| `adr/authentication-security-cycle-consolidation-2026-10-15.md` §2.6 | D-92 decides the Pending item "handling of an `ADVANCED` actor found with fewer than two active passkeys" for ORG at migration (stays `ADVANCED`, keeps signing in with existing passkeys, required to register a second); record it before D-88 is implemented. `adr/authentication-security-mode.md` Open decision 1 is answered by consolidation §2.2 and should say so |
| `adr/passkey-identifier-first-sign-in.md`, `adr/identity-resolution-and-credential-binding.md`, `adr/passkey-current-state-limit-and-chronicle-outbox.md`, `adr/README.md` | D-116: the four-slot capacity is superseded and ten per Identity restored; the 2026-10-19 ADR's "partially superseded" note is reversed for capacity only |
| `adr/base-authority-and-self-rp-separation.md` | After X-19: the self-RP's pending OIDC state lives outside the Rails session that the Authority rotates at login. If Phase 3 finds Base's Local Sign-in Flow to be a non-OIDC shortcut, record how D-54 treats it (D-57: only when the change needs it) |
| ADR for the RP return target (amend `adr/redirect-target-lanes-pt-nt-xt.md` / `adr/signed-return-targets-only.md` for the RP lane, or a new ADR) | D-137: RP-signed `pt` up to the start of authentication, tied to `state`, once; records the partial supersession of D-42 / D-109 / D-55's mechanism; Jump/Away rules unchanged |
| RP JWT verification (ADR or `docs/security` page chosen by the owner) | D-136: distributed refetch limit, typed result (found / invalid / unavailable), 503 vs 400/401 |
| Sign-up Finalization ADR (WU-05a) | D-131 replaces the "completing commit after the deadline is refused" reading of D-105 (G-9 / A06-6 corrected 2026-10-22) |

## 5. Open decisions, in unblocking order

| # | Decision | Blocks | Notes / recommendation |
|---|---|---|---|
| X-1′ | ~~Protocol pattern for the anonymous ceremony~~ → **Decided D-100** (Design D) | T1, T3, T5 | — |
| X-1 | ~~GET continuation / Root Session by GET~~ → **Decided D-100** | T1, T3, T5 | — |
| X-2 | ~~Removal of the pre-R5 OP-chain path~~ → **Decided D-108** | T6–T13 go-live | — |
| X-3 | ~~BCL promise, executor, receiver parent~~ → **Decided D-117, D-118**; dispatcher choice is X-41 | T10 | — |
| X-4 | Stop primitive → **Direction decided D-119** (new browser-independent stop record as authority); the cause × scope × realm matrix, lock order and table design are drafted in `two.md` WU-16/WU-22 | T11, T12, T13 | Joint with SO-3 |
| X-5 | ~~Entry input format and post-cancel destination~~ → **Decided D-109** | T3, T14 | — |
| X-6 | ~~Explicit intent vs silent re-authorization~~ → **Decided D-110** | T1, T7 | — |
| X-7 | ~~External RPs and Jump~~ | — | **Resolved by D-53** (Accepted `adr/oidc-rp-scope-umaxica-tlds-only.md`) |
| X-8 | ~~One-Puma self-call capacity~~ → **Decided D-120: increase workers/threads only** | T7, T8, T10 | Numbers from a load estimate |
| X-9 | ~~Access JWT 10 min vs 300 s + 30 s~~ → **Decided D-111: amend the ADR to 10 min + 30 s** | T9, T10 | — |
| X-10 | ~~Identifier-first this cycle~~ → **Decided D-112: this cycle**; capacity ten (D-116) | T16 | — |
| X-11 | ~~Region vs language~~ → **Decided D-113: language only** | T17 | — |
| X-12 | Bootstrap → **Direction decided D-122: rebuild from scratch, destructive changes allowed**; the new entry, deployment discriminator and context design are drafted in `two.md` for review | T15 | R-14's requirements stay as review criteria |
| X-13 | ~~E1 remaining~~ → **Decided D-125 (①②③), D-127 (④)** | T6 | E1 ADR Pending items other than these stay Pending |
| X-14 | ~~Sign-out SO-1/SO-2/SO-7~~ → **Decided D-123 (strict)**; table design with X-4 in `two.md` WU-16/WU-22 | T12, WU-22 | — |
| X-15 | ~~Replacement Gates~~ → **Decided D-124: `three.md` G-1 … G-16** | Acceptance | Gates for D-84 … D-123 still to be added |
| X-17 | ~~Social sign-in vs sign-up crossing~~ | — | **Resolved** by D-47 P1, D-48, D-72; remaining work is implementation (WU-05, WU-08) |
| X-16 | ~~F1 root cause~~ → **Closed by D-102** (no POST relay survives D-100) | — | — |
| X-18 | ~~`GET /sign` Continue page~~ → **Decided D-103: kept for every entry** | T1 | — |
| X-19 | ~~Where the self-RP's pending OIDC state lives on the shared Base host~~ | — | **Resolved by D-59** (Visa host separation) |
| X-20 | ~~Post-containment journey~~ → **Decided D-104** | T1, T5, T6 | — |
| X-21 | ~~Browser E2E this cycle~~ → **Decided D-114: not this cycle** | Acceptance | — |
| X-22 | ~~No subdomain sharing for every cookie~~ → **Decided D-115: all host-only** | Repository split, D-58 consistency | — |
| X-23 | ~~Ceremony-binding confirmation after the Visa split~~ | — | **Resolved by D-61** |
| X-24 | ~~Finalization spanning the deadline~~ → **Decided D-105: refused after the deadline** (supersedes D-83) | T2, WU-05, WU-06 | — |
| X-25 | ~~10-second origin~~ → **Decided D-101** | WU-12 | — |
| X-26 | Durable registration authority gate → **Direction decided D-106**; AX26-1 Red test runs first | T6, WU-05, sign-in paths | — |
| X-27 | Concrete lock order → **Approach decided D-107**: inventory first, Q9 order as the target; the final order is still open | WU-05, WU-24 | Inventory of current lock acquisitions |
| X-28 | ~~Repair of partial registrations~~ → **Decided D-126: user reset + automatic deletion after expiry** | Operations | — |
| X-41 | ~~BCL dispatcher~~ → **Decided D-121: Solid Queue** | T10, WU-15 | — |
| X-42 | ~~COM unfinished-registration gate~~ → **Decided D-128** | T6, WU-34 | — |
| X-43 | ~~`entry_intent` rows~~ → **Decided D-129** | T6, WU-24 | — |
| X-44 | ~~Lost response before cookies~~ → **Decided D-130** | T1, WU-27 | — |
| X-45 | ~~ORG halt exactly-once~~ → **Decided D-134** | T24, WU-32 | — |
| X-46 | ~~Re-registration reset flow~~ → **Decided D-135: no reset** | WU-38 | — |
| X-47 | ~~Security Mode ORG permission table~~ → **Decided D-132** | WU-30 | — |
| X-48 | ~~Finalization state per commit point~~ → **Decided D-131** | T6, WU-05, WU-34, WU-38 | — |
| X-29 | ~~Sentry enforcement set~~ → **Decided D-93** | T21 | — |
| X-30 | ~~Class placement and names~~ → **Decided D-94** | T21 | — |
| X-31 | ~~Provider callbacks under `BLOCKED`~~ → **Decided D-95** | T21 | — |
| X-32 | ~~ORG scope~~ → **Decided D-96** | T21 | Does not decide D11/D12 of the Sign In First ADR |
| X-33 | ~~Transition from `sign_up_suspended_*`~~ → **Decided D-97** | T21 | — |
| X-34 | ~~OP pre-check with `temporarily_unavailable`~~ → **Decided D-98: no** | T21, T19 | — |
| X-35 | ~~Refusal class; flag-store failure~~ → **Decided D-99** | T21, T19 | — |
| X-36 | ~~Security Mode scope this cycle~~ → **Decided D-88: implement the migration.** Remaining gate: explicit approval of the destructive data migration with a recovery plan. The Security Mode ADR's Open decision 1 is settled by consolidation §2.2 (two active passkeys; nothing else counts) and Open decision 2 by §2.5; Open decisions 3 (recovery), 4 (ORG sign-up) and 5 (reconciliation) and the rest of consolidation §2.6 do not block the value migration and stay Pending; the §2.6 item "an `ADVANCED` actor with fewer than two active passkeys" is decided for the migration by D-92 | T22, T16 (X-10) | Order backfill before DB constraints; `docs/mermaid/` axis in the same change; re-survey the latest local `feature` branch before the migration (ADR verification requirement); `NULL` and unknown values permit neither authentication nor authorization (§2.1) |
| X-37 | ~~How to proceed on `already_verified`~~ → **Decided D-89: Red tests first** | T23 | The reconciliation itself (idempotent re-delivery, refusal, or re-check) stays open until the Red results are recorded |
| X-38 | ~~Target cycle and write path~~ → **Decided D-90: this cycle, direct Chronicle write** | T24 | Lock order relative to the halt and the Chronicle row remains an implementation detail inside X-27's principle |
| X-39 | ~~Failure convergence scope~~ → **Decided D-91: the table now, implementation after X-20** | T25, T19, X-20 | — |
| X-40 | ~~Mapping of existing `mfa_level_id` values~~ → **Decided D-92** | T22, D-88 | — |

**Must stay Pending** (implementer must not decide): the E1 ADR Pending table (restart after OTP
issuance or evidence, OIDC/Local restart route, legacy backfill, `ON DELETE`, Purger order,
retention, D14); `global`-pod signer co-location (D-17).

## 6. Work already done in this cycle (committed in `6e4d70d0b`)

| Change | Files | Verification |
|---|---|---|
| `# FIXME:` markers on the multi-job `/oauth/authorize` | `app/controllers/base/{app,com,org}/oauth/authorizations_controller.rb`, `app/controllers/concerns/oidc_authorization_result_post.rb` | Comments only; RuboCop clean |
| Secret sign-in page "他の方法を選びますか？" back link | `app/controllers/auth/app/sign/in/secrets_controller.rb`, `src/pages/auth/app/sign/in/secrets/new.tsx`, `test/controllers/auth/app/in/secrets_controller_test.rb` (setup extracted to a helper), `gait/pages/auth/app/secret_sign_in_presentation.test.tsx` | New tests Red then Green; Vitest 15/15, Minitest 14/14; RuboCop, oxfmt, oxlint, `tsc --build` clean. `test/integration/app_secret_login_journey_test.rb` + `oidc_initiated_sign_in_completion_test.rb`: 23 errors `Couldn't find OpAppProtocolEpoch with 'id'=1` (known missing reference data, `plans/backlog/2026-10-20-reference-data-outside-migrations.md`) and 2 failures in result/session-limit paths — not shown to be caused by this change (no pre-change run) |
| Evidence | `evidence/2026-10-21-oidc-browser-flow-log-review-R3N7.md` | — |
| Auth COM/ORG translation namespace (D-68) | `config/locales/{jp,us}/{ja,en}.yml`, 14 files in `app/controllers/auth/{com,org}/`, `test/security/invariants/auth_surface_translation_namespace_invariant_test.rb` | Guard Red → Green; 1263 runs, 11 failures, all pre-existing; RuboCop clean |
| G-1 baseline (owner-approved test DB rebuild, 2026-10-23) | 32 test databases dropped/created and migrated with `skip_initialize: true`; replicas untouched | 18448 runs, 77 failures, 2 errors; `evidence/2026-10-22-g1-full-test-baseline-B7G1.md` |
| Test DB rebuild and full run (owner-approved) | Dropped 1022 clone DBs; `db:drop db:create` + migrations for `test`; the 30 replica base DBs were deleted by mistake and recreated empty for the cloner. `db/` structure files unchanged | Run 3: 18420 runs, 59 failures, 1 error (TR, G1–G6); the epoch/function-owner environment errors are gone |

## 6a. Cycle documents status (2026-10-21)

- `two.md`: Work Units WU-01 … WU-05 (detailed), WU-06 … WU-23 (Part 2: Ready or Blocked with the
  deciding item). Every requirement in §2–§5 maps to a unit.
- `three.md`: Gate register G-1 … G-7, acceptance cases per Ready unit, standing checks S-1 … S-4,
  empty execution record. Implementation is to be done by another AI; nothing implemented from
  these definitions yet.

## 7. Next: definition packages for `two.md` (from `four.md` §3)

1. Current contract projection — **this document** (done when the owner accepts it).
2. Retained RP topology and path selection (X-2, X-8; CR R-04, R-15).
3. OP authority-stop contract with Sign-out (X-4, X-14; CR R-06).
4. BCL delivery and receiver (X-3, X-9; CR R-03 … R-09).
5. Admission, continuation and Cancel/Switch (X-1, X-6; CR R-10, R-11).
6. E1 Flow authority (X-13; CR R-12, R-13).
7. RP navigation and logout (X-5, X-7; CR R-16).
8. Bootstrap (X-12; CR R-14).
9. Passkey and translations (X-10, X-11; CR R-17, R-18).

### 7.1 H7 investigation plan (Sign-in path, entry to return)

Rule: past explanations (ChatGPT, five.md, H7 §3) are hypotheses; only current worktree code,
configuration, tests and logs count. Report gaps that existing logs cannot trace as observability
defects. Correlate with safe IDs; never log secrets, cookies, codes or tokens.

- **Phase 1 — trace the current routes:** Warp top → sign-in; Warp top → sign-up; Warp protected
  URL → sign-in; Base self-RP sign-in/up (report it as broken where it is, TR G1); return to the
  original page; Cancel / Switch / expiry / refusal. For each hop record: host, URL, method, status
  (303/302/409/422 …), Jump issue/pass/verify, cookies set/updated/deleted, `state`/`nonce`/PKCE
  creation and checks, Admission issue/attach/confirm/consume, the Auth result, the Root Session,
  the RP session, and the return target before and after.
- **Phase 2 — UX classification** of every page: a user decision; authentication itself; relay
  only; a Continue that can be removed or automated (X-18).
- **Phase 3 — common-method gaps** between Warp, Base, Palm, Core: sign entry, authorization
  request, callback, token exchange, RP session, return target, failure, sign-out. Base Local
  Sign-in Flow vs standard self-RP (D-54). OP/RP cookie responsibilities on one host, HTTP
  self-calls, Puma thread exhaustion (X-8), session-state mixing (X-19).
- **Phase 4 — Design D scope:** keep the RP intent, the OIDC authorization request, the Base ↔ Auth
  Admission, the OIDC callback and the RP return separate. List every GET state change with its side
  effects, safeguards and repeat behavior. The Root Session GET is decided on its own (X-1).
- **Phase 5 — implement after the open decisions:** TDD (Red → Green → Refactor) in small steps
  that keep each existing safety property. Unit, integration and real-browser E2E (X-21): complete
  sign-in/up; no meaningless Continue; no JS relay; no relay-HTML flicker; target neither lost nor
  replaced; double submit, resend, expiry, foreign browser and concurrency controlled; no duplicate
  or inconsistent Root/RP sessions; no sign-up/sign-in regression. Update ADRs and docs as each step
  needs them (D-57).

Deliverables to present first: **A** route diagrams (Warp-origin and Base-origin, entry → relays →
exit); **B** URL / method / status / cookie / state-transition table with the owning code and
confirming tests and logs; **C** gaps against D-54 … D-57 (implemented / not / ADR mismatch / open);
**D** unnecessary Continue pages, why they exist, how to remove them; **E** Design D re-evaluation,
especially GET state changes and Root Session establishment (security, standards, alternatives);
**F** a staged plan (targets, order, tests, risks, rollback). Open security questions are presented
to the owner, never resolved silently.

Principle (H7 §7): a person makes only the necessary decisions and authenticates; the system
completes the internal relays automatically and safely. Base is not special-cased.

## Appendix D — Decision log (verbatim history; superseded entries are marked in place and projected into §2–§5)


- **D-1** Base issues admissions, owns OIDC transactions, Root Session and tokens; Auth runs
  ceremonies, records evidence, hands results to Base; RP owns its session. No Auth Root Session path.
- **D-2** Session fixation containment: the four reissue methods and retry Browser Nonce restoration
  stay removed; finalized OIDC results are not reissued.
- **D-3** Sign In First: separate Sign-up and Sign-in state machines; registration hands off to full
  Sign-in controls.
- **D-4** OIDC result URL → `/sign/result` (GET/POST); Local `/sign/handoff`, Base `/oauth/authorize`,
  `/sign/completion` unchanged; no compat route; class names kept; OIDC and Local not merged.
- **D-5** E1: `SignUpFlow.auth_admission_binding_id` same-DB FK, ultimately NOT NULL, fixed at
  creation, sole authority; `local_sign_up_flow_ref` retired; Rails session locator is UI continuity.
- **D-6** ≤ 1 live Admission/Ceremony per parent transaction; no browser-wide singleton.
- **D-7** ≤ 1 in-progress Sign-up Flow per Binding by status-scoped partial UNIQUE; no time predicate;
  restart = HALTED + new row.
- **D-8** Integrity in PostgreSQL (FK/NOT NULL/UNIQUE); no trigger-based counting; NULL never carries
  meaning; no unnecessary `optional: true`.
- **D-9** ES384 only; no RS256; no algorithm fallback; strict alg/kty/crv/iss/aud.
- **D-10** Refresh Token mandatory: standard grant, rotation, reuse detection.
- **D-11** External RP session identifier is `public_id`, never numeric `id`; not a credential.
- **D-12** Separated RPs: OP COMMIT establishes sign-out; standard RP-Initiated Logout and
  Back-Channel Logout; outbox persists delivery intent; no single-service sign-out; `logout_challenge`
  not removed for being non-standard.
- **D-13** Bootstrap: ORG only; dev-only idempotent seed; Entra `(tid, oid)` only; no Passkey;
  separate controllers/callback; dev/test routes + independent refusal at finalization; no
  Flipper/ENV enablement; dedicated Authentication Context; minimal authorization; no
  Bureau/Ownership/Membership; fail-closed invitations kept.
- **D-14** `openid_connect` is the first-candidate RP library, not mandatory.
- **D-15** (owner, 2026-10-21) **Rails credentials: exactly one credentials set per Rails
  environment (development, test, production), shared unchanged by every process, role and
  surface.** No per-role, per-surface or per-cell credentials bundle in any environment, production
  included. Reason given: per-role credentials caused a regression earlier. This cycle implements no
  code for it; ADRs and docs are rewritten to state it (DOC-2).
- **D-16** (owner, 2026-10-21) Independent RP E2E (H4 §8) is not done this cycle.
- **D-17** (owner, 2026-10-21) Production runs on **AWS**. OP signing keys are to be held in **AWS KMS**
  (asymmetric `ECC_NIST_P384`, `ECDSA_SHA_384`, consistent with D-9); the private key never leaves
  KMS; `kms:Sign` is granted only to the OP workload's IAM role (e.g. ECS task role / EKS IRSA);
  AWS credentials that can sign are never placed in Rails credentials (D-15 makes those readable by
  every process). Pod split `global`, `publishing`, `regional(n)`; RP cells are not pods — several
  cells run in one pod. `kms:Sign` is never granted to `publishing` or `regional(n)` pods. The
  `global` pod co-locates the realm OP signers with the worldwide RPs (`rp-base-*-ww`,
  `rp-edit-org-ww`, `rp-tech-org-ww`); because IAM roles attach per pod, those RPs could request
  signatures. **How to treat that co-location is Pending** (owner, 2026-10-21: undecided; candidates:
  accept in an ADR, or split a `global-op` pod). Replaces the
  Google Cloud Secret Manager / Cloud KMS example in `adr/runtime-secret-isolation-deferred.md`.
  Recorded as a **decision in an ADR now**; implementation timing undecided (not this cycle unless
  re-scoped).
- **D-18** (owner, 2026-10-21) **R5 cell activation** (`op_client_activations` rows; switching an RP
  from the pre-R5 shared-DB path to its own cell DB, OIDC and BCL) is **forbidden in every
  environment, development included,** until both hold: OP signing runs through AWS KMS (D-17), and
  the `global` pod co-location decision is made. `AT-R5-03A` ("RP cannot read OP keys") is rewritten
  to this condition because D-15 makes the original wording unreachable. Cell paths are verified by
  automated tests only this cycle. **Withdrawn by D-35** (no cell activation remains after D-19).
- **D-19** (owner, 2026-10-21) **One Puma process serves every FQDN.** The owner never intended RP
  cells to run as separate processes; the per-role process implementation (`UMAXICA_RUNTIME_ROLE`
  roles other than `shared`, `RuntimeRoleRouteGuard`, `rp_cell_process?` branches) is to be
  **removed**. Exact removal scope, and its effect on D-17 (KMS / pod split), D-18, the separated-RP
  BCL ADR and the `rp_*` cell databases, is being clarified (Q-9).
- **D-20** (owner, 2026-10-21, Q-9a) **R5 OP/RP separation is withdrawn.** Accepted in an ADR: an RP
  compromise is equivalent to an OP compromise; surface boundaries are enforced by code discipline
  inside the one process. Remove all three layers: (1) process split (`RuntimeRole` non-shared roles,
  `RuntimeRoleRouteGuard`, `rp_cell_process?` branches); (2) RP-owned cell databases (`rp_*`, 12
  connections, ~96 `Rp*` models, `RpCallbackCommitter`, `RpRequestAuthenticator`); (3) RP↔OP
  OIDC/BCL for first-party RPs (RPs return to the OP-chain path,
  `adr/first-party-sign-out-shared-database-without-backchannel-logout.md` governs again). Owner
  condition: the design must account for **one Rack application on Puma serving every surface**.
  Which R5 parts that the shared path also uses are kept, and dropping databases, are separate
  questions (destructive steps need explicit approval).
- **D-21** (owner, 2026-10-21) The service stays a **monolithic Rails application split only by
  subdomain**, developed the **Rails Way**. Cookies are already separated per host; no new cookie
  requirement. New work must not reintroduce process-level or service-level splits.
- **D-22** (owner, 2026-10-21, layer (3) decomposition) **Kept**: #1 OIDC Authorization Code + PKCE
  between first-party RPs and Base OP; #2 Token Endpoint over HTTP with `private_key_jwt` client
  assertion (`OidcOpTokenClient`); #3 Access/Refresh in `__Host-` host-only cookies. Still under
  discussion one by one: #4 JWT/ID Token verification (in-process key vs OP public JWKS), #5 RP
  session storage location, #6 refresh delivery receipts, #7 Back-Channel Logout, #8 RP-initiated
  logout / `logout_challenge`, #9 Zenith→OP identity stop events (re-investigate), #10
  `op_client_activations` / `contract_epoch` (re-check).
- **D-23** (owner, 2026-10-21) **Standards-first OP for any RP.** Goal: an RP outside the WAF and
  without DB access, in any language, signs in / up / out with its ordinary OIDC library, lowering
  RP implementation cost. **First-party RPs also behave as standard OIDC RPs** (no OP-chain
  shortcuts; option "ア"), because a first-party-only shortcut becomes an accident source when RPs
  are added. Where UMAXICA is stricter (ES384 only, no downgrade — D-9), RPs use their library with a
  thin adapter. Missing standard capabilities are added; every deviation from the standards is kept
  only with a written rationale (conformance profile). **#4 decided**: first-party RPs verify ID
  Tokens and Access JWTs via Discovery → `jwks_uri` over HTTP, per issuer, ES384 pinned, bounded
  unknown-`kid` refetch, fail closed — the same contract as external RPs. **Back-Channel Logout is
  defined and fixed this cycle** (known issues, source reading: only `OpLogoutCommitter` writes
  outbox rows; dispatch runs only from the every-minute recurring job with no after-commit trigger;
  one job processes all three realms). **D-20 is amended accordingly**: the process split (layer 1)
  is removed; the standard RP↔OP contract (layer 3) is kept and completed; what remains of layer 2
  depends on #5.
- **D-24** (owner, 2026-10-21, #5) First-party RP local state stays in the **existing 12 `rp_*`
  databases** (one per RP client), served by the one Puma through Rails multi-DB. Kept tables:
  `rp_callback_states` (single-use state/nonce/PKCE), `rp_principals`, `rp_identity_bindings`
  (`(iss, sub)` → principal), `rp_op_session_bindings` (OP `sid`, BCL target),
  `rp_sessions` (cookie carries `public_id` only), `rp_event_receipts` (BCL `jti` replay/idempotency).
  `rp_refresh_attempts` depends on #6; `rp_sessions.installed_generation` on #6 and
  `contract_epoch` on #10. Layer (2) of D-20 is therefore **kept**, not removed.
- **D-25** (owner, 2026-10-21, #6) **Refresh follows the standards (RFC 6749 §6, RFC 9700 §4.14),
  no grace period.** Rotation on every use; reuse of a consumed refresh token returns `invalid_grant`
  and revokes **only that grant's refresh family**, never the OP Root Session (answers Q-R1), so the
  RP recovers by re-running the Authorization Code flow (try `prompt=none` first) and the user is
  not asked to authenticate again while the Root Session lives. Unknown/garbage tokens never revoke
  anything. **Removed**: the custom delivery-receipt query endpoint
  (`/oauth/refresh_delivery_queries`, `OidcRefreshDeliveryQuery`, `OidcOpTokenClient.query_delivery`),
  the receipt replay in `OidcRefreshTokenIssuer`, `rp_refresh_attempts` / `RpRefreshCommitter`
  recovery, and the AUTH-11/AUTH-12 receipt-window contract (checklist to be rewritten). Browserless
  refresh failures return 401 and recover on the next browser navigation. Precondition: a signed-in
  user reaching `/oauth/authorize` gets a Code without any page (the Continue-button work, ADM-3, is
  in scope this cycle; AR-2 user-activation analysis still applies to the remaining relays).
- **D-26** (owner, 2026-10-21, #7) **Back-Channel Logout is defined and fixed this cycle** following
  OpenID Connect Back-Channel Logout 1.0. Direction accepted: (1) send on every OP stop of a
  participating RP's `sid` or grant — logout, identity stop, token revocation, revoke-all, **refresh
  reuse detection included**; (2) revocation and outbox row in one transaction, after-commit dispatch
  plus sweep; (3) Logout Token `iss`/`aud`/`iat`/`exp`/`jti`/`sid`/`events`, no `nonce`,
  `typ: logout+jwt`, ES384; (4) 200 = done, 400 = permanent (no retry, observable), 5xx/timeout/
  connect = transient with backoff; (5) stop retrying after the RP session's maximum lifetime,
  recorded; (6) RP validates and revokes durably before 200, idempotent on `jti`; (7) Discovery and
  client metadata advertise BCL; (8) ADR supersedes the shared-DB logout ADR for first-party RPs; (9)
  realm outboxes/keys never mixed. Problems B1–B7 must all be resolved. **Implementation detail
  pending a deeper investigation** (owner asked what happens once B1–B7 are fixed and whether more
  problems exist).
- **D-27** (owner, 2026-10-21, Appendix B review) **BX-1 mandatory**: one OP authority-stop
  primitive; every stop goes through it. **BX-7 accepted**: key-unavailable / JWKS failure → 503,
  400 only for a verifiably invalid token. **BX-10 accepted**: per-participant retry deadline = grant
  absolute expiry + max Access JWT lifetime + clock skew. **Environment correction**: production
  Rails sits behind **Amazon CloudFront**; Cloudflare fronts only Jump-like services; the Cloudflare
  seen in the dev log is a development artifact. **Design stance**: sign in/up/out are deliberately
  unforgiving — no compensation paths — to keep the reasoning small and security high; the need for
  a durable outbox must be justified, not assumed (BX-2 under review).
- **D-28** (owner, 2026-10-21) **BX-2: no durable outbox (O2).** Loss of a notification is accepted
  because the OP revocation is already committed and a first-party RP's authority ends at its Access
  JWT expiry (5 min, core browser 10 min) when refresh returns `invalid_grant`. **Solid Queue is not
  to be used for delivery**; the delivery mechanism is being reconsidered. **BX-4/5: deliver to the
  RP's public URL** (through CloudFront/AWS WAF, same conditions as an external RP; WAF rule for the
  BCL path). **Single logout intent**: signing out at one RP (e.g. `jp.umaxica.app`) must also sign
  the user out of every other RP in that browser session (e.g. `us.umaxica.app`); BCL is the
  mechanism; BX-3 is to be resolved in that light.
- **D-29** (owner, 2026-10-21) **BX-3: every client must register a Back-Channel Logout URI**; a
  client without one cannot be registered and boot fails (fail fast). No "BCL not used" option.
  **Why public network**: RPs may be written in other languages and hosted elsewhere, so no internal
  network can be assumed; BCL delivery is designed for arbitrary internet endpoints, first-party RPs
  included. Delivery mechanism still under discussion. **Solid Queue is rejected for delivery
  because its workers cannot reach networks outside the WAF.**
- **D-30** (owner, 2026-10-21) **BCL delivery = T2**: after COMMIT, a dedicated in-process thread pool
  inside Puma (separate from request threads) POSTs each Logout Token through
  `OutboundHttp::Connection` (Faraday; HTTPS only, no redirects, explicit timeouts) to the RP's public
  URL, with a short bounded retry; loss on process restart is accepted (D-28). Puma already reaches
  the internet through the same connection (Cloudflare Turnstile verify, Google JWKS). **Added
  requirement**: connection-time SSRF protection in `OutboundHttp::Connection` for RP endpoints
  (resolve once, reject private/link-local/loopback/metadata addresses, connect to the checked
  address, response size limit). Receiver-side routing/CSRF/sender trust: under discussion.
- **D-31** (owner, 2026-10-21) **RP BCL receiver route**: `resources :closures, only: :create` under
  each RP host's `oidc` scope → `POST /oidc/closures`, controller `<Surface>::Oidc::ClosuresController`
  (e.g. `Core::App::Oidc::ClosuresController`) on all 12 RPs; registered as each client's
  `backchannel_logout_uri`. The existing `resource :backchannel_logout, path: "backchannel-logout"`
  routes and `BackchannelLogoutsController` classes are replaced with no compatibility route
  (`generic/no-compatibility-layer.mdc`).
- **D-32** (owner, 2026-10-21) **RP receiver hardening**: `ClosuresController` inherits the surface
  `BareController` (fixes today's direct `ActionController::API` inheritance against
  `project/controller-inheritance.mdc`); Rails CSRF verification is skipped for this `create` only,
  recorded as the sole AUTH-1 exception; the action never reads or writes cookies or session (static
  guard); rate limit per endpoint/source, body size limit (`RequestBodySizeLimit`), only
  `application/x-www-form-urlencoded`; responses 200 / 400 (verifiably invalid token) / 503
  (DB or JWKS dependency, BX-7) with `Cache-Control: no-store`; logs carry reason codes, never the
  token. **Sender trust is the Logout Token signature only** (ES384 via Discovery `jwks_uri`,
  exact `iss` and `aud`, `typ: logout+jwt`, BCL event, no `nonce`, `iat`/`exp` window, `jti`
  record, `sid` tombstone idempotency); no IP allow-list, no mTLS.
- **D-33** (owner, 2026-10-21, #8) **RP-Initiated Logout follows OpenID Connect RP-Initiated Logout
  1.0** (checked against the spec text 2026-10-21):
  1. **Scope**: confirming at the OP signs the browser's Root Session and every RP under it out
     (single logout, e.g. `jp` → `us`); other devices are separate (revoke-other-sessions). The
     current confirmation path is `SignOidcLogout#confirm_oidc_end_session_logout` →
     `AuthenticationLogoutCurrentSession` → `OpAuthorityStopCommitter`; the 2026-09-20 RP logout
     amendment text ("parent and sibling RP Sessions remain usable") is outdated and is corrected
     (resolves BX-12).
  2. **RP clears its own local session and cookies before redirecting** to `end_session_endpoint`;
     cancel at the OP therefore means "signed out of this RP only".
  3. OP accepts a signed `id_token_hint` with its issuer, audience, type and not-before claims
     verified; expiration is allowed for this hint. A supplied `client_id` must match the hint's
     client. The hint `sub` must match the authenticated OP actor. Its `sid` is declined because it
     names the RP grant; the current OP Root Session supplies the logout target. `ui_locales` is
     best-effort; `logout_hint` is unused. **The OP always shows a confirmation.** First-party RPs
     store their ID Token server-side with the RP grant and send it as `id_token_hint`. Redirect only
     to an exactly registered `post_logout_redirect_uri`, with `state`.
  4. `end_session_endpoint` treats **both GET and POST as the logout request** (spec MUST) and only
     stages and renders the confirmation; the user's confirmation is the separate CSRF-protected
     `POST /oidc/logout/confirmation` resource.
  5. **Deviation accepted**: the spec describes redirecting after notifying RPs; UMAXICA redirects
     without waiting for asynchronous BCL (D-30). Rationale: the initiating RP already cleared itself;
     other RPs catch up within seconds, or at worst at Access JWT expiry (5–10 min); no new authority
     can be obtained after COMMIT.
  - **Removed**: the RP writing `AcmeLogoutTransaction` into the OP DB before redirect and the RP
    re-revoking the OP grant on return (`OidcRpLogoutLauncher#revoke_browser_rp_origin_session!`).
    `logout_challenge` stays as the OP-internal state of its own confirmation ceremony (D-12), never
    an RP-facing parameter.
- **D-34** (owner, 2026-10-21, #9) **Zenith → OP identity stop propagation is kept** (used today by
  withdrawal ×2, administrative access lock, ORG operator lifecycle execute). It stays durable
  (Zenith event row + direct apply + `OpIdentityEventDeliveryJob` retry + 5-minute
  `OpIdentityEventSweepJob`) because a lost stop would leave a long-lived Root Session alive with no
  natural expiry bound; Solid Queue is acceptable here (DB-to-DB inside the app, no egress). It must
  go through the BX-1 stop primitive so RPs receive BCL (today `AuthenticationLogoutCurrentSession`
  is called without `within_commit`, so no BCL is sent despite the class comment). The
  `authentication_epoch IS NULL OR < cutoff` NULL meaning is handled with #10.
- **D-35** (owner, 2026-10-21, #10) (1) **`op_client_activations` and `OpClientAdmissionGate` are
  removed** (no `op-*` roles after D-19); **D-18 is withdrawn** (no cell activation exists any more).
  (2) **`contract_epoch` is removed**: `Op*ProtocolEpoch`, the `contract_epoch` columns on roots,
  grants, authorization transactions and `rp_sessions`, refresh epoch matching (AUTH-16), the
  `umx_contract_epoch` Access JWT claim, RP-side matching and `UMAXICA_RP_CONTRACT_EPOCH`. The
  realm-wide emergency stop becomes "revoke every grant of the realm through the BX-1 stop
  primitive" (standard, emits BCL). The backlog bug "code exchange from a NULL/older-epoch root
  creates a current-epoch grant" becomes moot. (3) **`authentication_epoch` is kept** (identity stop,
  D-34) and made NOT NULL on roots and grants: existing NULL → 0 (behavior-preserving because every
  cutoff ≥ 1), value always written at issuance, no default; the bulk update needs explicit approval
  before execution.
- **D-36** (owner, 2026-10-21, Q-3) **Admission deadlines**: the 60 s binding `expires_at`
  (`OpaqueAdmissionStore::CODE_TTL`) governs **acceptance only** (the one Base→Auth redemption).
  After redemption, continuation is governed by **min(ceremony session expiry (30 min), parent expiry
  — OIDC `login_challenge_expires_at` (10 min) / Local Sign-in Flow `expires_at` (15 min))**; single
  use, binding/browser match and not-retired checks stay. Fixes F5
  (`auth_social_admission_binding!` must stop using `binding.expired?`). Accepted consequence: a
  Sign-up (15 min) outliving its OIDC parent (10 min) completes registration but its Sign-in handoff
  fails; the user signs in again (no compensation).
- **Open (2026-10-21)**: relay clicks. Owner rejects both the Continue-button relays and JS
  auto-submit (must work with JS disabled). Proposal under discussion: server-side 303 chain where
  each hop is a GET consuming a single-use, short-lived reference **only after** host-only cookie
  browser-binding verification (the same safety basis as the OAuth authorization code), requiring an
  amendment of the 2026-09-21 "GET never consumes" ADR rule and AUTH-1/AUTH-2; would also remove F1.
  Owner is reproducing sign-in actions to review the live behavior first (log offset 5811).
- **D-37** (owner, 2026-10-21) **One entrypoint carrying several jobs is unacceptable.**
  `/oauth/authorize` today serves the OIDC authorization request plus ceremony start
  (`ceremony_action`), Auth→Base result (`result_ref`), Cancel (`cancellation_ref`) and Switch
  (`switch_handoff`), dispatched on parameter presence (`OidcAuthorizationResultPost#create`,
  `Base::*::Oauth::AuthorizationsController#show`). Target: `/oauth/authorize` carries only the
  standard authorization request; the other jobs move to dedicated Base resources. This **amends D-4**
  ("Base `/oauth/authorize` unchanged") — amendment confirmation and resource naming pending.
  `# FIXME:` markers were added (comments only, RuboCop clean) to
  `app/controllers/base/{app,com,org}/oauth/authorizations_controller.rb#show` and
  `app/controllers/concerns/oidc_authorization_result_post.rb` (`#create`,
  `#render_oidc_exit_continuation!`). Live confirmation 2026-10-21: all four APP RP entries (www,
  www-jp, jp, palm-jp) reach the Auth sign-in form; Cancel and sign-in→sign-up Switch both fail
  with 422 null Origin at `POST https://www.umaxica.app/oauth/authorize`.
- **D-38** (owner, 2026-10-21) **This cycle carves out Cancel and Switch only.** On each Base host:
  `namespace :oidc { resource :cancellation }` → `/oidc/cancellation`
  (`Base::<Surface>::Oidc::CancellationsController`, APP/COM/ORG) and `resource :switch` →
  `/oidc/switch` (`Base::<Surface>::Oidc::SwitchesController`, APP/COM; ORG has no Switch). Names
  follow `generic/routing.mdc` (nouns, no route-level `path:`) and mirror Auth's existing
  `resource :cancellation` / `resource :switch`. The `cancellation_ref` / `switch_handoff`
  branches leave `/oauth/authorize` with no compatibility route. The Auth→Base result (#3) stays on
  `/oauth/authorize`, so **D-4 is not amended**; D-37's wider split remains a later decision.
  Actions (keep `show` + `create`, or GET-only after the relay redesign): pending.
- **D-39** (owner delegated the design to Claude, 2026-10-21; owner's model confirmed against
  `OidcAuthorizationResultPost#cancel_authorization_from_post!` / `#switch_authorization_from_post!`)
  - **Cancel** ends the Auth ceremony and the parent OIDC authorization transaction
    (`transaction.cancel!`, terminal) and returns the browser to the RP.
  - **Switch** ends the Auth ceremony, **keeps the parent transaction** (it holds the RP's request:
    `client_id`, `redirect_uri`, `state`, PKCE, `nonce` — ADR D06) and issues a fresh Admission with
    the target `entry_intent` (`issue_switch_admission!`), then sends the browser to Auth.
  - `pt` is the RP-held return path (saved at RP `/sign`, single use, same-origin path only);
    `rt` is the per-hop Jump return token, consumed by `verify_jump_return_rt!`.
  - Design: `GET /oidc/cancellation` (`show` only): verify cookie browser binding → consume the
    single-use reference → cancel → 303 to RP `redirect_uri?error=access_denied&state=…&iss=…`
    (RFC 6749 §4.1.2.1, RFC 9207). RP `/oidc/callback`: after `state`/`iss` validation,
    `access_denied` → `consume_oidc_pt`, clear OIDC flow state, 303 to the original page (today it
    dead-ends in `render_callback_failure`, plain text 422); other errors → recoverable page linking
    to `/sign` (OBS-1). `GET /oidc/switch` (`show` only): verify binding → consume → keep parent,
    issue switch Admission → 303 via Jump to Auth. No intermediate page, no click, no JavaScript,
    no form POST — removes F1 for both.
  - ADR: amend 2026-09-21 ("GET never consumes") with the exception "a single-use, short-lived
    reference that passes host-only cookie browser-binding verification may be consumed on GET",
    scoped to Cancel and Switch; update AUTH-1/AUTH-2.
- **D-40** (owner, 2026-10-21) **i18n region bundles: root fix required, specified in `two.md`, not
  done now.** Finding: `config/initializers/locale.rb` loads `jp/ja.yml` then `us/ja.yml` (and
  `jp/en.yml`, `us/en.yml`) into the same locale, so for every key present in both regions the `us`
  value wins regardless of `ri` (`docs/architecture/i18n.md`: "merged at load time"). Measured
  2026-10-21: ja 66 and en 36 shared keys differ (ja: 523 jp-only, 160 us-only; en: 421 jp-only,
  479 us-only). Visible symptoms: Passkey sign-in shows registration copy ("パスキーを登録する",
  "信頼できる端末を使ってパスキーを追加し…") and Email sign-in shows "メールでページ登録". Options
  for `two.md`: (ア) jp/us values of one language must be identical, enforced by a test; (イ) real
  per-region translation selection by `ri`. Copy corrections are judged key by key (e.g.
  `email.edit.submit` "Email で登録" is wrong for sign-in in jp too).
- **D-41** (owner, 2026-10-21) **One deadline for the Auth sign-in page.** The time during which
  `https://auth.<realm>/sign/in` is usable and the time during which its actions (Google, Apple,
  Passkey, Email, Secret, Cancel, Switch) are accepted must be **the same single deadline**, from
  one source of truth (the D-36 continuation deadline: min(ceremony expiry, parent expiry)). Today
  the page stays usable while Social refuses after 60 s (F5), an accident the owner wants prevented.
  After the deadline every action yields a deterministic, recoverable restart page linking to the
  RP `/sign` (OBS-1), never a silent bounce; without JavaScript, so the deadline is enforced and
  explained server-side.
- **D-42** (owner, 2026-10-21) **The RP return target will not use `pt`.** Today the RP entry
  (`OidcSsoInitiator`, `OidcRpSignEntry`) accepts an unsigned plain-path `pt`
  (`/sign?ri=jp&pt=/dashboard`), so anyone can craft a link that sends the user to an arbitrary
  same-host path after sign-in (only `RedirectsPathTargetResolver` limits it to internal paths).
  The replacement mechanism is undecided; the owner prefers an established Rails convention if one
  exists, to be discussed later. Context for that discussion: Auth/Base already use a signed `pt`
  (`AuthenticationRedirects#issue_authentication_path_target_token` /
  `#verify_authentication_pt_path`: purpose, salt, flow, surface, session nonce); other candidates
  are server-side storage of the return location (Rails session) or a per-RP allow-list. Related
  facts: root-page sign links carry no return target; `Base::App::AuthorityController#sign_in_url_with_pt`
  deliberately drops it; direct `/sign` defaults to `/`. Also explained: root pages
  (`Base::App::RootsController`, `Warp::App::RootsController`) override `set_region` so a direct
  request is not redirected to add `?ri=`; `ri` allows only `jp`/`us` (`ww` is a host placement,
  not an `ri` value).
- **Decided** (2026-10-21): Passkey sign-in policy is recorded in the updated Accepted
  [Passkey Identifier-First Sign-In ADR](adr/passkey-identifier-first-sign-in.md). Read that ADR
  for the governing contract, scoped supersession and implementation prerequisites; this is no
  longer an open design question. ADR updates are complete; implementation and verification
  remain separate work and are not certified by acceptance.
- **H5 / D-43** (owner, 2026-10-21) **Sign-out moves into this thread** (handoff "Sign-out
  設計・実装の移管依頼": SO-1 … SO-7; method C — no `belongs_to optional: true`, no
  `belongs_to_required_by_default = false`, no Model Concern `included do`/`prepended do`,
  lookup-table statuses, no `default_scope`/persistent `enum`, deletion behavior not changed
  unilaterally). Reconciliation with this thread's decisions (source reading 2026-10-21):
  - The handoff's "R5-switched RP vs R1–R4 shared-DB RP" split no longer exists: no cell activation
    remains (D-35) and every first-party RP behaves as a standard RP with BCL (D-23, D-26 (8)); the
    separated-store logout ADR therefore applies to all first-party RPs and supersedes the
    shared-DB logout ADR for them.
  - **Conflict to record as an ADR amendment**: the 2026-10-16 ADR requires the outbox to be
    persisted in the OP transaction; D-28 (no durable outbox) and D-30 (in-process delivery)
    change that contract.
  - **Two parallel logout records**: `AuthenticationLogoutCurrentSession` writes the legacy
    `Client/Visitor/OperatorSignOutFlow` on every logout, while `Op*LogoutFlow` /
    `Participant` / `Receipt` are written only on the RP-initiated path through `within_commit` →
    `OpLogoutCommitter`. Base local sign-out and identity stops create no `Op*LogoutFlow`, hence
    no BCL (B1/BX-1). Which record is the authority and which is evidence is undecided (SO-3).
  - The 2026-10-16 ADR's residual-access bound is 300 s + 30 s; `AUTH_ACCESS_JWT_TTL` is 5 min but
    `CoreBrowserCredentialContract::ACCESS_TTL` is 10 min — a mismatch to resolve.
  - `app/models/concerns/sign_out_flow.rb` still has `included do` and
    `belongs_to_required_by_default = false` (SO-4/SO-5).
  - Consistent: GET read-only / CSRF POST completion (`/sign/out/completion`), `id_token_hint` is
    a hint not authority (D-33), current-session vs all-sessions are different operations.

## Appendix E — Earlier requirement draft (history; superseded by §2–§5, do not implement from it)

### E.4 Requirements by trust boundary

Format: **ID** — statement. *Source · Status · Tier.* Tier A = correctness of shipped/accepted paths;
B = final QA after A; C = next cycle unless re-scoped (§6 Q-1). Abuse cases that a requirement must
withstand are listed under it; each becomes a refusal test in `three.md`.

#### E.4.1 Base → Auth: admission, browser binding, relays

- **ADM-1** — Each relay step (authorize start, admission continuation, binding confirmation,
  exit continuation) refuses stale, mismatched, cross-browser and replayed references; GET never
  consumes; consumption is a CSRF-protected POST. *H3/ADR 2026-09-21, AUTH-2 · Decided · A.*
- **ADM-2** — Cancel (APP/COM/ORG) and Switch (APP/COM) complete at Base; Base keeps Rails origin
  checking and never treats a null Origin as proof. A browser that genuinely sends a null Origin gets
  a deterministic recoverable page, not a stranded flow. The fix must not place `cancellation_ref`,
  `transaction_ref`, `switch_handoff` or any reference into a Referer sent to another origin.
  *H1 F1 · Proposed · A.* `[AR-1]`
  - Abuse: attacker-initiated cancel/switch of a victim's live flow via a crafted top-level GET →
    refused by the existing browser-binding check (must stay covered).
  - Scope limit: transport only; distributed Cancel/Switch/Late-result semantics stay Pending (D14).
- **ADM-3** — Relay pages that carry no user decision may submit without a click **only if** each
  relay's security is shown not to depend on user activation (link scanners, headless prefetch,
  login CSRF, attacker-driven top-level navigation). Otherwise the visible button stays. No-JS
  fallback required; POST/CSRF/"GET never consumes" unchanged. *H1 F3 · Blocked (Q-4) · B.* `[AR-2]`
- **ADM-4** — A repeated start submission for the same parent and intent yields the same live
  admission, never a second live one. *H1 F4, D-6 · Proposed · A.*
- **ADM-5** — Admission **acceptance** (60 s, `OpaqueAdmissionStore::CODE_TTL`) and ceremony/Flow
  **continuation** are separate deadlines. After redemption, continuation is checked against the
  governing deadline chosen in Q-3, never against the acceptance deadline; single-use of the
  admission and binding/browser checks stay in force. *H1 F5, H3 §9 · Blocked (Q-3) · A.* `[AR-3]`
  - Abuse: a redeemed binding replayed after its ceremony ended → refused.
- **ADM-6** — Admission reuse/renewal on restart follows the Pending decisions only (§5); nothing
  here authorizes reuse after evidence. *H3 · Pending.*

#### E.4.2 Auth: ceremonies and Sign-up Flow (E1)

- **CER-1** — APP `client_sign_up_flows` and COM `visitor_sign_up_flows` carry
  `auth_admission_binding_id` → their surface's binding (same DB). *D-5 · Decided · A.*
- **CER-2** — A Flow is created only under the Binding row lock, after confirming: binding redeemed,
  not retired, surface match, admitted ceremony == the browser's current active ceremony, and
  sign-up-eligible **effective intent** (purpose + `entry_intent` + parent, per ADR R2). Request
  params and Referer never select sign-up. *D-5, ADR · Decided · A.* (Today Social uses
  `params[:entry]`/Referer — Appendix A.2.)
- **CER-3** — The in-progress Flow is **resolved from** the current admitted ceremony → binding →
  its in-progress Flow; the Rails session locator is only a hint that must agree, and disagreement is
  refused. *D-5 · Proposed · A.* `[AR-4]` (This makes Q-E2 a UI question, not a security one.)
  - Abuse: tab 2 redeems Admission B (ceremony cookie rotates); tab 1's Flow from Admission A is
    submitted → refused.
- **CER-4** — ≤ 1 in-progress Flow per Binding in PostgreSQL; predicate equals the state machine's
  in-progress set, enforced by a static guard; every status that can still lead to session issuance
  is in that set. *D-7 · Decided (predicate content Blocked Q-E7) · A.* `[AR-5]`
- **CER-5** — Restart/supersession for **every** entry method (email, telephone, Google, Apple) halts
  the old Flow (HALTED, system-originated) inside the same Binding lock that inserts the replacement;
  an old page cannot affect the replacement; an in-progress Flow left past expiry cannot block the
  Binding beyond the expiry job's bound. *D-7, ADR · Decided · A.* `[AR-6]`
- **CER-6** — Evidence (OTP issuance ≠ OTP verification ≠ Passkey ≠ Social callback) is bound to its
  Flow, ceremony, admission, parent, browser, method and deadline; evidence never moves to another
  Flow. Survival across restart is Pending. *ADR · Decided (binding) / Pending (restart) · A.*
- **CER-7** — The Flow's binding FK never changes after creation; mechanism Blocked (Q-E4). *D-5.*
- **CER-8** — `local_sign_up_flow_ref`, its FK and every CHECK naming it (APP, COM **and ORG**
  ceremony tables) are removed after CER-1..5 hold. *D-5 · Decided · A.* `[AR-7]`
- **CER-9** — NOT NULL after the backfill policy (Q-E5) is executed. *D-5 · Blocked · A.*
- **CER-10** — Zenith/OP partial commits are reported and fail closed; no compensating deletion of a
  durable identity and no compensating credential issuance. *ADR R6, H3 E3 · Decided (report-only
  this cycle) · B.*

#### E.4.3 Auth → Base: result handoff and Root Session

- **RES-1** — OIDC result routes are `/sign/result` on APP/COM/ORG; the old path does not route;
  methods and checks unchanged; forms rendered before deployment with the old path fail closed (no
  compat). *D-4 · Decided · A.*
- **RES-2** — Sign-up → Sign-in → Base Root Session works for Local and OIDC on APP and COM through
  the ordinary issuance boundary (cooldown, session limit, fixation protection); another browser's
  result is refused; concurrent double finalize yields at most one Root Session. *D-1, D-3 ·
  Decided · A.*
- **RES-3** — The OIDC sign-up path, which creates a new Sign-in Flow at handoff
  (`authentication_sequence_gate.rb:410`), binds the Base result to the same principal and the same
  authorization transaction (E2). *H3 E2 · Proposed (audit + test) · A.*
- **RES-4** — Root Session issuance is reachable only through Base finalization; the Auth-side
  `auth_credential_ceremony?` flag is not the sole guard (E4). *H3 E4 · Proposed (audit) · B.*
- **RES-5** — Old Result-retry tests that expect the removed behavior are changed to expect refusal,
  with the reason in the test; no test is deleted to hide a failure (E5). *D-2 · Decided · A.*

#### E.4.4 OP ↔ RP: tokens, refresh, logout

- **RP-1** — RP session cookie and lookup use `public_id` bound to cell, issuer, subject, session,
  generation and revocation; tests use differing numeric `id` and `public_id`. *D-11, AUTH-10 ·
  Decided (appears implemented, verify) · A.*
- **RP-2** — Refresh: atomic rotation, one successor under concurrency, reuse of a **consumed**
  token detected and distinguished from unknown input (unknown input never triggers family
  revocation), bounded lost-response recovery within AUTH-11/12 budgets (changing the 5 s window
  changes the checklist contract and needs a decision), absolute expiry preserved, safe races with
  IdP stop and logout, one contract for all callers. Revocation scope on reuse Blocked (Q-R1).
  *D-10, H4 §6.2 · Decided · A.* `[AR-8]`
- **RP-3** — Raw Refresh Token storage: either (a) stays in the browser cookie as an explicitly
  recorded exception, with `__Host-`, `Secure`, `HttpOnly`, `SameSite` and path scoping verified; or
  (b) moves server-side by a new ADR and migration. *H4 §3.3 vs P-3 · Blocked (Q-1) · A(a)/C(b).*
- **RP-4** — Revocation Endpoint accepts the client's registered authentication method including
  `private_key_jwt` (signature ES384, audience, client binding, JTI replay, realm, endpoint), sharing
  one client-authentication implementation with the Token Endpoint. *H4 §6.5 · Decided · A.* (Today
  only `client_id`/`client_secret` reach `OidcTokenRevoker`.)
- **RP-5** — RP-side logout launch reads no OP database or OP model. *H4 §6.6/§3.1 · Decided · A.*
  (Today `OidcRpLogoutLauncher` reads `AcmeLogoutTransaction`, `Op*Grant`.)
- **RP-6** — BCL delivery: revocation commit and outbox row in one transaction; after-commit trigger;
  sweep from the persistent outbox; lease-expiry recovery; classified retry; observable exhaustion;
  each realm's dispatcher handles only its realm. *D-12, H4 §6.3 · Decided · A.*
- **RP-7** — RP Logout Token handling: ES384, `iss`, `aud` = exact client, `iat` window, `events`,
  no `nonce`, `sid` binding, JTI replay stored in the RP's own realm store; idempotent duplicates;
  success response only after the durable local revoke (AUTH-13). *D-12 · Decided · A.* `[AR-9]`
- **RP-8** — Invariant over every OP authority stop (RP-initiated logout, challenge logout, identity
  stop, token revocation, refresh reuse, revoke-all, other stops): after COMMIT, every required RP is
  notified; a delivery failure never undoes the committed revocation. *H4 §6.4 · Decided · A.*
- **RP-9** — Access tokens already issued remain acceptable at the RP only up to the ADR bound
  (natural expiry + clock skew); this bound is measured, and BCL convergence after recovery is
  verified separately; no finite delivery-time guarantee under indefinite network failure. *H4 §8.4 ·
  Decided · B.*

#### E.4.5 Runtime isolation

- **ISO-1** — RP processes cannot read OP signing keys, other cells' keys or other surfaces' DB
  logins; replay storage per realm in the owning DB; workers/queues per owner; verified with real
  credentials, not `RuntimeRole` switching. *H4 §6.6 vs P-2 · Blocked (Q-1) · C.*

#### E.4.6 Dev-only ORG Bootstrap

- **BOOT-1** — Dev `db:seed` creates one Bootstrap Operator idempotently (no duplicate, no identity
  re-binding, no reactivation of a stopped Bootstrap) bound to an explicitly configured Entra
  `(tid, oid)` pair; an unverifiable identity fails. *D-13 · Decided · A.*
- **BOOT-2** — Bootstrap sign-in uses the ordinary Base issuance boundary (admission, browser
  binding, cooldown, session limit, fixation protection); only the Passkey stage is replaced, and
  nothing records Passkey/MFA/Step-Up. Entry point per Q-5. *D-13 · Blocked (Q-5) · A.* `[AR-10]`
- **BOOT-3** — Bootstrap is unreachable in every deployed environment: routes only when
  `Rails.env.development? || Rails.env.test?`, **and** an independent finalization refusal that does
  not rely on `Rails.env` alone, because how staging is deployed is unverified (P-2). No Flipper/ENV
  can enable it; seeds for it run only in development. *D-13 · Blocked (Q-6) · A.* `[AR-11]`
- **BOOT-4** — The Bootstrap Authentication Context is a distinct non-NULL value; every
  authorization decision is allow-listed for it (only the Bootstrap screen and Sign out), so code that
  only special-cases `standby` cannot grant normal access. A static guard covers every policy entry
  point. *D-13 · Proposed · A.* `[AR-12]` Interacts with AUTH-8 NULL-means-Normal (Q-7).
- **BOOT-5** — Normal ORG Operators still need Entra → Passkey; the normal Entra callback gains no
  Passkey-skip branch. *D-13 · Decided · A.*
- **BOOT-6** — No Bureau/Ownership/Membership creation; `BaseSelectorBootstrapAuthority` not reached
  unconditionally; fail-closed invitations kept. Name collision with the existing `bootstrap_handoff`
  admission purpose (step-up parent) is resolved before naming. *D-13 · Decided · A.*

#### E.4.7 Cross-cutting

- **OBS-1** — Every refusal on these boundaries emits a reason-coded structured event without refs,
  digests, tokens or contact data; recovery pages link only to the surface's configured `/sign`
  entry (never a request-supplied URL). *H1 F2 · Proposed · A.* `[AR-13]`
- **DOC-1** — ADRs, docs, mermaid diagrams, checklists, public contracts and runbooks match code and
  tests; new decisions are new ADRs or explicit amendments; history is not rewritten. Includes
  reconciling AUTH-8/AUTH-14 "credential reissue" wording with D-2. *H4 §9 · Decided · B.* `[AR-14]`
- **DOC-2** — ADRs and docs state D-15: amend or supersede `adr/runtime-secret-isolation-deferred.md`
  (its production direction of per-pod secret injection and "production remains an open defect"),
  update `docs/security/role-secret-isolation.md`, the backlog
  `plans/backlog/2026-10-18-production-runtime-secret-isolation.md`, and every doc that still
  describes per-role bundles; historical evidence and archived plans are not rewritten. *D-15 ·
  Decided · A (docs only).*
- **AUD-1** — R5-A01..A17 each classified against current code with evidence. *H4 · Blocked (Q-2) · B.*
- **E2E-1** — Independent RP E2E per H4 §8 (separate processes, DBs, credentials, real HTTP,
  failure scenarios). In-process transport is not evidence for it. *H4 · Blocked (Q-1) · C.*
- **GATE-1** — Gates 1–4 judged PASS/FAIL/PENDING/UNVERIFIED from current-session evidence only.
  With ISO-1/E2E-1 in Tier C, Gates 1, 2 and 4 cannot PASS this cycle. *H4 · Decided · B.*

### E.5 Pending (the implementer must not decide)

From the E1 ADR: restart after OTP issuance; restart after evidence and old-evidence treatment;
OIDC/Local restart route; admission/ceremony expiry and continuation eligibility (overlaps Q-3); FK
immutability mechanism; legacy backfill; `ON DELETE`; Purger order; retention; D14 distributed
Cancel/Switch/Supersession/Late Result. From H4: refresh reuse revocation scope unless an ADR decides
it. From D-17: treatment of OP signer and worldwide-RP co-location in the `global` pod. Known coupling: `AuthAdmissionBindingPurger` hard-deletes bindings while `RetentionPurgeJob`
purges sign-up flows separately with source holds, so any `ON DELETE` choice needs a purge order.

### E.6 Owner decisions, in unblocking order

| # | Decision | Unblocks | Recommendation |
|---|---|---|---|
| Q-1 | Re-scope to include runtime isolation, server-side refresh and multi-process RP E2E (supersede `runtime-secret-isolation-deferred`, reopen frozen R5 WUs), or keep them Tier C and accept Gates 1/2/4 not PASS | ISO-1, RP-3(b), E2E-1, GATE-1 | Keep Tier C this cycle; choose RP-3(a) with cookie hardening verified |
| Q-2 | Provide the R5-A01..A17 text | AUD-1 | — |
| Q-3 | Governing continuation deadline after redemption (ceremony expiry / parent expiry / new bound) | ADM-5, CER-2, F5 fix | Ceremony session expiry capped by parent transaction expiry |
| Q-5 | Bootstrap entry: A start at Base reusing admission, or B new handoff (ADR) | BOOT-2 | A |
| Q-6 | How is staging deployed (Rails env), and what deployment signal backs BOOT-3's second refusal | BOOT-3 | Fail closed unless an explicit development-only credential is present |
| Q-7 | Bootstrap context vs AUTH-8 "NULL means Normal": fix the NULL meaning now or keep it out of scope | BOOT-4 | Make the context NOT NULL in the same change |
| Q-E7 | Canonical terminal/in-progress sets (`FINALIZED`, `SIGN_IN_HANDOFF_PENDING` have no writers) | CER-4 | Treat them as terminal and add a static guard |
| Q-E5 | Backfill: phased NOT NULL after legacy rows age out, or approved data deletion | CER-9 | Phased |
| Q-E6 | Interim `ON DELETE` for the new FK | CER-1 migration | RESTRICT as interim, explicitly non-final |
| Q-E4 | FK immutability mechanism | CER-7 | Rails `before_update` (binding-model precedent) now; DB mechanism later |
| Q-4 | Allow auto-submit after ADM-3 analysis | ADM-3 | Decide after the analysis |
| Q-R1 | Refresh reuse revocation scope | RP-2 | Check ADRs first |
| Q-E2 | Locator per browser or per Binding (UI only after CER-3) | CER-3 UX | Per Binding |
| Q-E8 | `entry_intent` NULL-as-neutral vs NULL rule | separate ticket | Separate ticket |
| Q-E1 | Approve the WU order in `two.md` | all | — |

### E.7 Adversarial review of this requirement set

Method: for each requirement, ask which invariant fails under replay, races, partial failure or stale
authority; what observation would falsify it; which recovery is irreversible
(`security-and-hardening` skill). Source-level only.

| AR | Finding | Change made |
|---|---|---|
| AR-1 | Fixing F1 by loosening the referrer policy could leak `cancellation_ref`/`switch_handoff` (they are in the URL query) through Referer | ADM-2 forbids reference leakage and fixes only the Origin outcome |
| AR-2 | The relay "Continue" buttons may be an intentional user-activation barrier; auto-submit turns any attacker-induced top-level GET into a consuming POST without interaction | ADM-3 is conditional on proving no relay relies on user activation; Q-4 deferred until then |
| AR-3 | Relaxing the 60 s check for Social could let a redeemed binding authorize later actions after its ceremony ended | ADM-5 separates acceptance vs continuation and keeps single-use and binding checks |
| AR-4 | A per-browser Rails session locator lets a Flow from Admission A continue under Admission B in the same browser | CER-3 resolves the Flow from ceremony → binding; locator only a hint |
| AR-5 | A status that can still lead to session issuance but sits outside the in-progress predicate (e.g. a future writer of `SIGN_IN_HANDOFF_PENDING`) would allow a second Flow and a second Root Session | CER-4 requires the predicate to cover every session-capable status, with a static guard |
| AR-6 | The new UNIQUE can lock a user out if an expired in-progress Flow is never transitioned; Social paths that skip supersession would hit it | CER-5 requires supersede-in-lock for all methods and a bounded lockout |
| AR-7 | `local_sign_up_flow_ref` also exists in ORG ceremony CHECKs although E1 scope is APP/COM; partial removal leaves a dangling constraint | CER-8 names ORG explicitly |
| AR-8 | Reuse detection that revokes on any unknown token lets an attacker revoke a victim's family with garbage (DoS); extending the 5 s window silently changes AUTH-11 | RP-2 limits reuse to consumed tokens and ties window changes to the checklist |
| AR-9 | BCL requirements covered delivery but not Logout Token validation and replay at the RP | RP-7 added |
| AR-10 | A separate Bootstrap path could bypass cooldown, session limits and fixation protection | BOOT-2 requires the ordinary issuance boundary |
| AR-11 | `Rails.env` routing alone fails if staging runs in a development env (unverified, P-2); dev seeds would also run there | BOOT-3 requires an env-independent second refusal; Q-6 |
| AR-12 | Authorization that only special-cases `standby` would treat a new Bootstrap context as normal; AUTH-8 maps NULL to Normal, so a missing value could escalate | BOOT-4 allow-lists the context, NOT NULL, static guard; Q-7 |
| AR-13 | A recovery link built from request data becomes an open redirect | OBS-1 limits links to configured entries |
| AR-14 | AUTH-8/AUTH-14 still describe credential reissue; readers could reintroduce a D-2 path | DOC-1 reconciles the checklist |
| AR-15 | The requirement set cannot make H4's Gates PASS while P-2/P-4 hold; claiming otherwise would be unverifiable | GATE-1 states it; Q-1 is first |
| AR-16 | Overlaps merged: F5 ↔ E1 deadlines (ADM-5), F1 ↔ D14 (ADM-2 transport-only), Bootstrap ↔ relay fixes (BOOT-2 depends on ADM-2/ADM-3 when Q-5 = A), revoke paths ↔ BCL (RP-8 over RP-6) | Single requirements, cross-referenced |

Remaining unknowns that could falsify requirements: the F1 root cause (headers not observed); whether
`CODE_TTL` is the only cause of F5; whether APP/ORG revocation controllers match COM; the location of
the 5 s receipt in code.

## Appendix B — BCL deep dive (source reading 2026-10-21, not executed)

Files: `app/operations/op_logout_committer.rb`, `app/jobs/op_outbox_dispatch_job.rb`,
`app/adapters/oidc_backchannel_logout_client.rb`, `app/operations/op_logout_token_issuer.rb`,
`app/controllers/concerns/rp_backchannel_logout_endpoint.rb`, `OidcOpLogoutTokenVerifier`,
`app/operations/rp_cell_session_revoker.rb`, `app/operations/rp_session_revoker.rb`,
`app/operations/oidc_token_revoker.rb`, `app/operations/oidc_refresh_token_issuer.rb`,
`app/operations/op_identity_event_invalidator.rb`.

Already sound: Logout Token claims and `typ`; RP verifier (ES384, typ, exact iss/aud, iat/exp
leeway 30 s, max lifetime 300 s, no nonce, sid, jti, event); RP revoke is idempotent through the
per-sid `OpSessionBinding` tombstone (a retry with a fresh `jti` revokes nothing new; a logout before
the callback leaves a tombstone so a late callback cannot enroll — AUTH-13); outbox lease with
`FOR UPDATE SKIP LOCKED`; refresh reuse already revokes only the grant (consistent with D-25).

| ID | Problem that remains or appears after fixing B1–B7 | Consequence | Direction |
|---|---|---|---|
| BX-1 | OP authority is ended by ~8 independent writers (`OpLogoutCommitter`, `RpSessionRevoker` scopes rp_session/browser_session/identity, `AuthenticationLogoutCurrentSession`, `OidcRefreshTokenIssuer#handle_refresh_token_reuse`, `CredentialSecurityTransition` ×2, `SignRiskEnforcer`, `OidcTokenExchangeCoordinator:827`, `OidcRpLogoutLauncher:490`, `Tech::Org::Oidc::CallbacksController`, enforcement `sessions_revoked_at`); only one writes outbox rows | Fixing B1 per call site will drift again | One OP stop primitive that revokes and writes participant + outbox rows in the same transaction; static guard that no other code revokes OP roots/grants |
| BX-2 | Participant/outbox rows hang off `Op*LogoutFlow`, which requires a browser binding digest, idempotency key and browser receipt | Non-browser stops (identity stop, revocation, reuse, risk) have no valid parent | A stop-event parent with a cause from a status/reference table; browser-only facts in their own table (no NULL-with-meaning) |
| BX-3 | `OidcClientStoresStaticClientStore.backchannel_logout_uri` raises `KeyError` for a client with no endpoint, inside the logout transaction | One client without BCL makes the whole logout fail | "No BCL registered" is an explicit client property; such a grant gets no participant, and that is recorded |
| BX-4 | After B3, only 200/400 are classified; 403 (WAF/Cloudflare challenge), 404/405/410 (misconfiguration), 413, 429 are not | A WAF block could be treated as permanent and drop the logout, or retried forever | Explicit table: 200 done; 400 permanent; 429/5xx/timeout/connect transient; 401/403 transient + alert; 404/405/410 permanent misconfiguration + alert |
| BX-5 | OP→RP delivery goes out to the RP's public HTTPS URL; with one Puma it loops back through Cloudflare/WAF and bot protection | Deliveries may be challenged or rate-limited | WAF rule for the BCL path and server identity; still verified by the token signature only |
| BX-6 | RP endpoint builds a new `OidcOpJwksClient` per request and hard-codes `#{issuer}/.well-known/jwks.json` | Every BCL refetches JWKS over HTTP (self-call), amplified by mass stops; bypasses Discovery (D-23) | Share the cached per-issuer client via Discovery `jwks_uri` |
| BX-7 | Once BX-6 caches keys, an unknown `kid` after the bounded refetch makes the verifier fail → **400 → permanent** under B3 | A key rotation race silently loses a logout | Key-unavailable and JWKS fetch failure map to 503 (transient), never 400; 400 only for a token that is verifiably invalid |
| BX-8 | Retries mint a fresh `jti` each attempt | `jti` replay protection does not dedupe retries; correctness relies on the sid tombstone (present) | Keep sid-idempotency as the contract; receipts per `jti` are an audit trail, purge by `exp` |
| BX-9 | Outbox state uses NULL with meaning (`completed_at` NULL = pending, `lease_expires_at` NULL = unleased); B4 adds an "exhausted" state | Conflicts with the repository NULL rule if extended the same way | New/changed states through a status reference table; existing columns noted for owner decision |
| BX-10 | Retry stop "after the RP session's maximum lifetime" needs a per-participant deadline | Without it retries never end | Deadline = grant absolute expiry + max Access JWT lifetime + clock skew, stored on the participant |
| BX-11 | After a failed/late BCL an RP still accepts its Access JWT until `exp` (RP-9) | Residual window | Measure and document the Access JWT lifetime bound; not fixable by BCL |
| BX-12 | RP-initiated logout at `OidcRpLogoutLauncher:490` revokes only that RP session (RP logout amendment 2026-09-20), while the shared-DB ADR Decision 5 says "no single-service sign-out" | Contradictory ADRs on what RP sign-out ends | Decide in #8 |
| BX-13 | Refresh reuse BCL lets whoever replays a stolen token end the victim's RP session | Intended theft response; a nuisance-DoS vector only with a stolen token | Accept and document |
| BX-14 | Completed outbox / participant / receipt retention not checked | Growth | Verify purge jobs in two.md |

## Appendix A — Observations behind the requirements (not executed)

### A.1 Dev log (H1)

| ID | Observation | Evidence |
|---|---|---|
| F1 | Cancel/Switch → Base exit continuation POST 422 null Origin (APP cancel+switch, COM switch) | exit page headers via `apply_base_browser_continuation_headers!` (`base_admission_browser_binding.rb:45`, `oidc_authorization_result_post.rb:15`); `config/application.rb:178`; the binding confirmation POST with the same headers succeeded |
| F2 | 400s without reason event | APP/COM/ORG |
| F3 | Five relay clicks before the sign-in form | all surfaces |
| F4 | Double start submit (0.3 s) | COM |
| F5 | Social `intent_invalid` | `auth_ceremony_context.rb:30` requires `!binding.expired?`; binding expiry ≤ now + 60 s |
| F6 | COM 406 `allow_browser` after earlier 200 | **Closed, ignore** (owner, 2026-10-21): a 406 seen later was `security.browser_block.blocked` for host `www.umaxica.dev`, browser "Safari 13.0.3" — a bot, not the owner's browser; the dev log interleaves every host |

### A.2 E1 current state

| Item | Status | Evidence |
|---|---|---|
| Sign In First handoff | Implemented | `sign_up_sequence_controller_support.rb:194,595` |
| `/sign/result` | Not implemented | `config/routes/auth.rb:61,302,480` |
| Flow FK, in-progress UNIQUE | Not implemented | `*_sign_up_flows` structure |
| `local_sign_up_flow_ref` writer | None | `AuthCeremonyAdmission#rotate_auth_ceremony_session!`; test asserts nil (`base_auth_admission_coordinator_test.rb:131`) |
| Flow authority | Rails session locator | `SignUpCycleLocator#current`; lazy `current \|\| issue_sign_up_flow!` |
| Live admission per parent | Implemented | `idx_client_admission_bindings_live_*`, parent lock, `create_or_reuse_binding!` |
| Live ceremony per parent | OIDC only | `idx_auth_ceremony_sessions_on_live_tx_ref` |
| Supersede | Email/telephone only | `SignUpFlowEntry`; Social creates at `app_social_ceremony_entry.rb:97`, `omniauth_callbacks_controller.rb:311,470` |
| Effective intent | Social uses params/Referer | `AppSocialCeremonyEntry#social_auth_entry` |
| Retry in binding creation | PLAUSIBLE defect | `create_or_reuse_binding!` `rescue RecordNotUnique; retry` without savepoint |
| Cross-DB order | E3 | finalize holds OP lock while writing Zenith; email entry writes Zenith first; `cleanup_pending_signup!` destroys unverified Zenith Client |

Structure: local sign-up admission parent is a Sign-in Flow (`parent_purpose` CHECK); OIDC parent is
the authorization transaction; APP/COM sign-up schemas identical except names; COM has no Social and
no status 36; `entry_intent` NULL = neutral.

### A.3 OP/RP spot checks

| Item | Observation | Evidence |
|---|---|---|
| `public_id` | Appears resolved | `rp_cell_local_session.rb:74`, `rp_request_authenticator.rb:70`, `browser_rp_authentication.rb:612` |
| RP → OP dependency | Present | `oidc_rp_logout_launcher.rb:417,471-479`, included by `core/{app,com,org}/sign/outs_controller.rb`, `palm/app/sign/outs_controller.rb` |
| Outbox schedule | Dispatch every minute; identity event sweep every 5 min | `config/recurring.yml:139-149,287-295` |
| Revocation auth | `client_id`/`client_secret` only | `base/com/oauth/revocations_controller.rb:30-37` |
| Logout receipt TTL | 10 min | `op_logout_committer.rb:38` |
| Independent RP E2E | Absent | `test/support/in_process_op_transport.rb` |
