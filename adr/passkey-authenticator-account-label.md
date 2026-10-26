# Passkey Authenticator Account Label

## Status

**Accepted (2026-10-23).** Decision record for the lost-authenticator threat. The current Rails
registration path uses the fixed surface label; the remaining lifecycle and production verification
evidence belongs to the Passkey work unit.

## Context

Every surface registers discoverable credentials (`Webauthn::RegistrationVerifier`,
`resident_key: "required"` for APP, COM and ORG). A discoverable credential stores the WebAuthn
`user.name` and `user.displayName` on the authenticator. Anyone holding the authenticator and its
PIN can list them through the operating system's or browser's security-key management.

Today both values are the account's first Email address, or the public id when no Email exists
(`PasskeyCeremonyContext#passkey_resource_display_name`).

[Passkey Identifier-First Sign-In](passkey-identifier-first-sign-in.md) requires the person to name
the Identity before the Passkey ceremony, so that an attacker holding a lost authenticator and its
PIN cannot pick an account. That ADR also states that it does not help when the attacker knows the
victim's Email, Telephone or Employee Number. Storing the Email on the authenticator hands exactly
that identifier to whoever finds the authenticator, so the identifier-first barrier does not hold
for that attacker.

Non-discoverable credentials would store no account data, but sign-in would then have to send the
Identity's credential IDs before authentication. That reveals whether an account exists and how
many credentials it holds, which [credential response nondisclosure](credential-response-nondisclosure.md)
and the identifier-first ADR forbid.

## Decision

1. Credentials stay discoverable on APP, COM and ORG.
2. The `user.name` and `user.displayName` sent at registration MUST NOT contain an Email address, a
   Telephone number, an Employee Number, an Entra identifier, the WebAuthn user handle or any other
   value that selects or helps select an Identity. They carry a fixed, non-identifying label per
   surface (for example the service name). The exact text is an implementation detail inside this
   rule.
3. Account selection stays with the identifier the person enters (APP/COM) or the Entra
   transaction (ORG Normal), as the identifier-first ADR decides. The authenticator's account
   picker is not a source of Identity selection.

## Consequences

- An attacker who finds an authenticator and its PIN learns which service it belongs to, not which
  account. The identifier-first barrier then requires knowledge the authenticator does not reveal.
- A person with several accounts on one authenticator sees identical labels in the picker. Choosing
  the wrong credential is refused because ownership must match the named Identity; the person
  chooses again.
- Possession of the authenticator together with its PIN and the victim's identifier still defeats
  APP/COM Passkey sign-in. This ADR does not change that limit; removing a lost Passkey from the
  account settings remains the response. ORG Normal additionally requires the Entra sign-in.
- Existing credentials keep the label they were registered with. The cycle resets every database
  (owner decision, 2026-10-22), so no stored credential needs relabelling; no migration is needed.

## Amendments recorded with this decision

[Passkey Identifier-First Sign-In](passkey-identifier-first-sign-in.md) is amended as follows:

- **ORG discoverable credentials.** Its paragraph keeping ORG non-discoverable credentials
  compatible ("Neither exposing descriptors nor silently requiring discoverable ORG credentials is
  an approved resolution") is superseded. ORG registration requires discoverable credentials with
  UV, as [credential response nondisclosure](credential-response-nondisclosure.md) decided and the
  code already does. With every database reset there are no existing non-discoverable ORG
  credentials to keep.
- **Capacity.** The four-slot capacity is superseded. Each Identity holds at most **ten** Passkeys
  on APP, COM and ORG and the eleventh registration is refused, restoring the 2026-10-19 capacity of
  [Passkey lifecycle and limit](passkey-current-state-limit-and-chronicle-outbox.md) (owner decision,
  2026-10-22). Identifier-first selection, the `ADVANCED` two-active-Passkey minimum, owner
  serialization and the rule that a slot number never selects the only usable credential are
  unchanged.

## Verification

- Registration options on APP, COM and ORG contain no Email, Telephone, Employee Number, Entra
  identifier or user handle in `user.name` or `user.displayName` (request tests per surface).
- Registration on ORG without a discoverable credential or without UV is refused.
- Registering the ninth and tenth Passkey succeeds and the eleventh is refused; two concurrent
  registrations at nine existing credentials yield at most one success.

## References

- [Passkey Identifier-First Sign-In](passkey-identifier-first-sign-in.md)
- [Credential response nondisclosure](credential-response-nondisclosure.md)
- [WebAuthn user handle](webauthn-user-handle.md)
- [Passkey lifecycle and limit](passkey-current-state-limit-and-chronicle-outbox.md)
- `docs/security/passkeys.md` (current-behavior overview)
