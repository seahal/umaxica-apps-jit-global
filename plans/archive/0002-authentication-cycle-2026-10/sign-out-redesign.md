# ten.md — Sign-out redesign: decisions, definition and acceptance (2026-10-26)

> Archived 2026-10-27 from the working file `ten.md` (cycle archive 0002; frozen, not maintained).

Working document (gitignored). Single current text for the sign-out redesign; it absorbs the Phase 1
audit, the owner's decisions of 2026-10-26 and Codex's critical review (CR-1 … CR-6) of the same
day. History of the decisions: `one.md` D-181 … D-192. `nine.md` is not used.

- Audit and review base: `aeb09ca9fb97ef1ca24c0195b2fa1d28d21245df`, dirty worktree. No test was run
  for the audit or the review; test references mean source reading.
- Labels: **[Decided]** owner decision; **[Proposal]** awaiting the owner; **[Fact]** read in code or
  spec; **[Unverified]** needs a test.
- Codex units: `tmp/sign-out-common.md`, `tmp/sign-out-so1-…` … `tmp/sign-out-so5-…`, aligned with
  this text on 2026-10-26.

## 1. Decisions

| # | Decision | Source |
|---|---|---|
| S-1 | RP → OP → RP by OIDC RP-Initiated Logout 1.0; the OP authority stop is the truth; BCL to every participating RP | owner prompt; D-182 |
| S-2 | Normal sign-out ends the browser's current OP session only (§3.1); other devices, principals and realms untouched; incident-wide revocation is a separate operation | D-182; D-33 (1); D-173 |
| S-3 | APP / COM / ORG never propagate to each other | D-182 |
| S-4 | Forward-only: no rollback of a committed stop, no compensation, no cascade beyond §3.1, no guessed target; nothing unconfirmed is reported as signed out; no new "indeterminate" DB state | D-182; owner rulings 4, 5 |
| S-5 | The RP clears its own cookies and session **before** redirecting; the return to the RP changes nothing (D-33 (2)) | D-182 |
| S-6 | The RP discards its own tokens; it never writes OP authority and does not call the revocation endpoint during sign-out. Cancel at the OP leaves that RP's grant alive until expiry (backlog `docs/backlog/2026-10-26-rp-grant-alive-after-cancelled-op-logout.md`) | D-188 (replaces D-186, D-5 (a)) |
| S-7 | The OP stops the browser's current OP session; `id_token_hint` must identify a grant of it. Verified hint with no OP session, or not matching → 403 plain "This action is not allowed." / 「禁止された振る舞いです」, no state change, no redirect | D-184 |
| S-8 | Completion: the originating RP's `GET /sign/out/completion`, shown once (reload 404). Without a usable redirect, the OP's own signed-out page, shown once | D-182; D-191 |
| S-9 | Removed: `AcmeLogoutTransaction` machinery; `/sign/bye` and the browser receipt; `POST /sign/out/purge`; the launcher's direct OP grant stop | D-185; D-189; D-188 |
| S-10 | BCL: HTTP 204 is an acknowledgement; discovery advertises `backchannel_logout_supported` and `backchannel_logout_session_supported`; the ID Token `sid` equals the Logout Token `sid`, a missing `sid` raises | D-183 (204); D-190 |
| S-11 | **BCL timing — [Decided] P-A, replaces the in-request attempt of D-183:** no delivery from the request; participants committed with the stop and dispatched by `OpOutboxDispatchJob` right after commit (today's behavior). The bounded in-request attempt returns with WU-18, when first-party receivers have an effect, under the conditions of §6 | D-193; CR-1, CR-2; R-8 |
| S-12 | Auth `/sign/out` stays as an entry (clears Auth ceremony state, redirects to the Base sign-out) | D-192 |
| S-13 | All twelve first-party RPs stay on the OP-chain path this cycle; WU-18c … e wait for the owner's Q18 judgement after this implementation | D-181 (held) |
| S-14 | Migrations for the removed tables approved; irreversible drops allowed (not deployed; D-159) | owner, 2026-10-26 |
| S-15 | No automated browser E2E; the owner checks the browser flow by hand (§5) | D-114; R-10 |
| S-16 | Shared Sign-in / Sign-up code unchanged, except the ID Token `sid` fail-fast (S-10) | owner ruling 2; D-190 |

## 2. Findings (audit, still valid)

- **F-1 [Fact] Production runs the OP-chain path.** `RuntimeRole` is `shared` everywhere; RP request
  authentication reads the OP grant → root → device session chain on every request, so an OP stop
  ends every first-party RP on its next request (zero residual window). The standard RP store
  (`rp_*`, `RpCellSessionRevoker`, tombstones) runs in no process; BCL to first-party RPs is
  acknowledged but closes nothing they read. External RPs and WU-18 are what BCL is for.
- **F-2 [Fact]** The code already follows S-5: the launcher clears the RP before the 303; the return
  destroys nothing, so an old return cannot end a newer login.
- **F-3 [Fact]** On the shared path the launcher stops the RP's OP grant itself (`RpSessionRevoker`,
  cause `token_revocation`) — removed by S-6.
- **F-5 [Unverified, Critical]** Visa stores the hint's `sid` (a **grant** `public_id`, ≤ 21 chars)
  and later looks it up as a root / device-session `public_id` or a root `oidc_sid` (UUID only). None
  matches, so `AuthenticationLogoutCurrentSession` stops nothing, returns true, and Visa redirects as
  success. The registered-RP matrix test returns to the RP without confirming at Visa, so it does
  not cover this. Proven by a Red test first (A14-5a).
- **F-6 [Fact]** `CommitOutcomeUnknown` is not rescued: 500 after Visa's `ensure` has already
  cleared cookies; the indeterminate renderers have no caller.
- **F-7 [Fact]** Verified hint without OP session → plain 400 `login_required`; replaced by S-7.
- **F-8 [Fact] Conformance gaps:** (a) only 200 acknowledged (S-10); (b) no BCL discovery metadata
  (S-10); (c) end-session compares `sub` only (closed by S-7); (d) random `sid` fallback in
  `SecurityJwtOidcIdTokenCodec` (S-10); (e) Logout Token conforms (`sid`, `typ logout+jwt`, fresh
  `jti`, no `nonce`); (f) retries until the BX-10 deadline — accepted deviation from BCL §2.5.
- **F-9 [Fact] Dead code:** `AcmeLogoutTransaction*` (readers only; Auth `logout_challenge`
  continuation hands off to a Visa that answers 400); `/sign/bye` + `OpLogoutReceiptSession` +
  `*AuthorityStopBrowserLogout` (nothing visits it on the RP path); `POST /sign/out/purge` (no
  caller). Stop records, targets and participants remain the audit trail.
- **F-10 [Fact] Visa error rendering:** `render_oidc_end_session_error` and
  `render_oidc_end_session_failure` render the signed-out/completion page for most errors (bad hint,
  stale confirmation) — a refusal shown as a sign-out.
- **F-11 [Fact] Durable checklist out of date:** `docs/checklists/sign-out.md` SIGNOUT-2 (RP revokes
  its grant), SIGNOUT-3 (hint `sid` declined; missing session → `login_required`), SIGNOUT-7 (wording
  of dispatch) and SIGNOUT-8 (retry wording) disagree with §3.
- **F-12 [Fact] DNS without timeout:** `ConnectionAdapterPort` resolves with `Addrinfo.getaddrinfo`
  without a timeout; Faraday timeouts do not cover it. Affects the job today; blocks any in-request
  delivery deadline (§6).

## 3. Definition

Applies to APP, COM and ORG separately; the realm is chosen by host.

### 3.1 Terms

- **OP session** = the browser's Visa device session. **Stopping it** = the existing
  `AuthenticationLogoutCurrentSession` behavior: every root token row under that device session (the
  rotation lineage) is stopped, one stop record per root row (`OpAuthorityStopCommitter.stop_root`,
  cause `rp_initiated_logout`, scope `root`), every grant under those roots is stopped, and the device
  session is revoked. Other device sessions are untouched; the principal epoch does not move. (CR-4:
  the service is used unchanged, with the cascade on; this is the intended scope.)
- **Grant of the OP session** = a grant found by realm, `public_id = hint sid` and
  `oidc_client_id = client_id` whose root belongs to the browser's current device session.

### 3.2 Path

1. **RP `POST /sign/out`** (CSRF). Reads the ID Token for its grant (the hint), deletes its own
   cookies, resets its session, stores the one-time completion notice, answers 303 to Visa
   `/oidc/logout` with `id_token_hint`, `client_id`, the registered `post_logout_redirect_uri` and
   `state`. No OP write, no OP call (S-6). A cell RP's write to its own local store stays.
2. **Visa `GET`/`POST /oidc/logout`** — never changes authority:

   | Input | Response |
   |---|---|
   | `logout_challenge` | 400 (kept) |
   | Hint with bad signature or foreign issuer; `client_id` not its audience | Error response (400 / plain), never a signed-out page (F-10) |
   | Expired but otherwise valid hint | Accepted |
   | `post_logout_redirect_uri` not registered for the client and realm | Refused; never redirected to |
   | Verified hint, no OP session | **403** (S-7) |
   | Verified hint, `sid` not a grant of the OP session | **403** (S-7) |
   | No hint, no OP session | **200 "already signed out" page** (no confirmation, no state change, no redirect; Keycloak shows the same kind of page) |
   | Otherwise (OP session present) | Pending request stored in the Visa session with the device session id and, with a hint, the resolved grant; confirmation shown |

3. **Visa confirmation `POST /oidc/logout/confirmation`** (CSRF):

   | State at the POST | Response |
   |---|---|
   | No pending request | Stale-request refusal (422 / plain), never a signed-out page (F-10) |
   | Stored device session is not the browser's current one | 403 |
   | Stored device session already revoked (double submit, second tab, retry after an unknown outcome) | "already signed out" page; no new stop; Visa cookies and session cleared |
   | Stop raises before commit (rolled back) | 5xx "not signed out, try again"; Visa cookies, session and pending request kept; no redirect |
   | `CommitOutcomeUnknown` (re-read could not confirm) | 503 result-unknown page (existing indeterminate renderer); cookies and pending request kept; no redirect. A retry re-reads (row above or below); it never targets anything else |
   | Stop committed (or confirmed by the re-read) | **Committed path** (3.3) |

### 3.3 Committed path (CR-3)

Once the stop is known committed, the outcome is fixed as "signed out at the OP"; nothing after it
reclassifies it.

1. Clear Visa cookies and reset the Visa session.
2. Store the one-time notice for the OP signed-out page (only when step 3 goes there).
3. 303: with a verified hint and registered URI, via Jump to `post_logout_redirect_uri?state=`;
   otherwise to the OP signed-out page.
4. Any exception in steps 2–3 is logged (no tokens, cookies, `state` or raw session ids) and answered
   with the OP signed-out page rendered directly (200, no notice needed). Never an error,
   result-unknown or retry page.
5. Delivery is not part of the request (S-11). The after-commit enqueue may fail; the recurring sweep
   re-enqueues (A15-2). Participants stay durable.

### 3.4 Pages

- **RP completion `GET /sign/out/completion`:** unchanged — 404 while any session is active; `state`
  compared; notice consumed; shown once; reload 404; writes nothing.
- **OP signed-out page (new, replaces `/sign/bye`):** `GET /oidc/logout/completion` per realm (or the
  path the routing style requires); shown once from the one-time notice; reload 404; writes nothing.
- **OP "already signed out" page:** 200, no state; distinct text from the signed-out page.
- All texts in en and ja; `DESIGN.md`; no flash.

### 3.5 Back-Channel Logout (P-A)

- Unchanged: participants written in the stop transaction, `OpOutboxDispatchJob` enqueued after
  commit, sweep every minute, retries and permanent classes per BX-4 / BX-10, receivers idempotent
  per `jti` receipt and `sid` tombstone.
- Changed: 200 **and 204** acknowledge; discovery flags (S-10); ID Token `sid` fail-fast (S-10).
- Not done this cycle (P-A): pre-leased participants, in-request sending.

### 3.6 Removed

- `AcmeLogoutTransaction`, `AcmeLogoutTransactionable`, `AcmeLogoutTransactionCoordinator`, their
  table(s), the Auth `logout_challenge` branches (APP/COM/ORG), the references in
  `SignOutCancellation` and `SignOutNotice`, their tests.
- `/sign/bye` (`SignByesController` ×3, `BaseSignBye`), `OpLogoutReceiptSession`, the receipt issuance
  and `browser_binding` plumbing used only by it, `*AuthorityStopBrowserLogout` and the
  `*_authority_stop_browser_logouts` tables.
- `RpCookiePurgeEndpoint` and its routes.
- The launcher's `RpSessionRevoker` call; the class if nothing else uses it.
- Kept: stop records, targets, participants, outbox job and sweep, receivers, Auth `/sign/out`.

### 3.7 Durable documents updated with the code (CR-6)

- `docs/checklists/sign-out.md`: keep the IDs; rewrite SIGNOUT-2 (S-6), SIGNOUT-3 (§3.2 step 2,
  S-7), SIGNOUT-6 (cancel leaves this RP's grant alive), SIGNOUT-7 (dispatch after commit, 204),
  SIGNOUT-8 (§3.2 step 3 and §3.3); reconcile `docs/security/logout-sequence.md` and
  `docs/security/logout-session-management.md`.
- `docs/mermaid/` diagrams and the transition inventory where the logout axes change.
- `three.md` acceptance (§4); `test/integration/oidc_rp_logout_registered_rp_matrix_test.rb`
  expectation "grant revoked before Visa confirmation" is superseded by A14-6/A14-7 and must be
  changed, not counted as a pass.

## 4. Acceptance (replaces `three.md` A14-*, A22-1; SO-5 transfers it)

| ID | Case | Expected |
|---|---|---|
| A14-1 | GET and POST `/oidc/logout` | Confirmation or refusal only; no authority change |
| A14-2 | Confirmation | Separate CSRF-protected POST; bad or missing token refused, nothing stopped |
| A14-3 | Hint expired / foreign issuer / `client_id` not audience / bad signature | Accepted / refused / refused / refused; no refusal renders a signed-out page |
| A14-4 | Unregistered `post_logout_redirect_uri` | Refused; never redirected to |
| A14-5a | Two first-party RPs in one browser, sign out at one, hint `sid` = grant id (F-5); the device session holds two root rows (after a rotation) | After confirmation: both root rows stopped (one stop record each), every grant under them stopped, device session revoked; both RPs refuse the browser next request; another device of the same person untouched; 303 to the RP completion with `state` |
| A14-5b | Same; receiver answers 200 or 204 | Job marks the participants done |
| A14-5c | Same; receiver fails | Job retries per BX-4; OP authority stays stopped; the redirect did not wait |
| A14-6 | Cancel or no answer at the OP | Initiating RP signed out; OP session, other RPs and that RP's grant still valid (S-6 gap, asserted) |
| A14-7 | RP sign-out side effects | No OP authority row, no OP endpoint call; the RP completion writes nothing |
| A14-8 | Verified hint + no OP session; hint `sid` of another device's grant (same person); hint `sid` of an unrelated grant | 403, plain text en/ja; nothing stored, stopped or redirected |
| A14-9a | No hint, OP session present | Confirmation → stop → OP signed-out page; once; reload 404 |
| A14-9b | No hint, no OP session | "already signed out" page; no confirmation; no state change |
| A14-9c | Hint without registered URI | Refused per A14-4 (never a redirect) |
| A14-10a | Stop raises before commit | 5xx; Visa cookies, session and pending request kept; root live; no redirect |
| A14-10b | `CommitOutcomeUnknown` | 503 result-unknown; no redirect; retry ends on "already signed out" if the stop committed, or stops the same session if it did not |
| A14-10c | Stop committed, then (a) notice storage or redirect construction raises, or (b) the after-commit enqueue fails | (a) OP signed-out page rendered (§3.3 step 4); (b) the normal 303 to `post_logout_redirect_uri` (§3.3 steps 3 and 5; delivery is outside the request, RP-Initiated Logout redirect is not conditioned on back-channel delivery); both: Visa cookies cleared, stop and participants durable, the sweep later enqueues delivery (owner, 2026-10-27) |
| A14-11 | Two confirmation POSTs for one pending request | One stop; the second answers "already signed out" |
| A14-12 | Stored device session is no longer the browser's current one | 403; nothing stopped |
| A14-13 | Discovery and `sid` | Both BCL flags true; ID Token `sid` = grant `public_id` = Logout Token `sid`; encoding without `sid` raises |
| A14-14 | Removals | `/sign/bye`, `/sign/out/purge`, Auth `logout_challenge` not routed or refused; tables absent from the three `structure.sql`; no reference to removed constants (command check in evidence) |
| A14-15 | Realm isolation | APP sign-out leaves COM and ORG sessions; a COM hint at the APP OP refused |
| A14-16 | RP completion | Once; reload 404; 404 while a session is active; `state` mismatch refused |
| A14-17 | Refresh or rotation racing the stop | Refresh after COMMIT refused; a rotation committed first is stopped with the device session (A14-5a lineage) |
| A14-18 | Old sign-out's return after a new sign-in at that RP | 404; nothing destroyed |
| A15-3 | Receiver answers 200 / 204 / 400 / 5xx / timeout | done / done / permanent / retry / retry |
| A22-1 | — | Retired (models removed) |
| A44-6, A44-10 | As in `three.md` | Count for sign-out acceptance (D-187) |

**G-16 (restated):** Sign-in / Sign-up intact; realms separate; the RP writes no OP authority and
clears only itself; `id_token_hint` identifies, the current OP session is the target; GET changes no
authority; POSTs verify CSRF; delivery never decides the result; nothing unconfirmed is reported as
signed out and nothing committed is reported as failed; an old return never breaks a new login;
completion pages are read-only GETs shown once. Covered by A14-*, A15-3, A44-6, A44-10.
**G-19, G-20:** unchanged; the browser receipt is no longer part of a stop.

## 5. Owner's manual browser check

**Status 2026-10-27: deferred to the next cycle (owner).** One APP sign-out was observed
(`www.umaxica.app` → Visa confirm → Jump → `/sign/out/completion`, 200). Back-channel delivery cannot
be checked in development (`invalid_endpoint`; `docs/backlog/2026-10-27-backchannel-logout-unverifiable-in-development.md`).
The checks below were not run.

Per realm, two RPs signed in in one browser:

1. Sign out at RP 1 → confirm at Visa → RP 1 completion once; reload 404; RP 2 asks to sign in.
2. Sign out at RP 1 → cancel at Visa → RP 1 signed out; RP 2 still signed in.
3. After step 1, Back to the old confirmation and confirm again → "already signed out"; nothing else.
4. Open Visa `/oidc/logout` directly while signed in → confirm → OP signed-out page once.
5. Same while not signed in → "already signed out".
6. Signed in on APP and COM, sign out on APP → COM still signed in.

## 6. Open items and conditions

- **In-request delivery (deferred to WU-18 by P-A / D-193).** Before it returns it needs at least:
  a process-wide bounded executor with bounded admission and queue, and refusal to the job when full
  (CR-1); a DNS timeout (F-12); a deadline covering token preparation, admission and recording, with
  recording left to the job when the budget is spent (CR-2); participants pre-leased so the job cannot
  send first (R-2); tests for repeated timeouts, saturation and recovery; an explicit margin.
- **F-12** DNS timeout for the job → backlog candidate (pre-existing).
- **Rate limits (R-6, pending):** receivers 60/min and revocation 20/min per `remote_ip`.
- **Q18-1 … Q18-4** (WU-18): `docs/backlog/2026-10-25-op-chain-runtime-role-removal.md`
  "Update (2026-10-26)"; judged after this implementation.
- **Cancel gap (S-6):** backlog `2026-10-26-rp-grant-alive-after-cancelled-op-logout.md`.
- **Database consistency:** the 39 findings on the stop tables stay with the owner; those on the
  removed browser-logout tables disappear with them.
- **Conformance suite** expectations for BCL timing: not found [Unverified].

## 7. Codex review record (CR-1 … CR-6, 2026-10-26)

| # | Finding | Resolution here |
|---|---|---|
| CR-1 [P1] | Abandoned calls are not bounded across requests (DNS without timeout) | P-A (decided): no in-request delivery this cycle; conditions in §6 |
| CR-2 [P1] | The 3 s deadline excluded signing, checkout and recording | P-A (decided); conditions in §6 |
| CR-3 [P1] | No defined path for failures after a confirmed commit | §3.3 committed path; A14-10c |
| CR-4 [P2] | `token:` with the cascade stops every root row of the device session | §3.1 defines the OP session as the device session and its lineage; A14-5a two root rows |
| CR-5 [P2] | No-hint/no-session contradicted "never success without a stop" | §3.2 "already signed out" page; A14-9a/b, A14-11 |
| CR-6 [P2] | Durable checklist and existing test expectations not in the handoff | §3.7; F-11 |
