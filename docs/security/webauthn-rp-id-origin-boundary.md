# WebAuthn RP ID And Origin Boundary

> **Legacy Sign/Acme vocabulary:** The signed-result handoff described below is historical. Auth
> owns the credential ceremony, while Base owns browser sessions, RP sessions, and authorization
> code issuance in the current Rails architecture. Do not use this document to introduce a new
> signed or one-shot result path.

## Boundary

WebAuthn and passkey ceremonies run in `sign/id` because browser origin, RP ID, provider callback,
and challenge handling require stable credential ceremony URLs.

The WebAuthn ceremony result is evidence. `acme/www` consumes the signed result and commits any
session, account, credential-enrollment, authorization, or freshness effect that belongs to acme.

## Sign/ID Responsibilities

`sign/id` may own:

- WebAuthn RP ID and origin ceremony validation;
- challenge generation and short-lived challenge state;
- credential inventory needed for assertion or registration;
- attestation and assertion verification;
- ceremony audit records.

## Acme/WWW Responsibilities

`acme/www` owns:

- account lifecycle decisions;
- session creation and freshness updates;
- authorization decisions;
- preference/settings/dashboard state;
- downstream token issuance.

Physical credential tables may remain sign-side during this implementation phase. That placement
does not authorize sign-side sessions, account lifecycle, preference writes, or freshness storage.

## Related

- `docs/security/credential-gateway.md`
- `docs/security/ceremony-grant-result.md`
