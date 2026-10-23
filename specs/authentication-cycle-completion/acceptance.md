# Authentication cycle acceptance reconciliation

Status: implementing. Every row is unverified until a current requirement-level result is linked.
The full source case, including expected behavior and gates, remains authoritative; this index does
not shorten acceptance or discard boundary cases. See `spec.md` and `tasks.md`.

Source snapshots at intake (SHA-256):

- `one.md`: `1c9411cf16afcabc4a568a1a62185eaafbf59e74bc1e0d7b1bb4226b38434406`.
- `two.md`: `a2a6f32f369bcc80205e0fa75234f5b6a4bb58b4420d23ed05b37283472b1fd9`.
- `three.md`: `028042a8cabf8cd3e4e92369deb1b71388ad86e8016dd37f06ad8700ea543915`.

| Case / gate | Source condition | Current evidence / disposition |
|---|---|---|
| G-8 | At every hop that takes a reference: a foreign browser can never **advance** a flow — no confirm, redeem, result acceptance, Root Session, callback success, Switch or Cancel — and ends no Flow, Candidate or ceremony other than through D-51. **Exception (D-51, accepted residual risk):** a stolen live reference may be attached first by a foreign browser before the victim (denial of the victim's attempt only); the test asserts the attacker then cannot confirm, redeem, be accepted or get a Root Session, and that a repeat attach after the first is refused (AUTH-19, D-73). Corrected 2026-10-22 per seven.md #4 | Unverified |
| G-9 | 29:59 / 30:00 / 30:01 for every consumer, Switch near the deadline (inherits it, D-74), lock wait spanning the deadline, Finalization whose deadline check under the lock runs at 29:59 → registered (kept even if the principal commit lands after 30:00, D-131) with the Sign-in handoff judged on its own, and whose check runs at 30:00 / 30:01 → nothing registered, fail closed (D-105 read by D-131), Auth-side in time but OP-side receipt late; after the curfew the owner's own attempt returns to the RP as `access_denied`, a foreign request ends nothing (D-160 (3)). The RP `state` deadline is a separate check on the Rails clock (D-160 (1)), accepted in A43-6 / A43-20, not here | Unverified |
| G-10 | R23-INV-1 … 4: resend adds no expiry, authority, single-use reference or consumption; no re-minting of a consumed next reference; lost response after COMMIT yields nothing new | Unverified |
| G-15 | `prompt=none` → `login_required` and one new interactive transaction (no loop); `access_denied` Cancel return after `state`/`iss`; revocation with the registered method; RP-Initiated Logout GET/POST; expired `id_token_hint` accepted for logout only, never for authentication | Unverified |
| G-16 | For every unit touching logout (WU-02 V9, WU-14, WU-15, WU-16, WU-22): Sign-up/Sign-in intact; APP/COM/ORG separate; RP never takes OP authority; `id_token_hint` only a hint; unauthenticated viewing ≠ revocation; GET changes no authority; POST verifies CSRF; BCL outcome ≠ OP sign-out outcome; an old logout's after-work never breaks a new login; completion `GET /sign/out/completion` read-only and `POST` CSRF-protected | Unverified |
| G-17 | For WU-29 and every unit touching a Sign-in path entry or POST: unset flag and flag-store error refuse; no Sign-in path entry, POST or callback reaches evidence, registration or root login while BLOCKED; Re-verification path, Refresh, Sign Out and `prompt=none` unaffected | Unverified |
| G-18 | For every Design D continuation endpoint: Fetch Metadata required, HEAD refused, binding checked before consumption, CAS, same-browser repeat only within issuance + 10 s, `no-store` + `no-referrer`, clean final URL | Unverified |
| G-19 | Every stop writes one outbox row per participant in its transaction; every row reaches a final state or the BX-10 deadline through Solid Queue and the sweep | Unverified |
| G-20 | Every stop record has principal and cause NOT NULL; token references in the OP database `ON DELETE RESTRICT`, the principal referenced by public id and protected by the purge order (cross-DB); a re-run is answered from the stored record. **Authority per cause** (corrected 2026-10-22 per seven.md #5; D-123's "no valid OP session → no authoritative stop" applies to **browser sign-out only**): browser sign-out — a valid OP session and the person's own request; identity stop — a committed identity-stop event; refresh reuse — a verified used token and its grant; token revocation — the authenticated client per D-79; administrative or risk stop — the operator's authorization and scope. A stop without its cause's authority is refused | Unverified |
| G-21 | Only `3`/`7` admit authentication; `0`, unknown and `NULL` refuse both authentication and authorization | Unverified |
| G-22 | No cookie set with `Domain` or `Partitioned` by any unit | Unverified |
| G-1 | Before the first unit starts, a fresh full `bin/rails test` baseline is taken at the starting commit **including the uncommitted worktree**, and its failure list recorded; the 2026-10-21 TR numbers (59/1) are history, not the baseline. A unit passes only when it adds no failure **and** every baseline failure in the unit's own area is fixed or explicitly reassigned with a reason ("no new failures" alone is not completion; seven.md) | Unverified |
| G-2 | Static invariant guards pass (`project/static-invariant-guards.mdc`), including `test/security/invariants/auth_surface_translation_namespace_invariant_test.rb` | Unverified |
| G-3 | No test deleted or weakened to pass; every rewritten test has a stated reason; no compatibility route, alias or fallback added | Unverified |
| G-4 | RuboCop clean on changed Ruby; oxfmt/oxlint/`tsc --build` clean on changed TypeScript | Unverified |
| G-5 | ADRs, `docs/`, checklists and `docs/mermaid` match the code for the touched area | Unverified |
| G-6 | One `evidence/` record with the full commit hash, uncommitted-change note, commands, results, and Not-run items | Unverified |
| G-7 | No key, token, cookie, code or contact value in logs, evidence, tests' printed output or docs | Unverified |
| G-11 | Two Flows finalizing one provider subject (both providers), unlink/relink racing Finalization, ban visible at Finalization, pre-existing revoked/deleted subject: one winner, loser adopts nothing and leaves no verified orphan | Unverified |
| G-12 | Cleanup vs confirmation/Finalization, old-Flow cleanup vs a new attempt: a confirmed Client/Identity stays usable (D-77) | Unverified |
| G-13 | Single consumption, expiry (≤ curfew, never the 60 s acceptance), mismatch refusal, OP DB outage → fail closed (D-78) | Unverified |
| G-14 | Failure at each boundary (Candidate consume, principal commit, graph commit, Flow transition, evidence handoff, response delivery) through public entry points with real separate transactions; assert remaining rows and the next sign-in's observable result; no single mocked exception as proof | Unverified |
| A01-1 | Request Base `/sign/completion` and Auth `/sign/handoff` on app/com/org | Unverified |
| A01-2 | Admit a ceremony with purpose `local_sign_in` / `local_sign_up` | Unverified |
| A01-3 | Dead-code check before each deletion | Unverified |
| A01-4 | `grep -rn "local_sign_in\ | Unverified |
| A01-5 | Re-pointed fixture tests | Unverified |
| A01-6 | `local_sign_in_flow_ref` column | Unverified |
| A02-1 | Each OP route on `visa.umaxica.{app,com,org}` | Unverified |
| A02-2 | Look-alike host (e.g. `visa.umaxica.app.example`) | Unverified |
| A02-3 | Boot without a `VISA_*` setting | Unverified |
| A02-4 | Discovery `issuer`, ID Token `iss`, authorization response `iss`, logout token `iss` | Unverified |
| A02-5 | Token with the old `www` issuer; client assertion with the old audience | Unverified |
| A02-6 | Visa JWKS vs Base JWKS | Unverified |
| A02-7 | Base self-RP sign-in end to end with per-host cookie jars (G1 regression) | Unverified |
| A02-8 | Auth result targets (R2) per realm | Unverified |
| A02-9 | Ceremony binding confirmation purpose ↔ host | Unverified |
| A02-10 | Jump edge table vs signed RTs | Unverified |
| A02-11 | Logout across hosts | Unverified |
| A02-12 | No Base page reads OP-written Rails-session state | Unverified |
| A02-13 | Old Base OP paths | Unverified |
| A02-14 | Jump integration | Unverified |
| A02-15 | Provider callback URLs after each realm unit (D-161 (4)) | Unverified |
| A02-16 | After 02-APP, before 02-COM | Unverified |
| A03-1 | `/edge/v0/cookie` on app/com/org | Unverified |
| A03-2 | `/api/v0/preferences/cookie` | Unverified |
| A03-3 | `grep -rn "edge/v0/cookie" app config src` | Unverified |
| A04-1 | OTP page props (app, com) | Unverified |
| A04-2 | Valid Turnstile + valid code | Unverified |
| A04-3 | Missing token / invalid token / verification failure | Unverified |
| A04-4 | After each refusal | Unverified |
| A04-5 | Retry with a new challenge and the valid code | Unverified |
| A04-6 | Email OTP regression | Unverified |
| A04-7 | `docs/security/turnstile.md` table | Unverified |
| A05-1 | New ADR exists **before** implementation commits (U4) | Unverified |
| A05-2 | Effective intent (EI-1/EI-2) | Unverified |
| A05-3 | One social Flow per attempt (R2-A) | Unverified |
| A05-4 | Unknown identity under a sign-in Admission / registered identity under a sign-up Admission | Unverified |
| A05-5 | Existing social user signing in | Unverified |
| A05-6 | Pending social Client (P1–P5) | Unverified |
| A05-7 | Candidate (C1–C3, corrected per D-78) | Unverified |
| A05-8 | Finalization (F1–F6) for all six paths — **Waits for WU-35's lock order (D-107); D-105 and D-106 apply** | Unverified |
| A05-9 | Concurrent sign-ups for one provider subject | Unverified |
| A05-10 | Sign In First for Google/Apple (S1–S4) | Unverified |
| A05-11 | Old social sign-up transport removed | Unverified |
| A05-12 | Social confirmation Turnstile | Unverified |
| A05-13 | Com email/telephone | Unverified |
| A06-1 | Each REQ-CURFEW 3 consumer at 29:59, 30:00, 30:01 | Unverified |
| A06-2 | Result issued before the curfew, presented after | Unverified |
| A06-3 | Social after 60 s within the curfew | Unverified |
| A06-4 | OP-side parents (ceremony, flows, OIDC transaction, `login_challenge`) | Unverified |
| A06-7 | Own browser acts at 30:00 / 30:01 (one Auth action, one provider callback, Cancel) | Unverified |
| A06-8 | Foreign browser (no or another cookie binding) presents the same references after the curfew | Unverified |
| A06-9 | Own browser after the curfew with the authorization transaction row removed | Unverified |
| A06-5 | Carried codes | Unverified |
| A06-6a | Finalization whose deadline check (OP clock, under the Flow/Binding lock) runs at 29:59 | Unverified |
| A06-6b | Same, with the principal commit and the Sign-in handoff landing at or after 30:00 (lock wait / delay injected through a real separate transaction) | Unverified |
| A06-6c | Deadline check at 30:00 / 30:01 | Unverified |
| A07-0 | Each refusal cause mapped to exactly one of the six classes | Unverified |
| A07-1 | Every definitive refusal of the owner's own attempt | Unverified |
| A07-1b | Ownership mismatch | Unverified |
| A07-1c | Retryable (Turnstile) | Unverified |
| A07-1d | Dependency failure | Unverified |
| A07-1e | Internal inconsistency | Unverified |
| A07-1f | Protocol refusal | Unverified |
| A07-2 | After a refusal, per D-73 class | Unverified |
| A07-3 | Log event per refusal | Unverified |
| A07-4 | Re-verification path and BCL receiver | Unverified |
| A08-1 | Intent × L1–L8 × provider | Unverified |
| A08-2 | L8 ban present together with any other state | Unverified |
| A08-3 | L4 (identity without Client) | Unverified |
| A08-4 | Any refusal | Unverified |
| A09-1 | Outdated browser UA on a browser page | Unverified |
| A09-2 | BCL receiver, token endpoint, health | Unverified |
| A10-1 | Refresh | Unverified |
| A10-2 | Reuse of a consumed token | Unverified |
| A10-3 | Unknown token | Unverified |
| A10-4 | Receipt endpoint and recovery code | Unverified |
| A10-5 | RP recovery | Unverified |
| A10-6 | `rp_refresh_attempts` removal migration | Unverified |
| A11-1 | Repeated verification, including the BCL receiver | Unverified |
| A11-2 | Unknown `kid`, fetch succeeds with / without it | Unverified |
| A11-3 | Unknown `kid`, fetch fails | Unverified |
| A11-4 | Known `kid` while the rate-limit Valkey is down | Unverified |
| A11-5 | Many random `kid`s for one issuer inside one window, two workers | Unverified |
| A11-6 | Window active: last fetch ok and `kid` absent / last fetch failed / lease held without a result | Unverified |
| A11-7 | Valkey down and unknown `kid` | Unverified |
| A11-8 | Lease holder dies before writing a result | Unverified |
| A11-10 | Non-ES384 token | Unverified |
| A11-11 | Unknown `kid` with a non-ES384 `alg`, a malformed `kid`, or another issuer | Unverified |
| A11-12 | Window value 30 s: unknown `kid` at 29 s / 30 s / 31 s after the last fetch | Unverified |
| A14-1 | GET and POST to `end_session_endpoint` | Unverified |
| A14-2 | Confirmation | Unverified |
| A14-3 | `id_token_hint` expired / foreign issuer / `client_id` mismatch | Unverified |
| A14-4 | Unregistered `post_logout_redirect_uri` | Unverified |
| A14-5a | Two RPs in one browser, logout at one: right after the OP commit | Unverified |
| A14-5b | Same, after the other RP receives the BCL | Unverified |
| A14-5c | Same, BCL undeliverable | Unverified |
| A14-6 | Cancel at the OP | Unverified |
| A14-7 | RP no longer writes OP logout rows or re-revokes on return | Unverified |
| A17-1 | Code exchange, refresh, identity stop | Unverified |
| A17-2 | Root with `authentication_epoch` 0 and a cutoff ≥ 1 | Unverified |
| A17-3 | `umx_contract_epoch` claim, `OpClientAdmissionGate`, activations | Unverified |
| A17-4 | Bulk update NULL → 0 and column drops | Unverified |
| A24-0 | WU-24a classification | Not applicable: D-159 removes existing-data classification |
| A24-1 | `authentication` Admission on a sign-up page or action | Passed: APP/COM wrong-intent GET/POST, preserved valid redemption; evidence I4B6 |
| A24-2 | Binding issuance | Passed for storage: OP clock bounds, immutable facts, repeated Switch inheritance; C7D4 |
| A24-3 | Flow ↔ Binding | Unverified |
| A24-4 | Stale tab with another attempt's locator | Unverified |
| A24-5 | Migrations WU-24c/d | Passed on empty development tables: rollback and reapplication; C7D4. Global drift gate still failed |
| A24-5a | Before WU-24f | Not applicable: D-159/D-168 remove settlement approval/data work |
| A24-5b | Before WU-24g | Not applicable: D-159/D-168 remove row-count/backup approval gate |
| A24-5c | Before WU-24h | Not applicable: D-159/D-168 remove row deletion/backup approval gate |
| A24-6 | `entry_intent` after WU-24d (D-157, D-159) | Passed: NOT NULL and purpose-intent CHECKs in all three realms; C7D4 |
| A24-7 | Cleanup decision (WU-24e) | Passed: APP/COM real lock races; evidence A6C4 |
| A24-8 | After WU-24f | Not applicable: D-159 removes existing-row settlement |
| A24-9 | After WU-24g | Passed: existing WU-01 retirement, matching live OP schemas and admission HTTP matrix; C7D4 |
| A24-10 | Binding purge with a Flow present | Unverified |
| A25-1 | Registered method per client (app, com, org) | Unverified |
| A25-2 | Wrong client / realm / audience / replayed assertion | Unverified |
| A25-3 | Discovery `revocation_endpoint_auth_methods_supported` | Unverified |
| A26-1 | Run against constructed partial states (six.md C.2 scenarios) | Unverified |
| A26-2 | Run with a writing role | Unverified |
| AX26-1 | App and Com telephone sign-up abandoned after the passkey step (before birthdate); discoverable Passkey sign-in with that passkey | Unverified |
| AX26-2 | Email sign-up abandoned after OTP verification; email sign-in with that address | Unverified |
| A23-1 | Listed ADR/docs | Unverified |
| A12-1 | Happy path RP `POST /sign` → … → RP `/oidc/callback` on app/com/org | Unverified |
| A12-2 | Each continuation GET from another browser (no or foreign cookie binding) | Unverified |
| A12-3 | Same bound browser repeats a **relay** hop (attach, confirm, redeem) at 9 s / 10 s / 11 s after issuance | Unverified |
| A12-4 | Repeat whose stored next-hop reference is consumed or expired | Unverified |
| A12-5 | HEAD, iframe (`Sec-Fetch-Dest: iframe`), missing Fetch Metadata | Unverified |
| A12-6 | Final result GET repeated after the Root Session exists | Unverified |
| A13-1 | Cancel from a Sign-in page and a Sign-up page on app/com/org, end to end through `/oidc/cancellation` | Unverified |
| A13-5 | OP Cancel response | Unverified |
| A13-2 | Switch Sign In → Sign Up on app/com | Unverified |
| A13-3 | ORG Switch | Unverified |
| A13-4 | `/oauth/authorize` with `cancellation_ref` / `switch_handoff` | Unverified |
| A15-1 | Stop with N participants | Unverified |
| A15-2 | Enqueue fails or the process restarts after COMMIT | Unverified |
| A15-3 | RP answers 200 / 400 / 5xx / timeout | Unverified |
| A15-4 | `POST /oidc/closures` from a server client with no browser User-Agent and no cookies | Unverified |
| A15-5 | Invalid signature, wrong `aud`, `nonce` present, missing `events` | Unverified |
| A15-6 | RP answers 401/403 (WAF challenge) / 404/405/410 / 413 / 429 (BX-4) | Unverified |
| A15-7 | RP URL resolving to private, loopback, link-local or metadata addresses; redirect from the RP | Unverified |
| A15-8 | Late BCL arriving after a new sign-in at that RP | Unverified |
| A15-9 | BCL arriving before the RP's callback for that `sid` completed | Unverified |
| A15-10 | Two workers lease the same outbox row | Unverified |
| A15-11 | Row past the BX-10 deadline; retention of finished rows | Unverified |
| A18-1 | Inventory | Unverified |
| A18-2 | After removal per surface | Unverified |
| A18-3 | Table drops | Unverified |
| A19-1 | Duplicate key with different text | Unverified |
| A19-2 | Key present in `en` but missing in `ja` (and the reverse) | Unverified |
| A19-3 | Same page with `ri=jp` and `ri=us` | Unverified |
| A20-1 | APP/COM sign-in: identifier → Passkey of the same Identity | Unverified |
| A20-2 | Passkey of another Identity after identifier selection | Unverified |
| A20-3 | Register the 9th / 10th / 11th Passkey | Unverified |
| A20-4 | Two concurrent registrations at 9 existing | Unverified |
| A20-5 | ADR-PK V1: missing, empty, malformed identifier; unknown, unverified, released, expired, ambiguous binding | Unverified |
| A20-6 | ADR-PK V2: disabled, revoked, deleted, unknown and foreign-surface credentials; each valid Passkey of A alone | Unverified |
| A20-7 | ADR-PK V3: existing vs unknown identifier | Unverified |
| A20-8 | ADR-PK V4: reuse, expiry boundary, wrong purpose, RP ID, Origin, userHandle, signature, UP, UV; concurrent resubmission | Unverified |
| A20-9 | ADR-PK V5: ORG Normal unchanged; Standby by Employee Number, cannot Step-Up or become Normal | Unverified |
| A20-10 | Contact owner changes between identifier selection and verification | Unverified |
| A20-11 | Registration options on APP, COM and ORG (every registration entry: sign-up telephone, registration for a signed-in Identity, Base management) | Unverified |
| A20-12 | ORG registration with a non-discoverable credential or without UV | Unverified |
| A20-13 | `docs/security/passkeys.md` | Unverified |
| A27-1a | Lost response after the auth cookies arrived, then repeat | Unverified |
| A27-1b | Lost response before the auth cookies arrived (D-130) | Unverified |
| A27-2 | Then RP 続行 | Unverified |
| A27-3 | Two tabs started in one browser | Unverified |
| A27-4 | TR G2/G5 tests and G3 Sign-in path cases | Unverified |
| A29-1 | Resolver: each of six pairs × `true` / `false` / unwritten | Unverified |
| A29-2 | Resolver: unknown surface or flow | Unverified |
| A29-3 | Sentry GET ALLOWED / BLOCKED | Unverified |
| A29-4 | Direct admitted-entry GET, `POST /sign/in`, `POST /ceremony_bindings`, one continuation POST per method, one provider callback (Google, Entra) while BLOCKED | Unverified |
| A29-5 | Root-login commit while Sign In BLOCKED | Unverified |
| A29-6 | Sign Up completes while Sign In BLOCKED | Unverified |
| A29-7 | Flag flipped between two requests of one flow | Unverified |
| A29-8 | While BLOCKED: authenticated page, Refresh, Sign Out, Step-Up ticket, `prompt=none`, SSO code | Unverified |
| A29-9 | ORG Emergency while `sign_in_available_org=false`; ORG invitation while `sign_up_available_org=false` | Unverified |
| A29-10 | `grep -rn "sign_up_suspended\ | Unverified |
| A29-11 | Six flags written `true` per environment before enforcement | Unverified |
| A29-12 | BLOCKED response content (D-169) | Unverified |
| A30-1 | Approval | Unverified |
| A30-2 | After migration | Unverified |
| A30-3 | Actor with mode `0`, `5`, unknown or `NULL` (constructed) | Unverified |
| A30-4 | APP/COM `ADVANCED` sign-in by email OTP, TOTP, social without passkey | Unverified |
| A30-5 | `ADVANCED` passkey deletion 3 → 2 / 2 → 1 | Unverified |
| A30-6 | ORG Operator with one passkey after migration (D-132) | Unverified |
| A30-7 | ORG Operator with zero passkeys | Unverified |
| A31-1 | Same ceremony, second `update` with a different code in the result window (APP, COM) | Unverified |
| A31-2 | Another admitted ceremony submits for the same account | Unverified |
| A31-3 | Two concurrent correct submissions | Unverified |
| A32-1 | Stale-generation binding POST (C6R2 reproduction) | Unverified |
| A32-2 | Replay of the same POST | Unverified |
| A32-5 | Two concurrent halting requests; a lost response after the Chronicle commit, then a repeat | Unverified |
| A32-3 | Chronicle write fails | Unverified |
| A32-4 | Record content | Unverified |
| A33-1 | Failure convergence table | Unverified |
| A35-1 | Lock inventory | Unverified |
| A35-2 | F-1 (if approved): replayed termination vs cleanup job on one Flow; APP telephone passkey save vs termination | Partial: Flow waiter and HTTP tests pass; request race remains; evidence A6C4 |
| A35-3 | F-2 (WU-24e): cleanup fails after deleting the contact, then retries | Passed: APP/COM real retention failure, rollback and retry; evidence A6C4 |
| A34-1 | AX26-1 / AX26-2 after the change | Unverified |
| A34-2 | Each method (OTP, Passkey, Secret, social, TOTP) for a pre-Finalization Client/Visitor | Unverified |
| A34-3 | A Finalized Identity | Unverified |
| A34-4 | COM candidate creation and Finalization (D-128) | Unverified |
| A34-5 | Failure after the principal's registered commit (graph or OP Flow completion fails, D-131) | Unverified |
| A36-1 | Every `Set-Cookie` and every cookie deletion from authentication, preference, withdrawal and enforcement-recovery paths | Unverified |
| A36-2 | `grep -rn "CoreCookieDomain" app lib config` | Unverified |
| A37-1 | Load estimate and chosen workers/threads/DB pool | Unverified |
| A37-2 | Under the estimated concurrent sign-in load | Unverified |
| A38-1 | New sign-up with a contact held by an unfinished registration before its cleanup | Unverified |
| A38-2 | Same after the deadline and the cleanup run | Unverified |
| A38-3 | Flow past its deadline without Finalization | Unverified |
| A38-4 | Finalized Identity with the same contact | Unverified |
| A42-1 | Authorize with the registered `redirect_uri` per realm | Unverified |
| A42-2 | Unregistered URI; differing scheme / host / port (`:443` written explicitly, `:3001`) / path (trailing slash, case) / added query / fragment; URI of another realm; missing | Unverified |
| A42-3 | Invalid `redirect_uri` together with another error (bad scope, missing `state`) | Unverified |
| A42-4 | Token request: code exchanged by another client; `redirect_uri` differing in one character; `redirect_uri` omitted | Unverified |
| A42-4b | Token request with a wrong `code_verifier` / without `code_verifier` | Unverified |
| A42-5 | Client store with a registered URI carrying a fragment, `http` in production, or a reserved query key | Unverified |
| A42-6 | Jump-forwarded authorize request (D-146: accepted risk until then) | Unverified |
| A42-7 | PKCE, realm separation, code single use, `state`/`nonce`, OIDC session | Unverified |
| A42-8 | Valid client and `redirect_uri`, then one representative per row of the N-1 table | Unverified |
| A42-9 | Unknown `client_id`; valid client with an unregistered `redirect_uri`; either combined with a later error | Unverified |
| A42-10 | Registered URI with a query (constructed client) | Unverified |
| A42-13 | `code_challenge` of 42 / 43 / 44 characters, with `=` padding, with a `+` or `/` | Unverified |
| A42-11 | Discovery per realm (D-148) | Unverified |
| A42-12 | `prompt=consent`, `select_account`, an unknown value, ORG `create`, and combinations (`none login`, `login create`) | Unverified |
| A43-1 | `state` issued and verified by the same RP | Unverified |
| A43-2 | `alg` `none`, HS256, RS256, ES256; header `alg` ES384 with a payload signed otherwise | Unverified |
| A43-3 | Tampered payload or signature; unknown `kid`; `kid` of another RP's key | Unverified |
| A43-4 | Wrong `typ`, `iss`, `aud`; missing `jti`/`iat`/`exp`/`v` | Unverified |
| A43-5 | Client assertion presented as `state`; `state` presented as a client assertion at the token endpoint | Unverified |
| A43-6 | `exp` = `iat` + 30 min (D-150, D-160): 29:59 / 30:00 / 30:01 after `POST /sign` on the Rails clock; `iat` in the future beyond the leeway | Unverified |
| A43-20 | RP `state` expired while the OP curfew is still open: the OP issues a code for a Sign In, and for a Sign Up | Unverified |
| A43-7 | Key rotated after issue, old public key retained / removed | Unverified |
| A43-8 | Valid `state` in another browser (no pending entry) | Unverified |
| A43-9 | **Intended behavior (D-155):** tab A `POST /sign`, then tab B `POST /sign`; B completes; then A completes every Auth step and the OP issues A's code | Unverified |
| A43-9b | Same start order, but A completes first, then B | Unverified |
| A43-9d | **Best effort (owner: implement if feasible):** tab A Sign Up, then tab B Sign In with another existing account; B completes; A completes its Sign Up | Unverified |
| A43-9e | Two **browsers** (separate cookie jars), same APP account with no active session, both sign in | Unverified |
| A43-9c | After `POST /sign` in two tabs | Unverified |
| A43-10 | ID Token `nonce` mismatch; code reuse; PKCE mismatch | Unverified |
| A43-11 | CSRF enabled inside the test: `POST /sign` without / with a valid token; callback GET | Unverified |
| A43-12 | Target restored once after callback validation, code exchange and RP session; an external, protocol-relative or nested target refused → RP default page | Unverified |
| A43-13 | `target_link_uri` with a query, a fragment, `//host`, a dot segment, `%2f`, under `/sign` or `/oidc`; missing | Unverified |
| A43-15 | Cancel during Sign In and during Sign Up, per RP (D-152) | Unverified |
| A43-16 | Each D-153 case per RP: other OP error, unknown/expired/foreign `state`, missing pending entry, failed code exchange, bad ID Token or `nonce` | Unverified |
| A43-17 | `GET /sign/interruption` signed out / signed in / with any query | Unverified |
| A43-18 | Replay after success: the same callback (`state` + code), or the old RP session cookie re-sent (D-154) | Unverified |
| A43-19 | Logs and headers | Unverified |
| A43-21 | Auth's own `pt` lane after the RP `pt` removal (D-162 (3)) | Unverified |
| A43-14 | Protected page with a query string | Unverified |
| A44-1 | Connection 1: `log_in` passes the early checks and is held before the actor lock; connection 2 commits an administrative lock (then a withdrawal suspend, then an operator stop); connection 1 continues | Unverified |
| A44-2 | Same, but the stop commits after the root insert | Unverified |
| A44-3 | Root and Access JWT issued; stop committed with the OP apply failing (queued); account restored before the apply | Unverified |
| A44-4 | Epoch read on the authentication boundary while the reading replica lags (constructed: replica shows the old epoch) | Unverified |
| A44-5 | Writer unavailable during the epoch read | Unverified |
| A44-6 | Single-root sign-out, token revocation and refresh reuse | Unverified |
| A44-7 | Static guard | Unverified |
| A44-8 | Epoch equality (D-165): root epoch equal / one lower / one higher than the actor's | Unverified |
| A44-9 | Credential change (password/secret change, passkey removal) committing while a login with the old credential is held before the actor lock (D-167) | Unverified |
| A44-10 | "Sign out other sessions" while another browser's login commits | Unverified |
| A41-1 | `SHOW lock_timeout` / `SHOW statement_timeout` on every connection (development, test) | Unverified |
| A41-2 | Full test run after the change | Unverified |
| A41-3 | Retention, expiry and secret-lifecycle jobs once in development | Unverified |
| A40-1 | APP and COM recovery send without a Turnstile token / with a failed token | Unverified |
| A40-2 | Valid token, registered verified address / unknown address | Unverified |
| A40-3 | Turnstile unreachable with degradation off / on | Unverified |
| A40-4 | Verify branch (`pass_code`) without a Turnstile token | Unverified |
| A40-5 | Recovery page render (APP, COM) | Unverified |
| A39-1 | Each item in two.md WU-39 | Unverified |
| S-1 | AUTH-19 with D-51: a foreign browser presenting an admission or result reference cannot confirm, redeem, be accepted or get a Root Session; a first attach before the victim is the accepted D-51 denial and is asserted to go no further | Unverified |
| S-2 | Sign In First: no Sign-up path issues a session directly; no Sign-in failure or Sentry refusal deletes a Finalized Identity | Unverified |
| S-3 | Surface separation: no controller/route/session sharing across app/com/org; Auth com/org translation guard green | Unverified |
| S-4 | No database NULL with meaning introduced | Unverified |
