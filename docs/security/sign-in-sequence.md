# Sign-In Sequence

## Authority

Sign-in has two boundaries:

- `sign/id` hosts unauthenticated sign-in entry points and executes credential ceremonies.
- `acme/www` consumes the ceremony result and commits session, actor/session, OIDC, and token state.

Sign-in completion means the credential ceremony is complete on sign and the session commit is
complete on acme. A credential ceremony alone is not a signed-in session.

Logical authority moves now; physical storage may remain where it is. Existing sign-side tables,
models, services, controllers, route names, or namespaces do not imply sign-side authority.

## Sign/ID Responsibilities

`sign/id` may:

- host unauthenticated sign-in entry points;
- collect identifiers needed to start a credential ceremony;
- execute passkey/WebAuthn, OTP, TOTP, passcode, and social callback ceremonies where supported;
- host MFA ceremony steps that are part of sign-in credential proof;
- consume or introspect an acme session only to decide whether a ceremony is needed;
- keep credential inventory and short-lived ceremony state;
- return a signed, one-shot ceremony result to acme.

`sign/id` must not:

- create, rotate, continue, revoke, list, or display user sessions;
- issue access tokens, refresh tokens, OIDC tokens, or downstream tokens;
- store step-up freshness, `recent_auth`, `sudo`, or `last_step_up_at`;
- redirect to a sign dashboard as signed-in authority;
- commit actor/session state;
- decide authorization for product behavior.

Acme's own browser flow uses the shared browser RP client id `base-rails-rp`. The first
`/oauth/authorize` login step establishes Acme authority for code issuance. The later
`/oidc/callback` step validates state, PKCE, nonce, and ID token claims, then establishes the local
product browser session on the same host. That callback is an intentional RP boundary, not a second
authority issuer.

## Acme/WWW Responsibilities

`acme/www` owns:

- session creation and continuation;
- actor/session state;
- sign-in guardrails that depend on account/session/product policy;
- session-limit decisions and session-management UI;
- the Acme sign-in limitation ceremony at `/sign/in/limitation`;
- dashboard and post-auth navigation as authenticated product surfaces;
- OIDC authorization, token issuance, and JWKS authority;
- refresh token family issuance and rotation;
- downstream token issuance;
- step-up freshness confirmation when sign-in is not enough for a later sensitive action.

`core`, `line`, and future downstream services must trust acme-issued downstream tokens, not
sign-issued tokens.

## Ceremony Result Flow

The sign-in flow uses the credential grant/result boundary:

1. The browser enters a sign/id unauthenticated sign-in route.
2. sign/id executes the requested credential ceremony.
3. sign/id returns a signed ceremony result that is audience-bound to acme, purpose-bound, one-shot,
   expiring, and bound to the acme transaction or session where applicable.
4. acme validates and consumes the result.
5. acme commits or rejects session creation and actor/session state.
6. acme performs post-auth navigation, dashboard routing, OIDC continuation, or downstream token
   issuance as acme-owned behavior.

Redirect targets, OAuth/OIDC `state`, Jump `rt`, and local return paths are navigation state. They
must not carry authentication result facts. The signed ceremony result is the security object.

## Sequence Vocabulary

The old sign-in state-machine vocabulary remains useful only as ceremony or compatibility routing
vocabulary:

| Vocabulary                   | Current meaning                                                                     |
| ---------------------------- | ----------------------------------------------------------------------------------- |
| Primary credential           | The first credential ceremony executed by sign/id.                                  |
| MFA challenge during sign-in | Additional credential ceremony before sign returns evidence to acme.                |
| Guardrail                    | A policy stop. If it depends on session/account/product state, acme owns it.        |
| Checkpoint                   | A required pre-session or post-auth requirement. acme owns session/account effects. |
| Selector                     | Acme-owned actor/session selection before session commit.                           |
| Session issuance             | Acme-owned session creation, never sign-owned.                                      |
| Welcome/dashboard            | Acme-owned post-auth navigation or product surface.                                 |

Existing DB-backed sign-in cycle rows may remain physically where they are during migration. They do
not make sign the session authority.

## Surface Inventory

The supported credential methods remain surface-aware:

| Surface | sign/id ceremony methods                                            | acme-owned commit                                            |
| ------- | ------------------------------------------------------------------- | ------------------------------------------------------------ |
| `app`   | email OTP, passkey, TOTP where implemented, passcode, Google, Apple | Client session, account/session state, OIDC/token issuance   |
| `com`   | email OTP, passkey, passcode                                        | Visitor session, account/session state, OIDC/token issuance  |
| `org`   | passkey, passcode                                                   | Operator session, account/session state, OIDC/token issuance |

Org production sign-in does not use external social providers. Google, Apple, Microsoft, and other
external social providers are not org sign-in methods.

## App Sign-In Route Matrix

Current `app` sign-in routes share the same completion gate. Route-local controllers verify the
credential or provider response, then hand off to `establish_signed_in_session!` and the shared
`SignInResult` adapter when a session is actually issued.

| route family                        | controller path                                                                                 | credential / provider                | state object                        | completion gate                                         | notes                                                                                                         |
| ----------------------------------- | ----------------------------------------------------------------------------------------------- | ------------------------------------ | ----------------------------------- | ------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------- |
| Email OTP                           | `Sign::App::Sign::In::EmailsController`                                                         | email + OTP                          | `SignAppInEmailAuthenticationState` | `establish_signed_in_session!`                          | `create` issues real or dummy OTP; `update` verifies OTP and returns success, MFA, restricted, or hard reject |
| Google social                       | `Sign::App::Social::AuthenticationsController` + `Sign::App::Auth::OmniauthCallbacksController` | Google OAuth / OmniAuth              | social auth intent + callback state | `establish_signed_in_session!`                          | callback validates state, provider assertion, and callback replay before completion                           |
| Apple social                        | `Sign::App::Social::AuthenticationsController` + `Sign::App::Auth::OmniauthCallbacksController` | Apple OAuth / OmniAuth               | social auth intent + callback state | `establish_signed_in_session!`                          | Apple-specific form-post callback handling is delegated to the provider integration                           |
| Passkey / WebAuthn                  | `Sign::App::Sign::In::PasskeysController` + `Sign::App::Sign::In::Passkey::*`                   | WebAuthn credential                  | passkey challenge state             | `establish_signed_in_session!`                          | options and verification controllers already route through the shared gate                                    |
| TOTP / passcode / secret credential | `Sign::App::Sign::In::SecretCredentialsController` + `Sign::App::Sign::In::Challenge::*`        | TOTP, passcode, or secret credential | pending MFA state                   | `establish_signed_in_session!` or `finalize_mfa_login!` | direct login and MFA follow-up branches both converge on the same session completion rules                    |

The route families above must not create `ClientToken`, `ClientDeviceSession`, or auth cookies
directly in controller code.

All successful sign-in routes must normalize the completion result through the shared `SignInResult`
adapter. The current result shape includes `success`, `mfa_required`, `session_limit_pending`,
`session_limit_hard_reject`, `credential_rejected`, `identity_unavailable`, `transaction_expired`,
`failure`, and `invalid_request`.

## Timing And Enumeration Mitigation

Credential endpoints must not make account or credential existence easy to infer from response
timing. Controllers that include `MinimumResponseBudget` now get timing protection enabled by
default; endpoints that need a narrower action set override `minimum_response_budget_enabled?` for
those actions. The contract test in
`test/controllers/auth/credential_timing_protection_contract_test.rb` lists credential controllers
that must either use that response budget or document another timing-equalized path.

Current coverage is:

| Credential path                       | Mitigation                                                      |
| ------------------------------------- | --------------------------------------------------------------- |
| App email OTP sign-in                 | Dummy OTP generation and minimum elapsed verification on update |
| App/com/org passkey sign-in           | `MinimumResponseBudget` on challenge/options endpoints          |
| App/com/org secret credential sign-in | `MinimumResponseBudget` on credential submission                |
| Org Entra sign-in                     | `MinimumResponseBudget` on authorization start                  |

New credential endpoints must be added to the contract test. If an endpoint intentionally opts out
of the response budget, it must have an alternate dummy-work or fixed-time verification path that is
visible in tests and documentation.

## Ceremony Cleanup

Sign-in credential ceremonies store short-lived transaction rows keyed by `expires_at`. These rows
are not part of the account-retention `purge_eligible_at` model handled by `RetentionPurgeJob`, so
production recurring cleanup registers the dedicated ceremony transaction purge jobs in
`config/recurring.yml`.

The cleanup contract is intentionally narrow: expired ceremony transaction rows beyond their
retention period may be physically deleted; active and non-expired transactions must remain
available until they either complete, expire, or are superseded by a fresh ceremony. Running the
purge repeatedly is safe because each job scopes deletion to currently purgeable expired rows.

## Signed-In Re-Entry

If a browser already has an acme session, sign/id may introspect or consume that fact only to decide
whether a credential ceremony is needed. It must not create a second sign-owned session, redirect to
a sign dashboard as authority, or mutate acme session state.

## OIDC And Token Authority

OIDC survives, but OIDC is acme authority.

Protocol endpoints or route namespaces may remain in compatibility locations during migration. That
does not make sign/id the token authority. Acme owns OIDC authorization, token issuance, ID tokens,
access tokens, refresh tokens, JWKS authority, and downstream token issuance.

## Related

- `docs/identity/authority-boundary.md`
- `docs/security/credential-gateway.md`
- `docs/security/ceremony-grant-result.md`
- `docs/security/session-token-authority.md`
- `docs/security/redirect-vs-ceremony-result.md`
