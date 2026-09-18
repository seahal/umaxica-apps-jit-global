# App Rails Route and Authentication Audit

Date: 2026-09-12

## Scope and method

This report covers only the Rails `app` realm of Core, Auth, Base, and Side. It does not inspect or
change the separate Edge repository, and it does not treat the parallel `com` and `org` realms as
implementation targets.

The inventory is based on `config/routes.rb`, the four drawn route files, `bin/rails routes`, route
recognition, controller pipelines, OIDC services and concerns, request/integration tests, host
configuration, and accepted architecture records.

## Host boundaries

The URL path does not identify a surface. Rails selects each surface through a `constraints host:`
block:

| Surface | App host source | Trust role |
| --- | --- | --- |
| Core/App | `boot_config.hosts.core_service.host`, `PRIVATE_CORE_SERVICE_URL` | Browser BFF and RP |
| Auth/App | `boot_config.hosts.auth_service.host`, `PUBLIC_AUTH_SERVICE_URL`, `auth.app.localhost` | Credential ceremony gateway and RP |
| Base/App | `boot_config.hosts.base_service.host`, `PRIVATE_BASE_SERVICE_URL`, `www.app.localhost` | Acme authorization/session authority and Base UI |
| Side/App | `boot_config.hosts.side_service.host`, `PRIVATE_SIDE_SERVICE_URL` | Rails control-plane RP |

Evidence: `config/routes/{core,auth,base,side}.rb`; `lib/config_values_host_family_values.rb`;
`bin/rails routes --expanded`.

## Browser navigation and authentication route inventory

This table lists the routes that form the app browser authentication boundary or determine which
application owns presentation. Operational health, revision, robots, sitemap, CSP-report, MCP, and
unrelated domain CRUD routes were inspected but are outside this authentication inventory.

| Method | Path | Route helper | Rails owner | Surface | Authentication | Mutation | Caller | Redirect target | SSO | Current status | Proposed action | Evidence |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| GET | `/` | `core_app_root` | `core/app/roots#index` | Core/App | public | creates anonymous preference state when needed | browser | none | no | intentionally transitional while Edge split is not deployed | keep and contract-test | `config/routes/core.rb:15`; Core root tests; Edge contract deployment-status section |
| GET | `/oidc/authorization` | `core_app_oidc_authorization` | `core/app/oidc/authorizations#show` | Core/App | public | no durable mutation; stages OIDC session state | browser | Base `/oauth/authorize` | yes | working | keep | runtime routes; `OidcSsoInitiator`; Core sign-out/browser-flow tests |
| GET | `/oidc/callback` | `core_app_oidc_callback` | `core/app/oidc/callbacks#show` | Core/App | public/conditional protocol callback | establishes RP session | browser | validated local `pt` | yes | working | keep | `OidcCallback`; OIDC callback and browser-flow tests |
| POST | `/oidc/backchannel/logout` | `core_app_oidc_backchannel_logout` | `core/app/oidc/backchannel/logouts#create` | Core/App | signed logout token | yes | internal IdP | no browser redirect | yes | working | keep | `config/routes/core.rb`; RP logout receiver tests |
| GET | `/api/v0/session` | `core_app_api_v0_session` | `core/app/api/v0/sessions#show` | Core/App | conditional cookie authentication | no | Edge/browser | none; JSON | no | working canonical Edge endpoint | keep and contract-test ownership | controller, OpenAPI contract tests |
| POST | `/api/v0/token/refresh` | `core_app_api_v0_token_refresh` | `core/app/api/v0/token/refreshes#create` | Core/App | refresh cookie plus CSRF | yes | Edge/browser | none; 204 | no | working canonical Edge endpoint | keep and contract-test ownership | controller, OpenAPI contract tests |
| GET/PATCH | `/api/v0/preferences/cookie` | `core_app_api_v0_preferences_cookie` | `core/app/web/v0/cookies#show/update` | Core/App | public/conditional preference actor | PATCH yes | Edge/browser | JSON | no | working canonical Edge endpoint; controller namespace is historical | keep | runtime routes; preference controller tests |
| GET/PATCH | `/api/v0/preferences/theme` | `core_app_api_v0_preferences_theme` | `core/app/web/v0/themes#show/update` | Core/App | public/conditional preference actor | PATCH yes | Edge/browser | JSON | no | working canonical Edge endpoint; controller namespace is historical | keep | runtime routes; preference controller tests |
| POST | `/api/v0/preferences/dbsc` | `core_app_api_v0_preferences_dbsc` | `core/app/edge/v0/dbsc#create` | Core/App | conditional device binding | yes | Edge/browser | JSON | no | working canonical Edge endpoint; controller namespace is historical | keep | runtime routes; DBSC wiring tests |
| GET | `/sign/out/new` | `new_core_app_sign_out` | `core/app/sign/outs#new` | Core/App | public | no | browser | `/sign/out/edit` (303) | yes | working | keep | sign-out controller/request tests |
| GET | `/sign/out/edit` | `edit_core_app_sign_out` | `core/app/sign/outs#edit` | Core/App | public; active-session branch is conditional | no | browser | none | yes | working | keep | `docs/security/logout-sequence.md`; sign-out tests |
| POST | `/sign/out` | `core_app_sign_out` | `core/app/sign/outs#create` | Core/App | authenticated execution | yes | browser | Base `/oidc/logout` | yes | working; GET cannot execute it | keep | `OidcRpLogoutLauncher`; sign-out tests |
| GET | `/sign/out/complete` | `core_app_sign_out_completion` | `core/app/sign/outs/completions#show` | Core/App | public | no | browser | completion UI | yes | working RP completion | keep | logout ADR/docs; sign-out tests |
| GET | `/` | `auth_app_root` | `auth/app/roots#index` | Auth/App | guest/open | no | browser | `/sign/in`, or Base dashboard when signed in | yes | working credential-gateway entry | keep | root controller/tests |
| GET | `/sign/in` | `auth_app_sign_in` | `auth/app/sign/ins#show` | Auth/App | guest | no | browser | none | yes | working | keep | Auth route contract and sign-in tests |
| GET/POST/PATCH/DELETE | `/sign/in/*` | resource helpers | `auth/app/sign/in/*` | Auth/App | guest/conditional ceremony | POST/PATCH/DELETE yes | browser | ceremony-dependent; successful login resumes OIDC or Base dashboard | yes | working | keep | `config/routes/auth.rb`; credential and OIDC integration tests |
| POST | `/social/{google,apple}/{session,registration}` | provider resource helpers | `auth/app/social/*#create` | Auth/App | guest plus CSRF | yes | browser | provider request phase (307) | yes | working; no GET ceremony start | keep | routes; social ceremony tests |
| GET | `/social/{google,apple}/callback` | provider callback helpers | OmniAuth callback controller | Auth/App | state-bound callback | yes | browser/provider | validated ceremony continuation | yes | working protocol exception | keep | routes; OmniAuth callback tests |
| GET | `/oidc/authorization` | `auth_app_oidc_authorization` | `auth/app/oidc/authorizations#show` | Auth/App | public | no durable mutation; stages OIDC session state | browser | Base `/oauth/authorize` | yes | working | keep | runtime routes and OIDC tests |
| GET | `/oidc/callback` | `auth_app_oidc_callback` | `auth/app/oidc/callbacks#show` | Auth/App | public/conditional protocol callback | establishes RP session | browser | validated local `pt` | yes | working | keep | OIDC browser-flow integration test |
| GET/GET/POST/GET | `/sign/out/new`, `/edit`, base resource, `/complete` | Auth sign-out helpers | `auth/app/sign/outs*` | Auth/App | public reachability; session-guarded execution | POST only | browser | Base OIDC logout and local completion | yes | working | keep | logout sequence and controller tests |
| GET | `/` | `base_app_root` | `base/app/roots#index` | Base/App | public | no | browser | dashboard when authenticated | yes | working | keep | route/runtime and root tests |
| GET | `/lobby` | `base_app_lobby` | `base/app/lobbies#show` | Base/App | unauthenticated only contract | consumes one-shot notice only | browser | dashboard when authenticated | no | working canonical anonymous entry | keep | `adr/base-lobby-unauthenticated-entry.md`; lobby tests |
| GET | `/dashboard` | `base_app_dashboard` | `base/app/dashboards#show` | Base/App | authenticated and authorized | no | browser | auth initiation when anonymous | yes | working canonical authenticated entry | keep | dashboard/full-access tests |
| GET | `/.well-known/openid-configuration` | `base_app_well_known_openid_configuration` | discovery endpoint | Base/App | public | no | browser/internal RP | JSON | yes | working protocol endpoint | keep | Base authority route contract |
| GET | `/oauth/authorize` | `base_app_oauth_authorization` | `base/app/oauth/authorizations#show` | Base/App | conditional Acme session | issues code after authorization | browser/RP | Auth ceremony or exact registered callback | yes | working | keep | OAuth/OIDC authority tests |
| POST | `/oauth/token` | `base_app_oauth_token` | `base/app/oauth/tokens#create` | Base/App | registered client authentication plus code/PKCE | yes | internal RP | JSON | yes | working | keep | token exchange tests |
| GET/POST | `/oidc/logout` | `base_app_oidc_logout` | `base/app/oidc/logouts#show/create` | Base/App | conditional; exact registered logout request | POST yes | browser/RP | exact registered post-logout URI or `/lobby` | yes | working | keep | end-session and logout tests |
| GET/GET/POST | `/sign/out/new`, `/edit`, base resource | Base sign-out helpers | `base/app/sign_outs` | Base/App | public reachability; session-guarded execution | POST only | browser | `/lobby` after mutation | yes | working | keep | lobby ADR and sign-out tests |
| GET | `/sign/out/complete` | none | none on Base/App | Base/App | none | no | browser | 404 | no | intentionally closed | keep absent and pin negative route | Base lobby ADR; runtime routes |
| GET | `/` | `side_app_root` | `side/app/roots#index` | Side/App | public | no | browser | dashboard when authenticated | yes | working control-plane entry | keep | root tests |
| GET | `/dashboard` | `side_app_dashboard` | `side/app/dashboards#show` | Side/App | authenticated and authorized | no | browser | OIDC initiation when anonymous | yes | working | keep | dashboard tests |
| GET | `/oidc/authorization` | `side_app_oidc_authorization` | `side/app/oidc/authorizations#show` | Side/App | public | no durable mutation; stages OIDC session state | browser | Base `/oauth/authorize` | yes | working | keep | routes and OIDC concerns |
| GET | `/oidc/callback` | `side_app_oidc_callback` | `side/app/oidc/callbacks#show` | Side/App | public/conditional protocol callback | establishes RP session | browser | validated local `pt` | yes | working | keep | callback tests |
| GET/GET/POST/GET | `/sign/out/new`, `/edit`, base resource, `/complete` | Side sign-out helpers | `side/app/sign/outs*` | Side/App | public reachability; session-guarded execution | POST only | browser | Base OIDC logout and local completion | yes | working | keep | sign-out tests |

## Normal app SSO flow

1. A browser opens an authenticated Core, Auth, Base, or Side page. The surface application
   controller's authentication pipeline calls `OidcSsoInitiator#authenticate!` when no valid local
   actor session exists.
2. The RP creates a 48-byte PKCE verifier, an S256 challenge, 32-byte `state`, and 32-byte `nonce`.
   Ordinary auth-required navigation stores up to two pending flows under
   `session["oidc_pending_flows"]`; explicit authorization entry stores the legacy single-flow keys.
3. The RP sends `response_type=code`, its registered `client_id`, its exact host-matched
   `redirect_uri`, PKCE S256, `state`, `nonce`, `scope=openid profile`, region, and an optional
   `screen_hint` to Base/App `GET /oauth/authorize`.
4. Base is Acme, the authorization/session authority. If an Acme session is absent, it stages an
   authorization transaction and sends the browser to the Auth/App credential ceremony. Auth may
   perform email OTP, passkey, secret/TOTP, Google, or Apple authentication. A successful ceremony
   registers the authorization result and resumes Base authorization.
5. Base issues a one-time authorization code only for the exact registered `client_id` and
   `redirect_uri`, then returns it with the original `state` to the RP callback.
6. The RP callback consumes and constant-time compares `state`, consumes the PKCE verifier, exchanges
   the code at Base `/oauth/token` using the same exact `redirect_uri`, and verifies issuer,
   audience, signature, expiry, and the expected `nonce` in the ID token.
7. The RP provisions or resolves the surface-local actor bridge, creates the Rails-side browser
   session/token through the shared login path, binds OIDC `sid`/client metadata for logout, deletes
   consumed transaction state, and redirects only to the stored validated local path target.
8. Sign-out starts at `GET /sign/out/new`, redirects to the non-mutating confirmation at
   `GET /sign/out/edit`, and mutates only on CSRF-protected `POST /sign/out`. RPs coordinate with
   Base `/oidc/logout`; Core/Auth/Side finish at their local GET completion resources. Base finishes
   at `/lobby` and has no `/sign/out/complete` route.

### OIDC values and cookies

| Item | Observed behavior |
| --- | --- |
| `client_id` | Core `core-next-rp`; Auth `sign-rp`; Base and Side `base-rails-rp`. Values come from surface application/callback controllers and `OidcClientRegistry`. |
| `redirect_uri` | Selected from the registered client's URI list by exact request host; an absent host match raises `ActionController::BadRequest`. The same URI is used in authorization and token exchange. |
| PKCE | Random verifier, SHA-256 digest, base64url challenge, `code_challenge_method=S256`; callback fails if the verifier is missing. |
| `state` | Random, stored in the cookie-backed Rails session, consumed once, compared with equal length and `secure_compare`; mismatch/expiry returns 422 and clears affected state. |
| `nonce` | Random, stored with the pending flow, consumed by ID-token verification. |
| Return target | Stored as `pt`; `safe_oidc_pt` allows a local path/query or a same-host HTTP(S) URL reduced to path/query. External, protocol-relative, malformed, credential-bearing, control-character, or non-path values normalize to `/`. Callback redirect uses `allow_other_host: false`. |
| RP cookies | Rails session cookie carries bounded OIDC transaction state. Successful RP login sets the existing HttpOnly access cookie and opaque refresh cookie. Core API reads only the Core browser cookie transport and rejects Authorization bearer transport. |
| Callback errors | Invalid/expired state or missing PKCE returns 422 plain text with `no-store`; token/ID-token failures clear OIDC state and restart a fresh authorization flow. Logs contain identifiers, outcomes, and digests rather than tokens or raw state. |

No secret, private key, token, cookie value, authorization header, or actual credential is recorded
in this report.

## Findings and discrepancies

| Classification | Finding | Evidence | Disposition |
| --- | --- | --- | --- |
| Intentionally valid transition | Core `/` is routed to `Core::App::RootsController`, while the target Edge contract assigns `/` to Edge. The same operational document says the split is not in force and Rails answers every Core path because the Edge origin does not yet exist. The Rails root also creates anonymous preference state and remains linked by the Rails Core layout. | runtime route; Core root tests and layout; Edge contract deployment-status section | retain until an Edge deployment/cutover change provides evidence that the replacement is live |
| Documentation mismatch | The accepted ADR still names Next.js, while the task describes a newer TanStack Start Edge implementation. The Rails-owned path contract is framework-independent; the presentation framework name is historical. | `adr/core-browser-jwt-cookie-transport-and-nextjs-zero-cookie-boundary.md`; task scope | create a new ADR for current Rails/Edge ownership rather than rewrite history |
| Documentation mismatch | `api-route-vocabulary-consolidation.md` describes `/api/v0` as future and `/edge/v0`/`web/v0` as current, but Core has already moved its actual browser BFF contract to `/api/v0`. | accepted ADR dated 2026-06-13; current runtime routes and OpenAPI tests | document the implemented state in the new ADR |
| Intentionally valid | Core `/api/v0/session`, `/api/v0/token/refresh`, and `/api/v0/preferences/*` already provide the justified Edge-facing Rails boundary. | controllers, OpenAPI, request tests, operational contract | retain; do not add duplicate or speculative endpoints |
| Intentionally valid | Auth credential ceremony pages, Base identity/authority pages, Side control-plane pages, all OIDC endpoints, and explicit sign-out resources remain Rails-owned. | route/controller pipelines and accepted auth/logout docs | retain |
| Intentionally valid | Base `/sign/out/complete` is absent; Base sign-out completes at `/lobby`, which redirects authenticated actors to `/dashboard`. | lobby ADR, runtime routes, tests | retain absence and add ownership-contract coverage |

No route points to a missing controller/action: `test/integration/routes/route_target_contract_test.rb`
checks every surface route, and the pre-change full suite exercises that contract.

## Proposed Rails/Edge contract after remediation

No new JSON shape or new Edge endpoint is justified by current Rails or repository-local caller
evidence. The existing contract remains:

```json
GET /api/v0/session
{"authenticated":false,"csrf_token":"<masked token>"}
```

An authenticated response additionally includes the existing public actor object. Token refresh
remains `POST /api/v0/token/refresh` with a refresh cookie and CSRF token, returning `204 No
Content`. Preference endpoints retain their existing tested response shapes. No API-shape change is
proposed.

## Closed route record

No additional route is safe to close from current repository evidence. Base/App
`GET /sign/out/complete` was already closed by the accepted lobby change and remains absent. Core
`GET /` is a documented transition route whose replacement is not yet deployed according to the
current operational contract.

## Implemented result

The audit found no confirmed runtime route defect, security defect, duplicate route, dead route, or
missing Edge operation that justified changing the Rails route set. The repair is therefore an
ownership contract rather than speculative routing:

- `test/integration/routes/app_rails_edge_ownership_contract_test.rb` declares representative
  Rails-owned authentication, logout, API, and retained UI routes with their host, method,
  controller, and action.
- The same contract proves that Core legacy page aliases, Base's retired sign-out completion route,
  and GET variants of Core refresh and sign-out mutations remain absent.
- `adr/app-rails-edge-route-ownership.md` records the current normative boundary without rewriting
  the historical Next.js ADR.

No route was added, removed, redirected, or given a new response shape. No application controller,
authentication implementation, session implementation, Edge repository file, or com/org behavior
was changed by this audit.

## Compact before/after route table

| Method | Path | Before | After | Owner |
| --- | --- | --- | --- | --- |
| GET | Core `/` | transitional Rails UI | retained and ownership-tested | Core/App Rails |
| GET | Core `/oidc/authorization` | working RP initiation | retained and ownership-tested | Core/App Rails |
| GET | Core `/oidc/callback` | working RP callback | retained and ownership-tested | Core/App Rails |
| POST | Core `/oidc/backchannel/logout` | working protocol endpoint | retained and ownership-tested | Core/App Rails |
| GET | Core `/api/v0/session` | working JSON session endpoint | retained and ownership-tested | Core/App Rails |
| POST | Core `/api/v0/token/refresh` | working CSRF-protected mutation | retained; GET absence tested | Core/App Rails |
| POST | Core `/sign/out` | working CSRF-protected mutation | retained; GET absence tested | Core/App Rails |
| GET | Base `/lobby` | working anonymous entry | retained and ownership-tested | Base/App Rails |
| GET | Base `/sign/out/complete` | absent/404 | retained absent and negative-tested | none |
| GET | Core `/dashboard` | absent/404 | retained absent and negative-tested | none |
| GET | Core `/sso/authorize` | absent/404 | retained absent and negative-tested | none |

## Verification Results

- `bin/rails routes --expanded`: completed; effective owners and source locations were captured.
- `bin/rails routes`: completed after the audit; the route set is unchanged.
- Focused route, OIDC, sign-out, lobby, and Core OpenAPI contract set: 79 runs, 1,157 assertions,
  0 failures, 0 errors, 1 skip. The skip is an existing session-limit scenario blocked by issue
  #846.
- `bin/rails test test/integration/routes/app_rails_edge_ownership_contract_test.rb`: 4 runs,
  7 assertions, 0 failures, 0 errors, 0 skips.
- `bin/rails test test/tooling/evidence_layout_test.rb`: 3 runs, 6 assertions, 0 failures,
  0 errors, 0 skips.
- `bin/rubocop test/integration/routes/app_rails_edge_ownership_contract_test.rb`: one file,
  no offenses.
- The first complete `bin/rails test` run finished with 13,008 runs, 79,242 assertions,
  0 failures, 4 errors, and 2 skips. Three errors were missing translations in concurrently changed
  Base App/Com/Org dashboard tests; the fourth was an undefined `assert_not_includes` call in the
  concurrently changed compose tooling test.
- `bin/ci` ran all configured steps and failed because unrelated worktree changes did not pass
  JavaScript style, Ruby style, or the complete Rails suite. Database preparation, ERB lint, gem and
  JavaScript audits, Brakeman, dependency reports, Rails server boot, and 1,077 JavaScript tests
  passed. Its Rails retry finished with 13,008 runs, 79,274 assertions, 0 failures, 1 error, and
  2 skips; the remaining error was the concurrently changed compose tooling test.

The worktree changed concurrently during verification. This report does not claim results for
those unrelated changes, and the audit did not alter them.
