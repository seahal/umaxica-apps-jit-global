# Authentication Architecture Investigation History

> Archived snapshot, generation 0001 (originally `zero.md`). Non-normative and not evidence; see
> [README](./README.md).

## 2026-10-18 — RP database separation and successful authentication paths

### Scope and provenance

- Requested: read-only architecture investigation of App, Com and Org sign-in/sign-up, RP/OP/Auth
  database ownership, Jump, entry cancellation, mode links and Org registration guidance.
- Checkout: `/home/global/workspace`; branch `feature`; HEAD
  `17903f7d121aa33efe29f2db9235c9aa5db4b001`.
- Initial `git status --short`: 1,613 entries, including staged, unstaged and untracked work.
  Findings describe those checkout files, including uncommitted implementation; HEAD alone does not
  reproduce them. Existing work was preserved. This history file is the only authored change.
- Primary evidence: local controllers, concerns, models, operations, adapters, routes, SQL dumps,
  database configuration, accepted ADRs and test source. Remote GitHub repository landing pages were
  inspected read-only; remote main was not treated as the implementation authority.
- No Rails boot, tests, migrations, DB queries, DB mutations, production requests, activation,
  deployment, branch changes or external writes were performed. Existing evidence files describe
  earlier sessions; their test results are not claimed as this session's results.
- The Japanese report is delivered in the conversation. This repository history is English under the
  repository language policy. No credentials, token values or cookie values are retained here.

### 1. Overall assessment

Separation is partially implemented, not demonstrated as completed or activated. Twelve JP/worldwide
RP cell stores, fixed model connections, local callback/session handling and role admission gates
exist. The shared transitional role still serves all surfaces and uses the OP-chain RP path.
`rp_callback_states` exists but the current shared OIDC initiator/callback uses encrypted Rails
CookieStore pending state instead. Entry Cancel is text only on App sign-in/sign-up. Mode links
perform GET navigation without coordinated flow/ceremony termination.

### 2. Database separation

- `config/database.yml:50`: twelve `rp_*` connection definitions; `:266` development expansion.
- `app/values/rp_cell_binding.rb:9`: fixed client/realm/region/record-prefix mapping.
- `app/models/rp_base_app_record.rb:8`: explicit writer/reader connections; analogous classes exist
  for Base/Core/Warp App/Com/Org, Palm App, Edit Org and Tech Org.
- `lib/runtime_role.rb:14`: shared role retained until WU19; `:58` database allowlists; `:112`
  closed/open cell admission; `:182` route ownership.
- `app/controllers/concerns/rp_cell_local_session.rb:28`: local path requires an RP runtime role.
- `app/controllers/concerns/oidc_sso_initiator.rb:119` and `oidc_callback.rb:401`: pending
  state/verifier/nonce/pt in Rails session, not cell CallbackState rows.
- `config/initializers/session_store.rb:12`: CookieStore. `rp_*_callback_state.rb` has validations
  but no application issuance/consumption caller was found by source search.
- `app/models/client_auth_ceremony_session.rb:4`, `client_sign_in_flow.rb:44`,
  `client_sign_up_flow.rb:59`, `client_oidc_authorization_transaction.rb:47`: same-realm OP store.
  Visitor/Operator equivalents use Com/Org OP stores.
- Canonical Client/Visitor/Operator and credentials use semantic PrincipalRecord classes that
  inherit the matching ZenithRecord; physical ownership is `*_zenith`, not `rp_*`.
- OP grants remain OP-owned (`app/models/op_app_grant.rb:4`); local RP sessions are separate rows.
- Earlier status record `evidence/2026-10-17-r5-wu19-wu20-source-and-status-W19S.md:24` says actual
  common cutover/activation and final acceptance were NOT_RUN and legacy removal NOT_DONE. This
  session did not independently query deployment or activation state.

### 3. Successful sign-in path reconstructed from source

1. Passive RP GET `/sign`; CSRF-protected POST starts the flow (`oidc_rp_sign_entry.rb:11`).
2. Initiator generates random state, verifier and nonce, derives S256 and retains safe local pt
   under state (`oidc_sso_initiator.rb:42`). It sends no pt to the OP authorize endpoint.
3. Base validates the request and admission; an adequate existing root can issue a Code directly.
   Otherwise GET renders a local POST form, then POST creates the authorization transaction and
   admission (`base/app/oauth/authorizations_controller.rb:18`, `:113`;
   `oidc_authorization_result_post.rb:72`). First-party intent is `authentication` (`:253`).
4. Base-to-Auth start uses Jump. Auth attaches its continuity row, Base confirms the original
   browser by its own POST, Auth redeems by its own POST and rotates the ceremony SID
   (`auth/app/ceremony_bindings_controller.rb:15`, `base_ceremony_binding_confirmation.rb:27`,
   `auth_ceremony_admission.rb:63`). Those confirmation return redirects are direct cross-host 303s.
5. App offers email/passkey/Secret/Google/Apple; Com email/passkey; Org Entra plus a separate
   Emergency entry (`auth/{app,com,org}/sign/ins_controller.rb`). SMS is registration, not a listed
   ordinary sign-in method.
6. Auth records credential evidence and advances applicable sign-in participants; it does not
   establish an ordinary root (`authentication_base.rb:2935`, `:3011`). Auth local handoff POST
   registers the result and completes the ceremony, then directly redirects to Base result lookup
   (`auth_oidc_result_handoff.rb:26`). Its header comment describes an older form transport.
7. Base's result-local POST validates browser binding/generation, finalizes root login through
   `log_in(establishment: :root_login)`, then issues the Code. Valkey Code TTL is ten seconds
   (`valkey/auth_state/authorization_code_store.rb:11`).
8. RP callback consumes matching pending state (ten-minute TTL), checks response issuer, exchanges
   Code/PKCE using client assertion, verifies ID Token/nonce/auth_time. RP role commits a local
   Principal/IdentityBinding/OpSessionBinding/Session; shared role uses canonical actor/OP-chain
   provisioning (`oidc_callback.rb:24`, `:206`; `rp_callback_committer.rb:46`).
9. RP returns directly to its own retained pt (`oidc_callback.rb:284`). Base self-RP authorization
   start and callback stay same-origin; other ordinary RPs use Jump, with existing Edit/Tech start
   exceptions (`oidc_sso_initiator.rb:87`, `base/app/sign/entries_controller.rb:20`).

Org Normal sign-in resolves an existing active Entra identity by tenant/object ID, never JIT
provisioning (`external_sign_in/org_entra_resolver.rb:27`). Entra success creates a ten-minute
CookieStore pending transaction, then requires that Operator's passkey or existing Secret second
stage (`org_normal_sign_in_transaction.rb:35`). Emergency uses a distinct challenge purpose and
eligibility policy and records `standby` (`sign_org_standby_passkey_ceremony.rb:64`, `:112`). The
RP-initiated OIDC result carries method/time but no context; Base Org OIDC issuance explicitly
passes NORMAL (`base/org/oauth/authorizations_controller.rb:209`). This is a material source-level
contract mismatch requiring a dedicated end-to-end check. Existing Emergency finalization test uses
local admission and `/sign/handoff`, not this OIDC path
(`test/controllers/auth/org/in/emergency/passkeys_controller_test.rb:41`, `:141`).

### 4. Sign-up

- App and Com: email -> OTP -> birthdate; telephone -> SMS OTP -> passkey -> birthdate. App
  telephone additionally routes through Secret issuance/confirmation after passkey before completing
  the passkey requirement (`sign_up_requirement_registry.rb:12`,
  `auth/app/sign/up/check/telephone/passkeys_controller.rb:50`).
- App social: POST Google/Apple registration, provider callback, confirmation and birthdate.
  Existing provider identity/account can resolve as sign-in; Com has no social registration.
- Contact POST creates candidates and flow/delivery bindings; GET method selection is not durable
  registration. Finalization checks policy/version/requirements under the flow lock, finalizes
  actor/contact and identity graph, completes SignUpFlow and enters ordinary sign-in evidence
  (`sign_up_sequence_controller_support.rb:194`, `:595`). Durable account completion and root
  session issuance are different boundaries.
- Org static page has recruitment/contact guidance, not self-service registration. Helper uses an
  accepted configured URL or Base Com root (`auth/org/sign_ups_helper.rb:13`). Invitation acceptance
  is separate; it consumes an invitation and provisions an Operator/email/account, then redirects to
  Auth sign-in without creating a session (`auth/org/sign/up/invitations_controller.rb:23`,
  `org_operator_lifecycle_invitation_acceptance.rb:18`). That bare redirect supplies no new
  admission, so automatic continuation to a usable sign-in entry is unproven.

### 5. pt, rt and consistency

- RP pt is a validated same-host path held in CookieStore; it is not an OIDC authorization input.
  Auth's signed pt helper is a separate local navigation contract
  (`authentication_redirects.rb:242`). Switching pages may omit that local value without removing
  the initiating RP's retained pt.
- Jump rt is a short-lived signed navigation token, not OIDC state or a session credential. Issuer
  strips pt/rt and other nested redirect keys; registered OIDC redirect_uri is explicitly preserved
  (`jump_rt_issuer.rb:20`, `:104`; `common_redirect.rb:111`).
- Jump return verifies issuer/audience/source/exact URL, then removes rt via local 303 before the
  business action (`jump_rt_return_verification.rb:15`). External Jump traversal and Edge deployment
  were not executed or independently verified.
- Local atomicity: admission+parent/rotation locks in OP DB; Base result generation/finalization and
  grant redemption in OP DB; local callback lock/tombstone in RP DB. Valkey is bounded transport.
  There is no distributed atomic transaction across OP, Zenith, RP, avatar or queue stores.
  Registration uses owner-specific operations/retained cleanup and some compensations; complete
  recovery coverage was not established by this investigation.

### 6. Entry Cancel

- `src/features/auth/signin/SignInMethodChoice.tsx:72` and
  `src/features/auth/signup/SignUpMethodChoice.tsx:111` render a paragraph only.
- Entry routes expose show/create, not entry cancellation (`config/routes/auth.rb:57`).
- Reusable: `AuthCeremonySession#cancel!`, flow cancellation/termination and cleanup, browser-bound
  Base confirmation, same-origin return validation, OIDC error response URL builder and Jump.
- Missing: entry-only phase assertion, correlated child ownership, coordinated terminalization, OIDC
  cancellation lifecycle, Base cancellation receiver and RP callback return-on-cancel.
  `OidcAuthorizationTransactionable` allows pending/authenticated/consumed only (`:7`). Existing
  verification cancellation is Step-Up/registration-ticket-specific, not ordinary OIDC auth.
- Individual OTP/registration steps already have DELETE cancellation; these end their own flow and
  restart registration (`sign_up_explicit_step_controller_support.rb:97`). They do not supply the
  requested entry-to-RP cancellation contract.

### 7. Sign-in/sign-up links

- Entry links perform GET only; no explicit current-flow cancellation or new admission issuance.
- First-party `authentication` intent allows both entry pages. Current ceremony context also accepts
  all ordinary authentication intents for either entry (`auth_ceremony_context.rb:197`), while
  initial admission checks are stricter (`auth_ceremony_admission.rb:313`).
- Auth SID and OP authorization transaction remain in use. A new signup flow is created later by
  method submission/provider start; contact restart can HALT an earlier signup flow
  (`sign_up_flow_entry.rb:28`). Page switching itself does not guarantee old ceremony invalidation.
- Links do not consistently carry local pt/region/flow binding, so late/back navigation can be
  refused by phase binding even though the entry link itself was rendered.

### 8. Org registration link

- Org suppresses registration whenever `@oidc_authorization_intent` is present
  (`auth/org/sign/ins_controller.rb:69`). First-party `authentication` is also present, so it is
  hidden independently of `ri=jp`. Entry admission sets this variable from the OP transaction.
- Reciprocal Org sign-in link has the same suppression (`auth/org/sign/ups_controller.rb:48`).
- Tests explicitly assert hidden registration/sign-in links
  (`test/controllers/auth/org/sign_ins_controller_test.rb:1271`,
  `test/controllers/auth/org/sign_ups_controller_test.rb:265`).
- Future static-guide visibility need not grant self-registration or change OP intent. It must
  retain or deliberately terminate the original admission, define Com navigation/return behavior,
  preserve intent checks for mutation endpoints and update those exact expectations.

### 9. Uncertainty and follow-up priority

1. Verify/fix Org OIDC Emergency context preservation before claiming Restricted Mode end-to-end.
2. Complete isolated R5 readiness, CallbackState ownership and actual approved activation gates; do
   not infer cutover from schemas or test source. US runtime is not established.
3. Define entry cancellation as a browser-bound, idempotent OP transaction termination and RP return
   contract, including races with success and protection of completed accounts/sessions.
4. Define switching lifecycle separately, including existing flows and late requests; reconcile
   initial-admission versus continuing-ceremony intent matching and missing flow bindings.
5. Expose Org static guidance deliberately; retain privileged invitation boundaries and define the
   Com exit without transferring Org authentication authority.
6. Reconcile stale docs/comments and verify complete App/Com/Org journeys under actual isolated
   roles, Jump, provider/sender dependencies and writer/replica behavior in an authorized cycle.

### Verification limits

Read-only source search and line-numbered inspection were performed. Test source establishes
intended assertions only. The cell readiness helper directly enrolls decoded ID Token payloads and
stubs assertion authentication (`test/support/rp_cell_session_helper.rb:24`); it is not proof of a
complete isolated HTTP callback/browser journey. No test result or operational success is asserted.
