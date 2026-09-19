# Passkey allowCredentials anonymization review

Date: 2026-09-19
Origin: finding F8 of `2026-09-19-owasp-asvs-5-checklist-review-V5R8.md` (ASVS 6.3, account
enumeration; 11.5, random values)

## Summary

The username-first passkey sign-in on the app and com surfaces pads `allowCredentials` with dummy
credential IDs so that every identifier receives four descriptors. The padding is intended to hide
whether an account exists and has passkeys. Static review shows that the padding can be told apart
from real credentials in two ways, so the hiding does not hold:

1. **Across two requests (High confidence).** Real credential IDs are stable, while dummies are
   regenerated on every request. Two `options` requests for the same identifier return the same
   real IDs and different dummies.
2. **Within one request (Likely).** Every dummy is exactly 43 characters. Real IDs are the
   authenticator's credential ID, whose length is chosen by the authenticator.

The original F8 concern (the order is shuffled with a non-cryptographic PRNG) is real but
irrelevant next to these two findings: once real and dummy IDs can be told apart, their order hides
nothing.

No change was made. This record describes the review only.

## Scope

| Surface | Controller | Affected |
|---|---|---|
| app | `Auth::App::Sign::In::Passkey::OptionsController` | Yes: identifier is an email address or telephone number typed by the visitor |
| com | `Auth::Com::Sign::In::Passkey::OptionsController` | Yes: same flow |
| org | `SignOrgNormalPasskeyCeremony`, `SignOrgEmergencyPasskeyCeremony` | No: the identifier comes from the Entra-selected operator and the browser value is ignored (`normalized_passkey_identifier`) |

## How the padding works

`PasskeySignInFlow#options` (`app/controllers/concerns/passkey_sign_in_flow.rb:19`):

1. Looks up the active actor for the identifier; if none, `passkeys = []`.
2. `anonymized_passkey_allow_credentials(passkeys)` (line 223) adds
   `ANONYMIZED_ALLOW_CREDENTIALS_COUNT - passkeys.size` dummies (`ANONYMIZED_ALLOW_CREDENTIALS_COUNT
   = 4`), each `{ id: SecureRandom.urlsafe_base64(32) }`, then returns
   `(passkeys + dummy_credentials).shuffle`.
3. The IDs are returned in `options.allowCredentials`. Real entries are `passkey.webauthn_id`
   (`PasskeyCeremonyContext#webauthn_credential_ids`), which is the authenticator's credential ID
   stored at registration (`Webauthn::AuthenticationContext`, `webauthn_id: credential.id`).

Accounts are capped at four passkeys (`MAX_PASSKEYS_PER_USER`, `MAX_PASSKEYS_PER_VISITOR`), so the
response always contains exactly four descriptors.

## Finding 1: comparison across two requests

- Dummies come from `SecureRandom` on each call, so no dummy is ever repeated.
- Real IDs are read from the database and are the same on each call.
- Therefore an ID that appears in two responses for the same identifier is a real credential.

Observable result: an identifier whose two responses share at least one ID belongs to an active
account with at least one active passkey. If the responses share no ID, the account either does
not exist or has no passkey. Accounts without passkeys stay indistinguishable from nonexistent
identifiers.

Basis: code reading. The claim follows directly from the lines cited above and was not reproduced
with an HTTP request.

## Finding 2: length within one request

- Verified: `SecureRandom.urlsafe_base64(32)` always yields 43 characters (checked with
  `ruby -rsecurerandom`).
- Not verified here: the length of real credential IDs. WebAuthn lets the authenticator choose the
  credential ID length, and common authenticators do not all use 32 bytes. Any real ID whose
  encoded length is not 43 characters stands out in a single response.

Assessment: likely. The exact exposure depends on which authenticators users register. A single
request would then be enough, which also defeats the per-IP rate limits described below.

## Existing mitigations

- Rate limits per IP on `options`: 5 per minute and 20 per 15 minutes (app controller).
- Cloudflare Turnstile stealth check before issuing options (`before_passkey_options_request!`).
- `MinimumResponseBudget` pads response time, so timing does not reveal the lookup result.
- The existing tests assert only the count of four descriptors
  (`test/controllers/auth/app/in/passkeys_controller_test.rb`,
  `test/controllers/auth/com/in/passkeys_controller_test.rb`). No test checks that dummies are
  stable across requests or indistinguishable from real IDs.

These controls slow down bulk enumeration. They do not stop a targeted check of a known email
address or telephone number.

## Impact

An attacker can learn whether a specific email address or telephone number has an active account
with a passkey on the app or com surface. That is account enumeration (ASVS 6.3) and a privacy
disclosure about the person behind the identifier. The disclosure does not give access to the
account: the passkey assertion still requires the authenticator.

Severity: Low to Medium. It is Low as an access-control issue, but it contradicts a protection the
code explicitly claims ("must not reveal whether an account exists, has a passkey"), and other sign-in
paths may reveal the same fact differently. Those paths were not reviewed here.

## Remediation options

1. **Deterministic dummies (addresses finding 1).** Derive each dummy from the normalized
   identifier with a server-side key, for example `HMAC(key, identifier || index)`, so the same
   identifier always gets the same dummies. Reuse the existing identifier HMAC key management if it
   fits (`docs/security/identifier-hmac-emergency-rotation.md`).
2. **Realistic lengths (addresses finding 2).** Match dummy lengths to the distribution of real
   credential IDs. Measure the lengths stored in `*_passkeys.webauthn_id` first, then choose lengths
   from that distribution deterministically, as in option 1.
3. **Stable order.** With options 1 and 2 in place, sort the combined list by a keyed hash of the ID
   rather than by `shuffle`, so the order is also stable per identifier. This removes the
   non-cryptographic PRNG from the path.
4. **Alternative: stop sending allowCredentials.** Use discoverable credentials (an empty
   `allowCredentials`), so the server never discloses credential IDs for an identifier. This
   changes the sign-in UX and authenticator requirements, so it needs its own decision.

Options 1 to 3 together keep the current UX. Any change needs tests asserting that two requests
for the same identifier return identical descriptors, and that responses for an existing account
and a nonexistent identifier have the same shape.

## Open items

Followed up in `2026-09-19-account-enumeration-sign-in-sign-up-J4N7.md`: real credential ID lengths
could not be measured (no passkeys in the development database), and the email sign-in and sign-up
paths were found to disclose account existence independently of this finding.
