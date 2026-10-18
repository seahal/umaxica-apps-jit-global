# Cloudflare Turnstile

This document records the product use of CAPTCHA-style anti-automation verification. The current
implementation uses Cloudflare Turnstile, not Google reCAPTCHA.

## Purpose

Turnstile is an anti-automation control for request flows that are attractive to bots or scripted
abuse. It is not an authentication factor, does not prove the actor's identity, and must not replace
authentication, authorization, CSRF protection, rate limiting, step-up, lockout, or audit logging.

OWASP describes CAPTCHA as a defense-in-depth control for automated login attempts. OWASP also notes
that CAPTCHA implementations can be bypassed or outsourced, so they should make automated abuse more
expensive rather than be treated as complete prevention:

- OWASP Authentication Cheat Sheet, CAPTCHA:
  `https://cheatsheetseries.owasp.org/cheatsheets/Authentication_Cheat_Sheet.html#captcha`
- OWASP Automated Threat OAT-019 Account Creation:
  `https://owasp.org/www-project-automated-threats-to-web-applications/assets/oats/EN/OAT-019_Account_Creation`

For this application, Turnstile primarily protects:

- sign-in attempts, especially credential stuffing and brute-force style flows;
- sign-up and identity registration flows, where bulk account creation or bulk contact submission is
  a realistic abuse case;
- sensitive credential-management mutations, where scripted requests can amplify CSRF, stolen
  session, or workflow-abuse risk.

Turnstile should be applied to mutation endpoints that create, update, verify, or delete
authentication methods or recovery/contact identifiers when those endpoints are exposed to ordinary
browser traffic.

## Product

Cloudflare describes Turnstile as a smart CAPTCHA alternative that can be embedded on any website
without requiring the site to use Cloudflare's CDN:

- Cloudflare Turnstile overview: `https://developers.cloudflare.com/turnstile/`

Cloudflare documents three widget modes:

- `managed`: Cloudflare decides whether to show an interaction based on risk.
- `non-interactive`: the visitor does not interact with the widget.
- `invisible`: the widget is hidden from the visitor.

This application uses two local partials:

- `shared/cloudflare_turnstile_visible`
- `shared/cloudflare_turnstile_stealth`

The visible variant is appropriate for public sign-in or sign-up entry points where an explicit
challenge is acceptable. The stealth variant is appropriate for signed-in configuration forms where
the user already completed authentication or step-up and the product should avoid unnecessary UI
friction.

Frontend code must reuse only these partials. Do not add ad hoc Turnstile markup, custom hidden
field names, inline widget scripts, or per-view JavaScript implementations. Both partials submit the
same `cf-turnstile-response` field, and backend verification depends on that stable parameter name.

When adding Turnstile to a `form_with` form, render the partial inside the form body so the hidden
response field is submitted with the protected action. For delete actions, prefer an actual form,
such as `form_with method: :delete`, instead of a link using `data-turbo-method` because a link
cannot carry a fresh Turnstile token in the request body.

## Server-Side Validation

Client-side widget rendering is not sufficient. Cloudflare requires server-side validation of the
response token through the Siteverify API before the protected action is completed:

- Cloudflare server-side validation:
  `https://developers.cloudflare.com/turnstile/get-started/server-side-validation/`

In Rails controllers, the server must validate `cf-turnstile-response` before committing the
mutation. A failed or missing token must leave the protected state unchanged.

Current helper boundary:

- `CloudflareTurnstile#cloudflare_turnstile_validation` validates visible-mode tokens.
- `CloudflareTurnstile#cloudflare_turnstile_stealth_validation` validates stealth-mode tokens.
- `CloudflareTurnstile#verify_turnstile_stealth!` is JSON-oriented and should not be reused for
  ordinary HTML forms unless the caller accepts its JSON error response.

Backend code must validate Turnstile only through Rails controller concerns. The shared concern
boundary is `app/controllers/concerns/cloudflare_turnstile.rb`; flow-specific controller concerns
may wrap that concern to standardize error handling for a feature area. Do not call the verifier
service directly from individual controllers, models, services, views, or JavaScript.

Controllers must run Turnstile validation before committing the protected mutation. A failed
validation must not create records, update records, delete records, consume one-time codes, rotate
credentials, or clear pending registration state.

## Development And Test Mode

The codebase has a test-only override mechanism on `CloudflareTurnstile` and
`Jit::Security::TurnstileVerifier` so automated tests can force a success or failure response
without depending on Cloudflare. That is useful for deterministic tests, but it must not be used in
development, staging, or production.

Future development environments should exercise the same Turnstile integration shape as production:
render a widget, submit `cf-turnstile-response`, and validate the token server-side. Until that
change is fully exercised, code reviews must treat test override success as test scaffolding only,
not proof that the real Turnstile integration is wired correctly.

## Placement Rules

Turnstile is required for browser-submitted mutations in these classes of flows unless a documented
exception applies:

- public sign-in credential submission;
- public sign-up contact submission;
- contact registration start and contact verification submission;
- credential registration, update, and deletion;
- recovery-method registration, update, and deletion.

Turnstile is not required for idempotent `GET` pages that only display existing state. It is also
not a substitute for step-up on sensitive signed-in actions. Sensitive credential-management
endpoints must require both recent step-up and successful Turnstile unless a documented exception
exists.

### Visible Placement

Visible Turnstile belongs on public browser-rendered entry forms where this application receives the
submitted mutation directly. Render `shared/cloudflare_turnstile_visible` inside the form, and
validate the submitted `cf-turnstile-response` in the controller before changing state.

Current visible placement policy:

| Surface | Browser entry                               | Protected mutation             | Placement        |
| ------- | ------------------------------------------- | ------------------------------ | ---------------- |
| app     | `/sign/up/email/new`                        | `POST /sign/up/email`          | visible required |
| app     | `/sign/up/telephone/new`                    | `POST /sign/up/telephone`      | visible required |
| app     | `/sign/in/email/new`, `/sign/in/email/edit` | `POST/PATCH /sign/in/email`    | visible required |
| app     | `/preference/email/:id/edit`                | `DELETE /preference/email/:id` | visible required |
| com     | `/sign/up/email/new`                        | `POST /sign/up/email`          | visible required |
| com     | `/sign/up/telephone/new`                    | `POST /sign/up/telephone`      | visible required |
| com     | `/sign/in/email/new`, `/sign/in/email/edit` | `POST/PATCH /sign/in/email`    | visible required |
| com     | `/preference/email/:id/edit`                | `DELETE /preference/email/:id` | visible required |
| org     | `/sign/up/invitations/new`                  | `POST /sign/up/invitations`    | visible required |
| org     | `/preference/email/:id/edit`                | `DELETE /preference/email/:id` | visible required |

The table is the implementation checklist for visible Turnstile. If a new public browser-rendered
entry form is added to sign-up, sign-in, invitation, or external email-preference flows, update this
table before implementation unless the new route fits an existing documented exception.

Permanent-secret sign-in has been retired on app, com, and org. The retired `/sign/in/secret` routes
are not entry forms and have no Turnstile contract.

### Placement Exceptions

Do not add Turnstile to social login entry or callback routes:

- app Google social login;
- app Apple social login;
- org Google social login.

These flows are delegated to the external identity provider's authentication and abuse controls.
Local code must still validate provider state, callback integrity, account-linking rules, and
surface-specific policy.

Do not add Turnstile to `POST /preference/email/:id`. That route is for List-Unsubscribe style mail
client behavior where the client may send a POST without displaying an application-rendered page.
The normal user-facing unsubscribe flow is `/preference/email/:id/edit` followed by
`DELETE /preference/email/:id`, and that browser form must use visible Turnstile.

Do not use visible Turnstile for passkey sign-in. Passkey sign-in uses the passkey/WebAuthn flow and
the stealth Turnstile path where Turnstile is required.

Do not add an extra Turnstile challenge to sign-up checkpoint `birthdate`, `passcode`, or `passkey`
actions when those actions are reachable only through a valid Turnstile-protected sign-up sequence.
See `adr/sign-up-checkpoint-turnstile-boundary.md`.

## Error Handling

For normal `form_with` HTML forms backed by an Active Model object, Turnstile failures should be
reported by adding an error to that object, usually `errors.add(:base, t("turnstile_error"))`, and
rendering the same form with `422 Unprocessable Content`. This keeps the error in the same location
as other validation failures and avoids losing user-entered form data.

For forms or requests that are not naturally backed by a model object, return the least surprising
response for that UI:

- HTML create/update forms should render the original form with a clear alert or form-level error.
- HTML destructive actions may redirect back to the index or detail page with an alert, preserving
  the existing state.
- JSON endpoints should return a structured error and `422 Unprocessable Content`.
- Multi-step verification flows must not consume OTPs, passkey challenges, pending secrets, or
  registration sessions when Turnstile fails.

## Review Checklist

For every new or changed credential, recovery, contact, sign-in, sign-up, or social-link endpoint:

- Does the route mutate state or verify a submitted code/token?
- If yes, does the rendered form include the correct Turnstile partial?
- If the action is delete-like, is it submitted through a form that can include the Turnstile
  response token?
- Does the controller validate `cf-turnstile-response` before saving, updating, deleting, or
  consuming a one-time code?
- Is validation performed through the shared controller concern boundary rather than direct service
  calls?
- On validation failure, does the endpoint preserve existing state and return `422` or redirect
  without performing the mutation?
- For model-backed `form_with` flows, is the failure added to `errors` and rendered in the normal
  form validation UI?
- Is Turnstile layered with the existing controls: authentication, authorization, CSRF, rate limits,
  step-up, lockout, and audit logging?
- Is the behavior covered by tests for both successful and failed Turnstile validation?

## Current Implementation Notes

The application already has mixed visible and stealth Turnstile usage across sign-in, sign-up,
contact registration, TOTP, social unlink, and passcode management flows. Coverage is intentionally
reviewed per endpoint because app, com, and org are separate surfaces and must not silently share
controller state.

Known follow-up work should be tracked in plans or backlog items rather than this stable document.
