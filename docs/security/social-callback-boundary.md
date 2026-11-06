# Social Callback Boundary

> **Legacy Sign/Acme vocabulary:** The signed result handoff in this document is historical context
> for the former delegation model. In the current Rails OIDC architecture, Auth remains
> ceremony-only, Visa is the OIDC and Root Session authority, and Base is the browser RP; use the
> current Auth/Visa result contract for new work.

## Boundary

Social provider callbacks may terminate on `sign/id` because provider redirect URLs require stable
credential ceremony endpoints. `sign/id` validates the provider response and returns signed evidence
to `acme/www`.

`sign/id` must not make the final account linking, account creation, session creation, preference,
authorization, token, or freshness decision.

## Responsibilities

For an APP login, the provider-start request records the admitted Auth ceremony row ID only as a
callback-attempt correlation value in the Rails session. Before the callback consumes OAuth state,
it resolves the current host-only `auth_sid` and requires the same active ceremony row. A mismatch
returns the shared 409 refusal without consuming state or writing authentication evidence; the
correlation value does not grant admission or select an actor.

For APP sign-up, the Google/Apple registration POST stores callback state, provider and the Apple
nonce when applicable, but creates no `ClientSignUpFlow` and records no Auth evidence. The user can
return to the initial sign-up page and choose another method. A later provider POST consumes the
previous callback state present in its current server-side session before issuing its replacement.
After that consume commits, the old callback state is refused. Concurrent provider starts made from
stale signed-cookie sessions are not yet associated with one persisted Admission generation; their
ordering is unverified. Only a verified successful callback locks the Admission Binding and then the
Auth Ceremony, rechecks the active sign-up admission, absence of cancellation, prior Flow and
evidence, and creates/advances the Flow with callback evidence. A callback refuses when Email,
Telephone or another social Flow already belongs to the admission.

A refusal for a known superseded or already-consumed callback state does not clear or commit the
session. This prevents an in-flight callback carrying an older signed-cookie snapshot from
overwriting the newer session cookie after a restart. This does not serialize concurrent provider
starts from stale snapshots.

`sign/id` may:

- validate OAuth/OIDC provider callback state and nonce;
- validate provider subject and provider claims needed for the credential ceremony;
- bind callback evidence to an acme transaction;
- return a signed ceremony result.

Visa owns:

- account lookup and account linking decisions;
- sign-up finalization;
- Root Session issuance;
- authorization and policy decisions;
- downstream token issuance.

## Object-level authorization

OmniAuth callback controllers do not call Action Policy `authorize!` or `authorized_scope`. They are
authentication and state-verification endpoints: login and sign-up have no authenticated actor or
record to authorize, and `link` always binds to the signed-in `current_resource`. Protection comes
from the authentication mode, callback state (CSRF/replay) validation, provider assertion
verification, and session binding of the intent. A future screen where an operator manages another
staff member's links MUST design object-level authorization in its own controller.

The APP social-link callback stages a receiver-local POST form with `strict-origin` in its response
and HTML metadata. The subsequent POST retains CSRF, session, device and Step-Up checks; its
referrer carries no callback path or query.

The current APP link-completion controller holds the Client lock while it validates the candidate,
grant and device. It consumes the candidate, grant and operation-scoped Step-Up in the OP device
transaction before attempting the Zenith identity link and its audit outbox write. If the Zenith
link fails after that OP commit, the spent authorization cannot be reused; a new ceremony is
required. The implementation currently performs this final link in Auth, although the historical
responsibility list above assigns linking decisions to Visa.

## Related

- `docs/security/social-login-provider-scope.md`
- `docs/security/ceremony-grant-result.md`
