# two.md — Detailed definitions (Work Units)

> Archived 2026-10-27 from the working file `two.md` (cycle archive 0002; frozen, not maintained).

> Status 2026-10-25 (updated after local WU-14/15/16/22 implementation; **Part 6 (H18) wins over earlier sections where they differ**): WU-14, WU-15, WU-16 and WU-22 are implemented in the current worktree. Their acceptance is not closed; see `three.md` and `evidence/2026-10-25-wu15-16-22-op-authority-stop-6B3Q.md` plus the current WU-14 focused evidence. WU-16/WU-22 acceptance remains subject to G-16 and D-166/A44 prerequisites. The 2026-10-25 full suite run was red (18,309 runs, 190 failures, 298 errors); its complete per-file failure output was not retained, so the remaining baseline failures still need inventory and disposition. See `evidence/2026-10-25-wu15-16-22-suite-check-C7M4.md`. Start from `one.md` "Resume here". Other units retain their recorded status. Part 3 adds WU-27 … WU-39.

Working document (gitignored). Role in the cycle: `one.md` holds the requirements and owner
decisions; **this file defines the Work Units an implementer executes**; `three.md` will hold
acceptance. Opened 2026-10-21 at `febec3225cc9a0cfa53b9cbe817d20d366aba5a2`; the worktree is dirty
with work that is not ours — preserve it (no `git reset/clean/restore`).

Rules for the implementer:

- Load the rules that the root `AGENTS.md` Task Rule Index selects before editing. For these units
  that means at least `generic/model-behavior-calibration.mdc`, `generic/rails-change-discipline.mdc`,
  `generic/no-compatibility-layer.mdc`, `generic/testing.mdc`, `generic/no-test-only-code.mdc`,
  `project/static-invariant-guards.mdc`, `project/surfaces.mdc`, `generic/routing.mdc`, and
  `docs/mermaid/README.md` for any state-machine change.
- TDD (Red → Green → Refactor). Run the narrowest tests after each step; never delete or weaken a
  test only to make it pass.
- A step whose dead-code check does not come out clean **stops**: report it, do not delete.
- Owner decision IDs (D-…, X-…) refer to `one.md`.

| WU | Title | Owner decision | Status |
|---|---|---|---|
| WU-01 | Remove the entry-less Local Sign-in Flow | D-60 | Done 2026-10-23 (evidence L0R1; deviations listed there) |
| WU-02 | Visa OP / Base RP host separation | D-59, D-61, D-62, D-65 | Definition complete (§2.6, steps V1–V11). Not implemented; runs after WU-04 and WU-05 |
| WU-03 | Remove the legacy `/edge/v0/cookie` entry point | D-63 | Defined, not started |
| WU-04 | Sign-up telephone SMS OTP (app and com): add visible Turnstile | D-66, D-67 | Defined, not started |
| WU-05 | Sign-up six-path unification (App 4, Com 2) | H11, D-69 … D-72 | **Definition complete** (2026-10-21). Not implemented. Before implementation: the new ADR (U4), the owner's go, and approval of the E1 migration |
| WU-06 … WU-23 | Remaining one.md requirements | see Part 2 | Ready, Design first or gated per Part 2 |
| WU-24 | E1 binding, effective intent and curfew storage (prerequisite of WU-05/WU-06) | D-72, D-74, D-75, D-125, D-127 | Defined; migration choices decided (D-125, D-127); deletion of unbound Flows lists counts and recovery first |
| WU-25 | Revocation client authentication and Discovery metadata | D-79 | Ready after WU-02 |
| WU-26 | Read-only diagnosis of partial registrations | D-82, D-126 | Lookup inputs and safe OP/audit references extended locally (2026-10-26); remaining D-82 inventory and acceptance stay open; deletion is WU-38 |
| WU-27 … WU-39 | Units from the 2026-10-22 decisions | D-84 … D-127 | see Part 3 |

---

## WU-01 — Remove the entry-less Local Sign-in Flow

> **Implement through sub-units WU-01a … WU-01f only (D-133, Part 4).** This section stays the contract.

### Why

The Local Sign-in Flow is a Base-only sign-in path that bypasses OIDC: Base issued a local
Admission, Auth ran the ceremony, Auth `/sign/handoff` sent the result to Base `/sign/completion`,
and Base created the Root Session directly. It contradicts D-54 (Base is a standard RP with no
internal shortcut).

Its only entry, `BaseNeutralSignEntry` (Base `/sign`), was deleted on 2026-10-08 in `48ff7040de`
and replaced by `OidcRpSignEntry` (OIDC). The entry method
`BaseAuthAdmissionCoordinator.issue_local_entry!` remained and has **no caller in `app/`, `lib/` or
`config/`** (checked 2026-10-21). The receivers and the local branches in shared code are therefore
unreachable in production, while 195 test call sites in 71 files still create local entries
directly. Runtime evidence is unavailable: `log/development.log` currently holds no request lines.

The project has never been deployed; destructive removal is allowed and no compatibility path is
kept (`no-compatibility-layer`).

### Inventory (2026-10-21, static reading — re-verify before each deletion)

**Delete (dead by static reading):**

| Part | Files | Reachability |
|---|---|---|
| Local entry and restart | `BaseAuthAdmissionCoordinator.issue_local_entry!`, `restart_local_flow!`, `local_entry_purpose_for` and the `"sign_in" => "local_sign_in"` mapping (`app/services/base_auth_admission_coordinator.rb`) | No caller |
| Admission purposes `local_sign_in`, `local_sign_up` | `AuthAdmissionBinding` (`sign_in_flow:` purposes), `AuthCeremonySession::ADMISSION_PURPOSES`, `Valkey::AuthState::OpaqueAdmissionStore` purpose list, coordinator purpose checks (`%w(authentication_handoff local_sign_in local_sign_up)`) | Only `issue_local_entry!` creates them |
| Base local receiver | `config/routes/base.rb` `namespace :sign { resource :completion }` (app/com/org), `Base::{App,Com,Org}::Sign::CompletionsController`, `BaseLocalAuthenticationCompletion` | Reached only with a local Admission result |
| Auth local handoff | `config/routes/auth.rb` sign handoff routes (app/com/org), `Auth::{App,Com,Org}::Sign::HandoffsController`, `AuthLocalResultHandoff`, the `*_sign_handoff_path` links in `Auth::{App,Com,Org}::ApplicationController` | Acts only on `local_sign_in`/`local_sign_up` ceremonies (`auth_ceremony_local_sign_in_flow`) |
| `AuthenticationSequenceGate#continue_selector_sequence!` | `app/controllers/concerns/authentication_sequence_gate.rb` and its cases in `test/controllers/concerns/authentication/sequence_gate_extra_coverage_test.rb` | No caller in `app/` since `e2b87fde9a` (2026-10-08); owner decision D-64 |
| `LocalAuthenticationResultCoordinator` | `app/services/local_authentication_result_coordinator.rb` | Used by the local receiver/handoff and by `LocalAuthenticationSessionCommitter` (see below) |

**Check first (may be partly alive):**

| Part | What to establish |
|---|---|
| `LocalAuthenticationSessionCommitter` (`app/operations/local_authentication_session_committer.rb`) | `AuthenticationSequenceGate#…` calls `LocalAuthenticationSessionCommitter.resume_pending!` (line ~539). Establish whether that call is reachable from an OIDC-parent ceremony (session-limit / pending-session resume). If yes, keep the OIDC part and remove only the local branch; if no, delete it with the receiver |
| `auth_ceremony_local_sign_in_flow` and `local_sign_in_flow_ref` | Referenced in Auth `Sign::InsController` (app/com/org), `Sign::In::SecretsController`, `AuthCeremonyAdmission`, `AuthCeremonyContext`, `AuthenticationSequenceGate`, `AuthenticationBase`, and the models/operations below. Each call site has an OIDC branch and a local branch; remove the local branch only |
| Local branches in credential code | `ClientSecretCredential`, `ClientSecretSignInReceipt`, `ClientSecretClaimFinalizer`, `ClientSecretClaimCommitter` (`admission_purpose == "local_sign_in"`), `AuthEmailOtpChallenge` (`parent_kind` `local_sign_in` vs `oidc`), `CredentialSecurityTransition` (`where(admission_purpose: %w(local_sign_in local_sign_up))`). Keep the OIDC behavior byte-for-byte |
| `SignInCycleLocator` | Used by `AuthenticationSequenceGate`, `SignInPhaseBindingControllerSupport` and the local receiver. Keep unless every caller is local |
| Post-login sequence (welcome gate, selector) | `AuthenticationSequenceGate#continue_selector_sequence!` has no caller in `app/` (only a concern test); the welcome gate is issued only on the non-OIDC branch; `Base::Social::Authentication::CompletionsController#complete_social_signup_local_login!` is the local branch of the social sign-up receiver. Establish whether `/welcome`, `/selector`, `SignInSequenceCarrier` and the welcome gate are reachable from an OIDC parent; remove only what is local |
| `AuthCeremonySession#local_sign_in_flow_ref` column | Schema change: a column removal needs a migration and an owner-approved recovery plan (AGENTS.md, irreversible persistence). Do **not** drop it in WU-01; record it as a follow-up |

**Keep (alive — not part of the Local flow):**

- `ClientSignInFlow`, `VisitorSignInFlow`, `OperatorSignInFlow` and their states/statuses: shared
  with OIDC (`ClientOidcAuthorizationTransaction`, `*SessionLimitResolutionTransaction`, Base
  `/oauth/authorize`).
- Base `/sign/in/limitation` (session limit): reached from `AuthenticationSequenceGate` on the OIDC
  path; it moves to Visa in WU-02.
- Base `/social/authentication/completion`: reached from Auth Google/Apple sign-up birthdate pages
  (`SignUpSocialBirthdateSupport`). Whether it serves the OIDC sign-up is unverified; leave it for
  WU-02.

### Dead-code check (required for every part before it is deleted)

1. **Callers:** `grep` over `app/ lib/ config/` (and `src/` for links) finds no reference outside the
   parts being deleted in the same step.
2. **Reachability:** no route reaches it, and no Admission purpose / parent kind that can still be
   created selects it. Record the route table before and after (`bin/rails routes`).
3. **Behavior (R-28):** an unchanged pass/fail set is necessary but not sufficient. For each surviving
   public behavior reached by a re-pointed fixture, a test proves the behavior beneath its intended
   boundary; known blockers (one.md TR groups) are recorded by cause with a defect reference and the
   affected assertions reported as **unverified**, not as passed.

If any check fails, stop and report; do not delete that part.

### Steps

1. **Baseline.** Record the failing set of the full suite at the starting commit (one.md TR: 59
   failures, 1 error at `febec3225` + D-58) so later runs can be compared.
2. **Re-point fixture tests.** Classify the 72 test files (two.md Part 5.7) that call `issue_local_entry!`:
   - (i) tests whose subject is the Local flow itself (e.g. `test/controllers/base/local_authentication_entry_test.rb`,
     `test/integration/local_authentication_boundary_test.rb`, local cases in
     `test/services/base_auth_admission_coordinator_test.rb`) — deleted together with the code they test;
   - (ii) tests that use a local entry only as a way to reach an Auth ceremony (Email OTP, Passkey,
     Secret, TOTP, rate limits, layouts, session limits) — re-point them to an OIDC-parent entry and
     keep their assertions. List each file with its class before changing it.
   Re-pointing must not change what a test asserts; the test still proves the same ceremony
   behavior under the surviving entry.
3. **Red.** Add request tests that Base `/sign/completion` and Auth `/sign/handoff` are not routable on
   app/com/org (404 / routing error), and that a ceremony session can no longer be admitted with a
   `local_sign_in` / `local_sign_up` purpose (refused, not silently mapped). These fail before
   removal.
4. **Green, in order:** (a) routes and controllers of the receiver and the handoff; (b)
   `issue_local_entry!` and its helpers and purposes; (c) local branches in shared code (one file
   per sub-step, OIDC behavior unchanged); (d) `LocalAuthenticationResultCoordinator`, and
   `LocalAuthenticationSessionCommitter` only if the check says it is local-only. Run the dead-code
   check before each sub-step and the affected tests after it.
5. **Refactor.** Remove now-unused helpers, i18n keys, views, policies and their tests. Rename
   nothing that is still alive.
6. **Docs.** Update `docs/mermaid/idp-{client,visitor,operator}-local-result-delivery.mmd` (retire or
   rewrite), the local-parent rows in `docs/mermaid/idp-state-machine-transition-inventory.md`
   (e.g. the "overdue primary-pending local sign-in parent" text), and any ADR or doc that still
   describes the local completion route; record superseded passages instead of rewriting history.

### Exit criteria

- No route, controller, concern, service method or Admission purpose of the Local flow remains;
  `grep -rn "local_sign_in\|local_sign_up\|issue_local_entry\|sign/completion\|sign_handoff" app lib config`
  shows only intentionally kept items, each listed in the WU report.
- The OIDC sign-in and sign-up tests have the same pass/fail set as the baseline; no new failure.
- Every re-pointed test still asserts the same behavior; every deleted test is listed with the code
  it covered.
- Static invariant guards (`project/static-invariant-guards.mdc`) pass.
- Mermaid diagrams and the transition inventory describe the code after removal.
- An `evidence/` record states the commit, the dead-code checks performed and the before/after
  runs.

### Risks

- A local branch that is in fact reached from an OIDC parent (a mislabelled `parent_kind` or
  purpose) — mitigated by check 3 and by removing one file per sub-step.
- Re-pointing fixture tests to the OIDC entry may surface G1/G2 failures (one.md TR) in tests that
  passed through the local entry before; record them as pre-existing groups, do not paper over them.
- The `local_sign_in_flow_ref` column stays until an approved migration removes it.

---

## WU-02 — Visa OP / Base RP host separation

> **Implement through sub-units WU-02a … WU-02i only (D-133, Part 4).** This section stays the contract.

Status: **Phase 1 (ownership matrix) written 2026-10-21 from static reading at `febec3225` + this
session's uncommitted changes. Not yet an implementation definition**; the items marked *Decide*
in §2.4 need owner decisions first. Source: one.md H8, D-58, D-59, D-61.

### 2.1 Host and identity contract (decided)

| Realm | Visa OP | Base RP | Auth ceremony | Logical names | Jump issuer namespace |
|---|---|---|---|---|---|
| app | `visa.umaxica.app` | `www.umaxica.app` | `auth.umaxica.app` | `visa-app-ww`, `base-app-ww` | `VISA_APP`, `BASE_APP` |
| com | `visa.umaxica.com` | `www.umaxica.com` | `auth.umaxica.com` | `visa-com-ww`, `base-com-ww` | `VISA_COM`, `BASE_COM` |
| org | `visa.umaxica.org` | `www.umaxica.org` | `auth.umaxica.org` | `visa-org-ww`, `base-org-ww` | `VISA_ORG`, `BASE_ORG` |

- OP controllers: `Visa::{App,Com,Org}::…` in `config/routes/visa.rb` (D-59). Base RP client IDs
  `base-{app,com,org}-ww` are unchanged.
- Development/test hosts follow `ConfigValues::HostFamilyValues`: today Base uses
  `base.app.localhost` plus `www.umaxica.app` (`development_host`), keys
  `BASE_SERVICE_URL`/`PUBLIC_BASE_SERVICE_URL` etc. Proposed for Visa: `visa.app.localhost` /
  `visa.umaxica.app` (and `.com`/`.org`), keys `VISA_{SERVICE,CORPORATE,STAFF}_URL` and
  `PUBLIC_VISA_{SERVICE,CORPORATE,STAFF}_URL`. Confirm the exact convention in
  `lib/config_values_host_family_values.rb` while implementing.
- Rails session cookie host-only everywhere (D-58, done), so Visa and Base hold separate sessions.

### 2.2 Ownership matrix — app realm (com/org deltas in §2.3)

Method: `bin/rails routes` + controller ancestry (`Authority` = inherits
`Base::App::AuthorityController`; `RP` = `Base::App::ApplicationController`; `Bare`; `API` =
`ActionController::API`), `AUTHENTICATION_MODE`, forgery strategy and callbacks, plus reading of the
concerns named. All Base HTML controllers use `protect_from_forgery with: :exception` and
`verify_authenticity_token`; Authority and RP controllers also run `verify_jump_return_rt!`.
Classification: **V** Visa, **B** Base, **A** Auth (unchanged), **D** *Decide* (§2.4), **X** removed
by WU-01.

| Route(s) | Controller (base, mode) | Class | Notes |
|---|---|---|---|
| `GET/POST /oauth/authorize` | `oauth/authorizations` (Authority, open) | **V** | Authorization request, Auth→Base result receipt, Cancel/Switch continuation, Root Session establishment (`log_in`, `reset_session`). Carries `# FIXME` (multi-job, one.md T4) |
| `POST /oauth/token` | `oauth/tokens` (API) | **V** | `private_key_jwt`; audience/endpoint URLs change with the issuer |
| `GET/POST /oauth/userinfo` | `oauth/userinfos` (Bare, open) | **V** | |
| `POST /oauth/revoke` | `oauth/revocations` (Bare, open) | **V** | |
| `POST /oauth/refresh-deliveries/query` | `oauth/refresh_delivery_queries` (API) | **V** | Removed by D-25 (receipt machinery) in a later unit; move or remove, do not keep both |
| `GET /.well-known/openid-configuration` | `well_known/discoveries` (Bare) | **V** | Issuer becomes the Visa origin |
| `GET /.well-known/jwks.json` | `well_known/jwks` (Bare, `JWT_KEY_NAMESPACE = "BASE_APP"`) | **D** (both) | Serves the `BASE_APP` key set, used for OP tokens and for Jump RTs issued by Base. Visa needs its own `VISA_APP` set; Base RP still issues Jump RTs (to Visa, Core, Warp, Palm) and keeps `BASE_APP`. See §2.4 D-K |
| `GET/POST /oidc/logout` | `oidc/logouts` (Authority, open) | **V** | End-session endpoint (T9) |
| `GET/POST /sign/bye` | `sign_byes` (Authority, open; `BaseSignBye`) | **V** | Shows the committed **OP** logout outcome and consumes the browser-bound `LogoutReceipt`. Receipt must be bound to the Visa session (R3) |
| `GET/PATCH/POST/DELETE /sign/in/limitation` | `sign/in/limitations` (Authority, open) | **V** | Session-limit resolution before Root issuance; reached from `AuthenticationSequenceGate#sign_in_session_limit_path` on the OIDC path |
| `GET/POST /social/authentication/completion` | `social/authentication/completions` (Authority, open) | **V** | Google/Apple **sign-up** only: Auth birthdate pages (`SignUpSocialBirthdateSupport`) → this receiver (a result-continuation page with a button) → it records the sign-up commit and, for an OIDC parent (`binding.parent_kind == :authorization_transaction`), issues an OIDC result and redirects to `/oauth/authorize` (`handoff_social_signup_oidc!`). The other branch, `complete_social_signup_local_login!` (`log_in`), is the Local remnant (WU-01). Social **sign-in** does not use it (Auth `/sign/oidc/handoff`). An extra relay page on the sign-up path (one.md T1) |
| `GET/POST /ceremony_bindings/:ref/confirmation` | `ceremony_binding_confirmations` (Authority, open) | **V + B** (D-61) | Split: Sign-in path purposes on Visa; Re-verification purposes stay on `www`; each refuses the other |
| `GET /edge/v0/token/check`, `POST /edge/v0/token/refresh`, `POST /edge/v0/token/dbsc` | `edge/v0/token/*` (Authority, deny_all) | **V** (provisional) | Root-cookie check/refresh and DBSC registration; DBSC binds the cookies of the host that issued them, and login emits the DBSC registration header for `/edge/v0/token/dbsc`. Edge-side callers are out of scope (handoff) |
| `GET/PATCH/PUT /edge/v0/cookie` | `edge/v0/cookies` (Authority, open) | **D** | Preference cookie-consent endpoint under the Authority base (W10). Owner of the consent cookie (Base RP pages) vs Authority base — see §2.4 D-E |
| `GET/POST /sign/completion` | `sign/completions` (Authority) | **X** | Local Sign-in Flow receiver (WU-01) |
| `GET/POST /sign` | `sign/entries` (RP, open; `OidcRpSignEntry`) | **B** | RP sign entry. Its override keeps a same-origin authorize URL direct because Jump refuses `url` origin == `iss`; after the split the authorize URL is cross-host, so the override goes and the shared Jump decision applies (D-52) |
| `GET /oidc/callback` | `oidc/callbacks` (RP, open) | **B** | RP callback; pending flow in the `www` session (G1 fixed structurally). Issuer allowlists in `OidcCallback` (`hosts.base_*`) change to Visa |
| `POST /oidc/backchannel-logout` | `oidc/backchannel_logouts` (API; `RpBackchannelLogoutEndpoint`) | **B** | Base RP's BCL receiver; verifies Visa-issued logout tokens |
| `/sign/out*` (show/new/edit/create/completion) | `sign_outs` (RP, open; `OidcRpLogoutLauncher`) | **B** | RP-initiated logout launcher: clears RP cookies, sends the browser to Visa `/oidc/logout` (R3) |
| `POST /sign/out/purge` | `sign/cookie_purges` (RP, open; `RpCookiePurgeEndpoint`) | **B** | RP cookie purge of this host |
| `/verification`, `/verification/{setup,completion,cancellation}` | `verifications`, `verification/*` (RP, private) | **B** | Re-verification path (D-44, D-61); Auth hands results back to `www` (`base_app_verification_completion_url`) |
| `/welcome` | `welcomes` (RP, private; `SignInWelcomeGate`) | **B** | Stays on Base RP (D-62). The OP-written welcome gate is issued only on the non-OIDC branch (WU-01 remnant), so on the OIDC path the page just redirects to the dashboard; after WU-01 the gate dependency is removed and any welcome decision is made by the RP from its verified callback and RP state |
| `/selector` | `selectors` (RP via `PreAccessController`, private) | **B** (+ OP step on Visa) | Two different things share the name. (1) The sign-in flow's `SELECTOR_PENDING` step is auto-committed **at Root issuance** (`AuthenticationBase#advance_sign_in_flow_to_issuance!` → `SignInSelectorParticipant#auto_commit_single!`), i.e. on the OP → moves with Root issuance to Visa. (2) Base `/selector` is an RP page after the RP session exists: `current_session` is the root token resolved from the RP access state (DB, not the root cookie), and `BaseSelectorAuthority.select` returns the selection. Its `enforce_sign_in_phase_binding!("SELECTOR_PENDING")` only acts on a session-located flow (local remnant, WU-01); `continue_selector_sequence!` is removed (D-64) |
| `/`, `/dashboard`, `/identity/**`, `/preference/**`, `/avatars/**`, `/groups/**`, `/accounts`, `/organizations/**`, `/billings`, `/secrets/**`, `/secret_issuances/**`, `/switcher`, `/sessions/**`, `/api/v0/**` (avatar, membership, identity, preferences) | RP / API | **B** | Base RP and its APIs. Credential management pages start the Re-verification path on `www` |
| `/identity/recovery/**` | RP, open (`EnforcementRecoveryCeremonyCookie`) | **B** | Enforcement recovery and appeals with its own ceremony cookie; not a Root Session path |
| `/identity/withdrawal*`, `/identity/privacy/erasure*` | RP, open (`WithdrawalCeremonyAuthentication`) | **B** | Withdrawal ceremony with its own cookie |
| `/preference/emails/:id` | Bare | **B** | Mail preference links |
| `/health*`, `/revision`, `/api/v0/{health,revision}.json`, `/robots.txt`, `/sitemap.xml`, `/csp-violation-report` | Bare | **B + V** | Operational endpoints; Visa gets its own health/revision/robots (no sitemap; robots disallow all) and CSP report endpoint |

### 2.3 com / org deltas

- **com:** same Authority set as app except no `social/authentication/completion` (COM has no social).
  RP adds `identity/recovery_secrets`. `oauth/tokens` is `Bare` on com (API on app) — keep each
  realm's base when moving.
- **org:** same Authority set as app except no social completion. Many more org APIs under
  `/api/v0/**` (support, IAM grants, tech capability checks, publishing, avatar) — all **B**.
  Entra sign-in runs in Auth. RP has no recovery pages.

### 2.4 Breakage dependencies and decisions (*Decide*)

| ID | Dependency found | Why a plain move breaks | Proposal |
|---|---|---|---|
| R1 | `JumpRtSurface.namespace_for_controller` maps `Base::` → `BASE_*`; `ISSUER_ORIGIN_ENV` maps namespaces to `PUBLIC_BASE_*_URL`; `JumpRtReturnPolicy::ALLOWED_EDGES` lists `BASE_*`↔`AUTH_*`, `CORE_*`, `WARP_*`, `PALM_APP` | A Visa controller under `Base::` would sign as `BASE_*` with a `www` origin | **Owner, 2026-10-21: the Jump edge list is not decided in this repository; the Edge (Hono) side is changed at integration-test time.** Rails side: `Visa::` namespace → `VISA_*` issuer namespace and origin. Deliverable when WU-02 is implemented: a Jump contract written so that an AI or person who cannot read Ruby can check it — (1) one data table in code listing every Rails-issued edge (issuer namespace, origin, destination namespace, purpose), (2) a test that compares that table with what Rails actually signs, (3) a doc (`docs/` + handoff) that reproduces the table in plain language with the JWKS URL, `iss`/`aud` and the refusals Jump must keep |
| R2 | `base_authority_host` in `Auth::{App,Com,Org}::ApplicationController` (`ENV.fetch("PUBLIC_BASE_*_URL")`) is used for **OP** targets (`base_*_oauth_authorization_url` in `Sign::OidcHandoffsController`, `base_*_sign_completion_url`, `base_app_social_authentication_completion_url`) and for **RP** targets (`base_*_identity_url`, `base_app_dashboard_url`, `base_*_verification_completion_url`) | One host value cannot point at two hosts | Two explicit contracts: an OP (Visa) origin for result/authorization targets and a Base RP origin for identity/dashboard/re-verification targets. Every call site classified; no fallback between them |
| R2b | Other `hosts.base_*` readers: `OidcIssuer`, `ConfigValues::OidcAuthorityValues`, `OidcClientRegistry`, `StaticClientStore` (`BASE_*_URL`), `OidcSsoInitiator` (`oidc_base_service_origin`), `OidcCallback` issuer allowlists, `JitSecurityJwtRegistry`, `PreferenceJwtConfiguration`, `FqdnAvailabilityRegistry`, CSP `form-action`, `production.rb` `config.hosts` and mailer host, omniauth host lists, `AcmeLogoutTransactionCoordinator`, `authentication_client`/`_operator`/`_visitor` cookie host, `Auth::Org::SignUpsHelper`, telephone registration | Each means either "OP" or "RP"; today they coincide | Classify each (OP → Visa host value; RP → Base) in the implementation definition; add Visa to host registries and CSP explicitly, no wildcard |
| D-K | One `BASE_{APP,COM,ORG}` surface key (`JWT_BASE_*_PRIVATE_KEY`, `_PUBLIC_KEYSET`, `_ACTIVE_KID`; ES384 / P-384) signs today: OP JWTs (`OidcIssuer.jwt_issuer_id_for_resource_type` → `surface:BASE_*`), root access tokens (`AuthenticationJwtTokens#auth_jwt_namespace` from `controller_path`), Base Jump RTs (`JumpRtKeyring`), and ceremony contract tokens (`Identity*CeremonyContract#acme_issuer_id` → `surface:BASE_*`). Published at `www` `/.well-known/jwks.json` | Visa must publish its own JWKS at its issuer and sign OP tokens with its own key; Base keeps its key for its Jump RTs | Add `VISA_APP`, `VISA_COM`, `VISA_ORG` to `JitSecurityJwtRegistry::SURFACE_NAMESPACES` (+ issuer origins). Development/test keys are generated by `JitSecurityJwtLocalKeysetInstaller` (`tmp/local_jwt_keysets.json`). **Production: owner provides three ES384 (P-384) key sets** in credentials: `JWT_VISA_{APP,COM,ORG}_PRIVATE_KEY`, `JWT_VISA_{APP,COM,ORG}_PUBLIC_KEYSET`, `JWT_VISA_{APP,COM,ORG}_ACTIVE_KID` (AWS KMS later, D-17). Ceremony contract tokens: classify per path (Sign-in path → `VISA_*`, Re-verification path stays `BASE_*`) |
| D-S | Post-login sign-in sequence in the Rails session: welcome gate (`issue_welcome_gate_and_path` → `session[welcome_gate_key]`), `SignInSequenceCarrier.new(session, …)`, phase binding for `/welcome` and `/selector` | Written at Root issuance (Visa after the split), read on Base RP pages | **Finding 2026-10-21:** under an OIDC parent, `AuthenticationSequenceGate` redirects to `after_login_path` (`if oidc_authorization_login_challenge.present?`); the welcome gate is issued only on the non-OIDC (local) branch. On the OIDC path `/welcome` sees no gate and redirects to the dashboard. `continue_selector_sequence!` (calls `log_in`) has **no caller in `app/`** since `e2b87fde9a` (2026-10-08); only `test/controllers/concerns/authentication/sequence_gate_extra_coverage_test.rb` calls it. Likely outcome: (c) local remnant — add to WU-01's check list; confirm before WU-02 moves anything |
| D-E | `/edge/v0/cookie` (`Base::*::Edge::V0::CookiesController`, Authority base, `PreferenceWebCookieEndpoint`): GET returns `show_banner` and DBSC data, PATCH applies the cookie-consent decision and sets the consented buffer cookie | Legacy route vocabulary: `adr/api-route-vocabulary-consolidation.md` (Accepted) moves APIs to `/api/v0`; the browser now uses `/api/v0/preferences/cookie` (`PreferenceBrowserControlsRegistry`), and **no caller of `/edge/v0/cookie` exists in `app/` or `src/`** (tests and docs still reference it). An Edge (Hono) caller is not visible from this repository | Do not move it to Visa. Candidate for removal (with the owner confirming no Edge caller), handled like WU-01; never moved under the Authority base of Visa |
| R3 | Logout: RP launcher on `www` clears RP cookies and sends the browser to Visa `/oidc/logout`; Visa revokes Root/grant and shows `/sign/bye` with a `LogoutReceipt` bound to the Visa session; BCL to every RP including Base; `AcmeLogoutTransactionCoordinator` picks `hosts.base_*` for the return host | Visa cannot delete `www` host-only cookies; a receipt bound to the `www` session cannot be read on Visa | Keep the authority-first order; Visa never touches Base cookies; Base clears its own before leaving and on BCL. Tests for order, double execution, retry, timeout, already-revoked session |
| R6 | Host registration: `FqdnAvailabilityRegistry` (Flipper), `config.hosts` (production), CSP, Host Authorization, development host lists | A new host that is not registered fails closed (good) but nothing works | Add exactly the three Visa hosts in every registry; no wildcard; unknown look-alike hosts stay refused (test) |
| R7 | Issuer change: Discovery, `iss` in ID Token and authorization response (RFC 9207), token endpoint audience for client assertions, logout token `iss`, every RP's expected issuer | Partial change leaves verifiers rejecting or, worse, accepting two issuers | One issuer per realm (Visa), switched everywhere in one change; no dual-issuer acceptance (no compatibility, never deployed) |

### 2.4a Resolution of the Phase 1 decisions (owner + ChatGPT review H9, 2026-10-21)

Phase 1 is approved (Visa/Base/Auth split, `Visa::` + `config/routes/visa.rb`, Base RP client IDs
kept). Binding resolutions for the implementation definition:

1. **D-K adopted, in the current key style (D-65).** Add `VISA_*` exactly as the existing namespaces are handled; do not fix the credentials name mismatch, rename other namespaces or remove `ACME_*` here (backlog `2026-10-21-production-credentials-key-name-mismatch.md`). Visa gets independent `VISA_{APP,COM,ORG}` JWT namespaces, signing keys and
   JWKS; Base keeps `BASE_*` for its Jump RTs. The public OIDC issuer and every token signer move to
   Visa together (no token signed with a `BASE_*` key under a Visa `iss`). Production key material
   is a separate owner task, not part of the code change; development/test keys come from
   `JitSecurityJwtLocalKeysetInstaller` once the namespaces are added.
2. **D-S split into two problems.** Welcome stays on Base RP and decides what to show from the
   verified OIDC callback result and RP-side state, never from a gate written by the OP. Selector:
   classify each step as before Root issuance (OP) or after RP session establishment (RP) by
   reachability first, then assign ownership. `continue_selector_sequence!` is removed as dead code
   (owner; WU-01 list). **Sharing a Rails session between Visa and Base is forbidden** as a fix.
3. **D-E: cookie consent belongs to Base RP.** `/edge/v0/cookie` is removed on app/com/org (owner:
   the frontend is being rebuilt; no in-repository caller exists) — WU-03. Confirm that
   `/api/v0/preferences/cookie` covers the behavior the browser needs, consistent with
   `adr/api-route-vocabulary-consolidation.md` (`/api/v0` only; `/edge/v0`, `/web/v0` legacy).
4. **Identifiers.** `visa-{app,com,org}-ww` are logical host identities; they are not OIDC client IDs
   and must not be registered or validated as clients. Base RP client IDs stay
   `base-{app,com,org}-ww`.
5. **Ceremony binding.** Each confirmation endpoint verifies purpose ↔ host fail-closed: Visa accepts
   only Sign-in path purposes, `www` only Re-verification path purposes; anything else is refused
   before any state change.
6. **R2 approved.** Separate settings: Visa OP `PUBLIC_VISA_{SERVICE,CORPORATE,STAFF}_URL` (and the
   boot-config keys that follow the existing convention), Base RP the existing `PUBLIC_BASE_*`. No
   fallback in either direction; a missing value fails at boot. Return target is chosen by the
   ceremony's requester and result receiver: Visa for sign-in/sign-up results, `/oauth/authorize`
   handoff, social sign-up completion and anything that establishes a Root Session; Base for
   dashboard/identity links, Re-verification completion (`/verification/completion`) and anything
   belonging to the RP session. Every reader of `base_authority_host`, `PUBLIC_BASE_*`,
   `hosts.base_*` and Base URL helpers is classified (OP / RP / other) — no string replacement.
   `base_authority_host` is renamed to names that state the role (e.g. a Visa authority host and a
   Base RP host), following existing naming. Required tests per realm: sign-in result returns to
   Visa; sign-up result returns to the Visa path; Re-verification completion returns to Base;
   dashboard/identity links point to Base; missing Visa setting does not fall back to Base; wrong
   realm/host/purpose combinations are refused. Never expose session proofs in URLs or skip result
   verification to make the split work.
7. **Order kept:** Rails side complete with TDD → Jump change (Edge/Hono) → integration test. No
   Jump change and no browser E2E in this work.

### 2.5 Owner actions and limits

- New Visa key material in credentials (D-K).
- Jump repository change and integration test: out of scope (H8 R8); a handoff specification is
  a deliverable.
- No browser E2E (H8); Rails unit/controller/integration/contract tests only, with per-host cookie
  jars in integration tests (not proof of real browser behavior).
- WU-01 should land first; until then the matrix marks the Local receiver **X** and does not move it.

### 2.6 Implementation definition (steps)

> **Grouping (D-161, 2026-10-23):** the steps below describe *what* changes. They are executed only
> as the sub-units in Part 4 "WU-02 sub-units": V1–V2 = 02a, V3 = 02b, V4–V10 per realm = 02-APP,
> 02-COM, 02-ORG (one commit each), V11 = 02i. "Realms app, com and org in every step" below means
> "in each realm's own sub-unit". Provider callbacks never move (D-161 (4)).

(Revocation client authentication moved out to WU-25, D-79.)

Preconditions: WU-04 and WU-05 done (D-69 order; after WU-05 no social sign-up receiver remains on
Base). WU-01 and WU-03 done or done first (no dead local routes or `/edge/v0/cookie` to move).
Baseline full-suite failure set recorded. Each step: Red → Green → Refactor, the step's tests plus
the affected realm suites, compared with the baseline. Realms app, com and org in every step unless
stated.

| Step | Change | Tests (Red first) | Exit |
|---|---|---|---|
| V1 Host contract | `ConfigValues::HostFamilyValues`: `visa_service`, `visa_corporate`, `visa_staff` (development/test hosts `visa.{app,com,org}.localhost` and `visa.umaxica.{app,com,org}` per the existing `development_host` pattern; keys `VISA_{SERVICE,CORPORATE,STAFF}_URL`, public `PUBLIC_VISA_*_URL`, read with one-argument `ENV.fetch`, no default). Register exactly these hosts in `FqdnAvailabilityRegistry` (Flipper), production `config.hosts`, CSP `form-action`, OmniAuth host lists where the OP is involved; no wildcard | Request tests: an OP route answers only on its Visa host and is not routable on `www`/`auth`; a look-alike host (e.g. `visa.umaxica.app.example`) is refused. Configuration values themselves are **not** Minitest subjects (`project/no-environment-tests.mdc`): boot with a missing `VISA_*` and record the fail-closed result in `evidence/` | Boot fails without the Visa settings; host-exclusivity tests green |
| V2 JWT namespaces (D-65) | Add `VISA_{APP,COM,ORG}` to `JitSecurityJwtRegistry::SURFACE_NAMESPACES` and `SURFACE_ISSUER_ORIGINS`, and to `JumpRtSurface::ISSUER_ORIGIN_ENV` (`PUBLIC_VISA_*_URL`); development/test keys come from `JitSecurityJwtLocalKeysetInstaller`; `BASE_*` stays | Registry builds `surface:VISA_*`; Visa JWKS publishes only `VISA_*` keys; Base JWKS only `BASE_*` | Both JWKS endpoints serve disjoint key sets |
| V3 Visa skeleton | `app/controllers/visa/{app,com,org}/` with the Authority base (from `Base::*::AuthorityController`) and its own `BareController`; `config/routes/visa.rb` with per-realm host constraints; Visa health/revision/robots (disallow all) and CSP report endpoint | Routing and base-class tests (`Visa::` controllers inherit only the Visa bases; no RP concern included) | Empty Visa surface boots and routes on its hosts only |
| V4 Move OP endpoints | Per §2.2 **V** rows: `/oauth/{authorize,token,userinfo,revoke}`, `/oauth/refresh-deliveries/query` (or remove under D-25 — not both), `/.well-known/{openid-configuration,jwks.json}`, `/oidc/logout`, `/sign/bye`, `/sign/in/limitation`, `/edge/v0/token/*`. Move controllers and concerns into `Visa::`, update URL helpers (`base_*_oauth_*` → `visa_*_…`), delete the Base copies (no aliases, no redirects) | Existing endpoint tests re-pointed to the Visa host and helpers (they assert the same behavior on the new host); a request to the old Base path is not routable | No OP route left under `config/routes/base.rb` |
| V5 Issuer switch (R7) | `OidcIssuer#host_for_resource_type` → Visa hosts; `jwt_issuer_id_for_resource_type` → `surface:VISA_*`; `ConfigValues::OidcAuthorityValues`; `OidcClientRegistry` / `StaticClientStore` expected issuer and endpoints; `OidcCallback` issuer allowlists (`hosts.base_*` → Visa); `OidcSsoInitiator` authorize origin (`oidc_base_service_origin` → Visa); remove `Base::*::Sign::EntriesController#oidc_redirect_decision` (same-origin override; Base → Visa is now a Jump handoff, D-52); token-endpoint audience of client assertions; logout-token `iss`; Discovery. One issuer per realm, switched in one change | Discovery `issuer` equals the Visa origin; ID Token / authorization response (RFC 9207) / logout token `iss` equal it; a token with the old `www` issuer is refused; client assertion with the old audience refused; unregistered `redirect_uri` refused; PKCE and `state`/`nonce` checks unchanged | No `www` issuer accepted anywhere |
| V6 R2 host split in Auth | Replace `base_authority_host` with two explicit contracts (a Visa authority host and a Base RP host, names per existing conventions); classify every reader listed in §2.4 R2/R2b and switch each to its role; no fallback between them | D-62 #6 test list per realm: sign-in and sign-up results return to Visa; Re-verification completion returns to Base; dashboard/identity links point to Base; missing Visa setting does not fall back; wrong realm/host/purpose refused | `base_authority_host` gone; every reader classified in the WU report |
| V7 Ceremony binding split (D-61, D-62 #5) | Visa `ceremony_bindings/:ref/confirmation` for Sign-in path purposes; `www` keeps the Re-verification one; each refuses the other's purposes before any state change | Purpose ↔ host matrix tests (both directions, every realm); browser-binding mismatch refused; G1 regression: Visa `reset_session` leaves Base's pending OIDC flow intact (per-host cookie jars) | TR G1 tests pass for the right reason |
| V8 Jump contract (R1, Rails side only) | One data table in code of every Rails-issued edge involving Visa (issuer namespace, origin, destination namespace, purpose: e.g. `BASE_*` → `VISA_*` sign start, `VISA_*` ↔ `AUTH_*` ceremony, `VISA_*` → `BASE_*`/`CORE_*`/`WARP_*`/`PALM_APP` authorization responses); `JumpRtSurface.namespace_for_controller` maps `Visa::` → `VISA`; `JumpRtReturnPolicy::ALLOWED_EDGES` extended to match the table | A test compares the table with what Rails signs and verifies; no change to open-redirect, signature or CSRF checks | Handoff document for the Edge (Hono) change with the table in plain language, JWKS URLs, `iss`/`aud`, refusals Jump must keep; integration not claimed |
| V9 Logout (R3) | Base launcher clears Base cookies, sends the browser to Visa `/oidc/logout`; Visa revokes Root/grant, binds the `LogoutReceipt` to the Visa session, shows `/sign/bye`; BCL to every RP including Base; `AcmeLogoutTransactionCoordinator` return host = Base RP; Visa never touches Base cookies | Order, double execution, retry, timeout, already-revoked session, cookie ownership per host | Logout tests green per realm |
| V10 Sign-in sequence steps | The OP-side selector auto-commit and session-limit resolution run on Visa with Root issuance; Base `/selector` and `/welcome` stay RP-only (after WU-01 removes their session-gate remnants) | Root issuance with a selector-pending flow on Visa; Base pages work with RP state only | No Base page reads OP-written Rails-session state |
| V11 Docs and ADR | New ADR "Visa OP host" (supersedes the same-FQDN part of `adr/base-authority-and-self-rp-separation.md`; references D-58/D-59/D-61/D-65); README routing, `docs/dds.md`, `docs/security/*` host lists; evidence | — | Docs match the code |

Out of scope (H8): Jump/Edge repository change, deployed Jump configuration, Jump integration
test, browser E2E. Production `JWT_VISA_*` credentials are the owner task in
`plans/backlog/2026-10-21-production-credentials-key-name-mismatch.md`.

Note on H8 vs repository rules: H8 asks for tests of Host Authorization, CSP and Flipper; the
repository forbids Minitest whose subject is configuration (`project/no-environment-tests.mdc`).
V1 resolves it by testing **request behavior** (which host answers which route, look-alike refusal)
and recording configuration checks in `evidence/`.

---

## WU-03 — Remove the legacy `/edge/v0/cookie` entry point

**Why.** `adr/api-route-vocabulary-consolidation.md` (Accepted) makes `/api/v0` the only API
namespace; the browser already uses `/api/v0/preferences/cookie`
(`PreferenceBrowserControlsRegistry#cookie_endpoint_path`). `/edge/v0/cookie`
(`Base::{App,Com,Org}::Edge::V0::CookiesController`, under the Authority base) has no caller in
`app/` or `src/`; the owner confirmed the frontend is being rebuilt and the entry point is to be
removed (D-63). Cookie consent belongs to Base RP.

**Scope.** Routes `GET/PATCH/PUT /edge/v0/cookie` on app/com/org; the three controllers; any helper
used only by them (check `PreferenceWebCookieEndpoint#apply_consented_update_from_request!`, whose
comment names this entry point); tests and docs that reference the route
(`test/integration/preference_credential_recovery_matrix_test.rb`,
`test/integration/routes/core_route_contract_test.rb`,
`test/integration/routes/legacy_api_namespace_guard_test.rb`,
`test/security/invariants/withdrawal_gate_invariant_test.rb`,
`test/lib/runtime_role_route_ownership_test.rb`, `test/unit/security/forbidden_rails_patterns_test.rb`,
`test/unit/security/ri_routing_contract_test.rb`, `docs/security/db-write-allowlist.md`,
`docs/architecture/preference-behavior-contract.md`, the ADR's observed-facts list as history).
`/edge/v0/token/*` is **not** in scope (it moves to Visa in WU-02).

**Checks.** Same dead-code check as WU-01 (callers, reachability, unchanged behavior of
`/api/v0/preferences/cookie`). Before deleting, compare the two endpoints: anything the browser
needs that only `/edge/v0/cookie` provides (e.g. the DBSC payload in its JSON) is reported, not
silently dropped.

**Red/Green.** Red: requests to `/edge/v0/cookie` on each realm are not routable; the
`/api/v0/preferences/cookie` behavior tests stay green. Green: remove routes, controllers and
now-unused helpers; update the route-contract tests to the final route set (they assert the final
behavior only).

**Exit.** No `/edge/v0/cookie` route or controller remains; `grep -rn "edge/v0/cookie" app config src`
is empty; docs updated; evidence recorded.

---

## WU-04 — Sign-up telephone SMS OTP (app and com): add visible Turnstile

Recorded as a security-audit inconsistency (H10, D-66): an implementation mistake, not a policy
change.

**Finding (code reading 2026-10-21 at `febec3225`).** App sign-up applies visible Turnstile on both
contact steps for email but only on the first step for telephone:

| Check point | Email | Telephone |
|---|---|---|
| Registration start (`POST /sign/up/email`, `POST /sign/up/telephone`) | visible (`Auth::App::Sign::Up::EmailsController`) | visible (`Auth::App::Sign::Up::TelephonesController`, `cloudflare_turnstile_validation` before OTP issuance) |
| OTP check (`PATCH` on `sign/up/check/{email,telephone}/otp`) | visible: `Check::Email::OtpsController#update` calls `verify_otp_turnstile!` before `verify_otp_ceremony!` | **none**: `Check::Telephone::OtpsController#update` goes from the session check straight to `verify_otp_ceremony!`, then `verify_telephone_ownership!` and `advance_sign_up_after_contact_otp!` |

`adr/turnstile-visible-placement-policy.md` (Accepted) puts visible Turnstile on browser-rendered
forms that "create, resume, verify, or mutate sign-up … state", so the telephone OTP check is in
scope of the existing policy. `adr/sign-up-checkpoint-turnstile-boundary.md` exempts only the
checkpoint actions (birthdate, passcode, passkey) that follow a Turnstile-protected sequence.

**Scope.** App only. Telephone SMS OTP check page and its `update`. Google/Apple unchanged
(provider-delegated, ADR). No Turnstile on birthdate or passkey checkpoint (ADR kept). Visa
separation, sign-up finalization and the Google/Apple route discussion keep their agreed direction.
**COM added (owner, D-67):** COM has the same gap — `Auth::Com::Sign::Up::Check::Telephone::OtpsController`
has no Turnstile while `Auth::Com::Sign::Up::Check::Email::OtpsController#update` calls
`verify_otp_turnstile!` before `verify_otp_ceremony!`, and `Auth::Com::Sign::Up::TelephonesController`
already applies visible Turnstile at registration start. Every design point, security condition,
test and doc change below applies to COM as well, with COM's own controllers, messages and page
(do not share controllers or views across surfaces). ORG has no telephone sign-up.

**References.** `app/controllers/auth/app/sign/up/check/email/otps_controller.rb`,
`app/controllers/auth/app/sign/up/emails_controller.rb`,
`app/controllers/auth/app/sign/up/check/telephone/otps_controller.rb`,
`app/controllers/auth/app/sign/up/telephones_controller.rb`,
`src/features/auth/signup/OtpVerificationForm.tsx` (already renders `TurnstileWidget` when the
`turnstile` prop is given), `CloudflareTurnstile`, `TurnstilePageProps`.

**Design.**
- The telephone OTP page receives `turnstile: turnstile_visible_props` exactly as the email OTP page
  does (a fresh `challenge_id` on each render that can be retried).
- `Check::Telephone::OtpsController#update` runs the server-side Turnstile validation right after
  the gate and session checks and **before** reading or verifying the code — before OTP lookup,
  consumption, `verify_telephone_ownership!` and any Sign-up Flow transition.
- Reuse `CloudflareTurnstile`; extracting the email and telephone OTP checks into one shared concern
  is allowed only if the email OTP behavior stays byte-for-byte the same (same order, messages,
  status codes, events). Follow `generic/rails-concerns.mdc` if a concern is added.

**Security conditions.**
1. A Turnstile success is required for the telephone OTP check.
2. Missing token, invalid token and a failed verification are refused.
3. On refusal the OTP is not consumed (attempt counters and lock state unchanged), the Sign-up Flow
   does not advance, and no telephone verified state is established.
4. The page re-renders with an error and a new Turnstile challenge so the user can retry.
5. Only when both Turnstile and the OTP succeed does the flow continue to the existing Passkey
   registration path.

**Tests (TDD, Red → Green → Refactor).** For the app and com telephone OTP checks (each realm separately): valid Turnstile + valid
code proceeds; missing token, invalid token and verification failure are refused with the error
page; each refusal leaves the OTP unconsumed and the flow and telephone state unchanged; a retry
with a new challenge and a valid code succeeds. Email OTP: run the existing tests as regression and
add none that change its contract. The page props test asserts the Turnstile props on the telephone
OTP page. Use the existing Turnstile test stub (`test/support/turnstile_verifier_stub.rb`).

**Docs.** Add the OTP check rows (email and telephone, app and com) to the visible placement table in
`docs/security/turnstile.md` (today the table lists only the registration-start rows) and record
the fix as a resolved audit inconsistency (evidence record with the before/after test runs).

**Exit.** Telephone OTP check refuses without a valid Turnstile before touching the OTP; email OTP
behavior unchanged; tests and the placement table updated; evidence recorded.

---

## WU-05 — Sign-up six-path unification (App email/telephone/google/apple, Com email/telephone)

> **Implement through sub-units WU-05a … WU-05g only (D-133, Part 4).** This section stays the contract.

Source: owner + ChatGPT handoff H11 (2026-10-21). Status: **investigation and plan only; no
implementation until the owner resolves U1–U6.** Static reading at `febec3225` + uncommitted work.
Goal (H11): four independent entry methods (two on Com), independent requirements and credential
checks, one sign-up Finalization contract, then Sign In First into Visa; Root Session by Visa, RP
Session by Base. Org and Com social are out of scope.

### 5.A Current six-path matrix

| Stage | App email | App telephone | App google / apple | Com email | Com telephone |
|---|---|---|---|---|---|
| Entry (Auth) | `Sign::Up::EmailsController` | `Sign::Up::TelephonesController` | OmniAuth callback `Auth::App::Omniauth::OmniauthCallbacksController` creates `ClientSignUpFlow` (`create!` at ~L311 / ~L470) under a sign-up admission | `Auth::Com::Sign::Up::EmailsController` | `Auth::Com::Sign::Up::TelephonesController` |
| Requirements (`SignUpRequirementRegistry`) | `otp birthdate` | `otp passkey birthdate` | `confirmation birthdate` (`social: true`) | `otp birthdate` | `otp passkey birthdate` |
| Turnstile at start | visible | visible | delegated to provider | visible | visible |
| Turnstile at OTP / confirmation | visible (`verify_otp_turnstile!`) | **missing** (WU-04) | visible, ceremony-bound: `Turnstile::VerifierFactory.current.verify_for_ceremony` with action `social_signup_confirmation`, hostname, cdata = flow public id (`Check::{Google,Apple}::ConfirmationsController`) | visible | **missing** (WU-04) |
| **Pending account created** | Auth, at registration start: `EmailSignUpCandidateCreator` → `Client.create!(status UNVERIFIED_WITH_SIGN_UP)` | Auth: `TelephoneSignUpCandidateCreator` | **none in Auth**; provider evidence held in `IdentitySocialCeremonyCandidateStore` / replay store | Auth: `EmailSignUpCandidateCreator` → `Visitor.create!` | Auth: `TelephoneSignUpCandidateCreator` |
| Birthdate | Auth, saved on the pending actor (`SignUpSequenceControllerSupport#clear_sign_up_birthdate_requirement`) | same | Auth page, but `SignUpSocialBirthdateSupport` overrides the shared method: no actor exists, the birthdate goes into a signed social ceremony result | same (Visitor) | same |
| **Finalization** | Auth: `finalize_sign_up_from_checkpoint!` (cycle row lock → `finalize_sign_up_side_effect!` → `SignUpStateMachine :finalize` → `IdentityGraphProvisioner` → `:complete` → `handoff_to_sign_in_flow!`) | same, telephone branch of `finalize_app_sign_up_actor!` (`SignAppUpTelephoneRegistrationFinalizer`) | **Base** `/social/authentication/completion` (a Continue page, then POST): `IdentitySocialCeremonyFinalCommitter#commit_signup!` → `ExternalAuthenticationSignupUseCase` → `SocialAuthSignupFinalizer` (Client + External Identity, App principal DB) → result consumption (OP ticket DB) → `IdentityGraphProvisioner` → `SignUpStateMachine :finalize/:complete` | same path as App email (`finalize_com_sign_up_actor!`) | same (`SignComUpTelephoneRegistrationFinalizer`) |
| Sign-in handoff | `handoff_to_sign_in_flow!` → `establish_signed_in_session!` → canonical Sign In flow in Auth (guardrail, checkpoint, MFA, selector) → OIDC evidence → Base `/oauth/authorize` | same | **no canonical Sign In flow**: Base `handoff_social_signup_oidc!` calls `BaseAuthAdmissionCoordinator.register_result_and_issue!` directly, then `/oauth/authorize` | same as App email | same |
| Root Session | Base `/oauth/authorize` (`log_in`: cooldown, session limit) | same | same | same | same |

Transactions: the shared finalizer holds the sign-up flow row lock (OP ticket DB) while writing the
principal DB; the social committer nests App principal and OP ticket transactions. Neither is one
atomic transaction across databases (`adr/global-regional-database-ownership.md`); partial-failure
behavior is today defined by locks, state checks and the one-shot result.

### 5.B Parts

| Class | Parts |
|---|---|
| Common already (keep, route social into it) | `finalize_sign_up_from_checkpoint!` boundary and `SignUp::FinalizationPolicy`; `SignUpStateMachine` (`finalize`, `complete`; `start_social_callback`, `complete_social_callback` exist); `IdentityGraphProvisioner`; `SignUpEligibilityPolicy` (birthdate); `handoff_to_sign_in_flow!`; `SignUpRequirementRegistry` (already per entry method) |
| Realm-specific | `ClientSignUpFlow` vs `VisitorSignUpFlow`; `finalize_app_sign_up_actor!` vs `finalize_com_sign_up_actor!`; principal models and statuses; page props (`AppSignUpCheckpointPage`, `ComSignUpCheckpointPage`); messages |
| Entry-method-specific | Email/telephone OTP issue/verify (`SignUpContactOtpControllerSupport`, OTP committers); passkey registration; provider evidence verification (OmniAuth, `IdentitySocialCeremonyContract`); the ceremony-bound social confirmation Turnstile |
| Removable after unification | `SignUpSocialBirthdateSupport` override; the sign-up branch of `IdentitySocialCeremonyFinalCommitter` (`commit_signup!`, `committed_signup!`); the sign-up branches of `Base::App::Social::Authentication::CompletionsController` (`complete_admitted_social_signup!`, `handoff_social_signup_oidc!`, `record_social_signup_completion!`, `redirect_completed_social_signup!`) and its Continue page for sign-up; the local branch is already WU-01. Whether the controller has any non-sign-up use left (link, login) is to be checked before removal |
| Dangerous to merge | Treating google/apple as one `social` method (H11 forbids; `sign_up_auth_method` already collapses them to "social" only as an MFA label); the ceremony-bound Turnstile replaced by a generic call; one transaction assumed across databases; a shared session writer for Sign Up (Sign In First ADR: "shared code is not shared policy") |

### 5.C ADR alignment — the Auth authority question (conclusion)

**Conclusion: Auth creating the pending account and running the shared sign-up Finalization is
consistent with the accepted boundaries; it is already what App/Com email and telephone do. What
Auth must never do — issue a Root/Browser Session, OIDC codes or tokens — is unchanged.**

- `adr/base-auth-ceremony-and-seven-rp-boundary.md` already requires that app/com email and
  telephone sign-up "cannot create a pending actor, contact, OTP or delivery before confirmed
  admission redemption" — i.e. Auth creates pending actors after admission. The code agrees
  (`EmailSignUpCandidateCreator`, `TelephoneSignUpCandidateCreator`, `finalize_sign_up_from_checkpoint!`
  with `IdentityGraphProvisioner`, all running in Auth controllers).
- `adr/sign-in-first-and-sign-up-handoff.md`: after durable registration the result "enters the
  ordinary Sign In admission … guardrail, checkpoint, MFA, selector, cooldown, session-limit"; Base
  (Visa after D-59) is the sole Browser Session and OIDC authority; it requires verifying that **App
  Google and Apple** enter the same canonical Sign In policy. **Today they do not**: the Base social
  completion issues the OIDC result directly (`register_result_and_issue!`) without the Auth Sign In
  flow. The unification removes this nonconformity.
- Not recorded in any ADR found: an explicit statement that Auth runs sign-up Finalization and
  Identity Graph provisioning, and the reverse statement in the `SignUpSocialBirthdateSupport`
  comment ("Acme owns the durable social signup commit and session issuance"). A new ADR (D-57,
  when implementing) states the boundary: Auth may create pending principals and finalize sign-up
  through shared operations on the principal writers; Root Session, OIDC and RP Session authority
  stay with Visa and Base; it supersedes the social-commit-at-Base design in
  `adr/sign-up-authentication-handoff-and-social-rt.md` (and the concern comment) explicitly.
- Kept: `adr/sign-up-checkpoint-turnstile-boundary.md` (no Turnstile on birthdate/passcode/passkey
  checkpoints), `adr/turnstile-visible-placement-policy.md`; `docs/security/turnstile.md` says
  controllers validate through the shared concern — record the social confirmation's direct
  `verify_for_ceremony` call as the documented stronger exception, not a gap to "fix" downward.
- one.md D-48 L6 ("linked Client still `UNVERIFIED_WITH_SIGN_UP` → fixed message, end") collides
  with creating a social pending Client earlier: an abandoned social sign-up would block its own
  retry. See U1/U5.

### 5.D Adversarial review

| Threat / failure | Today | After unification — required control |
|---|---|---|
| Duplicate new social identity | `(issuer, subject)` unique index; slot taken at Base commit | Uniqueness checked and the External Identity written **inside the shared Finalization under the flow lock** (U1); a concurrent second flow for the same subject fails closed |
| Takeover of an existing social identity | Callback: existing identity → sign-in path; sign-up entry + registered → error (D-48 L2) | Unchanged decision at the callback; the Finalization re-checks that the subject is still unregistered and never links to an existing Client (no auto-merge) |
| Sign-in mistaken for sign-up | `entry_intent` of the Admission (D-47 P1) | Same; tests for both crossings per provider |
| Auth/Visa authority breach | Social commit at Base | Auth finalizes registration only; session via canonical Sign In → OIDC evidence → Visa. No session writer called from Sign Up |
| Session for an incomplete account | Social: Base commit then OIDC result | `COMPLETED` is not a session grant; Sign In applies eligibility (`login_allowed?`, `access_enabled?`) |
| Replay of OTP / ceremony result | OTP single-use; signed result + replay store + candidate consume | Provider candidate consumed once at confirmation or Finalization (U2); no Auth→Base signed result for sign-up anymore, so its replay surface disappears; flow lock + state checks stop double Finalization |
| Races | Flow row lock in shared finalizer | Same lock covers the social branch; separate-connection concurrency tests |
| Partial commit across databases | Nested transactions, not atomic | State the order (principal + identity first, then flow `finalize/complete`); a crash between them leaves a durable Identity with a non-completed flow → resume path or explicit failure, never deletion of the Identity (Sign In First ADR) |
| Leftovers after cancel / expiry | Email/telephone: pending actors; `SignUpArtifactCleanup`, `SignUpCancellation` | Social pending Client (if created at confirmation) follows the same cleanup; no External Identity before Finalization keeps the subject slot free (U1, U5) |
| Turnstile bypass to advance requirements | Telephone OTP gap | WU-04 first; requirement transitions only from the Turnstile-checked actions |
| Birthdate check/store mismatch | Social: checked twice (Auth page, Base committer) | One check in the shared requirement clear + Finalization re-check |
| Misuse of an already registered credential | Contact uniqueness at OTP verification | Unchanged |

### 5.E Staged plan (each step its own Red → Green → Refactor and test run)

0. Baseline full-suite failure set (one.md TR) and characterization tests of the six paths where
   missing — especially "existing social user signs in, never treated as sign-up" per provider.
1. **WU-04** (telephone OTP Turnstile, App + Com) — independent, first.
2. **Social pending account in Auth** (U1, U5): after provider evidence + confirmation Turnstile,
   create the pending Client through a social candidate creator (shared pattern with
   `EmailSignUpCandidateCreator`); tests for duplicate subject, existing-client conflict, cancel,
   expiry, retry, concurrency.
3. **Birthdate unification**: remove the `SignUpSocialBirthdateSupport` override; the social
   birthdate uses the shared `clear_sign_up_birthdate_requirement`.
4. **Finalization unification**: a `social_identity` branch in `finalize_app_sign_up_actor!` that
   writes the External Identity via the existing `SocialAuthSignupFinalizer` logic (moved, not
   wrapped), under the flow lock; then the shared `IdentityGraphProvisioner`, `:finalize`,
   `:complete`.
5. **Sign In First for social**: `handoff_to_sign_in_flow!` for social too (canonical Sign In →
   OIDC evidence); refusal tests for guardrail/MFA/checkpoint/cooldown/session limit.
6. **Remove the old social sign-up transport**: sign-up branches of the Base social completion and
   of `IdentitySocialCeremonyFinalCommitter`, the sign-up result-token operation and the extra
   Continue page (after checking for remaining non-sign-up callers).
7. **Visa handoff** is WU-02: if steps 2–6 land first, WU-02 has no social sign-up receiver to move.
8. ADR (5.C), `docs/mermaid` (sign-up axis and inventory), `docs/security/turnstile.md`, evidence.

Rollback: each step is a separate commit with its own tests; nothing is deployed, so reverting a
step is a code revert; no data migration is planned (U1 may need none if the identity is written
only at Finalization).

### 5.F Decisions (owner, H12, 2026-10-21 — D-69)

| ID | Decision |
|---|---|
| U1 | **Approved.** The social pending Client is created in Auth after provider evidence is verified and the new registration is explicitly confirmed. The External Identity row is written only at Finalization, where `(issuer, subject)` uniqueness and conflicts with existing identities are re-checked; concurrent and duplicate registrations are refused safely |
| U2 | **Approved with conditions.** Reuse `IdentitySocialCeremonyCandidateStore`. Candidate lifetime ≤ the 30-minute curfew and never beyond the Sign-up Flow, provider evidence, Admission or Ceremony lifetimes and bindings. Expired provider evidence is never revived by reusing an old candidate |
| U3 | **Approved with conditions.** Order WU-04 → WU-05 → WU-02. Every intermediate step keeps the canonical Sign-in Admission; no new dependency on Base-specific sessions or hosts; the result receiver must be retargetable to Visa in WU-02 |
| U4 | **Approved, order changed:** the new ADR is written **before** implementation (Auth pending-account creation and shared Finalization, Sign In First, Visa/Base/Auth roles, partial supersession of existing ADRs) and extended with verification results after implementation |
| U5 | **Approved as amended.** Safe resume of one's own unfinished flow, or safe re-registration after expiry or cancellation, is allowed. Ownership of a pending Client is never granted because of the same email address or the same browser; it requires valid authority over the original Flow/Admission/Ceremony, or a fresh provider authentication. Completed identities, other people's flows and other operations' data are never taken over or deleted. Explain why D-48 L6 refuses and show no protection is lost (§5.I) |
| U6 | **Approved.** Google/Apple sign-up always passes the canonical Sign In First; guardrail, checkpoint, MFA, session limit and cooldown are never skipped; extra screens are accepted |
| Extra | Before deleting Base `/social/authentication/completion`, classify every non-sign-up use (login, link, retry, result transport) and move each to its proper new path; no bulk deletion that breaks another use (§5.H) |

### 5.G Invariants

**Social pending Client**
- P1. Created only in Auth, only under a redeemed sign-up Admission whose effective `entry_intent`
  is sign-up (D-47 P1), only after (a) the provider callback evidence was verified for that
  Admission's ceremony and (b) the confirmation POST passed the ceremony-bound Turnstile
  (`verify_for_ceremony`, action `social_signup_confirmation`, hostname, cdata = flow public id).
- P2. Exactly one pending Client per Sign-up Flow; the Flow records it (`principal_id`) under the
  flow lock; a second confirmation for the same Flow is idempotent or refused, never a second Client.
- P3. Status `UNVERIFIED_WITH_SIGN_UP`; it cannot sign in, has no External Identity, no contact and
  no credential until Finalization.
- P4. Bound to its Flow; no lookup by provider subject, email or browser can reach it. Resume only
  through the Flow locator plus a live Admission/Ceremony of that Flow (U5).
- P5. Cleanup (D-77): an expired, cancelled, halted (age) or failed Flow's pending Client is retained
  logically by the sign-up cleanup. After taking its locks the cleanup re-checks: still unconfirmed,
  Flow ownership matches, no other Flow confirmed it, no External Identity that forbids deletion.
  Today `SignUpArtifactCleanup` decides eligibility before locking and keys on a pending contact
  (contact-less social pending Clients are not covered) — both change in WU-05. A pending Client is
  never reused by another Flow.

**Candidate (`IdentitySocialCeremonyCandidateStore`; corrected 2026-10-22 per D-78)**
- C1. Stored in PostgreSQL (`IdentitySocialCeremonyCandidate < OpBaseAppRecord`, OP DB), encrypted
  `auth_hash` holding the verified provider principal only; `credential_candidate` is **not** stored
  (reconstructed as `nil`) and stays unstored once WU-05 verifies registration does not need it.
  Bound to provider, surface, ceremony transaction and Sign-up Flow; `expires_at` = min(**curfew**,
  Flow lifetime, provider-evidence lifetime) — never the 60-second acceptance expiry.
- C2. Read for confirmation and birthdate pages without consuming; consumed exactly once, inside
  Finalization, under the Flow lock. Consumed, expired or mismatched (flow, provider, subject digest,
  transaction) → refusal (D-47), never revival from an older candidate.
- C3. OP database unavailable → fail closed (no Candidate, no progress). The Candidate has no Valkey
  dependency; Valkey-backed Admission references keep their own fail-closed behavior.

**Finalization (shared `finalize_sign_up_from_checkpoint!`, social branch)**
- F1. Runs only at `CHECKPOINT_PENDING` with every requirement of the entry method cleared
  (`confirmation`, `birthdate`), under the Flow row lock, with `SignUp::FinalizationPolicy`.
- F2. Re-checks birthdate eligibility (`SignUpEligibilityPolicy`).
- **Decisive commit (D-131):** the principal's registered-status commit, made after the deadline
  check under the OP Flow/Binding lock, decides "registered". Before it: unfinished (Sign In refuses,
  reset/cleanup may delete). After it: registered (Sign In admits, never deleted as registration
  cleanup); graph and OP Flow completion failures afterwards are completed idempotently later.
- **F1–F6 ordering and commit design (updated 2026-10-22):** X-24 decided — a Finalization completes
  before the deadline or fails closed (D-105); X-26 direction decided — AX26-1 first, then the status
  gate WU-34 (D-106); X-27 — the final lock order comes from the WU-35 inventory (D-107). **Do not
  implement F1–F6 before WU-35's order is fixed by the owner.** Facts (six.md §C.1): the shared finalizer commits principal → graph →
  OP; today's social committer commits graph → OP → principal; the subject lock
  (`ClientExternalIdentity.with_subject_lock` + `released_since_ceremony?`) must be kept.
- F3. Consumes the candidate (C2); re-checks that `(issuer, subject)` is unregistered and not
  released-blocked/banned (D-48 L5, L8); writes the External Identity and promotes the pending
  Client to `VERIFIED_WITH_SIGN_UP` in **one principal-database transaction**, so the D-48 L6 state
  (identity linked to an unverified Client) cannot be produced.
- F4. Then `IdentityGraphProvisioner`, `SignUpStateMachine :finalize`, `:complete` (existing order);
  the cross-database order is fixed and documented; a crash after the principal commit leaves a
  durable Identity with an incomplete Flow → the next attempt is an ordinary sign-in; the Identity is
  never deleted as compensation (Sign In First ADR).
- F5. Idempotent: a second Finalization of the same Flow returns the refused/terminal result and
  writes nothing.
- F6. Entry method (`google`/`apple`) recorded on the Flow, the state-machine events and audit.

**Sign-in handoff**
- S1. Always `handoff_to_sign_in_flow!` → `establish_signed_in_session!` → canonical Sign In
  (eligibility, guardrail, checkpoint, MFA, selector) → OIDC evidence → the authority's result
  receiver; never `register_result_and_issue!` from a sign-up path.
- S2. The receiver is reached through the existing OIDC result handoff (`oidc_authorization_after_login_path`),
  so WU-02 retargets it to Visa by changing the host contract (R2), not the sign-up code.
- S3. Authentication event time and method come from the provider ceremony
  (`ceremony.authentication_event_at`, `established_authentication_method` = provider).
- S4. A Sign In refusal after durable registration is a Sign In failure; the user signs in again.

### 5.H Uses of Base `/social/authentication/completion` (checked 2026-10-21)

| Use | Producer | Today | New path |
|---|---|---|---|
| Sign-up commit (`operation == "signup"`) | the only producer: `SignUpSocialBirthdateSupport#render_social_signup_completion!` → `IdentitySocialCeremonyResultIssuer.issue!(operation: "signup")` | `IdentitySocialCeremonyFinalCommitter.call!` → `commit_signup!` | Auth shared Finalization (5.G) |
| Retry of a committed sign-up (lost response) | same token re-posted | `committed_signup!` receipt → `redirect_completed_social_signup!` | Removed with the transport: after durable registration a lost response is a Sign In failure (S4); covered by one.md X-20 |
| Link (`operation == "link"`) | **no producer posts here** | rejected: `reject_social_link_completion!` redirects to settings | Nothing to move; the guard goes with the controller. Link ceremonies keep their own Auth settings paths |
| Login | none | refused (`BadRequest` unless `signup`) | Nothing to move. `IdentitySocialCeremonyFinalCommitter#commit_login!` / `#commit_link!` are unreachable (their only caller refuses those operations) — remove in WU-05 after the WU-01-style dead-code check |
| Local sign-up login | local parent | `complete_social_signup_local_login!` | WU-01 |

### 5.I D-48 L6 — why it refuses and why nothing is lost

L6 (identity linked to a Client still `UNVERIFIED_WITH_SIGN_UP`) refuses because signing in such an
account would skip birthdate eligibility and Finalization, and treating it as unknown would create a
second Client for the same subject. Today the social path never produces it (`SocialAuthSignupFinalizer`
creates the Client as `VERIFIED_WITH_SIGN_UP` together with the identity), so L6 guards leftover or
foreign data. Under WU-05 the pending Client has no External Identity (U1, P3) and F3 writes the
identity and the verified status in one transaction, so the new code cannot produce the L6 state
either. L6 therefore stays unchanged; U5 resume/re-registration acts only on the user's own Flow
(P4), which an L6 row never is.

### 5.J Second adversarial review (2026-10-21) — design reasoning only; "Resolved" below means *designed*, not executed or passed (R-28)

| # | Question | Result |
|---|---|---|
| 1 | Two flows for the same provider subject (two tabs or devices) | Both may create pending Clients (P2 per Flow); F3's re-check + the `(issuer, subject)` unique index let one finalize; the other gets a D-47 refusal and its pending Client is cleaned (P5). Neither browser is signed into the other's account (S1 binds actor and browser). **Resolved** |
| 2 | Abandoned flow blocks re-registration | No identity row before F3, so the subject stays free (L1). **Resolved**, given P5 |
| 3 | Expired candidate revived | C1/C2. **Resolved** |
| 4 | Pending Client reachable by email/browser | P4; social pending Clients have no contact. **Resolved** |
| 5 | Sign In First bypass | S1; the direct issuance path is removed (5.H). **Resolved** |
| 6 | Provider-side revocation (Apple `consent-revoked` / `account-deleted`) between confirmation and Finalization | The notification finds no identity row yet; Finalization does not consult provider events. **Accepted residual risk (R-1 = a)** |
| 7 | Two `ClientSignUpFlow.create!` sites in the OmniAuth callback (one.md X-17: a Flow created at entry before the provider round trip and another at the callback) | Must collapse to one Flow per attempt (approved). **Open (R-2)**: where it is created is undecided; investigate both sites first |
| 8 | Cross-database partial commit | F4 fixes the order and the recovery (Sign In failure). **Resolved by design; must be tested** |
| 9 | Cleanup gap for contact-less pending Clients | P5. **Approved (R-3)**: WU-05 extends the cleanup |
| 10 | Visa dependency during WU-05 | S2; WU-05 must not add new uses of `base_authority_host`. **Resolved** |
| 11 | Turnstile weakened during refactor | The ceremony-bound check stays as is and is documented as the stronger exception. **Resolved** |
| 12 | Lost response after social Finalization | S4 / X-20. **Accepted as decided** (no reissue, D-2) |

Owner resolutions (2026-10-21, D-70):
- **R-1: (a) accepted.** A provider-side revocation or deletion that arrives between confirmation
  and Finalization (≤ 30-minute curfew) is accepted as a residual risk; Finalization does not
  consult provider events. The provider-event handling stays in
  `plans/backlog/2026-10-21-social-provider-account-event-notifications.md`.
- **R-3: approved.** WU-05 extends the sign-up cleanup to contact-less social pending Clients (P5).
- **R-2: unification to one Flow approved; the location is not decided.** One social sign-up
  attempt has exactly one `ClientSignUpFlow`. Whether that Flow is created at the entry (before the
  provider round trip) or at the callback is **not** fixed yet: WU-05 first investigates both
  `create!` sites in `Auth::App::Omniauth::OmniauthCallbacksController` (what each creates, under
  which Admission and `entry_intent`, what E1 binding and cleanup apply) and brings the options back
  to the owner. Until then no step may move Flow creation.

### 5.J-2 R-2 investigation: where the social Sign-up Flow is created (2026-10-21, code reading)

There are **three** `ClientSignUpFlow.create!` sites for App social sign-up, not two:

| Site | Where | When it runs | What it creates | Live? |
|---|---|---|---|---|
| E (entry) | `AppSocialCeremonyEntry#issue_sign_up_flow!` | Before the provider round trip, when `social_auth_entry == "sign_up"`, which is decided by `params[:entry]` (`sign_up`/`auth_up`) **or the Referer** being `/sign/up` | Flow `STARTED` → `SignUpStateMachine :start_social_callback`; locator in the Rails session (`SignUpCycleLocator`, `:auth_app_up_sequence_id`). `reject_suspended_sign_up!` runs first | **Live** |
| C1 (callback, pending) | `OmniauthCallbacksController#handle_pending_social_sign_up_intent` → `sign_up_flow_locator.current \|\| create_pending_social_sign_up_flow!` | At the callback, for `intent == "login"` with **no existing user or identity**, whether the entry was sign-in or sign-up | Reuses the session's current Flow (from E) or creates a new `SOCIAL_CALLBACK_PENDING` Flow; then stores the candidate (`IdentitySocialCeremonyCandidateStore`, `expires_at: cycle.expires_at`) and `completed_requirements["social_signup"]`, under `with_pending_social_sign_up_lock` (provider + HMAC subject digest) | **Live** |
| C2 (callback, legacy) | `OmniauthCallbacksController#handle_social_sign_up_intent` → `create_social_sign_up_flow!` (+ `bind_social_sign_up_flow!`, `social_sign_up_required?`) | — | — | **Dead**: `handle_social_sign_up_intent` and `social_sign_up_required?` have no caller in `app/` or `test/`; add to WU-05 removal with the dead-code check |

Facts that bear on the choice:
- E decides "sign-up" from request parameters or the Referer, which D-47 P1 forbids (the decision
  must come from the Admission's effective `entry_intent`). This must change under either option.
- C1 runs for an unknown identity even under a **sign-in** entry: it then creates a sign-up Flow —
  the X-17 crossing that D-48 L1 forbids (sign-in + unknown identity → error).
- C1's reuse of `sign_up_flow_locator.current` trusts the Rails-session locator (nonce matched),
  not the Admission; a mismatched provider or entry method is refused later in
  `store_pending_social_signup_evidence!`.
- `ClientSignUpFlow` has no `auth_admission_binding_id` yet (E1 ADR not implemented), so neither site
  binds the Flow to the Admission today.
- The Flow lifetime is `SignFlow.default_ttl`, not the 30-minute curfew (REQ-CURFEW 2 not applied).

Options to bring back to the owner (one Flow per attempt is already decided):

| Option | Flow created | Callback does | Pros | Cons |
|---|---|---|---|---|
| R2-A | At the entry, only under a sign-up Admission (`entry_intent`), bound to that Admission (E1) | Finds the Flow bound to the redeemed Admission; never creates one; unknown identity under a sign-in Admission → error (L1) | One owner of creation; suspension check stays at the entry; the Flow can carry the curfew from the start | A Flow for every user who abandons at the provider (cleanup); a Flow exists before the identity is known |
| R2-B | At the callback only, under a sign-up Admission, after evidence is verified | Creates the single Flow, bound to the Admission; the entry creates nothing | No Flows for provider abandonment; created with evidence in hand | Suspension and eligibility checks must also run at the callback; the entry keeps no sign-up state except the Admission |

**Owner, 2026-10-21 (D-71):** C2 is removed as dead code in WU-05 (after the dead-code check).

**Where the Admission comes from, and what it does not decide (finding).** The social button runs
inside an already admitted Auth ceremony: Base `/oauth/authorize` issues the Admission
(`BaseAuthAdmissionCoordinator.issue_handoff!`), Auth `/sign/in?entry_ref=…` attaches it (`POST
/ceremony_bindings`), Base confirms it (`/ceremony_bindings/:ref/confirmation`), Auth redeems it into
the ceremony session (`__Host-auth_sid`). The social entry (`AppSocialCeremonyEntry`) calls
`auth_social_admission_binding!` (active ceremony, redeemed and unexpired binding) and the callback
checks it again (`store_pending_social_signup_evidence!`). **But the ordinary Admission does not
say sign-in or sign-up:** `authorization_intent` (Base `oauth/authorizations_controller.rb`) is
`sign_up` only for `prompt=create`, `authentication` for first-party browser RPs, otherwise
`sign_in`; `issue_handoff!` sets no `entry_intent` (only a Switch Admission carries one); and
`validate_entry_parent_intent!` / `auth_ceremony_matches_intent?` accept both `sign_in` and
`sign_up` under `authentication`. So for a first-party RP, "sign-up" is today decided only by the
Auth page or the social entry's params/Referer. D-47 P1 ("decided by the Admission's effective
`entry_intent`") therefore has no data to rely on until the effective intent is made explicit: the
Switch `entry_intent` when present, otherwise `prompt=create`, otherwise sign-in — and the Auth sign-up
page reached without a Switch would have to be refused or would have to issue the sign-up Admission
through Base first. This is a prerequisite for R2-A and R2-B alike.

Either option removes E's Referer/params decision, removes C1's creation under a sign-in Admission,
and removes C2. Recommendation for discussion: R2-A, because the Admission already exists at the
entry and E1 makes "one in-progress Flow per Binding" enforceable there; decide with the owner.

### 5.J-3 Adopted design: explicit effective intent + R2-A (owner delegated, 2026-10-21 — D-72)

The owner adopted the recommendation. Applies to all six sign-up paths and to sign-in.

- **EI-1 Effective intent of an Admission:** the binding's `entry_intent` when present (Switch);
  otherwise the parent OIDC transaction's intent mapped `sign_up` → sign-up, `sign_in` → sign-in,
  `authentication` → **sign-in**. A first-party RP's ordinary Admission is therefore a sign-in
  Admission; sign-up needs `prompt=create` or a Switch (Base issues a fresh Admission with
  `entry_intent: "sign_up"`; the sign-in page already renders this Switch form,
  `sign_entry_exit_forms(switch_to: "sign_up")`).
- **EI-2 One decision point:** a single shared check computes EI-1 from server state (never params,
  Referer or the page path). Auth sign-up pages and actions (email, telephone, Google/Apple sign-up)
  require effective intent sign-up; sign-in pages and actions require sign-in. Mismatch → the D-47
  uniform error. `auth_ceremony_matches_intent?` / `validate_entry_parent_intent!` stop accepting
  both intents under `authentication`.
- **EI-3 Social entry:** `AppSocialCeremonyEntry#social_auth_entry` (params/Referer) is removed; the
  social sign-up decision is EI-1.
- **R2-A Flow creation:** the single `ClientSignUpFlow` is created at the social entry only when the
  effective intent is sign-up (after the suspension check), bound to the Admission binding (E1
  `auth_admission_binding_id`), with `expires_at` = the curfew. The callback looks up the Flow bound
  to the redeemed binding and never creates one; an unknown identity under a sign-in Admission is an
  error (D-48 L1); a registered identity under a sign-up Admission is an error (L2). C1's creation and
  its reuse of the Rails-session locator as authority go away; C2 is removed (D-71). Provider
  abandonment leaves a `STARTED` Flow without a pending Client, cleaned by the ordinary expiry.
- **Consequences to expect:** tests that open a sign-up page with an ordinary first-party
  (`authentication`) Admission must go through the Switch or use `prompt=create`; they assert old
  behavior and are updated with that reason (not deleted). The E1 binding column needs a migration
  (E1 ADR is Accepted; the migration and its rollback are approved at implementation time). Com
  email/telephone sign-up follow EI-1/EI-2 the same way.

### 5.K Work plan in the order WU-04 → WU-05 → WU-02

1. **WU-04** (telephone OTP Turnstile, App + Com), its own tests and evidence.
1b. **WU-24** (effective intent, curfew storage, E1 association, authoritative Flow lookup) —
   prerequisite of the WU-05 steps below (four.md R-20).
2. **WU-05 ADR first** (U4): new ADR "Sign-up Finalization in Auth and Sign In First for all six
   paths" with partial supersession of `adr/sign-up-authentication-handoff-and-social-rt.md` (social
   commit at Base) and the concern comment; references `adr/sign-in-first-and-sign-up-handoff.md`,
   `adr/base-auth-ceremony-and-seven-rp-boundary.md`, `adr/sign-up-flow-admission-binding-and-cardinality.md`.
3. **WU-05 design closed:** R-1, R-2 (§5.J-3: EI-1/EI-2/EI-3 + R2-A), R-3 decided. Step order inside WU-05: effective intent (EI) first, then the single social Flow (R2-A), then the pending Client and the rest.
4. **WU-05 steps** (each Red → Green → Refactor): characterization tests → pending social Client
   (P1–P5, cleanup) → birthdate unification → Finalization social branch (F1–F6) → Sign In First
   handoff (S1–S4) → removal of the old transport and the dead committer branches (5.H) → ADR
   verification addendum, mermaid, `docs/security/turnstile.md`, evidence.
5. **WU-02** (Visa): with no social sign-up receiver left on Base, only the OIDC result receiver
   moves; retargeting follows R2.

WU-01 (Local Sign-in Flow removal) and WU-03 (`/edge/v0/cookie`) are independent and may run
before WU-02.

---

# Part 2 — Remaining requirements of one.md (WU-06 … WU-23)

Added 2026-10-21 so that every requirement in one.md §2–§5 has a Work Unit. Units marked
**Ready** can be implemented once the owner gives the go; units marked **Blocked** list exactly what
must be decided first and must not be started. File references are from static reading at
`febec3225`; re-verify before editing. Every unit follows the implementer rules at the top of this
file, keeps the baseline comparison (one.md TR) and leaves an `evidence/` record.

| WU | Title | one.md | Status |
|---|---|---|---|
| WU-06 | Sign-in path curfew (30 min from Admission issuance) | D-45, REQ-CURFEW, D-36, D-41, T2 | Ready |
| WU-07 | Uniform refusal and reason-coded observability | D-47, T19 (OBS-1), F2 | Ready |
| WU-08 | Social callback state matrix L1–L8 | D-48, X-17 | Ready (after WU-05 step EI) |
| WU-09 | Browser allowlist (`allow_browser :modern`) | D-50 (1), CR R-09 | Ready |
| WU-10 | Standard refresh, receipt machinery removed | D-25, T7 | **Done locally 2026-10-25** (`evidence/2026-10-25-wu10-standard-refresh-R7K2.md`) |
| WU-11 | RP JWT verification through Discovery/JWKS only | D-23 #4, T8, BX-6, BX-7 | Ready |
| WU-12 | Automatic relays (Design D continuation GETs) | T1, D-100, D-101, D-103, D-46, D-49, D-50 (2) | Ready after WU-02 |
| WU-13 | Cancel and Switch leave `/oauth/authorize` | T3, D-37, D-38, D-39, D-100 | Ready after WU-02 (transport D-100) |
| WU-14 | RP-Initiated Logout per spec | D-33, T9, BX-12 | Implemented locally 2026-10-25; hint sid/expiry and current-root targeting verified; full acceptance remains open |
| WU-15 | Back-Channel Logout delivery and receiver | D-26, D-29, D-31, D-117, D-118, D-121, T10 | Implemented locally 2026-10-25; focused sender, receiver, SSRF and concurrency checks recorded in `evidence/2026-10-25-wu15-16-22-op-authority-stop-6B3Q.md`; full acceptance remains open |
| WU-16 | One OP authority-stop primitive | D-27 (BX-1), D-34, D-119, T11, T13, D-172, D-173 | Implemented locally 2026-10-25; cause/scope checks and the single-writer guard recorded in current evidence; G-16 and D-166/A44 prerequisites remain open |
| WU-17 | Remove activation and `contract_epoch`; `authentication_epoch` NOT NULL | D-35 | Done 2026-10-23 (D-168; evidence K7E0) |
| WU-18 | Remove the pre-R5 OP-chain path | D-108 | Ready (inventory first; table drops need approval) |
| WU-19 | i18n: one bundle per language | D-40, D-113, T17 | Done 2026-10-25 (evidence L19M; asymmetric-key test not added) |
| WU-20 | Passkey identifier-first implementation | T16, ADR-PK, D-112, D-116 | Done 2026-10-23 (partial acceptance; evidence P2F0) |
| WU-21 | Merged into WU-43 (D-151, D-162) | D-151, D-162 | Retired |
| WU-22 | Sign-out records, bindings, model rules, deletion contract (SO-1 … SO-7) | T12, D-43, D-119, D-123 | Implemented locally 2026-10-25; SO-1 … SO-7 reflected in the stop records, typed bindings, model rules and purge; acceptance remains open under G-16 and D-166/A44 prerequisites |
| WU-23 | Credentials / KMS documentation | D-15, D-17, T18, §4 | Ready (docs only) |
| WU-24 | E1 binding, effective intent, curfew storage | D-72, D-74, D-75, R-20 | Defined (X-13 for migration details) |
| WU-25 | Revocation client authentication | D-79, R-30 | Ready after WU-02 |
| WU-26 | Partial-registration diagnosis (read-only) | D-82 | Lookup inputs/outputs extended locally (2026-10-26); reconcile remaining D-82 scope |
| — | Post-containment journey | D-104 | Now WU-27 (Ready) |
| — | Bootstrap | D-122 | Now WU-28 (Design first) |
| — | Gates for this cycle | D-124 | Decided: three.md G-1 … G-16 plus G-17 … G-22 |

## WU-06 — Sign-in path curfew

**Contract:** one.md REQ-CURFEW 1–9 (normative; REQ-CURFEW 2 and 6 as rewritten by D-160) and
D-160. Refusal after the curfew: the owner's own attempt returns to the RP as `access_denied`
through the Cancel route; anything else gets the uniform error without ending anything. Scope: Sign-in path only (sign-in and sign-up, App/Com/Org);
Re-verification path keeps its lifetimes (D-44).

**Today (to change):** `OpaqueAdmissionStore::CODE_TTL` 60 s also bounds the binding;
`auth_social_admission_binding!` uses `binding.expired?` (Social refuses after 60 s, F5);
`auth_ceremony_matches_intent?` ignores the parent's expiry; result issuance checks the OIDC
`login_challenge_expires_at` (10 min; `base_auth_admission_coordinator.rb` around the result
issuance and acceptance paths); `AuthCeremonySession::DEFAULT_TTL` 30 min counts from the ceremony
session, not from Admission issuance; `SignFlow.default_ttl` 15 min; OIDC transaction
`RETENTION_PERIOD` 15 min; RP `OidcCallback::OIDC_PENDING_FLOW_TTL` 10 min.

**Design:**
1. Store `curfew_at = issuance database time + 30 min` once on the Admission Binding (migration;
   NOT NULL for new rows, no default; existing rows: none in production, test fixtures updated).
2. One shared decision object (e.g. a value object in `app/values/`, per
   `project/value-object-boundaries.mdc`) answers "within curfew?" from the Binding and
   `database_now`; every consumer in REQ-CURFEW 3 calls it: Auth sign-in/sign-up page render, every
   Auth action (method selection, Email, Telephone, Passkey, Secret, Google, Apple, Cancel, Switch,
   each sign-up step), provider callbacks, evidence recording, result issuance, Base/Visa result
   acceptance. The database time is read with `ApplicationRecord.database_now` on the Binding's
   model after the Binding/Flow lock (D-75, D-160 (1)); never `CURRENT_TIMESTAMP` or `now()`.
   Refusal: when the browser binding proves the owner's own attempt, Auth sends the browser through
   the Cancel route (`/oidc/cancellation` after WU-13; the existing `cancellation_ref` branch before
   it) and the OP redirects to the registered `redirect_uri` with `error=access_denied`, the
   unchanged `state` and `iss` (D-160 (3)); a Cancel pressed after the curfew takes the same exit;
   ownership not proven → WU-07 uniform error, nothing ended; transaction row gone → uniform error.
3. OP-side parents never end the window early: ceremony session, Sign-in Flow, Sign-up Flow, OIDC
   transaction and `login_challenge` live at least until the curfew (set their expiry to the curfew
   or later; no extension past it is used for authority). The OIDC transaction row is retained at
   least until the curfew so the post-curfew exit can find its `redirect_uri` (D-160 (3)). The RP
   `state` and pending entry are **not** OP parents: they live 30 minutes from `POST /sign` on the
   Rails clock (D-150, D-160 (1)) and are implemented in WU-43, not here.
4. Carried values stay short (REQ-CURFEW 5): acceptance code, authorization code (10 s), result
   reference keep their own TTLs, each additionally capped by the curfew. Method ceremonies (email,
   passkey, secret, social, TOTP transactions, 10 min) keep their own shorter lifetimes, capped by the
   curfew; they are not extended.
5. Sign-up completing at or after the curfew keeps the registration; only its Sign-in handoff is
   refused (REQ-CURFEW 7).

**Decided 2026-10-22:** Switch inherits the original `curfew_at` (D-74); the decision reads
`clock_timestamp()` on the OP database that owns the Binding, after the Binding/Flow lock, once per
decision unit (D-75; `ApplicationRecord.database_now` already does this per model — callers must use
the Binding's model); ~~the RP pending OIDC state lifetime is derived from the three bounds of D-76~~
*(superseded by D-160: RP `state` 30 min from `POST /sign`, WU-43; the authorization code stays
10 s)*. Finalization spanning the deadline (D-105 as read by D-131): the deadline is checked on the OP clock under the Flow/Binding lock; if that check passes, the principal's registered-status commit that follows is decisive and kept even if it lands after the deadline; the Sign-in handoff after it is a separate consumer and is refused at or after the deadline (no session; the person signs in normally). If the check fails, nothing is registered.
`curfew_at` storage itself moves to WU-24.

**Tests:** every consumer just before, exactly at and just after the curfew (30:00 is out), plus a
result issued before and presented after (REQ-CURFEW 9); time controlled through the database clock
helper used by existing deadline tests. Social no longer refuses after 60 s. Post-curfew exit
(A06-7 … A06-9): own browser → `access_denied` to the RP; foreign browser → nothing ended;
transaction row gone → uniform error.

**Exit:** no consumer uses another expiry as authority; checklist AUTH-2 updated; docs/mermaid for
the Admission axis updated.

## WU-07 — Uniform refusal and reason-coded observability

**Contract (D-73 narrows D-47):** six classes, each with its own outcome —

| Class | Response | Flow / attempt | OTP / Candidate | Rails session | Other tabs |
|---|---|---|---|---|---|
| Ownership mismatch (foreign browser, wrong Binding) | uniform error | untouched | not consumed | the requester's own continuity keys cleared only | untouched |
| Retryable (Turnstile failure, correctable input) | the same page with an error and a new challenge | kept within its rules | not consumed | kept | untouched |
| Definitive refusal of the owner's own attempt (crossing, banned subject, curfew, consumed/expired evidence) | uniform error (same status and body for every cause) | ended through a named transition | as the transition defines | continuity keys cleared | untouched |
| Dependency failure (PostgreSQL, Valkey, provider) | dependency error (503 class) | not ended | not consumed beyond what committed | kept | untouched |
| Internal inconsistency (broken invariant, e.g. D-48 L4) | 5xx | not advanced | not consumed | kept | untouched |
| OIDC protocol refusal (`login_required`, `access_denied`, Cancel, token/revocation errors) | the standard protocol response to the validated `redirect_uri` / endpoint client | per protocol | per protocol | per protocol | untouched |

Reason codes only in server logs (T19): one event per refusal with the class and code, no
references, tokens, codes or contact data; an internal inconsistency also leaves an auditable
record. No class leaves authority behind (assert after each refusal).

**Today:** refusals differ (`render plain:` with various messages and 400/401/403/422; silent 400s
without an event, F2).

**Design:** one refusal responder for the Sign-in path (Auth and Visa/Base sides) that clears the
listed session keys and renders the single response; a reason-code catalogue (closed set) used by
the log event; call sites switch to it. Re-verification path and BCL receiver are not changed.

**Tests:** for each refusal cause of WU-06, WU-08 and the existing admission/binding refusals: same
status and body; session keys cleared; exactly one log event with the right reason code and no
sensitive value (assert on the formatted event).

## WU-08 — Social callback state matrix (App Google/Apple)

**Contract:** D-48 L1–L8 with D-72 (effective intent):
L1 unknown → sign-in error, sign-up continues (Flow from WU-05/R2-A); L2 registered → sign-in
proceeds, sign-up error; L3 linked Client unusable → error; **L4** identity without Client →
`raise`, 5xx, FATAL log (remove the "treat as unknown" branch in
`SocialAuthLoginHandler#login_existing_identity`); L5 released during the ceremony → error; **L6**
linked Client `UNVERIFIED_WITH_SIGN_UP` → fixed message, end (kept, see WU-05 §5.I); **L7**
`consent_revoked` / `account_deleted` → detected explicitly (today `find_by_subject` returns only
`active`), fixed message and stop in both intents; **L8** `AppEnforcementIdentifierEffect`
`google_subject` / `apple_subject` checked **first**, before identity lookup, for sign-in, sign-up
and linking → fixed message, stop.

**Tests:** the full matrix intent × state × provider; L8 precedence over every other state; L4 raises
with FATAL log; no Flow or pending Client created on any refusal.

## WU-09 — Browser allowlist

**Contract:** D-50 (1): `allow_browser versions: :modern` (Rails 7.2+) on browser-facing controllers
(Auth, Visa, Base RP, other RP surfaces); excluded: the BCL receiver (`POST /oidc/closures`), token
and other server-to-server endpoints, health. Documented in `docs/dds.md` (done). Part (2), the
Fetch Metadata check on relay GETs, belongs to WU-12.

**Tests:** request tests: an old UA gets 406 on a browser page; a server endpoint is unaffected.
Library behavior itself is not re-tested.

## WU-10 — Standard refresh

**Contract:** D-25: rotation on every use; reuse of a consumed refresh token → `invalid_grant` and
revoke **only that grant's family**; unknown tokens revoke nothing; no grace period. Remove the
delivery-receipt query endpoint (`/oauth/refresh-deliveries/query`, `OidcRefreshDeliveryQuery`,
`OidcOpTokenClient.query_delivery`), the receipt replay in `OidcRefreshTokenIssuer`,
`rp_refresh_attempts` / `RpRefreshCommitter` recovery; rewrite AUTH-10 … AUTH-12. RP recovers by a new
Code flow (`prompt=none` first). Browserless refresh failure → 401.

**Note:** removing `rp_refresh_attempts` is a schema change (migration with a rollback plan; owner
approval at execution). WU-02 V4 must not move the receipt endpoint if WU-10 lands first.

RP recovery per D-80: on `login_required` after `prompt=none` the RP starts a **new** interactive
authorization (new `state`, PKCE, nonce; the old transaction is not prolonged); no silent retry loop.

**Tests:** rotation, reuse → family revoked and Root Session intact, unknown token → nothing revoked,
RP recovery through `prompt=none`, `login_required` → one new interactive transaction (no loop);
removed routes not routable.

## WU-11 — RP JWT verification through Discovery/JWKS only

> **Revised by D-136 (H18): see Part 6.3** — the refetch limit is a distributed Valkey control, not per process.

**Contract:** D-23 #4: every first-party RP verifies ID Tokens and Access JWTs via Discovery →
`jwks_uri` over HTTP, per issuer, ES384 pinned, bounded unknown-`kid` refetch, fail closed. BX-6:
one cached client per issuer (no per-request `OidcOpJwksClient`, no hard-coded
`/.well-known/jwks.json`). BX-7 / T8: key-unavailable or JWKS fetch failure → 503, never 400.
AUTH-17 stays.

**Tests:** cached client reused; unknown `kid` → one refetch; fetch failure → 503 and cached key
used within its windows; a token with a different `alg` refused.

**To define before implementation (seven.md #15):** one result table — known `kid` / unknown `kid`
× cache fresh / within the allowed stale window / past it × fetch succeeds / fails — giving accept,
refetch, 503 or refuse for each cell; the allowed stale window as a fixed value; and the refetch
limit stated as "how many fetches per issuer per interval" (not per token).

## WU-12 — Automatic relays (Design D)

**Goal:** T1 — at most three user steps (RP `GET /sign` page, its `POST /sign`, the authentication
page); no page, click or JavaScript between them; HTTP redirects only.

**Decided:** D-100 Design D in full (`five.md` §6): every user action is a CSRF-protected POST; every
system hop is a 303 + GET continuation endpoint, including the final result GET that creates the
Root Session, under six conditions: Fetch Metadata `navigate`/`document` and HEAD refused (D-50);
host-only cookie binding verified before the one-time record is touched; atomic CAS; a repeat from
the same bound browser returns the same next redirect, anything else refused without consuming;
`no-store` + `no-referrer`; clean final URL. The binding confirmation round trip stays, automatic.
D-101: carried codes and every same-browser repeat bounded by issuance + 10 s; a repeat whose next
reference is consumed or expired is refused. D-103: the RP `GET /sign` page stays for every entry.
D-104: the Root Session hop always errors on repeat (WU-27). D-52, REQ-CURFEW.

**Work (`five.md` §10):** replace `auth/shared/admission_continuation`,
`base/shared/ceremony_binding_confirmation`, `auth/shared/oidc_authorization_handoff`,
`base/shared/result_continuation`, `base/shared/authorization_ceremony_start`,
`base/shared/authorization_exit_continuation` and their POST actions with GET continuation `show`
resources; separate Sign-in path purposes from the Re-verification path without changing the
latter (D-44); D-46's 10 s TTLs ship in the same change. The final result GET's repeat rule is
D-104 and is accepted in A12-6; WU-27 covers the journey around it (lost responses, tabs). Runs on the Visa host after WU-02; the
Sentry hop (WU-29) sits between the OP redirect and the Auth entry.

## WU-13 — Cancel and Switch leave `/oauth/authorize`

**Decided:** D-38 routes on the OP host (after WU-02: Visa) — `namespace :oidc { resource
:cancellation }` (`/oidc/cancellation`, APP/COM/ORG) and `resource :switch` (`/oidc/switch`,
APP/COM); `cancellation_ref` / `switch_handoff` branches removed from `/oauth/authorize` without a
compatibility route. D-39 semantics: Cancel ends ceremony and parent and returns `access_denied` +
`state` + `iss` to the RP; Switch keeps the parent, issues a fresh Admission with the target
`entry_intent` and inherits the deadline (D-74). **Transport (D-100):** the user's Cancel/Switch is a
POST at Auth; the OP side is a Design D GET continuation (`show`). F1 is not investigated (D-102).
Switch redirects to the Sentry path of the target intent (WU-29).

**Split with WU-43 (D-152, D-153, 2026-10-22).** This unit owns only the **OP side**: the
`/oidc/cancellation` and `/oidc/switch` routes, removing the `/oauth/authorize` branches, ending the
ceremony and parent, and returning `error=access_denied` with the unchanged `state` and `iss` to the
registered `redirect_uri` (RFC 6749 §4.1.2.1; the OP never reads `state` claims). The **RP side**
(verify `state`, consume the pending entry, discard `target_link_uri`, 303 to
`GET /sign/interruption`, and the D-80 classification of other errors) is implemented in WU-43
(WU-43c/f). This unit adds the **end-to-end re-check** of Cancel from a Sign-in and a Sign-up page
through the moved OP route to each surface's RP landing (A13-1), once WU-43 is done. (The earlier
note "only `tech-org-ww` handles `access_denied`" referred to a token-exchange capability refusal,
not Cancel.)

## WU-14 — RP-Initiated Logout per spec

> **Superseded on 2026-10-26** by `one.md` D-182 … D-186 and the consolidated sign-out definition to be written in Phase 2 (`ten.md`). Text below kept as history.

**Contract:** D-33 1–5: confirmation stops the current browser Root Session and every RP grant under
it; other roots remain independent. An RP first revokes its own grant, clears its local cookies and
session, then redirects to Visa with its server-stored ID Token hint, exact registered
`post_logout_redirect_uri`, and `state`. Visa verifies the hint signature, issuer, audience, type,
not-before time and current actor subject; it accepts an expired hint, declines its RP `sid`, and
uses the current OP Root Session ID as the stop target. A supplied `client_id` must match. GET and
POST to the end-session endpoint stage the request; the confirmation is a separate CSRF-protected
`POST /oidc/logout/confirmation`. Visa redirects to the exact callback after commit without waiting
for asynchronous BCL. The RP callback consumes its state-bound completion once and does not revoke a
grant again. `logout_challenge` stays OP-internal; the RP no longer writes
`AcmeLogoutTransaction` for this path.

**Order:** after WU-02 (the endpoint lives on Visa; WU-02 V9 keeps the authority-first order).

**Local verification (2026-10-25):** the RP launch/callback matrix covers all 12 registered
first-party clients; focused end-session tests cover different RP/OP `sid` values, expired and
not-yet-valid hints, subject and client mismatch, and exact callback validation. OP confirmation,
root/sibling scope and broader browser acceptance remain acceptance work.

## WU-15 — Back-Channel Logout (locally implemented)

> **Superseded on 2026-10-26** by `one.md` D-182, D-183 and the consolidated sign-out definition (Phase 2, `ten.md`). Text below kept as history.

**Decided:** D-26 (spec claims, `typ: logout+jwt`, ES384; send on every OP stop of a participating
`sid`/grant including refresh reuse), ~~D-28 (no durable outbox; loss accepted; no Solid Queue)~~ superseded by D-117/D-121, D-29
(every client registers a BCL URI, boot fails otherwise), D-30 (~~in-process bounded pool after COMMIT~~ superseded by D-121;
still applies: `OutboundHttp::Connection` with connection-time SSRF protection), D-31 (`POST /oidc/closures`
on all 12 RPs replacing `backchannel-logout`, no compatibility route), D-32 (receiver hardening;
signature-only trust), BX-4 status table, BX-6/7 (WU-11), BX-10 retry deadline, BX-13 accepted.

**Decided 2026-10-22 (supersedes D-28 and D-30 where they differ):** every participating RP is
notified — the stop transaction writes one durable outbox row per participant (D-117); delivery is
`OpOutboxDispatchJob` on Solid Queue after COMMIT, plus a Solid Queue recurring sweep that
re-enqueues rows without a final state (D-121); response classes D-26, retry deadline BX-10,
`OutboundHttp::Connection` requirements of D-30 apply to the job. The promise is three facts:
authority durably stopped; a durable row per participant; closure acknowledged, permanently refused
or expired. Receiver `POST /oidc/closures` keeps `ActionController::API` with explicit FQDN gating
and rate limiting, recorded as a scoped ADR exception (D-118). The sending side depends on WU-16.

**Local implementation (2026-10-25):** the three OP realms persist one participant per revoked
grant and dispatch from the OP outbox; Solid Queue enqueue-after-commit plus the recurring sweep
recover lost enqueues and worker crashes. All twelve first-party RP cells expose only
`POST /oidc/closures`; the receiver verifies the fixed OP issuer, client audience and Logout Token
claims before its local receipt/tombstone/session transaction. The sender pins the validated public
DNS address, never follows redirects, and applies the BX-4 / BX-10 outcome and deadline rules. See
the accepted ADR amendment and WU-15 evidence for the local checks. Deployment and external-RP
acceptance remain outside this local implementation result.

## WU-16 — One OP authority-stop primitive (5.8 v2, accepted D-172; locally implemented)

> **Superseded on 2026-10-26** by `one.md` D-182 … D-185 and the consolidated sign-out definition (Phase 2, `ten.md`). Text below kept as history.

**Decided:** BX-1 mandatory — every OP stop (logout, identity stop D-34, revocation, revoke-all,
refresh reuse, risk) goes through one primitive that revokes and records participants in one
transaction; a static guard forbids other writers; D-34 identity stop keeps its durable path
(Zenith event + direct apply + retry job + sweep) and calls the primitive so RPs get BCL. D-173
maps the other existing root-revocation callers to the accepted nine causes; all root/grant writers
now route through the primitive.

**Direction decided (D-119):** a new, browser-independent OP authority-stop record is the authority
for every cause (browser logout, identity stop, revocation, revoke-all, refresh reuse, risk), with
cause, scope and realm, written by the one primitive in the same transaction as the revocation and
the D-117 outbox rows. D-179 (2) supersedes the earlier plan to retain `Op*LogoutFlow` and
`*SignOutFlow` as evidence: the legacy sign-out flow classes, reference tables, concern and writers
are removed, while the browser receipt is a typed child of the stop and the one-use notice remains
transport state. D-123 applies: principal and cause NOT NULL, a stop without an established principal
is refused, references `ON DELETE RESTRICT`. The accepted cause × scope × realm matrix and lock
order are implemented by `OpAuthorityStopCommitter`; the record, typed children and outbox rows
commit with the revoked authority.

## WU-17 — Remove activation and `contract_epoch`; `authentication_epoch` NOT NULL

**Contract:** D-35: remove `op_client_activations`, `OpClientAdmissionGate` (still included in
`Base::*::Oauth::AuthorizationsController` and the token controller), D-18 is withdrawn; remove
`contract_epoch` everywhere (`Op*ProtocolEpoch`, columns on roots, grants, authorization
transactions and `rp_sessions`, refresh epoch matching / AUTH-16, the `umx_contract_epoch` claim,
RP-side matching, `UMAXICA_RP_CONTRACT_EPOCH`); keep `authentication_epoch`, make it NOT NULL on
roots and grants with existing NULL → 0, always written at issuance, no default.

**Approval needed at execution:** the NULL → 0 bulk update and the column drops are irreversible
persistence operations (AGENTS.md) — the implementer prepares the migration, rollback and risk note
and waits for the owner's approval before running them. Note the test-environment fact from this
session: `Op*ProtocolEpoch` rows exist only via migrations (`plans/backlog/2026-10-20-reference-data-outside-migrations.md`).

**Tests:** code exchange, refresh and identity stop without epochs; an identity stop cutoff still
refuses a root with epoch 0; removed claim absent.

## WU-18 — Remove the pre-R5 OP-chain path (D-108)

> **2026-10-26: WU-18c … 18e are back in this cycle** (`one.md` D-181, superseding D-175 for them); 18f is decided separately. The consolidated WU-18 definition is written with the sign-out definition (Phase 2, `ten.md`). Text below kept as history.

> **Implement through sub-units WU-18a … WU-18f only (D-133, Part 4).**

1. Inventory: every caller, route, table and test of the OP-chain path, and what selects it versus
   the standard RP path per client (CR question 3). Recorded before any deletion.
2. Remove it in one change per surface, landing only with the standard-RP path's tests green; no
   switch or flag between the two, so both authorities can never run for one client.
3. Table drops are destructive migrations: row counts, risk and recovery plan, owner approval.
4. **RuntimeRole removal (added per seven.md #11; D-19/D-20 layer 1):** today the RP path is chosen
   by process role — `RpCellLocalSession` (`app/controllers/concerns/rp_cell_local_session.rb:29`,
   `RuntimeRole::RP_ROLES.include?(RuntimeRole.current)`), `OidcClientRegistry`
   (`app/values/oidc_client_registry.rb:127`), `lib/runtime_role.rb`,
   `lib/runtime_role_route_guard.rb`, `config/initializers/runtime_role_route_guard.rb`,
   `lib/jit_security_jwt_registry.rb`, `lib/jit_security_jwt_local_keyset_installer.rb`,
   `config/environments/development.rb`. Define, per RP, how callback, JWT verification, refresh and
   local session switch to the standard-RP path without a role, then remove the role and its guard
   in the same per-surface change (sub-units WU-18a … WU-18f).

## WU-19 — i18n: one bundle per language (D-113)

Region does not change translation content. Merge `config/locales/{jp,us}/{en,ja}.yml` into one
bundle per language (resolving the D-40 differing keys: ja 66 / en 36, owner reviews each chosen
text); a test refuses duplicate keys with different text and keys missing in one language. Region-
specific copy, if ever needed, is a separate decision. Related backlog:
`plans/backlog/2026-10-21-base-com-org-translation-namespace.md`.

## WU-20 — Passkey identifier-first (D-112, D-116)

The Accepted `adr/passkey-identifier-first-sign-in.md` is the contract, except capacity: **ten
Passkeys per Identity** on APP, COM and ORG, the eleventh refused (D-116, restoring the 2026-10-19
decision; the enforcement gap is `plans/backlog/2026-10-19-passkey-limit-enforcement-gap.md`).
APP/COM select the Identity by effective Email or Telephone before the ceremony, keep
`allowCredentials` empty or omitted, and require the verified credential owner to equal the
server-fixed Identity; ORG Normal keeps Entra binding. Today `PasskeySignInFlow#options` selects no
actor. Shares sign-in paths with WU-30 (Security Mode): sequence them, do not merge.

**Added 2026-10-23 (D-171, `adr/passkey-authenticator-account-label.md`).**

1. Contract additions: credentials stay discoverable on APP, COM and ORG (already the code:
   `RegistrationVerifier::RESIDENT_KEY_BY_SURFACE`); `user.name` / `user.displayName` become a fixed
   non-identifying label per surface — never an Email, Telephone, Employee Number, Entra identifier
   or user handle. Change points: `PasskeyCeremonyContext#passkey_resource_display_name`
   (`passkey_ceremony_context.rb:128`) and its two callers (`passkey_ceremony_context.rb:38`,
   `auth_passkey_registration_ceremony.rb:31`). ORG registration without a discoverable credential
   or UV is refused.
2. Inventory to start from: `research/2026-10-23-passkey-usage-inventory.md` (65 routes, 25
   controllers, 8 concerns, shared components, models, tests). Re-check it against the code before
   relying on it.
3. **Exit includes the overview page `docs/security/passkeys.md`**, written against the code as it
   stands after this unit, with these sections: (a) where Passkeys are used — surface × purpose
   (sign-in, sign-in second factor, ORG Normal after Entra, ORG Emergency, sign-up, Step-Up,
   registration, management) with route, controller, concern and main tests; (b) registration —
   discoverable, UV, capacity ten, user handle and account label, metadata; (c) sign-in —
   identifier-first, empty `allowCredentials`, ownership equality, ORG Entra first, Emergency;
   (d) invariants — non-disclosure, ownership, replay, `ADVANCED` minimum two; (e) threats and
   limits — lost authenticator plus PIN, the response (remove the Passkey in settings); (f) the
   governing ADRs and which parts of each are superseded. `docs/security/webauthn-architecture.md`
   and `docs/security/webauthn-security-invariants.md` are either merged into it or reduced to
   pointers; `docs/security/org-emergency-access.md` is reconciled. The page describes current
   behavior only; decisions stay in the ADRs.

## WU-21 — RP return target owned by the RP (D-55, D-109)

> **Merged into WU-43 (D-151); acceptance retired into A43 (D-162).** The text below is history; implement WU-43 only. The RP `pt` helper is renamed `sign_in_url_with_target`; Auth's `pt` lane (`AuthenticationRedirects`, `AuthenticationVisitor#sign_in_url_with_pt`) is not touched.

> **Merged into WU-43 by D-151 (2026-10-22).** `pt` is abolished; the target is `target_link_uri` (path only). Nothing in this section or in 6.4 is implemented as written.

> **Superseded in its mechanism by D-137 (H18): see Part 6.4.** The target travels as an RP-signed `pt`; the Rails-session slot and "no `pt` in any URL" below no longer apply. Ownership rules and the Cancel rule stay.

**Decided:** the RP validates the target, stores it, restores it only after callback validation and
RP session establishment, uses it once; only the RP's own permitted internal paths; Base/Visa, Auth
and Jump never carry or rewrite it. **Entry input (D-109):** a protected page stores its validated
path and permitted query in the RP's Rails session (`store_location` convention) before redirecting
to `GET /sign`; `POST /sign` moves it into the authentication transaction keyed by `state`; no `pt`
in any URL (D-42). After Cancel the RP drops it and goes to its top page. Today
`BrowserRpAuthentication` builds `sign_in_url_with_pt(encoded_pt(request.fullpath))` and
`OidcSsoInitiator#remember_oidc_pending_flow!` stores `pt`; both change.

**To define before implementation (seven.md #19):** two tabs storing a target before either
`POST /sign` (proposal: last store wins, each `POST /sign` takes the current value and clears it);
when the stored value is cleared; the permitted query keys per RP; and the RP pending-state upper
bound with its behavior when exceeded (D-76), as a fixed value rather than a measurement.

## WU-22 — Sign-out (H5 SO-1 … SO-7)

> **Superseded on 2026-10-26** by `one.md` D-182 … D-185 and the consolidated sign-out definition (Phase 2, `ten.md`). Text below kept as history.

Sign-out work is split across units; this unit owns the Sign-out records and models and points to
the others:

| Part | Unit |
|---|---|
| Logout across Visa/Base hosts (cookie ownership, `/sign/bye` receipt on Visa, return host) | WU-02 V9 |
| RP-Initiated Logout per spec (GET/POST request, confirmation POST, `id_token_hint`) | WU-14 |
| Back-Channel Logout sender and `POST /oidc/closures` receiver | WU-15 |
| One OP authority-stop primitive (BX-1), stop-event parent independent of browser logout | WU-16 |
| Sign-out records, binding design, model rules, deletion contract | **this unit** |

**Source:** owner handoff H5 "Sign-out 設計・実装の移管依頼" (D-43). Method C applies (decided by the
owner in the sibling cycle): no `belongs_to optional: true`, no `belongs_to_required_by_default =
false`, no Model Concern `included do` / `prepended do`, lookup-table statuses + FK, no
`default_scope`, no persistent `enum`, constraints in PostgreSQL (NOT NULL / FK / UNIQUE / CHECK),
no trigger-based counting, `database_consistency` towards zero warnings; deletion behavior is not
changed unilaterally.

**Historical facts (one.md D-43, source reading 2026-10-21; superseded by D-33, D-179 (2), and the
local implementation below):** `AuthenticationLogoutCurrentSession` wrote legacy
`Client/Visitor/OperatorSignOutFlow` rows on every logout; `Op*LogoutFlow` / `Participant` / `Receipt`
were written only on the former RP-initiated path; Base local sign-out and identity stops did not
create those rows. The sign-out concern had an inclusion hook, and legacy `token_id` / `principal_id`
were nullable. The former completion contract allowed a CSRF-protected POST continuation. Current
OIDC RP return is a state-bound one-shot GET; `/sign/out/complete` and a direct `/sign/out` return URI
are not current, and Base local sign-out to `/lobby` remains a separate path.

**Local implementation (2026-10-25):** WU-16's durable OP stop record is the authority for every
cause. D-179 (2) removes `Client/Visitor/OperatorSignOutFlow`, their kind/status tables, the
`SignOutFlow` concern and all writers. Typed root/grant/cutoff/participant/browser children and the
one-use return notice retain the necessary evidence and transport state. Restricted foreign keys
and child-first retention purge enforce the deletion contract. See the WU-15/16/22 evidence; this
local implementation does not close G-16 or the D-166/A44 gates.

| Item | Question | Status | Notes |
|---|---|---|---|
| SO-1 | **Decided D-123 (strict):** no valid OP session → no OP authority stop, other-root revocation or BCL; re-run or unknown commit is answered from the durable stop record, fail closed if unreadable. Under D-33 the initiating RP grant is already locally revoked before the OP request. Original question: can an OP authority stop arise without a valid OP Browser Session? Distinguish unauthenticated viewing, expiry, deleted token, RP-started logout without OP session, re-run and unknown commit | Implemented locally in WU-16; focused authority/logout tests pass | The durable stop record is OP authority; the initiating RP local revoke is not a global sign-out |
| SO-2 | **Decided D-123:** principal NOT NULL on every stop record; a stop without an established principal is refused. Original question: Meaning of a missing principal (not yet known, deleted, known at session end, kept for Chronicle, authority not proven) | Implemented locally in WU-16; required principal and evidence are validated before writes | Audit actor/subject record ≠ live association; never revoke on `principal_id` presence alone |
| SO-3 | Method C table design: Flow↔Token and Flow↔Principal bindings, history after token/principal deletion, and authority versus evidence ownership | Decided D-172/D-173; D-179 (2) removes legacy flow rows; implemented locally in WU-16/22 | OP stop plus typed root/grant/cutoff/participant/browser children replace the old logout-flow authority; principal remains a public-id value across databases |
| SO-4 | Remove `belongs_to_required_by_default = false` | Superseded by D-179 (2); implemented by removing the legacy models and concern | No optional association default remains in the removed flow family |
| SO-5 | Remove the `SignOutFlow` concern inclusion hook and its model-specific behavior | Superseded by D-179 (2); implemented by removing the concern and flow model family | Flow callbacks, associations, validations and scopes are no longer part of sign-out |
| SO-6 | Safety of the existing logout paths | Standing checklist (three.md G-16) | Focused checks cover the touched browser logout, authority stop, outbox and RP receiver boundaries; the broader G-16/WU-14 and browser acceptance remain open |
| SO-7 | **Decided D-123:** history on the stop record side, references `ON DELETE RESTRICT`, physical deletion only through the retention purge. Original question: DB constraints and deletion contract (token FK `ON DELETE CASCADE`, history after principal deletion) | Implemented locally in WU-16/22; explicit child-first purge and restrictive FKs | Cross-DB principal is stored by public id; purge waits until all referenced roots are eligible and every participant is final |

**ADR reading order (H5):** `first-party-sign-out-op-commit-and-backchannel-logout-for-separated-rp-stores`,
`first-party-sign-out-shared-database-without-backchannel-logout`, `base-auth-ceremony-and-seven-rp-boundary`,
`logout-ceremony-boundary`, `logout-primitive-and-composition`, `identity-centric-aaa-architecture`,
`authentication-security-cycle-consolidation-2026-10-15`, `docs/security/logout-session-management.md`,
`docs/security/logout-sequence.md`; decide conflicts by explicit supersession and scope, not by date.
Known amendment: the 2026-10-16 ADR's durable outbox clause vs D-28/D-30 (BCL only); residual
access bound 300 s + 30 s vs `CoreBrowserCredentialContract::ACCESS_TTL` 10 min (X-9).

**Existing tests to keep green and read first:** `test/models/sign_out_flow_test.rb`,
`test/controllers/concerns/authentication/logout_current_session_test.rb`,
`test/services/account_session_revocation_test.rb`. (`test/controllers/concerns/sign_oidc_logout_completion_test.rb`,
listed here earlier, was deleted on 2026-09-20 in `52efa31df`; whether
`test/controllers/concerns/social_callback_and_logout_completion_test.rb` covers the same logout
completion is not checked.)

**Order:** Phase 1 re-investigation (paths, DBs, models, tokens, device/RP sessions, logout flows,
outbox, receipts; delivered/undelivered per contract) → SO-1, SO-2, SO-3, SO-7 decisions (owner) →
ADR updates → TDD for SO-3 → SO-4 → SO-5, one concern/model group at a time with its tests and the
convention checks → adversarial review. WU-16 and this unit share SO-3/X-4 and are decided together.

## WU-23 — Credentials and KMS documentation

**Contract:** D-15 (one credentials set per environment), D-17 (AWS KMS direction, co-location
Pending), §4 amendments: `adr/runtime-secret-isolation-deferred.md`,
`docs/security/role-secret-isolation.md`, `plans/backlog/2026-10-18-production-runtime-secret-isolation.md`
(per-role design withdrawn). Docs only; no code. Cross-reference the credentials key-name backlog
(`plans/backlog/2026-10-21-production-credentials-key-name-mismatch.md`).

## Order across all units

> **Replaced by Part 6.6 (H18).** Kept for history.

Updated 2026-10-22 after D-84 … D-127.

1. Ready and independent: WU-04, WU-01, WU-03, WU-09, WU-11, WU-23, WU-26 (read-only), WU-31
   (Red tests), WU-32, WU-33 and WU-35 (investigations), WU-36, WU-37, WU-39 (docs), and the X-26
   Red test AX26-1/AX26-2 → then WU-34.
2. WU-24 (effective intent, curfew storage, E1; D-125/D-127 deletion first) → WU-05 (ADR first;
   Finalization per D-105; lock order after WU-35) → WU-08 → WU-06 → WU-07 → WU-38.
3. WU-02 (Visa) → WU-25 → WU-12 → WU-13 → WU-29 (Sentry; its OP redirect sites now on Visa) →
   WU-14 → WU-10 → WU-17 → WU-18 → WU-21 → WU-27.
4. WU-15, WU-16 and WU-22 implemented locally on 2026-10-25; their acceptance and upstream gates
   remain open as recorded in `three.md`. WU-19, WU-20 any time (WU-20 sequenced with WU-30).
5. Design first, then owner review: WU-28.
6. Gated: WU-30 on destructive-migration approval.

## WU-24 — E1 binding, effective intent and curfew storage (prerequisite)

> **Reissued by D-138 (H18): see Part 6.1 (sub-units WU-24a … WU-24h).** The text below is the earlier definition; its stage order and the cleanup it borrowed from WU-38 are replaced.

**Why (four.md R-20):** WU-05's P1/P4/C1 and R2-A need a Flow owned by the admitted Binding and a
curfew on the Binding; neither exists. `ClientSignUpFlow` has no E1 association; `SignUpCycleLocator#current`
resolves a Rails-session locator; `BaseAuthAdmissionCoordinator#create_or_reuse_binding!` caps the
Binding by the 60 s acceptance TTL; ordinary first-party Admissions carry `authentication`.

**Scope and order (each stage states what holds afterwards):**
1. **Effective intent (D-72):** one shared resolver from server state (Switch `entry_intent` →
   `prompt=create` → sign-in). Sign-up pages/actions require sign-up, sign-in ones sign-in;
   `validate_entry_parent_intent!` / `auth_ceremony_matches_intent?` stop accepting both under
   `authentication`. *After:* no page or param decides the intent.
2. **Curfew storage (D-45, D-74, D-75; D-105: a Finalization not completed before it is refused):** `curfew_at` on the Binding at issuance (OP DB
   `clock_timestamp()`), copied unchanged to a Switch Binding; the acceptance code keeps its 60 s.
   Migration: NOT NULL, no default (X-13 / owner approval for schema). *After:* every Binding has one
   immutable deadline; consumers still use old checks until WU-06.
3. **E1 association:** `auth_admission_binding_id` on `ClientSignUpFlow` / `VisitorSignUpFlow` (same-DB
   FK, immutable after set, partial UNIQUE "≤ 1 in-progress Flow per Binding" — E1 ADR); migration
   choices decided (D-125, D-127): `attr_readonly` only (plus a static guard against `update_all`/raw
   SQL on the column); unbound Flows deleted, not backfilled, after listing counts and recovery;
   then NOT NULL; FK `ON DELETE RESTRICT` (Purger: Flow before Binding). *After:* a Flow names its
   Binding.
   **Correction (seven.md #7):** `entry_intent` is a column of the **Admission Binding**
   (`client_auth_admission_bindings`, `visitor_auth_admission_bindings`; nullable with a CHECK of
   `sign_in`/`sign_up`), not of the Flow, and the same table holds Re-verification rows. **D-129:**
   NOT NULL for every row; Sign-in path rows `sign_in`/`sign_up`, Re-verification rows an explicit
   "not applicable" value, tied to `purpose` by a CHECK.
   A migration table (column owner table, surfaces, Sign-in vs Re-verification rows, what is deleted,
   cleanup-before-delete order so pending principals stay traceable, what is kept for recovery,
   `curfew_at` for existing Bindings) is written before A24-5's approval.
   **E1 duplicate reference (seven.md #12):** the E1 ADR retires
   `AuthCeremonySession.local_sign_up_flow_ref`; today it exists on the ceremony session tables with
   an FK to the Sign-up Flow and in the purpose-exclusive CHECKs
   (`db/op_base_{com,org}_structure.sql`, read in `app/models/concerns/auth_ceremony_session.rb`).
   List every column, FK, CHECK and reader per APP/COM/ORG and retire it here; it is separate from
   `local_sign_in_flow_ref`, which WU-01 keeps.
4. **Authoritative lookup:** the Flow used by a request is the one bound to the redeemed Binding of
   the admitted ceremony; `SignUpCycleLocator` becomes a hint only (mismatch → ownership-mismatch
   refusal, D-73). *After:* a stale tab's locator cannot select another attempt's Flow.

**Tests:** cross-Binding stale tab; concurrent same-Binding Flow creation (separate connections);
each surface's predicate; all six entries and callbacks after acceptance but before the curfew;
missing/mismatched E1 ownership and missing deadline refused; Switch keeps `curfew_at`.

## WU-25 — Revocation client authentication and Discovery metadata

**Contract (D-79, R-30):** `/oauth/revoke` (on Visa after WU-02) authenticates each client by its
**registered** `token_endpoint_auth_method` equivalent for revocation (RFC 7009 + RFC 8414
`revocation_endpoint_auth_methods_supported`): `private_key_jwt` client assertions verified like the
token endpoint (audience = the revocation endpoint per the registration contract, `jti` replay
refused), `client_secret_post` only for clients registered with it, public clients per RFC 7009.
Discovery advertises `revocation_endpoint_auth_methods_supported` matching what is implemented.
Today all three realms pass only `client_id` + `client_secret` to `OidcTokenRevoker`, and Discovery
advertises no revocation methods (RFC 8414's default when omitted is `client_secret_basic`).

**Tests:** per realm: revocation with the registered method succeeds; wrong client, wrong realm,
wrong audience and replayed assertion refused without revealing token validity beyond RFC 7009;
Discovery equals the implemented set.

## WU-26 — Read-only diagnosis of partial registrations (D-82)

**Timing (seven.md #20):** implement after WU-24 (its report includes the Binding id, `curfew_at` and
effective intent added there); report replica lag, unavailable databases and the read time of each
database, since they are read at different moments.

**Goal:** an operator can tell, for one sign-up attempt or one subject, what each database holds,
without writing anything. No repair, compensation or deletion is defined here (X-28).

**Inputs:** one of — Sign-up Flow public id, Admission Binding entry reference digest, principal id,
or provider + subject digest (never a raw subject, token or contact value in the output).

**Report (one section per database owner, each with its read timestamp):**

| Owner DB | What is reported |
|---|---|
| OP (`op_base_{app,com}`) | Sign-up Flow: status, step, entry method, `completed_requirements` keys (names only), principal id, `curfew`/expiry, E1 Binding id; Admission Binding: purpose, effective intent, `curfew_at`, redeemed/retired; ceremony session state; Candidate: exists, `consumed_at`, `expires_at` (no `auth_hash`); OIDC transaction and result references: state, consumed |
| Principal (`app_principal` / com) | Client/Visitor: status, `login_allowed?`, `access_enabled?`; contacts with status; External Identity: provider, state, `released_at`, owner id; passkeys: status, discard; secrets |
| Graph owners | Identity, account, assignment, collective, membership, avatar presence for the principal |
| Root/Grant (OP token DBs) | Root tokens, grants, RP sessions issued for the principal after the Flow's start time (presence and timestamps only) |
| Logs / audit | Correlation: request ids and event names recorded for the Flow id (from structured logs and audit outboxes), not their payloads |

**Classification output:** one of the C.2 scenarios of `six.md` (e.g. "principal committed, graph
missing, Flow not completed, no authority issued") or "unclassified".

**Implementation form:** a read-only Rails runner/task that opens only reading roles
(`connected_to(role: :reading)` or explicit read-only transactions) and prints the report; refuses to
run with a writing role. Verified by running it against a constructed partial state in test data
and recording the output (no secret values) in `evidence/`.

**2026-10-26 follow-up:** `SignUpAttemptDiagnosisInventory` accepts exactly one Flow public id,
entry-reference digest, or principal public id, or the APP-only provider + subject-digest pair. It
returns every matching Flow, with explicit not-found and multiple-attempt results, and adds
OIDC/result lifecycle, ceremony session, social Candidate, audit outbox and Chronicle correlations.
Inputs are format-checked; raw references and provider subjects are not accepted or emitted. The
query reads only owner-local reading roles and refuses a writing scope. Entry-reference digest
lookup computes the existing SHA-256 reference digest across sign-up Bindings in memory; social lookup
hashes encrypted Candidate subjects in memory. No schema change was made. This closes the
input/output follow-up, not the entire D-82 acceptance: graph-owner inventory, grants/RP-session
timestamps, replica-lag/unavailable-database reporting and the full runner acceptance remain to be
reconciled.

---

# Part 3 — Work Units from the 2026-10-22 decisions (D-84 … D-127)

Added 2026-10-22 after the owner decided every open X item. Same implementer rules as Part 1.
Static reading at `febec3225`; re-verify file references before editing. Acceptance cases are in
`three.md` §2 under the same unit IDs.

| WU | Title | one.md | Status |
|---|---|---|---|
| WU-27 | Post-containment journey: no reissue, SSO recovery | D-104, X-20, TR G2/G3/G5 | Ready |
| WU-28 | Dev-only ORG Bootstrap rebuilt from scratch | D-122, D-13, X-12, R-14 | **Design first** (draft for owner review, then implement) |
| WU-29 | Sign entry Sentry | D-84 … D-99, T21 | Ready (flags written first) |
| WU-30 | Security Mode migration | D-88, D-92, T22 | Defined; **gated on destructive-migration approval** |
| WU-31 | Email OTP `already_verified` Red tests | D-89, T23 | Ready (tests only) |
| WU-32 | ORG normal sign-in durable halt audit | D-90, T24 | Ready |
| WU-33 | Sign-in failure convergence table | D-91, T25 | Ready (investigation only) |
| WU-34 | Sign In refuses unfinished registrations | D-106, X-26 | Ready after AX26-1 is executed |
| WU-35 | Lock acquisition inventory | D-107, X-27 | Ready (investigation only) |
| WU-36 | Every cookie host-only | D-115, X-22 | Ready |
| WU-37 | Puma workers and threads | D-120, X-8 | Ready (configuration; evidence only) |
| WU-38 | Partial registrations: automatic deletion | D-126 (2), D-135 | Ready after WU-24 and WU-05 |
| WU-39 | ADR and documentation amendments from the 2026-10-22 decisions | one.md §4 | Ready (docs only) |

## WU-27 — Post-containment journey (D-104)

> **Two kinds of lost response (D-130, after seven.md #3):** the auth cookies are set in the response
> after the commit (`AuthenticationBase#bind_committed_login!`). Lost **after** the cookies arrived →
> SSO recovery (D-104). Lost **before** → a sign-in failure: the person signs in again, nothing is
> reissued, the orphan Root Session expires or is removed through session-limit remediation.

**Contract:** a repeat of a finalized result (lost response, back, reload, second tab) always errors
and never reissues (D-2); recovery is the RP 続行 followed by the standard SSO branch of
`/oauth/authorize`, which issues a fresh code from the existing Root Session. A browser that already
has a Root Session never gets a second one. Concurrent tabs: each attempt succeeds or errors on its
own bindings; a later attempt's Admission never replaces bindings it does not own (R23-INV-2).

**Work:**
1. Classify every TR G2, G3 (Sign-in path cases only) and G5 failure against the contract; record
   per test whether the test is stale (rewrite to the contract) or the code is wrong (fix).
2. Rewrite stale tests to assert the error and the SSO recovery path; no test is deleted without a
   stated reason (G-3).
3. Add request tests: lost response after finalization → error on repeat, then RP 続行 → SSO code
   without a new Root Session; two tabs started in one browser → each refused or completed on its
   own binding, at most one Root Session.

**Exit:** TR G2/G5 resolved, G3 Sign-in path cases resolved; G3 Step-Up cases stay with the
Re-verification path (D-44) and are listed as such.

## WU-28 — Dev-only ORG Bootstrap rebuilt (D-122) — design first

> **Out of this cycle (D-170).** Full plan moved to `docs/backlog/2026-10-23-org-seed-operator-bootstrap.md`. Do not implement.

**Contract:** the current Bootstrap code, routes, seeds and data may be removed and replaced.
Review criteria (D-13, R-14): ORG only; development only; Entra `(tid, oid)` only; no Passkey;
separate controllers and callback; a deployment discriminator independent of `Rails.env`, checked
again at finalization, refusing when missing or unknown; a Bootstrap authentication context carried
through root, grant, refresh and access claims that never collapses into Normal (today
`AuthenticationContextValue.from_claim` maps a blank claim to Normal); no widening of existing
Operator roles; no Bureau/Ownership/Membership.

**Step 1 (this unit's first deliverable):** a design draft in this file (entry, discriminator and
its provisioning, context propagation, what is removed, destructive migrations with risk and
recovery plan) for the owner's review. **Implementation starts only after the owner accepts it.**

## WU-29 — Sign entry Sentry (D-84 … D-99)

**Contract:** `adr/sign-entry-sentry.md` (items 1–23) and
`plans/backlog/2026-10-22-sign-entry-sentry-implementation.md`; where they differ, the ADR wins.

**Order:**
1. Register `sign_{in,up}_available_{app,com,org}` (`:availability`) in `FeatureFlags::REGISTRY`;
   in every environment run `feature_flags:register`, write the six flags `true`, and record
   `feature_flags:status` in `evidence/` (D-97). Nothing reads them yet.
2. `SignEntrySentryResolver` (`app/resolvers/`) + `SignEntrySentryStateValue` (`app/values/`), with
   the explicit six-entry table (D-94).
3. OP root-login backstop: `AuthenticationBase#log_in`, `establishment: :root_login` only, refusal
   status before the commit, never inside a caller's transaction (D-93 (5)).
4. Auth Admission redemption and admitted-entry `show` (D-93 (2)); ticket ceremonies excluded.
5. `Auth::{App,Com,Org}::Sign::{In,Up}::SentriesController` and `resource :sentry, only: :show`
   routes; `ALLOWED` → 303 to `/sign/in` or `/sign/up` forwarding only the Admission reference
   (context via `PreferenceGlobal#default_url_options` and `signed_pt_param`, D-86); `BLOCKED` →
   503, `Cache-Control: no-store` (D-85).
6. Point the OP ceremony-start and Switch redirects (5 sites, wherever they live after WU-02/WU-13)
   at the Sentry paths by effective intent (D-93 (1)).
7. Every Sign-in path evidence/registration action and the provider callbacks (refused, no draining,
   D-95); ORG Emergency outside, invitations and the recruit page gated (D-96). **The enforcement
   list is the final route/action table after WU-12 (seven.md #16), not HTTP verbs:** generate it
   from `bin/rails routes` for each Auth surface (including PATCH/PUT `update` actions such as the
   Email OTP `update`, Apple and Google callbacks, every surface) and map each row to "checked" or
   "exempt with reason"; A29-4 asserts that table.
8. In the same change as 3–7: remove `sign_up_suspended_*`, `SignUpSuspension`,
   `SignUpSuspensionGuard` and their tests, moving every current guard site to the resolver (D-97).
9. Documentation: `docs/security/authentication-capacity-admission.md` control table,
   `docs/security/idp-flow-lifecycle.md` availability row, sign-in/up sequence docs, checklist.

**Decided (D-169):** copy without reason, no `Retry-After`, `no-store`, one reason-coded log event, no audit/telemetry record. *(Earlier text:)* D-UX (copy, i18n keys, `Retry-After`) and D-OBS (logging/audit) are
proposed with step 5 and confirmed by the owner before merge.

## WU-30 — Security Mode migration (D-88, D-92) — gated

> **Status 2026-10-26:** D3 mutation consumption is wired for the APP/COM/ORG consumers listed in
> `evidence/2026-10-26-wu30-step-up-consumption-M3A7.md`, in addition to the earlier passkey and
> contact work. The current implementation binds each proof to its operation scope, actor and
> session; per-record target binding remains deferred (`resource_ref` is nil in existing settings
> callers). Mutations whose target state and root token live in separate databases also lack a
> distributed commit guarantee if the root-token database fails after the target write commits.
> The destructive-migration gate remains open.

**Contract:** `adr/authentication-security-mode.md` as amended by the consolidation ADR: rename
`mfa_level_id` → `security_mode_id` and the reference models; valid values `NORMAL=3`,
`ADVANCED=7` only; `0`, other values and `NULL` permit neither authentication nor authorization;
APP/COM `ADVANCED` ordinary sign-in requires a passkey (C1, social included); `ADVANCED` holds at
least two active passkeys, deletion 2 → 1 refused; step-up method sets and windows per consolidation
§2.3; `mfa_level_enabled` meaning retired; `docs/mermaid/` axis in the same change.

**Mapping (D-92):** APP/COM every existing value → `NORMAL`; ORG every Operator → `ADVANCED`; an
Operator with fewer than two active passkeys keeps signing in with them and is required to register
a second.

**ORG permission rule (D-132):** one active passkey → ordinary sign-in allowed, every action except
passkey registration and sign-out refused until a second exists; zero → ordinary sign-in impossible
(recovery stays Pending); Emergency unchanged; Re-verification readers change their reference only.

**Gate before any migration runs:** the destructive-migration approval with row counts per realm,
risk and recovery plan (AGENTS.md). Re-survey the latest local branch first.

**Today:** `ClientMfaLevel` etc. define `NOTHING/WEAK/MEDIUM/FULL` = 0/1/5/9;
`AuthenticationBase#mfa_required_for?` = level ≠ `NOTHING`; `mfa_bypassed_for_auth_method?` =
passkey.

## WU-31 — Email OTP `already_verified` Red tests (D-89)

**Scope:** tests only; no production change. APP (`Auth::App::Sign::In::EmailsController`) and COM
(`Auth::Com::Sign::In::EmailsController#update`).

1. A second `update` in the same admitted ceremony with a **different** code inside the result
   window.
2. The same submission from another independently admitted ceremony for the same account (ADR A
   expects refusal).
3. Two concurrent `update`s with the correct code (separate connections): at most one evidence
   record, no second session (ADR B, R23-INV-4).

Record each result (pass or fail) in `evidence/`; the reconciliation is decided by the owner after.

## WU-32 — ORG normal sign-in durable halt audit (D-90)

**Contract:** an attributable halt in `OrgNormalSignInTransaction#halt_org_normal_sign_in_transaction!`
writes exactly one `OperatorChronicle` `SIGN_FLOW_HALTED` record directly (no outbox): safe surface,
flow correlation, reason, request/time facts, no secrets. A replay writes none. A Chronicle write
failure is not swallowed and the request does not report success. 409, HALT, safe GET/HEAD refusal
and no new token/challenge are preserved.

**Exactly-once (D-134, after seven.md #6):** the HALT state lives in the Rails session and Chronicle in
another database, so concurrent requests or a lost response can both see "not halted". The halt row's
`context` carries the transaction public id and halt generation; a partial unique index on
`operator_chronicles` over those two values `WHERE event_id = SIGN_FLOW_HALTED`, plus a CHECK that
both keys exist for that event, rejects a second insert, which the application treats as already
recorded. Migration under the chronicle migration role.

**Work:** restore the removed positive audit assertion in the controller regression (backlog
`plans/backlog/org-normal-sign-in-durable-halt-audit.md`, reproduction C6R2); implement; close the
backlog item.

## WU-33 — Sign-in failure convergence table (D-91)

**Deliverable:** a table (in this file or `research/`) for each surface × method (email OTP,
telephone, passkey, TOTP, secret, Google, Apple, Entra) × outcome (credential failure, actor not
allowed, issuance failure, MFA pending, session-limit pending, OIDC handoff failure) → D-73 class
and HTTP result today, with file and line. Static reading only; no code change. Implementation waits
for WU-27.

## WU-34 — Sign In refuses unfinished registrations (D-106)

> **COM (D-128, after seven.md #1):** COM creates the Visitor `ACTIVE` at candidate creation today
> (`EmailSignUpCandidateCreator`; telephone likewise) and `VisitorStatus` has only
> `ACTIVE/NOTHING/RESERVED`. This unit therefore also adds `UNVERIFIED_WITH_SIGN_UP` and
> `VERIFIED_WITH_SIGN_UP` to `VisitorStatus`, creates COM candidates in the unfinished status,
> promotes them at Finalization (D-131's decisive commit), migrates existing COM data, and then
> applies the same refusal predicate to APP and COM.

**Precondition:** AX26-1 (and AX26-2) executed and recorded.

**Contract:** Sign In refuses, on every method (OTP, Passkey, Secret, social, TOTP), a Client or
Visitor whose status is an unfinished registration (`UNVERIFIED_WITH_SIGN_UP` and every other
pre-Finalization status, listed from the models), in `login_allowed?` or the single equivalent
predicate. No new durable fact; fail closed; no other check weakened. Today
`Client::LOGIN_BLOCKED_STATUS_IDS = [ClientStatus::RESERVED]` and discoverable Passkey sign-in
checks only passkey status, discard and `actor.active?`.

## WU-35 — Lock acquisition inventory (D-107)

> **H18 (D-139): report in Part 6.2**; the Q9 target below is not an approved final order.

**Deliverable:** every lock acquisition on the Sign-up and Sign-in paths (Admission Binding,
Sign-up Flow, principal subject lock, Client, identity graph, link/unlink, existing sign-in, cleanup)
with file, line, database and the order in which each path takes them; deviations from the Q9 target
(OP Flow → principal subject → Client) marked. Static reading; the owner fixes the final order from
it. WU-05 F3 and WU-38 wait for that order.

## WU-36 — Every cookie host-only (D-115)

> H18 P-141 (proposal): no Domain-cookie deletion exception — nothing was deployed, so no browser holds a production Domain cookie; development/staging browsers are cleared by hand. If the owner rejects P-141, the alternative is a bounded exception (enumerated legacy names, deletion only, `Max-Age=0`, removed after the longest cookie lifetime) recorded with its exit condition.

**Contract:** `CoreCookieOptions.for` sets no `Domain`; `CoreCookieDomain` is removed; the
production `Partitioned` attribute is removed; authentication, preference, withdrawal and
enforcement-recovery cookies are all host-only. A cookie found to need cross-subdomain sharing is
reported, not kept. Today `CoreCookieOptions.for` has 9 call sites (`grep -rn "CoreCookieOptions.for"
app lib`).

## WU-37 — Puma workers and threads (D-120)

**Contract:** raise Puma workers and threads (today one process, `RAILS_MAX_THREADS` default 3) to
values from a recorded load estimate; size the database pools to match. No concurrency cap on
RP→OP self-calls (accepted risk, D-120). Environment construction: verified by running and recording
in `evidence/`, never by a Minitest case.

## WU-38 — Partial registrations: automatic deletion (D-126 (2), D-135)

**Contract:** a Flow past its D-45 deadline whose principal has not reached the registered status
(D-131) is cleaned up by the sign-up cleanup axis (R-3), deleting its unfinished principal data
(pending Client/Visitor, contact, Passkey). No user-initiated reset (D-135): a new sign-up with a
contact still held by an unfinished registration is refused until cleanup has run. A registered
Identity is never touched. Diagnosis stays read-only (WU-26).

**Depends on:** WU-24 (Binding, curfew), WU-05 (pending-Client model), WU-35 (lock order).

> H18: WU-24 no longer runs any part of this unit (Part 6.1). Cleanup repair (decision under the principal lock, idempotent retry) lands earlier in WU-24e; this unit adds the curfew trigger, the D-131 predicate for APP and COM (after WU-34's COM statuses) and the D-135 refusal. Lock order: Part 6.2 F-1.

**Defined (D-176, 2026-10-25):** refusal copy option A (email and telephone variants, nothing about
registration state); cleanup schedule stays `SignUpExpiryJob` every 15 minutes.

**Status (2026-10-25): implemented.** Evidence: `evidence/2026-10-25-wu38-curfew-cleanup-refusal-R38K.md`.
- Curfew trigger: a Flow's `expires_at` is already capped at its Admission Binding `curfew_at` at
  creation and is immutable, so `SignUpExpiryJob` (every 15 minutes) expires the Flow at the curfew
  and `SignUpTermination` runs `SignUpArtifactCleanup` (Flow lock first, then the principal; 6.2 F-1,
  repaired in WU-24e). No code change was needed for the trigger; tests now pin it (curfew − 1 s,
  at, + 1 s; APP and COM; registered identity untouched).
- D-131 predicate: unchanged from WU-24e/WU-34 (`UNVERIFIED_WITH_SIGN_UP` for Client and Visitor).
- D-135 refusal: `SignUpContactHoldQuery` (contact with the same destination digest, not `DELETED`,
  owner in `UNFINISHED_REGISTRATION_STATUS_IDS`) is checked under the destination's
  `SignUpEmailPendingGuard` advisory lock in APP/COM email entry and in
  `TelephoneSignUpCandidateCreator` (new outcome `:contact_held`); the controllers answer 422 with the
  D-176 copy and create nothing. The browser's own superseded Flow is terminated and cleaned before
  the check, as before.
- Changed contract: two browsers could previously hold independent candidates for one destination;
  now the second is refused while the first is unfinished, for registered and unregistered
  destinations alike (the "fresh sessions cannot distinguish" tests were updated accordingly).
  Residual disclosure: the refusal tells a caller that some unfinished attempt holds the destination
  (not whether an account exists) — the consequence D-135 accepted.
- Follow-up (2026-10-26, D-180): APP/COM now have the read-only
  `SignUpStuckRegistrationReportQuery` for missing-Flow unfinished principals/contacts and terminal
  Flows with pending/failed cleanup at 10 or more attempts. `RetentionPurgeJob` emits one structured
  report event after its own cleanup and retention work; a query failure is logged without stopping
  that work. The query refuses a writing role, and the event contains identifiers/counts without
  contact values. It does not change registration state. The retention purge now keeps a
  non-completed terminal Flow until cleanup completes, allowing the capped case to remain
  diagnosable. ORG cannot express these cases with its
  current operator status and Flow retry schema, so it is excluded rather than reported as empty.
- Release boundary: an operator may retry case (b) once after diagnosis through the existing
  `SignUpArtifactCleanup.call(cycle:)` entry point. Case (a) has no Flow for that operation and no
  safe existing release path; its contact remains held and the case is escalated. See
  `docs/operations/stuck-sign-up-registration-runbook.md` and
  `evidence/2026-10-26-wu38-stuck-registration-report-S8J4.md`.


**2026-10-25 (D-177, D-178).** Sign-up entry is fail-closed: inline `cleanup_pending_signup!` and
`supersede_active_sign_up_flow!` are removed; a second entry submit while the browser's attempt is
not terminal-and-cleaned is refused (422, contact-held copy). A session hint for an earlier
admission's released attempt is dropped (`SignUpCycleLocator#current`). The late APP telephone
Passkey save is only refused (no inline expiry/cleanup). The birthdate checkpoint decides age on the
unsaved value (no underage birthdate is written) and keeps same-request halt + cleanup. Evidence:
`evidence/2026-10-25-codex-review-and-wu38-fail-closed-F7C1.md`,
`evidence/2026-10-25-wu38-underage-birthdate-D8B2.md`. The Email/Telephone sign-up OTP issuers,
verification committers and delivery guards refuse an overdue parent without the inline expiry
(owner, 2026-10-25).
## WU-39 — ADR and documentation amendments (2026-10-22)

Docs only, each a separate commit-sized change listed in one.md §4:

- New ADR: Sign-in path continuation protocol (D-100, D-101; Design D, RFC 9110 deviation with its
  six conditions); amend the 2026-09-21 / 2026-09-20 text, AUTH-1/AUTH-2 and
  `generic/authentication-boundaries.mdc`.
- `adr/first-party-sign-out-op-commit-and-backchannel-logout-for-separated-rp-stores.md`: residual
  bound 10 min + 30 s (D-111); durable outbox kept, Solid Queue delivery (D-117, D-121); receiver
  parent `ActionController::API` as a scoped exception (D-118).
- Passkey capacity ten (D-116): `adr/passkey-identifier-first-sign-in.md`,
  `adr/identity-resolution-and-credential-binding.md`,
  `adr/passkey-current-state-limit-and-chronicle-outbox.md`, `adr/README.md`.
- Consolidation ADR §2.6 and Security Mode ADR Open decision 1 (D-92).
- Sign-up Finalization: D-105 replaces D-83 in the new Sign-up Finalization ADR (WU-05).
- OIDC authorization profile (added 2026-10-22, H20/H21): `redirect_uri` per RFC/OIDC with exact
  match and no error to an invalid URI (D-145); post-validation errors redirected, unsupported
  `prompt` a direct 400, `prompt_values_supported` per realm, `invalid_grant` for mismatches and PKCE
  failures, registration-time validation (D-147, D-148); Jump forwarding as an accepted risk (D-146).
  One ADR or an amendment of the existing OIDC client/authorization ADRs, with `adr/README.md`.
- RP `state` and target (added 2026-10-22): ES384 JWS `state` with its own `typ`/`aud`, key reuse
  trade-off, no per-`state` revocation as an accepted risk, browser binding in the cookie pending
  entry, Rails CSRF unchanged (D-149); 30-minute lifetime without grace (D-150); `pt` abolished on
  the RP and `target_link_uri` path only (D-151), recording the supersession of D-137 / D-42 / D-109
  and the partial supersession of D-145 §7 in `adr/redirect-target-lanes-pt-nt-xt.md` /
  `adr/signed-return-targets-only.md` (the RP lane) and the Base/Auth boundary ADR; Cancel returned by
  the OP per specification and handled by the RP (D-152); `GET /sign/interruption` (D-153).
- One sign-in at a time (D-155): in the RP sign-in sequence documentation
  (`docs/security/sign-in-sequence.md` and the RP entry docs), state that a browser runs one RP
  sign-in at a time, the last `POST /sign` wins, and an earlier tab may proceed through Auth/OP and is
  rejected at the RP callback with `/sign/interruption` — intended behavior, not a defect. When the
  earlier tab was a Sign Up, its registration is still saved (D-131/D-135) and only its sign-in
  handoff is refused (at the OP because the browser already has a Root Session, or at the RP); the
  person signs in with the new account later. The rule is per browser; different browsers are
  independent and only the account's session limit applies.
- Key rotation runbook (`docs/operations/` or the JWT key documentation): after rotating an RP
  `oidc_client:<namespace>` key, keep the old public key for at least 30 minutes plus
  `CLOCK_SKEW_LEEWAY_SECONDS` so in-flight `state` values verify (D-150); a new OP signing key is
  published at least 1 h 5 min before first use (D-144).

---

# Part 4 — Sub-units of the large Work Units (D-133)

Added 2026-10-22 after the `seven.md` review. WU-01, WU-02, WU-05 and WU-18 are implemented **only
through these sub-units**, one per implementation request, in the listed order. Each sub-unit
inherits its parent's contract and the rules at the top of this file. "Commit point" names the
database writes the sub-unit introduces; "Left on failure" is what remains if it stops half way.
"Stop if" is a condition under which the implementer stops and reports instead of improvising.
Acceptance IDs keep their numbers; `three.md` §2 maps them to sub-units.

## WU-01 sub-units

| Sub-unit | Scope (WU-01 step) | Needs | Commit point / left on failure | Tests | Stop if |
|---|---|---|---|---|---|
| WU-01a | Classify the 72 test files (preliminary list in Part 5.7) calling `issue_local_entry!` into (i) local-subject and (ii) local-as-fixture; written list only (step 2 analysis) | G-1 baseline | None (document) | — | A file fits neither class |
| WU-01b | Re-point the class (ii) tests to an OIDC-parent entry, in batches of ≤ 10 files, assertions unchanged (step 2) | WU-01a | None | The re-pointed files: each batch has the same pass/fail set as the G-1 baseline for those files (a baseline failure keeps failing for the same reason; nothing newly fails) | An assertion would have to change, or a baseline failure changes its reason |
| WU-01c | Red tests, then remove the receiver and handoff routes/controllers (steps 3, 4a) | WU-01b | None | A01-1 + affected suites | Dead-code check not clean |
| WU-01d | Remove `issue_local_entry!`, its helpers and purposes; delete class (i) tests with the code (step 4b) | WU-01c | None | A01-2, A01-4 | A caller outside the inventory appears |
| WU-01e | Local branches in shared code, one file per change, OIDC behavior unchanged (step 4c) | WU-01d | None | Per file: its tests + OIDC suites | An OIDC test changes outcome |
| WU-01f | `LocalAuthenticationResultCoordinator`; `LocalAuthenticationSessionCommitter` only if proven local-only (step 4d), refactor, docs (steps 5, 6) | WU-01e | None | A01-3, A01-5, A01-6 | The committer is reachable from an OIDC parent |

## WU-02 sub-units (rewritten 2026-10-23, D-161; replaces 02c … 02h)

Precondition unchanged: WU-04, WU-05 (through WU-05g), WU-01 and WU-03 done. Implementer effort:
medium or higher for 02-APP, 02-COM and 02-ORG. There is no other WU-02 order; the earlier
02c … 02h split is withdrawn (it left a realm half on Visa and half on `www` between commits).

Why one realm moves in one commit (verified in code): the Admission browser nonce lives in the
host-only Rails session (`base_admission_browser_binding.rb:12`, D-58), so `/oauth/authorize` on
Visa with the binding confirmation still on `www` cannot read it; `JumpRtReturnPolicy::ALLOWED_EDGES`
(`app/policies/jump_rt_return_policy.rb:10`) refuses any `VISA_*` edge it does not list; the
logout launcher must target the moved `/oidc/logout`.

| Sub-unit | Scope (WU-02 steps) | Needs | Commit point / left on failure | Tests | Stop if |
|---|---|---|---|---|---|
| WU-02a | V1 host contract + V2 `VISA_*` JWT namespaces and keys (keys exist, nothing signs with them yet) | baseline | None (configuration recorded in `evidence/`) | A02-3 | A host must be wildcarded |
| WU-02b | V3 Visa skeleton (empty surface, bases, routes, health, CSP report) | WU-02a | None | Routing/base-class tests, A02-2 | A Visa controller needs an RP concern |
| WU-02-APP | For APP only, in one commit: V4 OP endpoints to Visa; V5 APP issuer, signer, Discovery, expected issuer in every APP reader; V6 Auth APP result target → Visa, Re-verification → Base; V7 Sign-in path binding confirmation on Visa, Re-verification stays on `www`; V8 Rails-side Jump edges for `VISA_APP` (`ALLOWED_EDGES`, `JumpRtSurface`); V9 APP logout across hosts; V10 root issuance, selector and session-limit steps on Visa | WU-02b | APP fully on Visa; COM and ORG fully unchanged. Failure before the commit leaves nothing; after it, rollback = revert this commit (APP back to `www` as a whole); development tokens issued under the other issuer become invalid (accepted, D-159) | A02-1, A02-4 … A02-9, A02-11, A02-13, A02-15 for APP; G-15, G-16; COM/ORG suites unchanged | An endpoint has a non-OP caller on Base; any APP reader still accepts the `www` issuer; a reader of `base_authority_host` cannot be classified; TR G1 passes for a reason other than the split |
| WU-02-COM | Same as WU-02-APP for COM (no social completion, D-161 (4)) | WU-02-APP | Same, for COM | Same cases for COM | Same |
| WU-02-ORG | Same for ORG (no Switch; Entra callback unchanged) | WU-02-COM | Same, for ORG | Same cases for ORG | Same |
| WU-02i | Base pages read RP state only (A02-12); V11 ADR "Visa OP host", README routing, `docs/dds.md`, `docs/security/*`; Jump handoff document (table in plain language, JWKS URLs, `iss`/`aud`, refusals Jump must keep) | WU-02-ORG | None | A02-10, A02-12, A02-14 recorded Not run, G-5 | A Base page still reads OP-written session state |

**Jump (D-161 (2)).** The Jump/Edge repository is not changed in this cycle. After WU-02-APP the
APP sign-in through the deployed Jump stops working in development; this is accepted and the Jump
change is designed after this implementation. Acceptance is by Rails tests only; A02-14 and A42-6
are recorded **Not run (Jump change pending)**. Later units on a migrated realm (WU-12, WU-13,
WU-29, WU-14, …) are likewise accepted by Rails tests only.

**Provider callbacks (D-161 (4)).** The redirect URIs registered at Google, Apple and Microsoft are
fixed: `OmniAuth.config.full_host` = `PUBLIC_AUTH_SERVICE_URL` (`config/initializers/omniauth.rb:104`)
with `/social/google/callback`, `/social/apple/callback`, `/social/entra/callback`. No unit changes
them. WU-02 moves no provider callback to Visa and leaves the duplicate google/apple callback
routes on `www` (`config/routes/base.rb:246-257`) untouched; whether they are dead is a separate
item. `/social/authentication/completion` on `www` is an internal UMAXICA receiver, not registered
at any provider; WU-05 replaces it before WU-02 starts.

## WU-05 sub-units

Precondition: WU-24 (through WU-24h) done; for WU-05e also the owner's decision on WU-35 F-1 (D-139, Part 6.2).

| Sub-unit | Scope (WU-05 §5.E / §5.K) | Needs | Commit point / left on failure | Tests | Stop if |
|---|---|---|---|---|---|
| WU-05a | New Sign-up Finalization ADR (U4) incl. D-105, D-128, D-131; characterization tests of the six paths | WU-24 | None | A05-1, A05-5 | Characterization shows a Sign In First violation that is **not** already in the G-1 baseline or the AX26-1/AX26-2 record (known ones are recorded as expected-red with their reference) |
| WU-05b | Effective intent enforcement on sign-up pages/actions (EI-1/EI-2) | WU-05a | None | A05-2, A05-13 (intent part) | A page decides intent from params, Referer or the page |
| WU-05c | One social Flow per attempt at the entry (R2-A); callback never creates one; remove the dead callback path (D-71) | WU-05b | Social Flow rows created at the entry, bound to the Binding | A05-3, A05-4 | The callback still needs to create a Flow |
| WU-05d | Pending social Client in Auth (P1–P5) + Candidate (C1–C3) + birthdate unification | WU-05c | Pending Client in the principal DB (unfinished status, D-128/D-131); Candidate row in the OP DB. Left on failure: an unfinished principal, removed by the existing cleanup axis (`SignUpExpiryJob` → `SignUpArtifactCleanup`, repaired in WU-24e); WU-05d tests assert only that it stays unfinished and refused at sign-in, not WU-38 behavior | A05-6, A05-7, A05-12 | A pending Client would be reused across Flows (D-77) |
| WU-05e | Finalization social branch and shared order (F1–F6) with the decisive principal commit (D-131) and deadline check (D-105) | WU-05d, WU-35 order | **Decisive commit:** principal registered status. Before: unfinished, deletable. After: registered; graph and OP Flow completion are completed idempotently later | A05-8, A05-9, A34-5, G-11, G-14 | The lock order would differ from WU-35's decision |
| WU-05f | Sign In First handoff for Google/Apple (S1–S4) | WU-05e | None beyond Sign In's own | A05-10 | Sign Up would need its own session writer |
| WU-05g | Remove the old social sign-up transport (Base social completion sign-up branches, committer `commit_signup!`), docs, mermaid, turnstile doc, evidence | WU-05f | None | A05-11, G-5 | A non-sign-up caller of the removed code exists (§5.H) |

## WU-18 sub-units (OP-chain and RuntimeRole)

> **2026-10-26:** see the note under WU-18 (D-181). Sub-unit text below kept as history until the consolidated definition replaces it.

| Sub-unit | Scope | Needs | Commit point / left on failure | Tests | Stop if |
|---|---|---|---|---|---|
| WU-18a | Inventory: OP-chain callers, routes, tables, tests; RuntimeRole readers (`rp_cell_local_session.rb`, `oidc_client_registry.rb`, `lib/runtime_role*.rb`, the route guard initializer, JWT registry/installer, `development.rb`); per RP, which path callback, JWT verification, refresh and local session use today | WU-02 done | None (document) | A18-1 | A client cannot be mapped to one path |
| WU-18b | Per-RP switch plan: how each RP's callback, verification, refresh and local session move to the standard-RP path without a role (document, owner review) | WU-18a | None | — | The switch needs a flag or dual authority |
| WU-18c | Remove the OP-chain path and RuntimeRole for **app** surface RPs | WU-18b accepted, WU-10, WU-11 | None in code; table drops excluded | A18-2 (app) | Standard-RP tests are not green before removal |
| WU-18d | Same for **com** | WU-18c | Same | A18-2 (com) | Same |
| WU-18e | Same for **org** (incl. Tech) | WU-18d | Same | A18-2 (org) | Same |
| WU-18f | Drop the OP-chain tables | WU-18e, owner approval with counts and recovery | **Destructive**: tables dropped | A18-3 | Approval missing |

**Status (2026-10-25):** WU-18a **done** (static reading, below). WU-18b plan kept as written
(open questions Q18-1 … Q18-4 stay open). **WU-18c … WU-18f deferred to a later cycle (D-175)**;
backlog entry `docs/backlog/2026-10-25-op-chain-runtime-role-removal.md`.

### WU-18a — Inventory (static reading, 2026-10-25, base `bde2346c1` + uncommitted worktree)

Re-verify each line against the code before any deletion; WU-10 (refresh) is being changed
concurrently.

**What selects the path today.** One predicate: `RpCellLocalSession#rp_cell_process?`
(`RuntimeRole::RP_ROLES.include?(RuntimeRole.current)`, i.e. `ENV.fetch("UMAXICA_RUNTIME_ROLE")`).
The development container (`.env.container.devcontainer`) and CI (`.github/workflows/ci.yml`, two
jobs) set `shared`, so **every one of the 12 RPs runs the OP-chain path in development, CI and the
test suite**. The standard (cell) path runs only where a test switches the role:
`test/support/rp_cell_session_helper.rb` (`as_rp_cell`, used by
`test/integration/rp_cell_local_session_readiness_test.rb`, one test per client) and
`test/controllers/palm/app/oidc/callbacks_controller_test.rb:273` (`rp-palm-app-jp`). The selection is
per process, not per client, so every client maps to exactly one path in a given process (A18-1 stop
condition not hit).

**Branch points (`if rp_cell_process?`)** — each has an OP-chain arm (role `shared`) and a standard arm:

| Location | OP-chain arm (today, `shared`) | Standard arm (`rp-*`) |
|---|---|---|
| `oidc_callback.rb#show` (:65) | access-token resource via `OidcAccessTokenAuthenticator` (`OidcRpIdentityProvisioning`), UserInfo, `provision_rp_account_from_id_token!` (canonical actor + `*OidcIdentityBinding`/`*Identity`/`Core*Bridge`), cookies, `bind_oidc_rp_grant_logout_token!` (writes `Op*Grant.oidc_sid` and `Op*GrantLogoutHint` in the OP database) | `complete_rp_cell_callback!` → `RpCallbackCommitter` (cell principal, identity binding, OP session binding, local session cookie) |
| `oidc_callback.rb#verify_id_token!` (:259) | `OidcIdTokenVerifier` (in-process key through `AuthenticationTokenService`) | `OidcOpIdTokenVerifier` + `OidcOpJwksClient` (Discovery/JWKS, WU-11) |
| `browser_rp_authentication.rb#resolve_browser_rp_access_cookie` (:505) | `OidcRpBrowserCredentialContract.decode_access_token` (in-process key) + chain read `Op*Grant` → device session → root token → canonical actor (`find_browser_rp_session`, `browser_rp_resource_for`, `valid_browser_rp_chain?`); yields `BrowserSessionSecurityContext` (root token, browser session) | `resolve_rp_cell_access` → `RpRequestAuthenticator` (JWKS + local session); resource = cell principal, `security_context: nil` |
| `browser_rp_authentication.rb#refresh_browser_rp_credentials!` (:758) | `OidcOpTokenClient.refresh` over HTTPS | `refresh_rp_cell_credentials!` → `RpRefreshCommitter` (being replaced by WU-10, D-25) |
| `browser_rp_authentication.rb` :573 (`rp_cell_selected_context`), :734 (clock) | selected context from the OP root token; DB clock `Op*Grant.database_now` | selected context from the OP owner API (`OrgAdminAuthorityClient` `/identity/selection`, Base only); `Time.current` |
| `core_browser_api_boundary.rb` :46 / :151 | Core API: same in-process decode + `Op*Grant` chain; refresh via `OidcOpTokenClient.refresh` | `authenticate_core_cell_session!` / `refresh_core_cell_token!` |
| `oidc_rp_logout_launcher.rb` :515, :681, :688, :714, :725 | logout credentials from `Op*Grant` (`find_oidc_rp_logout_session*`, `valid_oidc_rp_logout_access?`), revoke via `RpSessionRevoker(scope: :rp_session)` on the OP grant | `resolve_rp_cell_logout_credentials`, local session revoke, cookie clear |

**Dead arm found:** `OidcCallback#show`'s `log_in(..., establishment: :rp_session)` arm runs only when
`oidc_rp_credentials_only?` is false; all 12 callback controllers override it to `true`, so that arm
and the non-`credentials_only` half of `bind_oidc_rp_logout_session!` are unreachable today.

**Callers (controllers including the branching concerns; all served by both paths):**
`BrowserRpAuthentication` — `{base,core,warp}/{app,com,org}/application_controller.rb`,
`edit/org`, `tech/org`, `palm/app` application controllers and `base/com/identity/emails/registrations_controller.rb`.
`OidcCallback` — the 12 `*/oidc/callbacks_controller.rb` (base app/com/org, core app/com/org, warp
app/com/org, edit org, tech org, palm app). `CoreBrowserApiBoundary` —
`core/{app,com,org}/api/v0/base_controller.rb`. `OidcRpLogoutLauncher` — `base/*/sign_outs_controller.rb`,
`core|warp/*/sign/outs_controller.rb`, `edit/org/sign/outs_controller.rb`,
`palm/app/sign/outs_controller.rb` + `sign/out/completions_controller.rb`,
`tech/org/sign/outs_controller.rb` + `sign/out/completions_controller.rb`.

**Routes:** the OP-chain path has **no routes of its own**; it is the `shared` arm of the RP routes
above (`/oidc/callbacks`, protected pages, `/api/v0/*` Core APIs, sign-out). Route ownership is
`RuntimeRole.route_owner` / `serves?`; `shared` serves every controller.

**Tables read or written by the OP-chain arm (from the RP side):**
OP database — `op_{app,com,org}_grants` (read for request auth and logout; `oidc_sid`/`oidc_client_id`
written by the callback), `op_{app,com,org}_grant_logout_hints` (written by the callback), the root
token / device session tables behind `parent_token` / `parent_device_session`
(`client_tokens`, `visitor_tokens`, `operator_tokens` and their device sessions; read).
Canonical/RP-identity databases (`AppRpRecord`, `ComRpRecord`, `OrgRpRecord`) —
`client_identities`, `visitor_identities`, `operator_identities`,
`client_oidc_identity_bindings`, `visitor_oidc_identity_bindings`, `operator_oidc_identity_bindings`,
`core_app_client_bridges`, `core_com_visitor_bridges`, `core_org_operator_bridges` (written by
`provision_rp_account_from_id_token!`). The OP tables stay (the OP owns them); the WU-18f drop
candidates are only the RP-identity tables, and only after a reader search proves no OP or Base use
(not done here — Q18-4).

**Tests:** every RP controller/integration test that signs in through the `shared` default exercises
the OP-chain arm (336 test files reference `OidcRpBrowserCredentialContract` / the RP Access cookie —
an upper bound, not a classified list). Standard-arm tests: `rp_cell_local_session_readiness_test.rb`
(12 clients), the palm callback cell case, adapters/operations of the cell (`RpRequestAuthenticator`,
`RpCallbackCommitter`, `RpCellSessionRevoker`, `RpRefreshCommitter`, BCL receiver). RuntimeRole
tests: `test/integration/runtime_role_route_guard_test.rb`, `test/lib/runtime_role_route_ownership_test.rb`,
`test/unit/security/authentication_mode_inventory_test.rb`; `test/support/in_process_op_transport.rb`
forces `shared` around in-process OP calls.

**RuntimeRole readers:**

| Reader | What it does with the role | After removal (D-19/D-20, D-15) |
|---|---|---|
| `lib/runtime_role.rb` | role list, `current` (`ENV.fetch`), `cell_connection`, `rp_private_env_names`, `rp_browser_admission_open?` (`UMAXICA_RP_BROWSER_ADMISSION`), `route_owner`/`serves?` | deleted |
| `lib/runtime_role_route_guard.rb`, `config/initializers/runtime_role_route_guard.rb` | 404 for controllers another role owns; `shared` passes all | deleted (one Puma serves every FQDN; host routing constraints stay the boundary) |
| `config/application.rb:56` | requires `lib/runtime_role` | line removed |
| `app/controllers/concerns/rp_cell_local_session.rb:26` | `rp_cell_process?` (the only path switch) | predicate deleted; the cell is already chosen from the controller's fixed client id (`RpCellBinding.for_client`), not from the role |
| `app/values/oidc_client_registry.rb:127` | `rp-*`: validates only its own client key | the non-RP branch (all clients) stays |
| `lib/jit_security_jwt_registry.rb:272, :291` | `rp-*`: private keys required only for own records / own client namespace | non-RP branch stays |
| `lib/jit_security_jwt_local_keyset_installer.rb:55` | `rp-*`: deletes other private keys from `ENV` | method removed (one credentials set, D-15) |
| `config/environments/development.rb:82` | pending-migration page only for `shared` | becomes `:page_load` unconditionally |
| `test/support/in_process_op_transport.rb`, `rp_cell_session_helper.rb`, palm callback test | set/restore the role | role handling removed with the arm |

Per RP today (process role `shared`, i.e. development/CI/tests): **all 12 clients** —
`base-app-ww`, `base-com-ww`, `base-org-ww`, `core-app-jp`, `core-com-jp`, `core-org-jp`, `warp-app-jp`,
`warp-com-jp`, `warp-org-jp`, `edit-org-ww`, `tech-org-ww`, `palm-app-jp` — use: callback = OP-chain
(canonical-actor provisioning + OP grant binding); JWT verification = in-process key
(`OidcIdTokenVerifier`, `AuthenticationTokenService`), not JWKS; refresh = `OidcOpTokenClient.refresh`
over HTTPS (already standard); local session = none of its own (the OP grant chain is the session).
Under an `rp-<client>` role the same client uses the standard arm in all four. No client mixes arms
inside one process.

### WU-18b — Per-RP switch plan (for owner review)

**Target (all RPs):** callback = `OidcOpIdTokenVerifier` over the cached per-issuer
`OidcOpJwksClient` (WU-11) + `RpCallbackCommitter` into the RP's own `rp_*` database (D-24);
request authentication = `RpRequestAuthenticator` (Access JWT via JWKS + local session cookie);
refresh = the post-WU-10 standard refresh (RFC 6749 §6 rotation, D-25: `OidcOpTokenClient.refresh`,
reuse → `invalid_grant` → re-run Authorization Code with `prompt=none`; no delivery-receipt query,
no `RpRefreshCommitter` recovery) writing the rotated pair into cookies and the local session;
logout = local session revoke + RP-Initiated Logout (WU-14) + BCL receiver (WU-15).

**Mechanism (no flag, no dual authority):** in each per-surface change, delete the OP-chain arm and
the `if rp_cell_process?` guard together, so the standard arm becomes the only code. The cell is
already selected from the controller's fixed client id, so no role or setting replaces the predicate.
There is never a state in which both arms exist behind a switch: before the change a process runs one
arm for every client; after it, the code has only one arm.

| Step | Surface / RPs | Change | Exit (tests green before removal) |
|---|---|---|---|
| 18c | app: `base-app-ww`, `core-app-jp`, `warp-app-jp`, `palm-app-jp` | remove the OP-chain arms for app resource type in `OidcCallback`, `BrowserRpAuthentication`, `CoreBrowserApiBoundary` (core app API), `OidcRpLogoutLauncher`; move every app RP test from the `shared` default to the standard path (sign in via `RpCallbackCommitter`/real callback, not `as_rp_cell`) | app RP controller/integration tests green on the standard path; readiness test for the 4 clients |
| 18d | com: `base-com-ww`, `core-com-jp`, `warp-com-jp` | same for visitor | same |
| 18e | org: `base-org-ww`, `core-org-jp`, `warp-org-jp`, `edit-org-ww`, `tech-org-ww` | same for operator; then, with no arm left, delete `rp_cell_process?`, `RuntimeRole`, the route guard, the key-isolation branches, `UMAXICA_RUNTIME_ROLE` / `UMAXICA_RP_BROWSER_ADMISSION` from env files and CI, and the test role helpers | full RP suite green; boot without `UMAXICA_RUNTIME_ROLE` |
| 18f | tables | RP-identity tables listed in 18a (owner approval, counts, recovery) | approval |

Because the branch is per concern but the concerns are shared across surfaces, 18c/18d deletes the
arm *per resource type* inside each concern (`browser_rp_resource_type` / `oidc_resource_type`), not
per class; the predicate itself disappears only in 18e. During 18c a `shared` process still runs
com/org on the OP-chain arm and app on the standard arm — different clients, never two authorities
for one client, which is what D-108 forbids.

**Open questions for the owner (WU-18b cannot be accepted without them):**

- **Q18-1 (blocking, Base surfaces).** The OP-chain arm gives RP pages the canonical actor
  (`Client`/`Visitor`/`Operator`), root token and `BrowserSessionSecurityContext`
  (`current_session`, `current_session_public_id`, withdrawal state). The standard arm gives the cell
  principal and `security_context: nil`. 84 files under `app/controllers/base` + `app/views/base`
  (6 core, 6 warp, 3 edit, 1 tech, 2 palm) read these helpers. Which source replaces them on the Base
  Self-RP pages: OP owner APIs over HTTPS (as `rp_cell_selected_context` does via
  `OrgAdminAuthorityClient`), or are those pages OP-owned (Visa/Base OP role) and therefore not RP pages?
  Without a decision the Base part of 18c … 18e cannot be planned per page.
- **Q18-2.** Withdrawal gate (`withdrawal_required` from `resource.deactivated?`) has no standard-arm
  equivalent; should the OP refuse token issuance/refresh for a deactivated actor (the RP then only
  sees `invalid_grant`), or must the RP read actor status from an owner API?
- **Q18-3.** `OidcRpIdentityProvisioning` (canonical-actor provisioning, `Core*Bridge`) disappears
  with the arm; confirm that no RP feature needs the bridge rows after the switch (Core uses the bridge
  for domain data ownership today).
- **Q18-4.** WU-18f scope: confirm the drop list is only the RP-identity tables listed in 18a (the
  `op_*_grants` columns `oidc_sid`/`oidc_client_id` and `op_*_grant_logout_hints` are written by the
  OP-chain callback today, and `OidcRpLogoutLauncher` reads the hint as the WU-14 `id_token_hint`;
  the standard arm must store its own hint (cell) before these become OP-chain-only).

---

# Part 5 — Prepared material (static reading, 2026-10-22)

Everything here was read from the working tree at `febec3225` with the uncommitted changes present,
or generated by `bin/rails routes` in this session. Nothing was executed beyond that command. Each
section names the unit it prepares. **Findings** are observed facts; **Proposal** marks items that
still need the owner's acceptance (they are also listed in one.md §5 when they block).

## 5.1 WU-29 — Sign-in path route/action table (input to D-93 and A29-4)

Source: `bin/rails routes`, every row whose controller is under `auth/{app,com,org}/sign`,
`auth/*/social`, `auth/*/omniauth` or `auth/*/ceremony_bindings` (165 rows incl. HEAD-less GET forms
and `PUT` twins of `PATCH`). Classification rule (D-93): **C** = checked by the Sentry resolver;
**E** = exempt with the stated reason. GET form pages (`#new`, `#edit`, `check/*#show`) are **E**
("renders only; the action that records anything is C"). `PUT` rows follow their `PATCH` twin.
**This table describes today's routes; it is regenerated after WU-12 (Design D replaces several
POSTs with GET continuations) and that regenerated table is what A29-4 asserts.**

| Route (all three surfaces unless marked) | Action | Flow | Class |
|---|---|---|---|
| `GET /sign/in`, `GET /sign/up` | `ins#show`, `ups#show` | in / up | C (admitted-entry, D-93 (2)) |
| `POST /sign/in`, `POST /sign/up`, `POST /ceremony_bindings` | `ins#create`, `ups#create`, `ceremony_bindings#create` | per Admission purpose | C for Sign-in path purposes; E for `TICKET_CEREMONY_PURPOSES` |
| `POST /sign/in/email` (APP, COM) | `in/emails#create` | in | C (OTP issue) |
| `PATCH/PUT /sign/in/email` (APP, COM) | `in/emails#update` | in | C (OTP verify → evidence) |
| `DELETE /sign/in/email` (APP, COM) | `in/emails#destroy` | in | E (cancels; reduces state) |
| `POST /sign/in/passkey/options`, `POST /sign/in/passkey/verification` | passkey options / verifications | in | C |
| `POST /sign/in/emergency/passkey/options`, `…/verification` (ORG) | emergency | in | **E (D-96 break-glass)** |
| `POST /sign/in/secret` (APP) | `in/secrets#create` | in | C |
| `POST /sign/in/challenge/totp` (APP), `POST /sign/in/challenge/passkey` (APP, COM) | MFA challenge | in | C |
| `DELETE /sign/in/challenge` (APP, COM) | `in/challenges#destroy` | in | E (cancel) |
| `GET /sign/in/guard`, `GET /sign/in/check`, `GET /sign/in/challenge` | sequence pages | in | E (display; the OP root-login backstop D-93 (5) refuses issuance) |
| `GET/POST /sign/oidc/handoff` | `oidc_handoffs` | in / up | C (issues the Auth → OP result) |
| `GET/POST /sign/handoff` | `handoffs` (Local) | — | E (removed by WU-01) |
| `POST /sign/cancellation` | `cancellations#create` | — | E (Cancel) |
| `POST /sign/switch` (APP, COM) | `switches#create` | — | E (the Switch target lands on its Sentry path) |
| `POST /sign/up/email`, `POST /sign/up/telephone` (APP, COM) | registration start | up | C |
| `GET /sign/up/guard/{apple,google,email,telephone}` | guard pages | up | E (display) |
| `POST/PATCH/PUT /sign/up/check/{email,telephone}/otp` | OTP issue / verify | up | C |
| `DELETE /sign/up/check/*/*` | cancel steps | up | E (cancel) |
| `POST/PATCH/PUT /sign/up/check/telephone/passkey` | passkey registration | up | C |
| `POST/PATCH/PUT /sign/up/check/telephone/secret`, `POST …/secret/reattempt` (APP) | secret | up | C |
| `PATCH/PUT /sign/up/check/*/birthdate` | birthdate (may finalize) | up | C |
| `PATCH/PUT /sign/up/check/{apple,google}/confirmation` (APP) | social confirmation | up | C |
| `POST /social/{google,apple}/session` (APP) | social start, intent login | in | C (`sign_in_available_app`) |
| `POST /social/{google,apple}/registration` (APP) | social start, sign-up | up | C (`sign_up_available_app`) |
| `GET /social/{google,apple}/callback` (APP) | OmniAuth callback | by effective intent | C (refused, no draining, D-95) |
| `GET /social/failure`, `GET /social/entra/failure` | failure pages | — | E (display) |
| `POST /social/link_completion` (APP) | link | Re-verification | E (not Sign-in path, D-44) |
| `GET /social/entra/session/new`, `POST /social/entra/session` (ORG) | Entra start | in | C (`sign_in_available_org`) |
| `GET /social/entra/callback` (ORG) | Entra callback | in | C (refused, D-95) |
| `POST /sign/up/invitations` (ORG) | invitation acceptance | up | C (`sign_up_available_org`, D-96) |
| `GET/POST/… /sign/out*` | sign-out | — | E (D-84: Sign Out untouched) |

## 5.2 WU-35 — Lock acquisition inventory (input to D-107 / X-27)

> H18: the two-family proposal at the end of this section is **not adopted** (D-139); the report is Part 6.2.

Target order (Q9): **OP Flow lock → principal subject lock → Client/Visitor lock**, cleanup the same.
"OP" = `op_base_{app,com,org}`; "principal" = `*_principal` / `*_zenith`. Read order is outer → inner.

| Path | File | Order today | vs Q9 |
|---|---|---|---|
| Sign-up finalize (email/telephone) | `app/controllers/concerns/sign_up_sequence_controller_support.rb:194` | Sign-up Flow `with_cycle_lock` (OP, `transaction(requires_new: true)` + `lock!`) → side effect (principal writes) → identity graph → `:complete` → `handoff_to_sign_in_flow!` | Matches outer Flow; inner principal lock order depends on the side effect |
| Email sign-up OTP issue | `app/operations/email_sign_up_otp_issuer.rb:10,25,31` | Flow → owner (Client) → email | Matches (no subject lock on this path) |
| Email sign-up OTP verify | `app/operations/email_sign_up_otp_verification_committer.rb:12,23,24,128,158` | Flow → owner → email; separately the ceremony transaction | Matches |
| Email/telephone sign-up OTP delivery guard | `app/operations/{email,telephone}_sign_up_otp_delivery_guard.rb:12-23` | Flow → owner → contact → ceremony transaction | Matches |
| Telephone sign-up OTP issue | `app/operations/telephone_sign_up_otp_issuer.rb:10,25,31` | Flow → owner → telephone | Matches |
| COM telephone registration finalizer | `app/operations/sign_com_up_telephone_registration_finalizer.rb:42-52` | Flow → Visitor → telephone → ceremony | Matches |
| APP secret/passkey reservation (sign-up) | `app/operations/client_secret_passkey_reservation_issuer.rb:19-22, 43-49, 87-91, 124-126, 147-149` | **Client (principal) → Sign-up Flow (OP)** → passkey → issuance | **Inverted** (principal outer) |
| Social sign-up commit (Base, to be removed by WU-05g) | `app/operations/identity_social_ceremony_final_committer.rb:171-211` | Flow `with_cycle_lock` → principal transaction → **subject advisory lock** (inside `SocialAuthSignupFinalizer`) → Client `with_lock` → OP ceremony transaction `lock!` → candidate consume → graph → Flow (re-entrant) | Flow outer ✓; subject before Client ✓; then an **OP lock inside a principal lock** |
| Social sign-in | `app/services/social_auth_login_handler.rb:22` | subject advisory lock → identity row lock | No Flow lock |
| Social link / unlink | `app/services/social_auth_link_handler.rb:28`, `app/services/external_authentication_unlink_use_case.rb:24` | subject advisory lock → … | No Flow lock |
| Withdrawal anonymizer | `app/operations/withdrawal_personal_data_anonymizer.rb:115` | subject advisory lock | — |
| Admission binding redemption | `app/services/base_auth_admission_coordinator.rb:615` | **Base actor (principal) `with_lock`** → binding/ticket locks; `auth_admission_binding.rb:102` binding → ceremony session | **Principal outer** before the OP binding |
| Root login commit | `app/controllers/concerns/authentication_base.rb` `with_actor_session_lock` | actor (principal) row lock → token DB writes | Different path (Sign In); principal outer |
| Session-limit resolution | `app/models/concerns/session_limit_resolution_transactionable.rb:119-123, 439-460` | actor → sign-in flow; actor → authorization → parent | **Principal outer** |
| Secret claim finalize (sign-in) | `app/operations/client_secret_claim_finalizer.rb:17-25` | Client → OIDC transaction → sign-in flow → credential | **Principal outer** |
| Email OTP challenge (sign-in) | `app/models/concerns/auth_email_otp_challenge.rb:207-226` | owner → contact; parent lock separately | — |

**Findings.** (1) Sign-up OTP paths follow Q9. (2) Four paths take the principal lock **before**
an OP lock: APP secret/passkey reservation (sign-up), admission binding redemption, session-limit
resolution, secret claim finalize. Two of them are Sign-in paths whose own consistent order is
"principal → OP"; a single global order would have to choose. (3) The social commit nests an OP
lock inside a principal lock after taking the Flow lock first, i.e. OP → principal → OP. **Proposal
for the owner (X-27):** two orders by path family — Sign-up: OP Flow → subject → Client/Visitor →
contact → OP ceremony rows taken **before** leaving the OP transaction (no OP lock inside a principal
lock); Sign-in and admission: principal (actor) → OP rows, as today — and forbid any path that
holds both a Sign-up Flow lock and an actor lock taken in the Sign-in order. WU-05e and WU-38 follow
the Sign-up order; the APP secret/passkey reservation is reordered.

## 5.3 WU-24 — Migration table (input to A24-5 approval; D-125, D-129)

> H18: the table rows stay valid; the "Proposed order" is replaced by Part 6.1 (step 3 created the WU-38 cycle).

| Item | APP (`op_base_app`) | COM (`op_base_com`) | ORG (`op_base_org`) |
|---|---|---|---|
| Binding table | `client_auth_admission_bindings` | `visitor_auth_admission_bindings` | `operator_auth_admission_bindings` |
| `entry_intent` today | nullable, CHECK `NULL or sign_in/sign_up` | same | same |
| Sign-in path purposes | `authentication_handoff`, `invitation_handoff` (parent `authorization_transaction_id`); `local_sign_in`, `local_sign_up` (parent `sign_in_flow_id`, removed by WU-01) | same | same |
| Re-verification purposes | `step_up_handoff`, `reauthentication_handoff`, `bootstrap_handoff`, `credential_registration_handoff`, `credential_change_handoff` (parent `step_up_ceremony_transaction_id`) | same | same |
| Sign-up Flow table | `client_sign_up_flows` | `visitor_sign_up_flows` | `operator_sign_up_flows` (model only) |
| `local_sign_up_flow_ref` | `client_auth_ceremony_sessions` (FK → `client_sign_up_flows.public_id` `ON DELETE RESTRICT`; in `*_purpose_exclusive` and `*_transaction_exclusive` CHECKs) | `visitor_auth_ceremony_sessions` (same) | `operator_auth_ceremony_sessions` (same) |
| `curfew_at` | absent | absent | absent |

**Proposed order (each its own migration; destructive steps list row counts first):**
1. Add `curfew_at` (nullable for one step), backfill existing live Bindings with `created_at + 30 min`
   and retired/redeemed ones likewise (history only), then NOT NULL. (Never deployed: only
   development/staging rows.)
2. `entry_intent` (D-129): backfill Sign-in path rows from their parent transaction's effective
   intent (`prompt=create` → `sign_up`, else `sign_in`); Re-verification rows → the explicit
   "not applicable" value (**Proposal:** `not_applicable`); replace the CHECK with one tying
   `purpose` to the allowed values; NOT NULL.
3. Run the WU-38 cleanup for unfinished registrations **before** deleting unbound Flows, so pending
   principals stay traceable through their Flow; record counts.
4. Delete Sign-up Flows without a Binding (D-125 ②); then add `auth_admission_binding_id` NOT NULL,
   FK `ON DELETE RESTRICT`, partial UNIQUE "≤ 1 in-progress Flow per Binding".
5. Retire `local_sign_up_flow_ref`: drop the FK, remove it from both CHECKs (rewrite them without
   it), drop the column; remove its readers in `app/models/concerns/auth_ceremony_session.rb`.
   `local_sign_in_flow_ref` stays (WU-01).
6. Recovery: each step is reversible except 3 and 4 (deletions); before them, a `pg_dump` of the
   affected tables is taken and its location recorded in `evidence/`.

**Finding outside scope:** the Binding row already uses three nullable parent columns with a
`num_nonnulls = 1` CHECK and several nullable timestamps whose presence encodes state
(`redeemed_at`, `retired_at`, `base_confirmed_at`). That is the existing E1 design; it is recorded
here because it conflicts with the repository's "no NULL with meaning" rule and should be reviewed
separately, not changed in WU-24.

## 5.4 WU-33 — Sign-in failure convergence (first pass)

How each method turns a session result into a response today:

| Surface / method | Entry | Result path | Finding |
|---|---|---|---|
| APP Email OTP | `Auth::App::Sign::In::EmailsController#update` (~l.396–410) | `AuthenticationSessionCommitter` → `SignInResult` → `render_sign_in_refusal` | Uniform refusal helper |
| COM Email OTP | `Auth::Com::Sign::In::EmailsController#update` l.141–160 | same | Same; `already_verified` → evidence again (WU-31) |
| APP Secret | `Auth::App::Sign::In::SecretsController#create` l.59–69 | `AuthenticationSessionCommitter`; **any status other than evidence/MFA renders "invalid secret" 422** | Mixes D-73 classes: a cooldown, guardrail or `login_forbidden` refusal is shown as a wrong secret |
| APP Passkey | `in/passkey/verifications_controller.rb` l.75–90 | `AuthenticationSessionCommitter` → `render_sign_in_refusal` | — |
| COM Passkey | `in/passkey/verifications_controller.rb` l.71–86 | **`establish_signed_in_session!` directly** (not the committer) → `render_sign_in_refusal` | Inconsistent with APP |
| ORG Passkey (Normal), Emergency | `SignOrgNormalPasskeyCeremony` (concern) | own path | Not traced in this pass |
| APP TOTP / APP+COM MFA Passkey | `in/challenge/*_controller.rb` | `render_sign_in_refusal` | — |
| APP Google/Apple | `Auth::App::Omniauth::OmniauthCallbacksController` l.499–515 | `AuthenticationSessionCommitter` → `sign_in_result_from_session_result` | — |
| ORG Entra | `Auth::Org::Omniauth::OmniauthCallbacksController` | `render :error, status: :unprocessable_content` (l.168) | Single generic page for every refusal |
| Shared refusal helper | `SessionLimitGate#render_sign_in_refusal` | plain text, default `:forbidden`, message default "login limit exceeded" | The default message names the session limit even for other refusals |

`SignInResult` terminal statuses map to HTTP as: session-limit conflict 503, guardrail/login
forbidden/access locked 403, credential rejected/identity unavailable/credential failed 401,
transaction expired 410, failure/invalid request 400 (`app/values/sign_in_result.rb:4-15`).
**Next (WU-33 completion):** one row per surface × method × outcome with the D-73 class; the three
findings above are its first entries.


### 5.4.1 Completed convergence table (2026-10-27, A33-1)

Read from the code on 2026-10-27 (base `aeb09ca9f` + dirty worktree). Outcomes of the shared
committer are `SignInResult` statuses; `TERMINAL_HTTP_STATUSES` (`app/values/sign_in_result.rb`) fixes
the HTTP status. The D-73 class is the reading of each status against `SignInPathRefusalValue`; the
committer itself does not emit a D-73 reason (gap, see the last column).

Shared committer outcomes (APP/COM Email OTP, APP Secret, APP Passkey, APP Google/Apple):

| `SignInResult` status | HTTP | D-73 class (reading) |
|---|---|---|
| `success`, `authentication_evidence_recorded`, `mfa_required`, `session_limit_pending` | 302/303 (non-terminal) | — |
| `credential_rejected`, `credential_failed`, `identity_unavailable` | 401 | definitive |
| `login_forbidden`, `access_locked`, `guardrail_blocked` | 403 | definitive |
| `transaction_expired` | 410 | definitive (curfew) |
| `session_limit_conflict` | 503 | dependency |
| `sign_entry_blocked` | 503 | retryable |
| `failure`, `invalid_request`, any unknown status | 400 | definitive |

Per surface and method:

| Surface / method | Entry (file:line) | Result path | Outcome mapping | Remaining gap |
|---|---|---|---|---|
| APP Email OTP | `app/controllers/auth/app/sign/in/emails_controller.rb:402` | committer → `render_sign_in_refusal` | table above | unfinished registration now treated as unknown (A-7) |
| COM Email OTP | `app/controllers/auth/com/sign/in/emails_controller.rb:149` | committer → `render_sign_in_refusal` | table above | COM out of cycle (D-194) |
| APP Secret | `app/controllers/auth/app/sign/in/secrets_controller.rb:60` | committer; every non-evidence/MFA status → `render_form` 422 | **all refusals 422** | mixes D-73 classes (cooldown, guardrail, curfew all 422) |
| APP Passkey | `app/controllers/auth/app/sign/in/passkey/verifications_controller.rb:75` | committer → `render_sign_in_refusal` | table above; eligibility refusal before assertion 401 (A-7) | — |
| COM Passkey | `app/controllers/auth/com/sign/in/passkey/verifications_controller.rb:71` | `establish_signed_in_session!` directly → `render_sign_in_refusal` | `render_sign_in_refusal` default 403 unless the status supplies one | bypasses the committer; COM out of cycle |
| APP/COM MFA Passkey | `auth/app/sign/in/challenge/passkeys_controller.rb:218`, `auth/com/…:237` | `render_sign_in_refusal` | 403 default | — |
| APP TOTP | `auth/app/sign/in/challenges_controller.rb` | challenge page only; failures redirect (303) to the sign-in page | 303 | not a terminal refusal; no D-73 reason |
| ORG Passkey (Normal) | `app/controllers/concerns/sign_org_normal_passkey_ceremony.rb:111` | `establish_signed_in_session!` → `render_sign_in_refusal` (l.126); phase refusal 409 (`org_normal_sign_in_transaction.rb:183`) | 403 default; 409 phase | bypasses the committer |
| ORG Passkey (Emergency/Standby) | `app/controllers/concerns/sign_org_standby_passkey_ceremony.rb:132` | `establish_signed_in_session!` → `render_sign_in_refusal` (l.144) | 403 default | bypasses the committer |
| APP Google/Apple | `app/controllers/auth/app/omniauth/omniauth_callbacks_controller.rb:436` | committer; callback refusals → `SocialAuth#handle_social_auth_error` (`social_auth.rb:404`) → `refuse_sign_in_path!` (D-198) | committer table; callback refusals 400 definitive (`intent_crossing`, `subject_enforced`, `credential_failed`, `state_*`), 400 `credential_failed` on provider failure | — |
| ORG Entra | `app/controllers/auth/org/omniauth/omniauth_callbacks_controller.rb:168` | `render :error, status: :unprocessable_content` | **422 for every refusal, distinct texts per cause** | contrary to D-47 (D-198 note) |

Open gaps (not changed by this table): APP Secret and ORG Entra collapse classes into 422; COM and ORG
Passkey paths bypass the shared committer; the committer statuses carry no D-73 reason code.

## 5.5 WU-11 — JWKS result table (current behavior and proposal)

> H18: the per-process limit is superseded by D-136; the design is Part 6.3.

**Current (`app/adapters/oidc_op_jwks_client.rb`):** `CACHE_TTL` 1 h, `MAX_STALE_TTL` 5 min.
`public_key_for(kid)`: fresh cache with the `kid` → key; otherwise `refresh` (under a mutex,
skipped if another thread already refreshed and the `kid` is present); first-ever fetch gets one
extra refetch; then a stale entry ≤ 1 h + 5 min that has the `kid` → key; else `nil`.
**Findings:** (1) every unknown `kid` against a fresh cache triggers a network fetch — no per-issuer
rate limit, so a stream of tokens with random `kid`s becomes a stream of JWKS fetches; (2) `refresh`
swallows fetch errors and returns `nil`, and `public_key_for` returns `nil` both for "unknown kid"
and "fetch failed", so a caller cannot answer 400 vs 503 as BX-7 requires.

**Proposal (result table):**

| `kid` | Cache | Fetch | Result |
|---|---|---|---|
| known | fresh (≤ 1 h) | — | key |
| known | stale (≤ 1 h + 5 min) | fails | key (stale allowed) |
| known | stale | succeeds | key from new document |
| known | past stale window | fails | **503** (key unavailable) |
| unknown | any | allowed by the per-issuer limit, succeeds, `kid` present | key |
| unknown | any | allowed, succeeds, `kid` absent | **400/401** (invalid token) |
| unknown | any | allowed, fails | **503** |
| unknown | any | refused by the per-issuer limit | **400/401** if the last fetch succeeded within the limit window, **503** if it failed |

Per-issuer limit (**Proposal**): at most one unknown-`kid` refetch per issuer per 30 s per process.
The client returns a typed result (key / invalid / unavailable) instead of `nil`.

## 5.6 WU-21 — RP return target rules (proposal)

> H18: **withdrawn** — D-137 replaces `session[:return_to]` with an RP-signed `pt` (Part 6.4). Item 4's pending bound remains a proposal.

1. Store: a protected page validates path + permitted query (per-RP allow list of query keys;
   default none) and writes `session[:return_to]` (one slot per RP host, last write wins).
2. `POST /sign` moves the current value into the pending authentication transaction keyed by
   `state` and clears the slot; a second tab's later `POST /sign` therefore carries its own target.
3. After a successful callback and RP session: redirect to the transaction's target once; delete it
   with the transaction. After Cancel or any error: drop it; go to the RP top page.
4. *(Superseded by D-160: 30 min from `POST /sign`, WU-43.)* Pending transaction upper bound (D-76): **Proposal** 35 min (curfew 30 min + 5 min margin);
   beyond it the callback is refused and the person restarts from the RP.

## 5.7 WU-01a — Test-file classification (preliminary)

72 files call `issue_local_entry!` (two.md said 71). By text signal (local-only identifiers present
or not); WU-01a confirms each by reading:

- **(i) Local subject, delete with the code:** `test/controllers/base/local_authentication_entry_test.rb`,
  `test/integration/local_authentication_boundary_test.rb`.
- **(iii) Mixed — split per test** (local-specific cases next to fixture use):
  `test/integration/root_login_establishment_flow_test.rb` (a session-issuance guard that must stay
  green; only its local cases go), `test/models/auth_email_otp_challenge_test.rb`,
  `test/services/credential_security_transition_test.rb`,
  `test/controllers/auth/org/in/passkeys_controller_test.rb`,
  `test/services/base_auth_admission_coordinator_test.rb`,
  `test/controllers/auth/app/in/emails_controller_test.rb`,
  `test/operations/client_secret_claim_committer_test.rb`,
  `test/integration/session_limit_promotion_flow_test.rb`, `test/models/auth_admission_binding_test.rb`,
  `test/services/auth_admission_binding_concurrency_test.rb`.
- **(ii) Fixture only, re-point:** the remaining 60 files.

## 5.8 WU-16 / WU-22 — OP authority-stop record (accepted design; locally implemented)

### 5.8 v2 — rewritten 2026-10-23 (D-119, D-123, D-158 P-142, D-163 … D-168; inventory 6.14) — **accepted (D-172)**

The v1 text after this subsection is history; where it differs, v2 wins.

**Tables (one set per realm, OP database; all columns NOT NULL; no NULL carries meaning).**

| Table | Columns | Notes |
|---|---|---|
| `op_authority_stops` | `public_id`, `realm`, `cause_id` → `op_authority_stop_causes`, `scope_id` → `op_authority_stop_scopes`, `principal_public_id`, `authority_evidence_ref`, `idempotency_digest` (UNIQUE per realm), `occurred_at` (OP DB time), timestamps | The authority (D-119). Principal by public id (cross-DB, no FK; purge order protects it) |
| `op_authority_stop_causes` | `browser_logout`, `rp_initiated_logout`, `token_revocation`, `refresh_reuse`, `revoke_others`, `credential_change`, `identity_stop`, `administrative`, `risk` | Reference table |
| `op_authority_stop_scopes` | `root`, `grant`, `all_roots_of_principal` | Reference table |
| `op_authority_stop_root_targets` | `stop_id` FK RESTRICT, `root_ref` FK RESTRICT; UNIQUE (`stop_id`, `root_ref`) | P-142. `root`: exactly one; `all_roots_of_principal`: every root revoked (zero allowed) |
| `op_authority_stop_grant_targets` | `stop_id` FK RESTRICT, `grant_ref` FK RESTRICT; UNIQUE | `grant`: exactly one |
| `op_authority_stop_epoch_cutoffs` | `stop_id` FK RESTRICT UNIQUE, `cutoff_epoch` | Only for stops that advanced the principal's epoch (D-164); a separate child instead of a nullable column |
| `op_authority_stop_participants` | `stop_id` FK RESTRICT, issuer, client, `sid`, delivery state FK → status table, `attempts`, `next_attempt_at`, `deadline_at` (BX-10), lease columns | One outbox row each (D-117, D-121) |
| `op_authority_stop_browser_logouts` | `stop_id` FK RESTRICT UNIQUE, `browser_binding_digest`, receipt columns | Child only for `browser_logout` / `rp_initiated_logout`; replaces `logout_flows` / `logout_receipts` (replaced, not migrated: D-159, D-168) |

"Exactly one" target rules are enforced in the primitive and by tests (PostgreSQL cannot count
child rows in a CHECK).

**Cause → scope → epoch → authority (D-164, G-20).**

| Cause | Scope | Epoch | Authority (refused without it) | Caller today |
|---|---|---|---|---|
| `browser_logout` | `root` | never | valid OP session of this browser + the person's request (D-123 SO-1) | `AuthenticationLogoutCurrentSession` |
| `rp_initiated_logout` | `root` (single logout: the root and all its grants, D-33) | never | the confirmation POST of the OP session (D-33) | `SignOidcLogout#confirm_oidc_end_session_logout` → `AuthenticationLogoutCurrentSession` |
| `token_revocation` | `grant` | never | the authenticated client with its registered method (D-79), or an issuer-side decision for the exact grant | `OidcTokenRevoker`; authorization-code replay; exact-grant client revocation; refused Tech callback |
| `refresh_reuse` | `grant` (that family only; root kept, D-25) | never | the verified reused token and its grant | `OidcRefreshTokenIssuer#handle_refresh_token_reuse` |
| `revoke_others` | `root`, one stop per other root, point in time (D-167) | never | the person's authenticated request | `AuthenticationOtherSessionsRevoker` |
| `credential_change` | `root`, one stop per other root, under the principal lock (D-167) | never | the committed credential change | `CredentialSecurityTransition`, `IdentityCredentialRemovalCommitter` |
| `identity_stop` (withdrawal, operator lifecycle) | `all_roots_of_principal` | yes (cutoff child) | the committed Zenith identity-stop event (D-34) | `OpIdentityEventInvalidator` |
| `administrative` (access lock; method-protection stop) | `root` or `all_roots_of_principal` | never for `root`; yes for principal-wide stop | the authorized operator decision or committed enforcement decision | `EnforcementCaseApplicable` (one root); `AdministrativeAccessLock` (identity stop) |
| `risk` | `root` or `all_roots_of_principal` | never for `root`; yes for principal-wide stop | the committed risk decision | `AuthenticationBase` root refresh/DBSC failure; `SignRiskEnforcer` principal-wide identity-stop path |

**Lock order per scope (from 6.14; consistent with every issuance path, so no new wait cycle).**

- `root` / `grant`: stop row lookup by `idempotency_digest` (insert-or-return) → Device Session →
  root → grants / RP sessions (id order) → target rows → participants → outbox; one OP
  transaction. No principal lock and no epoch. Serializes with issuance on the Device Session and
  root rows (`RpSession#with_parent_and_self_lock` uses the same order).
- `refresh_reuse`: runs inside the refresh transaction that already holds actor → Device → root →
  RP session; the stop row and its children are inserted there.
- `credential_change`: principal row lock (Zenith) held → OP transaction (stop rows, then per root
  as `root`) → OP commit → credential change → Zenith commit. If the Zenith commit fails after the
  OP commit, sessions are revoked and the credential is unchanged (fail-safe direction).
- `all_roots_of_principal` (identity/administrative): Zenith transaction under the principal lock:
  status change + epoch + 1 + identity event (existing recorder) → commit. Then the OP apply:
  inbound receipt row → stop row + cutoff child → every root with `epoch < cutoff` in id order
  (Device → root → grants) → targets → participants → outbox; one OP transaction; retry and sweep
  as today (D-34). Roots created concurrently are handled by D-163 (re-check under the principal
  lock) and D-165 (`root_epoch == actor_epoch` at every boundary, writer read), not by enumeration.

**Re-runs and failures (D-123).** A re-run with the same `idempotency_digest` returns the stored
stop and revokes or notifies nothing again. If the stored record cannot be read, the request fails
closed and reports no success. A stop whose principal cannot be established is refused.

**Static guard.** Only the primitive revokes roots or grants (BX-1); only `create_login_token_record`
creates roots (D-163).

**Cause mapping for other callers (D-173, 2026-10-25; implementation reconciliation).** Only the
nine causes above. Session-limit resolution (both sites), selected-session revoke and revoke-all →
`revoke_others`; `AccountSessionRevocation` → `browser_logout`; `EnforcementCaseApplicable` →
`administrative`; DBSC refresh failure and root refresh invalidated (`AuthenticationBase`) → `risk`
through the Zenith identity-event path. Authenticated authorization-code replay, RP-origin grant
cleanup and a refused Tech callback → `token_revocation` for that exact grant, with the evidence ref
retaining which issuer-side decision authorized it. Identity invalidation includes already-revoked
roots below the cutoff so the primitive can repair any still-live grants beneath them.

**Owner decisions (D-172, 2026-10-23): S-1 … S-3 accepted as proposed.**
- S-1: scope of `risk` stops (proposal above).
- S-2: retention of stop records and their children (proposal: the same retention as the OP
  logout records today, purged children-first; never before every participant reached a final
  state).
- S-3: keep `browser_logout` and `rp_initiated_logout` as separate causes (proposal: yes, for audit;
  same scope and behavior).

### 5.8 v1 (history)


> H18 re-check: one `target_root_ref NOT NULL` cannot express the `grant` and `all_roots_of_principal` scopes without a placeholder. **Proposal P-142:** drop `target_root_ref` from `op_authority_stops`; add `op_authority_stop_root_targets` (`stop_id`, `root_ref`, both NOT NULL, FK RESTRICT) and `op_authority_stop_grant_targets` (`stop_id`, `grant_ref`); a `root` stop has exactly one root target, a `grant` stop exactly one grant target, an `all_roots_of_principal` stop records every root it revoked as root targets (zero allowed when none was live) and its selector is `principal_public_id` + `realm` + `occurred_at`. The "exactly one" rules are enforced in the primitive and by a deferred constraint check in tests (PostgreSQL cannot count child rows in a CHECK).

**Facts.** Per OP database (`op_base_{app,com,org}`): `logout_flows` (realm, `target_root_ref`,
`idempotency_digest` unique per realm, **`browser_binding_digest` NOT NULL**, `op_revoked_at`),
`logout_flow_participants` (issuer, client, `sid`, delivery/lease columns), `logout_receipts`
(browser-bound), `op_outbox_events` (participant FK nullable, delivery/lease columns), and the
legacy `*_sign_out_flows` (nullable `principal_id`, `token_id`; status/kind reference tables). Tokens
live in the same OP database; principals (`visitors`, `clients`, `operators`) live in
`*_zenith`/`*_principal` — **a foreign key to the principal is impossible** under
`adr/cross-db-reference-policy.md`.

**Proposed shape (one set per realm, OP database):**

| Table | Columns (all NOT NULL unless noted) | Notes |
|---|---|---|
| `op_authority_stops` | `public_id`, `realm`, `cause_id` → `op_authority_stop_causes`, `scope_id` → `op_authority_stop_scopes`, `principal_public_id`, `target_root_ref`, `authority_evidence_ref` (what authorized it, per cause — see G-20), `idempotency_digest` UNIQUE per realm, `occurred_at`, `created_at` | The authority. Principal referenced by public id (cross-DB), never NULL (D-123 SO-2) |
| `op_authority_stop_causes` | `browser_logout`, `identity_stop`, `token_revocation`, `revoke_all`, `refresh_reuse`, `risk`, `administrative` | Reference table |
| `op_authority_stop_scopes` | `root`, `grant`, `all_roots_of_principal` | Reference table |
| `op_authority_stop_participants` | `stop_id` FK RESTRICT, issuer, client, `sid`, delivery state FK → status table, `attempts`, `next_attempt_at`, `lease_expires_at` … | Replaces `logout_flow_participants`; one outbox row each (D-117) |
| `op_authority_stop_browser_logouts` | `stop_id` FK RESTRICT UNIQUE, `browser_binding_digest`, receipt columns | Child only for cause `browser_logout`; replaces the browser part of `logout_flows`/`logout_receipts` |
| `*_sign_out_flows` (legacy) | becomes evidence: `stop_id` FK RESTRICT NOT NULL where a stop exists; rows without a stop (unauthenticated viewing) are not written at all (D-123 SO-1) | Removes nullable `principal_id`/`token_id` meaning |

Token references (`target_root_ref`, grant ids) are same-database and use `ON DELETE RESTRICT`
(D-123 SO-7); principal references are public ids checked by the purge order instead of an FK
(correction to D-123's wording, which assumed an FK was possible). **Lock order (proposal):** stop
row insert → root/grant rows (same OP DB, id order) → participant rows → outbox rows, all in one OP
transaction; the principal is not locked (its public id is a value). *(Superseded by D-164/D-166: locking and epoch per stop scope; see 6.14.)* **Open for review:** whether
`logout_flows` is migrated or replaced (never deployed: replace), the status table for participant
delivery, and the retention period of stop records.

## 5.9 WU-28 — Dev-only ORG Bootstrap (design draft for review)

**Facts.** Nothing is implemented (one.md T15). Requirements BOOT-1 … BOOT-6 (one.md Appendix E.4.6).
`AuthenticationContextValue` knows `normal` and `standby`; `from_claim` maps a **blank claim to
Normal** and unknown values to `UNKNOWN` (`app/values/authentication_context_value.rb:107`). The
name `bootstrap_handoff` is already an Admission purpose (Re-verification parent).

**Proposed design:**
1. **Name:** "Seed Operator" (avoids the `bootstrap_handoff` collision, BOOT-6); context key `seed`.
2. **Discriminator (BOOT-3):** independent conditions, all required at route **and** at the final
   root-login commit: `Rails.env.development?` (routes are not drawn otherwise); a credential
   `seed_operator.enabled_secret` present only in `config/credentials/development.yml.enc`; and the
   TCP peer (`request.remote_addr`, not `remote_ip`, with no forwarding headers present) is a
   loopback address. Missing or unknown → refuse (fail closed). No Flipper or ENV switch.
   **Why the loopback peer:** a staging host started with `RAILS_ENV=development` would carry the
   development credentials (D-15: one set per environment), and a `*.localhost` Host header can be
   sent by anyone, so neither proves "local". A loopback TCP peer cannot be forged from outside the
   machine; it fails closed behind any proxy, which is the intended outcome. Residual: a process on
   the same staging machine could still reach it; recorded for review.
3. **Seed (BOOT-1):** `db:seed` in development creates one Operator bound to the configured Entra
   `(tid, oid)`; idempotent; never re-binds or reactivates a stopped one.
4. **Entry (BOOT-2):** the ordinary ORG OIDC path (Design D) with Entra; after the Entra callback, an
   Operator flagged as the Seed Operator skips only the Passkey stage, **only** when the
   discriminator holds; the ordinary issuance boundary (admission, binding, cooldown, session limit,
   fixation) applies; nothing records Passkey/MFA/Step-Up.
5. **Context (BOOT-4):** the root/grant/refresh/access chain carries `seed`; `from_claim` stops
   mapping blank to Normal (blank → `UNKNOWN`, which permits nothing) — this changes existing tokens
   without the claim, acceptable because nothing is deployed; every authorization entry point
   allow-lists `seed` for exactly the Seed screen and Sign Out; a static guard covers policy entry
   points.
6. **Normal Operators (BOOT-5):** the Entra callback gains no Passkey-skip branch for anyone else.
7. **Removed/created:** nothing to remove (not implemented); destructive changes limited to the
   `from_claim` default.

---

# Part 6 — H18 reconstruction (2026-10-22)

Input: the H18 handoff (one.md §1) with owner decisions D-136 … D-139. Static reading of the
working tree at `febec3225` with the uncommitted changes present; one read-only command was run
(`SHOW lock_timeout` / `SHOW statement_timeout` on three development connections, 6.2). Nothing
was implemented, migrated or deleted. Labels used below: **Fact** (read in code/schema, with
location), **Decided** (owner, one.md ID), **Proposal** (needs the owner), **Open**.
Where this Part and an earlier section of this file differ, this Part wins; the earlier sections
carry a pointer.

## 6.1 WU-24 reissued (D-138) — sub-units adopted (D-140)

> D-140 (H19): the split below is adopted. WU-24f/g/h are each approved separately after their counts and backup (A24-5a/b/c); the WU-24d backfill rule and the `not_applicable` name are decided (D-157).

**Why the old definition could not run.** Old step 3 ran "the WU-38 cleanup" in the middle of the
WU-24 migrations, while WU-38 depended on WU-24 and WU-05, and WU-05 on WU-24.

**How the cycle is removed.** The cleanup that settles existing data before deletion is **today's
cleanup machinery** (`SignUpExpiryJob` → `SignUpTermination` → `SignUpArtifactCleanup`, plus
`ClientSecretLifecycleJob`'s sign-up reconciliation), repaired first (WU-24e). WU-38 keeps only the
new behavior that needs WU-05: deadline from the Binding's curfew, the D-131 registered-status
predicate for every surface, and the D-135 refusal. WU-24 therefore depends on nothing in WU-05 or
WU-38.

**Facts used.**
- Physical databases per realm: OP (`op_base_{app,com,org}`: Flows, Bindings, ceremony sessions,
  tokens) and principal (`{app,com,org}_zenith`; `AppPrincipalRecord < AppZenithRecord`, so Client,
  contacts, passkeys and `client_secret_issuances` share one connection).
- `client_sign_up_flows.principal_id` is a nullable bigint with no FK (cross-DB); nothing on the
  principal side points back to the Flow except `client_secret_issuances.sign_up_flow_ref`.
- `SignUpArtifactCleanup` only claims Flows whose status is CANCELLED/EXPIRED/FAILED/HALTED;
  `SignUpExpiryJob` (every 15 min, queue `retention`) expires in-progress Flows past
  `expires_at` (the Flow's own TTL, not a curfew).
- `local_sign_up_flow_ref`: no caller passes it (`rotate_and_admit!` defaults it to `nil`; grep
  finds no other writer); one test asserts it is `nil`
  (`test/services/base_auth_admission_coordinator_test.rb:131`). FK `ON DELETE RESTRICT` to the
  Flow's `public_id` and part of `*_purpose_exclusive` and `*_transaction_exclusive` CHECKs on all
  three realms (`db/op_base_{app,com,org}_structure.sql`).
- `operator_sign_up_flows` exists (model only); ORG has no sign-up Flow in the D-125 scope.

**Sub-units (adopted, D-140).** Each is one implementation request.

| Sub-unit | Scope | Needs | DB change / destructive | Intermediate invariant after it | Tests (three.md) |
|---|---|---|---|---|---|
| WU-24a | Read-only data classification per surface (queries below), run in every environment that has data; result in `evidence/` | — | None | Counts known; nothing changed | A24-0 |
| WU-24b | Effective intent resolver (D-72): one shared resolver from server state; sign-up pages/actions require `sign_up`, sign-in ones `sign_in`; `authentication` no longer satisfies both | baseline | None | No page or parameter decides intent | A24-1 |
| WU-24c | `curfew_at` on the Admission Binding (D-74, D-75): add nullable → backfill `created_at + 30 min` (history value for every existing row) → NOT NULL, no default; issuance writes OP `clock_timestamp() + 30 min` in the issuing transaction; Switch copies the original | WU-24a | Add column; reversible (drop). Not destructive | Every Binding has one immutable deadline; consumers unchanged until WU-06 | A24-2 |
| WU-24d | `entry_intent` NOT NULL (D-129): backfill, then a CHECK tying `purpose` to its allowed values, then NOT NULL. Backfill rule (**decided D-157**): Sign-in path rows from the parent authorization transaction (`prompt` contains `create` → `sign_up`, else `sign_in`); `local_sign_up` → `sign_up`, `local_sign_in` → `sign_in` while WU-01 has not removed them; Re-verification rows → `not_applicable` | WU-24a, WU-24b | Column constraint change; reversible; no deletion (D-157) | No NULL `entry_intent`; NULL carries nothing | A24-6 |
| WU-24e | Cleanup repair (code only): (1) the cleanup decision is "Flow terminal **and** principal still unfinished", re-read **under the principal row lock** in the same principal transaction as the deletions; a registered principal (D-131: APP `ACTIVE`/`VERIFIED_WITH_SIGN_UP`; COM today any Visitor whose contact is no longer `UNVERIFIED_WITH_SIGN_UP`) is never touched; (2) idempotent retry: the deciding fact (actor status) is changed last, and a retry after a partial failure finishes the remaining rows instead of marking the cycle completed (6.2 F-2); (3) the lock-order fix F-1 (D-143) | D-143 | None | Cleanup can be re-run on any Flow without stranding or touching registered principals | A24-7, A35-2, A35-3 |
| WU-24f | Settle existing Flows before deletion (data operation): let in-progress Flows expire through `SignUpExpiryJob` (no forced expiry of Flows still inside their TTL), run cleanup and the `ClientSecretLifecycleJob` sign-up reconciliation, then re-run WU-24a | WU-24e; **owner approval A24-5a** (bulk deletion of unfinished principal data) | **Destructive** (unfinished principal rows discarded/destroyed by the existing cleanup) | Every remaining Flow is completed-with-registered-principal or terminal-and-cleaned; no unfinished principal is reachable only through a Flow about to be deleted | A24-5a, A24-8 |
| WU-24g | Retire `local_sign_up_flow_ref` on APP/COM/ORG ceremony sessions: count non-NULL rows (expected 0); drop the FK; rewrite both CHECKs without the column; drop the column; remove the parameter from `rotate_and_admit!` and the one test assertion | WU-24a | **Destructive** (column drop) — **owner approval A24-5b** | Ceremony sessions no longer reference Sign-up Flows; Flow deletion is not blocked by RESTRICT | A24-9 |
| WU-24h | E1 column (D-125): delete the remaining Flows (all are unbound by construction) after a `pg_dump` of the affected tables; add `auth_admission_binding_id` NOT NULL, FK `ON DELETE RESTRICT`, partial UNIQUE (≤ 1 in-progress Flow per Binding), `attr_readonly` + a static guard against `update_all`/raw SQL on the column; every Flow creation site binds the redeemed Binding in the same change; `AuthAdmissionBindingPurger` deletes Flows before their Binding; the request's Flow is resolved through the admitted Binding and `SignUpCycleLocator` becomes a hint (mismatch → ownership-mismatch refusal) | WU-24c, WU-24d, WU-24f, WU-24g; **owner approval A24-5c** | **Destructive** (Flow deletion) | Every Flow names its Binding; a stale tab cannot select another attempt's Flow | A24-3, A24-4, A24-10 |

**WU-24e implementation notes (D-143; static reading 2026-10-22, for the implementer).**

- **F-2 (cleanup atomic in the principal DB).** Contact, pending passkey, actor and their audit
  outbox rows live in one principal database per realm (`AppPrincipalRecord < AppZenithRecord`;
  `ClientPasskeyAuditOutbox`, `ClientSecretAuditOutbox` are `AppZenithRecord`; COM likewise in
  `com_zenith`). In `SignUpArtifactCleanup#schedule_dependent_retention!` open **one** principal
  transaction, lock the actor first (`Client` / `Visitor` `lock.find_by(id: cycle.principal_id)`),
  evaluate the existing decision on the locked rows (APP: actor `UNVERIFIED_WITH_SIGN_UP` and contact
  pending; COM: contact pending — D-128 changes COM later), lock and retire contact → passkey →
  actor inside that transaction. A failure rolls everything back, so the retry sees the same state
  and finishes; no per-record transactions. Principal lock order actor → contact → passkey matches
  the finalizers (L1). The Flow lock stays outermost (Flow → principal).
- **F-1 (Flow before Client).** `ClientSecretPasskeyReservationIssuer`: in `terminate_sign_up!` and
  `complete_sign_up!` open the OP transaction and take `ClientSignUpFlow.lock` before
  `Client#with_lock`; in `with_sign_up_delivery!`, `reattempt_for_sign_up!`, `call_for_sign_up!`
  move `ClientSignUpFlow.lock.find_by!` before `actor.with_lock`. `retire_signup_batch!` writes only
  principal rows, so the reorder keeps its semantics (principal commits inside the Flow's OP
  transaction, as in L1). `Auth::App::Sign::Up::Check::Telephone::PasskeysController#save_passkey_registration!`:
  wrap the existing body in `@sign_up_ticket.with_cycle_lock { @sign_up_actor.with_lock { … } }`
  (the issuer's inner Flow lock is then re-entrant on the same connection). No other path changes.
- **Red tests (write first, no test helpers; `use_transactional_tests = false` where threads commit,
  explicit teardown like `test/operations/passkey_registration_operation_concurrency_test.rb`).**
  - A35-3 (F-2), APP and COM: a cancelled Flow whose contact was created at T and actor at T + 2 h;
    `SignUpArtifactCleanup.call(cycle:, now: T + 10 min)` makes the actor's `discard_now!` raise
    `ArgumentError` (discard_at would exceed purge_eligible_at — a real production check), so the
    cycle becomes `FAILED`; then `call(cycle:, now: T + 3 h)`. Expected after the fix: contact
    `DELETED`, passkey gone, actor discarded, cleanup `COMPLETED`. Today the first call commits the
    contact deletion and the retry marks `COMPLETED` with the actor untouched (Red). Also: an actor in
    `ACTIVE` is never touched.
  - A35-2 (F-1): thread A holds `ClientSignUpFlow.lock` on a `CANCELLED` Flow in an open OP
    transaction; thread B calls `ClientSecretPasskeyReservationIssuer.terminate_sign_up!`; the test
    waits until the OP database shows a backend waiting on a lock (`pg_stat_activity.wait_event_type
    = 'Lock'`, bounded poll), then tries `Client.lock("FOR UPDATE NOWAIT")` on a separate
    connection. Expected after the fix: succeeds (B waits on the Flow, holds no Client lock). Today:
    `ActiveRecord::LockWaitTimeout` (Red). Release A, join B. Test-DB pool is 3 per database: A, B
    and the test thread.
  - Regression: `test/services/sign_up_artifact_cleanup_test.rb`,
    `test/operations/client_secret_passkey_reservation_issuer_test.rb`,
    `test/controllers/auth/app/up/telephones_controller_test.rb`, the APP telephone passkey sign-up
    controller tests, `test/services/sign_up/cancellation_test.rb`, `test/jobs/retention_purge_job_test.rb`.
  - Not covered by a dedicated concurrency test (recorded as such in evidence): the reorder in
    `with_sign_up_delivery!`, `reattempt_for_sign_up!`, `call_for_sign_up!` and the controller save;
    they follow the same pattern and their existing tests must stay green.

**WU-24a queries (read-only; APP shown, COM/ORG analogous with `visitor_*` / `operator_*`).**
OP database (`op_base_app`):

```sql
-- Q1 Flows by status and cleanup status
SELECT status_id, cleanup_status_id, count(*) FROM client_sign_up_flows GROUP BY 1, 2 ORDER BY 1, 2;
-- Q2 Flows with / without a principal, per status
SELECT status_id, count(*) FILTER (WHERE principal_id IS NULL) AS no_principal,
       count(*) FILTER (WHERE principal_id IS NOT NULL) AS with_principal
FROM client_sign_up_flows GROUP BY 1 ORDER BY 1;
-- Q3 Ceremony sessions still pointing at a Flow (expected 0)
SELECT count(*) FROM client_auth_ceremony_sessions WHERE local_sign_up_flow_ref IS NOT NULL;
-- Q4 Bindings by purpose and entry_intent
SELECT purpose, entry_intent, count(*) FROM client_auth_admission_bindings GROUP BY 1, 2 ORDER BY 1, 2;
-- Q5 Bindings by lifecycle (for the curfew backfill)
SELECT purpose,
       count(*) FILTER (WHERE redeemed_at IS NOT NULL) AS redeemed,
       count(*) FILTER (WHERE retired_at IS NOT NULL) AS retired,
       count(*) FILTER (WHERE redeemed_at IS NULL AND retired_at IS NULL AND expires_at > clock_timestamp()) AS live,
       count(*) AS total
FROM client_auth_admission_bindings GROUP BY 1 ORDER BY 1;
```

Principal database (`app_zenith`):

```sql
-- Q6 Clients by status (9 = UNVERIFIED_WITH_SIGN_UP, 10 = VERIFIED_WITH_SIGN_UP, 1 = ACTIVE)
SELECT status_id, count(*) FROM clients GROUP BY 1 ORDER BY 1;
-- Q7 Contacts still in the sign-up status (6 = UNVERIFIED_WITH_SIGN_UP)
SELECT 'email' AS kind, count(*) FROM client_emails WHERE user_email_status_id = 6
UNION ALL SELECT 'telephone', count(*) FROM client_telephones WHERE user_identity_telephone_status_id = 6;
-- Q8 Secret issuances waiting for their sign-up Flow
SELECT count(*) FROM client_secret_issuances
WHERE sign_up_flow_ref IS NOT NULL AND signup_completed_at IS NULL AND discard_at = 'infinity';
```

Cross-DB matrix (read-only runner on reading roles, counts only, no ids printed): Flow class
(in progress / terminal, cleanup pending or failed / terminal, cleanup completed / completed) ×
principal (none / unfinished / registered / missing), joined in Ruby on `principal_id`; plus
unfinished principals that no Flow references (orphans: reported, never touched by WU-24).
Each database's read time is recorded (they are read at different moments).

**Backup / rollback / recovery (Proposal).** Before WU-24f/g/h: `pg_dump --data-only` of the
affected tables of both databases of the realm, location and SHA-256 recorded in `evidence/`, kept
until the cycle closes. WU-24c/d are reversible migrations. WU-24f/g/h are irreversible in Rails;
recovery is restoring the dump into the dropped/emptied tables before any new row is written. Never
deployed (D-125); staging is treated like production for approval.

**Owner approval conditions before any deletion (A24-5a/b/c).** WU-24a counts for that
environment; the expected effect per row class; zero registered principals affected (matrix row
"registered" untouched by construction, re-checked after); backup taken; the operator named.

**New order of the Sign-up series.** WU-35 report → WU-24a → WU-24b → WU-24c → WU-24d → WU-24e →
(approval) WU-24f → (approval) WU-24g → (approval) WU-24h → WU-05a … WU-05g → WU-08 → WU-06 →
WU-07 → WU-38. WU-34 (after AX26-1) may run before WU-24 (it touches login predicates only); its COM
part (D-128 statuses) must land before WU-38 so that WU-38's predicate is the same on both surfaces.

## 6.2 WU-35 lock inventory report (D-139)

**Scope.** Sign-up (entry, OTP, passkey/secret steps), Finalization (email/telephone/social),
termination and cleanup, Admission redemption, root login, and the Re-verification committers that
the H18 table named. Not inventoried: refresh/rotation, logout, revocation and avatar/group paths
(they hold no Sign-up Flow; listed as further verification).

**Database facts.** Two databases per realm (OP, principal). A wait cycle that crosses them is
invisible to PostgreSQL's deadlock detector. **Fact (run, development):** `lock_timeout = 0` and
`statement_timeout = 0` on the primary, `op_base_app` and `app_zenith` connections — the
`lock_timeout: 2s` / `statement_timeout: 15s` keys in `config/database.yml` are top-level keys that
the PostgreSQL adapter drops (it forwards only libpq connection keys and sets session variables
only from `variables:`; `activerecord/.../postgresql_adapter.rb` `conn_params.slice!` and
`configure_connection`). Production uses the same `default` block; its server-side defaults were not
read. Web requests are bounded by rack-timeout (10 s); Solid Queue jobs have no bound. Retention
jobs run on one thread in one process (`config/queue.yml`), so two retention jobs do not overlap
inside one deployment.

**Acquisitions (outer → inner; DB in brackets).**

| # | Path | Location | Order |
|---|---|---|---|
| L1 | Sign-up Finalization (email/telephone/social Auth) | `app/controllers/concerns/sign_up_sequence_controller_support.rb:221-255` (`with_cycle_lock`, `flow_base.rb:92-107`) | Flow `FOR UPDATE` [OP, outer txn kept to the end] → side effect: APP telephone `sign_app_up_telephone_registration_finalizer.rb:46-64` Client → telephone → passkey [principal] → ceremony txn [OP]; COM telephone `sign_com_up_telephone_registration_finalizer.rb:41-52` Visitor → telephone [principal] → ceremony [OP] → graph → `handoff_to_sign_in_flow!` → `with_actor_session_lock` (`authentication_base.rb:412-424`) Client [principal] → token writes [OP, inside the Flow's open OP txn]. Principal commits before the OP commit |
| L2 | `ClientSecretPasskeyReservationIssuer.complete_sign_up!` after L1 | `sign_up_sequence_controller_support.rb:265-267` → `client_secret_passkey_reservation_issuer.rb:38-76` | Client `with_lock` [principal] → Flow `FOR UPDATE` [OP] → issuance [principal]. Runs after L1 committed (not nested) |
| L3 | APP telephone passkey save (sign-up) | `auth/app/sign/up/check/telephone/passkeys_controller.rb:125-137` | Client `with_lock` [principal] → `UPDATE` Flow (row lock) [OP] → `call_for_sign_up!` (`…_issuer.rb:137-158`): OP txn → Client (re-entrant) → Flow `FOR UPDATE` → passkey. **No Flow lock first** |
| L4 | Secret delivery / reattempt (sign-up) | `…_issuer.rb:78-135` via `client_secret_presentation_issuer.rb:32,41`, `client_secret_storage_confirmation_committer.rb:28`, `client_secret_manual_issuance_invalidator.rb:24`, `auth/app/sign/up/check/telephone/secrets_controller.rb:108` | OP txn opened → Client `with_lock` [principal] → Flow `FOR UPDATE` [OP] → passkey → issuance |
| L5 | Termination (cancel/expire/halt) | `app/services/sign_up_termination.rb:62-69, 168-177` | Flow `lock!` [OP] → state change → commit; **then** `terminate_sign_up!` (`…_issuer.rb:12-36`) Client [principal] → Flow [OP]; **then** L6 |
| L6 | Artifact cleanup (sync after L5, and `RetentionPurgeJob`) | `app/services/sign_up_artifact_cleanup.rb:41-64, 79-110, 126-166` | Claim Flow `FOR UPDATE SKIP LOCKED` [OP] → `with_cycle_lock` → for contact, passkey, actor: each its own principal txn `lock!` then delete/discard |
| L7 | `ClientSecretLifecycleJob` sign-up reconciliation | `app/jobs/client_secret_lifecycle_job.rb:89-104` | Per issuance: `complete_sign_up!` or `terminate_sign_up!` (Client → Flow) |
| L8 | Social sign-up commit (Base; removed by WU-05g) | `app/operations/identity_social_ceremony_final_committer.rb:171-205` | Flow `with_cycle_lock` [OP] → principal txn → subject advisory lock (`ClientExternalIdentity.with_subject_lock`) → Client [principal] → OIDC ceremony txn `lock!` [OP, same outer OP txn] → candidate consume → graph → Flow (re-entrant) |
| L9 | Sign-up OTP issue/verify, delivery guards | `email_sign_up_otp_*`, `telephone_sign_up_otp_*` (5.2) | Flow [OP] → owner [principal] → contact |
| L10 | Admission redemption | `app/services/base_auth_admission_coordinator.rb:615-628` | Only when a Base token exists (Re-verification): actor [principal] → Binding/ticket [OP]; otherwise Binding/ticket only |
| L11 | Root login | `authentication_base.rb:412-424` | actor [principal] → token writes [OP] |
| L12 | Re-verification committers | `identity_credential_removal_committer.rb:31-36`; `identity_step_up_ceremony_freshness_committer.rb:16-26, 135-152`; `identity_passkey_registration_final_committer.rb:63-64, 134-151`; `email_credential_registration_otp_finalizer.rb:72-88` | All take the actor [principal] first, then device session/token/credential/transaction [OP] in varying inner orders |

**Wait-for analysis.**

| ID | Pair | Same rows? | Cycle | Classification |
|---|---|---|---|---|
| F-1 | L5 web (replayed cancel/expire: `already_terminal_for_event?` → `run_artifact_cleanup` → `terminate_sign_up!` holds **Client**, waits **Flow**) vs L6 `RetentionPurgeJob` (holds **Flow**, waits **Client** when it reaches the actor) | Same Flow, same Client | Yes: Client→Flow vs Flow→Client across OP and principal DBs; no detector; `lock_timeout` 0 | **Fix required.** Outcome today: the web request stalls until rack-timeout (10 s) aborts it; the job then proceeds. Same shape: L3/L4 (Client→Flow) vs L1, L5 state change, L6 (Flow→…→Client) when two tabs act on one Flow |
| F-2 | L6 retry after a partial failure | — | Not a lock cycle: the contact is deleted first; the retry recomputes the dependents from the **contact** status, finds none, and marks the cycle `completed` — the pending Client and passkey stay forever (`sign_up_artifact_cleanup.rb:179-185`, `229-235`) | **Fix required** (correctness of cleanup; D-131/D-135 depend on it) |
| F-3 | Lock waits without a bound | — | Any cross-DB wait (F-1 included) has no server-side limit in jobs | **Fix required, owner decision X-49**: make the intended limits effective (`variables: { lock_timeout: …, statement_timeout: … }`), which changes behavior for every database and job |
| V-1 | L1 Finalization vs L6 cleanup of the same Flow | Same Flow | No: both take the Flow lock first; L6 claims only terminal Flows, L1 requires an active one | Safe today. **Further verification** after WU-24e/WU-38: cleanup must keep taking the Flow lock first |
| V-2 | L1/L8 vs Sign-in on the same unfinished Client (AX26 gap) | Same Client | Sign-in takes actor → token/OP rows, never the Sign-up Flow | No cycle found; closed by WU-34 anyway |
| V-3 | L8 holds Flow + Client, waits the OIDC ceremony transaction row [OP] | — | No path found that locks that transaction row first and then the Client | **Further verification** (path removed by WU-05g) |
| V-4 | L12 among themselves | Same actor | Serialized by the actor lock; inner order differences cannot cycle | No change |
| V-5 | L10 / L11 vs Sign-up | Different rows (no Sign-up Flow) | — | No change |
| V-6 | WU-24h FK: inserting/updating a Flow takes `FOR KEY SHARE` on its Binding, which conflicts with `FOR UPDATE` taken by redemption (`auth_admission_binding.rb:102`) | Same OP DB | Detected by PostgreSQL if it cycles | **Further verification** in WU-24h tests |
| V-7 | Refresh, logout, revocation (token first?) vs actor-first paths | — | Not inventoried | **Further verification** (WU-16 design) |

**Minimal fixes (Proposal, P-139a).**
- F-1: in `ClientSecretPasskeyReservationIssuer` (`terminate_sign_up!`, `complete_sign_up!`,
  `with_sign_up_delivery!`, `reattempt_for_sign_up!`, `call_for_sign_up!`) take the Flow lock
  (`with_cycle_lock`) **before** the Client lock, as L1/L6/L9 do; in the APP telephone passkey save
  (L3) do the same around `PasskeyRegistrationOperation` and the Flow update. No other path changes.
  Commit order: principal txn commits inside the Flow's OP txn, as in L1 (unchanged semantics).
- F-2: WU-24e (6.1).
- F-3: X-49.
- Not proposed: a global order, reordering L10–L12, or touching L8 (removed by WU-05g).

**Retry safety.** `SignUpTermination` replays are idempotent by design (status check); L4 delivery
yields inside the locks (a retry after an exception re-runs the yield — callers must be idempotent;
not verified). L6 is not retry-safe (F-2).

**Final order.** Not decided (D-139). After F-1 the Sign-up family is uniformly "OP Flow → principal
rows", and the Sign-in family "actor → OP rows"; no inventoried path holds a Sign-up Flow and an
actor lock in the Sign-in order. WU-05e and WU-38 use the Sign-up order.

## 6.3 WU-11 revised design (D-136, details approved as D-144)

> D-144 (2026-10-22): items 1–9 below are approved, plus item 10. The "Open (owner)" line at the end is closed.

**Facts (`app/adapters/oidc_op_jwks_client.rb`).** Per-process cache, `CACHE_TTL` 1 h,
`MAX_STALE_TTL` 5 min, timeouts 2 s open / 5 s read, ≤ 4 keys, `kid` ≤ 128 bytes; an unknown `kid`
against a fresh cache always fetches (a cold cache fetches twice); fetch errors are swallowed and
`public_key_for` returns `nil` for "unknown" and "failed" alike. Clients: one per resource type in
`RpCellLocalSession::JWKS_CLIENTS`; `RpBackchannelLogoutEndpoint` builds a new client per request
with a hard-coded `/.well-known/jwks.json` (BX-6). The rate-limit Valkey is wired only as
`ActiveSupport::Cache::RedisCacheStore` (`config.x.rate_limit.store`), whose error handler logs and
**swallows** failures (`lib/umaxica/valkey/store_error_handler.rb`) — so `write(unless_exist: true)`
cannot tell "already taken" from "Valkey down". `Umaxica::Valkey::Connection` raises
`Umaxica::Valkey::Unavailable` and accepts an explicit `url:`.

**Proposal (P-136a).**
1. **Coordinator:** a small adapter on `Umaxica::Valkey::Connection` built with the **rate-limit**
   URL (`Settings.current.rate_limit.url`) and namespace `<rate-limit namespace>:oidc_jwks_refetch`
   (production `rate_limit:production[:suffix]`, development `rate_limit:development`, tests via
   `Umaxica::Valkey::TestNamespace`). Keys per issuer:
   `…:oidc_jwks_refetch:<sha256(issuer)[0,32]>:lease` and `…:<digest>:last`.
2. **Lease:** `SET lease <worker id> NX EX 10` (10 s > 7 s worst-case fetch). Taken only for an
   unknown `kid` (or a known `kid` past the stale window). Not released early; it expires, so a worker
   crashing mid-fetch blocks others for at most 10 s.
3. **Window:** after the fetch, `SET last <json> EX 30` with `{"outcome":"ok"|"failed","at":…,
   "kids":[…]}` (the fetched `kid` list: public, ≤ 4 × 128 bytes). A new lease is taken only when
   `last` is absent (`SET lease NX` succeeds and `GET last` is nil inside one Lua script).
4. **Decision for an unknown `kid`:**

| Situation | Result |
|---|---|
| Lease taken, fetch ok, `kid` present | found (cache replaced) |
| Lease taken, fetch ok, `kid` absent | invalid |
| Lease taken, fetch failed | unavailable |
| Window active, `last.ok`, `kid` ∉ `last.kids` | invalid (no fetch) |
| Window active, `last.ok`, `kid` ∈ `last.kids` | this process fetches once for itself (the `kid` is genuine, so this is not attacker-driven; bounded by processes × rotations) → found / unavailable |
| Window active, `last.failed` | unavailable |
| Lease held by another worker, no `last` yet | unavailable (503, retryable) |
| Valkey unavailable | process-local limiter (same 30 s window per issuer per process): allowed → fetch as above; refused → unavailable. Never "no limit" |

   A known `kid` in a fresh or allowed-stale cache never touches Valkey (a Valkey outage never
   refuses it). Past the stale window with the fetch failing → unavailable.
5. **Typed result:** `found(key)` / `invalid(reason)` / `unavailable(reason)`; the three verifiers
   (`oidc_op_access_token_verifier.rb`, `…_id_token_verifier.rb`, `…_logout_token_verifier.rb`) pass
   it on; callers map invalid → their 400/401 contract, unavailable → 503 (BX-7).
6. **Window value:** recommend **30 s**. Reasons: ≥ 4 × the 7 s fetch bound; ≤ 2 fetches per issuer
   per minute per environment under attack; with keys pre-published at least `CACHE_TTL` (1 h) before
   first use, rotation never depends on the unknown-`kid` path; with an unannounced rotation the cost
   is at most 30 s of 503s. Pre-publication ≥ 1 h + 5 min is a key-rotation requirement to record
   with WU-02 (Visa keys).
7. **Operations:** keys always carry a TTL; rate-limit Valkey eviction (policy not read) can only
   drop a key early, which allows one extra fetch — acceptable; logs carry issuer digest, outcome,
   reason; never the token, `kid` value from the request, or the URL with credentials; metrics:
   fetch count/outcome per issuer digest, limited count.
8. **Tests:** injected clock and a fake connection for the table; one concurrency test with two
   threads against the test rate-limit Valkey (db 4, run-scoped namespace) asserting one fetch.
9. **Also in WU-11:** BX-6 — the BCL receiver uses the cached per-issuer client from Discovery.
10. **Pre-check before any refetch (D-144):** the header `alg` is ES384, the `kid` passes the
    existing format checks, and the token's issuer equals the RP's configured issuer for that client;
    otherwise the result is invalid and no lease is taken and nothing is fetched. Key rotation
    requirement (record with WU-02 Visa keys): publish a new key ≥ 1 h 5 min before first use.

**Open (owner):** none (D-144).

**Added 2026-10-25 (D-174), implemented.** Row "Window active, `last.ok`, `kid` ∈ `last.kids`": when
this process's own fetch fails, the same process does not fetch that `kid` again for 30 seconds and
answers unavailable (`recent_self_fetch_failed`; an allowed-stale cached key still verifies). At
30 seconds it fetches again; a success clears the entry. Process-local only; improvement later.
Evidence: `evidence/2026-10-25-wu11-negative-cache-N4C7.md`.

## 6.4 WU-21 revised design (D-137)

> **Superseded by D-151 (6.12, proposal (D) adopted).** Item 2's path rules carry over to `target_link_uri`, without any query.

**Facts.**
- Today the RP `pt` is an **unsigned** Base64 path (`OidcSsoInitiator#encoded_pt/#decode_pt`,
  `oidc_sso_initiator.rb:161-169`), checked only by `RedirectsPathTargetResolver`; the pending OIDC
  entry stores it per `state` in the Rails session (`remember_oidc_pending_flow!`, limit
  `OIDC_PENDING_FLOW_LIMIT = 2`, TTL 10 min in `OidcCallback`), consumed by deleting the entry.
- The session store is `:cookie_store` (`config/initializers/session_store.rb`): deleting the entry
  is not replay-proof against an old cookie.
- A signed, expiring, surface- and session-nonce-bound target already exists for Auth/Base
  (`AuthenticationRedirects#issue_authentication_path_target_token` / `#verify_authentication_pt_path`,
  `RedirectsSignedTargetSupport`: `MessageVerifier`, key from `key_generator` with a salt, 15 min).
  Accepted ADRs `adr/signed-return-targets-only.md` and `adr/redirect-target-lanes-pt-nt-xt.md`
  already require signed, session-bound targets; the RP's unsigned `pt` does not conform.
- `MessageVerifier` signs but does not hide the path: the payload is readable in URLs and logs.
  `log_signed_target_rejection` logs `request.fullpath`, which includes the `pt` value.

**Proposal (P-137a).**
1. **Token:** reuse the `RedirectsSignedTargetSupport` pattern with a **new salt/purpose**
   (`rp_return_target`) so RP tokens never verify as Auth/Base targets and vice versa; prefer
   `ActiveSupport::MessageEncryptor` (AEAD) so the path is not readable in URLs, history or logs.
   Claims: version, RP `client_id`, RP host, realm, path (+ permitted query), session nonce, random
   `jti`, issued at; expiry by the encryptor. Key rotation through the key generator's rotation.
2. **Validation at issue:** the existing internal-path checks plus: no dot segments, no `%25`
   (double encoding), path not under the RP's own `/sign` or `/oidc` routes, per-RP query-key allow
   list (default none).
3. **Carriage:** protected page → 303 `GET /sign?pt=…`; the `/sign` page carries it in a hidden
   field; `POST /sign` verifies it (expiry, RP, host, session nonce) and stores **the token** in the
   pending OIDC entry for the new `state` (state-keyed map, not a single slot); OP, Visa, Auth and
   Jump never see it. `Referrer-Policy: no-referrer` on `/sign`.
4. **Restore:** the callback consumes the pending entry by `state`, exchanges the code, establishes
   the RP session, then verifies the stored token again (signature, RP, host, nonce) and redirects
   once. **Single use** = the OP authorization code is single-use and the redirect happens only
   after a successful exchange in the same request; a replayed old cookie with the same `state`
   fails the exchange. Cancel/`access_denied`, a failed exchange, an expired or foreign token → RP
   top page, target dropped.
5. **Lifetime:** issue → `POST /sign` 15 min (the existing value); total ≤ 15 min + the RP pending
   bound (D-76; 35 min proposed in 5.6) = 50 min. Open.
6. **Tabs:** each tab has its own token and `state`; nothing overwrites another tab. The limit of 2
   pending entries evicts the oldest tab's entry (its callback then fails to the top page) — X-50.
7. **Logging:** reason codes only; the rejection log stops including `request.fullpath` for these
   requests.

**Open (owner):** encryptor vs verifier; final lifetime; per-RP allow lists; X-50; whether storing
the token in the state-keyed pending entry matches "no single shared session slot" (this proposal
reads it so).

## 6.5 Work Unit status matrix (WU-01 … WU-39)

Columns: Owner = decisions present; DB = schema/data change; Destr. = destructive operation.
Executable: **Now** (no blocking dependency or decision), **After X** (dependency), **Design first**,
**Gated** (approval). "Ready" is not used.

| WU | Scope | Depends on | Owner decisions | Open items | DB | Destr. | Tests / Gates | Executable | Order |
|---|---|---|---|---|---|---|---|---|---|
| WU-01 | Remove Local Sign-in Flow (01a–f) | G-1 baseline | D-60 complete | 01a classification (72 files) is its own first step | No | No | A01-*, G-1…7 | Now | 1 |
| WU-02 | Visa OP / Base RP (02a, 02b, 02-APP, 02-COM, 02-ORG, 02i) | WU-04, WU-05g, WU-01, WU-03 | D-59, D-61, D-62, D-65, D-158, D-161 | — | Config + new endpoints | No | A02-*, G-15 | After deps + P-140 | 4 |
| WU-03 | Remove `/edge/v0/cookie` | — | D-63 | — | No | No | A03-* | Now | 1 |
| WU-04 | Telephone OTP Turnstile (APP, COM) | — | D-66, D-67 | — | No | No | A04-* | Now | 1 |
| WU-05 | Sign-up unification (05a–g) | WU-24h; WU-35 F-1 for 05e | D-69…D-72, D-77, D-78, D-105, D-131 | Finalization ADR (05a) | Yes (05c/05d rows) | No | A05-*, G-10…14 | After WU-24 | 3 |
| WU-06 | Curfew enforcement | WU-24c, WU-05 | D-45, D-74, D-75, D-105, D-131, D-160 | — | No | No | A06-*, G-9 | After WU-05 | 3 |
| WU-07 | Refusal classes | WU-06 | D-47, D-73 | — | No | No | A07-* | After WU-06 | 3 |
| WU-08 | Social callback matrix | WU-05b | D-48, D-72 | — | No | No | A08-* | After WU-05 | 3 |
| WU-09 | Browser allowlist | — | D-50 (1) | — | No | No | A09-* | Now | 1 |
| WU-10 | Standard refresh | WU-02 V4 coordination | D-25, D-80 | — | Yes (`rp_refresh_attempts` drop) | Yes (authorized, D-168) | A10-* | After WU-02 | 4 |
| WU-11 | JWKS via Discovery, Valkey limit; self-fetch negative cache (D-174, done 2026-10-25) | — | D-23, D-136, D-144, D-174 | — | No | No | A11-* | Now | 1 |
| WU-12 | Design D relays | WU-02 | D-100…D-103 | — | No | No | A12-*, G-18 | After WU-02 | 4 |
| WU-13 | Cancel/Switch, OP side only (RP side in WU-43, D-152) | WU-12; WU-43 for the end-to-end re-check | D-38, D-39, D-74, D-152, D-153 | — | No | No | A13-* | After WU-12 | 4 |
| WU-14 | RP-Initiated Logout | WU-02 | D-33 | — | Yes (OP grant logout-hint records) | No | A14-*, G-16 | Implemented locally; focused RP/end-session tests pass; browser/G-16 acceptance open | 4 |
| WU-15 | BCL receiver; sender | WU-16 for sender | D-26, D-31, D-117, D-118, D-121 | — | Receiver no; sender yes | No | A15-*, G-19 | Implemented locally; focused suites recorded; reconcile A15 evidence | 1 / 5 |
| WU-16 | Authority-stop primitive (5.8 v2) | Accepted 5.8 v2; D-173 cause mapping | D-119, D-123, D-163 … D-168, D-172, D-173 | — | Yes | Replace legacy logout-flow tables (authorized, D-168) | G-20 | Implemented locally; G-20/A44 acceptance remains open | 5 |
| WU-17 | Remove activation, `contract_epoch` | — | D-35, D-168 | — | Yes | Yes (authorized, D-168) | A17-* | Now | 4 |
| WU-18 | OP-chain + RuntimeRole removal (18a–f); 18a done, 18b kept, **18c–18f deferred to a later cycle (D-175)** | WU-02, WU-10, WU-11 | D-108, D-175 | Q18-1 … Q18-4 (later cycle) | 18f drops | 18f (authorized, D-168) | A18-* | Later cycle | 4 |
| WU-19 | One bundle per language | — | D-113 | Owner reviews merged texts (evidence L19M) | No | No | A19-* (A19-1/2 passed; A19-3 not run) | Done 2026-10-25 | 1 |
| WU-20 | Passkey identifier-first | sequence with WU-30 | D-112, D-116 | — | No | No | A20-* | Now (not merged with WU-30) | 1 |
| WU-21 | Merged into WU-43 (D-151, D-162); do not implement separately | — | D-151, D-162 | — | No | No | A43-* | — | — |
| WU-22 | Sign-out records SO-1…7 | WU-16 (SO-3) | D-43, D-123, D-172 | Decided | Yes | Replace legacy logout models/tables (D-168) | G-16, G-20 | Implemented locally; reconcile touched gates | 5 |
| WU-23 | Credentials/KMS docs | — | D-15, D-17 | — | No | No | Diff | Now | 1 |
| WU-24 | Reissued; after D-159: 24b, 24c, 24d, 24e, 24g, 24h | — | D-72, D-74, D-75, D-125, D-129, D-138, D-140, D-157 | — | Yes | Authorized (D-168) | A24-* | 24b–24h now (24a not applicable, D-159); 24f after 24e | 2 |
| WU-25 | Revocation client auth | WU-02 | D-79 | — | No | No | A25-* | After WU-02 | 4 |
| WU-26 | Read-only diagnosis — **withdrawn and removed (D-196, 2026-10-27)** | — | D-82, D-196 | — | No | No | A26-* withdrawn | Withdrawn | — |
| WU-27 | Post-containment journey | WU-12 | D-104, D-130 | — | No | No | A27-* | After WU-12 | 4 |
| WU-28 | Seed Operator | design review | D-122 | 5.9, `from_claim` change | Possibly | Removal of old Bootstrap data | — | Design first | 5 |
| WU-29 | Sentry | WU-02, WU-12, WU-13 (route table) | D-84…D-99, D-169 | — | No (flags) | No | A29-*, G-17 | After WU-13 | 4 |
| WU-30 | Security Mode migration | — | D-88, D-92, D-132, D-168 | — | Yes | Yes (authorized, D-168) | A30-*, G-21 | Now | 6 |
| WU-31 | Email OTP Red tests | — | D-89 | Fix after results | No | No | A31-* | Now | 1 |
| WU-32 | ORG halt audit | — | D-90, D-134 | — | Yes (partial index) | No | A32-* | Now | 1 |
| WU-33 | Failure convergence table | — | D-91 | Fix order | No | No | A33-1 | Now (5.4 first pass exists) | 1 |
| WU-34 | Refuse unfinished registrations | AX26-1/2 run | D-106, D-128 | — | Yes (COM statuses, data) | COM statuses (authorized, D-168) | A34-* | After AX26-1; COM part gated | 1–2 |
| WU-35 | Lock inventory | — | D-107, D-139, D-143 | — | No | No | A35-1 | Report delivered (6.2); F-1/F-2 implemented in WU-24e, F-3 in WU-41 | 1 |
| WU-36 | Host-only cookies | — | D-115 | P-141 | No | No | A36-*, G-22 | Now (after P-141) | 1 |
| WU-37 | Puma | — | D-120 | Load estimate | No | No | A37-* | Now | 1 |
| WU-38 | Curfew-based cleanup, D-135 refusal — **done 2026-10-25** | WU-24, WU-05, WU-34 (COM) | D-126 (2), D-131, D-135, D-176 | — (D-176) | No | Yes (ongoing deletion) | A38-* (test files pass; case mapping open) | Done 2026-10-25 | 3 |
| WU-39 | ADR/docs | — | §4 | — | No | No | A39-1 | Now (only decided items) | 1 |
| WU-41 | Effective DB `lock_timeout` / `statement_timeout` | — | D-142 | — | Config | No | A41-* (evidence, not Minitest) | Now | 1 |
| WU-42 | `redirect_uri` conformance (D-145) | — | D-145, D-146, D-147, D-148 | — | No | No | A42-* | Now | 1 |
| WU-43 | ES384 JWS `state` + `target_link_uri` + RP-side Cancel/interruption (D-149 … D-153; WU-21 merged) | WU-42 (error delivery); Base RPs after WU-02f | D-149 … D-153 | — | No | No | A43-*, A21-* | Now (A43-15 with a constructed callback; end to end in WU-13) | 2 |
| WU-44 | Root issuance re-check + authoritative epoch + credential-change serialization (D-163, D-165, D-167) | R4-1 Red | D-163 … D-167 | — | No | No | A44-* | Now | 1 |
| WU-40 | Recovery OTP send: visible Turnstile (APP, COM) | — | D-141, D-156 | — | No | No | A40-* | Now | 1 |

## 6.6 Order across all units (replaces "Order across all units", H18)

1. Independent, now: WU-44 (after R4-1 Red; D-163/D-165), WU-42 (`redirect_uri` conformance), WU-43 for the separate-host RPs (Warp, Core, Edit, Palm, Tech; after WU-42), WU-41 (timeouts; early, so later units are tested under the real bounds), WU-01 (01a first), WU-03, WU-04, WU-40 (same Turnstile pattern as WU-04; may share its implementation request), WU-09, WU-15 receiver, WU-19, WU-20, WU-23,
   WU-31, WU-32, WU-33 (completion), WU-36 (after P-141), WU-37, WU-39, WU-11; AX26-1/AX26-2 → WU-34 (APP
   part).
2. Sign-up series: WU-35 fixes approved → WU-24a … WU-24h (approvals at 24f/g/h) → WU-26 →
   WU-05a … WU-05g → WU-08 → WU-06 → WU-07 → WU-34 COM part (if not earlier) → WU-38.
3. Visa series: WU-02a → WU-02b → WU-02-APP → WU-02-COM → WU-02-ORG → WU-02i (D-161) → WU-25 → WU-12 → WU-13 → WU-29 → WU-14 → WU-10 →
   WU-17 (gated) → WU-18a … WU-18f → WU-27. WU-43 for the Base RPs (`base-{app,com,org}-ww`) only
   after WU-02f (WU-21 is merged into WU-43).
4. Sign-out: accepted 5.8 v2 (D-172) and cause mapping (D-173) → WU-16 → WU-15 sender and WU-22. WU-44/30/38 are excluded from this implementation request.
5. WU-30 (authorized by D-168; sequence with WU-20). WU-28 is out of this cycle (D-170).

No unit depends on a later unit of its own series; WU-38 is the last Sign-up unit and nothing
depends on it.

## 6.7 Adversarial review of this plan (and of the earlier review items)

**Earlier review items (H18 §6).**

| # | Item | Status | Where |
|---|---|---|---|
| 1 | WU-24 ↔ WU-38 cycle | Resolved (proposal) | 6.1 |
| 2 | WU-06 / G-9 / A06-6 vs D-131 | Resolved: A06-6 split, G-9 reworded, WU-06 "Decided" paragraph corrected | three.md, WU-06 |
| 3 | WU-21 `session[:return_to]` tab collision | Resolved by D-137 (X-50 remains for the pending-entry limit) | 6.4 |
| 4 | WU-02c–02e inconsistent intermediate states | Confirmed: after 02c a realm's endpoints are on Visa while `iss` is still `www` (Discovery issuer ≠ its URL) and Auth results still target Base until 02e | P-140 |
| 5 | WU-02a accepts later Visa endpoints | Confirmed for A02-6 (needs Visa JWKS, WU-02c) and A02-2 (needs the Visa host routing, WU-02b) | Mapping changed |
| 6 | WU-05a stop rule vs known Red baseline | Confirmed | Stop rule now excludes violations already in the G-1 baseline / AX26 list |
| 7 | WU-05d expects WU-38 cleanup | Confirmed | "Left on failure" now points to the existing cleanup (repaired in WU-24e) |
| 8 | WU-01a classification | Open by design: 2/10/60 is preliminary; WU-01a is that work | 5.7 |
| 9 | WU-01b Green vs baseline failures | Confirmed | Rule now "same pass/fail set as G-1 for those files" |
| 10 | Host-only cookie vs Domain-cookie deletion | Confirmed: A36-1 asked for "no Domain" and for clearing a Domain cookie, which needs `Domain` | P-141 |
| 11 | WU-15/16 vs G-19 timing | Confirmed: G-19 was "introduced by WU-15 sender (after WU-16)" yet "re-checked by WU-16" | G-19 split |
| 12 | Stale `one.md` summaries | Confirmed (T14, T21, resume list, next steps) | Corrected |

**Plan checks.**
- Unapproved items as decided: every new mechanism in 6.1–6.4 is labeled Proposal; one.md D-136 …
  D-139 record only the approved principles.
- Cycles: none in 6.6 (checked per series).
- Intermediate states: WU-24c–24h each state an invariant; WU-02 needs P-140; WU-24f is safe only
  after WU-24e.
- Cross-DB failure and registered identities: WU-24e makes the registered-status check happen under
  the principal lock; F-2 is the known gap until then — **do not run cleanup at scale (WU-24f)
  before WU-24e**.
- Sign In First: unchanged; WU-24 adds no session writer.
- Sign-up / Sign-in / Re-verification: WU-24d gives Re-verification rows `not_applicable`; F-1
  touches only Sign-up paths.
- APP/COM/ORG: ORG `operator_sign_up_flows` is outside D-125 (stated); ORG gets WU-24c/d/g only.
- Tests ahead of features: A24-* cases are mapped to the sub-unit that introduces the behavior.
- Approvals before data destruction: A24-5a/b/c, A30-1, A18-3, WU-10, WU-17, WU-34 COM data.
- Not proven: V-1, V-3, V-6, V-7; production `lock_timeout`; rate-limit Valkey eviction policy;
  whether AEAD encryption is acceptable for `pt`.

## 6.8 Owner decisions needed before implementation starts

1. ~~WU-24 sub-units~~ adopted (D-140); backfill and `not_applicable` decided (D-157).
2. ~~WU-35 fixes F-1 and F-2 and X-49~~ decided: D-143 (WU-24e), D-142 (WU-41).
3. ~~WU-11 details~~ decided (D-144).
4. ~~WU-21 token format, lifetime, allow lists, X-50~~ → obsolete: `pt` abolished (D-151), one pending entry per browser (D-155), 30 min (D-150), acceptance in A43 (D-162).
4a. ~~WU-40 mode~~ decided (D-156).
5. ~~P-140, P-141, P-142~~ adopted (D-158); P-140 made final by D-161; P-142 used in 5.8 v2.
6. ~~5.8/5.9 designs, WU-30 approval, Sentry D-UX/D-OBS~~ → 5.8 v2 written 2026-10-23 (owner review: S-1 … S-3); 5.9 out of cycle (D-170); WU-30 authorized (D-168); Sentry D-169.

**Still open (2026-10-23):** none. 5.8 v2 accepted (D-172); ORG discoverable conflict resolved (D-171).

**First unit to implement (recommendation): WU-01a/WU-01 and the AX26-1 Red test.** Both need no
pending decision, change no schema, and WU-01 removes code that several later units would otherwise
have to carry (Local purposes in WU-24d's backfill, `local_*` rows in WU-12). AX26-1 decides whether
the suspected security gap is real (WU-34).

## 6.9 WU-40 — Account recovery OTP send: Turnstile (D-141)

**Source:** H19 relayed review; re-read in this session (static).

**Facts.**
- `Base::App::Identity::Recovery::SessionsController` and `Base::Com::Identity::Recovery::SessionsController`
  include `EnforcementRecoveryCeremonyFlow`; `create` sends (`start_recovery_otp` →
  `EmailReentryOtpIssuer.call`, `app/controllers/concerns/enforcement_recovery_ceremony_flow.rb:22-56`)
  or verifies (`params[:pass_code]` present → `verify_recovery_otp`).
- No `CloudflareTurnstile` in either controller, their `Identity::BaseController`s or the concern
  (grep). Throttles: `rate_limit to: 5, within: 1.minute, by: remote_ip` on `create` (shared by send
  and verify; `…/recovery/sessions_controller.rb:17-19` APP and COM), the per-address
  `otp_request_rate_limited?`, timing protection and a dummy path for unknown addresses.
- Sign-in and sign-up sends verify Turnstile first (`auth/app/sign/in/emails_controller.rb`,
  `sign_email_registrable.rb`, `auth/com/sign/up/emails_controller.rb`). ORG has no recovery entry.
- Residual today: with many IPs, an attacker can make the service send recovery codes to many
  registered addresses at the cooldown rate.

**Scope.** APP and COM recovery send branch: verify Turnstile **before** the address is resolved or
anything is sent; failure → the same page with an error and a new challenge (D-73 retryable), no
OTP issued, no cooldown consumed, no timing difference between known and unknown addresses.
Re-verification of an existing ceremony is unchanged. Same concern (`CloudflareTurnstile`) and the
same degradation rule (`TurnstileDegradation`) as sign-in/sign-up; no new fallback.

**Decided (D-156):** visible mode (as WU-04 / sign-up), on the send branch only — the verify branch
is bounded by the OTP attempt budget and the IP limit, like sign-in OTP verify. Added although the
recovery flow as a whole is not finished.
Splitting the send and verify branches into separate actions is not part of this unit.

**Not changed (accepted in the review, recorded here):** OTP resend actions without Turnstile
(`check/{email,telephone}/otps#create`, `web/v0/in/email/otps`) rely on server-side cooldowns
(`email_sign_up_otp_issuer.rb`, `telephone_sign_up_otp_issuer.rb`, `SignInOtpResender`); the cookie
cooldown in `telephones_controller.rb` is a UI aid only. Not read by the review: ORG screens, social
sign-in, `base/*/identity/emails/registrations`.

**Tests:** A40-* (three.md). Docs: `docs/checklists/authentication.md` and the Turnstile coverage
table in `docs/` updated in the same change (G-5).

## 6.10 WU-41 — Effective database timeouts (D-142)

**Fact.** `config/database.yml` sets `lock_timeout: 2s` and `statement_timeout: 15s` as top-level keys
in `default` (and 2 s / 10 s in `test_default`); the PostgreSQL adapter forwards only libpq connection
keys and sets session variables only from `variables:`, so both are ignored. Observed in development
(2026-10-22): `lock_timeout = 0`, `statement_timeout = 0` on primary, `op_base_app`, `app_zenith`.

**Change.** Move both under `variables:` for `default` and `test_default` (keeping the existing
`variables` entries); no code-side default, no ENV switch. Strong Migrations keeps its own
per-migration timeouts; `lib/umaxica/test_environment/database_safety.rb` keeps its `SET LOCAL`.

**Verification (environment construction: evidence only, no Minitest).** Run `SHOW lock_timeout` /
`SHOW statement_timeout` on every configured connection in development and test and record them;
run the full `bin/rails test` and compare with the G-1 baseline; run `RetentionPurgeJob`,
`SignUpExpiryJob` and `ClientSecretLifecycleJob` once in development and record durations. Any new
`ActiveRecord::LockWaitTimeout` / `QueryCanceled` is triaged: a lock-order defect is fixed (as F-1),
a legitimately long statement gets a scoped `SET LOCAL` with a recorded reason. Production values
are recorded after the first deploy.

## 6.11 WU-42 — `redirect_uri` conformance (D-145)

**Source:** H20. Static reading 2026-10-22 of the working tree; nothing run. Requirement labels:
RFC/OIDC keyword where one exists, "spec text" where the specification states behavior without a
BCP 14 keyword, "UMAXICA" for local hardening.

**Conformance (Facts).**

| # | Requirement | Code | Status |
|---|---|---|---|
| C-1 | OP compares `redirect_uri` with the registered values by simple string comparison (RFC 9700 §4.1.3 MUST exact match; RFC 3986 §6.2.1) | `OidcRedirectUriPolicy.valid_redirect_uri?` — `Array#include?` on the registered strings, per realm (`app/policies/oidc_redirect_uri_policy.rb:7-10`), called from `OidcAuthorizeRequestResolver#validate_redirect_uri!` (`app/resolvers/oidc_authorize_request_resolver.rb:101-106`) | Conforms |
| C-2 | `redirect_uri` required in the request (OIDC Core §3.1.2.1 REQUIRED) | `validate_required_params!` (`…resolver.rb:71`) | Conforms |
| C-3 | Invalid/missing/unregistered `redirect_uri` → no redirect to it (RFC 6749 §3.1.2.4 MUST NOT) | Every resolver error is rendered locally as JSON 400 (`base/{app,com,org}/oauth/authorizations_controller.rb` `show` rescues; `OidcAuthorizeCoordinator#call` returns a failure without a URL) | Conforms |
| C-4 | Code bound to `client_id` and `redirect_uri`; token request must carry the identical value (RFC 6749 §4.1.3 MUST; OIDC Core §3.1.3.2) | `OidcTokenExchangeCoordinator#prevalidate_payload` compares `payload["redirect_uri"] == redirect_uri` and `payload["client_id"] == client_id`, then re-checks registration for the code's realm (`app/services/oidc_token_exchange_coordinator.rb:381-391`; same at `:836-839`) | Conforms (error code: N-3) |
| C-5 | RP sends a registered callback and the same value at the token endpoint | `OidcSsoInitiator#oidc_callback_url` picks the registered URI whose host equals the request host; `OidcCallback` sends `redirect_uri: oidc_callback_url` (`oidc_callback.rb:139`) | Conforms |
| C-6 | Registered URIs: no fragment, HTTPS in production (RFC 6749 §3.1.2, §3.1.2.1 SHOULD TLS; RFC 9700 §2.1) | `OidcClientStoresStaticClientStore#build_redirect_uris` builds `"#{protocol}://#{host}#{port}#{path}"`; HTTPS in production or for a public host, `http://…:3000` otherwise (`app/values/oidc_client_stores_static_client_store.rb:137-143`). No explicit registration-time validation step | Conforms by construction; **N-4** (no guard) |
| N-1 | After a valid `client_id` and `redirect_uri`, request errors (`invalid_scope`, missing `state`/`nonce`, PKCE, unsupported `prompt`) are returned to the RP by redirect with `error` and `state` (RFC 6749 §4.1.2.1 spec text; OIDC Core §3.1.2.6) | Rendered locally as JSON 400 (same controllers); only `login_required` is redirected | **Deviation** (interoperability; fail-closed, no security loss). Changing it requires validating `client_id` and `redirect_uri` **before** scope and `prompt` (today scope and the ORG `prompt=create` check run first, `…resolver.rb:48-58`) |
| N-2 | Response built without altering the registered URI (H20 §8) | `OidcAuthorizeCoordinator.rp_redirect_url` parses the URI, drops a default port, decodes and re-encodes the existing query, then appends `code`/`state`/`iss` (`app/services/oidc_authorize_coordinator.rb:40-52`) | No effect today (registered callbacks have no query and production has no explicit port); **latent**: a registered query would be re-encoded, and a registered query key `code`, `state`, `iss` or `error` would collide |
| N-3 | Token-endpoint error code for a `redirect_uri` or client mismatch: `invalid_grant` (RFC 6749 §5.2) | Returns `invalid_request` for both (`…coordinator.rb:384-385`) | **Deviation** (error code only) |
| N-4 | Registration-time validation (H20 §4) | None explicit; correctness comes from the builder | Gap (UMAXICA hardening) |
| U-1 | Jump-forwarded authorize requests keep `redirect_uri` byte-identical | `OidcSsoInitiator#redirect_to_oidc_authorization_url` → `redirect_to_jump_url(url, preserve_query_keys: ["redirect_uri"])` (`common_redirect.rb`); not traced to Edge | **Accepted risk (D-146)**; judged in the Jump integration test. An altered value is refused by C-1, so the failure mode is a refused sign-in |

**Work (TDD, smallest change; PKCE, realm separation, single-use codes and OIDC session handling
unchanged).**
1. N-4: validate every registered `redirect_uri` when the client store is built — absolute URI,
   no fragment, no userinfo, HTTPS in production, no query key among `code`, `state`, `iss`,
   `error`, `error_description`, `session_state`; a violation stops the boot (fail fast). This also
   removes N-2's collision risk.
2. N-2: build the response by appending the encoded response parameters to the registered string
   (with `?` or `&`), without reparsing or re-encoding the registered part.
3. N-3: `invalid_grant` for `redirect_uri` and `client_id` mismatches at the token endpoint.
4. U-1: **not in WU-42** (D-146). Judged in the integration test with Jump (A42-6, run together with
   WU-02g's Jump contract / A02-14 when the Jump change exists).
5. N-1 (D-147): conform — see "Conforming behavior" below.
6. Docs: an ADR recording D-145 (new, or an amendment of the OIDC client registry ADR found during
   WU-39), linked from `adr/README.md`; `docs/checklists/authentication.md` row.

**Conforming behavior (D-147).**

*N-1 — authorization endpoint error handling.* Validation order in `OidcAuthorizeRequestResolver`:
(1) `client_id` present and registered; (2) `redirect_uri` present and registered for that client in
this realm (C-1). A failure in (1) or (2) is shown locally to the person (RFC 6749 §4.1.2.1: MUST NOT
redirect; SHOULD inform the resource owner) — an HTML error page from the OP host rather than JSON,
status 400, no `Location`. Every later check redirects to the validated `redirect_uri` through the
existing error-response path (`OidcAuthorizeCoordinator.error_redirect_url`, same Jump/same-origin
handling as `login_required`):

| Condition | `error` | Source |
|---|---|---|
| `response_type` missing or not `code` | `unsupported_response_type` (missing: `invalid_request`) | RFC 6749 §4.1.2.1 |
| `scope` without `openid` | `invalid_request` (the request is not an OIDC request this OP serves) | OIDC Core §3.1.2.1 |
| scope outside the client's allow list | `invalid_scope` | RFC 6749 §4.1.2.1 |
| `code_challenge` missing, or method not `S256` | `invalid_request` | RFC 7636 §4.4.1; RFC 9700 §2.1.1 |
| `state` or `nonce` missing (UMAXICA requirement) | `invalid_request` (no `state` echoed when it was absent) | local rule |
| unsupported `prompt` value (ORG `create`, `consent`, `select_account`, unknown) or a combination of values | `invalid_request`, **direct HTTP 400 from the OP, not redirected** (D-148, the one exception to this table's redirect rule) | Prompt Create 1.0 §4.1 |
| `prompt=none` without a sufficient session | `login_required` (unchanged) | OIDC Core §3.1.2.6 |
| resource inactive / client not admitted | `access_denied` or `unauthorized_client` as the cause fits; implementer lists each current refusal and its mapping in the change | RFC 6749 §4.1.2.1 |
| backend failure (Valkey, DB) after validation | `temporarily_unavailable` / `server_error` | RFC 6749 §4.1.2.1 |

Every redirected error carries `state` when the request had one and `iss` (RFC 9207); no
`error_description` text reveals stored data. The continuation parameters already refused on this
endpoint (`result_ref`, `transaction_ref`, `switch_handoff`) keep their current handling.

*N-2 — response URL.* `rp_redirect_url` appends `URI.encode_www_form(response_params)` to the
registered string with `?` (no query) or `&` (registered query); no parse-and-reserialize, no port
normalization. The registered query is retained byte for byte (RFC 6749 §3.1.2).

*N-3 — token endpoint.* `redirect_uri` mismatch and `client_id` mismatch → `invalid_grant`, HTTP 400
(RFC 6749 §5.2). Client authentication failures stay `invalid_client`. **Added 2026-10-22, owner-confirmed
(D-147):** a `code_verifier` that does not match the stored challenge → `invalid_grant`
(RFC 7636 §4.6); today `verify_pkce` returns `invalid_request` ("PKCE verification failed",
`oidc_token_exchange_coordinator.rb:482-491`). A missing `code_verifier` stays `invalid_request`.

*N-4 — registration validation.* At client-store build: absolute URI with scheme and host, no
fragment, no userinfo (MUST, RFC 6749 §3.1.2); `https` for every production web RP (RFC 6749
§3.1.2.1, RFC 9700 §2.1); no query key among `code`, `state`, `iss`, `error`, `error_description`,
`error_uri` (UMAXICA hardening). A violation fails the boot.

*N-5 — `prompt_values_supported` and unsupported `prompt` values (decided D-148: proposal items 1–4 with reading (a)).*

Primary source read 2026-10-22: "Initiating User Registration via OpenID Connect 1.0" (status Final,
2 December 2022), https://openid.net/specs/openid-connect-prompt-create-1_0.html.
- §4.2: `prompt_values_supported` is OPTIONAL in general, but "If an OpenID Provider supports this
  specification it MUST define this metadata element"; when present it lists every supported prompt
  value (lowercase "must" in that sentence, not a BCP 14 keyword).
- §4.1: for a prompt value the OP does not support, "the OP SHOULD respond with an HTTP 400 (Bad
  Request) status code and an `error` value of `invalid_request`", with an `error_description`
  RECOMMENDED. Whether this is a direct response or a redirect is not stated.
- §4: combining `create` with other values is NOT RECOMMENDED (not forbidden). §4.1: the OP decides
  whether the flow creates an identity or authenticates an existing one; the RP MUST NOT assume an
  identity was created without a successful response (consistent with D-72 / Sign In First).

Facts: `OidcAuthorizeRequestResolver::SUPPORTED_PROMPTS = %w(login none create)`; only a single value
is accepted (any combination → "prompt is not supported"); ORG refuses `create`
(`…resolver.rb:7-19, 51-54`); `OidcDiscoveryDocument.for_resource_type` has no
`prompt_values_supported` (`app/values/oidc_discovery_document.rb`). APP/COM accept `create` today, so
the §4.2 MUST already applies to them: **this is a current non-conformance**.

Proposal:
1. Discovery: APP and COM `prompt_values_supported: ["none", "login", "create"]`; ORG
   `["none", "login"]` (listing it on ORG is allowed and tells RPs that `create` is absent). Derived
   from the same per-realm table the resolver uses, so the two cannot drift.
2. Unsupported value (`consent`, `select_account`, unknown, ORG `create`): `invalid_request` with an
   `error_description` naming the parameter. Two readings:
   - (a) **direct HTTP 400 from the OP** (literal §4.1; stops at the OP — "when in doubt, stop");
   - (b) redirect to the validated `redirect_uri` with `error=invalid_request` (consistent with N-1 and
     RFC 6749 §4.1.2.1; the RP receives the error).
   Recommendation: (a) for unsupported values, because it is the specific rule for this case and the
   owner's stop-first principle; every other post-validation error follows N-1 (redirect).
3. Combinations of supported values (e.g. `none login`, `login create`): keep refusing them with
   `invalid_request`; OIDC Core §3.1.2.1 requires an error when `none` is combined with anything, and
   §4 of the Prompt Create specification advises against combining `create`. Same delivery as
   item 2's chosen reading.
4. Discovery is the only file change besides the resolver error path; RPs here never send
   `consent`/`select_account`.

*N-6 — `code_challenge` format (D-149, H21 candidate A).* Fact: the resolver checks only presence
(`oidc_authorize_request_resolver.rb:72`); `OidcPkce` validates the verifier (43–128 unreserved) and
S256 at the token endpoint. RFC 7636 §4.2: `code-challenge = 43*128unreserved`; an S256 challenge is
BASE64URL(SHA-256) without padding, i.e. exactly 43 characters of `[A-Za-z0-9_-]`. Change: refuse any
other shape with `invalid_request`, redirected per N-1. Test: A42-13.

## 6.12 WU-43 — OIDC `state` as an ES384 JWS (D-149, H21)

> **Final (2026-10-23):** lifetime and clocks per D-150/D-160 (30 min from `POST /sign`, Rails clock); interruption text per D-160 (4); path exposure accepted per D-162 (backlog concern recorded); A21 retired into A43-18/19/21; the RP `pt` helper is renamed `sign_in_url_with_target`, Auth's `pt` lane untouched. JWT options follow `adr/jwt-validation-and-key-risk-decisions.md` (`verify_expiration`, `verify_not_before`, `verify_iat: { leeway: 30 }`).

> **Implementation follow-up (2026-10-26):** D-162 (3) is implemented: RP callers and definitions use `sign_in_url_with_target`; Auth's signed `pt` lane, route behavior, and `target_link_uri` output remain unchanged. Verification and the RP/Auth inventory are recorded in `evidence/2026-10-26-wu43-rp-helper-rename-N6K2.md`.

Phases 1–3 of H21 (survey, design review, plan); static reading 2026-10-22, nothing run.
Implementation (Phases 4–5) is the implementer's, after X-52 and X-53.

**Survey (Facts).**
- Request parameters today: the RP sends all eight (`OidcSsoInitiator#oidc_authorization_url`); the
  OP requires `response_type=code`, `client_id`, `redirect_uri`, `openid` scope, `code_challenge`,
  `S256`, `state`, `nonce` (`OidcAuthorizeRequestResolver`, lines 67-80). Keyword status: OIDC Core
  §3.1.2.1 REQUIRED for `scope`, `response_type`, `client_id`, `redirect_uri`; `state` RECOMMENDED;
  `nonce` OPTIONAL for the code flow; PKCE: RFC 9700 §2.1.1 MUST for public clients, RECOMMENDED for
  confidential ones — the rest is UMAXICA policy (permitted, D-147 note).
- `state` today: 32 random bytes; pending entry `{code_verifier, nonce, pt, created_at}` keyed by
  `state` in the cookie session, limit 2 (`OIDC_PENDING_FLOW_LIMIT`), TTL 10 min
  (`OidcCallback::OIDC_PENDING_FLOW_TTL`), consumed by deletion (`consume_oidc_pending_flow`).
- Keys: `JitSecurityJwtRegistry.oidc_client(namespace)` holds per-RP ES384 keys (`oidc_client:<ns>`,
  globally unique `kid`s, `validate_global_kid_uniqueness!`). Client assertions:
  `OidcClientAssertionJwt` — header `typ` `oidc-client-assertion+jwt`, `iss`=`sub`=`client_id`, `aud`
  = token endpoint, single-use `jti` in PostgreSQL; the verifier requires that `typ` and `aud`, so a
  JWS with another `typ` and no `sub` is refused there.
- Lifetimes: D-45/D-74 (30 min from Admission issuance on the OP clock) are **decided but not
  implemented** (WU-24c/WU-06); today SignFlow 15 min, OIDC transaction retention 15 min,
  `login_challenge` 10 min, RP pending 10 min. The handoff's "already unified to 30 minutes in the
  latest cycle" is not what the working tree contains.
- CSRF: `ApplicationController` `protect_from_forgery using: :header_or_legacy_token, with:
  :exception`; tests disable it (`config/environments/test.rb:79`,
  `adr/csrf-protection-disabled-in-test-environment.md`). The callback is a GET and needs no
  `skip_forgery_protection`.
- `reset_session`: `AuthenticationBase#bind_committed_login!` (`authentication_base.rb:509`) resets
  the whole session ("Nothing from the pre-login session survives the rotation"). **No mechanism that
  saves and restores the OIDC pending flow around `reset_session` was found** (grep of
  `oidc_pending_flows` outside the initiator/callback: none). The handoff assumes one. On a separate
  RP host the callback consumes the pending entry before the RP session is established, so this is
  fine; on the shared Base host it is exactly TR G1, fixed by the Visa split (WU-02f, A02-7).
- Client ids: 18 registered, all `<family>-<realm>-<scope>` of 11 characters, including
  `core-app-us` (registered; whether a US deployment runs is not visible in code).
- JWT leeway: `AuthenticationJwtConfiguration.leeway_seconds` →
  `SecurityJwtRfc9068AccessTokenProfile::CLOCK_SKEW_LEEWAY_SECONDS`.

**Design review — conflicts and blockers.**
1. **X-52 `return_path` in the JWS.** A JWS is readable; the authorize URL (with `state`) passes the
   browser, Jump, the OP (stored in the authorization transaction, possibly logged) and back. D-145 §7
   says the RP's internal target is not disclosed to OP/Auth/Jump unnecessarily; D-55 says they do not
   manage it; D-137 keeps it in the `state`-keyed pending entry. Options: (a) **no `return_path`
   claim** — the target goes into the cookie pending entry keyed by `jti`, which exists anyway for
   `code_verifier`/`nonce` (recommended: same simplification — `pt` still ends at `POST /sign` — with
   no disclosure and no D-145/D-137 change); (b) `return_path` in the claims, recording a partial
   supersession of D-145 §7 and D-137 (target visible to OP/Jump, integrity-protected); (c) encrypt
   (JWE) — needs an encryption key, contradicting "no new key" (reusing the signing key for ECDH is
   not recommended practice).
2. **X-53 expiry anchoring.** The RP mints `state` at `POST /sign`; the OP curfew starts at Admission
   issuance, later by δ (authorize, Sentry, binding round trip; seconds with Design D). A person who
   finishes at curfew 29:59 reaches the callback at RP time δ + 29:59 + transfer. Proposal:
   `exp = iat + 31 min` (D-149 candidate) **plus** the RP pending entry TTL set to the same 31 min
   (today 10 min — raised in this unit or WU-06), OIDC transaction retention and `login_challenge` ≥
   curfew (WU-06), leeway = the existing `CLOCK_SKEW_LEEWAY_SECONDS` applied to `iat` (future) only,
   not added to `exp` (the RP verifies its own token on synchronized clocks). This replaces 5.6's
   35 min proposal for D-76 if accepted. Risk: δ + transfer > 1 min fails a sign-in that the OP
   accepted (fail closed, the person restarts; D-104 SSO recovery applies if the Root Session exists).
3. Pending entry limit 2 (X-50) also bounds tabs for this design.
4. Not a conflict: CSRF unchanged; `nonce` unchanged; client assertions cannot be confused (distinct
   `typ`, `aud`, required `sub`); key reuse adds no distribution.

**Plan (sub-steps, TDD, one responsibility each).**
- WU-43a `OidcStateJwt` value (`app/values/`): `issue(client_id:, jti:, now:)` and
  `verify(client_id:, token:, now:)` returning a typed result; header `alg` must equal ES384 before
  decode; `JWT.decode(..., true, algorithms: ["ES384"], required_claims: %w(iss aud jti iat exp v))`;
  key looked up only as `JitSecurityJwtRegistry.public_key_for("oidc_client:#{own namespace}", kid)`
  (never a registry-wide `kid` search); `typ` and `aud` checked; `v` = 1.
- WU-43b Initiator: mint `state` with WU-43a; pending entry keyed by `jti`
  (`code_verifier`, `nonce`, target per X-52, `created_at`); TTL per X-53.
- WU-43c Callback: verify `state` (WU-43a) → pending entry for its `jti` in this browser's session
  (absent → refuse: foreign browser) → consume → code exchange (PKCE) → ID Token `nonce` → RP session
  → target once. Order and refusals unchanged otherwise.
- WU-43d CSRF-enabled boundary tests (per the ADR, enabled inside the test only), docs, ADR
  (D-149 in the OIDC client ADR set; supersession notes for D-137 per X-52).
- Rollback: one release reverts to random `state`; in-flight flows of the other format fail closed
  (the person restarts). Old public keys kept ≥ `exp` window + leeway after a rotation.
- Jump: a JWS `state` makes the authorize URL longer (~0.5 KB more); checked in the Jump integration
  test (D-146), Jump itself unchanged.

**Adversarial review (H21 §13), before implementation.**

| # | Question | Answer from the design |
|---|---|---|
| 1 | Valid `state` from another browser | Refused: no pending entry for its `jti` in that browser's cookie session |
| 2 | Forge with another RP's key | Refused: only the RP's own namespace key verifies; global `kid` uniqueness prevents ambiguity |
| 3 | Client assertion accepted as `state` / reverse | Refused both ways: `typ`, `aud`, required claims differ; each verifier checks its own |
| 4 | `kid`/`alg` abuse | `alg` fixed to ES384 in header and verifier; `kid` only within the own key set; `none`/HS/RS/ES256 refused |
| 5 | Session regeneration weakens CSRF | Not touched; pending entry consumed before `reset_session`; Base shared-host case is TR G1 (WU-02f) |
| 6 | Reuse a lapsed authentication via the 31 − 30 min gap | No: the OP refuses after its curfew; `state` validity grants nothing at the OP |
| 7 | Tabs destroy each other's pending flow | Separate `jti` entries; the limit of 2 evicts the oldest (X-50) |
| 8 | Code single use vs cookie replay | Distinct: an old cookie can re-present a consumed pending entry; the OP's single-use code makes the exchange fail, so nothing is issued. Recorded as the limit of cookie storage |
| 9 | Error sent to an attacker URI | No: D-147 N-1 validates `client_id` and `redirect_uri` first |
| 10 | `return_path` in JWS breaks redirect/disclosure policy | Yes under X-52 (b); not under (a) |

**X-53 → D-150.** `exp = iat + 30 min`; RP pending TTL 30 min; leeway only for a future `iat`. The
RP's limit is reached δ seconds before the OP curfew (δ = `POST /sign` → Admission issuance), so the
window is slightly under 30 minutes; a person finishing in that last δ fails closed and restarts.

**X-52 direction (owner, 2026-10-22) and X-52a.** `pt` is abolished on the RP; the target is a
relative path in the `return_path` claim of the JWS `state` (validation as in 6.4 item 2: internal
path only, no dot segments, no double encoding, no `/sign` or `/oidc` paths, per-RP query allow list
— default none, which also limits what becomes readable outside the RP). Consequences to confirm:
the path (and any allowed query) is readable by Jump, Visa/OP and their logs; D-137's carrier and
D-145 §7's non-disclosure wording are partially superseded.

X-52a — the gap the `state` alone does not cover: a protected page redirects to `GET /sign`, and the
OIDC request starts only at the person's `POST /sign` (D-103). Without `pt`, the target must cross
that page. Options:
- (A) **Pre-minted entry token, re-minted at `POST /sign` (recommended).** The protected page mints a
  JWS of the same value type with `return_path` and a short dwell lifetime (proposal 15 min), puts it
  in `GET /sign?state=…` (or another name), the page keeps it as a hidden field; `POST /sign` verifies
  it and mints the real OIDC `state` (new `jti`, `iat` = now, same `return_path`). The 30-minute
  window then starts at `POST /sign`, so time on the `/sign` page does not eat it. A distinct `aud`
  (or `typ`) separates the entry token from the OIDC `state`, so one cannot be used as the other.
- (B) Pre-minted and used unchanged as the OIDC `state`: simplest, but the dwell time counts against
  the 30 minutes.
- (C) A Rails-session slot: rejected earlier (tabs overwrite each other, D-137).
An explicit Sign in on an RP page (no protected page) mints the OIDC `state` at `POST /sign` with the
RP's default `return_path`.

**X-52 / X-52a — OIDC-aligned carriage (2026-10-22, proposal after the owner asked for the
standard pattern).** Primary sources read:
- OIDC Core 1.0 §4 (Initiating Login from a Third Party): the RP's login initiation endpoint takes
  parameters "as query parameters using the HTTP GET method" or as "HTML form values that are
  auto-submitted in the User Agent" (POST); `target_link_uri` is "OPTIONAL. URL that the RP is
  requested to redirect to after authentication", and "RPs MUST verify the value of the
  target_link_uri to prevent being used as an open redirector to external sites". (§4 also makes
  `iss` REQUIRED because it is written for third-party initiation; UMAXICA's own entry borrows the
  parameter convention, it is not a third-party initiation.)
- draft-bradley-oauth-jwt-encoded-state-09 (expired Internet-Draft, 2018, Experimental — prior art,
  not a standard): a JWT `state` with `target_link_uri` ("location the user agent is to be redirected
  to after authorization"), `rfp` (REQUIRED, a verifiable browser-session identifier; for stateful
  clients "a random value stored in the server-side session"), `jti`, `iat`, `exp`, `aud`, `iss`,
  `kid`; the AS treats `state` as opaque.

Proposal (D) replacing `pt` with the standard names:
1. A protected page redirects to `GET /sign?target_link_uri=<relative path>`; the `/sign` page keeps
   it as a hidden form field; `POST /sign` receives it (OIDC Core §4's GET/POST forms). The RP
   verifies it on both requests (MUST): relative path on the RP's own host only, the 6.4 item 2 rules.
2. `POST /sign` mints the OIDC `state` JWS with claim `target_link_uri` (the draft's name, replacing
   `return_path`) and `jti`; the cookie pending entry keyed by `jti` is the draft's stateful `rfp`
   (binding to this browser). `iat` at `POST /sign` starts the 30 minutes (D-150), so time on the
   `/sign` page does not count. No separate entry token is needed: `target_link_uri` on `GET /sign`
   is a plain, verified relative path, not authority — anyone can only ask the RP to return to one of
   its own internal pages after a sign-in the person performs.
3. Callback: verify `state`, consume the entry, exchange the code, then redirect once to the verified
   `target_link_uri`.
This makes options (A)/(B) above unnecessary.

**Why the query restriction was proposed (answer to the owner).** A readable path is not a problem
in itself. The concern is only the query: real-world queries sometimes carry search words, email
addresses, ids, one-time codes or tokens, and once inside `state` they are copied into the authorize
URL, Jump and OP request logs, the OP's stored transaction and the browser history. D-55 already
refuses "queries carrying secrets", and the existing resolver refuses redirect-like keys
(`redirect_uri`, `return_to`, `redirect_to`, `next`, `continue`, `url`). Choice for the owner:
(i) allow any query except those keys and secret-looking ones (simplest, current D-55 wording);
(ii) a per-RP allow list (strictest). Without a query nothing is lost for pages like `/dashboard`;
search or list pages would come back without their filters.

**Decided (D-151).** Proposal (D) with `target_link_uri` path only (no query, no fragment). Plan
addition: **WU-43e** — protected pages (`BrowserRpAuthentication`, Inertia 409 +
`X-Inertia-Location`) build `GET /sign?target_link_uri=<request.path>`; `/sign` page hidden field;
`POST /sign` verification; remove `encoded_pt`/`decode_pt`, `sign_in_url_with_pt` on the RP side and
the `pt` key of the pending entry (no compatibility alias). Auth/Base's own signed `pt`
(`AuthenticationRedirects`) is a separate Auth-internal lane and is not part of this change. Sequence:
WU-43a → b → e → c → d.

**D-152 and X-54 — where Cancel lands (survey 2026-10-22).** Facts: the RP callback today verifies
`state`/`iss` and renders a generic failure on any `error` (`oidc_callback.rb:35`); the
`tech-org-ww` `render_oidc_access_denied!` is for a token-exchange `access_denied` (capability
refusal), **not** for Cancel — the earlier note "only tech-org-ww handles access_denied" meant that
path. After a successful sign-in, Base and Warp send `/` to their dashboard (`consume_oidc_pt`
overrides); the others use `/`. Every RP root (`roots#index`) is reachable without sign-in: Base and
Warp render the anonymous landing (and a 404 boundary when already signed in), Core, Edit and Palm
render a landing page, Tech renders its root view; the dashboards require sign-in.

Proposal for X-54: land on the RP's own root, keeping the region.

| RP (client ids) | Landing after Cancel | Note |
|---|---|---|
| Base `base-{app,com,org}-ww` | `base_{app,com,org}_root_path(ri:)` → `GET /` | Anonymous landing; the dashboard would bounce back to `/sign` |
| Warp `warp-{app,com,org}-{jp,us}` | `warp_{app,com,org}_root_path(ri:)` | Same |
| Core `core-{app,com,org}-{jp,us}` | `core_{app,com,org}_root_path(ri:)` | Landing page |
| Edit `edit-org-ww` | `edit_org_root_path(ri:)` | Root view |
| Palm `palm-app-jp` | `palm_app_root_path(ri:)` | Landing page |
| Tech `tech-org-ww` | `tech_org_root_path(ri:)` | Root view |

Alternative: the RP's `GET /sign` page (the person can retry or leave). Recommendation: the root —
it is D-109's "top page", needs no sign-in, and does not invite an immediate retry loop. Route helper
names above follow the surface naming and are to be confirmed against `bin/rails routes` by the
implementer.

**Decided D-153 (replaces the root proposal above).** Landing: `GET /sign/interruption` on every RP
(Base app/com/org, Warp, Core, Edit, Palm, Tech), `resource :interruption, only: :show` inside the
existing `scope path: "sign", as: :sign` (helper names `<surface>_sign_interruption_path`, confirmed
against `bin/rails routes` by the implementer). Plan addition **WU-43f**: the route and controller
per RP (authentication mode open, no session or DB write, `Cache-Control: no-store`, no automatic
redirect, no branching on sign-in state), one shared page component (DESIGN.md; translation keys per
`docs/architecture/i18n.md`, language bundles per D-113), and the callback change: every case listed
in D-153 → consume the pending entry, log one reason-coded event, 303 to the page. Sequence:
WU-43a → b → e → f → c → d.

**Implementation constraints recorded 2026-10-22 (owner: reflect).**
- **Base RPs after WU-02f.** While Base shares its host with the OP, the sign-in commit's
  `reset_session` (`AuthenticationBase#bind_committed_login!`) wipes the cookie pending entry that the
  JWS `state` needs (TR G1). WU-43 is applied to `base-{app,com,org}-ww` only after the Visa split
  (WU-02f, A02-7); the other RPs are on separate hosts and can go first.
- **30 minutes is effective only after WU-06.** WU-43 sets the RP side to 30 min (D-150), but the OP
  still caps the flow at the authorization transaction retention (15 min) and `login_challenge`
  (10 min) until WU-06 aligns them with the curfew. Until then the effective window is the shorter OP
  bound — fail-closed, and recorded as such in WU-43's evidence; "30 minutes" is claimed only after
  WU-06.
- **Key rotation.** Old RP public keys stay verifiable for ≥ 30 min + `CLOCK_SKEW_LEEWAY_SECONDS`
  after a rotation (A43-7); runbook item in WU-39.

**D-154 (2026-10-22).** The pending entry stays in the RP cookie session; the Valkey proposal is not
adopted. WU-43 keeps the cookie design; its evidence states the accepted limits (old-cookie replay
neutralized only by the OP's single-use code, size-bounded entry count per X-50, Base host until
WU-02f).

**D-155 (2026-10-22) — one sign-in at a time.** `OIDC_PENDING_FLOW_LIMIT` becomes 1 (the pending map
holds one entry; `POST /sign` replaces it). No early cancellation of the earlier tab and no OP
change. The callback refuses a `state` whose `jti` is not the current entry, or whose entry is
already consumed, and lands on `/sign/interruption` (D-153). A comment at the limit constant states
why (D-155) so it is not "fixed" later; the docs item is in WU-39.

## 6.14 Stop vs issuance lock inventory (D-166, statically reconciled 2026-10-25)

Static lock-order review, reconciled against the current implementation on 2026-10-25; no concurrent
execution was performed for this inventory. "Actor" = the principal row on its Zenith writer; OP
rows are in `op_base_{app,com,org}`.

| Path | Code | Locks, in order | Epoch read/write | Notes |
|---|---|---|---|---|
| Root issuance (`log_in`) | `authentication_base.rb:321` → `with_actor_session_lock` (l.412) → `commit_login_session!` (l.540) → `create_login_token_record` (l.2433, insert l.2474) | actor `lock!` (Zenith tx) → sign-in Flow `with_cycle_lock` (OP) → token tx (OP, `requires_new`) | writes `resource.authentication_epoch` read after `lock!` | **Gap:** eligibility checked only before the lock (l.332-333) → D-163 |
| Token exchange (code → grant) | `oidc_token_exchange_coordinator.rb:1143` `lock_actor_and_root` | actor `with_lock` → Device Session → root → RP session | `root_current?` under the actor lock | Does not check `active?` (refresh does); D-165 |
| Refresh rotation | `oidc_refresh_token_issuer.rb:113` with `refresh_actor_guard` (`oidc_token_exchange_coordinator.rb:296`) | actor `with_lock` → Device Session → root → RP session (`RpSession#with_parent_and_self_lock`, `rp_session.rb:236`) | `active?` + `root_current?` under the actor lock | — |
| Refresh reuse | same transaction, `handle_refresh_token_reuse` (l.444) | as refresh | none | Revokes that RP session (grant) only; Root kept (D-25). No epoch update (D-164) |
| Token revocation | `oidc_token_revoker.rb:41` → `RpSessionRevoker` scope `:rp_session` (`rp_session_revoker.rb:44`) | Device Session → root → RP session (`revoke!`) | none | No actor lock |
| Browser sign-out (direct and RP-Initiated confirmation) | `AuthenticationLogoutCurrentSession#call` → `OpAuthorityStopCommitter.stop_root` | Stop idempotency lock → Device Session → root → grants → stop targets / participants / browser receipt | none | No actor lock. Re-checks caller precondition under the Device lock. RP request stages confirmation only; the CSRF-protected confirmation POST uses this same root-stop path. |
| Revoke others / credential change | `AuthenticationOtherSessionsRevoker` (`authentication_other_sessions_revoker.rb:25`) → per session `AuthenticationSelectedSessionRevoker` | per session: Device Session → root → RP sessions; one transaction each | none | Point-in-time snapshot (`find_each`); a root created concurrently survives (open item O-2) |
| Identity Stop (record) | `IdentityAuthenticationStopRecorder` inside the caller's actor tx (`administrative_access_lock.rb:32`, `withdrawal_lifecycle.rb:77`, `org_operator_lifecycle_execute.rb:151`) | actor `lock!` (Zenith) only | epoch +1 with the status change | — |
| Identity Stop (apply) | `OpIdentityEventInvalidator.call` (`op_identity_event_invalidator.rb:40`) | inbound receipt row (OP) → per stale root `AuthenticationLogoutCurrentSession` (Device → root → RP) | reads `cutoff_epoch` | Runs after the Zenith commit, no actor lock; revokes `epoch < cutoff` only |

**Conclusions.**
1. Inside one OP database every path uses Device Session → root → children (RP grant). The
   authority-stop idempotency lock is acquired before that chain; no legacy logout-flow row remains
   in the stop path. No OP-internal wait cycle was found by this static review.
2. Across databases, only issuance paths and the stop recorder lock the actor, always actor → OP.
   No path found that holds an OP lock and then waits for the actor **in these paths**. The Sign-up
   → Sign In First handoff and session-limit resolution were traced under O-3 below; neither adds an
   OP-to-actor wait. WU-16's stop order is therefore consistent with the reviewed paths. Bootstrap
   (WU-28) and Emergency Access remain outside this inventory.
3. Single-root, single-grant and refresh-reuse stops serialize with issuance on the Device Session
   / root rows they share; they need no actor lock and no epoch update (D-164).
4. Account-wide stops serialize with issuance only through the actor lock + epoch (Identity Stop);
   D-163 closes the "checked before the lock" gap. `revoke_others` has neither (O-2).
5. Every authentication boundary must read the epoch from the writer (D-165); today
   `OidcAccessTokenAuthenticator#find_resource` uses `:reading`.

**Owner answers (2026-10-23).**
- O-1 → `root_epoch == actor_epoch` (D-165).
- O-2 → credential-change revocation serializes on the principal lock and re-checks the credential
  under it; plain revoke-others stays point-in-time (D-167). Implemented in WU-44 step 4.
- O-3 → traced (static, 2026-10-23), no wait cycle found:
  - Sign-up Finalization → Sign In First handoff (`sign_up_sequence_controller_support.rb:224`
    `@sign_up_ticket.with_cycle_lock` → `finalize_*_sign_up_actor!` `actor.with_lock` (l.494, l.531)
    → `handoff_to_sign_in_flow!` (l.595) → `establish_signed_in_session!`
    (`authentication_base.rb:2859`), which creates a **new** sign-in Flow and records evidence; no
    `log_in` and no Root in that request on the OIDC path (the Root is issued later at the OP result
    receipt). Order: sign-up Flow (OP) → actor (Zenith) → new sign-in Flow (OP); consistent with
    F-1 (Flow before principal). The local path that called `log_in` here is removed by WU-01.
  - Session-limit resolution (`authentication_base.rb:599-622`): inside `with_actor_session_lock` →
    sign-in Flow `with_cycle_lock` → resolution row `lock!`
    (`session_limit_resolution_transactionable.rb:327`). Order: actor → sign-in Flow → resolution.
    Removing the chosen sessions happens in a separate request through the Device → root order.
  - No path holds a sign-in Flow, a resolution row or a Device/root row and then waits for the
    actor. Not covered: Bootstrap (WU-28, rebuilt) and Emergency Access.

## WU-44 — Root issuance re-check and authoritative epoch (D-163, D-165)

> **2026-10-26: split** (`one.md` D-187): remaining acceptance tests this cycle (`tmp/wu44-remaining-acceptance.md`); A44-9 to backlog. Text below kept as history.

Independent of WU-16; can start after R4-1 is recorded Red. Implementer effort: medium or higher.

1. Red first: A44-1 (concurrent stop during `log_in`), A44-3 (restore after stop with an old
   Access JWT; the existing backlog reproduction made durable).
2. D-163: inside `with_actor_session_lock`, after `resource.lock!`, re-check every Root-issuance
   condition with the reloaded record; refusal returns the same statuses as the early check
   (`:access_locked`, `:login_forbidden`, unfinished registration) and issues nothing. Add a static
   guard that `token_class.create!` for root tokens appears only in `create_login_token_record`.
3. D-165: every boundary in the 6.14 table that authenticates or re-issues from a root compares the
   root epoch with the actor epoch read on the Zenith **writer**; read failure → fail closed
   (dependency failure, D-73). The rule is `root_epoch == actor_epoch` (D-165, O-1); the legacy
   `nil` branch is removed together with WU-17's NOT NULL.
4. D-167: `CredentialSecurityTransition` and `IdentityCredentialRemovalCommitter` take the
   principal row lock (actor → OP, same order as issuance) around the credential change and the
   revocation of other roots; D-163's re-check under the lock in `log_in` re-validates the
   credential state, so an in-flight login with the old credential is refused or revoked. Plain
   revoke-others is unchanged.
5. Exit: A44-* green; `docs/security/` session and token pages, `docs/mermaid` identity-stop axis
   updated; the backlog entry `2026-10-22-pre-stop-jwt-accepted-after-operator-restore.md` closed
   or narrowed with the remaining scope.

## 6.13 Database reset (D-159) — effects on the units

The owner rebuilds every environment from scratch — development, test, staging and production. Schema changes stay Rails migrations; data
handling disappears. Where an earlier section of this file prescribes data work, this section wins.

| Unit | What is dropped | What remains |
|---|---|---|
| WU-24 | 24a (classification queries, cross-DB matrix), 24f (settling existing Flows), backups, A24-5a/b/c approvals, `curfew_at`/`entry_intent` backfills | 24b resolver; 24c `curfew_at` NOT NULL directly; 24d `entry_intent` NOT NULL + purpose CHECK directly (D-157 value set); 24e cleanup repair (still needed for future data); 24g retire `local_sign_up_flow_ref` (schema only); 24h `auth_admission_binding_id` NOT NULL + FK + partial UNIQUE directly, creation sites bind the Binding. New order: 24b → 24c → 24d → 24e → 24g → 24h |
| WU-17 | NULL → 0 bulk update and its approval | `authentication_epoch` NOT NULL, column/table drops as migrations |
| WU-18f | Row counts and recovery plan | Table drops as migrations |
| WU-30 | Mapping of existing values, row counts, approval | `security_mode_id` with `NORMAL=3`/`ADVANCED=7` only; seeds create APP/COM `NORMAL`, ORG `ADVANCED` |
| WU-34 | Migration of existing COM Visitors | New `VisitorStatus` values and the refusal predicate |
| WU-10 | Approval for dropping `rp_refresh_attempts` | The drop as a migration |
| WU-16/22 | Migrating `logout_flows` | Replace with the new tables (D-158 P-142) |
| WU-36 | Legacy Domain-cookie handling (already none, D-158) | — |
| WU-26 | — (still useful: diagnoses partial registrations created after the reset) | Unchanged |
| D-125 ② | Deleting unbound Flows | — (no rows) |

Every migration still runs on the empty development and test databases and passes
`bin/rails db:verify_no_schema_drift`.

