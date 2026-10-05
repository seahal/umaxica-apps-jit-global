# Base-bound Passkey registration candidate proposal

Status: awaiting explicit data-shape approval, 2026-10-04. This supplements the approved registration
parent FK and evidence separation; it does not change ordinary step-up proof or add JWT transport.

## Database shape

Before, each actor-specific `*_passkey_ceremony_transactions` stores the registration parent FK,
RP/origin, actor/session, expiry, candidate reference/digest and result identifier, but no candidate
public-key material. The current settings path creates a credential directly on Auth.

After, add nullable columns to those same three child tables:

```text
candidate_webauthn_id:text
candidate_public_key:text
candidate_sign_count:bigint
candidate_description:string
candidate_metadata:jsonb
```

The verified WebAuthn registration context supplies the identifier, public key and signature
counter. A bounded user label supplies the description. The existing AuthenticatorMetadata
allowlist supplies metadata; arbitrary client keys are not retained. Named columns are preferable
to a positional tuple because these independently validated credential properties are consumed
by the existing credential models. The existing candidate digest binds the canonical approved
properties; the reference is generated server-side. No authenticator private key is stored.

All candidate fields are absent before verification. On verified candidate evidence, required key
properties are present, the counter is nonnegative, and metadata is a JSON object. The existing
`result_jti` marks candidate confirmation and is retained through final consumption. New binding
requires the existing exact registration parent FK. Historical unbound rows receive no authority.
The parent remains registration-only `verified`, with `aal=none`, no phishing resistance and no
credential reference. Base alone creates the credential and spends the parent and child.

The existing StepUpSession challenge columns hold short-lived registration challenges bound to
this registration parent and RP/origin. Registration and assertion operations use separate explicit
purpose guards; a registration challenge cannot satisfy ordinary assertion. No challenge lifetime
or failure budget is extended by redisplay/restart. Registration candidate expiry is the earlier
of the fixed challenge deadline and parent deadline.

Use additive actor-specific migrations and generated schema dumps. No bulk updates, destructive
cleanup, shared database rebuild, or deployment is part of approval. Before rollback, terminate
new registration permissions/candidates safely; do not reinstate Auth direct credential creation.
Ticket/principal databases retain the already documented fail-closed cross-database limitation.

## HTTP response

Before, successful Auth settings verification creates a credential and responds:

```json
{"status":"ok","passkey_id":123,"redirect_url":"/settings/passkeys"}
```

After, Auth confirms only the server candidate and responds:

```json
{"status":"ok","redirect_url":"/settings/passkeys/handoff"}
```

The same-origin handoff endpoint uses the approved opaque `{result,transaction_ref}` Base transport.
The server's fixed surface route supplies redirect_url, with the existing region propagation.
Registration UI consumes the existing success/redirect contract; passkey_id is removed because
there is no created credential yet. Options retain `{challenge_id,options}`. Base owns final
credential identity, registration audit/notification and the original protected-operation return.
Recovery credential behavior must follow its existing surface policy at the proper Base boundary;
Auth confirmation cannot imply that those records have been created.

Acceptance requires DB constraints, application authorization and negative tests that registration
evidence cannot become ordinary step-up freshness, plus replay, duplicate, ownership, limits,
expiry, cancellation and concurrent finalization coverage.
