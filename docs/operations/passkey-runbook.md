# Passkey Operations Runbook

## Updating the AAGUID Catalog

- Location: `config/webauthn/aaguid_catalog.yml`, mapping lowercase UUID AAGUID keys to friendly
  names.
- Sources: FIDO Alliance MDS descriptions and the community passkey-authenticator-aaguids list.
- Add an entry, then run
  `bin/rails test test/services/webauthn/authenticator_name_resolver_test.rb`. There is no external
  communication or restart-time dependency; startup does not contact an external service.
- Adding an entry does not change `provider_name` for existing credentials because the value is
  resolved and stored at registration. Design an explicit backfill separately if retrospective
  naming is required; never perform one automatically.

## Unknown AAGUID Values

- Unknown and zero AAGUID values are normal. Registration succeeds, `provider_name` remains NULL,
  the list uses the i18n default ("Passkey" or "My Passkey"), and the detail page displays "Unknown
  authenticator".
- Do not reject registration or warn the user solely because an AAGUID is unknown. It is a
  self-asserted value.

## Duplicate-Registration Support

- "This passkey is already registered" (`InvalidStateError` or HTTP 409) means the same credential
  was submitted again. This is expected defensive behavior. The same authenticator can still create
  a different credential.
- A revoked credential cannot be registered again with the same credential ID. Reusing the same
  physical key requires generating a distinct credential through a new registration.
- Multiple security keys from the same product and multiple passkeys from one provider are valid
  redundancy patterns.

## Limits and Constraints

- App Clients and org Operators may each have at most ten passkeys through the registration
  operation (`MAX_PASSKEYS_PER_*`). Direct database inserts are not yet protected by the planned
  slot constraint.
- Successful registration tops up recovery passcodes. Newly issued codes are delivered through a
  one-time reveal URL.

## Audit Coverage

`PasskeyRegistrationOperation` requires audit data and writes the registration and the matching
principal-side outbox event in one transaction. Invalid or missing audit data prevents registration.
The event must describe a registration and identify the owning actor when an actor reference is supplied.

Passkey audit delivery scans pending app and org outbox events in bounded pages through the
highest pending ID observed for each source at the start of its scan. A failed event remains
unacknowledged and is reported; delivery continues to later pages and the job then raises so the
failed event can be retried. Events added beyond the scan boundary wait for a later run.
Delivery refuses metadata that replaces the source's surface, Passkey reference or actor reference;
the event remains unacknowledged for investigation while later events are attempted.

- App and org registration outbox events use `passkey.registered.signup` or
  `passkey.registered.settings`. The com authentication surface has been retired.

## Failure Handling

- Catalog load failures surface on the resolver's first use. Check YAML syntax and inspect
  `Webauthn::AuthenticatorNameResolver.catalog` in the Rails console.
- UV failures such as `UserVerificationRequiredError` or the `uv_rejected` risk event may indicate
  that the authenticator cannot perform UV. Do not grandfather or infer UV capability for an
  existing credential.
- APP users may use Email OTP sign-in as the supported fallback. Email OTP is a Umaxica
  product exception and does not achieve NIST AAL2.
- ORG users may use Secret Credential or Microsoft Entra ID sign-in. Before enforcing the migration
  in production, identify operators whose only sign-in path is a passkey without `uv_verified_at`;
  arrange re-enrollment or another existing ORG sign-in method before rollout.
- A successful UV-required assertion sets `uv_verified_at`. Credential-removal guards must not treat
  a legacy passkey with unknown UV history as the final guaranteed compatible fallback.
