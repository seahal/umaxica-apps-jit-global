# OIDC Routing Cleanup — Remediation Plan

**Date:** 2026-06-16 **Status:** Planning pass only — no code changes in this document.

---

## A. Executive Verdict

The core problems are real and confirmed from code inspection. The highest-value change is
**retiring `/sso/authorize` and `/sso/logout` as RP login entrypoints** across Acme (app, com, org)
and Core (app, com, org) and replacing them with a canonical `GET /auth` and `POST /auth/logout`.

The current Acme `/oauth/*` provider endpoints are **not wrong** and should not be changed as a
prerequisite. They are correct protocol-prefixed paths that already match
`/.well-known/openid-configuration`.

The biggest clarity gap is **Base RP ownership**: the `base-rails-rp` client is registered with
redirect URIs pointing to Acme hosts and handled by `Acme::*::Auth::CallbacksController`. This is
either a legitimate "Acme owns its own local session login as 'base-rails-rp'" arrangement that
needs a clearer name, or a genuine misplacement of the Base RP callback. **This must be resolved
before any auth route is renamed on Acme.**

Palm's registered clients (`app-ios-rp`, `app-android-rp`) currently use custom-scheme redirect URIs
(`umaxica://`, `com.umaxica.app:/`), not claimed HTTPS. Palm's `/oauth/callback` stubs are
informational-only. There is no active claimed-HTTPS callback handling. This is a P5 item.

`OidcRpLogout#create` uses `notice:` in `redirect_to` (Rails flash), violating the project
no-flash-messages rule. This should be fixed as part of Phase 1.

---

## B. Confirmed Current Route Inventory

### Acme (OP/AS — three hosts: app, com, org)

**Provider / OP endpoints** (all three hosts):

```
GET  /oauth/authorize   → Acme::{surface}::Oauth::AuthorizationsController#show
POST /oauth/token       → Acme::{surface}::Oauth::TokensController#create
GET  /oauth/userinfo    → Acme::{surface}::Oauth::UserinfosController#show
POST /oauth/revoke      → Acme::{surface}::Oauth::RevocationsController#create
GET  /oauth/jwks        → Acme::{surface}::Oauth::JwksController#show
GET  /.well-known/openid-configuration → Acme::{surface}::WellKnown::DiscoveriesController#show
GET  /.well-known/jwks.json            → Acme::{surface}::WellKnown::JwksController#show
GET  /oidc/logout  (+ POST)            → Acme::{surface}::Oidc::LogoutsController
```

**RP / local-session endpoints** (all three hosts):

```
GET  /auth/callback   → Acme::{surface}::Auth::CallbacksController#show
                        oidc_client_id = "base-rails-rp"
GET  /sso/authorize   → Acme::{surface}::Sso::AuthorizationsController#show
POST /sso/logout      → Acme::{surface}::Sso::LogoutsController#create
```

**Sign-out bridge** (all three hosts):

```
GET/PATCH/POST/DELETE /sign/out → Acme::{surface}::Sign::OutsController
```

**Social authentication** (app host only):

```
POST /social/auth/:id/continue   → Acme::App::Social::AuthenticationsController
POST /social/auth/:id/completion → Acme::App::Social::AuthenticationsController
```

### Core (BFF — three hosts: app, com, org)

```
GET  /auth/callback       → Core::{surface}::Auth::CallbacksController#show
                            oidc_client_id = "core-next-rp"
GET  /sso/authorize       → Core::{surface}::Sso::AuthorizationsController#show
POST /sso/logout          → Core::{surface}::Sso::LogoutsController#create
POST /oidc/backchannel/logout → Core::{surface}::Oidc::Backchannel::LogoutsController#create
GET  /.well-known/jwks.json   → Core::{surface}::WellKnown::JwksController#show
```

### Sign (credential gateway — three hosts: app, com, org)

**RP login (Sign as RP):**

```
GET  /auth/callback         → Sign::{surface}::Auth::CallbacksController#show
                              oidc_client_id = "sign-rp"
```

No `/sso/*` routes. No `GET /auth`. No `POST /auth/logout`. Sign-as-RP has no login start route of
its own — the Acme OP redirects to Sign ceremony directly.

**Ceremony (app and com — not org sign-up):**

```
GET  /sign/in/entrance    → Sign::{surface}::Sign::In::EntrancesController#show   (LEGACY)
GET  /sign/up/entrance    → Sign::{surface}::Sign::Up::EntrancesController#show   (LEGACY)
GET  /sign/in/guard       → Sign::{surface}::Sign::In::GuardsController#show
GET/PATCH /sign/in/check  → Sign::{surface}::Sign::In::ChecksController
POST /sign/in/check/cancellation → Sign::{surface}::Sign::In::Check::CancellationsController
GET  /sign/in/challenge   → Sign::{surface}::Sign::In::ChallengesController#show
... (passkey, OTP, secret_credential sub-routes)
```

**Social OmniAuth callbacks (app only):**

```
GET  /auth/google_app/callback → Sign::App::Auth::OmniauthCallbacksController#omniauth
GET/POST /auth/apple/callback  → Sign::App::Auth::OmniauthCallbacksController#omniauth
GET  /auth/failure             → Sign::App::Auth::OmniauthCallbacksController#failure
```

**OIDC backchannel (all three hosts):**

```
POST /oidc/backchannel/logout → Sign::{surface}::Oidc::Backchannel::LogoutsController#create
```

### Base (control-plane — three hosts: app, com, org)

No auth routes. No `/auth/*`. No `/sso/*`.

The `base-rails-rp` client has redirect URIs pointing to Acme hosts (`ACME_SERVICE_URL`,
`ACME_STAFF_URL`, `ACME_CORPORATE_URL`). The callback handler lives under
`Acme::*::Auth::CallbacksController` with `oidc_client_id "base-rails-rp"`.

Base's route contract test asserts zero auth routes. This is currently consistent with the code but
the client name ("base-rails-rp") implies misplaced ownership.

### Palm (native API — app host only)

```
GET /oauth/callback         → Palm::App::Oauth::CallbacksController#show
                              (stub — renders informational plain text, no session, no cookie)
GET /oauth/callback/ios     → Palm::App::Oauth::Callback::IosController#index   (stub)
GET /oauth/callback/android → Palm::App::Oauth::Callback::AndroidController#index (stub)
```

Registered clients and their redirect URIs:

```
app-ios-rp:     umaxica://oauth/callback      (custom scheme — NOT claimed HTTPS)
app-android-rp: com.umaxica.app:/oauth/callback (custom scheme — NOT claimed HTTPS)
```

Neither client is explicitly registered with claimed HTTPS redirect URIs. Both use
`token_endpoint_auth_method: "none"` (correct for public clients). Neither has a `client_secret`
(correct).

No Palm login-start route exists.

---

## C. Target Contract Restatement

### Web RP Contract (Core, Acme local login, Sign-as-RP)

```
GET  /auth           — start OIDC login; redirects to Acme /oauth/authorize
GET  /auth/callback  — receive authorization code; create local RP session
POST /auth/logout    — destroy local RP session only (not global IdP logout)
```

### Sign Ceremony Contract

```
GET  /sign/in              — entrance (replaces /sign/in/entrance)
POST /sign/in              — submit sign-in credential
GET  /sign/up              — entrance (replaces /sign/up/entrance)
POST /sign/up              — submit sign-up step
GET  /sign/out             — sign-out start
POST /sign/out             — sign-out submit
GET   /sign/in/check       — verify MFA challenge
PATCH /sign/in/check       — submit MFA verification
POST  /sign/in/cancellation — cancel sign-in ceremony
GET   /sign/up/check       — verify registration challenge
PATCH /sign/up/check       — submit registration verification
POST  /sign/up/cancellation — cancel sign-up ceremony
```

### Acme Provider Contract

Keep current `/oauth/*` endpoints. They are correct and match discovery.

```
GET  /oauth/authorize
POST /oauth/token
GET  /oauth/userinfo
POST /oauth/revoke
GET  /oauth/jwks
GET  /.well-known/openid-configuration
GET  /.well-known/jwks.json
GET/POST /oidc/logout
```

Do not move to root-level at this time (see Phase 6 analysis).

### Palm Native Contract

```
GET /oauth/callback — claimed HTTPS stub (already exists)
```

Registered redirect URI should be claimed HTTPS (deferred until P5 decision).

---

## D. Risk Ranking

| Risk                                            | Level      | Description                                                                                                                                                                                        |
| ----------------------------------------------- | ---------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| base-rails-rp client identity confusion         | **HIGH**   | Client is named "Base Rails RP" but callback lives under Acme. Must be resolved before renaming.                                                                                                   |
| `/sso/*` references in Acme layout views        | **HIGH**   | Three layout files directly use `acme_app_sso_authorization_path`, `acme_app_sso_logout_path` etc. Renaming routes breaks views.                                                                   |
| Route contract tests lock old paths             | **MEDIUM** | `AcmeRouteContractTest` asserts `/sso/authorize` and `/sso/logout`. `SignRouteContractTest` asserts `/sign/in/entrance` and `/sign/up/entrance`. Must update tests in same commit as route change. |
| `OidcRpLogout` uses Rails flash                 | **MEDIUM** | `notice: rp_local_logout_notice` in redirect_to violates no-flash-messages rule. Fix in Phase 1.                                                                                                   |
| `sign_app_sign_in_entrance_url` has 20+ callers | **MEDIUM** | Ceremony entrance URL is used across many controllers/concerns. Renaming requires sweeping all callers.                                                                                            |
| Palm custom-scheme redirect URIs                | **LOW**    | Clients are not yet live as claimed HTTPS. No user-visible URL change required immediately.                                                                                                        |
| Acme `/oauth/*` endpoint shape                  | **LOW**    | Discovery document and actual routes already match. No client breakage risk if kept as-is.                                                                                                         |

---

## E. Phase-by-Phase Remediation Plan

---

### Phase 0: Inventory and Lock Current Behavior

**Goal:** Create accurate route assertions and identify every reference to legacy paths.

**Scope:**

- Add negative assertions to existing route contract tests for paths we will remove
- Audit every reference to `sso_authorization_path`, `sso_logout_path`, entrance helpers

**Non-goals:** No code changes to controllers or views.

**Files likely touched:**

- `test/integration/routes/acme_route_contract_test.rb` — add negative assertions
- `test/integration/routes/core_route_contract_test.rb` — add negative assertions
- `test/integration/routes/sign_route_contract_test.rb` — add negative assertions
- `test/integration/routes/palm_route_contract_test.rb` — note platform stubs

**Route changes:** None.

**Controller changes:** None.

**Test changes:** Add assertions that `GET /auth` does NOT currently resolve on Core and Acme
(expected to fail until Phase 1 is done). This documents the gap without breaking anything.

**Compatibility concerns:** None.

**Rollback strategy:** N/A — no code change.

**Acceptance criteria:**

- Document exists (this memo) listing all current paths with owner and intended semantic role
- Route contract tests have been reviewed; no negative assertions removed

---

### Phase 1: Introduce Canonical Web RP /auth Contract

**Goal:** Add `GET /auth` and `POST /auth/logout` alongside existing `/sso/*` routes on Core and
Acme. Do not remove `/sso/*` yet.

**Scope:** Core (app, com, org) and Acme (app, com, org).

**Non-goals:** Do not rename or remove `/sso/authorize` or `/sso/logout` yet. Do not touch Sign.

**Open question that must be resolved before this phase:** The `base-rails-rp` client registered
under Acme hosts needs a decision:

- Option A: Rename to `acme-self-rp` and treat Acme's local session login explicitly as Acme's own
  RP role. Update `oidc_client_id` in `Acme::*::Auth::CallbacksController`.
- Option B: Leave name unchanged but add a code comment making the ownership explicit.

Regardless of which option, the callback controller class stays in `Acme::*` namespace since the
redirect URIs point to Acme hosts.

**Files likely touched:**

_Routes:_

- `config/routes/acme.rb` — add `namespace :auth` with
  `resource :authorization, only: :show, path: ""` and `resource :logout, only: :create` under each
  host constraint
- `config/routes/core.rb` — same pattern

_Controllers (new files):_

- `app/controllers/acme/app/auth/authorizations_controller.rb`
- `app/controllers/acme/com/auth/authorizations_controller.rb`
- `app/controllers/acme/org/auth/authorizations_controller.rb`
- `app/controllers/acme/app/auth/logouts_controller.rb`
- `app/controllers/acme/com/auth/logouts_controller.rb`
- `app/controllers/acme/org/auth/logouts_controller.rb`
- `app/controllers/core/app/auth/authorizations_controller.rb`
- `app/controllers/core/com/auth/authorizations_controller.rb`
- `app/controllers/core/org/auth/authorizations_controller.rb`
- `app/controllers/core/app/auth/logouts_controller.rb`
- `app/controllers/core/com/auth/logouts_controller.rb`
- `app/controllers/core/org/auth/logouts_controller.rb`

_Concerns:_

- `app/controllers/concerns/oidc_rp_logout.rb` — remove `notice:` from `redirect_to` (flash
  violation)

**Route changes:**

On each Acme and Core host, add inside existing `namespace :auth`:

```ruby
# RP login start
resource :authorization, only: :show, path: ""   # → GET /auth

# RP local logout
resource :logout, only: :create                   # → POST /auth/logout
```

Note: `GET /auth/callback` already exists under `namespace :auth` on all relevant hosts. This phase
adds the missing two endpoints to complete the contract.

**Controller changes:**

`AuthorizationsController` delegates to the same logic as `Sso::AuthorizationsController`:

```ruby
def show
  url = initiate_oidc_session!
  redirect_to_oidc_authorization_url(url)
end
```

`LogoutsController` includes `OidcRpLogout` (same as `Sso::LogoutsController`).

`OidcRpLogout#create` must be fixed to not use `notice:`:

```ruby
def create
  log_out
  redirect_to("/", allow_other_host: false, status: :see_other)
  # Do not use notice: — render feedback inline or via the post-logout landing page
end
```

**Test changes:**

- Add positive assertions to `acme_route_contract_test.rb` for `GET /auth`, `POST /auth/logout`
- Add positive assertions to `core_route_contract_test.rb` for `GET /auth`, `POST /auth/logout`
- Add tests for `Auth::AuthorizationsController` on each surface
- Add tests for `Auth::LogoutsController` on each surface

**Compatibility concerns:**

- This phase is additive only. Existing `/sso/*` paths continue to work.
- No client redirect URIs change.
- No registered clients change.

**Rollback strategy:** Remove the new route entries and controller files. No data changes.

**Acceptance criteria:**

- `GET /auth` resolves on Core app/com/org and Acme app/com/org
- `POST /auth/logout` resolves on Core app/com/org and Acme app/com/org
- `GET /auth/callback` continues to resolve (already existed)
- `OidcRpLogout#create` no longer uses Rails flash
- Route contract tests updated to assert new routes

---

### Phase 2: Retire /sso/\* From RP Login Flows

**Goal:** Remove `/sso/authorize` and `/sso/logout` from Acme and Core.

**Scope:** Acme (app, com, org), Core (app, com, org). Views and tests.

**Non-goals:** Do not touch Sign ceremony. Do not touch Acme `/oauth/authorize` (OP endpoint).

**Prerequisite:** Phase 1 must be complete and green.

**Files likely touched:**

_Views (all references to sso route helpers):_

- `app/views/layouts/acme/app/application.html.erb` — replace `acme_app_sso_authorization_path` with
  `acme_app_auth_authorization_path`, replace `acme_app_sso_logout_path` with
  `acme_app_auth_logout_path`
- `app/views/layouts/acme/com/application.html.erb` — same substitution for com helpers
- `app/views/layouts/acme/org/application.html.erb` — same substitution for org helpers

_Tests:_

- `test/controllers/acme/app/roots_controller_test.rb` — update path assertions
- `test/integration/routes/acme_route_contract_test.rb` — remove positive assertions for
  `/sso/authorize` and `/sso/logout`; add negative assertions
- `test/integration/routes/core_route_contract_test.rb` — same

_Routes:_

- `config/routes/acme.rb` — remove `namespace :sso` blocks from each host
- `config/routes/core.rb` — remove `namespace :sso` blocks

_Controllers (candidates for deletion after confirming no remaining references):_

- `app/controllers/acme/app/sso/authorizations_controller.rb`
- `app/controllers/acme/com/sso/authorizations_controller.rb`
- `app/controllers/acme/org/sso/authorizations_controller.rb`
- `app/controllers/acme/app/sso/logouts_controller.rb`
- `app/controllers/acme/com/sso/logouts_controller.rb`
- `app/controllers/acme/org/sso/logouts_controller.rb`
- `app/controllers/core/app/sso/authorizations_controller.rb`
- `app/controllers/core/com/sso/authorizations_controller.rb`
- `app/controllers/core/org/sso/authorizations_controller.rb`
- `app/controllers/core/app/sso/logouts_controller.rb`
- `app/controllers/core/com/sso/logouts_controller.rb`
- `app/controllers/core/org/sso/logouts_controller.rb`

**Route changes:** Remove from each Acme and Core host:

```ruby
namespace :sso do
  resource :authorization, only: :show, path: "authorize"
  resource :logout, only: :create
end
```

**Controller changes:**

- Delete 12 Sso controller files listed above (after verifying no callers remain)
- Confirm that `Sso::AuthorizationsController`'s behaviour is now covered by
  `Auth::AuthorizationsController`

**Test changes:**

- Remove all positive assertions for `/sso/authorize` and `/sso/logout` from route contract tests
- Add negative assertions that `/sso/authorize` and `/sso/logout` no longer resolve
- Update `roots_controller_test.rb` to reference new auth path helpers

**Compatibility concerns:**

- Any external bookmark or hardcoded reference to `/sso/authorize` will break. Assess whether a
  temporary redirect is needed. Given these are browser-driven login start paths (not registered
  OIDC redirect URIs), no redirect should be needed — unauthenticated users will hit the application
  and be redirected to `/auth` naturally.
- If any external client uses `/sso/authorize` in a hardcoded way, that is a separate issue.

**Rollback strategy:** Re-add the `namespace :sso` blocks and restore the controller files from git.

**Acceptance criteria:**

- `GET /sso/authorize` returns 404 on all Acme and Core hosts
- `POST /sso/logout` returns 404 on all Acme and Core hosts
- `GET /auth` and `POST /auth/logout` work correctly as replacements
- Layout views render correct path helpers
- No NameError from deleted route helpers in views or controllers

---

### Phase 3: Normalize Sign Ceremony Routes

**Goal:** Rename `/sign/in/entrance` and `/sign/up/entrance` to canonical `/sign/in` and `/sign/up`.

**Scope:** Sign (app, com, org).

**Non-goals:** Do not rename the `EntrancesController` classes yet. Do not rename `/sign/in/check`
or deeper ceremony routes in this phase.

**Scale warning:** `sign_app_sign_in_entrance_url` / `sign_app_sign_in_entrance_path` (and com/org
variants) are referenced in 20+ locations across controllers and concerns:

- `authentication_client.rb`
- `authentication_visitor.rb`
- `authentication_operator.rb`
- `social_callback_guard.rb`
- `sign_up_sequence_controller_support.rb`
- `acme/app/oauth/authorizations_controller.rb`
- `acme/com/oauth/authorizations_controller.rb`
- `acme/org/oauth/authorizations_controller.rb`
- `acme/app/dev/r18/private_smokes_controller.rb`
- `acme/app/social/authentications_controller.rb`
- Multiple Sign ceremony controllers

**Decision required:** Choose one of:

1. **Additive alias approach:** Add new routes `GET /sign/in` and `GET /sign/up` pointing to
   `EntrancesController#show`. Leave `/sign/in/entrance` active as a redirect to `/sign/in`. Update
   callers in a follow-up. Mark entrance routes as deprecated in routes comment.
2. **Direct rename:** Change route definitions from `resource :entrance, only: :show` to
   `resource :in, only: %i(show create), path: ""` (or similar). Update all 20+ callers in the same
   commit. Higher blast radius but no redirect maintenance.

Recommendation: Use **additive alias** for Phase 3. Add new canonical routes first. Update callers
to use new path helpers in the same commit. Mark old routes as deprecated. Remove old routes in
Phase 7.

**Files likely touched:**

- `config/routes/sign.rb` — all three host blocks
- `app/controllers/concerns/authentication_client.rb`
- `app/controllers/concerns/authentication_visitor.rb`
- `app/controllers/concerns/authentication_operator.rb`
- `app/controllers/concerns/social_callback_guard.rb`
- `app/controllers/concerns/sign_up_sequence_controller_support.rb`
- `app/controllers/acme/app/oauth/authorizations_controller.rb`
- `app/controllers/acme/com/oauth/authorizations_controller.rb`
- `app/controllers/acme/org/oauth/authorizations_controller.rb`
- Multiple Sign ceremony controllers
- `test/integration/routes/sign_route_contract_test.rb`

**Route changes (per host):**

```ruby
namespace :sign do
  namespace :in do
    # Canonical: replaces /sign/in/entrance
    resource :session_start, only: :show, path: ""     # GET /sign/in
    # ... existing sub-routes stay unchanged ...

    # Deprecated alias (kept until Phase 7)
    # resource :entrance, only: :show                  # kept temporarily
  end
  namespace :up do
    # Canonical: replaces /sign/up/entrance
    resource :session_start, only: :show, path: ""     # GET /sign/up
    # ... existing sub-routes stay unchanged ...

    # Deprecated alias (kept until Phase 7)
    # resource :entrance, only: :show                  # kept temporarily
  end
end
```

Actually, this is tricky because `path: ""` within `namespace :in` gives `/sign/in` which is what we
want. We need to evaluate whether any `GET /sign/in/email` or other sub-resource conflicts with
this. Looking at the routes, `namespace :in` has `resource :email`, `resource :passkey`, etc. — all
sub-paths, so `resource :session_start, only: :show, path: ""` for `GET /sign/in` should work.

**Controller changes:** None structurally. Route new path to existing `EntrancesController#show`.

**Test changes:**

- Update `sign_route_contract_test.rb` to assert canonical `/sign/in` and `/sign/up`
- Keep deprecated route assertions until Phase 7
- Add negative assertion that `/sign/in/entrance` returns 404 (only after Phase 7)

**Compatibility concerns:**

- OmniAuth redirects use `sign_app_sign_in_entrance_path` — must be updated
- Acme OAuth `start_authorization_ceremony!` redirects to Sign entrance — must be updated
- All 20+ callers must be updated in the same commit

**Rollback strategy:** Remove new route entries; restore caller references from git.

**Acceptance criteria:**

- `GET /sign/in` resolves to the same controller/action as current `GET /sign/in/entrance`
- `GET /sign/up` resolves to the same controller/action as current `GET /sign/up/entrance`
- All callers use new path helpers
- Route contract tests assert canonical paths

---

### Phase 4: Clarify Base RP Ownership

**Goal:** Make an explicit decision about who owns the `base-rails-rp` client and its callback.

**Current state:**

- Client ID: `base-rails-rp`
- Client comment in registry: `"Acme/Base Rails browser RP"`
- Redirect URIs: Point to Acme hosts (`ACME_SERVICE_URL`, `ACME_STAFF_URL`, `ACME_CORPORATE_URL`)
- Callback controller: `Acme::App::Auth::CallbacksController` (and com/org equivalents)
- Base host routes: No auth routes

**Decision options:**

**Option A: Acme owns this client explicitly (recommended)**

The redirect URIs already point to Acme hosts. The callback controller already lives under
`Acme::*`. The Base Rails surface (`BASE_SERVICE_URL`) has its own host with no auth routes. This
arrangement means "Acme's own local browser session login" is implemented as an RP login against
itself, using the client ID `base-rails-rp`.

Action:

- Rename client to `acme-self-rp` in `OidcClientRegistry`
- Update `oidc_client_id` in all three `Acme::*::Auth::CallbacksController` files
- Update `app/controllers/acme/*/application_controller.rb` references
- No route changes needed
- No new controllers needed
- Add explicit comment in the registry explaining this is Acme's own browser RP client

**Option B: Give Base its own callback endpoint (not recommended)**

This would require adding `GET /auth/callback` to the Base surface (under `BASE_SERVICE_URL`),
creating `Base::*::Auth::CallbacksController` files, and changing redirect URIs in the registry to
point to Base hosts. This is a much larger change and only makes sense if Base is intended to serve
HTML and issue its own local sessions (which the current route file suggests it does not do).

**Files likely touched (Option A):**

- `app/services/oidc_client_registry.rb`
- `app/controllers/acme/app/auth/callbacks_controller.rb`
- `app/controllers/acme/com/auth/callbacks_controller.rb`
- `app/controllers/acme/org/auth/callbacks_controller.rb`
- `app/controllers/acme/app/application_controller.rb` (has `"base-rails-rp"` reference)
- `app/controllers/acme/com/application_controller.rb`
- `app/controllers/acme/org/application_controller.rb`

**Test changes:**

- Update test fixtures or stubs that reference `"base-rails-rp"` client ID

**Acceptance criteria (Option A):**

- No code references to `"base-rails-rp"` remain
- `Acme::*::Auth::CallbacksController#oidc_client_id` returns the new name
- Registry comment is clear: "Acme browser RP — handles local session login for the Acme surface"

---

### Phase 5: Clarify Palm Claimed-HTTPS Native Contract

**Goal:** Document and finalize Palm's native redirect URI strategy.

**Current state:**

- `app-ios-rp` uses custom scheme `umaxica://oauth/callback`
- `app-android-rp` uses custom scheme `com.umaxica.app:/oauth/callback`
- Palm's `/oauth/callback` Rails endpoint is an informational stub (no session creation, no token
  exchange)
- `/oauth/callback/ios` and `/oauth/callback/android` are also stubs

**Decision required:**

**Question:** Should Palm move to claimed HTTPS redirect URIs?

Universal Links (iOS) and App Links (Android) require HTTPS redirect URIs registered with the server
and claimed by the app's signed domain. Custom schemes work but are less secure (other apps on the
device can intercept them).

**Option A: Keep custom scheme (low migration cost)**

- Less secure but simpler
- No changes to `OidcClientRegistry` redirect URIs
- No changes to Rails routes
- Document that this is intentional

**Option B: Move to claimed HTTPS (higher security)**

- Requires Palm app update to handle Universal/App Links
- Requires adding HTTPS redirect URIs to `OidcClientRegistry`
- Rails `/oauth/callback` stub stays but gets HTTPS as primary
- Remove `/oauth/callback/ios` and `/oauth/callback/android` stubs (or keep for backward compat)
- Requires `.well-known/apple-app-site-association` and `.well-known/assetlinks.json` endpoints

**Palm login-start route decision:**

Recommendation: **Option D — no Rails login-start route; app directly opens Acme
`/oauth/authorize`.**

Native apps typically encode the Acme authorization URL directly (as a deep link or build
configuration), rather than routing through a Rails intermediary. Adding `GET /auth` or `GET /login`
on Palm creates an unnecessary hop and suggests Palm is a web RP (it is not).

**Cleanup candidates:**

- `/oauth/callback/ios` and `/oauth/callback/android` are dead if claims work correctly (app
  intercepts the callback before it reaches the server). Remove in Phase 7 if confirmed.

**Files likely touched:**

- `app/services/oidc_client_registry.rb` (if HTTPS URIs added)
- `config/routes/palm.rb` (if platform stubs removed)
- `test/integration/routes/palm_route_contract_test.rb`

**Acceptance criteria:**

- Decision documented in an ADR
- Either custom-scheme redirect URIs are explicitly documented as intentional, or HTTPS redirect
  URIs are registered and the app is updated
- If HTTPS: PKCE is tested in route/integration tests
- If HTTPS: No client secret accepted for Palm clients (already correct —
  `token_endpoint_auth_method: "none"`)

---

### Phase 6: Decide and Plan Acme Provider Endpoint Shape

**Goal:** Make an explicit decision on whether to keep `/oauth/*` or move to root-level OIDC paths.

**Current state:**

- Acme exposes `/oauth/authorize`, `/oauth/token`, `/oauth/userinfo`, `/oauth/revoke`, `/oauth/jwks`
- Discovery document at `/.well-known/openid-configuration` advertises these paths
- All existing RP clients (`sign-rp`, `acme-self-rp`, `core-next-rp`, `app-ios-rp`,
  `app-android-rp`) are configured with `/oauth/authorize` and `/oauth/token` URLs via
  `OidcSsoInitiator`

---

**Option A: Keep /oauth/\* endpoints**

Required changes: None.

Pros:

- Zero migration risk
- Discovery document already matches actual routes
- Client code in `OidcSsoInitiator` hardcodes `/oauth/authorize` and `/oauth/token` — no changes
- Protocol prefix is explicit and avoids root-level path collision risk
- Many production OIDC providers use protocol-prefixed paths (e.g., `/oauth2/*`)

Cons:

- Slightly longer URLs
- Less minimal than pure OIDC spec examples

Client compatibility risk: Zero — no client change needed. Discovery metadata change: None. Route
helper change: None. Controller change: None.

---

**Option B: Move to root-level endpoints**

Target:

```
GET  /authorize
POST /token
GET  /userinfo
POST /revoke
GET  /jwks
```

Required changes:

- Update `config/routes/acme.rb` for each host: rename `namespace :oauth` blocks
- Rename or alias all `Acme::*::Oauth::*` controllers to `Acme::*::*` (or keep controller names but
  change routes)
- Update `OidcSsoInitiator#oidc_authorization_url` (currently hardcodes `/oauth/authorize`)
- Update `OidcSsoInitiator#oidc_token_url` (currently hardcodes `/oauth/token`)
- Update `OidcDiscoveryDocument.for_resource_type` — must advertise new paths
- Update all registered clients if they hardcode the old URLs
- Add redirect aliases from `/oauth/authorize` etc. for a transition period

Client compatibility risk: **HIGH** — any client that cached the discovery document before the
change will have stale endpoint URLs. Apple and Google OAuth integrations in Sign's OmniAuth config
(those are outbound clients, not Acme-endpoint consumers, so less relevant) stay intact.

Route helper change: All `*_oauth_authorization_*` helpers become `*_authorization_*` etc.

Deployment risk: **HIGH** — must update discovery document and routes atomically. Any window where
discovery advertises new paths but old routes still serve creates a failure.

**Recommendation:** Choose Option A. The `/oauth/*` prefix is not incorrect and migration cost is
very high relative to the benefit. Revisit only if a spec compliance audit identifies a concrete
requirement for root-level paths.

**Files that would be touched (Option B only):**

- `config/routes/acme.rb`
- `app/controllers/concerns/oidc_sso_initiator.rb`
- `app/services/oidc_discovery_document.rb`
- All `Acme::*::Oauth::*` controller directories
- `test/integration/routes/acme_route_contract_test.rb`

**Acceptance criteria (either option):**

- `/.well-known/openid-configuration` advertises exactly the paths that resolve
- No RP has hardcoded a stale path
- `GET /authorize`, `POST /token`, `GET /userinfo` do NOT resolve on Core, Sign, Base, or Palm
  (important isolation boundary)

---

### Phase 7: Remove Legacy Aliases and Dead Controller Inventory

**Goal:** Final cleanup after canonical routes are confirmed green.

**Prerequisite:** All previous phases complete and passing in CI.

**Cleanup candidates:**

| Artifact                                               | Status                                       | Action                                          |
| ------------------------------------------------------ | -------------------------------------------- | ----------------------------------------------- |
| `Acme::*::Sso::AuthorizationsController`               | Replaced by `Auth::AuthorizationsController` | Delete if Phase 2 complete                      |
| `Acme::*::Sso::LogoutsController`                      | Replaced by `Auth::LogoutsController`        | Delete if Phase 2 complete                      |
| `Core::*::Sso::AuthorizationsController`               | Replaced by `Auth::AuthorizationsController` | Delete if Phase 2 complete                      |
| `Core::*::Sso::LogoutsController`                      | Replaced by `Auth::LogoutsController`        | Delete if Phase 2 complete                      |
| `Sign::*::Sign::In::EntrancesController`               | Replaced by canonical route                  | Rename to `SessionStartsController` or delete   |
| `Sign::*::Sign::Up::EntrancesController`               | Replaced by canonical route                  | Rename to `SessionStartsController` or delete   |
| `/sign/in/entrance` route                              | Deprecated in Phase 3                        | Remove                                          |
| `/sign/up/entrance` route                              | Deprecated in Phase 3                        | Remove                                          |
| `Acme::App::Oauth::UserInfoController`                 | Duplicate of `UserinfosController`           | Investigate; delete if dead                     |
| `Acme::*::WellKnown::JwksController`                   | Separate from `Oauth::JwksController`        | Keep (different path: `/.well-known/jwks.json`) |
| `Palm::App::Oauth::Callback::IosController`            | Platform stub                                | Evaluate; remove if Palm moves to HTTPS         |
| `Palm::App::Oauth::Callback::AndroidController`        | Platform stub                                | Evaluate; remove if Palm moves to HTTPS         |
| `Sign::App::Oidc::BackchannelLogoutsController` (flat) | Superseded by nested backchannel             | Verify no route; delete                         |

**Duplicate controller investigation needed:**

`Acme::App::Oauth::UserInfoController` (singular) vs `Acme::App::Oauth::UserinfosController`
(plural) — both exist. One appears to be the active route target (confirmed by route contract test
asserting `acme/app/oauth/userinfos`), the other (`user_info_controller.rb`) is unused. Verify then
delete the unused one.

**Required checks before deletion:**

- `grep -rn "UserInfoController\|user_info_controller" app test config` — confirm zero live
  references
- Run route contract tests to confirm paths still resolve

**Test changes:**

- Remove assertions for retired paths
- Add negative assertions (already added in Phase 0) for every removed path
- Remove controller tests for deleted controllers

**Acceptance criteria:**

- No dead route helpers in the application
- No duplicate controller implementing the same protocol concept
- No test asserts `/sso/authorize`, `/sso/logout`, `/sign/in/entrance`, or `/sign/up/entrance` as a
  canonical path
- `bin/rails routes | grep -E 'sso/(authorize|logout)'` returns empty on Acme and Core hosts

---

## F. Exact Route Changes By Surface

### Acme (app, com, org) — changes per phase

**Phase 1 adds:**

```ruby
namespace :auth do
  resource :callback, only: :show          # Already exists — unchanged
  resource :authorization, only: :show, path: ""   # NEW: GET /auth
  resource :logout, only: :create          # NEW: POST /auth/logout
end
```

**Phase 2 removes:**

```ruby
namespace :sso do
  resource :authorization, only: :show, path: "authorize"
  resource :logout, only: :create
end
```

### Core (app, com, org) — changes per phase

**Phase 1 adds:**

```ruby
namespace :auth do
  resource :callback, only: :show          # Already exists — unchanged
  resource :authorization, only: :show, path: ""   # NEW: GET /auth
  resource :logout, only: :create          # NEW: POST /auth/logout
end
```

**Phase 2 removes:**

```ruby
namespace :sso do
  resource :authorization, only: :show, path: "authorize"
  resource :logout, only: :create
end
```

### Sign (app, com, org) — changes in Phase 3

**Phase 3 adds:**

```ruby
namespace :sign do
  namespace :in do
    resource :session_start, only: :show, path: ""   # NEW: GET /sign/in
    # ... existing sub-routes unchanged ...
    # resource :entrance, only: :show                # deprecated; remove in Phase 7
  end
  namespace :up do
    resource :session_start, only: :show, path: ""   # NEW: GET /sign/up
    # ...
  end
end
```

**Phase 7 removes:**

```ruby
# resource :entrance, only: :show  # in each of :in and :up namespaces
```

### Base — no auth route changes expected

Option A for Phase 4 adds no routes to Base.

### Palm — Phase 5 decision

If Option A (keep custom scheme): no route changes. If Option B (claimed HTTPS): `/oauth/callback`
stub is already present. `/oauth/callback/ios` and `/oauth/callback/android` stubs removed in
Phase 7.

---

## G. Controller / Namespace Ownership Plan

| Surface  | Role                    | Controller Namespace                               | Notes                                |
| -------- | ----------------------- | -------------------------------------------------- | ------------------------------------ |
| Acme app | OP/AS provider          | `Acme::App::Oauth::*`                              | Keep as-is                           |
| Acme app | Self RP (local session) | `Acme::App::Auth::*`                               | Rename client to `acme-self-rp`      |
| Acme app | Sign-out bridge         | `Acme::App::Sign::OutsController`                  | Keep as-is                           |
| Core app | BFF RP                  | `Core::App::Auth::*`                               | Add `AuthorizationsController`       |
| Core app | Backchannel receiver    | `Core::App::Oidc::Backchannel::LogoutsController`  | Keep as-is                           |
| Sign app | Credential gateway RP   | `Sign::App::Auth::CallbacksController`             | Keep as-is                           |
| Sign app | OmniAuth callbacks      | `Sign::App::Auth::OmniauthCallbacksController`     | Keep as-is; note namespace collision |
| Sign app | Ceremony                | `Sign::App::Sign::In::*`, `Sign::App::Sign::Up::*` | Add canonical entry controllers      |
| Base     | No auth                 | (none)                                             | Confirmed no auth routes             |
| Palm     | Native stub             | `Palm::App::Oauth::CallbacksController`            | Stub only; no session                |

**OmniAuth namespace note:** `Sign::App::Auth::OmniauthCallbacksController` lives under the same
`auth/` namespace as `Sign::App::Auth::CallbacksController`. The OmniAuth routes
(`/auth/google_app/callback`, `/auth/apple/callback`) are social IdP callbacks, not OIDC RP
callbacks. This is an accepted conceptual overlap because OmniAuth expects its callbacks under
`/auth/<provider>/callback`. The naming is constrained by the OmniAuth gem. Do not attempt to rename
these.

---

## H. Test Plan

### Web RP route assertions (positive)

Add to each relevant route contract test:

```ruby
# Core
assert_recognizes({ controller: "core/app/auth/authorizations", action: "show" },
                  { path: "http://#{CORE_APP_HOST}/auth", method: :get })
assert_recognizes({ controller: "core/app/auth/logouts", action: "create" },
                  { path: "http://#{CORE_APP_HOST}/auth/logout", method: :post })
# repeat for com, org

# Acme
assert_recognizes({ controller: "acme/app/auth/authorizations", action: "show" },
                  { path: "http://#{ACME_APP_HOST}/auth", method: :get })
assert_recognizes({ controller: "acme/app/auth/logouts", action: "create" },
                  { path: "http://#{ACME_APP_HOST}/auth/logout", method: :post })
# repeat for com, org
```

### Web RP route assertions (negative — after Phase 2)

```ruby
assert_raises(ActionController::RoutingError) do
  Rails.application.routes.recognize_path("http://#{CORE_APP_HOST}/sso/authorize", method: :get)
end
assert_raises(ActionController::RoutingError) do
  Rails.application.routes.recognize_path("http://#{CORE_APP_HOST}/sso/logout", method: :post)
end
assert_raises(ActionController::RoutingError) do
  Rails.application.routes.recognize_path("http://#{ACME_APP_HOST}/sso/authorize", method: :get)
end
assert_raises(ActionController::RoutingError) do
  Rails.application.routes.recognize_path("http://#{ACME_APP_HOST}/sso/logout", method: :post)
end
```

Provider-isolation negative tests (RP surfaces must not expose OP endpoints):

```ruby
# Core must not expose provider endpoints
%w(authorize token userinfo jwks).each do |path|
  assert_raises(ActionController::RoutingError) do
    Rails.application.routes.recognize_path("http://#{CORE_APP_HOST}/#{path}", method: :get)
  end
  assert_raises(ActionController::RoutingError) do
    Rails.application.routes.recognize_path("http://#{CORE_APP_HOST}/oauth/#{path}", method: :get)
  end
end
```

### Sign ceremony route assertions (positive — Phase 3)

```ruby
assert_recognizes({ controller: "sign/app/sign/in/session_starts", action: "show" },
                  { path: "http://#{SIGN_APP_HOST}/sign/in", method: :get })
assert_recognizes({ controller: "sign/app/sign/up/session_starts", action: "show" },
                  { path: "http://#{SIGN_APP_HOST}/sign/up", method: :get })
# repeat for com, org
```

### Sign ceremony route assertions (negative — Phase 7)

```ruby
assert_raises(ActionController::RoutingError) do
  Rails.application.routes.recognize_path("http://#{SIGN_APP_HOST}/sign/in/entrance", method: :get)
end
assert_raises(ActionController::RoutingError) do
  Rails.application.routes.recognize_path("http://#{SIGN_APP_HOST}/sign/up/entrance", method: :get)
end
```

### Acme provider endpoints (existing — do not change)

Existing `AcmeRouteContractTest` already asserts `/oauth/authorize`, `/oauth/token`,
`/oauth/userinfo`, `/oauth/revoke`, `/oauth/jwks`. Keep these unchanged.

### Palm native (existing + Phase 5)

If Phase 5 chooses custom scheme: keep existing positive assertions for `/oauth/callback`,
`/oauth/callback/ios`, `/oauth/callback/android`.

If Phase 5 moves to claimed HTTPS: update assertions; remove platform stubs from assertions in
Phase 7.

Palm security property tests (should exist regardless of option):

```ruby
test "palm clients do not use client secret" do
  ios_client = OidcClientRegistry.find("app-ios-rp")
  assert ios_client.public_client?
  assert_nil ios_client.client_secret
end

test "palm clients use token_endpoint_auth_method none" do
  ios_client = OidcClientRegistry.find("app-ios-rp")
  assert_equal "none", ios_client.registered_token_endpoint_auth_method
end
```

### Flash violation fix (Phase 1)

```ruby
test "POST /auth/logout does not set flash notice" do
  # ... setup authenticated session ...
  post auth_logout_url, headers: ...
  assert flash.empty?
  assert_response :redirect
end
```

---

## I. Compatibility and Migration Strategy

### /sso/\* deprecation

The `/sso/authorize` and `/sso/logout` paths are internal paths used by:

- Acme layout views (direct route helper references — will be updated in Phase 2)
- Route contract tests (will be updated in Phase 2)
- No registered OIDC redirect URIs point to `/sso/*`
- No external client documentation references these paths

No public redirect aliases needed. Remove directly.

### Sign /entrance deprecation

The `/sign/in/entrance` and `/sign/up/entrance` paths are:

- Used by 20+ internal controller/concern references (update in Phase 3)
- Asserted in `sign_route_contract_test.rb` (update in Phase 3)
- Used by OmniAuth failure redirects (update in Phase 3)
- Used by `start_authorization_ceremony!` in Acme OAuth controllers (update in Phase 3)

Keep old route alive as redirect for one release cycle if needed for graceful degradation (e.g., if
any cached in-flight session carries the old entrance URL in a `return_to` field).

### base-rails-rp rename

The client ID is an internal identifier. No external party has registered this client ID. It appears
only in:

- `OidcClientRegistry` (1 location)
- Three `Acme::*::Auth::CallbacksController` files (3 locations)
- Three `Acme::*::ApplicationController` files (3 locations)
- Token records in the database (check whether the DB stores the client ID in a column)

**Important:** Check whether any database table stores `client_id = "base-rails-rp"` in issued
tokens, authorization codes, or sessions. If yes, a data migration must accompany the rename, or the
old ID must remain valid during a transition.

Run before implementing Phase 4:

```sh
grep -rn '"base-rails-rp"' app test db
# Check DB: SELECT DISTINCT client_id FROM oidc_access_tokens WHERE client_id = 'base-rails-rp';
```

---

## J. Open Decisions

1. **base-rails-rp rename target:** Is `acme-self-rp` the right name, or should it be
   `acme-browser-rp` or `acme-local-rp`? Decide before Phase 4.

2. **Phase 4 option choice:** Option A (keep callback on Acme) vs. Option B (give Base its own auth
   routes). Based on current evidence, Option A is correct, but confirm intent.

3. **Phase 5 Palm redirect URI strategy:** Custom scheme vs. claimed HTTPS. Requires native app team
   input.

4. **Phase 5 Palm login-start route:** None (recommended). Confirm with mobile team that the app
   encodes the Acme `/oauth/authorize` URL directly.

5. **Phase 6 Acme provider endpoint shape:** Option A (keep `/oauth/*`) is recommended. Confirm
   before scheduling any work on this.

6. **Sign ceremony route naming:** `/sign/in` (resource root approach) vs. keeping
   `/sign/in/entrance` long-term and just adding alias. If the ceremony router adds `POST /sign/in`
   for credential submission, there will be both `GET /sign/in` and `POST /sign/in` on the same path
   — verify this is intended and does not conflict with existing sub-routes.

7. **`OidcRpLogout` flash notice replacement:** After removing the flash `notice:`, how should the
   local-logout confirmation be communicated to the user? Options include: a query param on the
   redirect URL, a dedicated signed-out landing page, or a session-based inline message on the next
   page load. The current signed-out pages at `/signed-out` on Sign may be the right landing target.

8. **`Acme::App::Oauth::UserInfoController` vs `UserinfosController` duplicate:** Verify which is
   live, which is dead, and delete the dead one in Phase 7.

---

## K. Recommended First Implementation Prompt

Use this prompt to implement only Phase 1 and Phase 2 after this planning pass:

---

```
You are implementing Phase 1 and Phase 2 of the OIDC routing cleanup for this Rails application.

Context is in research/2026-06-16-oidc-routing-cleanup-remediation-plan.md.

Before implementing, read:
- .agents/harnesses/rules/generic/controllers.mdc
- .agents/harnesses/rules/generic/routing.mdc
- .agents/harnesses/rules/project/surfaces.mdc
- .agents/harnesses/rules/generic/no-flash-messages.mdc

## Phase 1: Add canonical GET /auth and POST /auth/logout

Add the following routes to each host block in config/routes/acme.rb and config/routes/core.rb,
inside the existing `namespace :auth` block:

  resource :authorization, only: :show, path: ""   # → GET /auth
  resource :logout, only: :create                   # → POST /auth/logout

Create the following new controller files (one per surface × two actions × two engines):

  app/controllers/acme/app/auth/authorizations_controller.rb
  app/controllers/acme/com/auth/authorizations_controller.rb
  app/controllers/acme/org/auth/authorizations_controller.rb
  app/controllers/acme/app/auth/logouts_controller.rb
  app/controllers/acme/com/auth/logouts_controller.rb
  app/controllers/acme/org/auth/logouts_controller.rb
  app/controllers/core/app/auth/authorizations_controller.rb
  app/controllers/core/com/auth/authorizations_controller.rb
  app/controllers/core/org/auth/authorizations_controller.rb
  app/controllers/core/app/auth/logouts_controller.rb
  app/controllers/core/com/auth/logouts_controller.rb
  app/controllers/core/org/auth/logouts_controller.rb

Each AuthorizationsController delegates to the same logic as the existing Sso::AuthorizationsController
on the same surface. Read the existing controllers for the pattern.

Each LogoutsController includes OidcRpLogout.

Fix OidcRpLogout#create to not use notice: — redirect without flash per no-flash-messages rule.
Do not add a replacement inline message in this phase; just remove the notice.

Add route contract test assertions for the new routes in:
  test/integration/routes/acme_route_contract_test.rb
  test/integration/routes/core_route_contract_test.rb

Run: bin/rails test test/integration/routes/acme_route_contract_test.rb
Run: bin/rails test test/integration/routes/core_route_contract_test.rb

## Phase 2: Remove /sso/* from RP login flows

Prerequisite: Phase 1 tests are green.

1. Update three Acme layout views to use new auth path helpers:
   - app/views/layouts/acme/app/application.html.erb
   - app/views/layouts/acme/com/application.html.erb
   - app/views/layouts/acme/org/application.html.erb

   Replace:
     acme_app_sso_authorization_path  →  acme_app_auth_authorization_path
     acme_app_sso_logout_path         →  acme_app_auth_logout_path
   (and com/org equivalents)

   Also update test/controllers/acme/app/roots_controller_test.rb if it asserts these paths.

2. Remove namespace :sso blocks from config/routes/acme.rb and config/routes/core.rb.

3. Delete the 12 Sso controller files:
   app/controllers/acme/{app,com,org}/sso/authorizations_controller.rb
   app/controllers/acme/{app,com,org}/sso/logouts_controller.rb
   app/controllers/core/{app,com,org}/sso/authorizations_controller.rb
   app/controllers/core/{app,com,org}/sso/logouts_controller.rb

4. Update route contract tests:
   - Remove positive assertions for /sso/authorize and /sso/logout
   - Add negative assertions (assert_raises RoutingError) for /sso/authorize and /sso/logout

Run the full route contract test suite:
  bin/rails test test/integration/routes/

Run the roots controller test:
  bin/rails test test/controllers/acme/app/roots_controller_test.rb

Do not touch Sign, Base, or Palm. Do not touch /oauth/* provider endpoints.
Do not implement Phase 3 or later in this pass.
```

---

_This memo is exploratory. Promote decisions to ADR once confirmed. Update docs/ once implemented._
