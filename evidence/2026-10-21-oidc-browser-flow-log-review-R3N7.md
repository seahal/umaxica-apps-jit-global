# OIDC browser flow review from the development log (APP surface)

- Date: 2026-10-21
- Commit: `febec3225cc9a0cfa53b9cbe817d20d366aba5a2`
- Worktree: uncommitted changes present (org invitation services, ADRs, sign-out React screens).
  None of the changed files are on the request paths reviewed here; the running server's code
  state at request time was not independently confirmed.
- Source: `log/development.log` (manual browser session on `www.umaxica.app` /
  `auth.umaxica.app`, approx. 09:58–10:10 UTC). `jump.umaxica.net` requests are not in this log.
- Method: read the request sequence, then the controllers, views and ADR text named below. No
  code was changed and no tests were run.

## 1. Five user clicks before the sign-in form appears

Observed for one successful pass (log lines ~2493–2642). Every intermediate page is a single
`Continue` button posting a form; no page asks the user to decide anything after step 1.

| # | Page (GET 200) | POST on click | Next |
|---|---|---|---|
| 1 | Base `GET /sign` (`shared/oidc_rp_sign_entries/show`) | `Base::App::Sign::EntriesController#create` | Base `/oauth/authorize` |
| 2 | Base `GET /oauth/authorize` (`base/shared/authorization_ceremony_start`) | `AuthorizationsController#create` (`ceremony_action=start`) | `jump.umaxica.net` → Auth `/sign/in?entry_ref=` |
| 3 | Auth `/sign/in` (`auth/shared/admission_continuation`) | `Auth::App::CeremonyBindingsController#create` | Base `/ceremony_bindings/:ref/confirmation` |
| 4 | Base binding confirmation (`base/shared/ceremony_binding_confirmation`) | `CeremonyBindingConfirmationsController#create` | Auth `/sign/in?entry_ref=` |
| 5 | Auth `/sign/in` (`admission_continuation`, second time) | `Auth::App::Sign::InsController#create` | Auth `/sign/in` (Inertia sign-in form) |

Whether the Jump hop shows an interstitial (a possible sixth click) is not visible here.

Assessment:

- Only click 1 expresses user intent. Clicks 2–5 are machine relays.
- Click 2: OIDC Core 1.0 §3.1.2.1 requires the authorization endpoint to accept GET; state and
  PKCE already bind the request. No ADR text found that requires a button on `GET /oauth/authorize`.
  Not yet traced in code why the start page exists.
- Clicks 3–5 are required to stay POST by `adr/base-auth-ceremony-and-seven-rp-boundary.md`
  ("Base-to-Auth admission transport amendment", 2026-09-21: GET is non-consuming; consumption
  is a CSRF-protected POST). Converting them to GET is a security decision (login CSRF / session
  fixation), not a UX tweak.
- The same `admission_continuation` page renders twice with different form targets, which reads
  to the user as a repeated screen.
- Lowest-risk reduction: keep the POSTs and CSRF tokens but auto-submit the relay forms
  (nonce'd script, `<noscript>` button). Precedents already exist:
  `app/views/auth/shared/step_up_cancellation.html.erb:13`,
  `adr/social-omniauth-callback-transport.md:38`, `docs/design.md:134`; CSP uses
  `content_security_policy_nonce_auto = true`.

## 2. Cancel and Switch from the Auth first page fail with 422 (defect)

Observed twice (Switch to sign-up at ~10:09:35, Cancel at ~10:10:13):

```
Auth Sign::SwitchesController#create / Sign::CancellationsController#create  303 → jump
Base GET /oauth/authorize?rt=…        303 (jump_return.accepted)
Base GET /oauth/authorize?switch_handoff=… | ?cancellation_ref=…&transaction_ref=…
      200 base/shared/authorization_exit_continuation
Base POST /oauth/authorize            422 ActionController::InvalidCrossOriginRequest
      "The browser returned a 'null' origin …"  (SignErrorResponses#handle_csrf_failure)
```

The user cannot cancel or switch to sign-up; the flow is stranded.

Relevant code:

- `app/controllers/concerns/oidc_authorization_result_post.rb:15` calls
  `apply_base_browser_continuation_headers!`, which sets `Referrer-Policy: no-referrer`
  (`app/controllers/concerns/base_admission_browser_binding.rb:47`), before rendering the exit
  continuation form.
- `config/application.rb:178` sets `forgery_protection_origin_check = true`.
- `oidc_authorization_result_post.rb:8`: "Neither an Auth Origin nor a null Origin substitutes
  for Base's CSRF protection."

Hypothesis (not confirmed): per the Fetch standard, a non-GET request from a document whose
referrer policy is `no-referrer` serializes `Origin` as `null`, which the Rails origin check
rejects. Unresolved discrepancy: `CeremonyBindingConfirmationsController#create` uses the same
header helper and its POST succeeded (303) in the same session. Request headers are not logged,
so the actual `Origin` / referrer policy per request was not observed. Next step: capture the
request headers in DevTools for both POSTs.

## 3. Other failures observed

- `Auth::App::Sign::SwitchesController#create` → 422, event `auth.sign_entry_exit.refused`
  reason `not_on_first_page`.
- `Auth::App::Sign::InsController#show` (with and without `entry_ref`) and
  `Base::App::CeremonyBindingConfirmationsController#show` → 400 several times **with no
  structured event or reason in the log**. Likely revisits of already-consumed references (back
  button / reload), not confirmed. Either way the 400s are not diagnosable from the log, and the
  user gets a dead end.
- Google social sign-in (`intent=login`, `prompt=none`) twice →
  `social_auth.error` `SocialAuth::UnauthorizedError`, `social_auth.intent.invalid`
  reason `intent_invalid`, `candidate_present: false`, then redirect to `/sign/in`. Cause not
  investigated.

## 4. ORG surface comparison

Observed one ORG pass at ~10:11:51 UTC (`www.umaxica.org` / `auth.umaxica.org`, client
`base-org-ww`). The sequence is identical to APP section 1: the same five `Continue` POSTs
(`Base::Org::Sign::EntriesController`, `Base::Org::Oauth::AuthorizationsController`,
`Auth::Org::CeremonyBindingsController`, `Base::Org::CeremonyBindingConfirmationsController`,
`Auth::Org::Sign::InsController`) render the same shared templates, then the Inertia ORG
sign-in form renders. The session stops there; Entra ID, Passkey and the Auth-to-Base result
were not exercised.

- ORG reuses the shared concerns (`OidcSsoInitiator`, `OidcAuthorizationResultPost`,
  `BaseCeremonyBindingConfirmation`, `AuthCeremonyAdmission`), so the section 1 assessment applies.
- The ORG sign-in page exposes `cancel_form` (`switch_form` is always `null`;
  `src/pages/auth/org/sign/ins/show.tsx:28`). Cancel returns through the same
  `OidcAuthorizationResultPost#render_oidc_exit_continuation!`, so the section 2 422 is expected
  to reproduce on ORG. Not observed: ORG Cancel was not exercised.
- Two `Base::Org::Oauth::AuthorizationsController#show` requests without parameters returned
  400 with no reason event (same observability gap as section 3).

## 5. COM surface comparison

Observed one COM pass at ~10:12:55–10:13:06 UTC (`www.umaxica.com` / `auth.umaxica.com`, client
`base-com-ww`).

- Same five-click path as APP and ORG, same shared templates, ending at the COM Inertia sign-in
  form. The user then opened the email and passkey sign-in pages without authenticating.
- `Base::Com::Oauth::AuthorizationsController#create` (`ceremony_action=start`) was received
  twice ~0.3 s apart (`jump_return.accepted` at 10:12:55.641 and 10:12:55.965), each issuing a
  Jump RT and a separate `entry_ref`; the second one was continued. Likely a double submit of the
  start button. Whether the first admission/transaction is cleaned up was not checked.
- **The section 2 defect reproduces on COM:** Switch to sign-up
  (`Auth::Com::Sign::SwitchesController#create`, `to=sign_up`) → jump → Base
  `authorization_exit_continuation` 200 → Base `POST /oauth/authorize` 422
  `ActionController::InvalidCrossOriginRequest` (null Origin). The exit continuation page was
  then rendered again (200) and the flow did not continue.
- Afterwards `Auth::Com::Sign::InsController#show` (with and without `entry_ref`) and
  `Base::Com::CeremonyBindingConfirmationsController#show` returned 400 (plain-text template, no
  reason event), as on APP.
- The last request, `Base::Com::RootsController#index`, returned 406
  `public/406-unsupported-browser.html` from Rails `allow_browser`, although the same browser
  received 200 from that action earlier in the session. Cause not investigated (user agent not
  logged).

## Not verified

- Callback (`/oidc/callback`) and token exchange: no successful sign-in reached them in this log.
- Root cause of the null `Origin` (section 2) and of the 400s and `intent_invalid` (section 3).
