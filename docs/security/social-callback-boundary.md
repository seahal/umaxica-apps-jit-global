# Social Callback Boundary

## Boundary

Social provider callbacks may terminate on `sign/id` because provider redirect URLs require stable
credential ceremony endpoints. `sign/id` validates the provider response and returns signed evidence
to `acme/www`.

`sign/id` must not make the final account linking, account creation, session creation, preference,
authorization, token, or freshness decision.

## Responsibilities

`sign/id` may:

- validate OAuth/OIDC provider callback state and nonce;
- validate provider subject and provider claims needed for the credential ceremony;
- bind callback evidence to an acme transaction;
- return a signed ceremony result.

`acme/www` owns:

- account lookup and account linking decisions;
- sign-up finalization;
- session issuance;
- authorization and policy decisions;
- downstream token issuance.

## Object-level authorization

OmniAuth callback controllers do not call Action Policy `authorize!` or `authorized_scope`. They are
authentication and state-verification endpoints: login and sign-up have no authenticated actor or
record to authorize, and `link` always binds to the signed-in `current_resource`. Protection comes
from the authentication mode, callback state (CSRF/replay) validation, provider assertion
verification, and session binding of the intent. A future screen where an operator manages another
staff member's links MUST design object-level authorization in its own controller.

## Related

- `docs/security/social-login-provider-scope.md`
- `docs/security/ceremony-grant-result.md`
