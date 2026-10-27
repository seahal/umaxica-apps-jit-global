# seven.md — Acceptance reconciliation and execution (2026-10-26)

> Archived 2026-10-27 from the working file `seven.md` (cycle archive 0002; frozen, not maintained).

Working document (gitignored). Role: reconcile `three.md` §2 acceptance statuses with what has
actually been executed, map open cases to tests, then execute unit by unit. `three.md` stays the
acceptance definition; results are merged back into it at cycle close (Codex may edit `three.md`
while this file is in progress).

## Scope and rules

- The sign-out suite A14, A15, A16, A22 and A44-6/A44-10 is returned to the cycle; see `ten.md` §4.
- Deferred until the current Codex batch finishes: WU-19 (i18n), WU-20, WU-26, WU-30, WU-38, WU-43.
- Evidence files dated 2026-10-16 … 2026-10-18 (`r2-*`, `r3-*`, `r5-*`) belong to the earlier OP/RP
  separation cycle and use different WU numbers; they are not evidence for this cycle.
- A "Passed" recorded on 2026-10-23 was run against `6e4d70d0b` + the worktree of that day. The
  worktree has since changed substantially (Design D admission, Visa OP/Base RP, WU-10, WU-24h,
  D-177 … D-179). Every such case is **Passed (stale)** until re-run in stage 3.
- Stage 3 judges a unit by its own mapped tests. Full-suite failures inside the unit's area are
  fixed or reassigned with a reason (G-1); 2026-10-26 full suite: 454 problems in 108 files
  (`evidence/2026-10-26-codex-batch-check-K3C9.md`).

## Sign-out acceptance (SO-5)

The per-case dispositions are in `three.md` and `evidence/2026-10-26-sign-out-so5-acceptance-G5P8.md`.
The selected suite has failures, and G-16/G-20 have not been accepted. The owner browser check remains
open. A14-18 uses freshly issued test credentials rather than an end-to-end new sign-in.

## Stages

| Stage | Content | Uses test DB | Status |
|---|---|---|---|
| 1 | Write back executed results from `three.md` §4 and evidence | No | Done (below) |
| 2 | Map every open case to existing tests; list cases with no test | No | Done for 1b units (2026-10-26) |
| 3 | Run mapped tests per unit; record; decide on missing tests with the owner | Yes | Selected runs complete; case-level gaps and failures remain open; see `evidence/2026-10-27-cycle-stage3-resume-R4J6.md` |

## Stage 1 — executed results not reflected in `three.md` §2

### 1a. Units with a `three.md` §4 row

| Unit | Passed (stale) | Not run / open (as recorded) | Evidence |
|---|---|---|---|
| WU-01 | A01-1, A01-2, A01-4 | A01-3 deviation; A01-5 deviation (listed in L0R1); A01-6 superseded (D-168) | `2026-10-23-wu01-local-sign-in-flow-removal-L0R1.md` |
| WU-03 | A03-1, A03-2, A03-3 | — | `2026-10-23-wu03-edge-cookie-removal-E3C1.md` |
| WU-04 | A04-1 … A04-7 | — | `2026-10-23-wu04-telephone-otp-turnstile-T4P1.md` |
| WU-09 | A09-1, A09-2 | — | `2026-10-23-wu09-browser-allowlist-B9A1.md` |
| WU-11 | A11-1, A11-3 … A11-7, A11-10 … A11-12 | A11-2 (not listed); A11-8 and request-level BCL 503 (logout-related) | `2026-10-23-wu11-jwks-refetch-limit-J1K5.md`; later `2026-10-25-wu11-jwks-limits-W7Q3.md`, `-negative-cache-N4C7.md`, `-concurrent-jwks-C1J8.md` |
| WU-17 | A17-1, A17-2, A17-3 | A17-4 n/a (D-159/D-168) | `2026-10-23-wu17-contract-epoch-removal-K7E0.md` |
| WU-23 | A23-1 | — | `2026-10-23-wu23-wu39-decision-records-A9D3.md` |
| WU-24 | A24-1, A24-2, A24-5, A24-6, A24-7, A24-9; A24-3, A24-4, A24-10 (H8P2) | No whole-unit acceptance; A24-0/5a/5b/5c/8 n/a (D-159) | `2026-10-23-wu24b-…-I4B6.md`, `-wu24cd-…-C7D4.md`, `-wu24e-…-A6C4.md`, `2026-10-24-wu24h-binding-ownership-H8P2.md`, `2026-10-25-wu24h-dead-social-readers-D24S.md` |
| WU-31 | A31-1, A31-2, A31-3 (sequential form) | A31-3 two-connection form | `2026-10-23-wu31-email-otp-retained-result-O3R1.md` |
| WU-32 | A32-1, A32-2, A32-4, A32-5 | A32-3 (no non-mocked failing write) | `2026-10-23-wu32-org-halt-audit-H2C9.md` |
| WU-35 | A35-3 | A35-1 (report delivered, `two.md` 6.2); A35-2 Passkey save/termination HTTP race (later `2026-10-24-wu24e-passkey-http-races-P4R1.md`, partial) | `2026-10-23-wu24e-…-A6C4.md` |
| WU-36 | A36-1, A36-2 (option level) | Per-endpoint Set-Cookie sweep | `2026-10-23-wu36-host-only-cookies-C6H1.md` |
| WU-37 | A37-1 (provisional estimate) | A37-2 (no load test; deployment input) | `2026-10-23-wu41-wu37-db-timeouts-puma-D4P7.md` |
| WU-39 | A39-1 | Later amendments since 2026-10-23 not checked | `2026-10-23-wu23-wu39-…-A9D3.md`, `2026-10-24-wu33-wu39-docs-final-D4M8.md` |
| WU-40 | A40-1, A40-4, A40-5 | A40-2, A40-3 (unchanged paths, not re-measured) | `2026-10-23-wu40-recovery-otp-turnstile-R4T0.md` |
| WU-41 | A41-1 … A41-3 (production values pending deploy) | — | `2026-10-23-wu41-wu37-…-D4P7.md` |
| WU-42 | A42-1 … A42-4b, A42-7 … A42-13 | A42-5 negative boot; A42-6 (Jump) | `2026-10-23-wu42-redirect-uri-conformance-R2U4.md` |

### 1b. Units with evidence but no `three.md` §4 row

Case-level results must be read from the evidence in stage 2; none is assumed passed here.

| Unit | Evidence (this cycle) | Open points recorded in the evidence |
|---|---|---|
| WU-02 | `2026-10-24-wu02-visa-host-separation-V2F1.md`, `-wu02-review-test-migration-R2V7.md`, `2026-10-25-visa-controller-boundaries-V8C2.md`, `-visa-public-roots-V3R8.md`, `-visa-op-start-and-result-V4O9.md`, `-visa-home-auth-style-H3V6.md` | Tests still expecting Base hosts; ORG root login establishment, result browser binding and social flow contract groups unverified; Jump integration not run |
| WU-05 | `2026-10-24-wu05abc-…-W5AC.md`, `-wu05dg-social-sign-up-in-auth-W5DG.md` | End-to-end six-path journey not certified |
| WU-06 | `2026-10-24-wu06-sign-in-path-curfew-C6W0.md`, `-wu06-carried-ttl-verification-H6T4.md`, `-wu06-identity-stop-serialization-W6S1.md` | A06-1 exact 30:00.000, A06-4, A06-5, A06-6a … c not run |
| WU-07 | `2026-10-24-wu07-wu29-refusal-sentry-7H2K.md` | — (to read) |
| WU-08 | `2026-10-24-wu08-callback-matrix-M8C4.md`, `-wu08-social-callback-matrix-S8M0.md` | Deployment/provider-network verification not run |
| WU-10 | `2026-10-25-wu10-standard-refresh-R7K2.md` | — (to read) |
| WU-12, WU-13 | `2026-10-24-wu12-wu13-continuations-9Q4M.md` | Cross-unit acceptance and Jump/Edge integration unverified |
| WU-18 (18a) | none this cycle; 18c … 18f deferred (D-175) | A18-1/A18-2 open |
| WU-25, WU-27 | `2026-10-24-wu25-wu27-oidc-rp-boundaries-X7P2.md` | — (to read) |
| WU-29 | `2026-10-24-wu07-wu29-refusal-sentry-7H2K.md` | — (to read) |
| WU-33 | `2026-10-24-wu33-wu39-docs-final-D4M8.md` | — (to read) |
| WU-34 | `2026-10-24-wu34-unfinished-registration-sign-in-refusal-U34R.md` | — (to read) |

### 1c. Deferred units (current Codex batch)

WU-19, WU-20 (A20-9 resolved by the 2026-10-26 ADR amendment: Employee Number = `Operator.public_id`),
WU-26, WU-30, WU-38, WU-43.

## Stage 2 — case-to-test mapping

Method: read the case in `three.md` §2, the unit's evidence, and search `test/` for test names and
assertions. Classification:

- **Mapped**: a named test asserts the expected outcome.
- **Partial**: tests cover part of the expected outcome; the uncovered part is named.
- **Gap**: no test found for the expected outcome.
- **Evidence**: the case is verified by running something and recording it, not by Minitest.
- **N/A / Out**: not applicable, or out of scope (reason given).

Mapping is from reading only; a mapped test may currently fail (stage 3 runs it).

### WU-02 — Visa OP / Base RP

| Case | Class | Tests / note |
|---|---|---|
| A02-1 | Mapped | `test/integration/routes/base_authority_route_contract_test.rb` "Visa protocol routes are exclusive to Visa and refuse Base, Auth, and look-alike hosts"; `test/integration/routes/oidc_discovery_route_stability_test.rb` |
| A02-2 | Mapped | same route contract test; `test/integration/visa_roots_test.rb` "look-alike Visa hosts remain unknown" |
| A02-3 | Evidence | boot probe recorded in `2026-10-24-wu02-visa-host-separation-V2F1.md`; re-run on the current worktree |
| A02-4 | Mapped | Discovery, verified ID and Logout Tokens, and error/code authorization response builders match in all realms. `evidence/2026-10-27-cycle-partial-boundaries-C4S9.md`. |
| A02-5 | Mapped | `test/services/acceptance_wu02_visa_base_issuer_test.rb` covers retired `www` issuers on ID Tokens and Access JWTs; `test/integration/acceptance_wu02_client_assertion_audience_test.rb` verifies the token endpoint rejects retired client-assertion audiences for client, visitor and operator realms |
| A02-6 | Mapped | `test/integration/acceptance_wu02_jwks_separation_test.rb` asserts disjoint Visa/Base `kid` and key material in all realms |
| A02-7 | Partial | `test/integration/oidc_rp_browser_flow_test.rb`, `root_login_establishment_flow` tests; per-host cookie jars and "Visa `reset_session` leaves the Base pending flow" not found as an explicit assertion |
| A02-8 | Partial | Re-verification → Base: "the protected GET returns to Base verification with its original operation scope"; Edit/Base ORG return: `oidc_rp_logout_edit_return_test.rb`. Sign-in/sign-up result → Visa per realm and "missing Visa setting does not fall back": not found |
| A02-9 | Mapped | `test/integration/acceptance_wu02_ceremony_purpose_host_test.rb` asserts wrong-host/purpose refusal leaves binding, ceremony and transaction unchanged |
| A02-10 | Mapped | All Visa handoff rows match verified signed issuer/destination and allowed graph; external Jump is separate A02-14. `evidence/2026-10-27-cycle-partial-boundaries-C4S9.md`. |
| A02-11 | Out | logout suite |
| A02-12 | Mapped | `test/security/invariants/acceptance_wu02_base_op_session_isolation_test.rb` checks Auth-written session keys are not read by Base; `test/integration/acceptance_wu02_base_rp_state_test.rb` exercises `/welcome` and `/selector` with RP state only |
| A02-13 | Mapped | `base_authority_route_contract_test.rb` "base authority retired routes do not resolve"; `oidc_rp_browser_flow_test.rb` "legacy RP authorize and callback paths are unroutable". The case asks each Base exception to be listed in the test: not checked |
| A02-14 | N/A | Not run by definition: Jump change pending (H8, D-161 (2)) |
| A02-15 | Partial | Provider callback routes are absent on Visa in all realms; unchanged provider redirect and full-host behavior remain open. `evidence/2026-10-27-cycle-partial-boundaries-C4S9.md`. |
| A02-16 | N/A | Transitional check between 02-APP and 02-COM; all three realms are migrated |

## Stage 3 — execution record

The resumed WU-30, WU-38 and WU-43 selected runs are recorded in `evidence/2026-10-27-cycle-stage3-resume-R4J6.md`; WU-38 has two deadline failures. WU-26 is withdrawn (D-196). Case-level results remain open where the selected tests do not cover them.

The 2026-10-26 selected unit runs and failures are recorded in `evidence/2026-10-26-cycle-stage3-execution-V4F2.md`. File-level results do not by themselves close cases with partial or missing mappings. WU-30 was interrupted and WU-38/43 remain unrun; the owner-held A34-2 APP Secret and COM OTP decisions remain open.

WU-44 remaining acceptance has started; the other unit runs remain unstarted.

### WU-44 — remaining acceptance

| Case | Status | Test / note |
|---|---|---|
| A44-2 | Passed | `evidence/2026-10-26-wu44-writer-check-N6K3.md` |
| A44-4 | Partial | The stale in-memory actor test passes; real replica lag remains unverified. `evidence/2026-10-26-wu44-writer-check-N6K3.md` |
| A44-5 | Blocked | No actual writer outage attempted; `evidence/2026-10-26-wu44-writer-check-N6K3.md` |
| A44-6 | Passed | All three cases passed after supplying the signer issuer. `evidence/2026-10-26-wu44-writer-check-N6K3.md` |
| A44-7 | Passed | `test/security/invariants/root_token_creation_invariant_test.rb:15`; 1 run, 2 assertions. |
| A44-9 | Deferred — backlog | `docs/backlog/2026-10-26-credential-version-recheck-at-root-issuance.md` |
| A44-10 | Failed | Independent revocation test timed out; `evidence/2026-10-26-wu44-writer-check-N6K3.md` |

### WU-05 — Sign-up six-path unification

| Case | Class | Tests / note |
|---|---|---|
| A05-1 | Evidence | `adr/sign-up-finalization-in-auth.md` exists (W5AC); commit order is the owner's (nothing committed yet) |
| A05-2 | Mapped (via WU-24b) | `AuthEntryIntentResolver` tests and the sign-up-page refusal tests of WU-24b (`2026-10-23-wu24b-effective-entry-intent-I4B6.md`); COM coverage to confirm in stage 3 |
| A05-3 | Mapped | `test/controllers/auth/app/social/ceremony_entry_test.rb` "a sign-up callback without its entry Flow is refused and creates no Flow"; Flow expiring at the curfew not asserted there |
| A05-4 | Mapped | `test/services/social_callback_state_matrix_test.rb` (L1/L2), see WU-08 |
| A05-5 | Mapped (known red) | `SocialAuthLoginTest` "Google/Apple sign up entry with existing identity falls through to sign in flow", "… login with existing identity does not create new user"; `OmniauthCallbacksTest` "should sign in with existing Google user" — red since G-1 (session fixation containment) |
| A05-6 | Partial | `SocialLoginAdmissionTest` "an unknown signup completes …", `test/controllers/auth/app/sign/up/check/google/birthdates_controller_test.rb`, `social_auth_login_handler_test.rb`; cleanup on expiry/cancel/halt of the pending social Client not found by name |
| A05-7 | Partial | Candidate storage, expiry and consumption are covered. An injected OP database-clock failure makes fetch and consume raise without consuming the candidate; an actual database outage and store failure remain unverified. `evidence/2026-10-27-social-candidate-failure-B6N4.md`. |
| A05-8 | Partial | `SocialAuthSignupFinalizerTest` (W5DG), `test/policies/sign_up/finalization_database_clock_test.rb`, `test/services/sign_up/contracts_test.rb`; one shared finalizer for all six paths and the idempotent second run not found as one assertion |
| A05-9 | Partial | `test/services/social_auth_link_concurrency_test.rb` (link, not sign-up) — separate-connection concurrent sign-up for one subject not found |
| A05-10 | Mapped | `SocialLoginAdmissionTest` "an unknown signup completes …" drives Sign In First to exactly one Root |
| A05-11 | Evidence | removal recorded in W5DG; re-run the dead-code search (`commit_signup!`, `committed_signup!`, `commit_login!`, `commit_link!`, Base social completion) |
| A05-12 | Mapped | Google and Apple confirmation requests supply action, request hostname and Flow public ID to the verifier; separate verifier tests reject each mismatched field. `evidence/2026-10-27-social-turnstile-binding-K3V5.md`. |
| A05-13 | Partial | COM social entry and callback routes are absent; COM effective-intent assertions remain open. `evidence/2026-10-27-cycle-partial-boundaries-C4S9.md`. |

Known coverage gap from W5DG: an Avatar/graph failure after the decisive commit has no test.

### WU-06 — Curfew

| Case | Class | Tests / note |
|---|---|---|
| A06-1 | Partial | APP admitted page is served one second before curfew and cancels at and one second after curfew; the remaining consumers have not all been checked at those boundaries. `evidence/2026-10-27-cycle-curfew-boundary-Q5F8.md`. |
| A06-2 | Mapped | `test/services/base_result_acceptance_curfew_test.rb` |
| A06-3 | Mapped | `admission_curfew_test.rb` "a social entry after the 60-second Binding expiry, within the curfew" |
| A06-4 | Mapped | `test/integration/admission_curfew_test.rb` now checks APP/COM/ORG Auth ceremony expiry equals the stored curfew and the before/at/after boundary; 1 run/42 assertions passed |
| A06-5 | Partial | Transport, result delivery and authorization-code expiry are capped by curfew; an authorization code is refused without consumption at its capped expiry. Method-specific ceremony TTL caps remain unverified. `evidence/2026-10-27-cycle-code-expiry-G2T8.md`. |
| A06-6a | Partial | `test/policies/sign_up/finalization_database_clock_test.rb` (deadline check); lock-wait form not found |
| A06-6b | Mapped | `test/concurrency/sign_up_passkey_termination_http_test.rb` "A06-6b: a real principal lock wait crossing curfew keeps registration and refuses handoff" (1 run, 36 assertions passed) |
| A06-6c | Partial | Policy refusal retains the flow and actor; end-to-end finalizer and cleanup behavior remains open. `evidence/2026-10-27-cycle-test-entry-repairs-M8D2.md`. |
| A06-7 | Mapped | `admission_curfew_test.rb` (owner's browser after the curfew → transaction canceled, no token) |
| A06-8 | Mapped | `admission_curfew_test.rb` "a browser without the ceremony → no exit and the transaction unchanged" |
| A06-9 | Mapped | `admission_curfew_test.rb` "the owner's browser with the transaction row removed → uniform 400" |

### WU-07 — Refusal classes

| Case | Class | Tests / note |
|---|---|---|
| A07-0 | Mapped | `test/values/sign_in_path_refusal_value_test.rb` "each reason maps to one of the six classes", "an unknown reason is refused" |
| A07-1 | Partial | same file "ownership mismatch and definitive refusals share the uniform status" (value level); parameterized request tests over every definitive refusal not found |
| A07-1b | Partial | ownership refusals in `test/controllers/auth/app/social/ceremony_entry_test.rb`, `sign_up_admission_ownership_test.rb`; victim Flow/Candidate untouched asserted per test, not across all causes |
| A07-1c | Mapped | `test/controllers/auth/app/in/emails_controller_test.rb` "A07-1c: Turnstile rejection keeps the Flow and OTP challenge unconsumed" (passed) |
| A07-1d | Partial | `rp_refresh_recovery_test.rb` "a dependency failure keeps the credentials…" (RP side); Sign-in path 503 class not found |
| A07-1e | Mapped | `test/integration/social_callback_refusal_matrix_test.rb` "A07-1e/A08/A34-2: inconsistent and unfinished callbacks refuse with no authority" asserts 5xx, one redacted fatal audit event, and no authority allocation (passed) |
| A07-1f | Partial | protocol refusals in `test/integration/visa_authorization_start_boundary_test.rb`, `visa_authorization_continuations_test.rb` |
| A07-2 | Mapped | `test/integration/sign_entry_sentry_test.rb` and `test/integration/admission_curfew_test.rb` assert retryable continuity is kept and definitive refusal clears only the current browser's continuity (passed) |
| A07-3 | Mapped | `test/integration/sign_entry_sentry_test.rb` asserts one `sign.refused` event per refusal with a reason code and no request secrets (passed) |
| A07-4 | Out / Mapped | BCL receiver: Out (logout suite); Re-verification path: existing Base verification tests |

### WU-08 — Social callback matrix

| Case | Class | Tests / note |
|---|---|---|
| A08-1 | Mapped | `test/services/social_callback_state_matrix_test.rb` (28 partitions), `test/integration/social_callback_refusal_matrix_test.rb` (36 HTML partitions, L1 … L8) |
| A08-2 | Mapped | ban-precedence partitions in the service matrix; `social_auth_link_handler_test.rb` |
| A08-3 | Mapped | HTTP L4 cases in `social_callback_refusal_matrix_test.rb` (500, one FATAL, no subject disclosure) |
| A08-4 | Mapped | every HTTP callback in the refusal matrix asserts unchanged Client / Flow / external identity / Root counts |

Provider-network and deployment verification: not run (M8C4), outside Minitest.

### WU-10 — Standard refresh

| Case | Class | Tests / note |
|---|---|---|
| A10-1 | Mapped | `test/services/oidc/token_exchange_service_test.rb` "D-25: every refresh use rotates and the consumed predecessor is never accepted again" |
| A10-2 | Mapped | same file "D-25: reuse of a consumed refresh token is invalid_grant and revokes only that grant's family" (Root intact to confirm in stage 3). Known limit (R7K2): only the immediate predecessor is detected as reuse |
| A10-3 | Mapped | same file "D-25: an unknown verifier for an existing grant and a garbage token revoke nothing" |
| A10-4 | Mapped | Removed route refused on three Visa hosts and old code references absent; `evidence/2026-10-27-cycle-partial-boundaries-C4S9.md`. |
| A10-5 | Mapped | `test/integration/rp_refresh_recovery_test.rb` "a refused refresh on a navigation starts one prompt=none authorization…" |
| A10-6 | N/A | D-168 |

### WU-12 — Automatic relays (Design D)

| Case | Class | Tests / note |
|---|---|---|
| A12-1 | Mapped | `test/integration/base_dashboard_passkey_login_journey_test.rb` (APP/COM) and `base_org_dashboard_local_login_journey_test.rb` assert automatic redirects and request counts through the full Dashboard login path (3 tests passed) |
| A12-2 | Partial | A live Visa confirmation binding rejects a foreign browser without changing binding or ceremony state; foreign-browser refusal remains unverified for each other hop. `evidence/2026-10-27-cycle-relay-boundaries-P7Q3.md`. |
| A12-3 | Mapped | `test/integration/acceptance_wu12_relay_repeat_test.rb` now enforces the absolute issuance + 10 s deadline and snapshots binding, ceremony, session count, admission-store payload and cookies; 1 run/25 assertions passed |
| A12-4 | Mapped | `acceptance_wu12_relay_repeat_test.rb` expired-attachment case passed (1 run/5 assertions); `test/controllers/auth/ceremony_admission_boundary_test.rb` consumed-relay case passed (1 run/12 assertions) |
| A12-5 | Partial | Live Visa confirmations refuse iframe on APP/COM/ORG without changing binding or ceremony; APP HEAD is refused and missing Fetch Metadata renders a non-consuming form. Live bindings on other hops remain unverified. `evidence/2026-10-27-a12-5-visa-confirmation-frame-D4K8.md`. |
| A12-6 | Mapped | `test/integration/oidc_initiated_sign_in_completion_test.rb` repeated final result case passed (1 run/34 assertions) |

### WU-13 — Cancel and Switch

| Case | Class | Tests / note |
|---|---|---|
| A13-1 | Partial | "Cancel on the first Sign In page returns access_denied with state and iss to the RP", "Com Cancel …", "Org Cancel …", `test/integration/rp_sign_interruption_test.rb`; Cancel from a Sign-up page not found by name. `oidc_rp_completion_matrix_test.rb` listed in 9Q4M was deleted with the logout change |
| A13-5 | Mapped | APP/COM/ORG cancellation and opaque reserved/multibyte state checks passed. `evidence/2026-10-27-cycle-partial-boundaries-C4S9.md`. |
| A13-2 | Mapped | `test/services/base_switcher_authority_test.rb`, `test/controllers/base/{app,com}/switcher*_test.rb` (deadline kept to confirm) |
| A13-3 | Mapped | "Org Cancel returns access_denied, and Org offers no Switch"; `base/org/switcher_controller_test.rb` |
| A13-4 | Mapped | Owner-approved definition now follows D-38: reject with 400 before allocation. `test/integration/acceptance_wu13_authorize_unrelated_params_test.rb` passed (1 run/1 assertion covering all six APP/COM/ORG requests) |

### WU-18 — Pre-R5 OP-chain removal

| Case | Class | Tests / note |
|---|---|---|
| A18-1 | Evidence | 18a inventory recorded in `two.md` (WU-18a); no evidence file of this cycle |
| A18-2 | Out | 18c … 18f deferred to a later cycle (D-175) |
| A18-3 | N/A | D-159, D-168 |

### WU-25 — Revocation client authentication

| Case | Class | Tests / note |
|---|---|---|
| A25-1 | Partial | `test/services/oidc_token_revocation_service_coverage_test.rb`; per-client registered method on Visa app/com/org as request tests not found |
| A25-2 | Partial | "refresh token revocation ignores tokens for another client"; wrong realm / audience / replayed assertion not found by name |
| A25-3 | Mapped | `test/services/oidc/discovery_document_test.rb` (methods advertised from the client registry) |

### WU-27 — Post-containment journey

| Case | Class | Tests / note |
|---|---|---|
| A27-1a | Partial | X7P2 states the result path is terminal and browser-bound; request test for "lost response then repeat → error, no reissue" not found by name |
| A27-1b | Failing | `test/controllers/base/oidc_result_browser_binding_test.rb:151` ran after rebuild but errored before assertions: `NoMethodError`, undefined `session` for nil at test line 158; this is not the prior fixture FK failure |
| A27-2 | Mapped | `test/controllers/base/oauth_oidc_authority_test.rb` "A27-2/A29-8: SSO codes reuse the Root while Sign In is blocked" asserts no second Root (passed) |
| A27-3 | Mapped | OP `test/controllers/base/oidc_result_browser_binding_test.rb:270` passed (1 run/12 assertions); RP `test/controllers/concerns/oidc/sso_initiator_test.rb:161` passed (1 run/5 assertions) |
| A27-4 | Evidence | TR G2/G3/G5 rewrites need a diff review; not recorded |

### WU-29 — Sign entry Sentry

| Case | Class | Tests / note |
|---|---|---|
| A29-1 | Mapped | `test/resolvers/sign_entry_sentry_resolver_test.rb` "every registered pair maps explicit true to ALLOWED", "false and unwritten availability are BLOCKED" |
| A29-2 | Mapped | same file "an unknown surface or flow is rejected" |
| A29-3 | Mapped | `test/integration/sign_entry_sentry_test.rb` "<surface> <flow> sentry redirects to its fixed entry when allowed", "… refuses without a cacheable response when blocked" |
| A29-4 | Mapped | `test/integration/acceptance_wu29_sign_entry_sentry_blocked_test.rb` accepts at most one state-free redirect hop before 503 and asserts no state allocation/change; targeted case passed (1 run/69 assertions) |
| A29-5 | Mapped | `test/integration/acceptance_wu29_root_login_sentry_test.rb` asserts blocked Root commit issues no token/cookie/audit and does not halt the flow (passed) |
| A29-6 | Mapped | `test/integration/social_login_admission_test.rb` "A29-6: Sign Up completes while Sign In is blocked without issuing a session" (passed) |
| A29-7 | Mapped | `test/integration/acceptance_wu29_sentry_toggle_test.rb` covers both flag-flip directions on the next request (passed) |
| A29-8 | Partial | Existing Refresh, SSO and `prompt=none` cases pass; `test/controllers/base/app/welcomes_controller_test.rb:17` passed (1 run/4 assertions) and `test/integration/app_passkey_secret_session_step_up_test.rb:16` passed (1 run/35 assertions). Sign Out remains excluded by the task constraint |
| A29-9 | Mapped | `test/controllers/auth/org/in/emergency/passkeys_controller_test.rb:165` passed (1 run/8 assertions); `test/controllers/auth/org/up/invitations_controller_test.rb:42` passed (1 run/6 assertions) |
| A29-10 | Evidence | `grep -rn "sign_up_suspended\|SignUpSuspension" app config test` currently returns no match (2026-10-26, read during stage 2); record in stage 3 |
| A29-11 | Evidence | `feature_flags:status` per environment not recorded |
| A29-12 | Failing | Six English requests receive Japanese refusal text; audit/telemetry absence remains unverified. `evidence/2026-10-27-cycle-partial-boundaries-C4S9.md`. |

Also: `test/security/invariants/feature_flag_registry_invariant_test.rb`.

### WU-33 — Failure convergence table

| Case | Class | Tests / note |
|---|---|---|
| A33-1 | Evidence | document review of `two.md` 5.4 (`2026-10-24-wu33-wu39-docs-final-D4M8.md`); not re-reviewed since D-177 … D-179 |

### WU-34 — Unfinished registrations refused

| Case | Class | Tests / note |
|---|---|---|
| A34-1 | Partial | `test/models/unfinished_registration_login_test.rb` (APP/COM, model level); AX26-1/AX26-2 as request tests not found |
| A34-2 | Partial | APP email OTP and APP social callback cases previously passed; reruns: APP TOTP passed (1 run/1 assertion), APP Passkey failed (1 run/10 assertions: expected 401, got 422), APP Secret errored (1 run/0 assertions: nil response body at test line 111), COM OTP failed (1 run/3 assertions: expected 422, got 403 session-limit refusal), COM Passkey errored (1 run/6 assertions: stale `Visitor` at test line 503). Valid OTP verification updates its challenge before refusal, outside this case's stated no-authority contract |
| A34-3 | Partial | registered case in `unfinished_registration_login_test.rb` (model level) |
| A34-4 | Partial | 16 COM sign-up/finalizer files use `UNVERIFIED_WITH_SIGN_UP` and promotion via `Visitor#promote_finished_registration!` (U34R); "existing COM data migrated with counts" N/A after D-159 reset |
| A34-5 | Mapped | `test/integration/acceptance_wu34_registered_commit_failure_test.rb` covers a post-commit graph failure, later sign-in completion, and cleanup recovery (passed) |

Execution follow-up (2026-10-26): the documented test-only rebuild completed without the HMAC
definer-role failure. The client/operator orphan queries were empty before the rebuild and after
each of 170 candidate test files, run individually in two full passes; no leaking file or narrow
leaking set was reproduced. The earlier `client_chronicles.event_id = 36` fixture error did not
recur in the 15 fixture-blocked line cases. Ten of those 15 cases passed; A27-1b and four A34-2
method cases still fail or error as itemized above. A29-8 Sign Out remains out of scope.

## Stage 2 summary (1b units)

| Unit | Mapped | Partial | Gap | Evidence | N/A / Out |
|---|---|---|---|---|---|
| WU-02 | 3 | 6 | 4 | 1 | 2 / 1 |
| WU-05 | 4 | 7 | 0 | 2 | 0 |
| WU-06 | 5 | 4 | 2 | 0 | 0 |
| WU-07 | 1 | 4 | 5 | 0 | 1 |
| WU-08 | 4 | 0 | 0 | 0 | 0 |
| WU-10 | 4 | 1 | 0 | 0 | 1 |
| WU-12 | 0 | 2 | 4 | 0 | 0 |
| WU-13 | 2 | 2 | 1 | 0 | 0 |
| WU-18 | 0 | 0 | 0 | 1 | 2 |
| WU-25 | 1 | 2 | 0 | 0 | 0 |
| WU-27 | 0 | 1 | 3 | 1 | 0 |
| WU-29 | 3 | 1 | 6 | 2 | 0 |
| WU-33 | 0 | 0 | 0 | 1 | 0 |
| WU-34 | 0 | 3 | 2 | 0 | 0 |

"Gap (to confirm)" counts as Gap. Units in 1a (Passed (stale)) are re-run in stage 3 with the tests
named in their evidence; they are not re-mapped here.

## Stage 2b — Codex request: tests for the Gap cases

Owner decision 2026-10-26: Codex writes tests for every **Gap** case of stage 2; Partial cases
follow in a second request. The instructions are in `eight.md`.
