# UMAXICA feature re-audit — current execution status

Revision: 2026-09-17 (cycle close; CYCLE_PASS_WITH_KNOWN_COVERAGE_DEBT pending final gates) HEAD at
cycle-close start: `cac794f88e473666832c78f043b87b15bb6bc38d` Historical planning-only NO_GO below
is not a current stop reason.

## 2026-09-17 cycle-close checkpoint

This cycle closes what current code, tests, and decisions can close. External devices, GUID
ownership, missing REQ-095 source, full `/web`/`/edge` migration, repository-wide
timestamp/visibility cleanup, and Ruby branch/method SimpleCov are next-cycle. Coverage thresholds
were not lowered.

Ruby SimpleCov: **DEFERRED_WITH_EXPLICIT_CYCLE_WAIVER** (not GREEN). Final measurement: line 98.33%
(58,004/58,985), branch 87.85% (8,674/9,873), method 93.80% (10,066/10,731); tests 13,098 / 79,395 /
0 failures / 3 skips; SimpleCov exit 2.

### REQ-001–095 classification

| ID      | Class                                                                                 |
| ------- | ------------------------------------------------------------------------------------- |
| REQ-001 | COMPLETE_ALREADY_SATISFIED                                                            |
| REQ-002 | COMPLETE_ALREADY_SATISFIED                                                            |
| REQ-003 | COMPLETE_ALREADY_SATISFIED                                                            |
| REQ-004 | COMPLETE_ALREADY_SATISFIED                                                            |
| REQ-005 | COMPLETE_ALREADY_SATISFIED                                                            |
| REQ-006 | COMPLETE_VERIFIED (this host / local `bin/ci`); other CI runners DEFERRED_NEXT_CYCLE  |
| REQ-007 | COMPLETE_VERIFIED                                                                     |
| REQ-008 | COMPLETE_VERIFIED                                                                     |
| REQ-009 | COMPLETE_VERIFIED                                                                     |
| REQ-010 | COMPLETE_VERIFIED (authority contract); UX DEFERRED_NEXT_CYCLE MISC-0004              |
| REQ-011 | COMPLETE_VERIFIED                                                                     |
| REQ-012 | COMPLETE_VERIFIED (existing acr/amr contract)                                         |
| REQ-013 | COMPLETE_VERIFIED (axes not collapsed); deeper policy DEFERRED_NEXT_CYCLE MISC-0003   |
| REQ-014 | COMPLETE_VERIFIED (SMS is `sms` amr, not phishing-resistant/AAL2)                     |
| REQ-015 | COMPLETE_VERIFIED                                                                     |
| REQ-016 | COMPLETE_VERIFIED (automated DPoP denial)                                             |
| REQ-017 | COMPLETE_ALREADY_SATISFIED                                                            |
| REQ-018 | DEFERRED_VALIDATION (MISC-0001)                                                       |
| REQ-019 | COMPLETE_ALREADY_SATISFIED                                                            |
| REQ-020 | COMPLETE_VERIFIED except coverage-green → DEFERRED_WITH_EXPLICIT_CYCLE_WAIVER         |
| REQ-021 | COMPLETE_ALREADY_SATISFIED (opaque 404 lookup; no generator)                          |
| REQ-022 | BLOCKED_BY_DECISION_NEXT_CYCLE                                                        |
| REQ-023 | COMPLETE_ALREADY_SATISFIED                                                            |
| REQ-024 | BLOCKED_BY_DECISION_NEXT_CYCLE                                                        |
| REQ-025 | COMPLETE_ALREADY_SATISFIED                                                            |
| REQ-026 | BLOCKED_BY_DECISION_NEXT_CYCLE                                                        |
| REQ-027 | COMPLETE_ALREADY_SATISFIED                                                            |
| REQ-028 | COMPLETE_VERIFIED                                                                     |
| REQ-029 | COMPLETE_VERIFIED                                                                     |
| REQ-030 | COMPLETE_VERIFIED                                                                     |
| REQ-031 | COMPLETE_VERIFIED                                                                     |
| REQ-032 | COMPLETE_VERIFIED                                                                     |
| REQ-033 | COMPLETE_VERIFIED                                                                     |
| REQ-034 | COMPLETE_VERIFIED                                                                     |
| REQ-035 | DEFERRED_NEXT_CYCLE                                                                   |
| REQ-036 | COMPLETE_VERIFIED                                                                     |
| REQ-037 | COMPLETE_VERIFIED                                                                     |
| REQ-038 | BLOCKED_BY_DECISION_NEXT_CYCLE (GUID/public net OpenAPI)                              |
| REQ-039 | COMPLETE_VERIFIED                                                                     |
| REQ-040 | COMPLETE_VERIFIED                                                                     |
| REQ-041 | COMPLETE_VERIFIED (Rails request/host; not physical browser)                          |
| REQ-042 | COMPLETE_VERIFIED                                                                     |
| REQ-043 | DEFERRED_VALIDATION                                                                   |
| REQ-044 | COMPLETE_VERIFIED                                                                     |
| REQ-045 | COMPLETE_VERIFIED for OIDC/auth event; repo-wide audit DEFERRED_NEXT_CYCLE            |
| REQ-046 | DEFERRED_NEXT_CYCLE                                                                   |
| REQ-047 | DEFERRED_NEXT_CYCLE                                                                   |
| REQ-048 | DEFERRED_NEXT_CYCLE                                                                   |
| REQ-049 | COMPLETE_VERIFIED for auth event time                                                 |
| REQ-050 | DEFERRED_WITH_EXPLICIT_CYCLE_WAIVER                                                   |
| REQ-051 | COMPLETE_VERIFIED                                                                     |
| REQ-052 | COMPLETE_VERIFIED                                                                     |
| REQ-053 | COMPLETE_VERIFIED (SecretKey is Entra second stage, owner-bound)                      |
| REQ-054 | COMPLETE_VERIFIED                                                                     |
| REQ-055 | DEFERRED_NEXT_CYCLE                                                                   |
| REQ-056 | COMPLETE_VERIFIED                                                                     |
| REQ-057 | COMPLETE_VERIFIED                                                                     |
| REQ-058 | COMPLETE_VERIFIED                                                                     |
| REQ-059 | COMPLETE_VERIFIED (in-process); real cluster DEFERRED_NEXT_CYCLE MISC-0007            |
| REQ-060 | COMPLETE_VERIFIED                                                                     |
| REQ-061 | COMPLETE_VERIFIED                                                                     |
| REQ-062 | COMPLETE_VERIFIED                                                                     |
| REQ-063 | COMPLETE_VERIFIED                                                                     |
| REQ-064 | COMPLETE_VERIFIED (this host); other CI runners DEFERRED_NEXT_CYCLE                   |
| REQ-065 | COMPLETE_ALREADY_SATISFIED                                                            |
| REQ-066 | DEFERRED_WITH_EXPLICIT_CYCLE_WAIVER                                                   |
| REQ-067 | DEFERRED_NEXT_CYCLE                                                                   |
| REQ-068 | DEFERRED_NEXT_CYCLE                                                                   |
| REQ-069 | DEFERRED_WITH_EXPLICIT_CYCLE_WAIVER for coverage-green; other gates COMPLETE_VERIFIED |
| REQ-070 | COMPLETE_ALREADY_SATISFIED                                                            |
| REQ-071 | COMPLETE_ALREADY_SATISFIED                                                            |
| REQ-072 | COMPLETE_ALREADY_SATISFIED                                                            |
| REQ-073 | COMPLETE_VERIFIED                                                                     |
| REQ-074 | COMPLETE_VERIFIED                                                                     |
| REQ-075 | COMPLETE_ALREADY_SATISFIED                                                            |
| REQ-076 | COMPLETE_VERIFIED                                                                     |
| REQ-077 | COMPLETE_VERIFIED                                                                     |
| REQ-078 | COMPLETE_VERIFIED                                                                     |
| REQ-079 | COMPLETE_VERIFIED                                                                     |
| REQ-080 | COMPLETE_VERIFIED                                                                     |
| REQ-081 | COMPLETE_VERIFIED                                                                     |
| REQ-082 | COMPLETE_VERIFIED                                                                     |
| REQ-083 | COMPLETE_ALREADY_SATISFIED                                                            |
| REQ-084 | COMPLETE_VERIFIED                                                                     |
| REQ-085 | COMPLETE_ALREADY_SATISFIED                                                            |
| REQ-086 | COMPLETE_ALREADY_SATISFIED                                                            |
| REQ-087 | COMPLETE_VERIFIED                                                                     |
| REQ-088 | COMPLETE_VERIFIED                                                                     |
| REQ-089 | COMPLETE_VERIFIED                                                                     |
| REQ-090 | COMPLETE_VERIFIED                                                                     |
| REQ-091 | COMPLETE_VERIFIED                                                                     |
| REQ-092 | COMPLETE_ALREADY_SATISFIED                                                            |
| REQ-093 | COMPLETE_VERIFIED                                                                     |
| REQ-094 | COMPLETE_VERIFIED                                                                     |
| REQ-095 | SOURCE_INCOMPLETE_NEXT_CYCLE                                                          |

## Previous checkpoint (2026-09-17 E10)

# UMAXICA feature re-audit — current execution status

Revision: 2026-09-17 (E10 reverse-direction closeout; not all-95 GO)

## 2026-09-17 E10 checkpoint

Focused isolated tests: 182 runs / 951 assertions / 0 failures twice. E1 owner-replay, fail-closed
family link, concurrent consume, consumed-stays-consumed, DPoP invalid proof without consume,
established DPoP no Bearer fallback: implemented-and-verified on coordinator/store/public token. E2
no-admission: implemented-and-verified. E3 T0 auth_time, prompt=login/none, max_age, com/org none:
implemented-and-verified on authorization/token paths. E7c Turnstile-before-OTP, degraded-on
unavailable-only, failed OTP not re-rendered: implemented-and-verified. E7b cookie deletion on Auth
sign-out: implemented-and-verified. GUID 404: already-satisfied. REQ-095: source-incomplete. D-GUID
persistence: blocked-by-decision. Physical DPoP: deferred-validation. Ruby SimpleCov 2026-09-17:
line 98.33% (meets 97), branch 87.83% / method 93.95% (below 90/95); gates unchanged. Ordinary Rails
and `bin/ci` green after ExplicitMethodVisibility on rails_performance patches. No deployment /
all-95 GO.

### REQ-001–095 dispositions (primary owner unchanged)

| IDs                             | Disposition                                                                                                        |
| ------------------------------- | ------------------------------------------------------------------------------------------------------------------ |
| REQ-001–005                     | already-satisfied (plan/worktree/audit)                                                                            |
| REQ-006, 064                    | already-satisfied on this host; CI service provisioning deferred-validation                                        |
| REQ-007–010, 032                | implemented-and-verified (admission boundary tests)                                                                |
| REQ-011, 030                    | implemented-and-verified for T0 claims, prompt/max_age, refresh auth_time; remaining RP matrix deferred-validation |
| REQ-012–014                     | already-satisfied containment; deeper AAL deferred-validation (MISC-0003)                                          |
| REQ-015, 028–029, 057–063       | implemented-and-verified locally for grant/refresh/owner; concurrent rotation deferred-validation                  |
| REQ-016                         | implemented-and-verified automated DPoP denial; physical deferred-validation (MISC-0001, REQ-018)                  |
| REQ-017                         | already-satisfied progressive enhancement                                                                          |
| REQ-018                         | deferred-validation                                                                                                |
| REQ-019                         | already-satisfied as plan/misc register                                                                            |
| REQ-020                         | implemented-and-verified horizontal: no weakened gates/skips; SimpleCov still red at unchanged floors              |
| REQ-021, 023, 025, 027          | already-satisfied transport 404; persistence blocked-by-decision                                                   |
| REQ-022, 024, 026, 038 net GUID | blocked-by-decision                                                                                                |
| REQ-033–044                     | already-satisfied / deferred-validation per route inventory; no `/dashboard` restore                               |
| REQ-045–049                     | implemented-and-verified no fabricated auth_time; historical backfill deferred-validation (MISC-0005)              |
| REQ-050, 066                    | deferred-validation for SimpleCov floors (evidence-backed red)                                                     |
| REQ-051–056                     | already-satisfied existing ORG paths; REQ-095 source-incomplete                                                    |
| REQ-065                         | already-satisfied                                                                                                  |
| REQ-067–069                     | already-satisfied gates; RuboCop red only on unrelated dirty files                                                 |
| REQ-070–072                     | already-satisfied social Step-Up ADR/tests                                                                         |
| REQ-073–074                     | implemented-and-verified cookie delete on Auth sign-out                                                            |
| REQ-075                         | already-satisfied distinct `/sessions`, `/sign/out`, Core `/api/v0/session`                                        |
| REQ-076–084                     | already-satisfied / deferred-validation UI matrix                                                                  |
| REQ-085–086                     | already-satisfied inert Create / Root Up                                                                           |
| REQ-087–091                     | implemented-and-verified Turnstile/OTP                                                                             |
| REQ-092                         | already-satisfied preload tests exist                                                                              |
| REQ-093–094                     | deferred-validation mail/i18n extras                                                                               |
| REQ-095                         | source-incomplete                                                                                                  |

## Previous checkpoint (2026-09-15)

# UMAXICA feature re-audit — current execution status (historical header retained below)

Revision: 2026-09-15 (E0 quality-gate continuation, previous checkpoint) Repository:
seahal/umaxica-apps-jit-global Branch / HEAD: feature / `e9fa72ce5fc0c9e62c9a5a7a8233b477ba77f8b6`
Worktree: intentionally dirty; all pre-existing and concurrent unrelated changes are preserved.
Scope: E0 guard completion, quality-gate repair, and the authorized remaining local implementation
slices. GitHub writes, deployment, live providers, and the all-95 deployment decision remain outside
this task.

## Current status table

| Item                                  | Status                 | Evidence / next action                                                                                                                                                                                                                                                                                                                                 |
| ------------------------------------- | ---------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| E0 isolated test services and cleanup | VERIFIED for this host | Explicit PostgreSQL/Valkey targets, test-only databases, run/worker cleanup and external-transport guards are active. Keep CI service provisioning separately scoped.                                                                                                                                                                                  |
| OIDC refresh reception                | IMPLEMENTED LOCALLY    | Base forwards `refresh_token`; client-bound rotation and persisted claims are exercised. Cross-surface failure injection and concurrent rotation remain open.                                                                                                                                                                                          |
| OIDC prompt/max_age slice             | IMPLEMENTED LOCALLY    | Base app/com/org transaction persistence, `login`/`none` handling, freshness checks and RP ID-token verification are covered by focused tests. Full public end-to-end policy coverage remains open.                                                                                                                                                    |
| Rails normal suite                    | GREEN                  | 2026-09-17 isolated `bin/ci` Rails stage: 13,086 tests, 79,258 assertions, 0 failures, 0 errors, 3 existing skips. Prior 13,058-run measurement is historical.                                                                                                                                                                                         |
| Rails SimpleCov gate                  | FAILED_CHECK           | 2026-09-17 `COVERAGE=true` isolated run: tests 13,086/79,320/0 failures; line 98.33% (`58,001/58,985`), branch 87.83% (`8,672/9,873`), method 93.95% (`10,082/10,731`); exit 2. Gates unchanged. Remaining branch/method gap: Coverband/diagnostic/architecture tooling (environment construction) plus production controllers not entered this suite. |
| JS formal coverage                    | GREEN                  | `bun run test:coverage` uses Node 24.20.0 + Vitest 5.0.0/V8: 85 files, 1,057 tests; statements 100%, branches 99.63%, functions 100%, lines 100%; exit 0.                                                                                                                                                                                              |
| Canonical local CI                    | GREEN                  | 2026-09-17 `bin/ci` with explicit Valkey DBs 3/4/5 exited 0 in 7m27s (database prepare, JS checks/coverage, Ruby/ERB lint, bundler-audit, bun audit, Brakeman, loopback boot, Rails 13,086/79,258). Nested `test-isolated bin/ci` is invalid (double run-id claim). Does not make SimpleCov green.                                                     |
| Static/security gates                 | GREEN                  | `bun run check`, RuboCop (after ExplicitMethodVisibility on rails_performance patches), ERB lint, Brakeman, bundler-audit passed.                                                                                                                                                                                                                      |
| Remaining feature work                | IN PROGRESS            | E10 reverse-direction closeout recorded. Ruby branch/method floors, physical DPoP/DBSC, GUID persistence ownership remain open; no all-95 or deployment decision is made.                                                                                                                                                                              |

The current implementation state is: **E0 execution and ordinary Rails baseline are achieved; the
Ruby coverage gate and several feature slices remain open.** This table is the active checkpoint;
the older planning verdict and source audit below are retained as history and must not be read as a
reason to stop the authorized local implementation work.

## Latest verification checkpoint — 2026-09-15

The corrected local `bin/ci` was run with explicit PostgreSQL test-target variables and Valkey
responsibility URLs for logical databases 3, 4, and 5. It exited 0 after the test database manifest,
JavaScript format/lint/type/dead-code/OpenAPI checks, Ruby/ERB lint, bundler-audit, bun audit,
Brakeman, loopback Rails boot, Node/V8 JS coverage, and Rails tests. The Rails stage reported 13,058
runs, 79,090 assertions, 0 failures, 0 errors, and 3 pre-existing skips; seed 48755, 16 workers. The
prior CI attempt with an inherited cache URL on the wrong logical database was rejected before
database preparation and is retained only as a fail-closed guard observation.

The same source state's explicit Rails coverage run completed 13,058 tests with no test failures,
but SimpleCov exited 2: line 98.38% (57,972/58,924), branch 87.88% (8,669/9,864), and method 93.87%
(10,064/10,721). Existing line, branch, method, file, group, and maximum-drop gates were not
changed. Formal Node/V8 coverage passed separately at statements 100%, branches 99.63%, functions
100%, and lines 100% for 85 files and 1,057 tests. These results do not claim all-95 completion,
physical DPoP/DBSC interoperability, GUID persistence ownership, or deployment approval.

## Current E0 status

Rails execution is available through the explicit isolated test-service wrapper. The effective test
databases are `test_primary_db`, `test_app_ticket_db`, `test_com_ticket_db`, and
`test_org_ticket_db` on the verified PostgreSQL test host; Valkey responsibilities use logical
databases 3, 4, and 5 on the verified Valkey test host. The Blazer migration
`20260915000000_create_blazer_tables` was applied only to the dedicated primary test database, and
the OIDC refresh-claim migrations were applied only to the three ticket test databases after
explicit target checks. No development, production, shared user database, or broad Valkey database
was reset, dropped, recreated, or flushed.

The E0 guard/transport tests, authorization-code/OTP target, OIDC refresh/freshness regressions,
focused endpoint tests, and the latest full Rails suite pass. The latest canonical CI run exercised
13,058 tests and 79,090 assertions with no failures or errors and 3 existing skips. The corrected
local `bin/ci` passed its configured stages after all three Valkey responsibility URLs were supplied
explicitly. These are separate from the Rails SimpleCov gate, which remains red at the values in the
status table above.

No threshold, assertion, skip, or exclusion was weakened. Formal Node-backed Vitest V8 coverage
passes with 85 files and 1,057 tests. Bundler-audit, Brakeman, static checks, and the local
canonical CI pass; the Ruby coverage gate remains open and is not being treated as green.

The current implementation slice connects `grant_type=refresh_token` at the Base OAuth token
endpoint, persists the original OIDC `auth_time`/`acr`/`amr`/nonce on RP sessions, rotates only a
client-bound refresh family, and fails closed when authentication-event time is absent. It also
persists nullable `prompt`/`max_age` options on the three dedicated authorization-transaction
stores, enforces `login`/`none` and freshness at Base, and passes the expected max-age to RP
ID-token verification. The migration and focused tests are limited to the verified test ticket
databases; full cross-surface/failure-injection coverage and the broader auth-time source audit
remain open.

The detailed commands, exit statuses, schema/connection checks, repairs, and remaining external
limitations are recorded in `evidence/2026-09-15-e0-green-baseline.md`. The historical all-95 NO_GO
assessment remains below as history and is not overwritten by this limited E0 result.

## 1. Executive verdict

**NO_GO for freezing or starting an autonomous implementation run covering all 95 requirements.**
This is not a rejection of the accepted Base/Auth architecture or proof that every candidate risk is
exploitable. The original V2 deliverable was a plan-only audit; the later continuation has applied
only the bounded source/test slices explicitly recorded below. Those slices are not a complete
E0–E10 implementation and remain validation-pending. The previous draft's GO and D-ENTRY adoption
claims are superseded and removed as current authority.

The remaining gates are: missing original requirement/review source files; a statically confirmed
OIDC `auth_time` source/propagation defect in the inspected issuance path; source-confirmed
`prompt`/`max_age` handling gaps at the RP builder, all three Base authorization surfaces,
transaction resume, and RP verifier; an unresolved OIDC refresh-token contract; unverified
cross-client replay effects and cross-store failure recovery despite the bounded fail-closed guards;
untested Valkey/PostgreSQL/HTTP partial-failure recovery; untested Auth admission paths; unresolved
Base-local/direct-entry UX; the conflict between the earlier literal `/dashboard` Up-link
requirement and the accepted Root-as-home ADR; and lack of proven isolated Rails test services. None
of these public-boundary behaviors was dynamically reproduced in this run. The full implementation
phase remains unstarted; bounded local slices are recorded as implementation-pending-validation.

This plan uses the 95-row summaries from the previous draft only as provisional aliases. They do not
reconstruct the unavailable P00-P17 source. REQ-095 remains unknown rather than invented.

Current continuation status: E0 execution, ordinary Rails, formal Node/Vitest coverage, and local
canonical CI are green. Ruby branch/method coverage remains below the unchanged gate, and the
remaining E1–E10 feature slices are not complete. This status is separate from the historical all-95
planning verdict and does not authorize deployment.

## 2. Current worktree and evidence boundary

At the initial planning snapshot, HEAD was 430ac354ba06c9d22885e1e69d027a7a1b1d5280 on feature with
no staged changes. Compared with review SHA 08fc1eeb6d2f354078787ab6f3f4e6890c774def, HEAD contains
21 committed file changes (+307/-6), including an accepted Social Identity Step-Up ADR and tests,
AAL documentation reconciliation, inert self-service Create actions, a Base Root Up link for those
pages, sign-up email value restoration, and React behavior tests. These changes are now current
repository evidence; they are not independent verification. Twelve tracked Auth/app-com email and
OTP files also had user changes in the starting worktree. Four untracked files predated this run:
misc.md, notes/implementation/2026-09-14-refactor-plan-before-execution.md,
notes/implementation/2026-09-14-refactor-plan-history.md, and refactor.md. They are preserved; only
refactor.md is updated. The auxiliary untracked notes/memo say D-ENTRY was adopted for a cycle,
which conflicts with the current V2 requirement and is not an accepted ADR. Current Auth/Base source
also shows an anonymous entry redirect-cycle candidate; neither the draft nor current code alone
resolves the product choice.

The S1 original 18-section/95-ID plan file was not found (supplied SHA-256:
2ae07102f486fd13c64fc45acfca65b990cc438db1098610dcb09415b52a92c8); S2 Sol review was not found
(supplied SHA-256: 3052638bea18ef029798632f068402333638eeacd222de23bad1af05e91b8533).
`umaxica_feature_plan_review.md` was not found either. The conversation contains many source request
prompts, but not the byte-exact S1 REQ ledger or a verifiable mapping from its IDs to those prompts;
at least one earlier source prompt is visibly truncated. The digests were not recomputed against
local bytes. Do not treat the prior ledger or notes as original requirements or independent runtime
evidence.

At the initial planning snapshot only refactor.md was changed. The later E0 continuation is recorded
separately at the top of this file and in the dated evidence record; it includes only the explicitly
scoped test-environment guards, test-support changes, limited contract repairs, and the approved
migration on `test_primary_db`. No route, GitHub state, deployment, or external provider state was
changed. Pre-existing and concurrent unrelated changes remain preserved.

### Historical repository facts at the prior audit snapshot

The following table is retained evidence from the earlier planning-only audit. Rows that describe
missing refresh or freshness support are superseded by the current checkpoint above; rows that do
not have a later evidence entry remain open. It is not a current green claim.

| Area                 | Source fact                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           | Reachability/validation limit                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 |
| -------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Authority            | adr/base-auth-ceremony-and-seven-rp-boundary.md names Base as sole physical IdP/AS and Auth as ceremony-only. It allows actor-specific opaque ceremony state and random-only __Host-auth_sid but says these are not Base login proof. Seven browser RPs: core-app/com/org, side-app/com/org, edit-org.                                                                                                                                                                                                                                                                                                                                                | Accepted decision; runtime admission across all controllers not proved.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       |
| auth_time            | `OidcAuthorizationCodeIssuer#call` still supplies `auth_time: Time.current` while the Valkey code store separately records `issued_at`. `ConsumedCode` now carries only the explicit payload `auth_time`; exchange rejects a missing/unparseable value and no longer falls back to code issuance or exchange time. The ordinary Base login JWT path inspected does not pass a semantic `auth_time`.                                                                                                                                                                                                                                                   | Static tracing still confirms the upstream issuer maps code-issue time instead of an authentication-event instant. The downstream guard and precedence slice are not an end-to-end fix. No T0/T1/T2 request was run.                                                                                                                                                                                                                                                                                                                                                          |
| Base auth context    | `OidcAuthorizationTransactionable#register_authentication!` writes `authenticated_at: now` when `BaseAuthAdmissionCoordinator.register_result_and_issue_resume!` records a completed ceremony. That is Base-side result-registration time; whether it precisely denotes the underlying authentication event must be established. `authorize_params` omits it and resumed authorization sends only that reduced hash to code issuance. Existing Base-session authorization skips the ceremony; no semantic auth time was found in the inspected root JWT/session path.                                                                                 | A candidate Base-accepted event timestamp exists for the ceremony transaction, but it is neither established as the exact event instant nor carried through the handoff/resume/code/token path. Existing-session provenance was not found in the inspected path. Never substitute AR `created_at` / `updated_at`.                                                                                                                                                                                                                                                             |
| max_age/prompt       | `OidcSsoInitiator#oidc_authorization_url` cannot emit either parameter. App/com/org Base `authorize_params` use fixed allowlists omitting both; `OidcAuthorizeRequestResolver` does not validate them; transaction serialization omits them; `OidcIdTokenVerifier` takes only expected nonce and does not verify an expected freshness or `auth_time` claim. The Base authorization action's already-authenticated branch issues a code after validating its filtered parameters.                                                                                                                                                                     | Source-confirmed gaps on inspected paths; predicted logged-in `prompt=login`, anonymous `prompt=none`, and stale `max_age` behavior are not endpoint reproductions. OIDC Core defines these as OP behavior; verify the actual public response under isolated requests.                                                                                                                                                                                                                                                                                                        |
| OIDC refresh         | Code exchange returns a `refresh_token`; the public Base OAuth token endpoint forwards `grant_type` to a coordinator whose accepted grant is `authorization_code` only. `OidcRefreshTokenIssuer` has no production call site in `app/`; direct service tests invoke it, and the issuer rotates RP usage state without minting Access/ID claims. Base browser-cookie refresh and legacy/non-OIDC token refresh endpoints are distinct.                                                                                                                                                                                                                 | Static source shows an unresolved response/endpoint contract. No registered RP's actual refresh use or external consumer contract was established. Do not infer OIDC refresh behavior from the standalone issuer or conflate it with Base session refresh.                                                                                                                                                                                                                                                                                                                    |
| Replay ordering      | `OidcTokenExchangeCoordinator#prevalidate_payload` checks expiry, client/redirect/registered redirect, PKCE, scope, then handles non-issued lifecycle state. The Lua consume script checks expiry and expected fields before replay classification. A same-owner replay is eligible for linked-family cleanup; a mismatched presenter is not.                                                                                                                                                                                                                                                                                                         | Client B must be independently valid and know A's raw code. Public cross-client side effect, Lua race behavior and owner-bound rejection remain untested. Lifecycle state differs from OAuth state parameter.                                                                                                                                                                                                                                                                                                                                                                 |
| Replay target        | `revoke_linked_family!` now requires client ID, redirect URI, registered redirect and PKCE ownership checks before using stored resource/session/family refs. A revocation exception is converted to a sanitized `server_error`; successful same-owner replay remains `invalid_grant`.                                                                                                                                                                                                                                                                                                                                                                | Whether an isolated HTTP request changes A's state, whether revoker outcomes are complete, and whether concurrent races preserve the invariant remain untested.                                                                                                                                                                                                                                                                                                                                                                                                               |
| Family link          | `link_consumed_family!` now requires an explicit `:linked` result; `missing`, `invalid_state`, nil and other outcomes raise before token success. Selected Valkey failures are re-raised.                                                                                                                                                                                                                                                                                                                                                                                                                                                             | Actual partial states, ambiguous timeout, rollback and retry recovery are untested.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           |
| DPoP                 | In the Base OAuth token endpoint, ownership/PKCE/scope prevalidation and optional DPoP proof verification now precede atomic code consumption. `DpopProofVerifier#verify_nonce` accepts an absent nonce and validates/consumes a nonce only when supplied. Token controllers do not issue `DPoP-Nonce`. The separate resource-authentication path can issue a nonce after authentication resolution fails.                                                                                                                                                                                                                                            | Static source says the AS token endpoint does not currently elect a nonce challenge. The resource-server response-header contract is separate and still needs an omission/retry test. No endpoint-level DPoP request was run.                                                                                                                                                                                                                                                                                                                                                 |
| Auth entry           | Sign-in/sign-up selectors include AuthCeremonyAdmission. For an anonymous no-admission request it redirects to the same realm's Base root; Base roots generate links back to Auth sign-in/sign-up without an admission. This is a static redirect-cycle candidate. Leaf credential routes exist and successful email paths can reach AuthenticationSessionCommitter → establish_signed_in_session!.                                                                                                                                                                                                                                                   | The redirect cycle is source-traced, not HTTP-followed. Callback order, actor/surface/purpose checks, Base acceptance and resulting state must be tested. The committer path is a candidate boundary issue, not a confirmed bypass.                                                                                                                                                                                                                                                                                                                                           |
| Activity storage     | Base::Identity::ActivityLogPresenter maps event, risk rank and visibility and filters internal event ids in its query. ClientChronicle has event_id and level_id foreign keys; ClientChronicleLevel ids are logging severity (DEBUG/ERROR/INFO/NOTHING/WARN), not risk. Chronicle visibility contexts are a separate audit stream.                                                                                                                                                                                                                                                                                                                    | Reuse existing mapping; verify event emission and props/DOM safety; do not add duplicate risk/visibility tables.                                                                                                                                                                                                                                                                                                                                                                                                                                                              |
| Session presentation | Base identity session controllers use Base::Identity::SessionPresenter and SessionTimestampHelper. Org mode comes from explicit authentication_context; it does not infer Emergency from DBSC.                                                                                                                                                                                                                                                                                                                                                                                                                                                        | UI/authorization/route behavior across all three surfaces and actual device metadata remain to test.                                                                                                                                                                                                                                                                                                                                                                                                                                                                          |
| Expiry               | SessionAbsoluteExpiryValue.cap is used by several OIDC Access/ID/Refresh issuance paths and RP refresh issue/rotation; root token rotation preserves finite discarded_at.                                                                                                                                                                                                                                                                                                                                                                                                                                                                             | Strong evidence for an expiry ceiling, but creation, all three token kinds, DBSC and no-revival semantics need boundary tests. Do not add a new column without contrary evidence.                                                                                                                                                                                                                                                                                                                                                                                             |
| GUID                 | config/routes/guid.rb routes public guid.umaxica.net GET /api/v0/resources/:guid. Guid::Net::Api::V0::ResourcesController validates transport input but has no authoritative lookup. Existing docs/ADR establish host/path.                                                                                                                                                                                                                                                                                                                                                                                                                           | Persistence DB owner is unknown. Public net host conflicts with OpenAPI test/docs that describe net as internal.                                                                                                                                                                                                                                                                                                                                                                                                                                                              |
| OpenAPI              | test/contracts/openapi_route_coverage_test.rb excludes /web/v0 and /edge/v0 as deferred, treats net/dev as internal and discovery may omit guid/edit; sources/bundles are app/com/org only.                                                                                                                                                                                                                                                                                                                                                                                                                                                           | The initial static pass had no runtime inventory; the 2026-09-15 read-only route run confirms declarations but not JSON responses, host constraints, coverage discovery, or any OpenAPI contract. Do not hide a public API gap in an indefinite FIXME or broad exemption.                                                                                                                                                                                                                                                                                                     |
| Roots                | Accepted RP inventory adds Edit org to Auth/Base/Core/Side app/com/org plus Palm app: 14 in-scope roots. A read-only `RAILS_ENV=test bin/rails routes` run exited 0 and emitted 1,395 lines; it includes all 14 root routes plus separate Base/Core net/dev and public content roots. Public content surfaces are not part of the authenticated-root task.                                                                                                                                                                                                                                                                                            | Route declarations are runtime-enumerated, but host dispatch, controller response behavior, inheritance/callback effects and authentication transitions remain untested.                                                                                                                                                                                                                                                                                                                                                                                                      |
| Test environment     | `config/database.yml` names Rails test databases `test_*`, distinct from `development_*`, while `test_host` may fall back to `POSTGRESQL_HOST`. Store unit tests pass unique Valkey test namespaces, but request-path store constructors default to fixed production namespaces. The current process has AUTH_STATE_REDIS_URL on Valkey logical DB 2; the supplied dev/example configuration also assigns DB 2. Turnstile has an injected test verifier, but it falls through to the real verifier when no response is configured; outbound HTTP stubbing is per-test and there is no confirmed global egress deny. CI starts with test `db:prepare`. | Read-only routes/notes boot succeeded with workspace logs/cache overlaid to `/tmp`; this does not prove general service isolation. A targeted OTP test attempt did not reach assertions: the first boot hit a ViteRuby/Bun subprocess abort, and the retry stopped at test-schema maintenance because PostgreSQL host `primary` was unreachable. No successful DB connection or schema mutation occurred. Test database identity, run-scoped Valkey isolation and global provider egress isolation remain unproved; do not run `db:prepare` or the full suite until they are. |

The existing shared ActivityLogPresenter and SessionTimestampHelper correct prior draft assumptions.
Use them unless behavior tests demonstrate a gap.

Changes since the Sol review SHA were read as a committed delta, not accepted merely because they
are recent. The Social Step-Up decision already exists in
`adr/social-identity-linking-requires-step-up.md`, with app Google/Apple Step-Up and unlink coverage
in the current integration tests. The self-service UI already passes server-supplied disabled Create
props and an Up link through `EntityList`; Avatar and the related account/organization controllers
and contract tests are present. That Up destination is Base Root via `dashboard_up_link`, consistent
with the accepted ADR that retires `/dashboard` and makes Base Root the Dashboard-as-home. The
earlier literal `/dashboard` example is therefore a contract conflict, not a reason to recreate the
retired route. Sign-up email value props and Rails assertions are also in HEAD. The local
uncommitted OTP changes include visible sign-up OTP Turnstile, server checks before OTP verification
for signup/sign-in, and failure tests. Those Auth files were already dirty at the starting snapshot;
the continuation preserved the starting diff and made only the bounded additions listed in §19.
Their final attribution must be reviewed from the starting diff, and they remain unvalidated by
Rails in this run; do not count them as proven behavior.

## 3. Requirement ledger and evidence hierarchy

The full row-by-row provisional ledger and traceability matrix is in §9. Every identifier has one
primary owner. REQ-020 is horizontal across every phase, not duplicate ownership.

Source labels:

- S1: supplied digest for original 18-section plan; source file absent.
- S2: supplied digest for Sol static review; source file absent, but findings are summarized in
  current prompt.
- V2: latest user-pasted planning-only instructions.
- Conversation: earlier individual implementation requests pasted by the user.

For every S1-ledger row, exact original REQ wording, classification, MUST/SHOULD/MAY strength, and
mapping back to P00–P17 remain unverified against the missing plan file. M* in §9 means “must remain
traced because V2 explicitly requires all REQ IDs,” not “the missing source definitely said MUST.”
Concise ledger text is a provisional alias informed by prior notes and available conversation
prompts, never a quotation or substitute for S1. REQ-095 is incomplete and must not be guessed.

Adjudication order: current explicit V2 constraints and accepted decisions; current accepted ADR;
normative protocol/security requirements; externally observable contracts; tests; production code;
current documentation; comments/history. Existing code proves behavior, not requirement correctness.
A source-order hint among missing prompts cannot supply absent wording or authorize a third
architecture.

## 4. Conflict matrix

| ID   | Classification                          | Conflict and resolution                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                |
| ---- | --------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| C-01 | REAL_CONFLICT                           | Earlier embedded implementation requests versus V2's planning-only scope. V2 governed the original audit; the later continuation was separately authorized for bounded local slices. `refactor.md` remains the plan artifact, while the full E0–E10 implementation has not begun.                                                                                                                                                                                                                                                                                      |
| C-02 | REAL_CONFLICT / STALE_PLAN              | Prior refactor draft asserts D-ENTRY and GO. Current V2 leaves direct-entry UX undecided. Remove those assertions as current authority; this planning run does not resolve that product choice.                                                                                                                                                                                                                                                                                                                                                                        |
| C-03 | MISSING_INFORMATION                     | S1/S2 files absent; Appendix summaries cannot replace exact P00–P17. Preserve provisional mappings; recover source before asserting exact strength.                                                                                                                                                                                                                                                                                                                                                                                                                    |
| C-04 | STALE_IMPLEMENTATION                    | Static trace confirms code issuance time maps to OIDC Access/ID `auth_time`; Base login and transaction paths do not propagate a durable semantic event to cover SSO. Runtime T0/T1/T2 test remains outstanding.                                                                                                                                                                                                                                                                                                                                                       |
| C-05 | REAL_SECURITY_CONFLICT candidate        | Replay side effect before current client/redirect/PKCE owner checks. Preserve replay denial but bind revocation to the code owner in both Ruby and Lua.                                                                                                                                                                                                                                                                                                                                                                                                                |
| C-06 | REAL_CONFLICT                           | Fail-closed code-store intent conflicts with ignored link statuses and swallowed Valkey errors. Treat only positive required linkage as success unless an accepted decision explicitly says otherwise.                                                                                                                                                                                                                                                                                                                                                                 |
| C-07 | APPARENT_CONFLICT                       | Missing DPoP nonce is not itself a defect: RFC 9449 §8 makes nonce use optional. If nonce is issued/elected, a valid fresh-proof retry must work.                                                                                                                                                                                                                                                                                                                                                                                                                      |
| C-08 | IMPLEMENTATION_CHOICE                   | Earlier universal DPoP aspiration conflicts with current per-client optional policy and missing device validation. Audit each controlled client; do not force a new global requirement.                                                                                                                                                                                                                                                                                                                                                                                |
| C-09 | APPARENT_CONFLICT / MISSING_INFORMATION | Earlier GUID example /resources/:eid versus existing /api/v0/resources/:guid contract. Preserve current public path and do not add a duplicate. Decide the storage owner and public net OpenAPI contract; evaluate :guid → :id from client/OpenAPI evidence.                                                                                                                                                                                                                                                                                                           |
| C-10 | APPARENT_CONFLICT                       | Aggressive route normalization versus legitimate CSP-report and .well-known path mappings. Preserve documented protocol/public paths; normalize only internal naming indirection.                                                                                                                                                                                                                                                                                                                                                                                      |
| C-11 | STALE_REQUIREMENT                       | Older Auth root → dashboard request conflicts with accepted Base/Auth ADR: Auth roots are public ceremony entries and retired dashboards/lobby stay retired. Direct sign-in product UX remains unresolved.                                                                                                                                                                                                                                                                                                                                                             |
| C-12 | APPARENT_CONFLICT                       | /sessions, /sign/out and Core /api/v0/session are separate user resource, current-browser ceremony and BFF contract. Preserve all three semantics.                                                                                                                                                                                                                                                                                                                                                                                                                     |
| C-13 | STALE_IMPLEMENTATION ASSUMPTION         | A risk FK was suspected, but current ClientChronicle level FK is log severity; risk/visibility already live in shared presenter mapping. Reuse and test it.                                                                                                                                                                                                                                                                                                                                                                                                            |
| C-14 | IMPLEMENTATION_CHOICE / STALE_BASELINE  | Failed-run 98.56% is neither a green baseline nor an adopted threshold. Current configured gates remain authoritative; no extra floor adopted.                                                                                                                                                                                                                                                                                                                                                                                                                         |
| C-15 | STALE_PLAN                              | Correct primary mapping: REQ-016–019→E5; REQ-020 is horizontal and audited in E10; REQ-055/056→E3; REQ-064→E0.                                                                                                                                                                                                                                                                                                                                                                                                                                                         |
| C-16 | REAL_CONFLICT for this run              | Prior per-step-commit preference versus explicit current prohibition on Git mutations. No commit now. A future authorized implementation run may commit each verified step without including user diffs.                                                                                                                                                                                                                                                                                                                                                               |
| C-17 | REAL_CONFLICT / MISSING_INFORMATION     | The earlier self-service prompt explicitly requires `/dashboard?ri=jp`; accepted `adr/base-auth-ceremony-and-seven-rp-boundary.md` retires Base `/dashboard` and makes Root the authenticated Dashboard home. Current controllers use `dashboard_up_link` and tests expect `base_app_root_path(ri: ...)`. The UI and ADR now disagree with the older literal URL requirement. Decide whether Dashboard is a semantic label linking to Root or whether the ADR/route contract is being reopened; do not add the retired route or silently reinterpret the explicit URL. |
| C-18 | STALE_IMPLEMENTATION / protocol gap     | The inspected OIDC RP and OP paths silently omit/drop `prompt` and `max_age`, and no Base freshness decision exists in the paths found. OIDC Core §§2, 3.1.2.1, 3.1.2.3 and 15.1 define support obligations. Public behavior must be verified once safe service isolation exists; this is a source-level conformance gap, not a reproduced endpoint result.                                                                                                                                                                                                            |
| C-19 | MISSING_INFORMATION / API contract      | Base emits a `refresh_token` in the authorization-code response but the token endpoint coordinator accepts only `authorization_code`; `OidcRefreshTokenIssuer` has no production caller in `app/`. Identify whether and where that response field is used before deciding to add refresh-grant handling or change the response contract.                                                                                                                                                                                                                               |

## 5. Initial synthesis

| Subsystem                             | Current                                                                                                                                                                                                                                    | Target                                                                                             | Gap / direction                                                                                                                                                        | Uncertainty                                                                                                                                                               |
| ------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | -------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Base/Auth                             | Accepted authority ADR exists; selector admission and leaf session-writing code coexist. Anonymous Auth sign-in/up entry bridges to Base root, while Base root links return to Auth without an admission: static redirect-cycle candidate. | Base alone accepts identity/session; Auth only verifies and returns evidence.                      | Trace every app/com/org route and callback before altering session/token behavior.                                                                                     | Does browser routing reproduce the cycle across hosts; which inherited guards protect leaf routes; direct-entry UX decision.                                              |
| auth_time/freshness                   | Issuer still uses `Time.current`; exchange now accepts only explicit payload `auth_time` and rejects missing values; `prompt`/`max_age` are omitted at inspected request and resume boundaries.                                            | One Base-accepted authentication-event time; standards-compliant prompt/max_age round trip.        | Carry the genuine event time, separately propagate and evaluate request freshness, then verify Access/ID claims at their public boundary.                              | Exact event source for existing sessions, HTTP request-visible outcomes, and actual OIDC refresh consumers. No safe upstream substitute was found in the inspected paths. |
| OIDC refresh                          | Token response has a refresh token; token endpoint coordinator accepts authorization-code grant only; standalone OIDC refresh operation has no production caller found.                                                                    | A coherent, documented token response and grant contract for actual RP clients.                    | Trace all in-repository and supplied client contracts, exercise the public token endpoint, then decide whether refresh is supported there or the response must change. | External client use and whether the issuer is intentionally dormant.                                                                                                      |
| Code exchange                         | Valkey is atomic for one-use; bounded slices now bind replay ownership before side effects, require positive family linkage and fail closed on revocation/link/token-output failures.                                                      | Preserve replay rejection while defining cross-store recovery.                                     | Test endpoint and Lua races; never unconsume.                                                                                                                          | HTTP public boundary, timeout states, concurrency.                                                                                                                        |
| RP/DPoP/DBSC                          | Shared code and verifiers exist; DPoP optional by client; DBSC classes exist.                                                                                                                                                              | Shared seven-RP contract, no Auth RP, accurate client policy/fallback.                             | Trace runtime wiring and test failures; defer real-device claims.                                                                                                      | Per-client compatibility and nonce policy.                                                                                                                                |
| Session/activity                      | Shared presenter and preference formatter exist; current routes are under identity; token expiry cap exists.                                                                                                                               | /sessions, safe user display and proven absolute expiry.                                           | Reuse existing abstractions and verify actor/time/lifecycle behavior first.                                                                                            | discarded_at semantics across all paths.                                                                                                                                  |
| APIs/GUID/roots                       | Public GUID route without record resolution; OpenAPI omits net/edit coverage; 14 static roots.                                                                                                                                             | Coherent routes/contracts, resolver and surface-specific roots.                                    | Inventory first; get data owner and net API decision before GUID persistence.                                                                                          | Runtime routes, source owner, direct-entry UX.                                                                                                                            |
| OTP/UI/mail                           | Current worktree has user Auth changes; limited frontend tests passed.                                                                                                                                                                     | Email preservation, no failed OTP persistence, server Turnstile, safe mail/logout/social/inert UI. | Preserve current changes; test server boundary after isolation.                                                                                                        | Rails flows and external stubs.                                                                                                                                           |
| Social linking / self-service preview | Current HEAD includes an accepted Social Step-Up ADR and tests, and inert Create actions/Root Up links with React and controller coverage.                                                                                                 | Preserve the accepted social-link contract; avoid reimplementing satisfied UI.                     | Verify current tests/route contract; add only missing behavioral coverage.                                                                                             | Rails tests not run here; direct callback with a prebuilt grant still needs negative assurance proof. Literal `/dashboard` conflicts with accepted Root-as-home.          |
| Timestamps/visibility                 | Broad cross-repo uses and private-test cleanup not baselined.                                                                                                                                                                              | Semantic timestamps, public behavior coverage, gates unchanged.                                    | Inventory; defer large cleanup until explicit green baseline.                                                                                                          | Full Rails health/per-file coverage.                                                                                                                                      |

## 6. Adversarial findings

These are seven adversarial self-review lenses; no independent reviewer agent was run. Fifteen
findings below are self-reviewed, not independently reviewed, against HEAD
430ac354ba06c9d22885e1e69d027a7a1b1d5280 plus the pre-existing dirty worktree where identified.
“Static fact” is not “public-boundary reproduction”; no suspected security path below was reproduced
through isolated Rails HTTP tests in this run.

ADV-003 through ADV-005 preserve the original pre-slice observations for traceability. The bounded
continuation slices recorded in §19 change the current source ordering and failure handling; their
public effects remain unverified until isolated services are available.

| ID / reviewer / severity | Affected REQ IDs | Evidence and prerequisite | Invariant / likely
impact | Counter-test that could falsify it | Proposed resolution / synthesis effect |
|---|---|---|---|---| | ADV-001 Requirement / BLOCKER to full freeze | REQ-001–095, especially 095 |
S1/S2 files are absent; previous Appendix summaries are secondary; REQ-095 is truncated. | A missing
requirement could be invented or omitted while the plan appears complete. | Recover and hash source
files; compare each ID and P00–P17 against both matrices. | ACCEPTED. Full-plan freeze remains
NO_GO; independent work continues. | | ADV-002 Architecture + security / HIGH | REQ-011, 030 |
Issuer still supplies current time; the bounded exchange slice now uses only explicit payload
`auth_time` and rejects missing values. A credential event earlier than code issuance remains the
condition for the upstream defect. | auth_time invariant; stale authentication may appear fresh and
undermine max_age/audit. | Instrument T0 credential event, T1 delayed code, T2 exchange and assert
both claims remain T0; test SSO, reauth and any supported refresh. An alternate trusted event field
propagated on every route would falsify that route’s defect. | ACCEPTED as a source-proven upstream
timestamp-mapping defect on the inspected OIDC path, not a reproduced request impact. Carry actual
Base-accepted event time; no now/created_at fallback. | | ADV-003 Security / HIGH | REQ-059, 060,
062 | At the initial review snapshot Ruby and Lua classified replay before current code-owner
checks; the bounded slice now checks ownership first in both layers. Prerequisite for the residual
risk test: valid client B possesses A’s raw code. | Owner-scoped revocation; before the slice B
could potentially revoke A’s RP session/family. | Use valid same-realm A and B, fresh client
assertion JTI per request, and a fresh DPoP proof except deliberate replay; assert the target branch
is reached and A/B/unrelated session/family/Base state is unchanged. Same-owner valid replay remains
denied. | ACCEPTED as mandatory owner-binding test, not a confirmed exploit. The source fix is
applied; dynamic Ruby/Lua race and side-effect tests remain pending. | | ADV-004 Operations/security
/ HIGH | REQ-059, 061, 062 | At the initial review snapshot `link_consumed_family!` ignored
missing/invalid_state returns and swallowed selected Valkey exceptions; the bounded slice now
requires `:linked` and re-raises selected failures. | Fail-closed required-state invariant; before
the slice a new credential response could be returned with replay linkage absent/unknown. | Inject
returned missing, invalid_state, exception, timeout where Lua may have succeeded, token-signing
failure after link, DB commit failure, and HTTP response loss after commit. Observe code/Valkey
state, PG state, usable credentials, retry and recovery. | ACCEPTED. Treat positive required linkage
as success; source fix is applied, but cross-store outcomes remain unexecuted. Do not unconsume or
assume one ACID transaction. | | ADV-005 Security/testability / HIGH | REQ-016, 030, 031, 059 | At
the initial review snapshot authorization code was consumed before DPoP proof validation. The
bounded slice validates the proof before consume. Separately, resource authentication can emit
`DPoP-Nonce` after failed resolution, but the verifier accepts a proof with no nonce even after such
a response. Nonce state is stored by actor type only; the schema does not identify the issuing
server/role. | Invalid AS proof must fail; the pre-consume source fix prevents that proof from
burning the code. If the RS header is intended as a challenge, accepting the next nonce-less proof
weakens that elected policy. | At AS token endpoint, exercise absent proof per Bearer policy,
malformed proof, wrong key, stale iat and replayed `jti`; assert error/header and code/family state.
At RS, follow the exact failed-auth response with a valid proof first omitting, then supplying its
nonce; assert the selected policy and token/session state. Obtain a nonce from one authority and
present it to another only where the architecture says they are distinct; assert rejection. |
PARTIALLY_ACCEPTED. Keep invalid proof rejected and preserve no-challenge AS behavior unless policy
changes. RFC nonce use is optional, but if the RS response is a nonce challenge, require it on the
follow-up and scope it to the issuing server. Dynamic endpoint behavior remains pending. | | ADV-006
Architecture/security / HIGH | REQ-007–010, 032, 051–056, 065 | Selector admission exists; inherited
selector gate returns for anonymous actors; leaf routes exist; email success may call
AuthenticationSessionCommitter → establish_signed_in_session!. | If an unauthenticated leaf can
produce state Base accepts as identity/session, Base-only authority is violated. Impact is unknown
pending Base acceptance trace. | For each actor/surface, test absent, valid, expired, replayed and
purpose/actor/realm/surface/browser-mismatched admissions; inspect response, Auth/Base cookies,
ceremony rows, token rows, DBSC, Base acceptance, code and RP session. Include valid flow to avoid
vacuous earlier rejection. | PARTIALLY_ACCEPTED. Keep as a required boundary test, not a confirmed
bypass. Local-entry UX is independently BLOCKED_BY_DECISION. | | ADV-007 Operations / BLOCKER to
Rails dynamic baseline | REQ-006, 064, 066, 069 | CI begins `db:prepare`; config declares
test-specific PostgreSQL database names, but test host can fall back to the shared host.
Request-path Valkey keys use fixed namespaces on logical DB 2, also assigned by development
examples. Test helpers do not establish suite-wide external egress denial. | Tests could cross-talk
through Valkey or contact real providers; Rails output would not meet the requested attributable,
isolated test condition. | Confirm fully resolved test database identities; provide disposable
Valkey and run/worker key namespaces; exercise external call denial/stubs before any behavior test.
| ACCEPTED. A targeted test was attempted and stopped before assertions at PostgreSQL schema
inspection (`primary` unresolved); no DB mutation occurred. Full tests, coverage and `bin/ci` remain
blocked. Read-only routes/notes succeeded with temporary filesystem overlays and do not require
claiming test-service isolation. | | ADV-008 Architecture/API / HIGH local blocker | REQ-021–027,
038–040 | Public GUID route exists but no resolver model; database ownership was not found; OpenAPI
treats net as internal. | Arbitrary DB attachment couples identifiers to wrong owner; no documented
public JSON contract leaves a gap. | Establish deployment and database ownership, decide a net
OpenAPI artifact, then test that the selected boundary owns lookup and covers the live host. |
PARTIALLY_ACCEPTED. Block only GUID persistence/public net contract, not other routes or
workstreams. | | ADV-009 Data/privacy / MEDIUM | REQ-045–050, 075–084 | Current ActivityLogPresenter
ranks/filters risk and visibility; SessionPresenter renders discarded_at expiry;
SessionTimestampHelper exists; shared expiry cap is called in several token paths. | Duplicate
schema/formatters add complexity; incomplete proof of expiry risks relabeling a sliding token TTL as
an absolute session ceiling. | Test real activity rows and props; verify all Client/Visitor/Operator
creation, refresh, access/ID/refresh issuance and DBSC paths at boundary times. | ACCEPTED as a
verification constraint. Reuse existing code, no duplicate schema absent a demonstrated gap. | |
ADV-010 Regression / MEDIUM | REQ-034–040 | OpenAPI test excludes legacy paths and assumes net
internal; route discovery may omit guid/edit. | Green coverage test could omit a public JSON service
or leave route/schema drift. | Compare runtime routes and each host’s JSON behavior against
source/bundle; test that a new app-owned route fails coverage if undescribed. | ACCEPTED. Reconcile
coverage without broad exemptions or indefinite FIXME. | | ADV-011 Complexity / MEDIUM | REQ-021,
028, 038, 045, 067–068, 078, 083, 092 | Shared RP primitives, activity presenter, timestamp helper
and expiry cap already exist. | Reimplementation could create independent policy owners or
unnecessary tables/services. | Require each proposed abstraction to cite a failing public behavior,
contract owner and measurable benefit. | ACCEPTED. Smallest coherent change; no parallel framework.
| | ADV-012 Architecture + regression / MEDIUM | REQ-010, REQ-041–044 | Auth app/com/org selector
controllers include AuthCeremonyAdmission and call admit_or_render_sign_ceremony!; anonymous
no-admission path calls bridge_to_base_admission! to Base root. Base app/com/org RootsController
ceremony_sign_in_href/ceremony_sign_up_href generate direct Auth entry URLs without admission. |
Anonymous click can alternate Base root → Auth selector → Base root and never reach a credential
ceremony; this is a usability/availability defect, not evidence of identity bypass. | Follow one
app/com/org entry across local test hosts; assert the request sequence reaches an admitted ceremony
or returns the selected explicit error, not a cycle. Verify actual root links and redirect chain. |
ACCEPTED as static redirect-cycle candidate. D-ENTRY remains undecided; choose and test an explicit
no-loop entry contract. Runtime reproduction not run. | | ADV-013 Testability / MEDIUM | REQ-088,
REQ-020 | Pre-existing dirty
`test/controllers/auth/{app,com}/sign/up/check/email/otps_controller_test.rb` stubs
`FeatureFlags.enabled?` to `true` around a result marked `unavailable: true`.
`TurnstileDegradation#apply` treats that result as success when `turnstile_degraded_mode` is
enabled; the docs explicitly record this accepted outage behavior. | The test expects 422/no OTP
transition while its broad flag stub selects the documented degraded-success branch. It is likely to
fail or assert the wrong policy when executed. | Run with unrelated signup flags enabled but
`turnstile_degraded_mode` explicitly disabled and assert outage failure leaves OTP attempts/state
unchanged. Separately test that enabling the degraded flag accepts only upstream-unavailable
results, while invalid/missing tokens still fail. | ACCEPTED as a dirty-test contradiction, not a
production defect. Narrow the test flag setup; retain and separately verify the existing documented
outage risk unless a user decision explicitly changes that policy. Runtime failure was not observed.
| | ADV-014 Protocol / security / HIGH | REQ-011, REQ-030 | `oidc_authorization_url` cannot emit
`prompt`/`max_age`; app/com/org Base fixed allowlists omit them; resolver and transaction
serialization/resume omit them; verifier has no freshness input or `auth_time` check. The
authorization action has an already-authenticated code-issue shortcut. A valid request reaching
these routes is the prerequisite; middleware or an alternate handler could falsify the path-level
conclusion. | OIDC OP prompt/max_age contract; stale authentication can be accepted as fresh,
`prompt=login` may be ignored for an existing session, and `prompt=none` may proceed interactively
after its value is dropped. This can invalidate RP freshness decisions. | With valid client,
redirect, state, nonce and PKCE, request each realm while logged in: `prompt=login` must
reauthenticate before code; while anonymous/stale, `prompt=none` must return the applicable OIDC
error without UI. Test `max_age` just-fresh, at/over boundary and zero, preserved through
transaction resume, with the final ID Token `auth_time` and RP rejection path. Any earlier
standard-compliant layer that preserves/enforces all parameters and these outcomes would falsify the
gap. | ACCEPTED as a source-confirmed conformance gap on the inspected route, not a reproduced
endpoint defect. Implement parameter validation/storage, Base freshness decisions and claim
verification per OIDC Core; no fabricated event time. The no-RP Base-local UX remains a separate
decision. | | ADV-015 API contract / MEDIUM | REQ-011, REQ-030 | Token exchange returns
`refresh_token`; Base OAuth endpoint passes `grant_type` to `OidcTokenExchangeCoordinator`, which
accepts `authorization_code` only. `OidcRefreshTokenIssuer` has no production caller found under
`app/`; service tests invoke it directly. Prerequisite is a client attempting to use the returned
token at this endpoint. | OAuth token lifecycle is ambiguous or unusable: a value presented as
refresh credential may fail with `invalid_request`, while the standalone issuer's rotation does not
mint updated Access/ID claims. External clients could have a separate contract not present in this
repository. | Complete a valid code exchange through each registered surface, then submit its
returned token as `grant_type=refresh_token` using fresh valid client auth; record response and
persisted family/session state. Exercise any documented actual alternate consumer. A successful
normal public grant or an explicit boundary contract would falsify the mismatch. |
PARTIALLY_ACCEPTED. The source-level endpoint/response mismatch is confirmed; intended/external
consumer contract is missing. Do not add a grant handler, remove the response field, or call the
standalone issuer until client ownership and contract are established; if refresh is supported,
preserve the original `auth_time` while `iat` advances. |

### Security detail for adversarial findings

The detailed security paragraphs and fixed-SHA evidence rows below preserve the initial
pre-continuation snapshot for audit traceability. They are not a claim that the same source still
has the same ordering after the bounded slices recorded later in this document. The current bounded
changes (owner checks before replay revocation, explicit family-link success, DPoP pre-consumption
validation, explicit-only downstream `auth_time`, and fail-closed replay-revocation errors) are
authoritative for the present worktree, but remain dynamically unverified until an isolated
PostgreSQL/Valkey test environment is available. Historical rows must therefore be read as "what the
initial review found", while the later bounded-slice sections state the current source intent and
remaining validation requirements.

- ADV-002 prerequisite: a credential event occurs at T0, then authorization/code issuance happens
  later at T1. Potential impact: ID Token and project Access JWT make authentication appear fresher
  than it was. Current candidate design prevents it only if the original event is actually accepted
  and propagated; this is not yet demonstrated.
- ADV-003 prerequisite: B has valid client authentication and knows A’s raw code, then submits it
  after A’s legitimate exchange. Potential impact: B can trigger revocation of A-linked state.
  Current code has no visible client check in the revoker path; runtime effect is unproven.
- ADV-004 prerequisite: code is consumed and family linking is unavailable, returns non-linked
  status or has ambiguous completion. Potential impact: credentials may be issued without the state
  used to revoke them on replay, or recovery may leave an unusable/ambiguous session. The design
  does not prevent this today by source inspection because the returned status is ignored.
- ADV-005 prerequisite: a valid client submits the consumed code with invalid proof, or a resource
  request receives a DPoP-Nonce response and retries without it. Potential impact is code burn after
  invalid AS proof, or weaker-than-elected RS nonce freshness if the header is intended as a
  challenge. Nonce use itself is optional under RFC 9449; do not infer a requirement from a blank
  request alone.
- ADV-006 prerequisite: direct leaf request passes inherited filters and reaches a state-changing
  committer whose Auth result is accepted by Base without Base admission. Potential impact would
  violate the authority boundary. The complete prerequisite chain is not observed, so no confirmed
  bypass claim.
- ADV-012 static path: Auth::App::Sign::UpsController#show / Auth::App::Sign::InsController#show
  (and com/org peers) → AuthCeremonyAdmission#admit_or_render_sign_ceremony! →
  bridge_to_base_admission! redirects to Base root;
  Base::App::RootsController#ceremony_sign_in_href/#ceremony_sign_up_href (com/org peers analogous)
  link back to the Auth selector without admission. Source trace supports a redirect-cycle
  inference, not browser-level reproduction.
- ADV-007 prerequisite: a command reaches shared PG/Valkey or live provider egress. Potential impact
  is external state mutation and false test confidence. No mutating Rails command was run.
- ADV-008 prerequisite: an implementation chooses a database/contract without owner decision.
  Potential impact is data ownership coupling or undocumented public interface; not an
  authentication bypass.
- ADV-014 prerequisite: a valid OIDC authorize request reaches the inspected Base controller with an
  existing session for `prompt=login`, no/freshness-expired session for `prompt=none`, or an old
  Base authentication event for `max_age`. Static path consequence is that the request allowlist
  drops the parameter and the logged-in branch can issue a code; the exact HTTP error, UI, code
  issuance and session effect were not observed. The standard contract applies at RP request
  generation, Base parsing/resume/freshness decision and RP ID Token verification; test each
  boundary independently.
- ADV-015 prerequisite: a registered client receives the token exchange response and attempts the
  OAuth refresh grant at the same Base endpoint. Static endpoint source rejects grant types other
  than `authorization_code`, but no actual client use or endpoint response was observed. The
  presence of a standalone issuer tested directly does not establish a public grant contract.

### Fixed-SHA evidence register for important findings

All source paths below refer to HEAD 430ac354ba06c9d22885e1e69d027a7a1b1d5280 on branch feature. The
observations are static source tracing unless explicitly marked otherwise. No Rails public-boundary
reproduction was performed because the current test PostgreSQL/Valkey targets are not proven
isolated.

| Finding                                  | Source, method and caller                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       | Reachability prerequisite                                                                                                                                                                                                                               | Reproduction procedure and observed result                                                                                                                                                                                             | Still unverified                                                                                                                                                                                                                                                                          |
| ---------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| ADV-002 / REQ-011, 030                   | Auth result is registered through `app/services/base_auth_admission_coordinator.rb#register_result_and_issue_resume!` → `app/services/oidc_authorization_transaction_coordinator.rb#register_result!` → `app/models/concerns/oidc_authorization_transactionable.rb#register_authentication!` (108–124), which stores `authenticated_at: now`. On Base result resume, `app/controllers/base/app/oauth/authorizations_controller.rb#show` (14–26) reloads the transaction; `#authorize_params` (app 177–185; com/org 150–159) and `OidcAuthorizationTransactionable#authorize_params` (95–106) omit `authenticated_at`. `app/operations/oidc_authorization_code_issuer.rb#call` (17–32, 28) still writes `auth_time: Time.current` to the code store; the bounded exchange now uses only explicit payload `auth_time` and rejects missing values. | An actual credential event precedes code issue and exchange; the transaction result resumes into code issuance. The Base `authenticated_at` value must itself be proven to represent that accepted credential event before use.                         | Static path traced at this SHA. It confirms transaction time is omitted and the issuer still supplies code-issue time; no T0/T1/T2 request was executed, and ordinary Base login JWT search found no semantic `auth_time` propagation. | Whether Base result-registration time equals authentication-event time; event provenance for existing Base sessions; all sign-in/SSO/reauth/step-up/social-link paths; public token claims; actual OIDC refresh endpoint/client contract; Access claim contract remains project-specific. |
| ADV-014 / REQ-011, 030                   | app/controllers/concerns/oidc_sso_initiator.rb#oidc_authorization_url (93–111) builds response_type/client/redirect/PKCE/state/nonce/scope/ri but not prompt/max_age; app/controllers/base/{app,com,org}/oauth/authorizations_controller.rb#authorize_params (app 177–185; com/org 150–159) allowlists omit both; app authorization #show (14–34) validates only filtered params and immediately issues code when already logged in; app/resolvers/oidc_authorize_request_resolver.rb#validate_required_params! (30–42) has no prompt/max_age logic; app/models/concerns/oidc_authorization_transactionable.rb#authorize_params (95–106) omits them and #register_authentication! (108–124) records authenticated_at; app/services/oidc_id_token_verifier.rb#call (20–28) checks decode/audience/nonce but no expected auth_time/freshness.     | A valid OIDC authorization request reaches a relevant host and needs forced, silent or age-bounded authentication; parameters must survive redirect and result resume.                                                                                  | `rg` and line-numbered source tracing at HEAD 430ac354 confirms the inspected generation, all three fixed allowlists, transaction serialization and verifier shapes. No public request was run.                                        | Middleware/alternate path, exact HTTP result, Base accepted event-time semantics, all RP callers and externally observed stale/fresh/none behavior.                                                                                                                                       |
| ADV-015 / REQ-011, 030                   | app/controllers/concerns/base_oauth_token_endpoint.rb#create (7–29) forwards `grant_type`; app/services/oidc_token_exchange_coordinator.rb#call (44–48) accepts only authorization_code, while #issue_exchanged_token_result (387–415) returns refresh_token; app/operations/oidc_refresh_token_issuer.rb#call (29–69) rotates the RP usage credential, with no `app/` production caller found by static search. Direct operation tests exist under test/services and token exchange tests call it directly.                                                                                                                                                                                                                                                                                                                                    | A client must first receive a refresh token and then submit it to an intended production endpoint.                                                                                                                                                      | Static callsite and endpoint tracing confirms the mismatch in source; no token endpoint refresh-grant request or actual client use was observed.                                                                                       | Client registry contracts, external/native consumer behavior, HTTP error/status/body, whether the response field is intended for another endpoint, and claim semantics on any refresh response.                                                                                           |
| ADV-003 / REQ-059, 060, 062              | app/services/oidc_token_exchange_coordinator.rb#exchange_authorization_code! (100–134) calls #prevalidate_payload (136–159); the latter calls #revoke_linked_family! before client_id/redirect/PKCE checks for a non-issued code. The replay result branch also calls it (119–126). #revoke_linked_family! (312–333) resolves stored resource_type and session/family references, with no visible comparison to presenting client. Lua equivalent is app/services/valkey/auth_state/authorization_code_store.rb::CONSUME_SCRIPT (33–64): lifecycle state != issued returns replay before expiry and expected fields. The script expected code challenge is read from the previously peeked payload by coordinator lines 109–117.                                                                                                                | Client B must authenticate independently and possess client A’s consumed raw authorization code; ensure no earlier client assertion or invalid fixture rejects before the replay branch. OAuth state parameter is distinct from Valkey lifecycle state. | Static code path is present; there is no observed A/B HTTP request and no recorded session/family diff.                                                                                                                                | Same-realm A/B registration, valid fresh client assertion JTI, branch reach, all three surface issuers, simultaneous consumption, and actual RP/Base/family side effects.                                                                                                                 |
| ADV-004 / REQ-059, 061, 062              | app/services/oidc_token_exchange_coordinator.rb#issue_tokens_for_consumed! calls #link_consumed_family!; #link_consumed_family! (298–310) returns the store result without checking it and catches selected Valkey errors after warning. Link script/store are app/services/valkey/auth_state/authorization_code_store.rb#link_family! and LINK_FAMILY_SCRIPT. The transaction then builds the token response and commits PostgreSQL through the exchange coordinator.                                                                                                                                                                                                                                                                                                                                                                          | A consumed code enters token issuance and the family link returns missing/invalid_state, throws, times out ambiguously or succeeds before a later DB/response failure.                                                                                  | Static read confirms ignored status and selected rescue. No fault injection or multi-store result was observed.                                                                                                                        | Exact return enum and caller interpretation; rollback boundaries; timeout completion; credentials after response loss; bounded RecordNotUnique retry; same-session/client concurrency.                                                                                                    |
| ADV-005 / REQ-016, 030, 031, 059         | app/services/oidc_token_exchange_coordinator.rb#exchange_authorization_code! consumes at 109–117, then #issue_tokens_for_consumed! (130) performs later work; DPoP proof verification is in that post-consume path. Base OAuth requests enter via BaseOauthTokenEndpoint#create. Resource requests pass through AuthenticationBase#load_from_token and AuthenticationCurrentResourceResolver. DpopProofVerifier#verify_nonce accepts blank nonce; DPoP state stores by actor type without an issuer/endpoint field.                                                                                                                                                                                                                                                                                                                             | AS client requests a DPoP-bound exchange with invalid proof; or a protected resource request emits `DPoP-Nonce` and a subsequent proof omits it; or AS/RS endpoints share actor-specific nonce storage.                                                 | Static ordering and caller trace only. No AS/RS request, response header, follow-up, or code/session state was observed.                                                                                                               | Client policy, exact AS error/header, RS challenge intent and exact failure response, omission behavior, nonce scope across server roles, and code/family/session state after rejection and retry. RFC 9449 nonce use is optional, but issued nonce claims are required by §§4.2–4.3.     |
| ADV-006 / REQ-007–010, 032, 051–056, 065 | app/controllers/auth/app/sign/in/emails_controller.rb#update reaches AuthenticationSessionCommitter.call around 336 after OTP success; com counterpart around 129. app/operations/authentication_session_committer.rb#call uses controller.send(:establish_signed_in_session!, ...) (18–20); implementation is in app/controllers/concerns/authentication_base.rb#establish_signed_in_session! (2470). BaseAuthAdmissionCoordinator#consume_result! / #validate_payload! exist in app/services/base_auth_admission_coordinator.rb (86–160).                                                                                                                                                                                                                                                                                                     | A directly invoked credential leaf action, not a protected selector, can commit Auth-side or Base-side state which is then accepted without valid Base-owned admission.                                                                                 | Source identifies candidate call paths and validation machinery; no request with missing/valid/expired/replay/mismatched admission was executed, and no cookie/token/database state diff was observed.                                 | Inherited filters and callback order for every app/com/org route; cookie ownership; Base acceptance result; Auth and Base rows/tokens; DBSC binding; all signup, Step-Up, social, Entra, SecretKey, Emergency and sign-out flows.                                                         |
| ADV-012 / REQ-010, 041–044               | app/controllers/auth/app/sign/ins_controller.rb#show and #show in ups call AuthCeremonyAdmission#admit_or_render_sign_ceremony!; app/controllers/concerns/auth_ceremony_admission.rb sends anonymous no-admission requests through #bridge_to_base_admission! to Base host path /. app/controllers/base/app/roots_controller.rb#ceremony_sign_in_href/#ceremony_sign_up_href (98–104) return Auth URLs without admission; com/org roots have equivalent helpers.                                                                                                                                                                                                                                                                                                                                                                                | An anonymous user opens Base root, clicks sign-in/sign-up, then follows the Auth redirect with no admission.                                                                                                                                            | Static source chain demonstrates a Base-root → Auth-selector → Base-root cycle candidate on app, with analogous com/org code. No browser/HTTP redirect following was performed.                                                        | Runtime hosts, redirect limits/canonicalization, callback order and exact sequence in a safe test request. The selected UX must break the cycle without a fake RP.                                                                                                                        |
| ADV-008 / REQ-021–027, 038–040           | `config/routes/guid.rb` maps the public GUID host to GET `/api/v0/resources/:guid`; `app/controllers/guid/net/api/v0/resources_controller.rb` performs transport validation but no authoritative lookup. The safely booted route table confirms the declaration is loaded. Existing GUID ADR/docs and OpenAPI route-coverage test list are additional contract evidence.                                                                                                                                                                                                                                                                                                                                                                                                                                                                        | A public client expects a registered identifier to resolve; persistence and OpenAPI owner must be selected.                                                                                                                                             | Static controller/doc audit plus runtime route enumeration only. No GUID request, lookup result, 404/5xx distinction or redirect behavior was exercised.                                                                               | Source of truth for resolver data, host-to-database routing, JSON error contract, net OpenAPI publication and client impact of `:guid` versus `:id`.                                                                                                                                      |
| ADV-007 / REQ-006, 064, 066, 069         | config/database.yml declares distinct `test_*` and `development_*` PostgreSQL database names; the test host may fall back to `POSTGRESQL_HOST`. `AUTH_STATE_REDIS_URL` points to logical DB 2, which examples also use for development. Store unit tests add unique suffixes, but default request-path stores do not. `test/test_helper.rb` injects a Turnstile verifier that can fall through to the real verifier; outbound HTTP stubs are per-test.                                                                                                                                                                                                                                                                                                                                                                                          | Rails boot/test reaches those configured targets or a non-stubbed provider call.                                                                                                                                                                        | Static environment inspection only; no database, Valkey, or provider was contacted. `bin/ci` begins with test `db:prepare`; it was not run.                                                                                            | Fully resolved test DB identity, disposable isolated Valkey, run/worker key scope for request paths, suite-wide egress control, background/cache/rate-limit stores and safe `db:prepare`.                                                                                                 |

## 7. Adjudication

| Finding | Decision           | Reason                                                                                                                                                                                                                                                                                                                 |
| ------- | ------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| ADV-001 | ACCEPTED           | Exact source absence is a traceability blocker, not a reason to stop all static planning.                                                                                                                                                                                                                              |
| ADV-002 | ACCEPTED           | Issuer/exchanger source conflicts with event-time contract. Correct the whole event path, not only one assignment.                                                                                                                                                                                                     |
| ADV-003 | ACCEPTED           | Current client must prove ownership before triggering replay side effects. Preserve same-owner reuse detection.                                                                                                                                                                                                        |
| ADV-004 | ACCEPTED           | Required linkage cannot be silently treated as success. Store ambiguity needs explicit response/recovery, not broad rescue.                                                                                                                                                                                            |
| ADV-005 | PARTIALLY_ACCEPTED | AS nonce challenge is optional and not wired in the token endpoint; resource authentication does emit a nonce header, while the verifier accepts omission. Test whether the RS header is a challenge and enforce only the policy actually elected. Do not universally promise code reuse.                              |
| ADV-006 | PARTIALLY_ACCEPTED | Candidate path needs inherited callback and Base acceptance evidence. No confirmed bypass; direct-entry UX remains undecided.                                                                                                                                                                                          |
| ADV-007 | ACCEPTED           | No Rails baseline without service isolation; safe frontend/static checks remain useful.                                                                                                                                                                                                                                |
| ADV-008 | PARTIALLY_ACCEPTED | GUID storage and public net docs require a decision. Independent route work remains available.                                                                                                                                                                                                                         |
| ADV-009 | ACCEPTED           | Reuse current abstractions and establish discarded_at semantics before schema changes.                                                                                                                                                                                                                                 |
| ADV-010 | ACCEPTED           | Cover every real JSON endpoint; do not hide coverage gaps with broad exclusions.                                                                                                                                                                                                                                       |
| ADV-011 | ACCEPTED           | New complexity requires observable need and measurable benefit.                                                                                                                                                                                                                                                        |
| ADV-012 | ACCEPTED           | The selector bridge and Base root links form a source-traced cycle candidate. Resolve the UX only after a user decision; test the public redirect chain before calling it fixed.                                                                                                                                       |
| ADV-013 | ACCEPTED           | The test's catch-all feature flag stub turns on the documented Turnstile outage degradation. Separate ordinary verification failure from explicitly accepted outage fallback; no production-policy change is implied.                                                                                                  |
| ADV-014 | ACCEPTED           | All inspected request, transaction and verifier boundaries drop or fail to check parameters/claims required for OIDC freshness. OIDC Core §§3.1.2.1, 3.1.2.3 and 15.1 make the expected behavior normative; public request outcomes remain unobserved. Fix and test the real RP-originated OIDC route after isolation. |
| ADV-015 | PARTIALLY_ACCEPTED | Static code proves the endpoint/response shape mismatch, but the active client contract is unverified. Do not silently choose an implementation; trace client use and obtain the owning API decision before changing response or grant semantics.                                                                      |

No BLOCKER/HIGH finding was resolved by voting. Resolution follows authority ownership, protocol
correctness, repository evidence, external contract, testability and operational safety. ADV-014 is
accepted as a source-level protocol gap; it is not a reproduced request-level impact. Overall GO is
not manufactured.

## 8. Revised target architecture

1. Base remains the sole physical IdP/AS and the authority that accepts identity, Base browser
   session, RP session, final assurance and authorization. Auth may maintain actor-specific
   temporary ceremony continuity and return verified evidence; it is not an RP or final
   token/session authority.
2. No Auth credential evidence/session may be accepted as Base login without a valid Base-owned
   admission bound to purpose, actor, realm/surface and browser. The standalone entry URL, local
   signup, success destination, failure/restart UX and already-authenticated behavior remain
   unresolved. No fake client_id, redirect_uri, authorization code, ID Token or RP session may be
   used for local entry.
3. Authentication event time is a distinct immutable event instant accepted by Base. Code issued_at,
   session start, JWT iat and AR timestamps remain separate. Missing trustworthy event time means
   actual reauthentication or non-authenticating failure, never now or created_at/updated_at.
4. The OP must preserve and evaluate valid OIDC `prompt`/`max_age` requests through parameter
   filtering and transaction resume: `prompt=login` attempts reauthentication even for an existing
   session; `prompt=none` does not render an interactive ceremony and returns the applicable OIDC
   error if silent completion is impossible; stale `max_age` requires reauthentication, and
   `max_age=0` is equivalent to `prompt=login`. When `max_age` applies, the ID Token carries the
   original accepted `auth_time`, and the RP verifies the resulting claim contract. Project Access
   JWT `auth_time` remains a separate project contract.
5. If OIDC refresh is supported for a registered RP, the public token endpoint must accept the
   returned refresh credential under the documented grant contract, rotate it safely and preserve
   the original authentication time while issuance `iat` advances. If no production client contract
   consumes the returned field, changing either side requires an explicit contract decision. Base
   cookie refresh and unrelated legacy token refresh are not evidence of OIDC refresh support.
6. Authorization-code replay remains denied. Ruby and Lua must bind replay classification and
   revocation to client, exact registered redirect URI and effective PKCE owner before side effect.
   The code is never unconsumed. Required tombstone family linkage must have an explicit positive
   success state before issuing new credentials.
7. PostgreSQL and Valkey are separate consistency domains. No plan may imply shared ACID. Every
   partial failure defines persisted code state, database state, client-held credentials, retry
   policy, repair and user restart.
8. Core, Side and Edit use common RP protocol mechanics with per-RP identity/config at boundary.
   Seven browser clients remain distinct; Edit uniqueness does not leak into common code. Preserve
   RP session parent ownership and selective revocation.
9. Existing short-lived Access JWTs may remain valid until exp after logout/revocation. Future
   refresh/new issuance stops. No per-request DB session lookup, introspection or denylist is added.
10. DPoP follows RFC 9449 in implemented paths, while current per-client enforcement remains until
    separately validated. Nonce is optional, but once issued its retry contract is mandatory. DBSC
    stays progressive enhancement; unsupported browser flow remains usable.
11. Reuse Base::Identity::ActivityLogPresenter’s event/risk/visibility classification and
    SessionTimestampHelper. ClientChronicle.level_id means log severity, not risk. Use explicit
    Emergency context, not DBSC binding.
12. Migrate user session management to /sessions only as a complete owner-scoped resource and
    preserve /sign/out plus Core /api/v0/session semantics. Prove discarded_at is a non-sliding
    absolute ceiling across all actor token types before relying on it; current cap usage is
    supporting evidence, not complete proof.
13. Keep guid.umaxica.net and current /api/v0/resources path. No catch-all, ID generation/gem,
    registration API, or canonical_url redirect. Do not pick a database or public net OpenAPI
    structure by convenience.
14. Apply current Base/Auth root ADR; verify 14 candidate authenticated roots. Core/Palm get no
    fictitious dashboards. Preserve documented CSP and .well-known mappings.
15. Keep AAL, FAL, actual amr, accepted acr, freshness and phishing resistance distinct. Preserve
    accepted SMS risk; do not claim NIST conformance without complete assessment.

## 9. Requirement traceability matrix and provisional ledger

Each ID has one primary implementation owner. All rows use the provisional aliases from the prior
draft, not missing source wording. Classes use INV invariant, ARCH architecture, FUNC functional,
SEC security, DATA data contract, API API contract, ROUTE routing, NFR non-functional, TEST test,
DOC documentation, PREF implementation preference, CLEAN cleanup and INVEST investigation. M* means
the latest V2 requires the ID be traced; its original strength remains unknown. P = partial
static/limited test evidence only; U = behavior unverified; S = exact source incomplete.

Documentation abbreviations: AD-A authority boundary ADR; AD-O OIDC claims/transactions; AD-AL
assurance docs and follow-up; AD-SMS accepted risk; AD-DP DPoP/DBSC docs; AD-API route vocabulary
ADR and OpenAPI source/bundle; AD-G GUID ADR/docs; AD-R root/authority docs; AD-T timestamp
policy/ADR; AD-S session docs; AD-Activity activity privacy/classification docs; AD-STAY social link
ADR; AD-Auth authentication/Turnstile docs; AD-Mail mailer/i18n docs; AD-CI baseline/verification
report. "No" means no document change unless implementation makes a current statement false.

| ID      | Provisional atomic summary; class / force                                                        | Primary phase and dependency     | Test/evidence                                                                              | Doc impact                                   | Observable acceptance; current status                                                                                                                                                                                                                                                                                |
| ------- | ------------------------------------------------------------------------------------------------ | -------------------------------- | ------------------------------------------------------------------------------------------ | -------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| REQ-001 | Planning only the original V2 audit; INV / M*                                                    | E0, none                         | Worktree and command audit                                                                 | refactor.md                                  | Satisfied for the audit snapshot; later bounded source/test slices are explicitly recorded as a continuation and are not the full 95-item implementation.                                                                                                                                                            |
| REQ-002 | Evidence hierarchy/conflict preservation; INVEST / M*                                            | E0, none                         | Source, ADR, protocol, contract comparison                                                 | affected ADR only                            | No silent reconciliation; P                                                                                                                                                                                                                                                                                          |
| REQ-003 | Deliver plan before later implementation; DOC/TEST / M*                                          | E10, all phases                  | 95-row source/trace audit                                                                  | refactor.md                                  | Plan delivered before the separately authorized continuation; full implementation still has not started; P                                                                                                                                                                                                           |
| REQ-004 | Store plan at repository root; DOC / M*                                                          | E10, none                        | file + status comparison                                                                   | refactor.md                                  | Plan exists at root; current write authorized.                                                                                                                                                                                                                                                                       |
| REQ-005 | Preserve worktree; no current Git mutation; INV / M*                                             | E0/E10, none                     | start/end status                                                                           | None                                         | Existing work untouched; no commit now.                                                                                                                                                                                                                                                                              |
| REQ-006 | No unsafe service/live-provider/server use; SEC/NFR / M*                                         | E0, none                         | isolated target and egress proof                                                           | AD-CI if needed                              | Tests cannot touch shared/live services; BLOCKED_BY_ENVIRONMENT.                                                                                                                                                                                                                                                     |
| REQ-007 | Base sole physical IdP/AS; ARCH/INV / M*                                                         | E2/E4, E0                        | Base issuance/admission integration                                                        | AD-A                                         | Only Base accepts identity/session; U.                                                                                                                                                                                                                                                                               |
| REQ-008 | Auth ceremony only; ARCH/SEC / M*                                                                | E2, E0                           | per-surface credential/result state tests                                                  | AD-A                                         | Auth state never proves Base login; U.                                                                                                                                                                                                                                                                               |
| REQ-009 | RP→Base→Auth→Base→real RP flow; ARCH/API / M*                                                    | E2/E4, E0                        | successful callback and negative tests                                                     | AD-A, AD-O                                   | No RP-facing result issued by Auth; U.                                                                                                                                                                                                                                                                               |
| REQ-010 | No admission bypass or pseudo-RP; UX unresolved; INV/SEC / M*                                    | E2, E0 + decision                | absent/malformed/mismatch handoff                                                          | AD-A, direct-entry plan                      | No unauthorized Base state; UX not chosen; U.                                                                                                                                                                                                                                                                        |
| REQ-011 | auth_time is accepted credential event; DATA/SEC / M*                                            | E3, E0                           | T0<T1<T2, reauthentication, and any supported refresh                                      | AD-O                                         | ID/Access claim stays T0 until a real accepted reauthentication; no fallback. Static issuance mapping defect confirmed; dynamic behavior U.                                                                                                                                                                          |
| REQ-012 | Base decides acr; amr are methods used; DATA/ARCH / M*                                           | E3, E2                           | claims across sign-in/Step-Up/reissue                                                      | AD-O, AD-AL                                  | Accepted claims reflect actual evidence; U.                                                                                                                                                                                                                                                                          |
| REQ-013 | Separate sign-in, Step-Up, AAL, phishing resistance, freshness, FAL; ARCH/DOC / M*               | E3, E0                           | assurance contract audit                                                                   | AD-AL                                        | No dimension collapsed or unassessed NIST claim; U.                                                                                                                                                                                                                                                                  |
| REQ-014 | Retain explicit SMS usability risk; SEC/DOC / M*                                                 | E3, E0                           | SMS claims and sensitive-action tests                                                      | AD-SMS, AD-AL                                | SMS not phishing resistant/AAL2; U.                                                                                                                                                                                                                                                                                  |
| REQ-015 | Short Access JWT may live until exp; no online lookup; ARCH/SEC / M*                             | E4, E1/E2/E3                     | revocation + request-query test                                                            | AD-A/AD-O risk                               | Future refresh stops; old JWT policy unchanged; U.                                                                                                                                                                                                                                                                   |
| REQ-016 | DPoP audited to RFC 9449; SEC/API / M*                                                           | E5, E1/E4                        | proof, endpoint, RS tests                                                                  | AD-DP                                        | Per-client policy correct; U.                                                                                                                                                                                                                                                                                        |
| REQ-017 | DBSC progressive enhancement; SEC/FUNC / M*                                                      | E5, E0/E4                        | lifecycle and unsupported fallback                                                         | AD-DP                                        | Legitimate unsupported users remain usable; U.                                                                                                                                                                                                                                                                       |
| REQ-018 | No fake device validation; TEST/DOC / M*                                                         | E5 validation debt               | real representative device/browser evidence                                                | AD-DP/plans                                  | No validated claim without evidence; deferred.                                                                                                                                                                                                                                                                       |
| REQ-019 | Bounded follow-up plans; DOC / M*                                                                | E10, source audit                | review all plan exit criteria                                                              | AAL, direct-entry, DPoP/DBSC, residual plans | Each has problem, impact, prereqs, test, exit; U.                                                                                                                                                                                                                                                                    |
| REQ-020 | No security/test weakening; INV/SEC/TEST / M*                                                    | E0–E10 horizontal                | every diff/config/test review                                                              | AD-CI                                        | Gates and negative tests remain; U for future phases.                                                                                                                                                                                                                                                                |
| REQ-021 | Opaque GUID lookup, no generator/gem; FUNC/API / M*                                              | E8, owner decision               | exact-match lookup                                                                         | AD-G                                         | Arbitrary registered ID resolves; U.                                                                                                                                                                                                                                                                                 |
| REQ-022 | Unique/non-null eid, kind/status required, nullable URL; DATA/SEC / M*                           | E8, persistence owner            | model + DB unique tests                                                                    | AD-G/schema                                  | DB constraint and input limits; blocked decision.                                                                                                                                                                                                                                                                    |
| REQ-023 | Scoped resolver route, no catch-all; ROUTE / M*                                                  | E8, E0                           | host/path request tests                                                                    | AD-G/AD-API                                  | Existing scoped route only; P/U.                                                                                                                                                                                                                                                                                     |
| REQ-024 | Found 200 HTML/JSON, unknown 404, outage 5xx; API / M*                                           | E8, persistence decision         | content negotiation + failure injection                                                    | AD-G/AD-API                                  | Correct three-way status contract; U.                                                                                                                                                                                                                                                                                |
| REQ-025 | No canonical_url redirect; SEC/API / M*                                                          | E8, none                         | Location header negative assertion                                                         | AD-G                                         | Canonical URL only displayed safely; U.                                                                                                                                                                                                                                                                              |
| REQ-026 | IDs not reused; no public registration/tombstone overbuild; DATA/FUNC / M*                       | E8, data owner                   | duplicate/deletion lifecycle tests                                                         | AD-G                                         | DB prevents reuse; no registration route; U.                                                                                                                                                                                                                                                                         |
| REQ-027 | Safe opaque input/SQL/HTML/host; SEC/TEST / M*                                                   | E8, E0                           | encoded, long, controls, injection, escaping, host                                         | AD-G/AD-API                                  | Safe lookup and rendering; U.                                                                                                                                                                                                                                                                                        |
| REQ-028 | Core/Side/Edit share RP primitives; ARCH / M*                                                    | E4, E1/E2/E3                     | shared RP contract                                                                         | AD-A/RP docs                                 | Semantically common protocol has one implementation; U.                                                                                                                                                                                                                                                              |
| REQ-029 | Edit singleton config does not constrain Core/Side scale; ARCH / M*                              | E4, registry                     | multi-instance client tests                                                                | RP docs                                      | No singleton branch in shared mechanics; U.                                                                                                                                                                                                                                                                          |
| REQ-030 | State/nonce/PKCE/JWT/session/logout plus OIDC request-freshness invariants; SEC/API / M*         | E4, E0/E1/E3                     | full positive/negative protocol matrix including prompt/max_age and RP ID Token validation | AD-O/RP docs                                 | All invariants pass; source gap for prompt/max_age/auth_time validation confirmed on inspected paths; public behavior U.                                                                                                                                                                                             |
| REQ-031 | Callback failure/recovery public tests; TEST / M*                                                | E4, E1/E2                        | callback/error contract matrix                                                             | RP docs                                      | Named failures deny safely and restart; U.                                                                                                                                                                                                                                                                           |
| REQ-032 | Auth not an RP, Base authority; ARCH/INV / M*                                                    | E2/E4, E0                        | client registry/dependency audit                                                           | AD-A                                         | Auth absent from RP authority; U.                                                                                                                                                                                                                                                                                    |
| REQ-033 | Preserve justified path mappings; ROUTE/INV / M*                                                 | E8, route inventory              | classify every path override                                                               | AD-API/routing docs                          | CSP and .well-known remain justified; P.                                                                                                                                                                                                                                                                             |
| REQ-034 | Full route and legacy/API inventory; INVEST/TEST / M*                                            | E8, E0                           | static + safe bin/rails routes                                                             | AD-API                                       | Every route file and prefix classified; runtime U.                                                                                                                                                                                                                                                                   |
| REQ-035 | Move valuable safe app APIs to /api/v0; ROUTE/API / M*                                           | E8, E0                           | caller/request/OpenAPI tests                                                               | AD-API                                       | Route/controller/caller/contract align; U.                                                                                                                                                                                                                                                                           |
| REQ-036 | Delete only evidenced dead surfaces; CLEAN/ROUTE / M*                                            | E8, E0                           | callsite/ingress/contract evidence                                                         | AD-API, actionable FIXME only                | No dead aliases or guessed deletions; U.                                                                                                                                                                                                                                                                             |
| REQ-037 | Default :id only if contract safe; ROUTE/API / M*                                                | E8, client evidence              | URL + OpenAPI/generated client comparison                                                  | AD-API/AD-G                                  | Opaque URL unchanged; parameter choice justified; U.                                                                                                                                                                                                                                                                 |
| REQ-038 | OpenAPI covers all app JSON APIs incl. Edit/public GUID if decided; API/DOC / M*                 | E8, net decision                 | route coverage per host/surface                                                            | AD-API                                       | No undocumented app JSON or broad exception; U.                                                                                                                                                                                                                                                                      |
| REQ-039 | Sources and generated bundles match; DOC/TEST / M*                                               | E8, source edits                 | lint, bundle, idempotence, verify                                                          | AD-API                                       | OpenAPI 3.0.4 output deterministic; U.                                                                                                                                                                                                                                                                               |
| REQ-040 | Protocol exemptions narrow; exact contracts; API/SEC / M*                                        | E8, route inventory              | Committee/status/content/security/cache tests                                              | AD-API                                       | Every exemption has protocol reason and test; U.                                                                                                                                                                                                                                                                     |
| REQ-041 | Authoritative root-surface inventory and behavior; FUNC/ROUTE / M*                               | E8, safe runtime routes          | 14-candidate surface matrix                                                                | AD-R                                         | True inventory and destinations verified; U.                                                                                                                                                                                                                                                                         |
| REQ-042 | Valid ri and safe temporary redirect; SEC/ROUTE / M*                                             | E8, E0                           | region and open-redirect negatives                                                         | AD-R                                         | ri retained only safely; U.                                                                                                                                                                                                                                                                                          |
| REQ-043 | No fake Core/Palm dashboards or JSON redirects; ARCH/FUNC / M*                                   | E8, surface evidence             | browser/machine/native behavior                                                            | AD-R                                         | Root is architecture-derived; U.                                                                                                                                                                                                                                                                                     |
| REQ-044 | Follow current accepted Base/Auth root ADR; ARCH/DOC / M*                                        | E8, accepted ADR                 | routes/controllers/ADR comparison                                                          | AD-A/AD-R                                    | No retired dashboard/lobby reintroduced; P/U.                                                                                                                                                                                                                                                                        |
| REQ-045 | created_at/updated_at are persistence metadata; INV/DATA / M*                                    | E9, E0 green                     | semantic callsite audit                                                                    | AD-T                                         | No domain use without separate semantic timestamp; U.                                                                                                                                                                                                                                                                |
| REQ-046 | Timestamp aliases need read/write/query proof; DATA/CLEAN / M*                                   | E9, inventory                    | alias contract tests                                                                       | AD-T                                         | No implicit/synthetic alias; U.                                                                                                                                                                                                                                                                                      |
| REQ-047 | No fabricated timestamp backfill; DATA/SEC / M*                                                  | E9, schema owner                 | disposable migration/backfill review                                                       | AD-T/migration doc                           | Every value has lifecycle provenance; U.                                                                                                                                                                                                                                                                             |
| REQ-048 | Narrow existing-harness timestamp rules; TEST/CLEAN / M*                                         | E9, baseline                     | positive/negative harness fixture                                                          | AD-T                                         | No extra harness or broad false-positive exception; U.                                                                                                                                                                                                                                                               |
| REQ-049 | Semantic event time changes only at true event; DATA/TEST / M*                                   | E9, event owner                  | transition vs unrelated update                                                             | AD-T                                         | Event timestamp is stable under incidental save; U.                                                                                                                                                                                                                                                                  |
| REQ-050 | Private-test cleanup maintains coverage; TEST/CLEAN / M*                                         | E9, green E0                     | public behavior + explicit coverage                                                        | AD-CI                                        | Current floors/max-drop all pass; U.                                                                                                                                                                                                                                                                                 |
| REQ-051 | ORG Entra, independent normal SecretKey, Emergency distinct; FUNC/SEC / M*                       | E3, E0/E2                        | ORG route-to-committer flows                                                               | AD-A/ORG docs                                | Separate authorized paths; U.                                                                                                                                                                                                                                                                                        |
| REQ-052 | Entra single-tenant, pre-provisioned, no JIT; SEC/API / M*                                       | E3, provider stub                | tenant/state/PKCE/nonce integration                                                        | ORG identity docs                            | Existing boundary unchanged; U.                                                                                                                                                                                                                                                                                      |
| REQ-053 | Independent SecretKey entry is owner-bound; FUNC/SEC / M*                                        | E3, E2                           | correct/wrong operator and realm                                                           | ORG auth docs                                | No Entra-only second-stage dependency; U.                                                                                                                                                                                                                                                                            |
| REQ-054 | Emergency remains restricted; no normal fallback/mode switch; SEC/ARCH / M*                      | E3/E9, E0                        | Emergency auth/authorization/session test                                                  | Emergency docs                               | Cannot gain ordinary authority; U.                                                                                                                                                                                                                                                                                   |
| REQ-055 | ORG signup follows actual policy; FUNC / M*                                                      | E3, source/policy                | eligibility positive/negative test                                                         | ORG signup docs                              | Shown only where permitted; exact source phrasing P.                                                                                                                                                                                                                                                                 |
| REQ-056 | ORG host/i18n isolation; Emergency not promoted; INV/FUNC / M*                                   | E3, E0                           | locale/host/UI test                                                                        | ORG docs                                     | ORG boundary remains distinct; U.                                                                                                                                                                                                                                                                                    |
| REQ-057 | Seven clients have independent config and required auth/PKCE; SEC/DATA / M*                      | E4, E0                           | seven-client registry test                                                                 | RP docs                                      | No key/redirect/config crossover; U.                                                                                                                                                                                                                                                                                 |
| REQ-058 | RP state protected, short-lived, tab-safe and callback-bound; SEC/DATA / M*                      | E4, E0                           | multi-tab/state/return tests                                                               | RP docs                                      | No state mix-up/open redirect; U.                                                                                                                                                                                                                                                                                    |
| REQ-059 | Code digest, TTL, atomic one-use and fail-closed; DATA/SEC / M*                                  | E1, E0                           | real Lua + Ruby race/fault test                                                            | AD-O/store contract                          | Single winner; failure never silently succeeds; U.                                                                                                                                                                                                                                                                   |
| REQ-060 | Assertion JTI unique and fail-closed; SEC/DATA / M*                                              | E1/E4, E0                        | replay/uniqueness/store tests                                                              | AD-O                                         | Same JTI cannot authorize twice; U.                                                                                                                                                                                                                                                                                  |
| REQ-061 | Identity→Base→RP ownership and unique active parent/client; ARCH/DATA / M*                       | E4, E1                           | PG uniqueness/concurrency tests                                                            | session hierarchy ADR                        | No duplicate active child session; U.                                                                                                                                                                                                                                                                                |
| REQ-062 | Scoped revocation; no normal JWT request DB lookup; SEC/INV / M*                                 | E4, E0                           | revoke hierarchy and query tests                                                           | accepted residual docs                       | New refresh denied, existing JWT until exp; U.                                                                                                                                                                                                                                                                       |
| REQ-063 | Client registry and user RP sessions are separate resources; FUNC/ARCH / M*                      | E4, policy                       | authorized request/UI tests                                                                | admin/session docs                           | Distinct owners/capabilities; U.                                                                                                                                                                                                                                                                                     |
| REQ-064 | Valkey topology/transport and isolated namespace; NFR/SEC / M*                                   | E0, none                         | connection and namespace canary                                                            | operations/CI docs                           | No flush or shared test data; BLOCKED_BY_ENVIRONMENT.                                                                                                                                                                                                                                                                |
| REQ-065 | Retire only obsolete Auth RP dependencies; keep ceremony and Jump JWKS; CLEAN/ARCH / M*          | E2, dependency proof             | route/caller/JWKS regression                                                               | AD-A                                         | Jump-compatible key path retained; U.                                                                                                                                                                                                                                                                                |
| REQ-066 | Green explicit Rails coverage baseline precedes broad cleanup; TEST / M*                         | E0/E9, isolation                 | COVERAGE=true full suite                                                                   | AD-CI                                        | Attributable counts and dimensions; BLOCKED_BY_ENVIRONMENT.                                                                                                                                                                                                                                                          |
| REQ-067 | Replace private tests with public/framework behavior; TEST/CLEAN / M*                            | E9, green E0                     | per-candidate public lifecycle tests                                                       | test policy                                  | No reflection-based substitute; U.                                                                                                                                                                                                                                                                                   |
| REQ-068 | Public API minimized; protected only real extension point; CLEAN/ARCH / M*                       | E9, green E0                     | caller graph and architecture harness                                                      | method visibility docs                       | Production callers still work; U.                                                                                                                                                                                                                                                                                    |
| REQ-069 | Keep all quality/security gates; INV/TEST / M*                                                   | E0/E10                           | config diff + full checks                                                                  | AD-CI                                        | No weakened gate/skip/exclusion; U.                                                                                                                                                                                                                                                                                  |
| REQ-070 | Existing account Google/Apple link needs fresh Step-Up; SEC/FUNC / M*                            | E7a, E0/E2                       | each provider start + callback                                                             | AD-STAY                                      | Accepted ADR and app integration tests now exist; code/test present, Rails execution pending. Direct callback with an invalid/prebuilt grant is not yet proven.                                                                                                                                                      |
| REQ-071 | Signup enrollment distinct; unlink Step-Up; no auto reuse; SEC/FUNC / M*                         | E7a, E0/E2                       | signup/link/unlink/last method + callback bypass                                           | AD-STAY                                      | ADR and tests cover sign-up separation, unlink Step-Up and last-method guard; direct callback proof and runtime remain pending.                                                                                                                                                                                      |
| REQ-072 | Record existing STAY decision, avoid needless prod change; ARCH/DOC / M*                         | E7a, source audit                | code/ADR symmetry and callback bypass                                                      | AD-STAY                                      | ALREADY_SATISFIED for accepted ADR; no duplicate ADR or production change planned unless an observed bypass contradicts it.                                                                                                                                                                                          |
| REQ-073 | Successful sign-out removes both issued-scope cookies; SEC/FUNC / M*                             | E7b, isolated browser            | Set-Cookie + CookieJar                                                                     | sign-out docs                                | auth_access/auth_refresh absent at lobby; U.                                                                                                                                                                                                                                                                         |
| REQ-074 | Immediate re-sign-in and app/com/org cookie isolation; TEST/SEC / M*                             | E7b, E0                          | logout then fresh sign-in                                                                  | auth cookie docs                             | No stale credential is accepted; U.                                                                                                                                                                                                                                                                                  |
| REQ-075 | User sign-in sessions use /sessions; preserve /sign/out and Core /api/v0/session; API/ROUTE / M* | E9, route audit                  | new/old helper, ceremony/API tests                                                         | AD-S                                         | Three contracts stay distinct; U.                                                                                                                                                                                                                                                                                    |
| REQ-076 | Owner-scoped, CSRF-safe session actions; no GET mutation; SEC/ROUTE / M*                         | E9, E0                           | foreign ID/CSRF/GET tests                                                                  | AD-S                                         | Only owner can revoke via unsafe method; U.                                                                                                                                                                                                                                                                          |
| REQ-077 | Current-session marker and other-session sign-out UI; FUNC/SEC / M*                              | E9, E0                           | DOM/props and forged ID test                                                               | AD-S                                         | Internal IDs hidden; current session not self-revoked there; U.                                                                                                                                                                                                                                                      |
| REQ-078 | Event/risk/visibility separate; internal filtered in SQL; DATA/SEC / M*                          | E9, current presenter            | pagination/count/visibility query                                                          | AD-Activity                                  | user/user_attention visible, internal absent; P/U.                                                                                                                                                                                                                                                                   |
| REQ-079 | No raw activity context, IP/secrets or technical enum; SEC/FUNC / M*                             | E9, E0                           | props/DOM/escape test                                                                      | AD-Activity                                  | Only safe normalized events; U.                                                                                                                                                                                                                                                                                      |
| REQ-080 | Session UI shows safe device/status/expiry, hides internals; FUNC/SEC / M*                       | E9, E0                           | app/com/org DOM tests                                                                      | AD-S                                         | Device/Unknown and no token IDs/binding/refresh TTL; P/U.                                                                                                                                                                                                                                                            |
| REQ-081 | Enforced non-sliding absolute expiry; DATA/SEC / M*                                              | E9, E0/E3/E4                     | token/DBSC boundary and no-revival                                                         | AD-S/session lifetime ADR                    | Rotations and renewals never exceed ceiling; P/U.                                                                                                                                                                                                                                                                    |
| REQ-082 | Emergency mode from explicit context, independent of DBSC; SEC/DATA / M*                         | E9, E0                           | mode × DBSC cases                                                                          | Emergency/DBSC docs                          | No DBSC-based inference; P/U.                                                                                                                                                                                                                                                                                        |
| REQ-083 | Preference timezone/date/clock and instant sorting; FUNC/DATA / M*                               | E9, helper exists                | timezone/day/date/clock boundary tests                                                     | preference docs                              | Shared formatter, sort on absolute instant; P/U.                                                                                                                                                                                                                                                                     |
| REQ-084 | i18n, query bounds, owner/surface isolation; NFR/SEC / M*                                        | E9, E0                           | N+1 + realm tests                                                                          | AD-S/Activity                                | No cross-read, leak or new N+1; U.                                                                                                                                                                                                                                                                                   |
| REQ-085 | Server props for inert Create; Avatar Up href; FUNC/API / M*                                     | E6, current Base Root ADR        | React role/disabled test + Rails props                                                     | self-service docs                            | Inert actions and server link exist; React passed. Exact href is BLOCKED_BY_DECISION: source prompt says `/dashboard`, accepted ADR says Root home. Rails request tests unrun.                                                                                                                                       |
| REQ-086 | No create route/write/policy/provisioning for preview; INV/SEC / M*                              | E6, route audit                  | distinguish existing Avatar CRUD from inert index action                                   | self-service docs                            | Runtime route table shows Base app Accounts/Organizations only have index/show, while Avatar already has POST `/avatars` and new/edit/update routes. Existing Avatar CRUD predates the inert preview and must remain untouched; no create request or controller behavior was exercised.                              |
| REQ-087 | app/com signup email survives allowed 422; FUNC/SEC / M*                                         | E7c, current HEAD code           | controller props + input behavior                                                          | AD-Auth                                      | HEAD restores posted email and keeps GET empty; assertions exist and Vitest passed; Rails tests not run.                                                                                                                                                                                                             |
| REQ-088 | Signup OTP server Turnstile before OTP check; SEC/FUNC / M*                                      | E7c, dirty user diff             | missing/invalid and degraded-off outage tests plus separate degraded-on policy test        | AD-Auth                                      | Current worktree adds app/com guards before OTP verification. The broad feature-flag stubs around the documented default-off rejection cases were removed; missing/invalid/unavailable challenge tests remain present but Rails execution is pending. The separate degraded-on outage policy case is still untested. |
| REQ-089 | Sign-in OTP same server order, enumeration preserved; SEC / M*                                   | E7c, dirty user diff             | real/dummy parity and state tests                                                          | AD-Auth                                      | Current worktree adds app/com server guards before assigning/verifying code and targeted negative tests assert no token/session/OTP-state change. Rails execution and dummy/real parity remain unverified.                                                                                                           |
| REQ-090 | Failed OTP never persists/rerenders; SEC/DATA / M*                                               | E7c, current worktree + dirty UI | props/session/flash/HTML/DOM/reentry                                                       | AD-Auth                                      | Sign-in React clears code/token on finish and remounts the challenge; signup document POST props omit OTP and the component has no value prop. Full failure round-trip and browser DOM re-entry remain unvalidated.                                                                                                  |
| REQ-091 | Turnstile retry gets fresh challenge; SEC / M*                                                   | E7c, dirty user diff             | token use/fail/resend lifecycle                                                            | AD-Auth                                      | Signup OTP pages receive visible widget props and render a fresh widget on rerender; show/failure tests exist in the worktree. Actual single-use provider behavior and browser challenge replacement remain unexecuted.                                                                                              |
| REQ-092 | Preload Visitor recovery associations in bounded operation; NFR/TEST / M*                        | E7c, E0                          | email/phone/none and multi-credential query test                                           | recovery service docs                        | Worktree preloads Visitor/Staff email and telephone associations and adds a public Prosopite regression test; query-count behavior is still U because Rails stopped before assertions.                                                                                                                               |
| REQ-093 | Four app/com signup/signin Rails flows; TEST/INV / M*                                            | E7c, E0/E2/E3                    | four controller integrations through next Rails step                                       | test docs                                    | Rails boundary works; no Jump changes/live call; U.                                                                                                                                                                                                                                                                  |
| REQ-094 | Localized purpose-specific branded OTP subjects; FUNC/DOC / M*                                   | E7c, stub mail                   | locale × purpose mailer tests                                                              | AD-Mail                                      | Worktree carries purpose-aware app/com adapter, notifier, mailer and locale changes plus exact subject/no-OTP tests; Rails mailer/notifier execution is still U because the test database host is unavailable.                                                                                                       |
| REQ-095 | Do not invent missing ORG requirement; INVEST? / strength unknown                                | E0, source recovery              | verify source digest                                                                       | none until known                             | Exact wording preserved; SOURCE-INCOMPLETE.                                                                                                                                                                                                                                                                          |

Mechanical traceability check performed on this revised table: 95 REQ rows, 95 unique IDs, no
missing/out-of-range/duplicate IDs, all rows have six cells, and all primary-phase references
resolve. The DAG in §11 has 13 defined phase nodes and 32 explicit prerequisite edges; a read-only
topological check found no cycle. REQ-020 remains horizontal; REQ-016–019→E5, REQ-055/056→E3,
REQ-064→E0; REQ-085–086→E6; REQ-070–072→E7a; REQ-073–074→E7b; REQ-087–094→E7c. This proves only
internal consistency of the provisional aliases, not fidelity to absent original wording. REQ-095
remains source-incomplete. Per-row implementation states distinguish current code evidence from
runtime validation.

## 10. GO / NO-GO decision

**NO_GO for freezing or executing the complete autonomous 95-item plan now.** This is not a
rejection of Base/Auth architecture and not caused by file-saving restrictions. Source traceability,
security boundaries and the runtime baseline still contain blockers.

A later GO requires the missing plan/review sources or explicit acceptance of a narrowed
traceability scope; resolution of D-ENTRY, D-DASHBOARD and D-OIDC-REFRESH; isolated public-boundary
tests for auth_time/max_age, replay ownership, cross-store recovery and Auth admission; safe test
databases/Valkey/provider stubs; and a GUID persistence owner plus public net OpenAPI contract.
DPoP/DBSC device validation remains a separate deployment gate.

Unresolved D-ENTRY blocks only flows that depend on direct local sign-in. D-DASHBOARD blocks only
the Avatar Up href choice. D-OIDC-REFRESH blocks only changing the refresh response/grant contract,
not T0/T1/T2 authentication-time tests. GUID ownership blocks only GUID persistence/public-contract
completion. Lack of safe Rails services blocks Rails dynamic verification, not static review or
unrelated isolated UI work. In the original planning-only run, no implementation phase was
authorized; these statuses describe what a separately authorized execution run could start after its
prerequisites.

## 11. Candidate implementation plan (not frozen)

This is a dependency-ordered candidate, not a frozen whole-program specification. Phase readiness
below was written for the original V2 planning run; the continuation in §19 records the separately
authorized local slices that have actually begun. A later implementation run for the remaining
program requires source/decision/environment gates and its own baseline. Every behavior change then
uses Red → Green → Refactor, preserves pre-existing work and security gates, and stops locally at
its own blocker. The current V2 safety instruction forbids Git state writes; therefore this
continuation makes no commit even though an earlier request preferred per-step commits. Never stage
or commit the pre-existing user changes listed in §2. For each failed phase, prefer a forward repair
that preserves security/data invariants. Never roll back a consumed authorization code, revive a
revoked/expired credential, reset user data, or reverse a data migration without an approved
data-safe recovery plan.

### Phase E0 — Source, safe targets and attributable baseline

Status: BLOCKED_BY_ENVIRONMENT for Rails/runtime checks; static worktree/source snapshot is
recorded.

- Objective / requirements: establish exact inputs/worktree, safe targets and comparable green
  baseline; REQ-001–006, 064, 066, 069, 095.
- Preconditions: PostgreSQL `test_*` databases are distinct from `development_*` in the checked-in
  config, but confirm the fully resolved database identities without printing credentials before any
  command that can prepare schemas. Provide a Valkey instance or logical database reserved for this
  test run, plus unique run/worker namespaces on request-path stores; current default request-path
  namespaces are fixed, and the active process URL targets DB 2, also used by development examples.
  Establish blocked/stubbed provider egress and identify background/cache/rate-limit connections. A
  test-looking hostname or separate app process does not prove isolation.
- Investigation references: AGENTS.md, .simplecov, config/ci.rb, package.json, vitest.config.ts,
  Gemfile.lock and service/provider connection settings. CI starts with test db:prepare.
- Expected files: none for this evidence stage. Any later test-environment configuration change
  needs separate authorization and must be scoped to disposable test targets.
- Tests first: no application behavior change. Prove disposable targets and egress isolation with
  safe canaries; then record ordinary test results, explicit coverage, skips and per-file/group/drop
  values separately.
- Sequence: snapshot HEAD/status and source inputs; recover S1/S2; capture safe read-only
  route/notes inventory under disposable filesystem overlays; prove PostgreSQL/Valkey/provider
  isolation; capture ordinary Rails baseline; capture Ruby coverage; run static/security; record
  canonical JS coverage separately.
- Verification: `bin/rails routes` and `bin/rails notes` may run before database/service isolation
  only under a read-only workspace with disposable log/cache overlays; these have now passed. After
  isolation, run `bin/rails test`; `COVERAGE=true bin/rails test test/`; `bun run test`;
  `bun run test:coverage`; `bun run format:check`; `bun run lint`; `bun run typecheck:verify`;
  `bun run typecheck`; `bun run deadcode`; `bun run openapi:lint`; `bin/rubocop`;
  `bundle exec erb_lint --lint-all`; established security checks; then `bin/ci` only after its
  `db:prepare`/server smoke targets are proven safe.
- Completion: comparable zero-failure full Rails run with configured gates, actual coverage by
  dimension/file/group/drop, skip reasons, command/exit records, verified source hashes and route
  inventory.
- Rollback / forward repair: No application state is changed in E0; remove diagnostics only from
  disposable temp and never alter shared services.
- Recovery / stop: do not reset/drop/recreate shared databases or flush Valkey. If isolation cannot
  be proved, stop dynamic commands and continue static planning. Never weaken gates to repair
  baseline.

### Phase E1 — Authorization-code ownership and partial failure

Status: READY_WITH_PRECONDITIONS (E0 isolated stores and valid same-realm A/B fixtures).

- Objective / requirements: preserve one-use/replay behavior while preventing wrong-owner revocation
  and silent success on store failure; REQ-020, 059, 060.
- Preconditions: isolated real Valkey running actual Lua scripts and disposable actor databases;
  valid same-realm clients A/B. Each client assertion has a fresh JTI except deliberate replay. DPoP
  proofs are fresh except deliberate proof replay.
- Investigation references: OidcTokenExchangeCoordinator methods exchange_authorization_code!,
  prevalidate_payload, issue_tokens_for_consumed!, link_consumed_family!, revoke_linked_family!;
  AuthorizationCodeStore CONSUME_SCRIPT/LINK_FAMILY_SCRIPT; token endpoint, RP revoker and existing
  request/store tests.
- Expected files: actual coordinator/store/endpoint and focused tests discovered by route tracing.
  Do not add online Access JWT lookup.
- Tests first: A consumes a code; valid B submits the same consumed raw code. Assert denial and no
  change to A/B/unrelated RP session, refresh family or Base session. Same-owner exact replay still
  denies and has only the intended owner effect. Separate wrong client, redirect, effective PKCE
  verifier, expiry, corrupt payload and unused-code tests; prove the replay branch was actually
  reached. Test valid concurrent exchange has one winner and replay races before/after family link.
- Failure injection: link returns missing/invalid_state; Valkey throws; link times out with unknown
  completion; signing/build fails after link; DB commit fails after link; DB commits but HTTP
  response is lost. Record code/Valkey state, PostgreSQL state, credentials delivered/usable, retry
  behavior and recovery. Also test same Base session/client concurrency, family switching and
  ActiveRecord::RecordNotUnique bounded recovery.
- Implementation sequence: bind replay classification in Ruby and Lua to presenting client, exact
  registered redirect and effective PKCE owner before side effects; keep consume
  atomic/irreversible; inspect link statuses; require positive required linkage before issuing
  credentials; define repair/re-auth for every uncertain result.
- Non-change: never delete replay detection/revocation, never unconsume code, do not assume a
  Valkey/PostgreSQL transaction or add a distributed framework without evidence.
- Verification: focused coordinator/store and token endpoint tests with actual isolated Lua/PG
  behavior across app/com/org.
- Completion: wrong client cannot destroy legitimate state; same-owner replay remains denied; no
  success token on unknown required linkage; fresh Base authorization recovers without reusing code.
- Rollback / forward repair: Fix owner/link checks forward; if an isolated test consumed a code,
  discard the fixture and use fresh authorization—never restore the code.
- Stop/recovery: if an ambiguous store result has no safe resolution, fail issuance and require a
  fresh authorized transaction; do not set code back to issued.

Normative source: [RFC 6749](https://www.rfc-editor.org/rfc/rfc6749.html), §§4.1.2 and 4.1.3 at the
AS token endpoint/code store. Reuse denial and client binding apply; cross-client non-destruction is
an additional project criterion.

#### E1 static execution order and failure-injection matrix

Observed success-path order in app/services/oidc_token_exchange_coordinator.rb is: grant/client
authentication (44–48) → code read (103–104) → prevalidate (106–107, 136–158) → atomic Valkey
consume (109–117 and AuthorizationCodeStore CONSUME_SCRIPT) → resource/root-session and actor checks
(191–203) → DPoP proof validation (204–205) → PostgreSQL transaction: connection record / RP usage
resolution / refresh token issue-or-rotation (210–227) → Valkey tombstone family link (227; link
method 298–310) → token response signing/build (228–237, 387–415) → PostgreSQL commit → HTTP
response via BaseOauthTokenEndpoint#create. Valkey and PostgreSQL do not share a transaction. This
order is fixed-SHA source observation; individual injected outcomes are not run.

| Fault point                                                                               | Expected remaining state to observe                                                                                                                                                                                                                                       | Retry/recovery criterion                                                                                                                                                                                                                                                 |
| ----------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Invalid grant/client auth or code missing/corrupt on read                                 | No code consume, no RP usage/refresh mutation; exact error class/status from endpoint                                                                                                                                                                                     | Correct client/new authorized flow; no credentials issued.                                                                                                                                                                                                               |
| Prevalidation wrong client, redirect, PKCE, expired/corrupt payload                       | No new consume or RP session mutation; prove replay branch not accidentally reached for a live code                                                                                                                                                                       | Correctly bind code and request; expired requires fresh authorization.                                                                                                                                                                                                   |
| Cross-client replay after A was consumed                                                  | Deny B; preserve A/B/unrelated sessions, families and Base session. Current bounded ordering checks client, redirect and PKCE ownership before the revocation branch in Ruby and Lua; this still needs an isolated race test.                                             | B cannot alter A’s owner state; A’s same-owner replay remains denied and intended revocation is preserved.                                                                                                                                                               |
| Simultaneous consume by two requests                                                      | Exactly one atomic consumed result; loser classified replay/mismatch under an owner-aware policy; inspect whether loser can race before link                                                                                                                              | One token response maximum; no unbounded retry or duplicate active RP usage.                                                                                                                                                                                             |
| Resource inactive, root token unusable/actor mismatch after consume                       | Code consumed; no committed usage or token response                                                                                                                                                                                                                       | Restart only through a new valid Base authorization; never set consumed code to issued.                                                                                                                                                                                  |
| Invalid DPoP proof before consume                                                         | Current bounded path validates the proof before atomic consume; no successful response and the code should remain issued, but endpoint behavior is unrun. Base OAuth token controllers do not emit a nonce challenge, and absent proof nonce is accepted by the verifier. | Current contract can require fresh authorization after invalid proof; do not claim an AS nonce challenge. If a nonce challenge is later elected, test `use_dpop_nonce` plus `DPoP-Nonce` and make valid fresh-proof retry work without treating the same code as replay. |
| Family link returns missing or invalid_state                                              | Current bounded method rejects every result except explicit `:linked` inside the existing DB transaction; the consumed code remains consumed, but rollback/response behavior is unrun.                                                                                    | Require documented positive-link result before credentials; otherwise deny and require reauthorization.                                                                                                                                                                  |
| Valkey link throws                                                                        | Selected exceptions are logged and re-raised; the public coordinator returns a sanitized server error and the PG transaction does not continue to token success, but cross-store state is unrun.                                                                          | Fail closed for a required link, preserve consumed code, and define explicit repair/re-auth.                                                                                                                                                                             |
| Link call times out after Valkey applied mutation                                         | Valkey result unknown; PG is still in transaction                                                                                                                                                                                                                         | Do not blindly retry a non-idempotent family switch; read/repair in isolated test or fail and require new flow.                                                                                                                                                          |
| Valkey link succeeds, token signing/response construction fails                           | Tombstone may point at RP usage that rolls back with PG                                                                                                                                                                                                                   | Determine actual rollback state; forward repair orphan link/session or require fresh flow; never claim atomic rollback.                                                                                                                                                  |
| PostgreSQL commit fails after Valkey link                                                 | Valkey tombstone can survive while PG session/refresh usage rolls back                                                                                                                                                                                                    | No token response; stale reference must be harmless/cleanable; test subsequent replay/recovery.                                                                                                                                                                          |
| PostgreSQL commits, HTTP response is lost                                                 | Code consumed, RP usage and refresh digest persisted, raw refresh value may not reach caller                                                                                                                                                                              | No code reissue; define safe orphan-session cleanup/re-auth and test old browser state.                                                                                                                                                                                  |
| Same Base session/client concurrent authorization, refresh-family switch, RecordNotUnique | Observe exactly one intended current RP usage/family and bounded retry; no stale-family link                                                                                                                                                                              | Use bounded retry or explicit conflict recovery, never indefinite retry loop.                                                                                                                                                                                            |

### Phase E2 — Base/Auth admission and authority boundary

Status: BLOCKED_BY_DECISION for final local-entry UX; READY_WITH_PRECONDITIONS for admission audit
after E0.

- Objective / requirements: prove Base is the only identity/session authority and every Auth result
  is bound/admitted; REQ-007–010, 032, 065.
- Preconditions: E0 isolated environment. D-ENTRY remains unanswered; no standalone-entry UX is
  implemented or selected.
- Investigation references: adr/base-auth-ceremony-and-seven-rp-boundary.md; Auth app/com/org
  application controllers, selector and leaf routes/controllers, AuthCeremonyAdmission,
  AuthenticationSequenceGate, AuthenticationSessionCommitter, AuthenticationBase;
  BaseAuthAdmissionCoordinator and actual Base authorization/callback/result consumers;
  OidcSsoInitiator. Inspect Jump dependency read-only.
- Expected files: only actual callback/concern/route/result path discovered during trace. Do not
  invent new controller paths or delete Auth state because it lives in Auth.
- Tests first: for each relevant surface and actor type, follow anonymous direct /sign/in and
  /sign/up across Base/Auth until an admitted ceremony or explicit terminal response; it must not
  loop. Also submit without admission and with valid, expired, replayed, wrong-purpose, wrong-actor,
  wrong-realm, wrong-surface and wrong-browser state. Observe response, Auth/Base cookies, ceremony
  records, actor/session/token rows, DBSC key/session binding, Base acceptance, code and RP session.
  Include signup, sign-in, Step-Up, social link, Entra, SecretKey, Emergency, sign-out and actual RP
  path.
- Sequence: trace router → inherited before_action order → credential verification → committer →
  Base result consumer → cookies/JWT/session writes. Add public request tests before guard changes.
  Require Base one-time purpose/actor/realm/browser binding for privileged acceptance. Keep allowed
  Auth ceremony continuity opaque. Remove legacy Auth RP paths only after dependency/tests and Jump
  JWKS/signing needs are proven.
- Required user decision, not chosen here: A) Base-owned local sign-in/signup transaction ending
  only in a Base local session; B) no standalone local sign-in, only RP/approved transaction entry;
  or C) Auth-hosted public UX which first starts a Base-owned local admission. The decision must
  state URL/entry, signup policy, success destination, signed-in behavior, failure/restart,
  Step-Up/link completion and prompt/max_age reauth. No option may synthesize an RP. The currently
  traced unauthenticated Base-root ↔ Auth-selector cycle must be resolved by the selected option,
  not retained as acceptable behavior.
- Non-change: Auth does not become RP or final AAL/session authority; do not remove permitted
  ceremony cookies/models indiscriminately; do not disable CSRF for cross-host return.
- Verification: valid actual RP flow returns to stored exact callback; local flow has no fake
  client, redirect, code, ID Token or RP Session; no-admission paths cannot produce accepted Base
  state.
- Completion: Base validates actor/purpose/realm/browser, expiry and one-time use before accepting
  identity/session; error/restart is explicit.
- Rollback / forward repair: Revert only this phase’s isolated code commit when safe; repair any
  verified unauthorized acceptance forward at Base and preserve existing user state.
- Stop: UX-dependent behavior waits for user choice. A privileged write reachable without Base
  admission is a security failure, not merely an unresolved UX.

### Phase E3 — Authentication event time, OIDC freshness and ORG methods

Status: READY_WITH_PRECONDITIONS for RP-originated OIDC freshness after E0; Base-local/direct-entry
behavior remains BLOCKED_BY_DECISION only for its own slice. Ceremony-backed reauthentication
depends on E2 admission proof. This phase is not authorized to execute in the present planning run.

- Objective / requirements: preserve the Base-accepted authentication event time, meet the OIDC
  request-freshness contract, preserve distinct assurance semantics, and audit ORG entry methods;
  REQ-011–014, 030, 051–056, 082.
- Preconditions: E0 isolated services and attributable tests. For reauthentication after an Auth
  ceremony, E2 must first prove the Base-owned admission/result path. The undecided standalone
  Base-local UX is not a precondition for a valid RP-originated OIDC request.
- Investigation references: app/controllers/concerns/oidc_sso_initiator.rb#oidc_authorization_url;
  app/controllers/base/{app,com,org}/oauth/authorizations_controller.rb#show/#authorize_params;
  app/resolvers/oidc_authorize_request_resolver.rb;
  app/models/concerns/oidc_authorization_transactionable.rb;
  app/services/base_auth_admission_coordinator.rb#register_result_and_issue_resume!;
  app/operations/oidc_authorization_code_issuer.rb#call;
  app/services/valkey/auth_state/authorization_code_store.rb#issue!;
  app/services/oidc_token_exchange_coordinator.rb#wrap_payload/#issue_exchanged_token_result;
  app/services/oidc_id_token_verifier.rb; app/values/security_jwt_oidc_id_token_codec.rb; all actual
  refresh callers and current OIDC/AAL/authority docs.
- Expected files: only the real event/result/transaction owner, claim issuers/verifiers, authorize
  parameters and tests; add schema only if no current semantic event reaches Base.
- Tests first: set one Base-accepted credential event to T0, deliberately issue a code at T1 and
  exchange at T2; decode both tokens and assert the project Access JWT and ID Token `auth_time`
  remain T0 while code `issued_at` and JWT `iat` retain their separate issuance times. Assert a
  missing event cannot be replaced by `Time.current`, code `issued_at`, exchange time, session start
  or AR timestamps. Use time boundaries with controlled clock and no sleeps.
- `prompt`/`max_age` behavior tests: valid same-realm clients on app/com/org; `prompt=login` with an
  active Base session triggers a real reauthentication before code issuance; `prompt=none` when
  logged out or when `max_age` is exceeded returns the applicable OIDC error without rendering or
  redirecting to an interactive screen; `max_age` comfortably fresh, just over and at its boundary,
  plus zero; unsupported/malformed/conflicting parameter combinations fail as OIDC requests, not by
  silently dropping a parameter. Assert accepted parameters survive controller allowlist,
  transaction persistence and result resume without cross-transaction bleed, Base freshness
  decision, ID Token `auth_time`, and RP verifier rejection of missing/stale claims.
- Operation-to-time contract to verify:

| Operation                                     | Correct time behavior                                                                                                                                      | Current source evidence / remaining test                                                                                                                                         |
| --------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Initial credential sign-in                    | Base records/accepts the real authentication-event instant T0; a later authorization/code issue must retain T0.                                            | OIDC transaction writes `authenticated_at: now` on Base result registration, but exact event semantics and ordinary Base root-session/JWT propagation are unproved.              |
| Existing-session SSO / repeated authorization | Reuse the original accepted authentication time; do not refresh it merely by issuing a new code.                                                           | Current code path issues code for an already logged-in Base resource; no semantic event source found in the inspected root token/session path.                                   |
| Reauthentication                              | A genuine credential reauthentication may establish Tnew after Base accepts that event.                                                                    | The transaction records result-registration time; test this corresponds to the accepted credential event and propagates to the next tokens.                                      |
| Step-Up                                       | Update auth_time only when the accepted policy treats the verified step-up as a new authentication event; assurance result and event time remain separate. | Step-up maps to a purpose-specific handoff/result; not yet proven against issued claims.                                                                                         |
| Social identity link/unlink                   | The link mutation itself does not make authentication newer. A separate Step-Up event may update time only if its policy says it is a new event.           | Accepted Step-Up ADR/test decision exists; token-time propagation through this path is unverified.                                                                               |
| OIDC authorization/code exchange              | Keep authentication time T0, code `issued_at` T1, Access/ID `iat` at their own issuance times.                                                             | Current source instead uses code `issued_at` (and then exchange-time fallback) for Access/ID `auth_time`.                                                                        |
| Refresh                                       | If the public OIDC refresh contract exists, preserve original auth_time and advance only new token `iat`; refresh is not authentication.                   | Same-endpoint OIDC refresh grant is not accepted by the current coordinator; standalone `OidcRefreshTokenIssuer` has no production caller found. Contract must be decided first. |
| AR persistence timestamps                     | `created_at`/`updated_at` remain persistence metadata and are never substituted for authentication time.                                                   | No fallback/backfill based on those fields is allowed.                                                                                                                           |

- Sequence: find the true credential-verification event and its trusted Base acceptance point; bind
  it to a one-time purpose/actor/realm/browser result; propagate only that accepted instant through
  transaction, code and tokens; preserve prompt/max_age parameters; apply freshness at Base;
  validate final ID Token at RP. If event provenance is missing for a session, force real
  reauthentication or fail the OIDC request. Do not backfill from AR timestamps. Trace any actual
  OIDC refresh consumer before designing grant support. Audit actual acr/amr and ORG.
- OIDC parameter/decision boundary matrix:

| Path                     | Required observation                                                                                                                                                                                                                                                                                            |
| ------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| RP request construction  | Current shared `oidc_authorization_url` builds fixed query keys and cannot emit these optional requests. Establish which RP product paths need `prompt` or `max_age`; preserve exact state/client/callback binding.                                                                                             |
| Base app/com/org parsing | All three inspected fixed allowlists omit `prompt` and `max_age`. Static source confirmation; request behavior pending.                                                                                                                                                                                         |
| Resolver and transaction | Resolver does not validate either; transaction `authorize_params` omits both on serialization/resume. Test valid/invalid values and exact transaction ownership.                                                                                                                                                |
| Base freshness decision  | Current already-authenticated shortcut issues code after filtering. Must attempt fresh authentication for `prompt=login` or stale `max_age`; `prompt=none` must not interact and must return a valid OIDC error when silent authentication cannot complete.                                                     |
| ID Token / RP validation | If `max_age` is used, emit the Base-accepted event instant as ID Token `auth_time`; verify missing/stale claims at RP. Access JWT follows the separate project claim contract.                                                                                                                                  |
| OIDC refresh             | No production consumer/endpoint contract identified. First verify whether issued refresh tokens are meant to use the same token endpoint. If supported, test rotation, client binding, original `auth_time` and advanced `iat`; otherwise do not invent a removal until the owning response contract is agreed. |

OIDC Core §2 defines `auth_time` as when end-user authentication occurred. §3.1.2.1 requires active
reauthentication when `max_age` is exceeded, inclusion of `auth_time` when max_age is used, and says
max_age=0 is equivalent to `prompt=login`. §3.1.2.3 defines `prompt=login` and `prompt=none`; §15.1
requires OP support for `prompt`, `max_age` and requested `auth_time`. §12.2 says that if a refresh
response contains an ID Token with `auth_time`, it is the original authentication time even though
the new token's `iat` is current. These apply respectively to RP request creation, all three Base
authorization endpoints, transaction storage/resume, the Base freshness decision, token claims and
RP validation. See
[OpenID Connect Core 1.0 incorporating errata set 2](https://openid.net/specs/openid-connect-core-1_0.html).
The repository gaps are statically confirmed on inspected source paths; endpoint errors,
bypassability, and consumer use are not dynamically established.

- ORG criteria: Entra stays single-tenant and pre-provisioned/no-JIT; normal SecretKey starts
  independently and is Operator-bound; Emergency remains restricted and cannot switch mode or gain
  normal write authority; signup follows verified policy.
- Non-change: Auth cannot decide final AAL/acr; no SMS/AAL2 inference; keep AAL/FAL and product
  terminology distinct.
- Docs: update affected OIDC/authority/AAL source in this step if made false; add bounded AAL/FAL
  follow-up, not an unbounded redesign.
- Verification after E0 isolation:
  `bin/rails test test/controllers/base/oauth_authorization_surfaces_test.rb test/controllers/base/com/oauth/authorizations_controller_test.rb test/controllers/base/org/oauth/authorizations_controller_test.rb test/controllers/base/oauth_oidc_authority_test.rb test/services/oidc/authorize_service_test.rb test/services/oidc/id_token_verifier_test.rb test/services/oidc/token_exchange_service_test.rb test/integration/oidc_rp_browser_flow_test.rb`,
  followed by the relevant full suite and canonical CI. These are current test entrypoints found
  during static inspection, not a claim that they already cover the requested cases.
- Completion: both tokens reflect accepted event; freshness behavior matches protocol; no time
  fabrication; Base owns final assurance.
- Rollback / forward repair: Revert only code-only claim/parameter changes before dependent work; if
  an event instant is unknown, require reauthentication rather than rewriting history.
- Stop: missing historical event requires guessed backfill or unapproved policy/schema decision.

RFC 6749 §6 governs a client presenting a refresh token to the authorization server token endpoint.
Apply it only if the repository's owning client/API contract confirms that the returned OIDC
`refresh_token` is intended for this endpoint; the legacy Base cookie refresh and the unit-tested
operation do not prove that public grant. See
[RFC 6749](https://www.rfc-editor.org/rfc/rfc6749.html).

Normative source:
[OpenID Connect Core 1.0 incorporating errata set 2](https://openid.net/specs/openid-connect-core-1_0.html),
§§2, 3.1.2.1, 15.1. These apply to RP request construction, Base parsing and transaction
persistence/resume, freshness decision and RP ID Token verification, not merely token issuance.

### Phase E4 — Shared RP contract and seven-client isolation

Status: READY_WITH_PRECONDITIONS after E0; changes depending on E1–E3 findings.

- Objective / requirements: Core, Side and Edit share protocol mechanics while each RP supplies its
  own client policy; preserve seven-client configuration, session ownership and revocation;
  REQ-028–032, 057–063, 065.
- Preconditions: isolated real Base, Valkey and PostgreSQL; test matrix for core-app, core-com,
  core-org, side-app, side-com, side-org and edit-org; E1 ownership and E2 Base admission contracts
  established.
- Evidence: route/controller inheritance, RP initiator/callback/token clients, state/nonce/PKCE
  stores, JWT verifiers, session establishment/logout, client registry, refresh families, Base
  issuer, accepted Base/Auth ADR.
- Candidate files/components (confirm by actual call graph):
  app/operations/oidc_authorization_code_issuer.rb, app/services/oidc_token_exchange_coordinator.rb,
  app/services/oidc_authorization_transaction_coordinator.rb,
  app/services/valkey/auth_state/authorization_code_store.rb, the discovered common RP
  initiator/callback/verifier and registry paths, their existing tests, and the accepted
  RP/authority ADR. Do not invent a shared object path before extraction is justified.
- Tests first: same public contract for each RP: authorization initiation, exact redirect,
  state/nonce/PKCE, callback/code exchange, issuer/audience/type/temporal checks, session rotation,
  authenticated request and logout. Mutate one client's redirect/client/key/session namespace and
  assert isolation. Include callback failures, recovery, replay and malformed response.
- Sequence: define common contract from verified identical semantics; extract only common mechanics;
  inject per-RP registration/presentation policy at boundary; migrate Core and Side; integrate Edit;
  remove duplicate mechanics only after coverage.
- Non-change: no global Edit singleton behavior, no weaker state/signature/claim checks, no open
  redirect, no Auth RP, no online Access JWT revocation lookup.
- Verification: public route/request contract and cross-client isolation for all seven IDs; focused
  shared RP, OIDC and static security checks.
- Completion: one authoritative implementation per shared invariant, configuration differentiates
  clients, Core/Side remain instance-capable, Edit uses its registered boundary.
- Rollback / forward repair: Retain the prior RP path until parity; revert only the isolated
  refactor commit if no dependent caller has moved, otherwise repair callers and contracts forward.
- Stop/recovery: retain existing behavior until parity is proven; record a plan deviation at first
  client-specific mismatch.

### Phase E5 — DPoP and DBSC

Status: READY_WITH_PRECONDITIONS for protocol automation; DEFERRED_VALIDATION for representative
native/browser interoperability.

- Objective / requirements: enforce configured sender-constraint policy, complete supported protocol
  behavior, preserve DBSC-free fallback; REQ-016–019, 020.
- Preconditions: isolated AS/RS tests; E1 irreversible code-consumption semantics known; E4 client
  type and key owner known.
- Evidence: DPoP proof/JWK/thumbprint/ath/htm/htu/iat/jti/replay/nonce code, metadata, token
  endpoint and Resource Server middleware, Bearer policy and native/BFF key storage; DBSC runtime
  wiring and fallback.
- Candidate files/components: app/lib/dpop_proof_verifier.rb, app/services/dpop_request_verifier.rb,
  app/services/dpop_nonce_service.rb, app/services/dpop_jti_replay_guard.rb, actual AS/RS
  controllers and metadata, app/services/dbsc_registration_service.rb,
  app/services/dbsc_verification_service.rb, app/lib/dbsc_proof_verifier.rb, relevant tests,
  docs/architecture/dpop.md and docs/architecture/dbsc.md. Verify runtime callers before editing.
- Tests first: malformed/unsupported algorithm/private JWK, thumbprint/cnf mismatch, wrong
  htm/htu/ath, stale/future iat, duplicate jti, wrong key, token replay without key, Bearer policy;
  AS no-nonce behavior versus an explicitly required `use_dpop_nonce` challenge; RS response/header
  and follow-up omission/supplied/wrong nonce; cross-role nonce rejection only where architecture
  identifies distinct servers; DBSC unsupported browser, registration, proof failure/replay,
  restart/expiry/revoke/logout/fallback.
- Sequence: determine client policy/key owner; native Palm is a strong DPoP candidate, while a
  confidential BFF may own keys/tokens server-side. For UMAXICA-controlled compatible clients, plan
  removal of optional Bearer fallback and require sender-constrained tokens, with a documented
  transition for clients not yet validated. Do not force one policy across all clients without
  architecture evidence. Server nonce use is optional. Static inspection currently finds no nonce
  challenge on the AS token endpoint, while a separate Resource Server authentication failure can
  emit a nonce header; the verifier accepts nonce-less proofs and consumes a nonce only when
  present. Nonce persistence is keyed by actor type without an issuer/endpoint field, so verify
  whether distinct server roles share that store before treating it as server-scoped. Test these
  paths separately against RFC 9449 §§4.2, 4.3, 5, 8 and 9; if a nonce is actually issued as a
  challenge, require the nonce claim and prove the valid retry. Determine whether post-consume proof
  validation is acceptable for the current no-challenge AS contract; retain DBSC as progressive
  enhancement.
- Non-change: no browser-JS DPoP key assumption without evidence, no claim that nonce absence is a
  defect, no immediate Access JWT revocation, no physical-device validation claim.
- Verification: automated AS/RS contracts and replay; representative native key storage/browser
  lifecycle is a separate gate.
- Completion: per-client policy explicit; invalid proof denied; nonce retry contract tested where
  applicable; DBSC failures do not lock out unsupported clients; device gaps marked pending.
- Rollback / forward repair: Roll back only an unshipped policy/code change when safe; after state
  transition require fresh proof/authorization and never revive consumed codes.
- Stop/recovery: if consumed-code behavior prevents a required retry, use safe fresh authorization
  or redesign ordering without making a consumed code reusable; defer deployment until real
  device/browser tests. Normative source: [RFC 9449](https://www.rfc-editor.org/rfc/rfc9449.html),
  §§5, 8, applied to actual AS and RS proof handlers. §8 nonce use is optional.

### Phase E6 — Independent UI previews

Status: **ALREADY_SATISFIED for inert Create UI; BLOCKED_BY_DECISION for the exact Up-link href**.
Rails props/request checks are also BLOCKED_BY_ENVIRONMENT until E0 proves isolation.

- Objective / requirements: verify inert Create actions and the Avatar Up link; REQ-085–086,
  REQ-020.
- Preconditions: preserve the current uncommitted Auth changes and all user-owned files. Resolve
  C-17's literal `/dashboard` versus Root-as-home conflict before changing the Up-link destination;
  do not reinstate the retired route by assumption.
- Evidence: current HEAD already passes server-provided actions and `dashboard_up_link` through
  Accounts/Organizations/Avatars and shared `EntityList`; Avatar controller tests expect
  `base_app_root_path(ri: "jp")`; the React test checks disabled button semantics/no href and
  unchanged list/empty state. React test file passed in this run. Accepted ADR retires `/dashboard`;
  older prompt names that literal href.
- Expected files if a specific regression is found: existing Base app controllers,
  `src/features/self_service/EntityList.tsx`, Page/Button and their existing tests. No change
  expected now.
- Tests first: retain the existing React assertions; after E0 run the three Rails controller tests
  to confirm exact props and region retention. Once C-17 is decided, assert the chosen href exactly.
  Inspect route output before any claim that Avatar's older create endpoints are absent; the request
  explicitly preserves that existing implementation.
- Sequence: none unless a focused assertion fails; if it does, establish the failing public behavior
  and make only the preview correction.
- Non-change: no create route/API/write, POST, fetch, policy, service, provisioning, change to
  Avatar's existing create flow, or React resource-name inference.
- Verification: `bun --bun vitest run spec/features/self_service/self_service_pages.test.tsx`
  (passed 20 tests); Rails controller tests are not run; typecheck/lint already passed in the
  broader safe checks below.
- Completion: UI remains server-configured and inert; Up link preserves `ri` and targets the
  destination selected under C-17.
- Rollback / forward repair: no change to roll back; if future corrective UI change fails, revert
  only that isolated UI change and preserve the older Avatar CRUD.
- Stop/recovery: do not change the href while C-17 is undecided; the Create UI remains complete and
  independent.

### Phase E7a — Existing-account social identity linking

Status: **ALREADY_SATISFIED for the accepted decision and recorded tests**; runtime and
direct-callback negative assurance remain unverified until E0.

- Objective / requirements: preserve Step-Up for existing-account Google/Apple linking, distinguish
  initial enrollment and retain unlink/no-lockout protection; REQ-070–072, REQ-020.
- Preconditions: E0 isolated Rails services and E2 Base/Auth trust path; retain accepted
  `adr/social-identity-linking-requires-step-up.md`.
- Evidence: the current ADR is Accepted and limits itself to app post-enrollment linking. Current
  integration tests cover both providers' link denial without `social_link`, wrong Step-Up scope,
  unlink denial and last-method protection; signup and link are separate.
- Expected files if evidence disproves current behavior: existing social auth concerns/controllers
  and their integration tests only. Do not make a duplicate ADR or change the fresh Step-Up policy
  by default.
- Tests first: run existing Google/Apple public tests, then add only a missing direct-callback case
  where a plausible callback reaches a grant/state but has missing, wrong-owner, stale or
  wrong-scope Step-Up. Assert no identity mutation. Retain valid Step-Up success and signup
  enrollment success.
- Sequence: no production change unless a bypass is reproduced; if reproduced, bind callback intent
  to Base-accepted fresh Step-Up and test owner/provider/state.
- Non-change: no auto-reuse of fresh primary sign-in, no AAL model change, no Auth authority and no
  provider flow redesign.
- Verification: focused social integration suite after E0; no such Rails run occurred in this
  planning run.
- Completion: both providers' initiation and callback require the same fresh scope-bound approval;
  unlink and last-method protection remain; signup is unaffected.
- Rollback / forward repair: no production change expected; if a fix is needed, prefer a narrow
  callback enforcement correction and preserve the ADR.
- Stop/recovery: if only a new policy can close the observed path, report PLAN_DEVIATION for user
  decision rather than changing the accepted STAY decision.

### Phase E7b — Normal sign-out cookie cleanup

Status: READY_WITH_PRECONDITIONS after E0; the defect is not yet reproduced.

- Objective / requirements: prove normal completion deletes `auth_access` and `auth_refresh` at the
  issuance scope and permits immediate new sign-in; REQ-073–074, REQ-020.
- Preconditions: isolated browser cookie jar plus isolated Rails/Valkey. No live token, service or
  production cookie.
- Evidence: trace cookie issue helpers and scope, sign-out state machine, revoke, completion
  redirect, app/com/org reuse and abnormal detach separately.
- Tests first: seed the issued cookies with the exact current Domain/Path/secure attributes;
  complete the ordinary sign-out flow; inspect both Set-Cookie expirations and the jar at Lobby;
  then immediately start sign-in and verify stale auth is not accepted. Cover app/com/org and
  malformed/partial sign-out separately.
- Sequence: reproduce first; if valid logout already clears cookies, report no production fix. If
  scope mismatch is observed, correct one shared low-level detach helper, not one surface at a time.
- Non-change: preserve state machine, revoke semantics, CSRF, cookie security attributes, Lobby and
  no GET mutation.
- Verification: focused Rails/browser-cookie test, sign-in and token/cookie suites after E0; no test
  was run here.
- Completion: normal logout browser jar has neither credential; server revoke completes; new sign-in
  starts immediately; app/com/org behavior remains consistent.
- Rollback / forward repair: correct the deletion scope forward and retain evidence; do not
  substitute natural JWT expiry or anomaly fallback for cleanup.
- Stop/recovery: if browser cookie semantics cannot be tested, mark the browser-level completion
  pending; do not infer from response text alone.

### Phase E7c — Email OTP, Turnstile, recovery query and OTP mail

Status: READY_WITH_PRECONDITIONS after E0; current worktree changes are user-owned and not validated
by Rails.

- Objective / requirements: preserve signup email on allowed 422, verify Turnstile before OTP
  validation on signup and sign-in, clear failed OTP/challenge state, bound recovery identity
  queries and localize OTP subjects; REQ-087–094, REQ-020.
- Preconditions: isolated Rails test DB/Valkey and provider stubs. Compare against the starting
  dirty diff before any authorized later edit; do not overwrite it.
- Evidence: app/com entry and OTP controllers with inherited callbacks, Turnstile concern/page
  props, current `OtpVerificationForm` worktree diff, Inertia sign-in form state,
  `RecoveryPasscodeTopUp`, Visitor/Client associations, shared mailers/locales.
- Existing state: email preservation is in HEAD with Rails assertions and React default value. The
  worktree diff already adds app/com sign-in OTP checks and app/com signup OTP checks before code
  verification; it adds visible Turnstile props/rendering and Rails negative tests. Treat this as
  proposed in-progress implementation, not validated behavior. The current sign-in React component
  clears code/token in `onFinish`; its test simulates that callback, but an actual 422 round-trip
  and widget re-challenge remain to verify. The two signup controller tests initially broadly
  stubbed `FeatureFlags.enabled?` to true around an upstream-unavailable case expected to return
  422; that contradiction was corrected in the current worktree by removing the broad stub, so the
  documented default-off degradation policy now remains in force for the test. The separate
  degraded-on policy case is still untested. Do not change accepted outage behavior by assumption or
  duplicate code/tests blindly.
- Tests first: inspect existing local tests; run focused app/com controllers and React component
  tests in isolated environment. Assert missing/invalid and degraded-off upstream outage prevent OTP
  verification, attempt count and auth/session/flow transitions unchanged; separately test the
  documented degraded-on outage path and keep missing/invalid challenges rejected. Assert dummy/real
  outward behavior parity. Assert failed/resend OTP empty in actual rerender and fresh challenge, no
  code in props/session/flash/HTML. Test exact email restore only on POST error, fresh GET empty.
  Test email-only, telephone-only and absent recovery identities through multi-credential top-up
  with query-count proof. Test all four normal signup/signin paths without Jump/network; mail
  subject locale by purpose without body changes.
- Sequence: review user diff → prove red/current test → run existing changed Rails tests → fix only
  demonstrated issue → test query counts → verify mail contract. Use provider stubs and never store
  OTP/challenge token.
- Non-change: no Jump code/registry/JWKS edits, no Turnstile bypass, no OTP persisted after failed
  submission, no enumeration weakening, no validation skip, no secret logging, no changes to mail
  body/protocol beyond required subject.
- Verification: React/Vitest safe checks passed; targeted and full
  Rails/controller/Turnstile/recovery/mail tests not run because E0 isolation is unproved. Static
  review predicts the dirty signup outage test conflicts with the documented degraded-mode branch;
  no runtime failure is claimed.
- Completion: app/com signup/signin reach expected next Rails state; failed challenge consumes no
  OTP attempt/state; OTP/challenge reset; four flows retain enumeration behavior; no recovery query
  multiplicity; subject purpose/locale correct.
- Rollback / forward repair: use a narrow forward correction; never restore consumed OTP or
  Turnstile state.
- Stop/recovery: stop local phase if correct verification order changes enumeration or
  step-up/Auth/Base ownership; report the conflict instead of loosening a guard.

### Phase E8 — Public routes, root behavior, GUID and OpenAPI

Status: READY_WITH_PRECONDITIONS for static and read-only runtime route inventory; route
changes/request contracts require E0; GUID resolver implementation requires an explicit owner
decision.

- Objective / requirements: normalize safe application API routes, preserve protocol paths,
  establish evidence-based root behavior, cover application-owned JSON APIs; REQ-021–044, 020.
- Preconditions: inspect every config/routes file and ingress/client references; safe Rails boot for
  route/notes/request tests; D-GUID must settle data ownership and net OpenAPI participation before
  adding resolver storage or a contract.
- Evidence: all service routes/controllers/callers, OpenAPI source/bundles and route-coverage test,
  Redocly config, API vocabulary ADR, documented path overrides, current Base/Auth root ADR, 14
  candidate authenticated roots, GUID route/controller and persistence ownership.
- Candidate files/components: config/routes/_.rb, controller paths resolved by runtime route
  inventory, app/controllers/guid/net/api/v0/resources_controller.rb,
  test/contracts/openapi_route_coverage_test.rb, openapi sources under openapi/,
  public/openapi._.yml generated only from source, redocly.yaml,
  adr/api-route-vocabulary-consolidation.md and current root/authority docs. No GUID model/migration
  path is selected until ownership is decided.
- Tests first: classify every web/edge API as active, planned, dead or blocked; request contracts
  for success, invalid, auth, CSRF, Bearer, content type, Problem Details and cache; route-coverage
  test for all services/surfaces; GUID exact match, host isolation, 404 vs 5xx and no redirect;
  roots anonymous/authenticated × ri/open redirect and machine/native requests.
- Sequence: retain .well-known, CSP report and standard protocol paths; simplify Core resource
  routes/controller namespaces only if public URL remains evidenced; migrate only valuable app APIs
  with caller/OpenAPI updates; delete only proven-dead surfaces; regenerate source-derived OpenAPI
  bundles; verify root reachability/inheritance; create GUID record/schema/API only after owner and
  net-surface decision. Any deferred valuable endpoint gets a specific actionable FIXME confirmed by
  Rails notes.
- Root inventory to verify rather than assume: Auth/Base/Core/Side app-com-org, Palm app, Edit org.
  Preserve accepted Base/Auth root behavior; do not restore retired Auth dashboard/lobby. No
  invented Core/Palm dashboard or JSON redirect.
- Non-change: no catch-all GUID route, unsafe redirect, justified path override deletion, broad
  protocol exemptions, guessed client migration or persistence owner.
- Verification: static and runtime route inventory (`bin/rails routes` and `bin/rails notes` now
  boot safely with temporary filesystem overlays); request/Committee/coverage contracts remain
  behind E0; `bun run openapi:lint`, bundle/idempotence/verify after source changes.
- Completion: no duplicate aliases; each legacy route has evidence; JSON paths documented or
  narrowly exempted; generated OpenAPI matches source; root matrix reflects reachable behavior.
- Rollback / forward repair: Regenerate bundles from sources; if a proven route contract breaks,
  restore the phase route/caller/schema set together and preserve uncertain valuable endpoints.
- Stop/recovery: keep uncertain endpoint functioning and annotate precise dependency; do not treat
  indefinite FIXME as OpenAPI completion.

### Phase E9 — Session/activity presentation, temporal semantics and bounded cleanup

Status: **ALREADY_SATISFIED for the inspected presentation/absolute-expiry contract;
READY_WITH_PRECONDITIONS for DB-backed runtime validation and any broader private-test cleanup**.
Schema changes still need event/expiry semantics and migration evidence.

- Objective / requirements: separate persistence metadata from domain time, make activity/session
  views user-safe, enforce owner-only session management and absolute expiry, apply preference time
  formatting, then reduce direct private-method tests without coverage loss; REQ-045–050,
  075–084, 020.
- Preconditions: E0 comparable green Rails baseline; inspect schema/history and
  Client/Visitor/Operator plus app/com/org and DBSC paths; establish discarded_at semantics before
  relying on it.
- Evidence: timestamp aliases/call sites and current architecture harness;
  Chronicle/Occurrence/ClientChronicle/presenter; risk and visibility IDs; Identity sessions
  routes/controllers/presenters; SessionAbsoluteExpiryValue, discarded_at, token issuance/refresh
  and DBSC; SessionTimestampHelper/preferences; private-test inventory.
- Candidate files/components: app/presenters/base/identity/activity_log_presenter.rb,
  app/presenters/base/identity/session_presenter.rb, app/helpers/session_timestamp_helper.rb,
  app/values/session_absolute_expiry_value.rb,
  app/controllers/base/{app,com,org}/identity/sessions_controller.rb, matching Inertia/React pages,
  token/refresh issuance and DBSC paths found by call graph, schema/migrations only if semantics
  prove a gap, and the existing architecture/coverage harnesses.
- Tests first: owner/surface isolation, current vs other session, CSRF and GET nonmutation, no
  internal IDs/token family/raw context/private IP in DOM/props; rank-based risk ordering; SQL
  visibility filtering; timezone × date × clock boundaries including midnight/noon and date
  crossing; expiry fixed at session establishment across refresh/access/DBSC, expired cannot revive,
  revoke may happen earlier; current-session status computed server-side. For every direct-private
  test, identify production callers and replace it through a public request/lifecycle contract
  before changing visibility or deleting dead code.
- Sequence: migrate user resource to /sessions while preserving /sign/out and Core /api/v0/session;
  reuse existing presenter/query/formatter; enforce absolute cap only in common issuance; add
  semantic time only when current event provenance cannot satisfy invariant; add Org emergency
  display only with reliable explicit source; do broad visibility cleanup in small batches after
  green baseline.
- Non-change: no per-request RP session DB lookup, no refresh-expiry-as-session-expiry, no
  DBSC-to-Emergency inference, no fabricated timestamps, no coverage exclusions or weakened
  assertions.
- Verification: focused request/presenter/token lifecycle tests; bounded query count and
  owner-scoped destroy; preference cross-product; complete Rails suite plus explicit coverage and
  architecture/lint/security checks.
- Completion: all actor paths respect one absolute ceiling; only owner can terminate child session;
  internal data absent; timestamp sorting uses instants; final coverage satisfies configured floors
  and comparable green baseline.
- Rollback / forward repair: Revert code-only presentation changes only at the phase boundary;
  schema changes need an approved reversible migration or forward repair, never revive expired
  credentials or fabricate event times.
- Stop/recovery: if discarded_at meaning differs for any token/actor path, do not alias or add a
  duplicate column without owner and migration evidence; omit uncertain emergency labels. Defer wide
  private-method cleanup if baseline is red.

### Phase E10 — Final independent behavioral audit and release gate

Status: DEFERRED until E0–E9 are complete; never treat a plan-conformance review as this audit.

- Objective / requirements: establish the implemented behavior from the finished system and compare
  it to security, contracts and every source requirement; REQ-003, 019–020, 069, 095.
- Preconditions: all accepted implementation phases complete; attributable green Rails and JS
  suites; no unresolved source or architecture decision affecting the claimed scope.
- Evidence: final working tree, routes, middleware/controller callback order, persistence
  transitions, signed token claims, response headers and browser-visible output.
- Audit order: start from public behavior and attack conditions, without reading expected-step
  checkboxes first. Independently infer the actual state/authority/contract from request flows and
  stored state; challenge it with negative, concurrency, cross-owner and partial-failure cases;
  inspect diff and tests after behavior is understood; then compare to source REQ ledger and current
  ADRs.
- Candidate files/components: the complete final diff, accepted ADRs and affected docs, public
  request/integration tests, source and generated OpenAPI, and evidence summaries. Do not edit the
  plan to make an implementation appear conformant; report deviations.
- Tests first: audit tests must verify externally visible denial/success, owner and realm isolation,
  no stale credentials, no secret leakage, cross-client isolation, absolute expiry, error/recovery,
  and no regression to app/com/org, Core/Side/Edit or Palm boundaries.
- Verification: repeat relevant focused suites, complete isolated Rails suite and canonical CI,
  frontend full suite/coverage, static/security checks, generated OpenAPI verification and
  routes/notes. Physical DPoP/DBSC checks remain unrun until actual representative devices are
  available.
- Completion: every source requirement has a disposition and evidence; no new failures or weakened
  gate; each accepted risk and validation debt is explicit; final production claims only match
  observed evidence.
- Rollback / forward repair: Block release, correct forward or revert only the isolated
  implementation commit where safe, then repeat the independent audit.
- Stop/recovery: any mismatch against an architectural invariant, identity owner, external contract
  or security semantics is a PLAN_DEVIATION and returns to adjudication; do not waive it in the
  final audit.

### Phase dependency graph and blocked scope

```text
E0 (sources, safe targets, baseline)
├── E1 (code replay and cross-store failures)
├── E2 (Auth/Base admission; local-entry UX decision gates only that UX)
├── E3 (event time and OIDC freshness; local reauth slice also depends on E2)
├── E4 (shared RPs)  ← E1 + E2 + E3
│   └── E5 (DPoP/DBSC)  ← E1 code-consumption result
├── E6 (inert Create UI satisfied; Rails props require E0; exact link href requires D-DASHBOARD)
├── E7a (existing social Step-Up decision; callback verification depends on E2)
├── E7b (normal sign-out browser cleanup; isolated Rails/browser target)
├── E7c (email OTP, recovery, mail; sign-in completion also uses E2/E3)
├── E8 static inventory (independent); route tests require E0; GUID persistence requires D-GUID
└── E9 (green baseline; expiry tests also use E3/E4)

E1–E6, E7a–E7c, E8–E9 accepted scope ──> E10 reverse-direction final audit
```

Explicit prerequisite edges for mechanical audit: E0→E1,E2,E3,E4,E5,E6,Rails parts of E7a/E7b/E7c,E8
runtime,E9; E1+E2+E3→E4; E1+E4→E5; E2→E7a callback verification; E2+E3→E7c sign-in completion;
E3+E4→E9 expiry; E1–E6 + E7a–E7c + E8–E9→E10. E8 static inventory and E6 React checks are
independent of E0. The edges form a DAG. D-ENTRY blocks only local-entry completion and
reauthentication paths that need that UX; D-DASHBOARD blocks only E6's exact link destination;
D-GUID blocks only GUID persistence and the public net contract; E0 service isolation blocks Rails
mutations and runtime checks, not static review or isolated frontend tests. The full execution plan
remains NO_GO until required source/decision/environment gates are resolved.

### Decisions and source needed before dependent implementation

- D-ENTRY: choose the product entry and completion behavior for Base-local/direct sign-in among
  Base-owned local admission, no standalone entry, or an Auth-hosted UX that first obtains Base
  admission. Define signup, success destination, failure/restart, signed-in root, Step-Up/link and
  max_age/prompt behavior. No choice is made here.
- D-DASHBOARD: resolve the conflict between the earlier required `/dashboard?ri=jp` Up link and the
  accepted ADR retiring Base `/dashboard` in favor of authenticated Base Root. Choose semantic
  Root-as-Dashboard or reopen the route ADR/contract; this decision gates only the link destination,
  not the already-inert Create UI.
- D-GUID: identify the authoritative persistence owner and durable uniqueness/lifecycle contract,
  and decide whether the public net service receives a per-surface OpenAPI document. Preserve the
  current host/path pending that decision.
- D-OIDC-REFRESH: trace all seven registered RP client paths, documentation and any supplied client
  contract for use of the `refresh_token` returned by code exchange. Then decide whether the Base
  token endpoint supports OAuth refresh-token grants and must wire the current rotation operation
  with claim reissuance, or whether the response contract must omit the unsupported value, or
  whether another explicitly owned endpoint is intended. Do not change either side on class-name or
  unit-test evidence alone. This gates only OIDC refresh contract changes; normal T0/T1/T2 and
  prompt/max_age work continues independently.
- S1/S2 recovery: provide the source plan/review bytes matching the supplied SHA digests, or
  explicitly accept that the later scope is narrowed to the pasted V2 and the provisional summaries.
  Until then, exact wording/strength and REQ-095 remain unresolved.
- D-DPoP per client: code investigation must first establish each key holder and present Bearer/DPoP
  contract. Ask only if a client contract or rollout policy cannot be established from registered
  clients/docs/tests; do not infer that absence of hardware authorizes a Bearer fallback
  indefinitely.
- D-LINK recovery: verify the store's actual return enum and timeout semantics. If required family
  linkage cannot be proven successful, the plan's fail-closed default is to issue no tokens and
  require a fresh authorized flow. Any proposal to issue despite missing linkage is a separate risk
  decision, not implied by this plan.

## 12. Verification strategy and current-run evidence

The following results are from this planning run's local, non-Rails commands, run against the
pre-existing dirty worktree recorded in §2. They are observational checks, not attributable to a
clean checkout and not evidence of Rails controller, database, Valkey, external-provider,
physical-device or complete implementation behavior.

| Command / condition                                                                                                        | Result                                                                                                                                           | What it proves / does not prove                                                                                                                                                                                                                                                                                                        |
| -------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| bun --bun vitest run spec/features/auth/signin/signin_interaction.test.tsx                                                 | exit 0; 1 file, 34 tests passed                                                                                                                  | Existing isolated React behavior only.                                                                                                                                                                                                                                                                                                 |
| bun --bun vitest run spec/features/auth/auth_com_signup_screens.test.tsx spec/features/auth/signin/signin_screens.test.tsx | exit 0; 2 files, 34 tests passed                                                                                                                 | Existing component behavior; no Rails server integration.                                                                                                                                                                                                                                                                              |
| bun --bun vitest run spec/features/self_service/self_service_pages.test.tsx                                                | exit 0; 1 file, 20 tests passed                                                                                                                  | Existing self-service rendering only.                                                                                                                                                                                                                                                                                                  |
| bun run test                                                                                                               | exit 0; 85 files, 1,054 tests passed                                                                                                             | Ordinary Vitest suite; not a coverage run.                                                                                                                                                                                                                                                                                             |
| bun run format:check; bun run lint; bun run typecheck:verify; bun run typecheck; bun run deadcode; bun run openapi:lint    | each exit 0; deadcode reported two hints                                                                                                         | Current frontend/repo checks passed as invoked; not an OpenAPI route coverage or runtime check.                                                                                                                                                                                                                                        |
| bin/rubocop                                                                                                                | exit 0; 4,790 files                                                                                                                              | Static lint passed for current tree.                                                                                                                                                                                                                                                                                                   |
| bundle exec erb_lint --lint-all                                                                                            | exit 0; 599 files                                                                                                                                | ERB lint passed; emitted a Ruby 3.3 parser warning under Ruby 4 runtime.                                                                                                                                                                                                                                                               |
| bundle exec brakeman --quiet --no-pager --exit-on-warn --exit-on-error                                                     | exit 0; 0 warnings                                                                                                                               | This Brakeman invocation reported no warnings; not proof of exploit resistance.                                                                                                                                                                                                                                                        |
| ruby -c on six currently modified auth controllers                                                                         | exit 0                                                                                                                                           | Syntax only.                                                                                                                                                                                                                                                                                                                           |
| Read-only Python trace audit of refactor.md REQ rows and phase references                                                  | exit 0; 95 rows / 95 unique IDs; no missing, duplicate or out-of-range IDs; six cells per row; all phase refs defined                            | Internal completeness of the provisional ledger only; does not recreate missing source requirements.                                                                                                                                                                                                                                   |
| Read-only Python topological check of the explicitly listed §11 phase dependency edges                                     | exit 0; 13 nodes / 32 edges; cycle: no                                                                                                           | Checks the written phase graph only; decision and environment gates remain separate.                                                                                                                                                                                                                                                   |
| git status --short; git rev-parse HEAD; git diff --stat review-SHA..HEAD; focused review of the 21-path delta              | exit 0; HEAD 430ac354...; review delta +307/-6 in 21 committed files; original 12 modified tracked paths and four untracked paths remain present | Confirms current versus review snapshot and protects scope; does not validate behavior.                                                                                                                                                                                                                                                |
| bun --bun vitest run --coverage                                                                                            | exit 1 with RangeError from @bcoe/v8-coverage 1.0.2                                                                                              | Canonical Bun coverage could not complete in this environment.                                                                                                                                                                                                                                                                         |
| Node 24 direct Vitest coverage diagnostic                                                                                  | exit 0; 85 files / 1,054 tests; statement/function/line 100%, branch 99.7% (1,343/1,347)                                                         | Diagnostic only; not the canonical Bun command and not an authoritative baseline.                                                                                                                                                                                                                                                      |
| Rails tests, Rails routes/notes, COVERAGE=true Rails coverage, bin/ci                                                      | not run                                                                                                                                          | Test PostgreSQL database names are distinct (`test_*` versus `development_*`), but the host may fall back to `POSTGRESQL_HOST`; test AUTH_STATE_REDIS_URL uses Valkey DB 2 without proven namespace isolation; bin/ci includes db:prepare/server smoke. Do not run until safe disposable targets and provider egress stubs are proven. |

### Continuation execution update — 2026-09-14

These checks were run after the initial planning-only run against the same pre-existing worktree. No
application or persistent test files were edited by this continuation.

| Command / condition                                                                                                                                                         | Result                                                                                                                                                | What it proves / does not prove                                                                                                                                                                                                                                                                                                                                                                                       |
| --------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `git diff --check` and `ruby -c` on the 6 modified Auth controllers and 4 modified Rails tests                                                                              | exit 0; all syntax checks reported `Syntax OK`                                                                                                        | Whitespace and Ruby syntax only.                                                                                                                                                                                                                                                                                                                                                                                      |
| `bin/rubocop --cache false` on those 10 modified Ruby files                                                                                                                 | exit 0; 10 files, no offenses                                                                                                                         | Targeted lint only; not a Rails runtime check. Cache writes were disabled.                                                                                                                                                                                                                                                                                                                                            |
| `bun run test -- spec/features/auth/signin/signin_interaction.test.tsx spec/features/auth/auth_com_signup_screens.test.tsx`                                                 | exit 0; 2 files, 51 tests passed                                                                                                                      | Focused React coverage only.                                                                                                                                                                                                                                                                                                                                                                                          |
| `bun run test`                                                                                                                                                              | exit 0; 85 files, 1,055 tests passed                                                                                                                  | Current ordinary Vitest result; not coverage.                                                                                                                                                                                                                                                                                                                                                                         |
| `bun run format:check`; `bun run lint`; `bun run typecheck:verify && bun run typecheck`                                                                                     | each exit 0                                                                                                                                           | Current frontend formatting, lint and TypeScript checks.                                                                                                                                                                                                                                                                                                                                                              |
| `bun run test:coverage -- --coverage.reportsDirectory=/tmp/umaxica-feature-coverage-20260914`                                                                               | exit 1; Vitest 5.0.0 / coverage-v8 5.0.0 / `@bcoe/v8-coverage` 1.0.2 threw `RangeError: Maximum call stack size exceeded` in `mergeRangeTreeChildren` | Canonical Bun coverage path failed during report merge, after enabling V8 coverage. No thresholds or tests were changed.                                                                                                                                                                                                                                                                                              |
| Same Bun coverage command with `--maxWorkers=1 --fileParallelism=false`, separate `/tmp` output                                                                             | exit 1 with the same merge stack overflow                                                                                                             | Worker parallelism does not explain the canonical-run failure.                                                                                                                                                                                                                                                                                                                                                        |
| `node_modules/.bin/vitest run --coverage --coverage.reportsDirectory=/tmp/umaxica-feature-coverage-20260914-node --maxWorkers=1 --fileParallelism=false` under Node 24.20.0 | exit 0; 85 files / 1,055 tests; statements 100%, branches 99.62% (1,344/1,349), functions 100%, lines 100%                                            | Diagnostic coverage result only. It meets configured numeric thresholds in Node but does not make the repository's canonical Bun coverage command green or establish the project's accepted baseline. Reports were directed to `/tmp`.                                                                                                                                                                                |
| Rails tests, `bin/rails routes`/`notes`, `COVERAGE=true` Rails coverage, `bin/ci`                                                                                           | still not run                                                                                                                                         | Current process routes auth-state Valkey to logical DB 2; no unique run/worker/test namespace is established on request-path stores. PostgreSQL test and development database names are distinct, but the test host may fall back to the same configured host; no connection was opened. `bin/ci` begins with `db:prepare`. The available process-listener probe was blocked by `EPERM`; no service state is claimed. |

Further read-only safety check: `config/database.yml` declares separate `test_*` versus
`development_*` database names, though `test_host` can fall back to `POSTGRESQL_HOST`; no connection
or schema was opened. `Umaxica::Valkey::Namespaces` supports unique suite/worker/test suffixes, and
store unit tests pass them explicitly, but default constructors used by request paths omit them. The
active `AUTH_STATE_REDIS_URL` was recorded in sanitized form as `redis://valkey:6379/2`; it was not
contacted. `test/test_helper.rb` injects `TurnstileVerifierStub`, which falls through to the real
verifier unless a test configures a response. `OutboundHttpStub` is scoped to individual tests; no
suite-wide external-network deny was found. `valkey-server`, `redis-server`, Docker, and Podman were
absent from `PATH`; `pg_isready`, `psql`, and `unshare` were present. The no-side-effect probe
`unshare -n -- true` exited 1 with `Operation not permitted`, so a process network namespace could
not be established. These observations do not prove shared services are absent. No service
connection was attempted. These facts keep E0's Rails gate closed despite the distinct PostgreSQL
test names.

Read-only OTP review against an earlier dirty-worktree snapshot found that
`CloudflareTurnstile#cloudflare_turnstile_validation` calls `TurnstileDegradation.apply`.
`docs/reference/feature-flags.md` states that `turnstile_degraded_mode` treats only a
Cloudflare-unavailable result as pass; missing/invalid challenges still reject. That earlier
snapshot had a broad `FeatureFlags.stub(:enabled?, true)` around the unavailable fixture, which
would map the case to verification success before an expected 422. The continuation removed that
broad stub; the current test diff now follows the documented default-off rejection policy. This
remains static evidence, not an observed Rails failure. The sign-in negative tests assert
session/token and OTP expiry remain unchanged but do not directly assert `otp_attempts_count`; add
that public-state assertion when tests can run safely. No Rails execution was attempted because E0
isolation remains unmet.

Additional DPoP static trace: all three `Base::{App,Com,Org}::Oauth::TokensController` classes
include `BaseOauthTokenEndpoint`; `create` forwards the `DPoP` header to
`OidcTokenExchangeCoordinator`. The initial pre-slice trace showed the coordinator consuming the
authorization code before `validate_dpop_proof`; the bounded continuation now validates the optional
proof before atomic consumption. `DpopProofVerifier#verify_nonce` accepts a blank nonce and only
calls the nonce store for a supplied value. The token endpoint controllers have no `DPoP-Nonce`
generation callback. Separately, `AuthenticationBase#load_from_token` emits a nonce when
`AuthenticationCurrentResourceResolver` returns no resource for a DPoP-scheme/proof request. That is
the resource-authentication path, not evidence that the AS token endpoint issues a challenge. No
public request, nonce retry, or code-state result was exercised.

### Targeted OIDC source re-audit — 2026-09-14

These are read-only source checks against HEAD `430ac354ba06c9d22885e1e69d027a7a1b1d5280`. Exit 1
from the parameter search means no textual match in the named files; it is not proof that
middleware, metaprogramming, or an alternate runtime path cannot preserve or enforce the parameters.

| Command / condition                                                                           | Result                                                                                                                                                                                                                                                                                                                                                                                         | What it establishes / leaves open                                                                                                                               |
| --------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `rg -n 'prompt                                                                                | max_age' app/controllers/concerns/oidc_sso_initiator.rb app/controllers/base/app/oauth/authorizations_controller.rb app/controllers/base/com/oauth/authorizations_controller.rb app/controllers/base/org/oauth/authorizations_controller.rb app/resolvers/oidc_authorize_request_resolver.rb app/models/concerns/oidc_authorization_transactionable.rb app/services/oidc_id_token_verifier.rb` | exit 1; no matches                                                                                                                                              | The inspected request builder, three Base controller files, resolver, transaction concern and RP ID Token verifier contain no literal support. This is static evidence only; no public OIDC request was exercised. |
| `rg -n 'auth_time: Time.current                                                               | authorization_code\.created_at                                                                                                                                                                                                                                                                                                                                                                 | created_at: payload\["issued_at"\]' app/operations/oidc_authorization_code_issuer.rb app/services/oidc_token_exchange_coordinator.rb`                           | exit 0 at the initial checkpoint; issuer still uses `Time.current`, while the later bounded exchange slice removed the `                                                                                           |                                                                                                                      | now`fallback and uses explicit`auth_time` only | Confirms source mapping, not the value observed in a signed token. No T0/T1/T2 test was run. |
| `rg -n 'grant_type                                                                            | refresh_token                                                                                                                                                                                                                                                                                                                                                                                  | valid_grant' app/services/oidc_token_exchange_coordinator.rb app/controllers/concerns/base_oauth_token_endpoint.rb`                                             | exit 0; endpoint forwards `grant_type`; coordinator's predicate accepts only `authorization_code`; code-exchange result contains `refresh_token`                                                                   | Confirms the source-level response/endpoint mismatch. No HTTP refresh-grant request or client-side use was observed. |
| `rg -n 'OidcRefreshTokenIssuer' app --glob '*.rb'`                                            | exit 0; only the operation class declaration was found                                                                                                                                                                                                                                                                                                                                         | No direct `app/` call site was found. This does not rule out reflective invocation or an external consumer.                                                     |
| Rails OIDC request tests, token-exchange requests, isolated Valkey/PostgreSQL fault injection | not run                                                                                                                                                                                                                                                                                                                                                                                        | Service isolation and provider egress controls were not proven; no dynamic claim, status, code lifecycle, session/family effect, or recovery result is claimed. |

The repository-root `refactor.md` is the only plan/document changed by this continuation;
`evidence/2026-09-14-e0-frontend-safety.md` is a separate untracked evidence note created earlier in
the same work. The bounded source/test slices listed in §19 changed application and test files; no
migration, route, configuration, ADR, database, Valkey state, external service or Git/GitHub state
was changed. The pre-existing modified tracked files and untracked paths listed in §2 remain
preserved rather than reset or cleaned.

Normative application boundaries:

- OIDC Core §2 defines `auth_time`; §3.1.2.1 covers `max_age`, freshness reauthentication and ID
  Token `auth_time`; §3.1.2.3 covers `prompt=login` and `prompt=none`; §12.2 preserves the original
  `auth_time` when a refresh response includes a new ID Token; §15.1 states OP support requirements.
  These apply respectively to RP request creation, all three Base authorization endpoints,
  transaction persistence/resume, Base freshness decisions, token claims, refresh responses and RP
  validation. If the inspected gaps hold at the public boundary, that is an existing OIDC
  conformance defect, not merely a possible future feature. The project Access JWT `auth_time`
  contract remains distinct from the OIDC ID Token requirement.
  [OpenID Connect Core](https://openid.net/specs/openid-connect-core-1_0.html)
- RFC 6749 §§4.1.2, 4.1.3 apply to authorization response code reuse, denial, client binding, code
  exchange authentication and exact redirect matching. The owner-bound replay revocation test is a
  project safety criterion layered on those AS rules; it must not remove legitimate same-code reuse
  denial/revocation. [RFC 6749](https://www.rfc-editor.org/rfc/rfc6749.html)
- RFC 9449 §§5, 8 apply to the actual DPoP proof verifier and error path at the AS or Resource
  Server. Nonce use is optional; once required/issued, test omitted/mismatching proof,
  use_dpop_nonce/DPoP-Nonce, and a valid retry. A response header's absence alone does not prove
  nonconformance. [RFC 9449](https://www.rfc-editor.org/rfc/rfc9449.html)
- Cloudflare Turnstile server-side validation applies at each server POST that accepts a challenge
  token. The token is single-use and expires; test challenge consumption separately from OTP
  attempts and request rerender.
  [Cloudflare Turnstile server-side validation](https://developers.cloudflare.com/turnstile/get-started/server-side-validation/)

### Follow-up verification update — 2026-09-15

These checks continued the planning and verification work against the same dirty worktree at HEAD
`430ac354ba06c9d22885e1e69d027a7a1b1d5280`. Rails commands ran with a read-only root filesystem and
fresh `/tmp` overlays for workspace logs, `tmp`, Vite test assets/cache; `DATABASE_URL` was unset
and `AUTH_STATE_REDIS_URL` pointed to loopback port 1. This protects repository files and avoids
connecting to the configured Valkey host, but does not establish safe PostgreSQL/Valkey/provider
targets for request tests or the full suite.

| Command / condition                                                                                                                                                                                                            | Result                                                                                                                                                                | What it proves / leaves open                                                                                                                                                                                                                                                                                                                                                                                       |
| ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `bin/rails routes` in the sandboxed test environment                                                                                                                                                                           | exit 0; 1,395 output lines; no stderr                                                                                                                                 | Runtime route declarations load. The route table contains 14 in-scope authenticated roots (Auth/Base/Core/Side app/com/org, Palm app, Edit org), plus Base/Core net/dev and public content roots; it also confirms current `/web/v0`, `/edge/v0`, `/identity/sessions`, `/sign/out`, and GUID paths. It does not exercise host matching, callbacks, authentication or request responses.                           |
| `bin/rails notes` in the same sandbox pattern                                                                                                                                                                                  | exit 0; 20 output lines; eight existing TODO/FIXME annotations across `actor_support`, `preference_transport`, outage/emergency services and two principal migrations | Notes enumeration works at runtime. No actionable route-migration FIXME was present in the output; any later deferred route must add a specific annotation and recheck notes.                                                                                                                                                                                                                                      |
| `bin/rails test test/controllers/auth/app/sign/up/check/email/otps_controller_test.rb` in the same filesystem/Valkey sandbox, using the temporary successful Vite build metadata after the earlier ViteRuby subprocess failure | exit 1 before test assertions; `ActiveRecord::Migration.maintain_test_schema!` failed because host `primary` could not be resolved                                    | The targeted Rails behavior remains unverified. No PostgreSQL connection was established and no test/schema mutation completed. This is an environment stop, not an application test failure. The earlier first attempt aborted in ViteRuby's `bun x --bun vite` subprocess; a direct `bun run vite build --mode test` under the sandbox succeeded, after which the retry reached the PostgreSQL connection check. |
| `bun run test -- spec/features/auth/auth_com_signup_screens.test.tsx spec/features/auth/signin/signin_interaction.test.tsx spec/features/turnstile/turnstile_widget.test.tsx`                                                  | exit 0; 3 files, 66 tests passed                                                                                                                                      | Focused React behavior with mocked Turnstile; not Rails integration or proof of server-side verification.                                                                                                                                                                                                                                                                                                          |
| `bundle exec rubocop` on the six modified Auth controllers and four related controller tests; `ruby -c` on those 10 Ruby files                                                                                                 | each exit 0; no RuboCop offenses; all syntax checks `Syntax OK`                                                                                                       | Targeted lint and syntax only.                                                                                                                                                                                                                                                                                                                                                                                     |
| `bun x oxlint` on the four changed frontend/test files; `bun x oxfmt --check` on those files; `bun run typecheck`                                                                                                              | each exit 0; format check clean                                                                                                                                       | Frontend lint, formatting and types only.                                                                                                                                                                                                                                                                                                                                                                          |

The Rails test failure does not provide a green/red behavioral result; no Rails assertions ran. The
route and notes commands do not clear E0: PostgreSQL test identity remains unresolved/unreachable,
request-path Valkey namespacing and complete provider-egress stubbing remain unproved, and canonical
Rails coverage/CI remain unrun. The runtime route inventory supersedes only the earlier statement
that Rails routes had not been run; host/request behavior remains unverified.

The OTP test fixture contradiction identified in the earlier static review was corrected in the
current worktree's two signup OTP test files: the broad `FeatureFlags.stub(:enabled?, true)` wrapper
was removed so the documented default-off `turnstile_degraded_mode` policy is exercised for the
unavailable case. This is a test-contract correction only; no production policy was changed. Ruby
syntax and targeted RuboCop pass after the edit, while the Rails tests remain unrun because the
isolated PostgreSQL prerequisite is still unavailable.

## 13. Baseline and regression strategy

Do not call either historical result a current baseline:

- A historical green note reports Rails 12,957 runs / 0 failures / 0 errors / 3 skips and Vitest 85
  files / 1,050 tests. This is prior evidence only.
- A historical failing run reports 13,014 runs / 11 failures / 42 errors / 2 skips with line 98.56%,
  branch 88.46%, method 94.50%. It is not a green baseline. Its line figure is not silently adopted
  as a new threshold.
- Current Rails SimpleCov settings read from `.simplecov`: line minimum 97%, per-file 70%,
  Models/Policies/Values groups 99%, Services/Controllers groups 98%, maximum line drop 0.2
  percentage points; branch minimum 90% with `implicit_else` ignored and maximum branch drop 0.5
  points; method minimum 95%. SimpleCov version in the lockfile is 1.2.0. The current run did not
  measure Rails coverage.
- Current Vitest coverage configuration requires 99% statements, branches, functions and lines.
  Ordinary `bun run test` does not establish those coverage values. The canonical Bun coverage
  command failed twice in V8 report merging; direct Node 24 diagnostic produced 100/99.62/100/100,
  but is not the canonical run and is not an accepted baseline. Do not infer `.last_run.json`
  generation/consumption behavior from comments alone; verify it against the locked SimpleCov
  version and an actual safe coverage run.

Future E0 must first prove disposable PostgreSQL, isolated Valkey namespace/connection, blocked or
stubbed provider egress and safe background/cache/rate-limit stores. Then capture:

1. Rails test count, pass/fail/error/skips and exit code.
2. Rails coverage with the repository's actual COVERAGE=true invocation; line/branch/method,
   per-file and group values, max-drop result and generated-file cleanup policy.
3. Ordinary Vitest and canonical Vitest coverage as separate commands.
4. RuboCop, ERB lint, security/static checks, OpenAPI lint/bundle/verify, routes/notes and bin/ci
   outcomes separately.
5. Exact environment/runtime and dependency versions.

If current Rails suite is red, classify each result as environment, existing production defect, test
inconsistency or planning-run side effect. First repair only authorized baseline defects and
remeasure green. Do not start wide private-test/method visibility cleanup before a green
attributable baseline. Never use a baseline failure to excuse a new failure. No threshold,
exclusion, skip, assertion or security gate is to be weakened.

## 14. Plan-deviation rules

A future implementation plan remains frozen only after user approval. The implementer may alter
local details that do not change invariants. Any change to Base/Auth authority, security boundary,
service ownership, external API/OIDC contract, auth_time or freshness semantics, data ownership,
destructive migration/backfill policy, DPoP client enforcement or unresolved direct-entry UX is
PLAN_DEVIATION.

A deviation report must give:

- the original assumption and affected REQ IDs;
- new repository/runtime evidence, including path/method/entrypoint and reproducible test;
- changed trust, protocol, data or deployment impact;
- least-risk alternatives, rollback/forward repair and test changes;
- the exact user decision required.

Pause only the dependent phase. Continue independent work that does not assume the disputed
invariant. Do not disguise a deviation as a refactor. No deviation is authorized by this planning
file.

## 15. Final independent audit procedure

The future final reviewer begins with actual deployed/local behavior, not phase names:

1. enumerate externally reachable host/path/method and actor/client boundaries;
2. infer which authority creates/accepts identity/session/assurance from the call and persistence
   paths;
3. attempt wrong-owner, cross-realm, replay, concurrency, expiry, malformed-input, store-failure and
   response-loss cases;
4. inspect actual signed claims, Set-Cookie/headers, browser-visible DOM and persisted rows;
5. inspect tests and implementation only after writing down the inferred behavior;
6. compare that behavior to the complete source REQ list, accepted ADRs, OpenAPI and explicit
   accepted risks;
7. run the attributable full test/static/coverage gates and list each skip;
8. independently verify that no implementation was validated by a fake browser/device test.

A passing test suite or code resemblance to this plan is insufficient if a hostile request disproves
the intended behavior.

## 16. Remaining risks and follow-up plans

Accepted risks from the supplied current decisions remain accepted; this project does not strengthen
them in this plan:

- SMS/PSTN retains residual security weakness for product usability. Do not imply telephone
  possession alone provides assurance or phishing resistance, and do not silently label it AAL2.
- A previously issued short-lived Access JWT may remain valid until expiration after session
  termination/revocation. Short lifetime bounds exposure; DPoP may reduce usefulness of a stolen
  token but is not immediate revocation; DBSC does not substitute for revocation. Revisit if token
  lifetime materially increases or immediate invalidation becomes a requirement.
- DPoP sender constraint remains policy-dependent by client type until actual BFF/native token/key
  ownership is proven. Device key interoperability is pending.
- DBSC remains provisional/progressive enhancement and device/browser validation pending;
  unsupported clients must retain a safe session path.

Required future plan items with exit criteria, not implemented in this run:

1. New bounded AAL/FAL/ACR/AMR normalization plan: settle policy/freshness/method/upstream
   IdP/passkey/emergency/federation semantics and distinguish product language from conformance.
   Exit only after a reviewed contract and tests; no NIST claim without full assessment.
2. Direct Base-local sign-in UX decision: choose entry, owner, completion, error/retry, signup,
   Step-Up and max_age/prompt behavior; no synthetic RP flow.
3. DBSC real browser/device validation: registration, key creation/persistence, restart, refresh,
   stolen-cookie resistance, proof failures, logout/revoke and unsupported fallback.
4. DPoP real-client/device validation: secure key storage, proof generation, AS and RS verification,
   replay/wrong key/token-without-key, restart and native/BFF interoperability.
5. Authorization-code cross-store and replay-owner decision: failure semantics for missing/invalid
   link, timeout, signing/DB/response failure; no implicit “Valkey fail-closed” claim.
6. GUID data ownership and public net API/OpenAPI decision: identify authoritative owner,
   durability/ID uniqueness/tombstone expectations and whether net receives a per-surface OpenAPI
   artifact.
7. Any additional inconsistency discovered during the bounded phases gets its own small plan with
   problem/current state/security impact/prerequisites/validation/exit criteria; do not turn plans
   into an unbounded dump.

## 17. Explicitly rejected approaches

- Treating current implementation or Sol's static review as unquestionable authority, or claiming
  static callsites prove a remotely exploitable path.
- Pretending the missing original prompt text or exact REQ-095 ORG wording is known.
- Freezing/executing the whole 95-item program despite unresolved D-ENTRY, replay/link
  partial-failure behavior and unsafe runtime targets.
- Faking auth_time from code issuance, exchange time, refresh time or Active Record timestamps.
- Moving replay revocation earlier without owner binding, or deleting replay revocation to avoid
  collateral effects.
- Returning success after an unconfirmed family link, assuming a cross-database/Valkey ACID
  transaction, or restoring consumed codes.
- Claiming RFC 9449 requires a nonce in every DPoP deployment, or treating absent nonce header as a
  violation without an issued challenge.
- Reintroducing Auth as RP/AS, deleting all Auth ceremony state because it is hosted by Auth, or
  manufacturing an RP for direct sign-in.
- Introducing online database lookup on each Access JWT request to meet an immediate-revocation
  preference that was explicitly accepted as deferred.
- Adding a GUID model or inventing net OpenAPI ownership before evidence or decision.
- Using permanent FIXMEs or wide protocol exclusions to represent completed OpenAPI coverage.
- Changing coverage floors, adding skips/exclusions, weakening assertions/security checks, or
  calling an ordinary test run a coverage run.
- Starting the complete implementation from the original planning-only run without a separate
  authorization. A later independently authorized run still cannot freeze all 95 items until the
  stated source, environment and decision gates are resolved.

## 18. Final readiness statement

The evidence-based candidate plan and continuation evidence are recorded in this repository-root
file. The complete 95-item program remains **NO_GO for autonomous freeze or execution**. The
original planning run did not execute an implementation phase; the separately authorized
continuation has begun only the bounded slices recorded in §19. For the remaining program, E0 static
evidence and read-only runtime `routes`/`notes` inventory are recorded, but its comparable Rails
test/coverage baseline gate remains BLOCKED_BY_ENVIRONMENT; E6's inert React Create behavior and
E7a's Step-Up decision are already satisfied by inspected code/tests, while their
Rails/direct-callback behavior remains unverified; E8 route declarations are runtime-enumerated but
request contracts, host dispatch, and route changes remain gated on isolated Rails services.
E1/E2/E3/E4/E5/E7b/E7c/E9 require their listed prerequisites; E2's standalone local-entry slice is
BLOCKED_BY_DECISION, E3's RP-originated OIDC conformance work is READY_WITH_PRECONDITIONS, E5
physical-client/browser checks are DEFERRED_VALIDATION, and E10 waits for the earlier work. Current
ordinary Vitest, targeted Ruby syntax/lint and frontend format/lint/typecheck checks passed;
canonical Bun coverage and Rails behavior checks remain unresolved as recorded above. OIDC time,
prompt/max_age, replay/link, Auth admission and overall baseline claims still need safe isolated
services. Direct-entry UX, GUID ownership/OpenAPI surface, the literal Base `/dashboard` link
conflict and OIDC refresh response/grant ownership require decisions before dependent changes.

The original final update was planning-only. The continuation has a separate status in §19. No
migration, route, configuration, ADR, database/Valkey state, external service or Git/GitHub state
was changed. Rails requests still did not reach an assertion: the targeted invocation stopped at the
PostgreSQL schema-connection check. No isolated token-exchange request, refresh-grant request,
physical DPoP/DBSC interoperability test or provider request was run. Pre-existing modified tracked
files and untracked paths remain preserved.

## 19. Local continuation — bounded implementation slices (2026-09-15)

The user subsequently instructed the work to continue. This section supersedes the original
planning-only statement only for the bounded, low-risk slices below; it does not approve the
complete 95-item program and does not resolve any NO_GO decision. Existing tracked and untracked
user changes were preserved. No checkout, reset, clean, stash, stage, commit, database reset, Valkey
write, external provider call or GitHub operation was performed.

### Slice A — purpose-specific email OTP subjects

The app/com OTP delivery path now carries a non-secret `purpose` value from the existing
sign-up/sign-in callers through `OtpEmailAdapter` / `OtpEmailNotifierAdapter`, the surface notifier,
and the existing mailers. App and com mailers select locale keys for `sign_up` and `sign_in`; all
other callers retain the existing generic subject. The shared sign-in resend service now receives an
explicit `surface` from the app/com endpoint, so a corporate resend cannot fall through to the app
mailer. The encrypted OTP payload, body, expiry, verification link and security notice are
unchanged, and the subject never contains the OTP. Org remains on the generic subject because no org
sign-up/sign-in requirement was established. The adapter uses the positional hash shape required by
Rails Action Mailer and Noticed `with` APIs; no keyword-only wrapper was introduced.

Changed files: `app/adapters/otp_email_adapter.rb`, `app/adapters/otp_email_notifier_adapter.rb`,
`app/notifiers/notify/otp_issuance_notifier.rb`,
`app/notifiers/notify/{app,com,org}/otp_notifier.rb`,
`app/controllers/concerns/sign_email_registrable.rb`, `app/services/sign_otp_ceremony.rb`,
`app/services/sign_in_otp_resender.rb`,
`app/controllers/auth/{app,com}/web/v0/in/email/otps_controller.rb`,
`app/mailers/email/{app,com}/otp_mailer.rb`, the four Japan/US locale files, and focused
adapter/notifier/mailer/resend tests. The existing dirty app/com Auth controllers supply `:sign_up`
or `:sign_in` at their direct delivery points; those pre-existing changes were not overwritten.

Status: implementation is syntactically and statically checked, but Rails mailer/adapter/notifier
tests could not reach assertions because the isolated test PostgreSQL host was unavailable.
`bundle exec rubocop --cache false` on the 18 touched Ruby files exited 0; `ruby -c` and
`git diff --check` exited 0. The exact mailer subject and no-OTP assertions are present but
unexecuted in Rails in this environment.

### Slice B — recovery identity preload

`RecoveryPasscodeTopUp#preload_recovery_identity_associations!` now loads Visitor and staff
email/telephone associations in addition to the existing Client associations. This keeps credential
validation and `RecoveryIdentityRequiredValidator` intact while preventing repeated Visitor/Staff
existence queries during the ten-passcode issuance loop. A public service regression test covers a
verified Visitor with email and asserts the full issuance result inside a Prosopite scan. It is a
written RED→GREEN regression, but RED/GREEN was not observed because the Rails test stopped during
schema connection before assertions.

Changed files: `app/services/recovery_passcode_top_up.rb` and
`test/services/recovery_passcode_top_up_test.rb`. No `Prosopite.pause`, validator bypass, global
memoization or broad rescue was added.

Status: syntax and targeted RuboCop passed; database/query-count behavior is unverified pending an
isolated PostgreSQL test target. The test must be run with verified test DB/Valkey isolation before
this slice is called validated.

### Slice C — OTP Turnstile test/flow continuation already present in the worktree

The pre-existing dirty Auth changes add visible sign-up OTP Turnstile props/widgets, server-side
checks before OTP verification on app/com sign-up and sign-in, OTP-clearing lifecycle behavior, and
related controller/React tests. During review, broad feature-flag stubs around signup negative cases
were removed so missing/invalid/unavailable Turnstile cases follow the documented rejection policy
instead of being accidentally converted to success. These files remain user-owned dirty changes and
are not claimed as Rails-validated here.

### Verification boundary

Successful checks for this continuation: focused Vitest and the full ordinary Vitest suite (85
files, 1,055 tests), frontend format/lint/typecheck, targeted RuboCop for the new Ruby slice, Ruby
syntax checks and `git diff --check`. Canonical Bun coverage still fails in the dependency's V8
range-tree merge; a direct Node/Vitest coverage run is diagnostic only. Rails tests still stop
before assertions at `PG::ConnectionBad` while resolving PostgreSQL host `primary`; no schema or
data was touched. `bin/ci`, full Rails tests, Rails coverage, OpenAPI route-contract tests,
OIDC/DPoP/DBSC dynamic tests and physical-device validation remain unrun.

The 2026-09-15 resend-surface correction was additionally checked with
`bundle exec rubocop --cache false` on the two resend controllers, `SignInOtpResender`, and its two
service test files (exit 0, no offenses), `ruby -c` on all five files (all `Syntax OK`), and
`git diff --check` (exit 0). The service now rejects an unsupported surface and the public resend
test asserts that a com request selects the com adapter and carries `purpose: :sign_in`; Rails
execution of that assertion remains pending the same isolated database prerequisite.

### Static code-review update — 2026-09-15

A follow-up review checked the changed delivery and Turnstile paths rather than treating the passing
frontend suite as proof of Rails behavior. Every repository call to `SignInOtpResender.new` now
supplies an explicit `app` or `com` surface; the resender rejects other surfaces before delivery.
The Action Mailer parameterized `with` API was inspected and accepts the positional parameter hash
used by `OtpEmailAdapter`; the notifier path likewise retains its existing positional `with`
contract. Purpose values are allowlisted by the app/com mailers and fall back to the existing
generic subject, so arbitrary caller text cannot become a subject template and no OTP is inserted
into the subject. The signup OTP controllers render the same OTP page on Turnstile failure, before
code extraction/verification, with a new visible challenge prop; the React form has no OTP value
prop. These are static observations only. No dynamic assertion was promoted to validated status.

The same read-only pass traced normal authentication cookie cleanup. `AuthenticationCookieService`
and `AuthenticationCookieStore` derive both issuance and deletion from `CoreCookieOptions` with
host-only scope (`domain: false`), `path: "/"`, `same_site: :strict`, and the
request/environment-derived secure flag; production adds the same partitioning behavior.
`AuthenticationLogoutable` calls `clear_auth_cookies!` from the normal-session `ensure` path, and
the OIDC logout path does likewise. This finds no code-level name/domain/path mismatch for
`auth_access` or `auth_refresh`, but it does not prove a browser jar receives and applies both
deletion headers. E7b remains pending an isolated cookie-jar request test across app/com/org.

### Continuation acceptance

These slices are **implemented but validation pending**, not complete feature acceptance. The full
plan remains **NO_GO** until the source/decision/environment gates in §§10–11 are resolved. Any
further service-backed TDD slice must wait for disposable PostgreSQL and Valkey targets plus
provider egress stubs; then the focused Rails tests can run before accepting runtime behavior.
Static review and bounded code changes that do not contact those services may continue only when
they preserve the listed invariants. No auth-time source, refresh contract, Auth admission, GUID
ownership or direct-entry architecture change is made by this continuation.

### Verification update — 2026-09-15 (continued)

After the resend-surface correction, the ordinary frontend suite was rerun: `bun run test` exited 0
with 85 files and 1,055 tests passed. `bun run format:check`, `bun run lint`, and
`bun run typecheck:verify && bun run typecheck` each exited 0. `bin/rubocop --cache false` exited 0
after inspecting 4,790 files; `bundle exec erb_lint --lint-all` exited 0 for 599 files (with the
repository's existing Ruby 3.3 parser warning under Ruby 4);
`bundle exec brakeman --quiet --no-pager --exit-on-warn --exit-on-error` exited 0 with zero
warnings; all 15 newly touched Ruby files passed `ruby -c`; and `git diff --check` exited 0. These
checks are static/frontend evidence only. Rails tests, Rails coverage, `bin/ci`, OpenAPI contract
tests, and provider/Valkey/DB-backed behavior remain unrun because no disposable PostgreSQL/Valkey
target and suite-wide external-egress boundary have been proven. The worktree status remains the
same set of preserved tracked modifications and untracked paths; no generated repository file was
added by these checks.

### Auth-time propagation continuation — 2026-09-15

A second read-only trace followed the ordinary Auth session path and the OIDC authorization path
from the current `feature` HEAD (`430ac354ba06c9d22885e1e69d027a7a1b1d5280`). It adds precision to
ADV-002/ADV-014 without changing their status or claiming an endpoint reproduction.

#### Confirmed source facts

1. The underlying codec accepts `auth_time`, and the bounded continuation now makes the ordinary
   Auth facade accept and forward that explicit keyword.
   `app/controllers/concerns/authentication_jwt_tokens.rb#encode_login_access_token`,
   `#encode_refreshed_access_token`, and `#reissue_access_token!` still do not supply a semantic
   authentication-event time, so the forwarding seam does not claim end-to-end propagation.
2. The three root session token models (`ClientToken`, `VisitorToken`, `OperatorToken`) expose no
   `auth_time` column in their model/schema declarations.
   `AuthenticationBase#create_login_token_record` persists the established authentication method
   and, where supported, the authentication context; it does not persist an authentication-event
   timestamp. The token models' `created_at` is session-row persistence metadata and is not promoted
   to `auth_time` by this audit.
3. `OidcAuthorizationTransactionable#register_authentication!` writes `authenticated_at: now`, but
   `#authorize_params` returns only the request fields.
   `OidcAuthorizationTransactionCoordinator.register_result!` accepts `auth_method` and `acr` but no
   event time. `BaseAuthAdmissionCoordinator.register_result_and_issue_resume!` likewise forwards no
   event time.
4. `app/controllers/base/{app,com,org}/oauth/authorizations_controller.rb#issue_authorization_code!`
   passes the current access-token `amr` and `acr` to `OidcAuthorizeCoordinator` for both the
   already-authenticated shortcut and the transaction-resume path. It does not pass `auth_time`.
   `OidcAuthorizeCoordinator` and `OidcAuthorizationCodeIssuer` therefore have no trusted event-time
   input and the issuer writes `auth_time: Time.current` to the authorization-code store.
5. The initial source used `issued_at` before `auth_time`, and `#issue_exchanged_token_result` used
   that value (or exchange `now`) for both the exchanged Access JWT and ID Token. The bounded
   continuation now returns only explicit payload `auth_time`, rejects missing values before
   consume, and has a delayed-code regression written. The upstream issuer still writes
   `auth_time: Time.current`, so the source-confirmed authentication-event defect remains unresolved
   end to end.
6. Identity tables do contain provider-specific `last_authenticated_at` fields, and the OIDC
   transaction tables contain `authenticated_at`, but the inspected code does not establish either
   as the canonical event for every email, telephone, passkey, secret, social, Step-Up, SSO, or
   existing-session authorization path. Choosing one by name would be an unsupported semantic
   substitution.
7. `OidcSsoInitiator#oidc_authorization_url` emits state, nonce and PKCE but no `prompt` or
   `max_age`. All three Base authorization controllers use fixed request allowlists that omit those
   parameters; the transaction serializer drops them; `OidcIdTokenVerifier` accepts an expected
   nonce but has no expected freshness or `auth_time` validation input. This confirms the inspected
   path's request-freshness gap; it is not a browser-level result.
8. `OidcRefreshTokenIssuer` is exercised by service/invariant tests but no production caller was
   found under `app/`. The public `OidcTokenExchangeCoordinator` accepts only
   `grant_type=authorization_code` while its response includes `refresh_token`. No production path
   was found that issues a refreshed Access/ID pair and carries the original `auth_time`; the
   refresh response/grant ownership remains a decision gate, not an implementation task.

#### Interpretation and required implementation gate

The next auth-time implementation must first define one Base-owned, semantically named
authentication-event source for each accepted authentication or reauthentication outcome, then carry
that value through Auth evidence/admission, Base transaction or existing-session context,
authorization-code payload, exchange, and any supported refresh response. It must not use code
`issued_at`, exchange `now`, refresh time, token/session `created_at`, or an identity timestamp that
only covers one provider. The ordinary Auth facade must be included in the design because changing
only `OidcAuthorizationCodeIssuer` would leave the root session JWT path unable to carry the event.

The first failing tests for E1 must set three distinct instants (`T0` accepted authentication, `T1`
code issue, `T2` exchange), decode both Access and ID tokens, and assert `auth_time == T0`, `iat`
remains each token's issuance time, and no refresh operation changes `auth_time`. Separate cases
must cover an existing SSO session, genuine reauthentication, Step-Up where policy treats it as a
new event, social-link evidence without granting Auth/Base authority, missing event data (fail
closed rather than substituting `now`), and all app/com/org authorization controllers. A supported
OIDC refresh response, if confirmed by the owner decision, must retain the original event time while
advancing only the new token `iat`; if no such public grant exists, the implementation must not
invent one or silently remove the returned refresh token.

#### Validation status

This is static source evidence only. No PostgreSQL-backed request, Valkey code exchange,
signed-token decode at a public endpoint, refresh request, `prompt`/`max_age` request, or RP
callback was executed because the repository still has no proven disposable PostgreSQL/Valkey
target. The plan therefore remains NO_GO for the complete autonomous program and E1 remains
READY_WITH_PRECONDITIONS after E0, with the event-source and refresh-contract decisions explicitly
unresolved.

### Auth admission continuation — 2026-09-15

The same source pass checked the leaf-controller boundary for app/com/org instead of generalising
the earlier app-only observation.

- `app/controllers/auth/{app,com,org}/sign/{ins,ups}_controller.rb` includes `AuthCeremonyAdmission`
  and calls `admit_or_render_sign_ceremony!`. With no admission and no admitted ceremony session,
  that concern bridges to the corresponding Base root; with a valid Base handoff it consumes the
  handoff, stores the login challenge and intent, rotates the ceremony-local `__Host-auth_sid`, and
  redirects to a clean selector URL.
- The app/com email OTP leaf controllers do not include `AuthCeremonyAdmission`. Their successful
  public update paths call `AuthenticationSessionCommitter.call`
  (`app/controllers/auth/app/sign/in/emails_controller.rb#verify_otp_and_login` and
  `app/controllers/auth/com/sign/in/emails_controller.rb#update`), which delegates to the
  controller's `establish_signed_in_session!`. App/com passkey leaf paths similarly call the
  committer. The leaf source does not itself check `session[:oidc_authorization_login_challenge]`
  before committing.
- The org secret path has a distinct `before_action :require_org_normal_sign_in_transaction!` and
  refuses a missing/invalid normal sign-in transaction before credential verification; org passkey
  paths consume their own normal/emergency ceremony state. This is evidence that org cannot be
  inferred from the app/com leaf shape, not evidence that every org path is complete.
- Auth application controllers use `AUTHENTICATION_MODE = :deny_all` as the parent default, while
  these leaf controllers declare `:guest`; the effective callback chain and `AuthenticationMode`
  implementation must be exercised rather than inferred from the constant alone.
  `AuthenticationModeSwitchGuard` prevents already-authenticated sign-in responses but is not an
  admission verifier.
- The Auth `after_login_path` for a non-OIDC challenge sends app/com/org to the corresponding Base
  root. For an OIDC challenge, it registers the result with Base and resumes the transaction. No
  direct-entry UX decision was made by this audit.

This makes ADV-006 a stronger, surface-qualified test requirement: use valid fixtures to submit a
leaf request with no admission, with a valid admitted challenge, with
expired/replayed/purpose-mismatched/surface-mismatched admission, and with a valid credential.
Observe whether Auth session cookies, root tokens, ceremony rows, DBSC headers, Base admission
result, authorization code and RP session are created. A request rejected earlier by a rate limit,
missing email session, invalid OTP or selector guard is not evidence that the admission invariant
was tested. The tests must separately cover app, com and org and distinguish a rendered page from a
committed Auth/Base authority state.

The static trace does not establish an exploitable bypass because no isolated database-backed
request was run and the inherited callback ordering is not proven by source names alone. It does
establish that a future implementation cannot close the gap by adding an RP code/assertion in Auth
or by deleting all Auth ceremony state. The direct-entry owner, completion target, and no-RP-request
behavior remain BLOCKED_BY_DECISION; only the dependent boundary tests and any correction are
blocked, while independent source inventory and plan work remain executable.

### Authorization-code replay and DPoP continuation — 2026-09-15

The Ruby and Lua paths were compared without contacting Valkey. The Lua
`AuthorizationCodeStore::CONSUME_SCRIPT` returns `replay` as soon as the stored lifecycle state is
no longer `issued` (before its expected client, redirect and PKCE fields are compared).
`OidcTokenExchangeCoordinator#exchange_authorization_code!` then calls `revoke_linked_family!` for
that result. The coordinator's Ruby `prevalidate_payload` has the same state-first ordering. For an
already-consumed code whose tombstone contains an RP-session or refresh-family reference, the source
path can therefore reach a revocation lookup before proving that the caller's authenticated client
owns the code. This is a source-qualified HIGH finding, not a reproduced cross-client exploit: no
isolated A/B client fixture, Valkey state, or persisted session diff was observed. The eventual test
must use two valid same-realm clients and inspect the code owner's RP session, family and Base
session as well as the unrelated client's records; a request rejected before the replay branch is
not sufficient evidence.

The consume/link sequence is also asymmetric. The code is atomically changed to `consumed` by
`consume!`, then resource/root-token and optional DPoP checks run, then the database transaction
creates or updates RP usage, rotates the refresh credential, calls `link_family!`, and builds the
token response. `link_consumed_family!` ignores a `missing` or `invalid_state` result and converts
selected Valkey exceptions to a warning before the response continues. Valkey and PostgreSQL are not
one transaction. The implementation phase must classify, with injected failures, link missing, link
invalid-state, link timeout/unknown outcome, token signing failure, database commit failure, and
response loss; it must not treat all of them as one rescue or restore a consumed code without a
decision about revocation guarantees.

DPoP proof validation occurs after code consumption in
`OidcTokenExchangeCoordinator#issue_tokens_for_consumed!`. `DpopProofVerifier` accepts an absent
nonce and verifies a supplied nonce only through `DpopNonceService`; the inspected token-endpoint
path does not itself emit a `DPoP-Nonce` challenge when proof validation fails. RFC 9449 section 8
makes nonce use optional, so the absence of a challenge is not by itself a conformance failure. It
does mean the later test must distinguish an endpoint that never requested a nonce from one that has
issued one, and must record the exact `invalid_dpop_proof`/nonce error and retry contract. A bad
proof currently returns after the code is consumed; whether retry requires a new authorization
transaction or a nonce-based re-request is an implementation/contract decision, not a reason to make
consumed codes reusable by default. These are static findings; no proof, nonce, or retry was
executed against a Valkey-backed endpoint.

### OTP/Turnstile static continuation — 2026-09-15

The current dirty worktree was re-read after the earlier `ADV-013` review. The broad
`FeatureFlags.stub(:enabled?, true)` wrapper described in that historical finding is no longer
present in either `test/controllers/auth/app/sign/up/check/email/otps_controller_test.rb` or its
`com` counterpart. The earlier finding therefore remains a record of the test setup that was
reviewed, while the current files are the evidence for the next run.

The policy boundary is still material: `TurnstileDegradation#apply` converts only a verifier result
marked `unavailable` into success when `turnstile_degraded_mode` is enabled; missing tokens and
failed challenges remain failures. The current signup negative tests do not explicitly pin that
feature flag, so they are not deterministic evidence of the degraded-off contract until the test
environment or a narrow per-test flag stub is proven. The implementation phase must run two separate
cases: degraded mode off, where upstream-unavailable rejects before OTP verification and does not
advance attempts/state, and degraded mode on, where only the documented upstream-outage case is
accepted while missing/invalid challenges remain rejected. This is a test determinism finding, not a
decision to remove the accepted outage policy.

The app/com sign-in resend callsite audit found that every `SignInOtpResender.new` call now passes
an explicit `app` or `com` surface; the service rejects any other surface before delivery. The
purpose-specific mailer path allowlists `sign_up`/`sign_in` and falls back to the existing generic
subject, so caller text and OTP values do not become subject content. These observations were
checked with source search, Ruby syntax checks, targeted RuboCop and `git diff --check`; no Rails
assertion ran because the disposable PostgreSQL/Valkey prerequisite remains unproved.

`EmailPassCodeForm` owns the sign-in OTP and Turnstile token as controlled Inertia state and clears
both in `onFinish`, remounting the widget for every submission and resend. The signup OTP form is an
ordinary document POST with no OTP value prop; a new server render therefore has an empty field, but
this full browser round trip and single-use provider behavior remain unvalidated. The later
verification must assert the rendered DOM and cookie/session state after both an invalid code and a
failed challenge; the React suite alone cannot prove the Rails or provider boundary.

### Read-only continuation checkpoint — 2026-09-15

The source-input hash search still found neither supplied SHA-256 artifact for the original plan and
Sol review, so the attached text remains the authoritative requirement seed available to this run;
no missing P00–P17 wording was reconstructed. The current plan's mechanical audit reports 95 ledger
rows, 95 unique IDs, no missing IDs, all E0–E10 phase tokens, and `NO_GO` status. After this
checkpoint, `sha256sum refactor.md` was refreshed; any later handoff must use the hash calculated
after the final append.

### Bounded implementation slice — authorization-code replay owner binding (2026-09-15)

The source review found the same ownership-ordering defect in both layers of the authorization-code
consume path. `OidcTokenExchangeCoordinator#prevalidate_payload` revoked a consumed code's linked
RP/family before comparing the presenting redirect URI, client ID and PKCE state. The Valkey
`CONSUME_SCRIPT` returned `replay` before comparing its expected fields, so a direct consume result
could also be classified as replay before ownership mismatch. A wrong client could therefore reach
the family-revocation branch if it possessed a consumed code value. This was a source-confirmed
side-effect risk; no cross-client HTTP/Valkey reproduction was possible in the current environment.

The bounded implementation now:

- checks expiry, redirect URI, client ID, registered redirect, PKCE and scope before Ruby invokes
  replay-family revocation;
- moves the Lua expected-field loop ahead of the lifecycle-state replay branch (while retaining
  expiry handling first), so a consumed code with mismatched ownership fields returns `mismatch`;
- preserves same-owner, correctly bound replay rejection and does not remove family revocation for
  that intended replay case; and
- adds a Valkey integration regression test for a consumed code whose client field is mismatched.

Changed files: `app/services/oidc_token_exchange_coordinator.rb`,
`app/services/valkey/auth_state/authorization_code_store.rb`, and
`test/services/valkey/auth_state/authorization_code_store_test.rb`.

Static verification after this slice: all three files passed `ruby -c`, targeted RuboCop inspected
three files with no offenses, and `git diff --check` exited 0. The new Valkey test and the existing
same-owner replay/concurrency tests are **not executed** because no disposable Valkey namespace with
a reachable server has been proven. The remaining implementation gate is an isolated same-realm
client-A/client-B endpoint test that observes A's RP session, refresh family and Base session, B's
state, and unrelated sessions—not just an HTTP denial. E1 remains READY_WITH_PRECONDITIONS; this
slice does not resolve the separate link-family partial-failure or DPoP-after-consume decisions.

At the point of this read-only checkpoint, the ending worktree comparison still showed only the
preserved tracked Auth/OTP/mail/recovery changes and the previously untracked evidence/notes/memo
files plus this plan. That checkpoint itself changed no application source, migration, route,
configuration, ADR or test file and performed no checkout/reset/clean/stage/commit/database/Valkey/
provider/GitHub operation. The later bounded implementation slices are recorded below. Rails
behavior, Rails coverage, Valkey-backed OIDC/DPoP, provider round trips and browser/device
validation remain unexecuted under the same isolation gate.

### Bounded implementation slice — resend-surface isolation (2026-09-15)

The continuation found a concrete cross-surface defect in the existing dirty resend change. The
resender accepted `surface` and selected a surface-specific adapter, but its lookup still always
used `ClientEmail`. A corporate (`com`) resend therefore searched the app principal database/model;
the encrypted resend state also carried no surface, so an app state could be presented to the com
endpoint (or vice versa). This was a source-confirmed defect in `SignInOtpResender#issue_and_send!`
and `SignInOtpResendState`, not a claim based on a method name alone.

The bounded fix is now present in the working tree:

- `SignInOtpResendState` allowlists `app` and `com`, embeds the surface in its short-lived encrypted
  payload, and rejects missing/unknown surface data during parsing.
- `SignInOtpResender` binds the parsed state to the requested endpoint surface and selects
  `ClientEmail` for `app` or `VisitorEmail` for `com`; adapter delivery receives that same surface
  and the existing non-secret `sign_in` purpose.
- Both Auth sign-in controllers mint state with their own surface. The two resend endpoints already
  pass their own surface into the service, and the app endpoint test helper now mints the new state
  shape.
- The app service test continues to assert app model/adapter delivery. New public service tests
  assert corporate VisitorEmail delivery and reject an app state presented to the com service.

Changed by this slice: `app/services/sign_in_otp_resend_state.rb`,
`app/services/sign_in_otp_resender.rb`, the app/com sign-in controller call sites, the app resend
controller test helper, and `test/services/sign/in/otp_resend_service_test.rb`. No migration, route,
configuration, external service, database record, Valkey record, Git index, commit or GitHub state
was changed.

The test-first regression cases are written, but the RED/GREEN runtime result is **unverified**: the
repository has no proven disposable PostgreSQL and Valkey targets (`primary:5432` has no response
and no local server/binary is available), and the task forbids using the development database or an
unisolated service. The safe checks that did run after the slice were:

| command                                                    | result                         |
| ---------------------------------------------------------- | ------------------------------ |
| `ruby -c` on all nine touched Ruby/controller/test files   | exit 0; every file `Syntax OK` |
| `bundle exec rubocop --cache false` on the nine-file slice | exit 0; 9 files, no offenses   |
| `git diff --check`                                         | exit 0                         |

No claim is made that the new database-backed tests pass until they run against an explicitly
isolated test database and Valkey namespace. The shared occurrence rate-limit key remains unchanged;
cross-surface isolation in this slice is limited to the signed state, principal email model, and
delivery adapter, so a separate product decision is still required before changing rate-limit
sharing semantics.

This slice is **implemented but validation pending** and does not alter the complete-program
verdict: E7c remains READY_WITH_PRECONDITIONS, E0 remains BLOCKED_BY_ENVIRONMENT for a comparable
Rails baseline, and the full E0–E10 plan remains **NO_GO** for autonomous freeze/execution until the
recorded auth-time, replay/link, partial-failure, Auth admission, direct-entry decision, refresh
contract, and isolated-service gates are resolved.

The prior sentence in this checkpoint saying the continuation changed no application source/test
file describes the earlier read-only checkpoint only; this later bounded slice is the explicit
exception recorded here. The current worktree still preserves every pre-existing tracked and
untracked path and contains no checkout/reset/clean/stash/stage/commit or remote operation.

### Final static handoff check for these bounded slices (2026-09-15)

After the resend-surface and replay-owner slices, the repository-wide static checks were repeated.
`bin/rubocop --cache false` inspected 4,790 files and exited 0 with no offenses. The mechanical plan
audit reported 95 ledger rows, 95 unique IDs, no missing IDs, all 13 E0–E10 phase tokens, and
`NO_GO`. `git diff --check` exited 0. The final plan hash was calculated with
`sha256sum refactor.md`; the hash reported by the command is the handoff identifier for this file,
not a claim that the source implementation or Rails behavior is validated.

### Bounded implementation slice — required family-link success (2026-09-15)

The same exchange path also ignored the result of `link_family!` and swallowed selected Valkey
exceptions before returning a successful token response. That contradicted the fail-closed exchange
boundary: a consumed authorization code must not produce credentials when the tombstone cannot be
linked to the newly created RP usage/family.

`OidcTokenExchangeCoordinator#link_consumed_family!` now requires an explicit `:linked` result.
`missing`, `invalid_state`, `nil` and other non-linked results raise the existing Valkey operation
error, and selected Valkey failures are logged without secrets and re-raised. The outer public
`call` therefore returns `server_error`; the PostgreSQL transaction rolls back its usage/refresh
changes, while the already-consumed code remains consumed and is never reopened. A public
coordinator regression test injects a `missing` link result and asserts no token response plus the
irreversible consumed state.

Changed files: `app/services/oidc_token_exchange_coordinator.rb` and
`test/services/oidc/token_exchange_service_test.rb`. Static verification after the change was
`ruby -c` for both files, targeted RuboCop with no offenses, and `git diff --check`, all exit 0. The
injected public test and the real Valkey/DB transaction behavior remain **unexecuted** until
isolated services are available. Unknown-outcome timeout and post-link/commit/response-loss
compensation are still separate E1 acceptance cases; this change does not claim distributed
transactionality or automatic repair.

The replay revocation helper was also tightened in the same slice: it now requires the payload's
client ID and redirect URI to match the presenting request, the registered redirect to remain valid
for the payload realm, and PKCE verification to succeed before it can revoke a linked family. This
is defense in depth for races or a nonstandard code-store implementation; it preserves revocation
for a correctly bound same-owner replay and does not add an Access-JWT per-request database lookup.

### Final static handoff check after family-link slice (2026-09-15)

The repository-wide static checks were rerun after the replay-owner and family-link changes. The
results are:

- `bin/rubocop --cache false`: exit 0; 4,790 files inspected; no offenses.
- `ruby -c` on the modified authorization-code coordinator, Valkey store, and their two tests: exit
  0 for every file (`Syntax OK`).
- `git diff --check`: exit 0.
- `bundle exec erb_lint --lint-all`: exit 0; 599 files linted with no errors (the existing Ruby 3.3
  parser-on-Ruby-4.0 warning remains informational).
- Brakeman 8.0.6 run through the vendored gem with its cache redirected to `/tmp`: exit 0; 86
  checks, 0 errors and 0 security warnings. The repository wrapper's forced latest check could not
  write `/home/global/.cache/gem` in this sandbox; the direct vendored run is the successful scan.
- The read-only plan audit still reports 95 ledger rows, 95 unique IDs, no missing IDs, all E0–E10
  phase references defined, and `NO_GO` for the complete autonomous program.

These are static and repository-local results. The new Valkey/DB-backed regression tests, Rails
behavior, coverage gates, and cross-store failure-injection cases remain unexecuted because an
isolated PostgreSQL and Valkey target is still unavailable. The final SHA-256 of this file must be
calculated after this append and reported with the handoff; it is an artifact identifier, not an
implementation or runtime-validation claim.

### Bounded implementation slice — DPoP proof before authorization-code consume (2026-09-15)

The token exchange path previously consumed the authorization code in the Valkey store and only then
validated the optional DPoP proof. A malformed or wrong-binding proof could therefore make a valid
code irreversibly unusable before the client had a chance to correct the proof. This was a
source-confirmed ordering defect; the actual endpoint behavior remains unexecuted without Valkey.

The bounded change validates the existing RFC 9449 proof contract after code ownership/PKCE/scope
prevalidation and before the atomic code consume. A valid proof is checked once, its JKT is passed
into token construction, and it is not rechecked after consume (which would incorrectly classify the
same proof JTI as a replay). Invalid proof requests return the existing `invalid_request` result
while leaving the code issued. Existing code replay, PKCE and family-link protections are unchanged.
No nonce requirement, Bearer policy, or device validation policy was invented here; nonce adoption
remains optional under RFC 9449 §8 and is still a separate E5 contract decision.

Changed files: `app/services/oidc_token_exchange_coordinator.rb` and
`test/services/oidc/token_exchange_service_test.rb`. The public tests for wrong `htm` and wrong
`htu` now assert the code remains unconsumed. Static syntax checks, targeted RuboCop and diff checks
pass. The Rails/Valkey tests, DPoP nonce/error-header endpoint checks, and real-client
interoperability checks remain pending under the same isolation gate; E5 remains
READY_WITH_PRECONDITIONS/DEFERRED_VALIDATION rather than validated.

### Final static handoff check after DPoP slice (2026-09-15)

The repository-wide static checks were completed again after the DPoP ordering change:

- `bin/rubocop --cache false`: exit 0; 4,790 files inspected; no offenses.
- `ruby -c` on the changed authorization-code coordinator, Valkey store, and their tests: exit 0 for
  every file (`Syntax OK`).
- `git diff --check`: exit 0.
- The plan audit remains 95 ledger rows, 95 unique IDs, no missing IDs, all E0–E10 phase tokens
  defined, and `NO_GO` for autonomous full-program execution.

The static result does not convert the plan to GO. Rails assertions, Valkey/DB-backed regression
tests, coverage-gate execution, public endpoint reproduction, OIDC `auth_time`/`max_age` runtime
checks, Auth admission checks, and physical DPoP/DBSC client validation remain pending because the
required isolated services, unresolved authority/UX decisions, and representative hardware are not
available in this run. No GitHub, database, migration, route, configuration, ADR, or test-suite
write was performed for those pending items.

### Bounded verification slice — sign-in Turnstile does not consume OTP attempts (2026-09-15)

The app and com sign-in controller regression tests now snapshot `otp_attempts_count` before a
valid-code submission with missing/invalid Turnstile, and assert that the count is unchanged after
both rejected requests. This complements the existing assertions for unchanged OTP expiry, session
state, token count, empty authentication cookies, and 422 Turnstile feedback. The assertions use the
public controller boundary; no private method or test-only production branch was introduced.

`ruby -c` for both tests, targeted RuboCop, and `git diff --check` exit 0. The Rails tests remain
unexecuted because PostgreSQL at `primary:5432` is unreachable and no disposable PostgreSQL/Valkey
pair has been proven. Therefore this is a test specification strengthening, not runtime validation;
the E7c and E0 statuses remain unchanged.

### Bounded implementation slice — fresh signup OTP challenge identity (2026-09-15)

Signup email OTP pages now receive a server-generated per-render `challenge_id` in their visible
Turnstile props. `OtpVerificationForm` uses that identity as the widget key, so a 422/error rerender
that receives a new page payload unmounts the old widget and creates a fresh challenge. The ordinary
signup email-entry widget is unchanged; no Turnstile secret, token value, authentication state or
provider policy crosses the boundary.

Changed files: `app/controllers/concerns/turnstile_page_props.rb`, the app/com signup email
controller props, `src/features/turnstile/TurnstileWidget.tsx`,
`src/features/auth/signup/OtpVerificationForm.tsx`, and the corresponding Rails/React tests.
`bun --bun vitest run spec/features/auth/auth_com_signup_screens.test.tsx spec/features/turnstile/turnstile_widget.test.tsx --maxWorkers=1 --fileParallelism=false`
passed (2 files, 32 tests); targeted Ruby syntax/RuboCop and frontend format/lint also passed. The
Rails prop assertions remain unexecuted because E0 still lacks an isolated PostgreSQL/Valkey target.

The broader `bun run test -- --maxWorkers=1 --fileParallelism=false` then passed with 85 files and
1,055 tests. This is ordinary Vitest evidence only; the canonical coverage command remains a
separate failing gate as recorded earlier and no coverage threshold or exclusion was changed.

### Bounded implementation slice — preserve explicit OIDC authentication time (2026-09-15)

`OidcTokenExchangeCoordinator::ConsumedCode` now carries the payload's explicit `auth_time` under
that name; it no longer exposes a `created_at` alias or falls back to `issued_at`. A public
token-exchange regression test plants an authorization code whose authentication event precedes code
issuance and asserts that both the Access JWT and ID Token retain the earlier event timestamp. The
test also asserts that the claim is earlier than the code issuance instant; it does not inspect a
private helper.

Changed files: `app/services/oidc_token_exchange_coordinator.rb` and
`test/services/oidc/token_exchange_service_test.rb`. Syntax, targeted RuboCop and diff checks pass.
The test remains unexecuted without isolated PostgreSQL/Valkey. This fixes downstream precedence
when a trustworthy event value is present; it does **not** claim that the current code issuer's
`Time.current` is a valid authentication-event source. The E3 auth-event source, SSO/direct-login
coverage, refresh preservation, and OIDC `prompt`/`max_age` gates remain open.

### Verification update — 2026-09-15 (latest continuation)

The latest repository-local checks completed after the OIDC precedence and signup challenge slices:

- `bundle exec rubocop --cache false`: exit 0; 4,790 files inspected, no offenses.
- `git diff --check`: exit 0.
- `bun run format:check`: exit 0; 571 files checked.
- `bun run lint`: exit 0.
- `bun run typecheck:verify && bun run typecheck`: exit 0.
- `bun run test -- --maxWorkers=1 --fileParallelism=false`: exit 0; 85 files and 1,055 tests passed.

These checks do not establish Rails behavior, SimpleCov coverage, Valkey atomicity, provider
verification, or public OIDC claim semantics. The latest Rails and Valkey-backed tests were not run
because `primary:5432` is unreachable and no disposable PostgreSQL/Valkey pair has been proven. The
canonical coverage command and `bin/ci` therefore remain pending under E0 rather than being
represented as successful. The full plan remains **NO_GO**.

The read-only Rails inventories were then retried with the process-only environment
`RUBY_DEBUG_LAZY=1` after the default boot attempted to bind the debugger UNIX socket and failed
with `Errno::EPERM` (no application setting was changed). `RUBY_DEBUG_LAZY=1 bin/rails routes`
exited 0 and emitted the route table; `RUBY_DEBUG_LAZY=1 bin/rails notes` exited 0 and reported the
existing TODO/FIXME set in `actor_support`, `preference_transport`, outage/emergency services and
migration history. These are route/notes inventories only: no request, database connection, Valkey
operation or external service call was performed. The initial default-environment failures are
recorded as a debugger-process restriction, not as application behavior.

An isolated-attempt Rails test was then run with the same safe debugger override:
`RUBY_DEBUG_LAZY=1 bin/rails test test/services/oidc/token_exchange_service_test.rb` exited 1 before
any test assertion. Active Record could not resolve PostgreSQL host `primary` while checking the
test schema (`ActiveRecord::DatabaseConnectionError` / `PG::ConnectionBad`). No migration, fixture,
Valkey command, provider call or application request was reached. This is the current environment
blocker for all Rails-backed evidence, not a test failure attributed to the changed implementation.

The final static/security pass also completed: `bundle exec erb_lint --lint-all` exited 0 with no
ERB errors across 599 files (the existing Ruby 3.3 parser warning under Ruby 4.0.6 remains), and the
vendored Brakeman 8.0.6 scan with its cache redirected to `/tmp/umaxica-bundle-cache` exited 0 with
86 checks, zero errors and zero security warnings. These results do not lift the Rails service or
public-boundary gates.

### Bounded implementation slice — reject authorization codes without an authentication event time (2026-09-15)

The token-exchange boundary now rejects an authorization-code payload whose `auth_time` is missing
or cannot be parsed, before one-time consumption or replay-family revocation. The exchanged-token
path no longer substitutes authorization-code issuance time or the exchange clock for this value; it
uses only the explicit parsed authentication-event time. A public regression test asserts the
`invalid_grant` response, the exact failure description, and that the authorization code remains
unconsumed when `auth_time` is absent. No database column, migration, API route, or token lifetime
was added or changed.

This is a fail-closed boundary guard, not a resolution of the upstream authority problem. The
current authorization-code issuer still supplies `Time.current`, and the authentication ceremony
does not yet provide a durable, authoritative Base authentication-event timestamp through every
initial-login, SSO, reauthentication, step-up, and refresh path. Those source/propagation decisions
remain E3 work and keep the complete 95-requirement implementation plan at **NO_GO**. The new Rails
regression test was not executed because `primary:5432` is unreachable; Ruby syntax, targeted
RuboCop, and `git diff --check` passed.

### Environment checkpoint — localhost isolation probe (2026-09-15)

The configured test dependencies still point at the shared-service names `primary` (PostgreSQL) and
`valkey` (Valkey). Read-only readiness probes for `127.0.0.1:5432` and `localhost:5432` also
reported no response; no Redis/Valkey connection was attempted. No PostgreSQL/Valkey binaries,
container runtime, or permitted network namespace were available to create an isolated disposable
pair. This keeps E0's Rails request/service/coverage gates blocked by environment rather than by a
new test result. All currently modified Ruby files pass `ruby -c`, and the full
`bundle exec rubocop --cache false` pass completed without reported offenses; no worktree file was
generated by those checks.

### Bounded implementation slice — fail closed after post-consume token-issuance failure (2026-09-15)

`OidcTokenExchangeCoordinator` now treats a blank required Access Token, ID Token, or refresh-token
result as an explicit token-issuance failure. The failure is raised inside the existing database
transaction after the authorization code has been atomically consumed, then converted to a fixed
`server_error` response. This rolls back RP Session/connection writes without returning a partial
success and leaves the consumed code unavailable for unconditional retry. A public regression test
stubs the access-token encoder, asserts the fixed error and nil response, verifies no RP Session was
committed, and confirms the Valkey tombstone remains `consumed`.

No immediate Access JWT revocation, per-request session lookup, new store, migration, or external
protocol change was introduced. The test is not executable until isolated PostgreSQL and Valkey are
available; syntax, targeted RuboCop, and diff checks pass. Failure injection for link timeouts,
unknown link outcomes, DB commit errors, and response loss remains E1 acceptance work.

The full `bundle exec rubocop --cache false` was rerun after this slice with exit 0 (`4,790` files,
no offenses). This is static evidence only; the new public regression remains pending until the
Rails/Valkey isolation gate is satisfied.

### Bounded implementation slice — post-consume token output integrity (2026-09-15)

The continuation added one additional E1 guard: after code consumption, the existing transaction now
requires nonblank Access Token, ID Token, and refresh-token outputs before it can return success. If
any required output is blank, an explicit `TokenIssuanceError` rolls back the RP Session and
connection writes, returns a fixed `server_error`, and leaves the Valkey code tombstone consumed.
The public regression stubs the Access Token encoder and checks all three observable outcomes. This
does not change the accepted short-lived JWT revocation policy, add request-time DB lookups, or add
a migration. The test is written but not run because E0 service isolation is still unavailable.

Post-change evidence: all 37 modified Ruby files passed `ruby -c`, the full RuboCop run inspected
4,790 files with exit 0 and no offenses, and `git diff --check` passed. E1's remaining failure
injection cases (link timeout/unknown outcome, DB commit failure, and response loss) are still
pending and are not implied by this slice.

### Static adversarial checkpoint — latest continuation (2026-09-15)

The latest read-only source pass rechecked the two remaining authentication-time substitutions and
the replay/link/DPoP ordering after the bounded slices.
`app/operations/oidc_authorization_code_issuer.rb` still supplies `auth_time: Time.current`;
`OidcTokenExchangeCoordinator` now consumes only the explicit payload `auth_time` and rejects a
missing value before Valkey consumption. No upstream Base-accepted authentication-event source has
been established, so this is a downstream guard, not an end-to-end `auth_time` fix. The inspected
Base transaction and RP builder still do not carry or enforce `prompt`/`max_age`; this remains E3
protocol work and is not treated as implemented.

The same pass confirmed that Ruby prevalidation and the Lua consume script compare ownership fields
before replay classification, DPoP proof validation occurs before one-time consumption, and family
link results must be explicitly `:linked`. This is static ordering evidence only. It does not prove
that PostgreSQL/Valkey race outcomes, revocation failures, ambiguous link timeouts, or DPoP endpoint
error headers are safe. The later bounded slice now converts an exception from
`revoke_linked_family!` into an explicit fail-closed `server_error`; an isolated failure-injection
run is still required to verify the public response and affected RP Session state. No further
replay-cleanup conclusion is claimed without isolated services.

Read-only commands for this checkpoint completed with exit 0: `ruby -c` on every currently modified
Ruby file, `git diff --check`, and the repository-wide static checks recorded above. No PostgreSQL,
Valkey, provider, browser/device, Rails request, Rails assertion, coverage gate, or `bin/ci` run was
performed. The complete E0–E10 program remains **NO_GO**; the bounded slices remain **implemented
but validation pending**. Worktree paths and user changes remain preserved.

### Bounded implementation slice — fail closed on replay-revocation failure (2026-09-15)

The replay path previously rescued every database/revocation exception, logged a warning, and still
returned the ordinary `invalid_grant` replay result. That response did not establish that the linked
RP Session or refresh family had actually been revoked. The coordinator now converts a revocation
exception into a fixed `server_error` (`authorization code replay revocation failed`) and never
presents the failure as a completed replay cleanup. Normal same-owner replay with a successful
revocation remains `invalid_grant`, and the owner checks added earlier remain in force.

A public coordinator test injects a consumed, owner-matched code and a revoker connection failure;
it asserts the sanitized server error, no token response, and the consumed code state. The test is
written but cannot reach assertions until PostgreSQL and Valkey are isolated. `ruby -c`, targeted
RuboCop and `git diff --check` passed after the slice. This change does not add retries, restore a
consumed code, revoke unrelated RP Sessions, or change the accepted short-lived Access JWT policy.

### Bounded implementation slice — preserve replay cleanup when a legacy consumed code lacks `auth_time` (2026-09-15)

The replay branch now runs after the code's client, redirect URI, registered-redirect, PKCE, and
scope ownership checks but before the required authentication-event-time check. This preserves
same-owner replay-family cleanup for a consumed payload produced before `auth_time` became a
required field, while an issued code that lacks a parseable `auth_time` still fails closed before
one-time consumption. The owner-boundary ordering remains unchanged: a mismatched client, redirect,
or verifier cannot trigger linked-family revocation.

Only `app/services/oidc_token_exchange_coordinator.rb` changed in this slice. Syntax, targeted
RuboCop, and `git diff --check` passed. The new behavior remains unexecuted against real Valkey and
PostgreSQL because the isolated-service gate is still unavailable.

### Auth-time source checkpoint — no safe upstream substitution found (2026-09-15)

The current transaction model does persist `authenticated_at` when Base registers an OIDC result,
but the authorization-code issuer does not receive that value. The normal issuer still writes
`auth_time: Time.current`; login token rows expose session creation/refresh metadata rather than a
durable authentication-event timestamp, and current access-token claims are not a complete source
for every initial-login, SSO, reauthentication, step-up, and refresh path. The Base resumed-flow
controllers also call the shared issuer without passing `transaction.authenticated_at`.

No code change was made to replace this with transaction `created_at`, token `created_at`, JWT
`iat`, or the exchange clock. Such substitutions would violate the distinction between
authentication event time, session start, authorization-code issuance, and token issuance. E3
therefore remains blocked on an authority/schema decision: define the authoritative Base-accepted
event source and propagate it through all issuance paths, including direct current-session
authorization, before changing the issuer contract. `prompt`/`max_age` handling remains part of the
same pending audit.

The replay-order slice also adds a public regression for a consumed same-owner payload without
`auth_time`: it must still perform the owner-bound family cleanup and return the normal replay
`invalid_grant`, while an issued code without `auth_time` remains rejected before consumption. The
regression is written but blocked at the same PostgreSQL/Valkey isolation gate.

Post-change static verification for this continuation: `ruby -c` passed for the coordinator and
token-exchange test, targeted RuboCop inspected both files with no offenses, and `git diff --check`
passed. A final `bundle exec rubocop --cache false` also exited 0 after inspecting 4,790 files with
no offenses. The final handoff hash is calculated after the last append and reported with the
delivery.

### Bounded implementation slice — preserve an explicit auth-time forwarding seam (2026-09-15)

`AuthenticationToken` now accepts and forwards an optional explicit `auth_time` to the existing
`AuthenticationTokenService`/codec chain. No timestamp is generated, inferred, persisted or
substituted by this slice; all current callers retain their previous behavior. A public token
boundary regression asserts that an explicitly supplied instant survives into the decoded claim. The
real authentication-event source and every login/refresh caller remain unresolved E3 work.

Changed files: `app/controllers/concerns/authentication_token.rb` and
`test/values/security_jwt_access_token_negative_cases_test.rb`. Syntax, targeted RuboCop and
`git diff --check` passed; the test is blocked by the same unavailable PostgreSQL/Valkey target. The
repository-wide `bundle exec rubocop --cache false` was rerun afterward: 4,790 files, exit 0, no
offenses.

### Auth-time propagation re-audit — current source call graph (2026-09-15)

The additional source trace confirms that the unresolved value is upstream of the bounded exchange
guard; the exchange cannot manufacture the missing event time safely.

| Operation                                  | Current source path                                                                                                                                                                         | Time currently available at the boundary                                                                                                                                                                                                                        | Current disposition                                                                                                                                                                                                                                              |
| ------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| RP-originated sign-in/sign-up result       | `BaseAuthAdmissionCoordinator#register_result_and_issue_resume!` → `OidcAuthorizationTransactionCoordinator#register_result!` → `OidcAuthorizationTransactionable#register_authentication!` | `transaction.authenticated_at` is stored using the registration `now`; `Base::{App,Com,Org}::Oauth::AuthorizationsController#resume_authorization!` later calls `issue_authorization_code!` with `transaction.authorize_params`, which omits `authenticated_at` | Source gap confirmed. The future change must establish whether registration `now` is the accepted authentication event, then explicitly carry it through transaction resume and code issuance. No `created_at`, `iat` or exchange clock substitution is allowed. |
| Already-authenticated direct authorization | `Base::{App,Com,Org}::Oauth::AuthorizationsController#show` → `#issue_authorization_code!` → `OidcAuthorizeCoordinator#call` → `OidcAuthorizationCodeIssuer#call`                           | The controller passes current `Actor.authn` `amr`/`acr` and `current_session`, but no authentication-event timestamp; the issuer currently writes `auth_time: Time.current`                                                                                     | Source gap confirmed. A separate authority decision is needed for an existing Base session's last accepted authentication event before this path can become compliant.                                                                                           |
| Access JWT first issue / reissue           | `AuthenticationJwtTokens#encode_login_access_token` and `#reissue_access_token!` → `AuthenticationToken` → `SecurityJwtAuthAccessTokenCodec`                                                | Token records expose session/persistence and step-up fields, but no durable general authentication-event field; the current callers do not pass `auth_time`                                                                                                     | No safe source found. The forwarding seam exists, but caller changes are deferred to the authority/schema phase.                                                                                                                                                 |
| OIDC ID/Access exchange                    | `OidcTokenExchangeCoordinator#issue_exchanged_token_result` → `encode_exchanged_access_token` / `encode_exchanged_id_token`                                                                 | The bounded code now accepts only parsed payload `auth_time`; missing or invalid values fail before one-time consume                                                                                                                                            | Bounded fail-closed behavior is source-confirmed; public claim behavior is unexecuted because services are unavailable.                                                                                                                                          |
| OIDC refresh operation                     | `OidcRefreshTokenIssuer#call` rotates the RP usage record and updates connection `last_used_at`; no production caller was found for this operation under `app/`                             | No refreshed ID/Access claim is built in this operation                                                                                                                                                                                                         | Public refresh-grant ownership and claim-preservation contract remain unresolved. Do not add a grant endpoint or reinterpret `last_used_at` as authentication time.                                                                                              |
| `max_age` / `prompt`                       | `OidcSsoInitiator#oidc_authorization_url`, all three Base OAuth `#authorize_params`, transaction `#authorize_params`, and `OidcIdTokenVerifier#call`                                        | The inspected builders/allowlists/transaction serialization omit `max_age` and `prompt`; the verifier has no expected freshness input                                                                                                                           | Source-level OIDC freshness gap remains accepted as a planning finding, not dynamically reproduced. The implementation phase must trace alternate middleware before changing the contract.                                                                       |

This table is static evidence at HEAD `430ac354ba06c9d22885e1e69d027a7a1b1d5280`; it does not prove
a public endpoint exploit or a complete absence of alternate paths. The required dynamic matrix
remains T0(authentication event) < T1(code issue) < T2(exchange), plus reauthentication, `max_age`,
`prompt=login`, `prompt=none`, and refresh, with ID Token `auth_time` checked against the accepted
event and JWT `iat` checked independently.

The continuation also removed the internal `ConsumedCode#created_at` alias so the exchange source
does not name an authentication event as an Active Record persistence timestamp. The exchange now
reads `authorization_code.auth_time` directly. This is a naming/invariant clarification only; it
does not supply the missing upstream event source. Targeted RuboCop for the coordinator and its
public token-exchange test passed after this edit, and `git diff --check` passed.

### Auth surface comparison — inherited guards still require runtime proof (2026-09-15)

The three Auth application controllers are not identical, and the app-only leaf observation must not
be generalized without tracing each surface. Static comparison found:

- App, Com and Org selector controllers (`Auth::{App,Com,Org}::Sign::InsController` and
  `Sign::UpsController`) include `AuthCeremonyAdmission` and call `admit_or_render_sign_ceremony!`
  before rendering their method selection.
- App and Com email sign-in controllers, and the App/Com email sign-up controllers, inherit their
  surface application callbacks and use `AUTHENTICATION_MODE = :guest`; they do not include the
  selector's `AuthCeremonyAdmission` module themselves. Their successful OTP paths call
  `AuthenticationSessionCommitter`, which delegates to
  `AuthenticationBase#establish_signed_in_session!`. The inherited application callbacks include
  `enforce_sign_in_selector_gate!`, `enforce_verification_if_required` and `enforce_access_policy!`,
  but static presence of those callbacks is not proof that a missing or malformed Base admission
  cannot reach the leaf action.
- Org has no parallel email sign-in controller in the inspected tree. Its normal entry is Entra
  (`auth/org/sign/in/...`) with separate passkey/secret second-stage controllers, plus an explicit
  Emergency passkey flow. Those paths must be tested independently; an app/com email result cannot
  stand in for Org admission evidence.
- When an Auth application controller has `session[:oidc_authorization_login_challenge]`, its
  `oidc_authorization_after_login_path` calls
  `BaseAuthAdmissionCoordinator.register_result_and_issue_resume!`; without that challenge, the
  current surface-specific `after_login_path` redirects to the Base root. This is the current source
  behavior, not a decision that direct-entry UX is correct.

The required E2 dynamic matrix therefore remains per surface and per ceremony: no admission, valid
admission, expired/replayed admission, purpose/actor/surface/realm mismatch, and direct entry.
Observe Auth ceremony cookies, Auth-side token/cookie writes, Base result acceptance and the final
session/RP state. No runtime claim is added by this static comparison.

### OTP delivery and Turnstile source checkpoint — current worktree (2026-09-15)

The current source pass rechecked the bounded email OTP changes without treating the dirty test
files as a green Rails result. `SignOtpCeremony#deliver!` and
`SignEmailRegistrable#send_verification_email` pass the purpose explicitly; the app/com sign-in
controllers and `SignInOtpResender` pass `:sign_in`; the app/com sign-up paths pass `:sign_up`.
`OtpEmailAdapter` converts the purpose to a string for the mailer, while each Noticed notifier keeps
the same purpose in its delivery params. The app/com mailers allow only `sign_up` and `sign_in`
subject keys and fall back to the existing generic subject; the OTP remains encrypted before
adapter/notifier delivery and is not used in the subject. This is source evidence for purpose
propagation and secret separation, not mailer execution evidence.

The sign-in and sign-up OTP controllers call `cloudflare_turnstile_validation` before assigning or
validating the submitted code. The shared `CloudflareTurnstile` concern applies
`TurnstileDegradation` only to an explicitly marked upstream-unavailable result; missing or invalid
challenge responses remain failures unless an operator has enabled the documented degraded-mode
suspension flag. The visible React OTP widgets clear their token and remount on the server-generated
challenge identity; `EmailPassCodeForm` clears the code and token in Inertia's `onFinish`, including
a 422 response, and on a successful resend. The source tests cover the component callback and the
standalone degradation policy. Controller tests still need an isolated Rails run with the flag state
and provider stub pinned explicitly; no public OTP attempt, session, or flow transition was
dynamically observed in this continuation.

`SignInOtpResendState` now binds the encrypted state to `app` or `com`, and the resender selects the
corresponding `ClientEmail` or `VisitorEmail` model and adapter. Static call-site search found all
current constructors and issuers updated to supply the surface. A signed state minted before the
surface field existed is intentionally rejected, which requires a fresh sign-in ceremony after
deployment; this migration behavior must be accepted or versioned before release rather than
silently falling back to the app model.

### Worktree drift checkpoint — 2026-09-15

After the previous continuation checkpoint, the working tree also contains uncommitted changes to
`.env.example`, `.env.devcontainer.example`, and `config/credentials/development.yml.enc`. Their
contents were not overwritten, staged, reset, cleaned, decrypted, or used to establish service
connectivity. They are treated as user-owned changes and are excluded from attribution for the
bounded slices above. The current environment still cannot resolve the configured PostgreSQL host or
reach Valkey, so these files do not constitute proof of an isolated test target.

The complete current dirty-file inventory also includes `config/application.rb`,
`config/environments/development.rb`, `config/initializers/blazer.rb`,
`config/initializers/pghero.rb`, and `config/routes/{blazer,pghero}.rb`. Their diffs add
development-only Blazer/PGHero requires, engine middleware, route mounts, and queue-role
configuration and were not authored, normalized, reverted, or used by this continuation. They remain
user-owned/out-of-scope. In particular, the full RuboCop failure at `config/routes/pghero.rb:6` is
attached to a file already dirty in the current worktree; it is not attributed to the E9 presenter
slice and is not repaired by changing that route.

### Route/OpenAPI static checkpoint — 2026-09-15

`RUBY_DEBUG_LAZY=1 bin/rails routes` completed successfully in the read-only route inspection
environment. The captured output contains 1,461 lines and, after route-line classification, 203
`/api/v0` occurrences, 124 `/web/v0` occurrences, and 51 `/edge/v0` occurrences. This is a route
declaration inventory, not proof that each endpoint is reachable through its intended host or that
its response is JSON.

The remaining legacy declarations are distributed across Base, Auth, and Side. They include
preference resources, token checks/refresh/DBSC endpoints, and Auth email OTP paths. Core already
has `/api/v0/preferences/...` public paths, but several declarations still dispatch to historical
`core/*/web/v0` and `core/*/edge/v0` controller namespaces through explicit `to:` or `controller:`
options. The latter is a confirmed naming/ownership mismatch candidate; it is not changed during
this plan-only audit because the client contract, controller semantics, and OpenAPI source must be
verified together.

`test/contracts/openapi_route_coverage_test.rb` currently treats `/api/v0` and `/health` as the
described scope, excludes `/web/v0` and `/edge/v0` as deferred by the route-vocabulary ADR, and
exempts only `/api/v0/preferences/dbsc` as an external DBSC wire protocol. It derives surface
ownership from route names/controller paths and loads only the existing `app`, `com`, and `org`
OpenAPI bundles. The test comments still state that `net` and `dev` are internal-only, while the
route inventory includes a public `guid_net_api_v0_resource` declaration at
`/api/v0/resources/:guid` and separate `net`/`dev` operational routes. The public GUID response, its
storage owner, and whether a `net` OpenAPI document is architecturally required remain unresolved.
No broad exemption or FIXME is accepted as closure.

The E8/E9 implementation phase must therefore proceed in this order: (1) classify each legacy route
from controller, caller, protocol, and host evidence; (2) migrate only application-owned routes
whose external contract is clear, relocating controllers and OpenAPI source together; (3) retain
documented protocol/public-path exceptions; (4) make the coverage harness discover every real owning
service, including Edit and GUID if the architecture confirms them; and (5) regenerate bundles and
run Committee/coverage tests in an isolated Rails environment. Until PostgreSQL, Valkey, and
provider egress isolation are proven, these remain static findings and planned acceptance criteria
rather than validated migrations.

Read-only JavaScript/OpenAPI checks after this checkpoint: `bun run openapi:lint` exited 0 for
`openapi/app.yml`, `openapi/com.yml`, and `openapi/org.yml`; `bun run deadcode` exited 0 with only
the existing Knip configuration hints for `@inertiajs/core` and the compiled `.css` extension. These
checks do not prove route coverage, request/response behavior, or generated-bundle freshness;
`openapi:bundle`/`openapi:verify` were not run because they write committed bundle files and the
current audit is preserving the dirty worktree.

A read-only comparison of the captured route table with the three committed OpenAPI bundles,
normalizing Rails `:param` to OpenAPI `{param}` and applying the harness's DBSC exemption, found no
static `/api/v0` operation mismatch for `app`, `com`, or `org` (12, 11, and 11 operations
respectively after surface ownership filtering). This does not replace the Minitest coverage
contract: it cannot verify route-name discovery, host dispatch, content types, status/error schemas,
or generated bundle determinism. It also confirms why the public `guid_net_api_v0_resource` route
remains outside that comparison: it is owned by the `net` surface, for which no committed OpenAPI
bundle exists. The route's public JSON contract and `net` ownership decision remain open.

### Bounded E9 timestamp invariant slice — 2026-09-15

The Chronicle tables declare `occurred_at` as a required event timestamp. Four user-facing activity
presenters nevertheless used `created_at` when `occurred_at` was absent, giving persistence metadata
business meaning. A temporary harness reproduced the old behavior (the old app presenter returned
`created_at`) and verified the current behavior after the change (missing `occurred_at` remains
nil). The app/com/org presenter tests now assert that persistence metadata is not used; the Base
presenter has the same negative contract. The production change is limited to the four presenter
accessors; it does not alter schema or event writes. Ruby syntax checks and targeted RuboCop passed
for all eight changed files. Rails presenter tests remain unrun because the isolated PostgreSQL
target is still unavailable, so this slice is implemented with runtime validation pending and does
not change E9's overall readiness.

The subsequent full `bundle exec rubocop --cache false` run (4,790 files) exited 1 on the
pre-existing, out-of-scope `config/routes/pghero.rb:6` `Layout/LineLength` offense (`135/120`). The
four presenter files and four presenter tests changed in the bounded E9 slice pass targeted RuboCop.
The PGHero route was not edited or attributed to this work; full static quality remains a baseline
failure until that independent issue is repaired or its ownership is explicitly resolved.

### Bounded E7b cookie-scope audit — 2026-09-15

The normal authentication cookie writer and deleter use the same `AuthenticationCookieService`. Both
`AuthenticationCookieStore#set_auth_cookies` and `#clear_auth_cookies!` resolve names through
`AuthenticationCookieName` and derive options from `CoreCookieOptions`; issuance and deletion both
use `path: "/"`, host-only `domain: false`, `SameSite=Strict`, the request/environment secure
decision, and the production partitioning flag. The deletion helper intentionally removes only
expiry and `httponly`, which are not required to identify the stored cookie. The normal logout
ensure path and the OIDC logout path invoke the shared clear operation for both access and refresh
cookies. Source inspection found no name/domain/path mismatch to repair in this layer.

This is not browser-jar proof: a real response `Set-Cookie`/cookie-jar test across app/com/org still
requires an isolated Rails request target. The direct refresh-cookie delete in the coordinated Auth
sign-out continuation is redundant but is followed by the shared scoped deletion; it is not changed
in this audit because the cross-host ceremony and its response ordering remain unexecuted. E7b
therefore remains READY_WITH_PRECONDITIONS rather than completed.

The three cookie/logout concerns passed `ruby -c`; targeted RuboCop inspected those concerns and
`test/controllers/concerns/authentication/cookie_service_test.rb` with no offenses, and
`git diff --check` exited 0. No Rails cookie-jar test was counted as executed.

### Auth admission coverage recheck — 2026-09-15

Static enumeration confirms that `AuthCeremonyAdmission` is included only by the six app/com/org
`Sign::InsController` and `Sign::UpsController` selectors. The leaf email, telephone, passkey,
secret, checkpoint and callback controllers inherit the surface application callbacks but do not
include that concern themselves. The selectors do bridge unauthenticated direct entry to the Base
authority and redeem the opaque admission, but source alone does not prove that a direct leaf POST
cannot reach `AuthenticationSessionCommitter` without an admitted transaction. This finding is kept
as a boundary-test requirement, not declared a bypass: adding a guard to every leaf would also
change the unresolved direct-entry UX and must follow the E2 admission decision plus valid
selector-to-leaf flow tests. No controller was changed in this recheck.

### Missing source-artifact search — 2026-09-15

A read-only Git object scan compared the supplied SHA-256 values for the original plan
(`2ae07102f486fd13c64fc45acfca65b990cc438db1098610dcb09415b52a92c8`) and Sol review
(`3052638bea18ef029798632f068402333638eeacd222de23bad1af05e91b8533`) against the repository's large
Git blobs. Neither digest was present. Three unreachable blobs contain earlier integrated plan
drafts with overlapping `REQ-*` text, but none has either supplied digest and none is treated as the
missing source artifact. The exact P00–P17 prose therefore remains unavailable; no wording was
reconstructed from those drafts. This preserves the source-completeness blocker rather than silently
upgrading a secondary draft into authoritative requirements.

### Revalidation of bounded frontend/static checks — 2026-09-15

After the latest plan append, `bun run test -- --maxWorkers=1 --fileParallelism=false` completed
with 85 files and 1,055 tests passing. `bun run format:check`, `bun run lint`,
`bun run typecheck:verify`, and `bun run typecheck` all exited 0. Targeted RuboCop over the four E9
presenters and four presenter tests inspected eight files with no offenses, and `git diff --check`
exited 0. These checks do not replace the blocked Rails/Valkey/provider runtime baseline or the
unexecuted browser/device validations, so the complete E0–E10 verdict remains NO_GO.

### Requested plan storage confirmation — 2026-09-15

This repository-root `refactor.md` is the requested persisted execution plan. It records the
evidence hierarchy, provisional requirement traceability, adversarial findings, revised E0–E10
sequence, verification commands and their actual results, unresolved decisions, and plan-deviation
rules. The current verdict is **NO_GO** for freezing or beginning autonomous implementation of all
95 requirements. No source implementation, migration, route, configuration, ADR, test, Git state,
database, external service, or GitHub write is authorized by this plan; the bounded source/test
slices already present in the worktree remain explicitly validation-pending where stated above.

### Authorized continuation checkpoint — OIDC authentication-event time — 2026-09-15

The current execution continuation applied a bounded E3 authentication-time slice while preserving
the existing dirty worktree. This does not change the overall source-completeness or
runtime-isolation verdict above. No checkout, reset, clean, stage, commit, push, GitHub write,
development-database reset, Valkey flush, live provider call, or external authentication request was
performed.

The preceding plan-only statement records the authorization at that earlier snapshot. The current
continuation is a separately authorized, bounded implementation slice; it does not authorize the
remaining E0–E10 work or override any unresolved decision.

Before/after data-shape proposal for the three ticket databases:

| Area                                           | Before                                                                      | After                                                                                                                     | Migration safety                                                                               |
| ---------------------------------------------- | --------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------- |
| Client, Visitor, and Operator login token rows | No durable authentication-event column in the current model contract        | Nullable `authentication_event_at :datetime` on the final tables `client_tokens`, `visitor_tokens`, and `operator_tokens` | Additive, nullable, no backfill and no destructive rewrite; old rows remain explicitly unknown |
| OIDC authorization transaction                 | Result registration could substitute registration `now` for a missing event | Registration requires an explicit accepted authentication-event time and stores that value in `authenticated_at`          | Existing pending rows are not rewritten; missing provenance fails closed at registration       |

The issuer now refuses to create an authorization code without an explicit authentication-event
time. Base app/com/org authorization controllers obtain the time from the current accepted token
claim or token record for an already-authenticated request, and the result-resume path passes the
transaction's accepted event time through both session issuance and code issuance. OIDC callback
session establishment forwards a valid ID Token `auth_time`; refresh and access-token reissue paths
preserve the token-record event time. Rotation copies the event column without changing it.
Persistence timestamps (`created_at`, `updated_at`), code issuance time, exchange time, and JWT
`iat` remain separate values.

The implementation intentionally does not claim that every upstream ceremony supplies a complete
provenance record yet. A normal successful credential login establishes its event at the successful
login boundary when no earlier event exists; an OIDC callback whose provider token lacks `auth_time`
still needs the separate OIDC freshness/claim-decision work in E3. The transaction and
authorization-code boundaries no longer invent a timestamp from AR persistence or code/exchange
time. Existing rows without the new nullable column and all `prompt`/`max_age` request handling
remain runtime-validation or decision work, not completed requirements.

Static checks for this slice:

- Ruby syntax checks for the changed controllers, concerns, services, model concern, and three
  migrations all exited 0.
- Targeted RuboCop over 29 changed/related files exited 0 with no offenses.
- `git diff --check` exited 0.
- A read-only ticket-migration identity check found no duplicate version, filename stem, or class
  name in the three ticket migration paths.

The targeted Rails command
`RUBY_DEBUG_LAZY=1 bin/rails test test/models/concerns/oidc_authorization_transactionable_test.rb test/services/oidc/authorize_service_test.rb test/models/concerns/refresh_tokenable_test.rb test/controllers/concerns/oidc/callback_test.rb test/controllers/concerns/authentication_reissue_access_token_test.rb`
was attempted but exited before assertions because the configured PostgreSQL host `primary` could
not be resolved/reached. No Rails assertion, migration, Valkey operation, provider call, or
request-path claim is counted as executed. The isolated-service prerequisite remains
`BLOCKED_BY_ENVIRONMENT`.

This checkpoint is an implementation record for the authorized continuation; it does not upgrade E3
or the complete E0–E10 plan to GO. The required next runtime evidence is a test-only PostgreSQL and
Valkey namespace plus stubbed provider egress, followed by T0/T1/T2 claims, existing-session,
reauthentication, refresh, and missing-provenance negative tests across app/com/org.

After this checkpoint, the canonical frontend command
`bun run test -- --maxWorkers=1 --fileParallelism=false` was rerun and exited 0 with 85 files and
1,055 tests passing. This covers no Rails/database path and does not change the blocked runtime
status.

### Authorized continuation checkpoint — social authentication-event propagation — 2026-09-15

The next bounded E3 slice follows the verified external-authentication boundary rather than
inventing an upstream provider timestamp. Google and Apple adapters construct a
`ExternalAuthentication::VerifiedPrincipal` with `verified_at` at the point the provider callback
has been accepted. The signed social ceremony result previously carried its own result-generation
`verified_at` but omitted the accepted authentication event. Base therefore had no event value to
forward when it completed the signed social handoff.

The implementation now adds the verified principal's `verified_at` as the optional signed
`auth_time` claim in `IdentitySocialCeremonyResultIssuer`. `IdentitySocialCeremonyResult` validates
that optional claim as an integer timestamp and rejects a future value beyond the ceremony leeway.
`Base::App::Social::Authentication::CompletionsController` parses the verified result claim and
passes it as `authentication_event_at` to `AuthenticationSessionCommitter`. The legacy app social
callback path passes the same verified principal event directly to its session committer. No Auth or
Base authority was moved; the signed result remains the handoff boundary, and the provider's raw
assertion is not stored or logged.

The issuer test now asserts that the signed result preserves the principal event time, and the Base
completion controller test captures the committer arguments and asserts that the signed event time
is forwarded. These are public handoff/session-boundary tests; no private method is tested.

Static verification for this slice:

- `ruby -c` passed for the issuer, result value, Base completion controller, and Auth callback
  controller.
- Targeted RuboCop over the four changed production files and two affected tests passed with no
  offenses.
- `git diff --check` passed.

The targeted Rails command
`RUBY_DEBUG_LAZY=1 bin/rails test test/operations/identity_social_ceremony_result_issuer_test.rb test/controllers/base/app/social/authentications_controller_test.rb test/services/identity/social_ceremony_contract_test.rb`
was attempted and exited before test assertions because PostgreSQL host `primary` could not be
resolved/reached. No Rails test result is counted as green, and no database, Valkey, provider, or
browser behavior is claimed from this attempt. A test-only PostgreSQL/Valkey namespace and stubbed
provider egress remain prerequisites for verifying social login, signup, link, refresh, and
re-authentication event-time behavior end to end.

This slice does not resolve the separate OIDC `prompt`/`max_age` contract gap, provider-supplied
authentication-time semantics, or the unresolved direct-entry UX. The overall E0–E10 verdict
therefore remains **NO_GO** for autonomous implementation of the complete requirement set, while the
social event-time propagation slice is locally implemented and runtime-validation-pending.

The follow-up contract coverage also separates the provider verification event from result
generation time in the issuer test (an earlier event is preserved), and rejects a future signed
`auth_time` in the social result value test. These tests remain unexecuted because the same Rails
boot-time PostgreSQL prerequisite failed before assertions.

Post-slice checks also include `bundle exec erb_lint --lint-all` (599 files, no ERB errors),
`git diff --check` (exit 0), and syntax checks for the two social controllers and two affected test
files (all `Syntax OK`).

### Authorized continuation checkpoint — OIDC callback missing-event fail-closed — 2026-09-15

The RP callback concern previously passed `authentication_event_at_from_id_token(...)` into the
generic login boundary even when the verified ID Token had no `auth_time`. The generic login code
then used its normal successful-login boundary (`Time.current`), which is valid for a local
credential event but is not valid evidence for an OIDC callback whose accepted authentication event
is absent. This was a source-confirmed fallback path, not a reproduced public request.

The callback now parses the ID Token event once and returns through the existing callback-failure
path when it is missing or unparseable; it no longer calls `log_in` with an invented current time.
Successful callback fixtures now provide an explicit fixed event time, and a regression test proves
that a cryptographically accepted ID Token without `auth_time` redirects to sign-in without
establishing a local session. This change is limited to the RP callback boundary and does not alter
the generic local credential-login event rule.

`ruby -c`, targeted RuboCop, and `git diff --check` passed for the callback and its tests. The
targeted Rails run was attempted but stopped at test-schema boot because PostgreSQL host `primary`
was unresolved; the new regression test is therefore not runtime-verified. The callback remains
runtime-validation-pending until an isolated test PostgreSQL/Valkey environment is available.

Read-only post-change route checks still boot: `RUBY_DEBUG_LAZY=1 bin/rails routes` exited 0 with
1,523 route lines, and `RUBY_DEBUG_LAZY=1 bin/rails notes` exited 0 with 31 note lines. These are
boot/inventory checks only and do not substitute for database-backed request tests.

### Current execution decision — NO_GO — 2026-09-15

This section is the current persisted decision for the requested feature plan.

**Decision:** `NO_GO` for freezing or starting autonomous implementation of the complete E0–E10 /
REQ-001–REQ-095 scope. The worktree contains bounded, explicitly recorded slices, but the complete
implementation plan is not authorized to advance to an all-requirements execution run.

**Blocking evidence:**

1. The exact P00–P17 source plan and Sol review artifacts identified by the supplied SHA-256 digests
   are not present in the repository or reachable Git blobs. Their summaries cannot be treated as
   the missing authoritative text, so the complete requirement ledger cannot be proven
   source-complete.
2. An earlier sandbox checkpoint could not resolve the configured PostgreSQL host `primary` or
   Valkey host `valkey`, so those commands stopped before assertions. A later host-authorized run
   did reach the test database, but the complete Rails suite was not green:
   `12992 runs, 78670 assertions, 4 failures, 15 errors, 3 skips` (exit 1). The user's separate
   terminal run also stopped via `^C` before a completion summary. No isolated Valkey namespace,
   provider egress stubs, browser, or device validation has been established. Consequently no
   database-backed authentication, replay, cookie, migration, request-contract, DPoP, or DBSC claim
   is counted as fully runtime-validated.
3. OIDC `prompt`/`max_age` handling, direct-entry UX, the final Auth/Base admission boundary, the
   public `guid`/`net` OpenAPI ownership decision, and physical DPoP/DBSC interoperability still
   require evidence or an explicit architectural decision. They must not be silently resolved by
   implementation.
4. The repository remains intentionally dirty with pre-existing and bounded local changes. No
   checkout, reset, clean, stash, stage, commit, push, GitHub write, development-database reset,
   Valkey flush, live provider call, or external authentication request is permitted by this plan.

**Already recorded bounded work:** the worktree records static and local changes for the
authentication-event-time propagation path, social authentication-event handoff, OIDC callback
missing-event fail-closed behavior, activity timestamp presentation, OTP/Turnstile and recovery
preload review, authorization-code owner binding/fail-closed handling, DPoP pre-consume review,
cookie-scope audit, and route/OpenAPI inventory. Each checkpoint identifies its own runtime
validation status; none upgrades the complete plan to `GO`.

**Execution status:**

| Area                                                        | Status                     | Next gate                                                                                                                                                        |
| ----------------------------------------------------------- | -------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Evidence inventory and source-artifact verification         | `READY_WITH_PRECONDITIONS` | Obtain the exact source artifacts or mark each missing requirement as decision-pending; do not reconstruct P00–P17.                                              |
| Isolated Rails baseline                                     | `BLOCKED_BY_ENVIRONMENT`   | Provide test-only PostgreSQL/Valkey services and stubbed provider egress; capture failures, skips, coverage, and static gates separately.                        |
| Authentication/OIDC and authorization-code safety           | `READY_WITH_PRECONDITIONS` | Run the T0/T1/T2, missing-event, owner-mismatch, replay, concurrency, and failure-injection tests in the isolated environment.                                   |
| Auth/Base authority cutover and direct-entry behavior       | `BLOCKED_BY_DECISION`      | Decide the direct-entry UX and prove inherited admission/callback order across app/com/org/org-specific ceremonies.                                              |
| OTP, email, social-link, cookie, activity/session UI slices | `READY_WITH_PRECONDITIONS` | Execute their existing focused Rails/JS suites; preserve surface boundaries and do not weaken security checks.                                                   |
| Routes, GUID, and OpenAPI coverage                          | `READY_WITH_PRECONDITIONS` | Establish `net`/GUID ownership and run route-coverage, Committee, bundle, and generated-artifact checks in a writable isolated worktree.                         |
| DPoP and DBSC interoperability                              | `DEFERRED_VALIDATION`      | Complete protocol-level automated checks first, then representative real-client/browser/device validation; do not call it validated before that evidence exists. |
| Broad cleanup and private-test/visibility work              | `BLOCKED_BY_ENVIRONMENT`   | Start only after a green, measured baseline; never lower thresholds, add exclusions, skip tests, or expose private methods for coverage.                         |

**GO gate for a later implementation run:** all exact requirements are traceable; no unresolved MUST
contradiction remains; the isolated Rails/Valkey/provider test environment is proven; the baseline
and coverage gates are measured; direct-entry and `net` ownership decisions are recorded; all
security-boundary tests and failure-injection tests have executable acceptance criteria; and the
final independent audit procedure is scheduled. Until those conditions hold, this file is a planning
artifact and must not be used as authorization to begin the complete implementation.

**Permitted next actions:** preserve the worktree, continue evidence-based static inspection, append
actual command results to this file, and run only isolated, non-destructive checks whose
prerequisites are proven. Any architectural or security-boundary change discovered during
implementation must be reported as `PLAN_DEVIATION` with the original assumption, evidence, affected
requirements, and proposed alternative before proceeding.

### Latest Rails test evidence — 2026-09-15

The command entered by the user was:

```text
bin/rails test
```

It discovered `12992` tests and started `16` workers, then was interrupted with `^C`. Because it did
not print a completion summary and did not exit normally, it is evidence that boot, discovery, and
at least part of test execution worked; it is not evidence of a green suite.

A host-authorized, non-destructive run completed separately with the same command and returned exit
`1`: `12992 runs, 78670 assertions, 4 failures, 15 errors, 3 skips`. The model-only command
`bin/rails test test/models` returned exit `0` with
`3001 runs, 10214 assertions, 0 failures, 0 errors, 0 skips`. The full suite therefore remains red
and the measured green baseline has not been established. The concrete failure list and targeted
rerun are recorded in the subsequent checkpoint; no assertion was weakened or skipped to improve the
result.

### Authorized continuation checkpoint — reject future OIDC authentication time — 2026-09-15

Static inspection found that the RP callback rejected a missing or malformed `auth_time`, but a
numeric value beyond the configured clock leeway could still be converted into an authentication
event and forwarded to the login boundary. The verifier and callback now reject a future event time
beyond `AuthenticationJwtConfiguration.leeway_seconds`. This does not implement `max_age` or
`prompt`; it only prevents a physically impossible authentication event from becoming trusted
session state.

The first regression test was added to `test/services/oidc/id_token_verifier_test.rb`, followed by
the callback boundary regression in `test/controllers/concerns/oidc/callback_test.rb`. Both tests
assert rejection without establishing a local session. `ruby -c` passed for all four changed files,
targeted RuboCop inspected four files with no offenses, and `git diff --check` passed.

`RUBY_DEBUG_LAZY=1 bin/rails test test/services/oidc/id_token_verifier_test.rb` was attempted and
exited before assertions because PostgreSQL host `primary` could not be resolved. No Rails assertion
is counted as executed or green; the new security boundary remains runtime-validation- pending. The
isolated test PostgreSQL/Valkey and provider-stub prerequisites in the NO_GO gate are unchanged.

The same callback contract required two existing integration fixtures to provide the accepted
authentication event instead of relying on an ID Token with no `auth_time`: the sign-surface browser
flow now derives it from the authorization-code payload, and the RP browser flow derives it from the
authenticated transaction. These are test-fixture corrections only; they preserve the production
rule that callback authentication time comes from the accepted event rather than token issuance
time.

### DPoP nonce and authorization-code retry recheck — 2026-09-15

The current source separates the optional RFC 9449 §8 nonce mechanism from proof validation:

- `app/controllers/concerns/base_oauth_token_endpoint.rb#create` forwards the DPoP proof to
  `OidcTokenExchangeCoordinator`, but does not emit a token-endpoint `DPoP-Nonce` challenge.
- `app/services/oidc_token_exchange_coordinator.rb#exchange_authorization_code!` calls
  `validate_dpop_proof` before `code_store.consume!`; an invalid proof therefore reaches the
  source-level failure return without intentionally consuming the code.
- `app/lib/dpop_proof_verifier.rb#verify_nonce` accepts a proof without a nonce because the server
  has not selected a nonce-required token-endpoint policy. When a nonce is supplied,
  `DpopNonceService.verify` consumes it once through the per-resource proof-state store.
- `app/controllers/concerns/authentication_base.rb#load_from_token` may emit `DPoP-Nonce` after a
  failed resource authentication. That response is a Resource Server challenge and is not evidence
  that the authorization server token endpoint requires a nonce on its next request.

This is consistent with RFC 9449's optional server nonce adoption; it does not prove the actual HTTP
retry contract, nonce authority separation, or concurrent code-consumption behavior. The remaining
E5 acceptance tests must exercise malformed proof, wrong key, stale `iat`, replayed `jti`, absent
nonce after an RS challenge, valid nonce retry where the endpoint chooses to use one, and
code/family state after each result. No nonce requirement is invented in this slice, and no DPoP
proof or device interoperability claim is marked validated.

Post-fix static verification also passed for the two integration fixtures that now carry the
accepted event (`ruby -c` for six changed Ruby files, targeted RuboCop over six files, and
`git diff --check`). The integration tests themselves remain unexecuted because the same PostgreSQL
boot prerequisite fails before assertions.

### Authorized continuation checkpoint — OIDC browser fixtures carry explicit session event time — 2026-09-15

Static follow-through found that the new authorization-event requirement also affects existing
browser-flow fixtures that create an already-authenticated token row and then call the Base
authorization endpoint. Those fixtures previously left the event column null, which would make a
real test run fail at the intended fail-closed authorization-code boundary rather than exercise the
flow. The affected test token factories now set `authentication_event_at: Time.current`:

- `test/integration/sign_app_oidc_browser_flow_test.rb` current-session and shared actor-token
  helpers;
- `test/integration/oidc_rp_browser_flow_test.rb` browser-session, session-limit, ownership, and
  shared actor-token helpers;
- `test/controllers/base/oauth_oidc_authority_test.rb` the app/com/org immediate-authorize token
  fixtures and shared actor-token helpers.

This is test-fixture alignment only. It does not make persistence timestamps an authentication event
and does not add a fallback to production code. The event remains an explicit fixture input, while
callback fixtures derive ID Token `auth_time` from the accepted transaction/code event.

Verification completed after this adjustment:

- `ruby -c` passed for all three changed test files;
- targeted RuboCop over those three files passed with no offenses;
- `git diff --check` passed.

The corresponding Rails integration tests were not counted as executed: a targeted run still stops
before test setup because PostgreSQL host `primary` cannot be resolved/reached. The isolated test
database and Valkey prerequisites in the NO_GO gate remain unchanged.

The attempted command was:

```text
RUBY_DEBUG_LAZY=1 bin/rails test test/integration/oidc_rp_browser_flow_test.rb
```

It exited with status 1 during `ActiveRecord::Migration.maintain_test_schema!` with
`PG::ConnectionBad: could not translate host name "primary" to address`; zero test assertions were
executed. This is recorded as an environment block, not as a test failure or a passing result.

### Current repository checkpoint — 2026-09-15 continuation

The current repository state was re-read after the preceding checkpoint. `feature` is at
`7bee4819ffe2a402c63a04af2a368bfcaf253c0d`, whose parent is
`430ac354ba06c9d22885e1e69d027a7a1b1d5280`; the worktree has no staged, unstaged, or untracked paths
at this observation. This supersedes the earlier provisional HEAD value in the historical planning
snapshot; that earlier section is retained as history rather than silently rewritten. No checkout,
reset, clean, stash, stage, commit, push, database operation, Valkey operation, or external provider
call was performed during this re-read.

### E8 bounded implementation slice — Core preference API controller vocabulary — 2026-09-15

The evidence-supported part of E8 was implemented locally after the preceding checkpoint. Core
app/com/org preference cookie and theme routes still expose the same `/api/v0/preferences/*` paths,
but now resolve through `Core::<surface>::Api::V0::Preferences::CookiesController` and
`ThemesController`. The DBSC registration route remains `POST /api/v0/preferences/dbsc` and now
resolves through the matching canonical `DbscController`. The old Core `Web::V0` and `Edge::V0`
controller files, plus their dead unmounted cookie coverage test, were removed after repository
search found no remaining application caller.

The existing GET/PATCH contract was deliberately preserved. Rails' ordinary
`resource ... only: :update` also exposes PUT, while the OpenAPI and route contract explicitly
reject PUT for cookie and theme updates. The route file therefore keeps a narrowly documented
GET/PATCH declaration; this is an established API-contract exception, not a new route vocabulary.
DBSC uses ordinary resource routing because its protocol contract is POST-only.

Updated contract and invariant tests follow the canonical controller paths, and the accepted API
vocabulary ADR now records this implementation amendment. `RUBY_DEBUG_LAZY=1 bin/rails routes`, the
canonical controller constant load, syntax checks, targeted RuboCop, `git diff --check`,
`bun run openapi:lint`, and `bin/rails notes` passed. Rails request/invariant tests remain
unexecuted because the isolated test PostgreSQL host `primary` cannot be resolved; no database or
Valkey service was started. The full E0–E10 program therefore remains `NO_GO` pending its existing
environment and architecture gates.

The subsequent full `bundle exec rubocop` inspection covered 4,786 files and exited 0 with no
offenses.

`bun run openapi:verify` also exited 0: source bundling succeeded and the three committed public
bundles had no generated diff.

A read-only `RUBY_DEBUG_LAZY=1 bin/rails runner '...'` check also recognized app/com/org GET and
PATCH cookie/theme requests and DBSC POST requests, while confirming that the contractually
unsupported cookie/theme PUT requests still raise `ActionController::RoutingError`.

The remaining Base/Side browser preference routes and Base token/DBSC routes were not renamed by
guesswork. Their route comments now contain actionable `FIXME:` notes describing the direct browser
callers, authority/protocol boundary, and compatibility/OpenAPI decisions still required before a
future `/api/v0` migration. Auth ceremony routes, content reads, and other protocol paths remain
outside this slice.

At this continuation point the worktree intentionally contains the route migration, test updates,
ADR amendment, evidence record, and this plan append. No checkout, reset, clean, stash, stage,
commit, push, database operation, Valkey operation, or external provider call was performed.

### User-requested NO_GO plan pointer — 2026-09-15

The current execution verdict for the complete feature program is **`NO_GO`**. The authoritative
decision is recorded above under **“Current execution decision — NO_GO — 2026-09-15”**. This is a
planning gate, not a claim that every bounded local slice is unimplemented.

The complete E0–E10 / REQ-001–REQ-095 run remains blocked because the exact P00–P17 source artifacts
are unavailable, the isolated PostgreSQL/Valkey test targets are unavailable, and the direct-entry
UX, OIDC `prompt`/`max_age`, `guid`/`net` OpenAPI ownership, and physical DPoP/DBSC validation
decisions remain unresolved or unverified. Rails request tests therefore must not be reported as
green; the attempted runs stopped before assertions when the PostgreSQL host `primary` could not be
resolved.

The currently permitted work is limited to evidence-based static inspection and explicitly bounded,
non-destructive slices whose dependencies are proven. Any later implementation run must first close
the listed environment and decision gates, capture a measured green baseline, and then execute the
frozen phase plan with public-behavior/security tests. No implicit approval to start the complete
implementation is granted by the bounded changes already recorded in this file.

### Documentation consistency follow-up — Core route amendment — 2026-09-15

The Core preference route slice left two stale ADR statements implying that the vocabulary decision
had never changed a route. `adr/README.md` now points to the reviewed Core amendment, and the
opening/consequence language in `adr/api-route-vocabulary-consolidation.md` distinguishes the
original naming decision from the implemented Core slice and the still-unmigrated services. This is
documentation-only reconciliation; it does not broaden the route migration or change any remaining
`/web/v0`/`/edge/v0` contract.

Verification: `git diff --check` exited 0 and the affected Ruby source remains syntactically valid.

### E8 GUID/OpenAPI boundary annotation — 2026-09-15

The GUID route inventory confirms `GET /api/v0/resources/:guid` is owned by
`guid/net/api/v0/resources#show`, while the current controller only performs transport-safe input
checking and returns a controlled 404. No durable resolver model or issuance contract is evidenced,
and the repository has no `net` OpenAPI bundle. `config/routes/guid.rb` now carries an actionable
`FIXME:` beside the route naming those three blockers and explicitly forbidding a guessed schema or
model. `RUBY_DEBUG_LAZY=1 bin/rails notes` finds it, and route output also confirms Edit's
`/api/v0/health.json` and `/api/v0/revision.json` remain mounted under `edit/org` and are covered by
the existing org-surface operational contract. No GUID persistence or OpenAPI ownership decision was
made in this slice.

The OpenAPI route coverage harness now includes `edit` in its application-service controller
discovery pattern. This closes a real discovery gap for Edit's org-facing `/api/v0` operational
routes without creating a new OpenAPI surface. GUID remains excluded from the three committed
surface documents and is guarded by the route-level FIXME until the `net` ownership decision is
made. `bundle exec rubocop test/contracts/openapi_route_coverage_test.rb config/routes/guid.rb`,
Ruby syntax checks, `RUBY_DEBUG_LAZY=1 bin/rails routes`, and `git diff --check` passed. The
database-backed OpenAPI Minitest remains unexecuted because Rails test boot cannot resolve
PostgreSQL host `primary`.

The attempted command was
`RUBY_DEBUG_LAZY=1 bin/rails test test/contracts/openapi_route_coverage_test.rb`; it exited 1 during
`ActiveRecord::Migration.maintain_test_schema!` with
`PG::ConnectionBad: could not translate host name "primary" to address`. No OpenAPI coverage
assertion executed, so the `edit` discovery change is static/runtime-route verified but not
database-backed test verified.

A read-only `RUBY_DEBUG_LAZY=1 bin/rails runner` inventory printed the expected `edit/org` health
and revision operations plus the three GUID `net` operations (resource, health, revision). The
runner loaded routes without performing database writes; its OpenTelemetry boot messages were
informational only. This supports the scoped discovery change and the separate GUID ownership
blocker, but it is not an OpenAPI schema or request-response validation.

The coverage contract now has an explicit Edit-org assertion for exactly the health and revision
operations and verifies that both are present in the existing org description. The focused Ruby
syntax, RuboCop, and diff checks pass; the contract test itself remains blocked before assertions by
the unavailable `primary` PostgreSQL host.

The current authoritative worktree recheck remains `feature` at
`7bee4819ffe2a402c63a04af2a368bfcaf253c0d`, with the Core route migration, its tests/evidence, the
GUID FIXME, the OpenAPI discovery change, and this plan documentation uncommitted. Existing user
changes were preserved; no staging, commit, reset, cleanup, database operation, Valkey operation, or
remote write was performed.

### Documentation consistency follow-up — preference contract — 2026-09-15

The Core preference migration also made one active architecture document stale: it said cookie and
theme JSON endpoints remained under `/web/v0` on every surface. The current contract now states that
Core uses `/api/v0/preferences/{cookie,theme}` while non-Core browser endpoints remain under legacy
`/web/v0` pending their own review. The before-action parity guidance now names both the non-Core
legacy controllers and the canonical Core controllers. No route, controller behavior, or unmigrated
service was changed by this documentation-only correction. `git diff --check` passed. The canonical
Core route/controller files and OpenAPI discovery test also passed targeted RuboCop and Ruby syntax
checks. No Rails request assertion was executed because test-schema boot still cannot resolve
PostgreSQL `primary`.

The read-only route inventory was rerun after the documentation correction; it exited 0 and asserted
exactly `GET /api/v0/health.json` and `GET /api/v0/revision.json` for `edit/org/api/v0`.

### E7b bounded Cookie scope verification — 2026-09-15

Without connecting to PostgreSQL or Valkey, a read-only Rails runner instantiated the existing
`AuthenticationCookieService` with test request objects for app, com, and org hosts. For both
issuance and deletion options, `path`, `domain`, `same_site`, and `secure` matched on all three
surfaces; deletion options omitted `expires` as required. This supports the source conclusion that
no name/domain/path mismatch is currently evidenced. It does not prove a browser applied the
`Set-Cookie` deletion headers after the complete sign-out ceremony; the cookie-jar request test
remains pending behind isolated Rails services.

### E9 bounded session-expiry semantics recheck — 2026-09-15

The existing implementation already has a single fixed session deadline for the token-backed session
inventory. `ClientToken`, `VisitorToken`, and `OperatorToken` persist `discarded_at` with an
infinite default; session establishment supplies the finite deadline. `RefreshTokenable` copies that
value unchanged during rotation and caps an explicitly proposed replacement deadline with
`SessionAbsoluteExpiryValue`. `TokenStatusManagement#currently_usable_at` and the refresh issuer
reject the record at or after the deadline. Access-token, ID-token, refresh-token, cookie, and DBSC
expiry calculations all cap their proposed lifetime against the same root-token value. This is also
stated by `docs/security/refresh-token-rotation.md`; no separate absolute-expiry column is justified
by the inspected code and tests.

The user-facing Base session presenter maps only the normalized fields `device`, `last_activity`,
`created`, `expires_at`, `status`, and the org-only authentication mode. It does not expose
`public_id`, token kind, binding, refresh-token expiry, generation, raw context, or token material.
`expires_at` is rendered from the fixed session deadline, while refresh-token expiry remains an
internal issuance/cookie value. `SessionTimestampHelper` converts the stored instant through the
actor preference timezone, date format, and clock format before presentation. The inventory query is
owner-scoped and filters at the database scope; it does not add a request-hot-path session lookup to
ordinary Access JWT validation.

Existing tests cover finite-deadline preservation across app/com/org rotation, rejection after the
deadline, token-expiry capping, user-facing field suppression, preference formatting, and the org
Emergency/Normal context distinction. The inspection did not prove the full DB-backed suite or
browser rendering because PostgreSQL host `primary` is unavailable. E9's bounded presentation and
expiry behavior is therefore classified **ALREADY_SATISFIED in source/tests, runtime validation
pending**; no schema, route, presenter, or token change is proposed in this continuation.

The post-update checks `find ... | ruby -c`, targeted RuboCop over the route/OpenAPI/security files,
`RUBY_DEBUG_LAZY=1 bin/rails notes`, and `git diff --check` all exited 0. `bin/rails notes` lists
the new actionable Base/Side/GUID route deferrals; it does not imply those deferred runtime
contracts are resolved.

The full `bundle exec rubocop --cache false` was rerun after this checkpoint: it inspected 4,786
files and exited 0 with no offenses. An earlier intermediate run had reported the pre-existing
PGHero line-length offense; this later complete run supersedes that transient result for the current
worktree without modifying the PGHero route.

`bun run openapi:lint && bun run openapi:verify` was also rerun after the documentation and route
checkpoint. Both commands exited 0; Redocly validated all three source documents, regenerated the
bundles deterministically, and `git diff --exit-code` found no generated-bundle drift.

### User-provided Rails test runner evidence — 2026-09-15

The user supplied an external terminal observation showing `bin/rails test` starting `12,992` tests
with `16` processes and producing normal test dots before the process was interrupted with `^C`.
This proves that, in that terminal environment, Rails boot/test discovery and at least part of the
parallel test execution reached the test body. It is not a completed result: no final run count,
failure/error count, skip count, coverage result, or exit-0 completion was observed because the
command was manually stopped.

The separate command `bin/rails test test:models` is not a valid Rails test path. Rails interpreted
`test:models` as a file and raised `LoadError` for `/home/global/workspace/test:models`. The correct
directory selector is `bin/rails test test/models` (or a specific file under that directory). The
managed tool environment was rechecked after the user report; `primary` and `valkey` still did not
resolve there, and `bin/rails test test/models` stopped during schema setup with `PG::ConnectionBad`
before assertions. The two observations are recorded separately rather than using the sandbox
failure to negate the user's terminal evidence or using the interrupted run as a green baseline.

### E0 isolated test-environment implementation checkpoint — 2026-09-15

This section supersedes the earlier environment-only **NO_GO** as an execution status for the
user-authorized E0 setup work. It does not approve autonomous implementation of the remaining
feature requirements, does not establish a full-suite baseline, and does not change the historical
plan-only verdicts above.

Starting state was preserved: branch `feature`, HEAD `7bee4819ffe2a402c63a04af2a368bfcaf253c0d`,
with the existing Core route migration and other uncommitted paths unchanged. No checkout, reset,
clean, stash, stage, commit, database reset/drop, remote write, provider request, or external
IdP/mail/SMS request was performed.

The E0 changes are local test configuration and support only:

- `config/database.yml` now requires `POSTGRESQL_TEST_HOST` for every test database instead of
  falling back to `POSTGRESQL_HOST` or localhost.
- `config/environments/test.rb` requires and validates the responsibility URLs on Valkey logical DBs
  3/4/5 and requires a validated `VALKEY_NAMESPACE_RUN_ID`.
- The three default auth-state stores include run/worker namespace scope. The existing direct store
  tests continue to supply their own suite/worker/test namespaces.
- `test/support/valkey_test_isolation.rb` updates the worker scope after Rails forks, and
  `test/support/service_stubs.rb` is loaded by the test helper so the existing SMS safety stub is
  available.
- `scripts/test-environment-check`, `scripts/test-isolated`, and `scripts/test-valkey-cleanup`
  perform read-only service identity checks and run-scoped SCAN/DEL cleanup. They never issue
  `FLUSHDB` or `FLUSHALL`.
- `test/config/test_environment_isolation_contract_test.rb` fixes the contract in 3 tests and 14
  assertions. `docs/operations/test-environment.md` documents the explicit runner and provider
  boundaries.

The authorized host checks were real and read-only. PostgreSQL at `primary.dns.podman:5432` reported
server 17.7, administration database `db`, and 646 `test_*` databases. Valkey at
`valkey.dns.podman:6379` returned `PONG` on DB 3 (cache), DB 4 (rate limit), and DB 5 (auth state),
server 7.2.4. The isolated smoke test exited 0 with
`2 runs, 7 assertions, 0 failures, 0 errors, 0 skips`; its run-scoped cleanup completed. The
requested auth-code/OTP target command reached the application and exited 1 with
`147 runs, 725 assertions, 0 failures, 3 errors, 0 skips`; two OIDC exchange test helpers omit
required client/redirect/PKCE keywords and one com sign-in test expects a missing `form_errors`
prop. Those are application/test-contract failures, not inability to connect to PostgreSQL or
Valkey. Full Rails/coverage results remain unclaimed.

A two-worker smoke plus contract run also exited 0 with
`5 runs, 21 assertions, 0 failures, 0 errors, 0 skips`; both worker processes completed before the
run-scoped cleanup.

The full Rails suite then ran with 16 workers through the wrapper and exited 1 after 452.716
seconds: `12995 runs, 78688 assertions, 4 failures, 15 errors, 3 skips`. This is a real
application/contract result after service connectivity succeeded, not an environment boot failure.
The subsequent `COVERAGE=true` attempt exited 1 before test assertions because Rails detected the
newly present untracked `db/migrate/20260915000000_create_blazer_tables.rb` as pending; the partial
SimpleCov report (52.02% line, 1.07% branch, 2.52% method) is not a baseline. Blazer migration,
structure, and initializer paths appeared during the suite and were left untouched to preserve
unrelated work.

The local `bin/` directory is read-only in this execution sandbox, so the permitted preparation
scripts live under `scripts/`; no workaround wrote into `bin/`. The host has no container runtime or
local PostgreSQL/Valkey binaries, but the already-running test-only endpoints were reachable through
the authorized host network. CI workflow service publication was not changed because the repository
rule forbids publishing datastore ports; a non-published CI service network remains a separate
environment task.

Final E0 recheck: the read-only preflight exited 0 again with the same PostgreSQL/Valkey identities,
and a run-scoped cleanup exited 0. The contract test was extended with a real auth-state key-scope
assertion after the earlier green run; its rerun stopped before assertions because Rails reported
the unrelated pending Blazer migration `db/migrate/20260915000000_create_blazer_tables.rb`. No
migration was applied, so the earlier 3-run/14-assertion result remains the last executed contract
result and the added assertion is explicitly unverified.

# Current execution status — E0 safety guard completion

As of 2026-09-15, Rails execution is enabled against an explicitly verified PostgreSQL/Valkey test
target. This continuation is implementing E0 guard completion and repairing the green baseline; it
is not an execution of the all-95 feature plan. Full feature completion, deployment GO/NO-GO, and
unrelated Core/PgHero work are outside this task. Existing user and concurrent worktree changes are
preserved.

The dedicated `test_primary_db` received only migration `20260915000000_create_blazer_tables` after
a read-only identity check. The new database and Valkey guards, run/worker cleanup scope, and
external-provider deny boundary still require the current contract and authentication tests to be
rerun. A green baseline has not yet been claimed.
