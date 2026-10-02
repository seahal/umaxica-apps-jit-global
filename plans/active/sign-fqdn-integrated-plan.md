# Sign FQDN Integrated Plan

Status: active. P0 re-baseline done 2026-10-02 against `845f84b281663786c4d4e0f6473fcf3ab2040b74`
plus uncommitted work. P3 has not started; its gate is in section 7.

The two inputs named by the request (`umaxica-sign-fqdn-integrated-plan-2026-10-03.md` and
`umaxica-sign-plan-review-addendum-2026-10-03.md`) were not found, and the user confirmed on
2026-10-02 that they cannot be located. This file is therefore the sole canonical plan. The S01–S28
item IDs those documents defined are retired unread; findings here use only D and E IDs, and no S
ID is reconstructed or guessed.

Accepted decisions live in `adr/sign-neutral-entry-and-logout-target-authorization.md`. Evidence:
`evidence/2026-10-02-sign-p0-baseline-d1-T5N3.md`.

## 1. Scope boundaries

In scope for this plan: the neutral `/sign` entry, refusal of a new Sign by an authenticated
browser, Auth admission, callback naming, logout target authorization, and Palm native entry.
Out of scope: Jump state (Jump stays a stateless forwarder; a 3xx is not evidence that the
destination processed anything), new authentication protocols, new self-registration on Org or any
surface that lacks it today.

## 2. Sign entry contract

### 2.1 Neutral entry

- The normal entry is `GET /sign` (display only) and `POST /sign` (start). The RP never offers a
  Sign in / Sign up choice and never sends `intent=sign_up`, `screen_hint=signup`, or
  `prompt=create` on a normal start.
- `GET /sign` creates no authentication transaction, issues or consumes no admission, and does not
  auto-POST or auto-redirect. CSRF material needed to render the form is the only state it may
  touch.
- Auth's first screen is `/sign/in`; a switch to registration happens inside Auth, only where
  registration is offered. Registration eligibility, result receipt, and session issuance belong to
  Base.
- Auth requires a Base-issued admission or verified continuation state. The automatic Base bridge
  for a context-free Auth request is retired (E01). Returning a normal success or cancel result to
  Base stays.

### 2.2 Authenticated browser starting a new Sign

- A browser that the RP or Base can verify as authenticated is refused a new Sign with
  `403 text/plain`, the shared i18n message equivalent to "この操作は許可されていません。", and
  `Cache-Control: no-store`. No `Location`, no Home/Dashboard redirect, no links, no logout hint, no
  automatic retry, no compensating path. The existing session is not ended, exchanged, or evicted.
- **Product constraint:** a browser signed in at Base but not at a given RP cannot start a new
  login at that RP. This is intended. The SSO success branch is not kept for convenience, and the
  refusal is not narrowed to RP-only state.
- Post-authentication processing of the same live transaction is not a new Sign. It is recognized
  by server-held stage, subject, browser binding, and expiry; never by a self-declared flag such as
  `continuation=true`.

### 2.3 New-Sign decision table

| State | Handling |
|---|---|
| Valid existing authentication | Refuse new Sign with 403 |
| Access expired, but continuable through a verified refresh family | Refuse new Sign with 403; do not refresh in order to decide |
| Unauthenticated | Start from the neutral entry |
| Invalid proof (bad signature, revoked family, wrong client) | Reject explicitly; never fall back to guest |
| Decision dependency failure (DB, Valkey) | Stop as a dependency failure; never treat as unauthenticated |
| Continuation of the same live transaction | Allow only the step that continuation needs |

Cookie presence alone decides nothing: session, refresh family, client, active generation, expiry,
and revocation must agree. History records, preferences, and sessions on other devices are not
evidence that this browser is authenticated. Refusing a new Sign is a separate decision from
whether an API accepts an expired access token.

Back means moving within the same procedure; Cancel ends the current transaction; Logout ends
authentication state for an explicit scope. Failure counts and consumed evidence are never restored
by Back or a switch. Cancel never ends an existing login. Normal logout keeps browser history and
preferences, which are never used as authentication proof.

## 3. Findings ledger

Static means the branch exists in current code; dynamic means a test drove it through the public
route. Only D1 and D2 were driven dynamically in P0.

| ID | Finding | Current code | Status |
|---|---|---|---|
| D1 | Unauthenticated browser presenting another subject's valid `id_token_hint` ended that subject's session | `app/services/oidc_end_session_request.rb` `handle_id_token_hint`; `app/controllers/concerns/sign_oidc_logout.rb:290` | Dynamically confirmed, fixed, regression-tested (section 3.1) |
| D2 | Base `/oidc/logout` POST without `logout_challenge` runs no CSRF verification on app, com, and org | `app/controllers/base/{app,com,org}/oidc/logouts_controller.rb` `protect_from_forgery ... only: :create, if: logout_challenge` replaces the inherited unconditional check | Dynamically confirmed on app, com, and org (RED). Fixed and verified (section 3.2) |
| E01 | Context-free Auth request bridges to Base admission; logged-in direct `/sign/up` redirects to the Base dashboard | `app/controllers/concerns/auth_ceremony_admission.rb:43,102`; `app/controllers/auth/app/sign/ups_controller.rb:36-43` | Bridge retired in P3: a context-free Auth request now answers 400 without a redirect. `ri` was never shown to be an open redirect (host was fixed by `base_authority_host`) |
| E02 | Base authorize issues a code when the browser is already authenticated | `app/controllers/base/app/oauth/authorizations_controller.rb:27-28` | Ordinary SSO, not a vulnerability; removed in P3 to meet section 2.2: an authenticated browser now gets 403 |
| E03 | A Valkey failure while reading the Auth result answered `400 invalid_request`, the same as a rejected result | `app/controllers/concerns/oidc_authorization_result_post.rb:30` (before fix) | Dynamically confirmed and fixed: now `503 temporarily_unavailable`, transaction not consumed (`test/controllers/base/oauth_authorization_surfaces_test.rb`, `E03 …`). The same merge in Base authorize `show` was fixed in P3 |
| E04 | HTML end-session errors and stale completions render the completion page with 200 | `sign_oidc_logout.rb:224-240` | Static |
| E05 | Revocation, `reset_session`, transaction advance, and notification can fail part-way | `sign_oidc_logout.rb:99-137,181-195,287-307` | Static only. Separate steps are not proof of a defect; no fault-injection test yet |

### 3.1 D1 result

Precondition: possession of another subject's valid ID Token for a registered client. No credential
was bypassed beyond that, and nothing was read or taken over.

Before the fix, with CSRF satisfied through a same-origin fetch and no authentication, `GET` with
B's hint and a registered `post_logout_redirect_uri` staged B's `sid` in A's Rails session, and the
following `POST` revoked B's `ClientToken` (`discard_at` set) and enqueued 7
`OidcBackchannelLogoutDeliveryJob`s for B's `sid`.

Fix: the hint's `sub` and `sid` become the logout target only when the verified current session
matches them. Without a current session the hint still validates client and redirect URI, the
browser's own state is cleared, and nothing is revoked or notified. RP-Initiated Logout 1.0 treats
`id_token_hint` as a hint about the End-User's current session and expects the OP to ask the user
when it cannot tie the request to that session; it does not grant authority over another session.
Refusing to act on a session the browser does not hold is a UMAXICA constraint consistent with that.

Coordinated logout (`logout_challenge`) does not use the hint `sid`: it ends the current session
through `logout_current_session!` and is bound to a stored `AcmeLogoutTransaction`
(`sign_oidc_logout.rb:50-74`). It was checked statically and by the existing challenge tests.

Further D1 cases, all passing after the fix (`test/controllers/base/app/oidc/logouts_controller_test.rb`,
tests named `D1 …`):

- An access token without `sid` is not accepted as authentication at all, so the
  `expected_sid.blank?` branch (`oidc_end_session_request.rb:125`) is unreachable through this
  route; that request is treated as unauthenticated and revokes nothing.
- Swapping another subject's hint into the POST ends neither session.
- Staged-request expiry, BVA: POST at 4:59 ends the session, at 5:00 does not (6:00 was already
  covered).
- Replaying a completed POST does not end a session created afterwards.
- Omitted, empty, array, hash, and NUL-suffixed `id_token_hint` end nothing. JSON null and
  duplicate keys are not representable as distinct values in a form or query parameter.

- A second staged request in the same browser does not replace the first: the later GET only
  renders the confirmation, and the POST ends the session with the first request's `state`.
- A hint issued for another realm's client and issuer (`core-org`, operator issuer) on the app
  host ends nothing.

### 3.2 D2: CSRF verification skipped on Base end-session POST

Each Base `Oidc::LogoutsController` calls `protect_from_forgery using: :header_only, only: :create,
if: -> { params[:logout_challenge].present? }`. Rails keeps one `verify_authenticity_token`
callback per controller, so this declaration replaces the inherited unconditional one; inspection
of `_process_action_callbacks` shows a single callback with two conditions on all three surfaces.
A POST without `logout_challenge` therefore runs no CSRF check.

Observed: after a same-origin GET staged the user's own logout, a POST with
`Sec-Fetch-Site: cross-site`, no `Origin`, and no token answered 303 and revoked the user's own
session. Impact is forced logout of the browser's own session; a real cross-site POST also needs
the Rails session cookie, which depends on its SameSite setting (not checked).

Fix (applied 2026-10-02 on the user's instruction): the `protect_from_forgery` redeclaration was
removed from all three controllers, so the inherited `:header_or_legacy_token` check covers every
POST. Coordinated-logout POSTs stay gated by `verify_coordinated_sign_out_post!` (Sec-Fetch-Site
same-origin/same-site, Origin rule) and `SignOutNotice#verified_request?` (live challenge in place
of the legacy token). RED: the cross-site test failed on app, com, and org. GREEN: the three Base
logout test files, 58 runs, 269 assertions, 0 failures, including same-origin control, same-site
Auth-origin challenge POST with forgery protection on, and cross-site challenge refusal (app only).
After the fix, RuboCop passed and the full suite ran 12418 tests with 0 failures; callback inspection
was replaced by the behavior tests above.

## 4. Migration table

| Current | Target | Change location / dependency | Tests | Status |
|---|---|---|---|---|
| Core/Warp/Edit `GET /sign/callback` (`config/routes/core.rb:78,160,242`, `warp.rb:82,180,277`, `edit.rb:43`) | `/oidc/callback` | Routes, client registry redirect URIs, Edge tunnel path rules | Route recognition, registry redirect URI match, old path unroutable | Done (P3): routes, `RegionalRpClientMatrix::CALLBACK_PATH`, `AuthBoundaryAuthorityMap::CANONICAL_RP_CALLBACK_PATH`; Edge path rules for Warp/Edit hosts unverified (7.1) |
| Mixed 409 / 403 / fixed English / redirect for authenticated new Sign (`auth/app/sign/ups_controller.rb:36`, `auth/{com,org}/sign/ups_controller.rb:33-34`, `authorizations_controller.rb:27`) | Shared i18n `403 text/plain`, `no-store` | Auth, Base authorize, RP entries | Per state in 2.3, headers, no session mutation | Done (P3): one renderer, `AuthenticationBase#render_sign_in_unavailable_while_authenticated` |
| Base `POST /` and Sign in/up choice (`config/routes/base.rb:14,274,471`) | Neutral `GET/POST /sign`; Base does not become its own RP | Base routes and root controllers | GET has no side effects; POST starts; old POST unroutable | Done (P3): `BaseNeutralSignEntry`, `Base::{App,Com,Org}::Sign::EntriesController` |
| Auth context-free bridge (`auth_ceremony_admission.rb:102`) | Explicit refusal | Auth admission concern | Missing admission refused; success/cancel return kept | Done (P3): 400 `invalid_request`, no redirect |
| Protected-page `OidcSsoInitiator#authenticate!` starts OIDC directly (`oidc_sso_initiator.rb:11-28`; Core/Warp/Edit application controllers) | Unauthenticated HTML goes to passive `/sign`; API keeps 401 JSON (`:17`) | RP application controllers | HTML redirect target, API 401, no replay of POST/PATCH/DELETE | Done (P3): RP, Base, and Auth protected pages and RP callback failure all point at a passive `GET /sign` |
| Palm pending flows trimmed with `last(PENDING_FLOW_LIMIT)` (`palm/app/sign/entries_controller.rb:18,61`) | Third pending flow refused explicitly; first two kept | Palm entry | Limit 1/2/3, cookie update race, expiry boundary | Done (P3) for Palm; the cookie update race is not covered |
| Palm fixed `Continue` (`app/views/palm/app/sign/entries/show.html.erb:7,13,18`) | Shared i18n | Palm view, locales | Template and i18n verified separately | Done (P3): `actions.continue` in the Palm view, the shared RP entry template, and Warp roots |
| No authorize parameter or request size limit | 2048 bytes per parameter, 8 KB per request, 400 before state allocation | Base authorize controllers (app/com/org) | Each limit at below/at/above; no transaction row on refusal | Done (P3): `OauthAuthorizeRequestSizeLimit` |
| Expired authorization transactions never removed | Purge job like `app/jobs/*_ceremony_transaction_purge_job.rb` | `app/jobs/`, recurring schedule | Expired rows removed, live rows kept, boundary at expiry | Done (P3): `OidcAuthorizationTransactionPurger` every 15 minutes, existing `RETENTION_PERIOD` (15 min) |
| End-session hint `sid` used as revocation target | Bound to the verified current session | `oidc_end_session_request.rb` | `test/controllers/base/{app,com,org}/oidc/logouts_controller_test.rb` | Done (P0) |

### 4.1 Removing the SSO success branch

Replacing E02's code issuance with the 403 refusal means a browser signed in at Base but not at an
RP can no longer start a login at that RP (product constraint from 2.2). The migration must not
keep the success branch behind a flag, and must not narrow the refusal to RP-only state. The
continuation of a live transaction (2.2, last bullet) is the only path that may still reach code
issuance for an authenticated browser.

## 5. Second entry and capacity

`OidcSsoInitiator#authenticate!` is a second entry: a protected HTML page starts OIDC without the
user pressing Start. It moves to the passive `/sign` entry; it is not an exception to section 2.1.
The Base Authorization Endpoint `GET` is protocol traffic, not the neutral entry `GET`, but it must
still validate the request and require a legitimate start before allocating state. `Referer`, a
public `client_id`, or an arbitrary "started" flag are not a legitimate start.

| Item | Current value | Source | Proposed | Basis |
|---|---|---|---|---|
| Authorize rate limit (production) | Fixed-window counters, evaluated in order: IP+surface 120/min, browser+client 60/min, client+redirect host 600/10 min; `Retry-After` 60/60/600 s; no separate burst allowance | `app/values/rate_limit_profiles.rb:36-50`, `app/controllers/concerns/oauth_authorize_rate_limit.rb:17-36` | Keep | Already in force; no measurement says otherwise |
| Authorize rate limit scope | `GET` (show) only; the Auth result `POST` is not counted | `oauth_authorize_rate_limit.rb:8` | Keep | The result POST needs a valid transaction and a one-time result first |
| Rate-limit backend failure | `503 temporarily_unavailable`, no state allocated | `oauth_authorize_rate_limit.rb:46-95` | Keep | Matches 2.3 "dependency failure" |
| 429 side effects | 429 with `Retry-After`; returned before a transaction is issued | `oauth_authorize_rate_limit.rb:150-170` | Keep | — |
| Auth result read on Valkey failure | `503 temporarily_unavailable`, transaction not consumed (fixed in P0, E03) | `oidc_authorization_result_post.rb` | Keep | — |
| Admission / result code TTL | 60 s | `app/services/valkey/auth_state/opaque_admission_store.rb:13` | Keep | — |
| Authorization transaction TTL | Login challenge 10 min, transaction 15 min | `app/services/oidc_authorization_transaction_coordinator.rb:21` | Keep | — |
| Pending end-session request TTL | 5 min (boundary tested at 4:59 / 5:00) | `sign_oidc_logout.rb:277` | Keep | P0 tests |
| Palm pending flows | 2, oldest silently dropped by `last(2)` | `palm/app/sign/entries_controller.rb:18,61` | Keep 2; refuse the 3rd explicitly | Request condition |
| Palm continuity parameter length | 1–256 bytes | `palm/app/sign/entries_controller.rb:20,82` | Keep | — |
| Unfinished authorization transactions per browser or client | No count cap | — | No count cap (decided 2026-10-02) | Bounded by the authorize rate limits, the 15-minute TTL, and the purge job below |
| Authorize parameter length and total size | No per-parameter or total limit in Rails | — | 2048 bytes per parameter, 8 KB per request; refuse with 400 before any state is allocated (decided 2026-10-02; P3) | Bounds stored size and work done before validation |
| Stored transaction size | No explicit limit | — | Bounded by the 8 KB request limit above (decided 2026-10-02) | — |
| Cleanup of expired authorization transactions | No purge job (other ceremonies have `*_ceremony_transaction_purge_job.rb`) | `app/jobs/` | Add a purge job following the existing pattern (decided 2026-10-02; P3) | Rows accumulate without bound today |
| Concurrency of result redemption | Transaction `consumed?` checks plus one-time result | `oidc_authorization_result_post.rb`, `auth_ceremony_admission.rb:66-76` | Keep; add a parallel-POST test in P3 | — |

## 6. Surfaces

Routes are in `config/routes/*.rb`. "Unverified" means not confirmed in this session. The Edge
repository (`seahal/umaxica-apps-edge`) could not be read: the GitHub CLI is not authenticated.
This repository's `origin` is `seahal/umaxica-app-jit`.

| Surface | Owner repo / ref | FQDN source | Role | Config owner | Status |
|---|---|---|---|---|---|
| Core | this repo @ `845f84b` | `config/routes/core.rb` | RP | this repo | Routes verified |
| Warp | this repo | `config/routes/warp.rb` | RP | this repo | Routes verified |
| Edit | this repo | `config/routes/edit.rb` | RP (org) | this repo | Routes verified |
| Palm | this repo | `config/routes/palm.rb` | Native RP entry (public client) | this repo | Routes verified |
| Base | this repo | `config/routes/base.rb` | OP: authorize, session, logout | this repo | Routes verified |
| Auth | this repo | `config/routes/auth.rb` | Ceremony UI | this repo | Routes verified |
| Info / Docs / News / Help | this repo | `config/routes/{info,docs,news,help}.rb` | Non-RP content | this repo | Not classified in P0 |
| Guid | this repo | `config/routes/guid.rb:5-8` (`guid.umaxica.net`) | Unverified | this repo | Routes read; role not classified |
| Xper | this repo | `config/routes/xper.rb:4-7` ("no credential lifecycle") | Unverified | this repo | Routes read; role not classified |
| Mission | this repo | `config/routes/mission.rb:5-7` (`mission.umaxica.dev`) | Unverified | this repo | Routes read; role not classified |
| Jump | external (Hono) | `PUBLIC_JUMP_GATEWAY_URL` | Stateless forwarder | Edge | Unverified |
| DNS apex sites (external root origins; not the retired RP boundary now named Acme) | external | — | Unverified | Edge | Unverified |

Non-RP surfaces receive ordinary links and public context only: no authorization code, ID/access/
refresh token, admission, subject data, or proof of authentication. Signed display data is never
reused for authentication or authorization. Same operator or same parent domain is not a reason to
trust every origin.

Palm: the public `client_id` is not proof of app authenticity, and a first-party flag does not
remove protection. When Auth switches to an allowed registration, the parent request's state,
nonce, PKCE challenge, client, and redirect must be preserved; the verifier stays on the device.
Palm's short-lived browser continuity cookie is not login evidence. The authenticated-browser guard
covers only state the server can verify; app-internal state that is never presented cannot be
detected.

## 7. P3 gate

P3 starts only when every row is met. The gate opened on 2026-10-02 and P3 was carried out the same day (7.1).

| Condition | State |
|---|---|
| Working baseline recorded | Met (evidence) |
| Normal test command boots without ad hoc ENV | Met for new shells: `~/.bashrc` and `~/.profile` export the correct `PUBLIC_JUMP_GATEWAY_URL` until the Dev Container is recreated; `bin/rails test` then ran 12410 tests |
| D1 decided, fixed, retested | Met (3.1) |
| D2 decided, fixed, retested | Met (3.2) |
| New-Sign / continuation state table | Met (2.3) |
| Capacity table | Met: all values defined or decided (5); size limits and purge job are P3 work |
| Migration table | Met (4) |

### 7.1 P3 result and remaining work

All migration rows in section 4 are done; evidence in `evidence/2026-10-02-sign-p0-baseline-d1-T5N3.md`.
Remaining, none of it started:

- RP side (`OidcSsoInitiator#remember_oidc_pending_flow!`) still trims pending flows with
  `last(2)`; only Palm refuses the third flow.
- Edge configuration (external, unverified): `/oidc/callback` on Warp (`www-jp.*`) and Edit hosts,
  and `/sign` on Base public hosts, must reach Rails. The `jp.umaxica.*` rule already admits `oidc`.
- `expires_at` on the three authorization transaction tables has no index; the purge query scans.
  Measure before adding one (a migration).
- `Base::*::Oauth::AuthorizationsController` redeclares `protect_from_forgery ... only: :create,
  if: result` (the D2 pattern). A create without `result` cannot progress past the one-time result,
  so no impact was found; the redeclaration should still go in a reviewed change.
- `config/recurring.yml` schedules `social_ceremony_transaction_purge` with
  `EmailCeremonyTransactionPurgeJob` (pre-existing, not changed).
- Palm sign-up switch preserving the parent request's state, nonce, PKCE challenge, client, and
  redirect (section 6) is not implemented or tested.
