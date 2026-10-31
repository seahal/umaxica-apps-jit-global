# WU-X2 acceptance disposition ledger

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`; the worktree had extensive uncommitted changes affecting the referenced results.
- Source for candidate IDs and descriptions: `plans/archive/0002-authentication-cycle-2026-10/acceptance-cases.md`, as inventoried in `/tmp/wux2-archived-not-run-inventory.md`. Historical status is an identification aid, not proof of current behavior.
- The archived later snapshot has 130 distinct rows beginning Not run; its README reports a different later total, and the original 166-ID snapshot has not been recovered. The 130 cannot be established as exactly the original 166 minus 36. The remaining 36 are an arithmetic gap, not identified test IDs or classified cases.
- Evidence links refer only to checks actually executed in this session. A link may show partial coverage, a failed probe, or an old-contract conflict; it is not automatically a whole-case pass. Unjudged means the complete case or its original membership needs reconciliation.

| ID | Historical case | Disposition | Result / reason | Current-session evidence |
|---|---|---|---|---|
| A02-7 | Base self-RP sign-in end to end with per-host cookie jars (G1 regression) | Not run | Whole case not run; no complete current-contract run is recorded. | None identified |
| A02-8 | Auth result targets (R2) per realm | Not run | Whole case not run; no complete current-contract run is recorded. | None identified |
| A02-11 | Logout across hosts | Not run | Whole case not run; no complete current-contract run is recorded. | None identified |
| A02-13 | Old Base OP paths | Not run | Evidence is partial or requires whole-case and original-set reconciliation. | [V7K2](2026-10-31-wux2-base-op-route-scope-V7K2.md), [P3V6](2026-10-31-wux2-base-confirmation-post-P3V6.md), [X7C5](2026-10-31-wux2-base-old-http-X7C5.md), [R4M8](2026-10-31-wux2-base-exceptions-R4M8.md) |
| A02-14 | Jump integration | Not run | Historical Jump integration depends on the remaining Jump work; full end-to-end behavior is unverified. | None identified |
| A02-15 | Provider callback URLs after each realm unit (D-161 (4)) | Not run | Evidence is partial or requires whole-case and original-set reconciliation. | [N6P4](2026-10-31-wux2-provider-config-baseline-N6P4.md), [B9H3](2026-10-31-wux2-entra-authorize-callback-B9H3.md), [P8C2](2026-10-31-wux2-entra-callback-token-P8C2.md), [W6J4](2026-10-31-wux2-app-provider-callbacks-W6J4.md) |
| A02-16 | After 02-APP, before 02-COM | Not run | Whole case not run; no complete current-contract run is recorded. | None identified |
| A03-1 | `/edge/v0/cookie` on app/com/org | Not run | Whole case not run; no complete current-contract run is recorded. | None identified |
| A03-2 | `/api/v0/preferences/cookie` | Not run | Whole case not run; no complete current-contract run is recorded. | None identified |
| A04-1 | OTP page props (app, com) | Not run | Whole case not run; no complete current-contract run is recorded. | None identified |
| A04-2 | Valid Turnstile + valid code | Not run | Whole case not run; no complete current-contract run is recorded. | None identified |
| A04-3 | Missing token / invalid token / verification failure | Not run | Whole case not run; no complete current-contract run is recorded. | None identified |
| A04-4 | After each refusal | Not run | Whole case not run; no complete current-contract run is recorded. | None identified |
| A04-5 | Retry with a new challenge and the valid code | Not run | Whole case not run; no complete current-contract run is recorded. | None identified |
| A04-6 | Email OTP regression | Not run | Whole case not run; no complete current-contract run is recorded. | None identified |
| A05-2 | Effective intent (EI-1/EI-2) | Not run | Evidence is partial or requires whole-case and original-set reconciliation. | [Q6G4](2026-10-31-wux2-a0502-effective-intent-Q6G4.md) |
| A05-3 | One social Flow per attempt (R2-A) | Not run | Partial Flow cases executed; callback refusal coverage and current WU-A9 dependencies remain incomplete. | [B6K2](2026-10-31-wux2-a0503-social-flow-B6K2.md) |
| A05-5 | Existing social user signing in | Not run | Sign-in cases passed locally; the historical signup-entry fallthrough conflicts with two.md §10.7 and is not accepted as a pass. | [R6V9](2026-10-31-wux2-a0505-existing-social-R6V9.md) |
| A05-6 | Pending social Client (P1–P5) | Not run | Evidence is partial or requires whole-case and original-set reconciliation. | [J9L2](2026-10-31-wux2-social-confirmation-replay-J9L2.md), [H6B3](2026-10-31-wux2-a0506-pending-social-H6B3.md) |
| A05-7 | Candidate (C1–C3, corrected per D-78) | Not run | Evidence is partial or requires whole-case and original-set reconciliation. | [M5R9](2026-10-31-wux2-a0507-candidate-failure-M5R9.md) |
| A05-8 | Finalization (F1–F6) for all six paths — **Waits for WU-35's lock order (D-107); D-105 and D-106 apply** | Not run | Whole case not run; no complete current-contract run is recorded. | None identified |
| A05-9 | Concurrent sign-ups for one provider subject | Not run | Whole case not run; no complete current-contract run is recorded. | None identified |
| A05-10 | Sign In First for Google/Apple (S1–S4) | Not run | Evidence is partial or requires whole-case and original-set reconciliation. | [B7P2](2026-10-31-wux2-a0510-social-signup-B7P2.md) |
| A05-11 | Old social sign-up transport removed | Not run | Evidence is partial or requires whole-case and original-set reconciliation. | [D4H6](2026-10-31-wux2-a0511-social-transport-D4H6.md) |
| A05-13 | Com email/telephone | Not needed: removed | The positive COM credential journey was retired by two.md §3.2; selected route checks passed. | [D6W3](2026-10-31-wux2-a0513-com-superseded-D6W3.md) |
| A06-1 | Each REQ-CURFEW 3 consumer at 29:59, 30:00, 30:01 | Not run | Whole case not run; no complete current-contract run is recorded. | None identified |
| A06-3 | Social after 60 s within the curfew | Not run | Evidence is partial or requires whole-case and original-set reconciliation. | [D8S3](2026-10-31-wux2-a06-a08-D8S3.md) |
| A06-7 | Own browser acts at 30:00 / 30:01 (one Auth action, one provider callback, Cancel) | Not run | Evidence is partial or requires whole-case and original-set reconciliation. | [D8S3](2026-10-31-wux2-a06-a08-D8S3.md) |
| A06-8 | Foreign browser (no or another cookie binding) presents the same references after the curfew | Not run | Evidence is partial or requires whole-case and original-set reconciliation. | [D8S3](2026-10-31-wux2-a06-a08-D8S3.md) |
| A06-9 | Own browser after the curfew with the authorization transaction row removed | Not run | Evidence is partial or requires whole-case and original-set reconciliation. | [D8S3](2026-10-31-wux2-a06-a08-D8S3.md) |
| A06-5 | Carried codes | Not run | Whole case not run; no complete current-contract run is recorded. | None identified |
| A06-6a | Finalization whose deadline check (OP clock, under the Flow/Binding lock) runs at 29:59 | Not run | Whole case not run; no complete current-contract run is recorded. | None identified |
| A06-6c | Deadline check at 30:00 / 30:01 | Not run | Whole case not run; no complete current-contract run is recorded. | None identified |
| A07-1 | Every definitive refusal of the owner's own attempt | Not run | Whole case not run; no complete current-contract run is recorded. | None identified |
| A07-1b | Ownership mismatch | Not run | Whole case not run; no complete current-contract run is recorded. | None identified |
| A07-1d | Dependency failure | Not run | Whole case not run; no complete current-contract run is recorded. | None identified |
| A07-1f | Protocol refusal | Not run | Whole case not run; no complete current-contract run is recorded. | None identified |
| A07-4 | Re-verification path and BCL receiver | Not run | Whole case not run; no complete current-contract run is recorded. | None identified |
| A08-2 | L8 ban present together with any other state | Not run | Whole case not run; no complete current-contract run is recorded. | None identified |
| A08-3 | L4 (identity without Client) | Not run | Whole case not run; no complete current-contract run is recorded. | None identified |
| A08-4 | Any refusal | Not run | Evidence is partial or requires whole-case and original-set reconciliation. | [D8S3](2026-10-31-wux2-a06-a08-D8S3.md) |
| A09-1 | Outdated browser UA on a browser page | Pass | Auth APP/ORG sign-in and Docs HTML reject the tested outdated browser; representative local request coverage. | Current-session run below; [A7Q4](2026-10-31-wux2-browser-health-A7Q4.md) |
| A09-2 | BCL receiver, token endpoint, health | Fail | APP Auth liveness returned 406 for the old browser; other surfaces remain incomplete. | [A7Q4](2026-10-31-wux2-browser-health-A7Q4.md) |
| A10-2 | Reuse of a consumed token | Not run | Evidence is partial or requires whole-case and original-set reconciliation. | [K5F9](2026-10-31-wux2-org-refresh-sibling-K5F9.md), [D8J4](2026-10-31-wux2-refresh-replay-scope-D8J4.md) |
| A10-3 | Unknown token | Not run | Evidence is partial or requires whole-case and original-set reconciliation. | [B5N7](2026-10-31-wux2-unknown-refresh-id-B5N7.md), [T9L4](2026-10-31-wux2-org-unknown-refresh-T9L4.md), [D8J4](2026-10-31-wux2-refresh-replay-scope-D8J4.md) |
| A11-1 | Repeated verification, including the BCL receiver | Not run | Whole case not run; no complete current-contract run is recorded. | None identified |
| A11-2 | Unknown `kid`, fetch succeeds with / without it | Not run | Whole case not run; no complete current-contract run is recorded. | None identified |
| A11-3 | Unknown `kid`, fetch fails | Not run | Whole case not run; no complete current-contract run is recorded. | None identified |
| A11-4 | Known `kid` while the rate-limit Valkey is down | Pass | A held key verifies with an unavailable rate-limit connection; the connection is not called. | Current-session run below; [T9P3](2026-10-31-wux2-jwks-cases-T9P3.md) |
| A11-5 | Many random `kid`s for one issuer inside one window, two workers | Not run | Whole case not run; no complete current-contract run is recorded. | None identified |
| A11-6 | Window active: last fetch ok and `kid` absent / last fetch failed / lease held without a result | Not run | Whole case not run; no complete current-contract run is recorded. | None identified |
| A11-7 | Valkey down and unknown `kid` | Not run | Whole case not run; no complete current-contract run is recorded. | None identified |
| A11-8 | Lease holder dies before writing a result | Not run | Whole case not run; no complete current-contract run is recorded. | None identified |
| A11-10 | Non-ES384 token | Pass | Access, ID and Logout verifiers reject an HS256 example before fetching keys. | Current-session run below; [T9P3](2026-10-31-wux2-jwks-cases-T9P3.md) |
| A11-11 | Unknown `kid` with a non-ES384 `alg`, a malformed `kid`, or another issuer | Not run | Evidence is partial or requires whole-case and original-set reconciliation. | [T9P3](2026-10-31-wux2-jwks-cases-T9P3.md) |
| A11-12 | Window value 30 s: unknown `kid` at 29 s / 30 s / 31 s after the last fetch | Not run | Whole case not run; no complete current-contract run is recorded. | None identified |
| A25-1 | Registered method per client (app, com, org) | Not run | Whole case not run; no complete current-contract run is recorded. | None identified |
| A25-2 | Wrong client / realm / audience / replayed assertion | Not run | Whole case not run; no complete current-contract run is recorded. | None identified |
| AX26-1 | App and Com telephone sign-up abandoned after the passkey step (before birthdate); discoverable Passkey sign-in with that passkey | Not run | Whole case not run; no complete current-contract run is recorded. | None identified |
| AX26-2 | Email sign-up abandoned after OTP verification; email sign-in with that address | Not run | Whole case not run; no complete current-contract run is recorded. | None identified |
| A12-2 | Each continuation GET from another browser (no or foreign cookie binding) | Not run | Whole case not run; no complete current-contract run is recorded. | None identified |
| A13-1 | Cancel from a Sign-in page and a Sign-up page on app/com/org, end to end through `/oidc/cancellation` | Not run | Whole case not run; no complete current-contract run is recorded. | None identified |
| A13-3 | ORG Switch | Not run | Whole case not run; no complete current-contract run is recorded. | None identified |
| A19-3 | Same page with `ri=jp` and `ri=us` | Not run | Evidence is partial or requires whole-case and original-set reconciliation. | [E7M2](2026-10-31-wux2-region-language-copy-E7M2.md) |
| A27-1a | Lost response after the auth cookies arrived, then repeat | Not run | Whole case not run; no complete current-contract run is recorded. | None identified |
| A27-4 | TR G2/G5 tests and G3 Sign-in path cases | Not run | Whole case not run; no complete current-contract run is recorded. | None identified |
| A29-2 | Resolver: unknown surface or flow | Pass | Resolver rejection was exercised for the stated unknown surface/flow examples. | [M2J5](2026-10-31-wux2-a29-unknown-resolver-M2J5.md) |
| A30-3 | Actor with mode `0`, `5`, unknown or `NULL` (constructed) | Not run | Whole case not run; no complete current-contract run is recorded. | None identified |
| A30-4 | APP/COM `ADVANCED` sign-in by email OTP, TOTP, social without passkey | Not run | Whole case not run; no complete current-contract run is recorded. | None identified |
| A30-5 | `ADVANCED` passkey deletion 3 → 2 / 2 → 1 | Not run | Whole case not run; no complete current-contract run is recorded. | None identified |
| A30-6 | ORG Operator with one passkey after migration (D-132) | Fail | The one-Passkey inventory probe returned 200 where the recorded case expected restriction; the full journey also failed. | [V6J8](2026-10-31-wux2-org-one-passkey-gate-V6J8.md), [C4F7](2026-10-31-wux2-org-one-passkey-signin-C4F7.md), [A3L8](2026-10-31-wux2-org-journey-second-passkey-probe-A3L8.md) |
| A30-7 | ORG Operator with zero passkeys | Not run | Whole case not run; no complete current-contract run is recorded. | None identified |
| A31-1 | Same ceremony, second `update` with a different code in the result window (APP, COM) | Not run | Whole case not run; no complete current-contract run is recorded. | None identified |
| A31-2 | Another admitted ceremony submits for the same account | Not run | Whole case not run; no complete current-contract run is recorded. | None identified |
| A31-3 | Two concurrent correct submissions | Not run | Whole case not run; no complete current-contract run is recorded. | None identified |
| A32-1 | Stale-generation binding POST (C6R2 reproduction) | Not run | Whole case not run; no complete current-contract run is recorded. | None identified |
| A32-2 | Replay of the same POST | Not run | Whole case not run; no complete current-contract run is recorded. | None identified |
| A32-5 | Two concurrent halting requests; a lost response after the Chronicle commit, then a repeat | Not run | Whole case not run; no complete current-contract run is recorded. | None identified |
| A32-3 | Chronicle write fails | Not run | Whole case not run; no complete current-contract run is recorded. | None identified |
| A32-4 | Record content | Not run | Whole case not run; no complete current-contract run is recorded. | None identified |
| A34-1 | AX26-1 / AX26-2 after the change | Not run | Whole case not run; no complete current-contract run is recorded. | None identified |
| A34-3 | A Finalized Identity | Not run | Whole case not run; no complete current-contract run is recorded. | None identified |
| A34-4 | COM candidate creation and Finalization (D-128) | Not run | Whole case not run; no complete current-contract run is recorded. | None identified |
| A42-1 | Authorize with the registered `redirect_uri` per realm | Not run | Whole case not run; no complete current-contract run is recorded. | None identified |
| A42-2 | Unregistered URI; differing scheme / host / port (`:443` written explicitly, `:3001`) / path (trailing slash, case) / added query / fragment; URI of another realm; missing | Not run | Whole case not run; no complete current-contract run is recorded. | None identified |
| A42-3 | Invalid `redirect_uri` together with another error (bad scope, missing `state`) | Not run | Whole case not run; no complete current-contract run is recorded. | None identified |
| A42-4 | Token request: code exchanged by another client; `redirect_uri` differing in one character; `redirect_uri` omitted | Not run | Whole case not run; no complete current-contract run is recorded. | None identified |
| A42-4b | Token request with a wrong `code_verifier` / without `code_verifier` | Not run | Whole case not run; no complete current-contract run is recorded. | None identified |
| A42-5 | Client store with a registered URI carrying a fragment, `http` in production, or a reserved query key | Not run | Whole case not run; no complete current-contract run is recorded. | None identified |
| A42-6 | Jump-forwarded authorize request (D-146: accepted risk until then) | Not run | Whole case not run; no complete current-contract run is recorded. | None identified |
| A42-7 | PKCE, realm separation, code single use, `state`/`nonce`, OIDC session | Not run | Whole case not run; no complete current-contract run is recorded. | None identified |
| A42-8 | Valid client and `redirect_uri`, then one representative per row of the N-1 table | Not run | Whole case not run; no complete current-contract run is recorded. | None identified |
| A42-9 | Unknown `client_id`; valid client with an unregistered `redirect_uri`; either combined with a later error | Not run | Whole case not run; no complete current-contract run is recorded. | None identified |
| A42-10 | Registered URI with a query (constructed client) | Not run | Whole case not run; no complete current-contract run is recorded. | None identified |
| A42-13 | `code_challenge` of 42 / 43 / 44 characters, with `=` padding, with a `+` or `/` | Not run | Whole case not run; no complete current-contract run is recorded. | None identified |
| A42-11 | Discovery per realm (D-148) | Not run | Whole case not run; no complete current-contract run is recorded. | None identified |
| A42-12 | `prompt=consent`, `select_account`, an unknown value, ORG `create`, and combinations (`none login`, `login create`) | Not run | Whole case not run; no complete current-contract run is recorded. | None identified |
| A43-1 | `state` issued and verified by the same RP | Not run | Whole case not run; no complete current-contract run is recorded. | None identified |
| A43-2 | `alg` `none`, HS256, RS256, ES256; header `alg` ES384 with a payload signed otherwise | Not run | Whole case not run; no complete current-contract run is recorded. | None identified |
| A43-3 | Tampered payload or signature; unknown `kid`; `kid` of another RP's key | Not run | Whole case not run; no complete current-contract run is recorded. | None identified |
| A43-4 | Wrong `typ`, `iss`, `aud`; missing `jti`/`iat`/`exp`/`v` | Not run | Whole case not run; no complete current-contract run is recorded. | None identified |
| A43-5 | Client assertion presented as `state`; `state` presented as a client assertion at the token endpoint | Not run | Whole case not run; no complete current-contract run is recorded. | None identified |
| A43-6 | `exp` = `iat` + 30 min (D-150, D-160): 29:59 / 30:00 / 30:01 after `POST /sign` on the Rails clock; `iat` in the future beyond the leeway | Not run | Whole case not run; no complete current-contract run is recorded. | None identified |
| A43-20 | RP `state` expired while the OP curfew is still open: the OP issues a code for a Sign In, and for a Sign Up | Not run | Whole case not run; no complete current-contract run is recorded. | None identified |
| A43-7 | Key rotated after issue, old public key retained / removed | Not run | Whole case not run; no complete current-contract run is recorded. | None identified |
| A43-8 | Valid `state` in another browser (no pending entry) | Not run | Whole case not run; no complete current-contract run is recorded. | None identified |
| A43-9 | **Intended behavior (D-155):** tab A `POST /sign`, then tab B `POST /sign`; B completes; then A completes every Auth step and the OP issues A's code | Not run | Whole case not run; no complete current-contract run is recorded. | None identified |
| A43-9b | Same start order, but A completes first, then B | Not run | Whole case not run; no complete current-contract run is recorded. | None identified |
| A43-9d | **Best effort (owner: implement if feasible):** tab A Sign Up, then tab B Sign In with another existing account; B completes; A completes its Sign Up | Not run | Whole case not run; no complete current-contract run is recorded. | None identified |
| A43-9e | Two **browsers** (separate cookie jars), same APP account with no active session, both sign in | Not run | Whole case not run; no complete current-contract run is recorded. | None identified |
| A43-9c | After `POST /sign` in two tabs | Not run | Whole case not run; no complete current-contract run is recorded. | None identified |
| A43-10 | ID Token `nonce` mismatch; code reuse; PKCE mismatch | Not run | Whole case not run; no complete current-contract run is recorded. | None identified |
| A43-11 | CSRF enabled inside the test: `POST /sign` without / with a valid token; callback GET | Not run | Whole case not run; no complete current-contract run is recorded. | None identified |
| A43-12 | Target restored once after callback validation, code exchange and RP session; an external, protocol-relative or nested target refused → RP default page | Not run | Whole case not run; no complete current-contract run is recorded. | None identified |
| A43-13 | `target_link_uri` with a query, a fragment, `//host`, a dot segment, `%2f`, under `/sign` or `/oidc`; missing | Not run | Whole case not run; no complete current-contract run is recorded. | None identified |
| A43-15 | Cancel during Sign In and during Sign Up, per RP (D-152) | Not run | Whole case not run; no complete current-contract run is recorded. | None identified |
| A43-16 | Each D-153 case per RP: other OP error, unknown/expired/foreign `state`, missing pending entry, failed code exchange, bad ID Token or `nonce` | Not run | Whole case not run; no complete current-contract run is recorded. | None identified |
| A43-17 | `GET /sign/interruption` signed out / signed in / with any query | Not run | Whole case not run; no complete current-contract run is recorded. | None identified |
| A43-18 | Replay after success: the same callback (`state` + code), or the old RP session cookie re-sent (D-154) | Not run | Whole case not run; no complete current-contract run is recorded. | None identified |
| A43-19 | Logs and headers | Not run | Whole case not run; no complete current-contract run is recorded. | None identified |
| A43-21 | Auth's own `pt` lane after the RP `pt` removal (D-162 (3)) | Not run | Whole case not run; no complete current-contract run is recorded. | None identified |
| A43-14 | Protected page with a query string | Not run | Whole case not run; no complete current-contract run is recorded. | None identified |
| A44-1 | Connection 1: `log_in` passes the early checks and is held before the actor lock; connection 2 commits an administrative lock (then a withdrawal suspend, then an operator stop); connection 1 continues | Not run | Whole case not run; no complete current-contract run is recorded. | None identified |
| A44-3 | Root and Access JWT issued; stop committed with the OP apply failing (queued); account restored before the apply | Not run | Whole case not run; no complete current-contract run is recorded. | None identified |
| A44-8 | Epoch equality (D-165): root epoch equal / one lower / one higher than the actor's | Not run | Whole case not run; no complete current-contract run is recorded. | None identified |
| A40-1 | APP and COM recovery send without a Turnstile token / with a failed token | Not run | Whole case not run; no complete current-contract run is recorded. | None identified |
| A40-2 | Valid token, registered verified address / unknown address | Not run | Whole case not run; no complete current-contract run is recorded. | None identified |
| A40-3 | Turnstile unreachable with degradation off / on | Not run | Whole case not run; no complete current-contract run is recorded. | None identified |
| A40-4 | Verify branch (`pass_code`) without a Turnstile token | Not run | Whole case not run; no complete current-contract run is recorded. | None identified |
| A40-5 | Recovery page render (APP, COM) | Not run | Whole case not run; no complete current-contract run is recorded. | None identified |

- Candidate-row counts: pass 4, fail 2, not run 123, not needed 1, unjudged 0; total 130.
- Original 166-case classification: not established; 36 is only the difference between two snapshots and is not a count of identified unjudged cases. The complete original ID list and its per-ID membership remain unverified.
- No full suite was executed to create this ledger. Referenced results are bounded by their individual evidence records; production deployment and unreceived material remain unverified.

## Additional IDs from the 56 historically mapped rows

The Stage 2 source contains 56 IDs, 16 overlapping the 130 later Not run rows and 40 additional IDs. The 170-ID union is not proven to be the original 166: the sources represent different snapshots. These additional rows are shown for reconciliation and are not included in the 130-row counts above. Historical mapping alone is not a test result.

| ID | Historical mapping | Disposition | Current-session evidence and limitation |
|---|---|---|---|
| A02-1 | Mapped | Not run | Whole case not run: linked evidence is partial or does not establish the full current contract. [L3C9](2026-10-31-wux2-a02-routes-L3C9.md) |
| A02-2 | Mapped | Not run | Whole case not run: linked evidence is partial or does not establish the full current contract. [L3C9](2026-10-31-wux2-a02-routes-L3C9.md) |
| A02-4 | Mapped | Not run | Whole case not run: linked evidence is partial or does not establish the full current contract. No matching execution evidence identified |
| A02-5 | Mapped | Not run | Whole case not run: linked evidence is partial or does not establish the full current contract. [L3C9](2026-10-31-wux2-a02-routes-L3C9.md) |
| A02-6 | Mapped | Not run | Whole case not run: linked evidence is partial or does not establish the full current contract. [G7B2](2026-10-31-wux2-a02-mapped-G7B2.md) |
| A02-9 | Mapped | Not run | Whole case not run: linked evidence is partial or does not establish the full current contract. [G7B2](2026-10-31-wux2-a02-mapped-G7B2.md) |
| A02-10 | Mapped | Not run | Whole case not run: linked evidence is partial or does not establish the full current contract. No matching execution evidence identified |
| A02-12 | Mapped | Not run | Whole case not run: linked evidence is partial or does not establish the full current contract. [G7B2](2026-10-31-wux2-a02-mapped-G7B2.md) |
| A05-4 | Mapped | Not run: depends on WU-A9 | Generic refusal tests ran; WU-A9 reason-specific public responses remain incomplete. [K6V2](2026-10-31-wux2-a0504-http-matrix-K6V2.md) |
| A05-12 | Mapped | Not run | Whole case not run: linked evidence is partial or does not establish the full current contract. [D3F7](2026-10-31-wux2-a0512-turnstile-D3F7.md) |
| A06-2 | Mapped | Not run | Whole case not run: linked evidence is partial or does not establish the full current contract. [D8S3](2026-10-31-wux2-a06-a08-D8S3.md) |
| A06-4 | Mapped | Not run | Whole case not run: linked evidence is partial or does not establish the full current contract. [D8S3](2026-10-31-wux2-a06-a08-D8S3.md) |
| A06-6b | Mapped | Not run | Whole case not run: linked evidence is partial or does not establish the full current contract. No matching execution evidence identified |
| A07-0 | Mapped | Not run | Whole case not run: linked evidence is partial or does not establish the full current contract. [E6B1](2026-10-31-wux2-a07-sentry-E6B1.md) |
| A07-1c | Mapped | Not run | Whole case not run: linked evidence is partial or does not establish the full current contract. No matching execution evidence identified |
| A07-1e | Mapped | Not run | Whole case not run: linked evidence is partial or does not establish the full current contract. [D8S3](2026-10-31-wux2-a06-a08-D8S3.md) |
| A07-2 | Mapped | Not run | Whole case not run: linked evidence is partial or does not establish the full current contract. [E6B1](2026-10-31-wux2-a07-sentry-E6B1.md), [D8S3](2026-10-31-wux2-a06-a08-D8S3.md) |
| A07-3 | Mapped | Not run | Whole case not run: linked evidence is partial or does not establish the full current contract. [E6B1](2026-10-31-wux2-a07-sentry-E6B1.md) |
| A08-1 | Mapped | Not run | Whole case not run: linked evidence is partial or does not establish the full current contract. [D8S3](2026-10-31-wux2-a06-a08-D8S3.md) |
| A10-1 | Mapped | Not run | Whole case not run: linked evidence is partial or does not establish the full current contract. [Q3R5](2026-10-31-wux2-a10-a12-mapped-Q3R5.md) |
| A10-4 | Mapped | Not run | Whole case not run: linked evidence is partial or does not establish the full current contract. No matching execution evidence identified |
| A10-5 | Mapped | Not run | Whole case not run: linked evidence is partial or does not establish the full current contract. [Q3R5](2026-10-31-wux2-a10-a12-mapped-Q3R5.md) |
| A12-1 | Mapped | Not run | Whole case not run: linked evidence is partial or does not establish the full current contract. No matching execution evidence identified |
| A12-3 | Mapped | Not run | Whole case not run: linked evidence is partial or does not establish the full current contract. [Q3R5](2026-10-31-wux2-a10-a12-mapped-Q3R5.md) |
| A12-4 | Mapped | Not run | Whole case not run: linked evidence is partial or does not establish the full current contract. [Q3R5](2026-10-31-wux2-a10-a12-mapped-Q3R5.md) |
| A12-6 | Mapped | Not run | Whole case not run: linked evidence is partial or does not establish the full current contract. No matching execution evidence identified |
| A13-5 | Mapped | Not run | Whole case not run: linked evidence is partial or does not establish the full current contract. No matching execution evidence identified |
| A13-2 | Mapped | Not run | Whole case not run: linked evidence is partial or does not establish the full current contract. [T6F9](2026-10-31-wux2-a13-a25-a27-T6F9.md) |
| A13-4 | Mapped | Not run | Whole case not run: linked evidence is partial or does not establish the full current contract. [T6F9](2026-10-31-wux2-a13-a25-a27-T6F9.md) |
| A25-3 | Mapped | Not run | Whole case not run: linked evidence is partial or does not establish the full current contract. [T6F9](2026-10-31-wux2-a13-a25-a27-T6F9.md) |
| A27-2 | Mapped | Not run | Whole case not run: linked evidence is partial or does not establish the full current contract. [T6F9](2026-10-31-wux2-a13-a25-a27-T6F9.md) |
| A27-3 | Mapped | Not run | Whole case not run: linked evidence is partial or does not establish the full current contract. No matching execution evidence identified |
| A29-1 | Mapped | Not run | Whole case not run: linked evidence is partial or does not establish the full current contract. [V6T3](2026-10-31-wux2-a29-sentry-V6T3.md) |
| A29-3 | Mapped | Not run | Whole case not run: linked evidence is partial or does not establish the full current contract. No matching execution evidence identified |
| A29-4 | Mapped | Not run | Whole case not run: linked evidence is partial or does not establish the full current contract. [V6T3](2026-10-31-wux2-a29-sentry-V6T3.md) |
| A29-5 | Mapped | Not run | Whole case not run: linked evidence is partial or does not establish the full current contract. [V6T3](2026-10-31-wux2-a29-sentry-V6T3.md) |
| A29-6 | Mapped | Not run | Whole case not run: linked evidence is partial or does not establish the full current contract. [H6B3](2026-10-31-wux2-a0506-pending-social-H6B3.md), [D3F7](2026-10-31-wux2-a0512-turnstile-D3F7.md) |
| A29-7 | Mapped | Not run | Whole case not run: linked evidence is partial or does not establish the full current contract. [V6T3](2026-10-31-wux2-a29-sentry-V6T3.md) |
| A29-9 | Mapped | Not run | Whole case not run: linked evidence is partial or does not establish the full current contract. No matching execution evidence identified |
| A34-5 | Mapped | Not run | Whole case not run: linked evidence is partial or does not establish the full current contract. No matching execution evidence identified |

- Additional 40-row counts: pass 0, fail 0, not run 40, not needed 0, unjudged 0. Combined candidate union: pass 4, fail 2, not run 163, not needed 1, unjudged 0 (170 candidates).

## Focused current-session run for A09-1, A11-4 and A11-10

With the configured local test environment, the selected browser gate and JWKS verifier tests passed twice; the verbose run identified six cases, 33 assertions, 0 failures, 0 errors and 0 skips. The relevant test methods were `SignInPathBrowserAllowlistTest#test_Auth_sign-in_pages_answer_an_outdated_browser_with_406_on_every_credential_surface`, `ContentSurfaceBrowserGateTest#test_the_html_landing_page_still_gates_outdated_browsers`, `OidcJwksRefetchLimiterTest#test_a_held_key_verifies_while_Valkey_is_unavailable_and_Valkey_is_not_consulted`, and `OidcOpProtocolVerifiersTest#test_non_ES384_OP_tokens_are_refused_before_fetching_keys`. The run used `-n /outdated|old.*browser|held_key_verifies|non_ES384_OP_tokens/`; its two other selected tests also passed. These are local representative checks, not deployed browser, Valkey or provider tests.

## Original 166-case set recovery

The archive and all available Git history contain the later 130-row Not run table and a separate 56-row Mapped table (16 overlap; union 170). They do not reconstruct the original 166-row snapshot. The 36-row difference is uncollected, with no identified case IDs; it is explicitly uncollected and is not padded with invented rows. Candidate dispositions above are individual case-level classifications for the available 170 IDs; “Not run” means no complete current-contract acceptance run exists, even where a partial probe is linked.

## Closure checks on 2026-10-31

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`. The worktree remained uncommitted, with extensive pre-existing WU-3–7/A1 and other staged, unstaged, and untracked changes; this work did not commit or reset them.
- The Base ORG `/settings` route and role-owner follow-up passed in `PREFERENCE_COM_JWT_ISSUER=https://www.umaxica.com PREFERENCE_COM_JWT_AUDIENCE=com PREFERENCE_COM_JWT_REVOKED_KIDS='' PARALLEL_WORKERS=1 bin/rails test test/lib/runtime_role_route_ownership_test.rb test/controllers/base/settings_authority_slice_1g_test.rb test/tooling/architecture_baseline_test.rb`: 24 runs, 2,435 assertions, 0 failures, 0 errors, 0 skips. This covers the two runtime-role ownership methods, the updated Base settings route assertion, and the architecture baseline after regeneration.
- The dedicated route contract passed with the same required environment: `bin/rails test test/config/org_settings_routes_test.rb`: 3 runs, 17 assertions, 0 failures, 0 errors, 0 skips. `bundle exec rubocop lib/runtime_role.rb test/controllers/base/settings_authority_slice_1g_test.rb` inspected two files with no offenses.
- `git diff --check` reported existing trailing whitespace at `Gemfile:209` (`# herb `), in a pre-existing uncommitted change; this line was not edited in the X work.
- One earlier targeted invocation without the COM JWT variables stopped during application boot with `preference_com issuer is missing`; the successful targeted rerun used the explicit variables above.
- The single full-suite run was `PREFERENCE_COM_JWT_ISSUER=https://www.umaxica.com PREFERENCE_COM_JWT_AUDIENCE=com PREFERENCE_COM_JWT_REVOKED_KIDS='' PARALLEL_WORKERS=1 bin/rails test`: 16,779 runs, 164,078 assertions, 111 failures, 109 errors, 0 skips. Compared with `plans/2026-10-28-baseline-failing-tests.md`, there were 7 exact-ID failures outside the baseline and 6 method-normalized failures outside it. The exact IDs were `ArchitectureBaselineTest#test_baseline_does_not_list_resolved_files`, `Auth::App::Verification::SetupsControllerTest#test_an_admitted_bootstrap_shows_the_registration_methods_and_cancellation,_never_a_back_link`, `BaseSettingsAuthoritySlice1GTest#test_base_com_and_org_settings_shell_routes_are_removed`, `DatabaseReconstructionAuthorityTest#test_committed_structure_dumps_contain_real_table_definitions`, `HtmlTitleContractTest#test_non-root_pages_render_the_localized_page_title_before_the_brand`, `RuntimeRoleRouteOwnershipTest#test_every_owning_role_is_a_known_runtime_role`, and `RuntimeRoleRouteOwnershipTest#test_every_routed_application_controller_has_an_owning_role`.
- The four route/role/baseline IDs in that list were subsequently covered by the passing focused run above. The full suite was not rerun after those focused fixes, so post-fix full-suite comparison is unverified. The Auth APP admitted-bootstrap test returned 400 instead of its expected 303. Its GET omits `Sec-Fetch-Mode: navigate` and `Sec-Fetch-Dest: document`, which `AuthCeremonyAdmission#invalid_admission_navigation?` now requires for an admission GET. `two.md` assigns that shared admission file to WU-A1/A3; the failure is outside X and was not changed. The baseline has the same method under Auth COM, so the exact surface ID differs. The new HTML non-root title method also failed in a focused 18-run/933-assertion run (2 failures total in that file); the other failure, the localized-title method, is already in the baseline. The title test enters Auth APP through the admission flow; the failing stage is not reported by its assertion, so no narrower WU attribution was established.
- The reconstruction test reported 23 empty dumps outside `db/structure.sql` and `db/publishing_structure.sql`. Those files were not regenerated, as instructed. The two requested dumps were regenerated and have 8 and 159 table definitions; the aggregate reconstruction test still has the 23-file failure. The truncation command/WU for those other files remains unknown. See [the dump recovery record](2026-10-31-wux-structure-dumps-R7T3.md).
- Current documentation now records the owner-approved Base ORG URL exception and its separation from Auth APP/ORG identity settings. The accepted generic `/configurator` rule remains for new routes; the Auth ORG `/configuration` transfer endpoint and Base ORG old URL have no alias.
- X1 remains dependent on WU-9 for the uncreated database-consistency targets; the prior six-table COM check covers only the listed WU-7 tables. The N5 AGENTS.md authority wording remains unresolved and unchanged without owner approval. X2 remains dependent on X1 and the target WUs; the original 166-case ID list is still uncollected. No production, Neon, or external-repository operation was performed.
