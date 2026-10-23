# Passkey Identifier-First Sign-In

## Status

**Accepted (2026-10-21); amended 2026-10-23** by [Passkey authenticator account label](passkey-authenticator-account-label.md): ORG registration
requires discoverable credentials (the ORG non-discoverable compatibility paragraph below is
superseded), the capacity is ten Passkeys per Identity (the four-slot capacity below is
superseded), and the authenticator stores no identifying `user.name`. This records the adopted design only. Implementation, application
audit, migration planning and runtime verification are outside this ADR-only change and remain
unverified. Acceptance does not certify that the current sign-in paths satisfy this contract.

## Context

[Discoverable direct sign-in](webauthn-discoverable-direct-sign-in.md) removed an identifier-driven
credential enumeration path by issuing APP/COM options without real credential descriptors. It also
allowed account selection through the credential returned by an authenticator, without prior
Identity selection. UMAXICA now requires explicit Identity selection before Passkey authentication
while preserving that credential non-disclosure protection.

Identity selection and proof of ownership are separate. Email, Telephone and Employee Number are
identifiers, not secrets or additional authentication factors.

## Decision

Passkey sign-in MUST follow this order:

1. Select an Identity through the surface's authoritative identifier resolution, or the existing
   Entra transaction for ORG Normal.
2. Fix that Identity in a server-side authentication transaction before issuing its challenge.
3. Verify a WebAuthn assertion from an active credential belonging to the fixed Identity.
4. Complete sign-in only after the existing Security Mode, account, admission and session
   requirements succeed through their established authority boundaries.

The mandatory equality is **Selected Identity == Verified Credential Owner**, within the same
surface. Assertion credential lookup supplies verification material; it cannot replace the
selected Identity. Failure at any prerequisite refuses authentication.

## Scope

This decision replaces APP/COM usernameless Passkey sign-in and specifies Employee Number selection
for ORG Standby. ORG Normal remains Entra ID → Operator → Passkey → Normal Session.
Registration, Step-Up, recovery, other sign-in methods, RP membership and session issuance
authority retain their independent contracts. No new sign-in method is authorized.

## APP/COM Identity Selection

APP/COM MUST accept either one registered effective Email or one registered effective Telephone;
both are not required. Resolution MUST use the owning surface's existing normalization rules,
verified and finalized Contact Binding, and Identity ownership. A pending candidate or historical
contact is not an effective binding.

Missing, empty, malformed, unknown, unverified, released, expired, revoked or ambiguously resolved
identifiers MUST NOT establish authentication. An ineligible Identity also refuses. A released
binding MUST NOT be re-resolved during verification to a successor owner of the same destination.

Before authentication, responses MUST conceal Identity and credential existence. Status, response
shape, body size, redirects, challenge transport, cookie effects and timing MUST be assessed as
observable channels. Unknown and ineligible identifiers MUST follow an indistinguishable refusal
ceremony rather than disclose lookup results. Any server-side negative transaction MUST remain
explicitly non-authenticating and MUST NOT become usable if the identifier is later registered.
It MUST NOT represent a fabricated persistent Identity. Exact response and timing mechanisms require
implementation verification; padding alone does not establish non-disclosure.

## Passkey Credential Ownership

*(Capacity superseded 2026-10-23: ten per Identity, see the Status amendment.)* An Identity may retain multiple Passkeys, with a maximum of **four slots per Identity** on APP,
COM and ORG. This expressly replaces the ten-credential capacity accepted on 2026-10-19; it does
not imply that four-slot enforcement already exists. Slot persistence and safe handling of an
existing owner above four require later investigation; this decision authorizes no deletion,
renumbering or destructive migration.

Any one active, valid credential of the selected Identity may satisfy the Passkey authentication
requirement. Slot number and registration order MUST NOT select the only usable credential.
Credential status, immutable ownership, signature, UP, UV, RP ID, Origin, challenge, returned
`userHandle`, sign-count and risk checks remain mandatory.

The [Security Cycle consolidation](authentication-security-cycle-consolidation-2026-10-15.md)
requires at least two active distinct credentials in `ADVANCED`. The number held and the number
used in one authentication are different: using one does not waive the two-credential holding
minimum. Its Pending handling of an already noncompliant `ADVANCED` Identity remains Pending;
this ADR supplies no bypass or automatic recovery.

## WebAuthn Discoverable Credential Policy

APP/COM registration MUST preserve `residentKey: "required"`, `userVerification: "required"`,
the existing RP ID / Origin contract and immutable opaque `webauthn_user_handle`. Discoverable
credentials remain supported and required; usernameless account selection is retired.

APP/COM authentication options MUST keep `allowCredentials` empty or omitted. Selecting an Identity
MUST NOT disclose its credential IDs, count, descriptor lengths or other credential inventory to
the browser. The former padded real-descriptor design remains rejected.

Verification MUST resolve the credential in the correct surface, verify with its stored credential
ID and public key, and compare its owner to the server-fixed Identity. Decoded returned
`userHandle` bytes MUST match the immutable stored handle. A handle, identifier, Identity ID or
other client metadata MUST NOT authorize changing the fixed Identity. Existing APP/COM exclusions
of non-discoverable credential compatibility remain in force.

## ORG Normal / Standby

### Normal

The verified Entra transaction uniquely selects the Operator; its existing transaction binding and
`tid + oid` resolution remain authoritative. Passkey ownership MUST match that Operator. No Email
or Employee Number re-entry is required at the Passkey stage. Entra alone does not establish a
session, and no alternative completion method is introduced by this decision.

### Standby

The sequence is Employee Number → Operator → existing registered Passkey → Standby Session.
Employee Number means the existing authoritative employee identifier, not a guessed model field,
an internal primary key or a newly invented identifier.

Before implementing selection, establish its source of truth, requiredness, uniqueness scope,
normalization, change and reuse rules, ownership and retirement/suspension/revocation behavior
against models, database definitions and existing contracts. These guarantees have **not been
audited in this change**. A missing guarantee blocks dependent implementation until its smallest
necessary contract decision is accepted.

Standby MUST preserve `standby` authentication context, existing eligibility policy and permission
restrictions, shared WebAuthn verification, and the existing Operator credential store. Step-Up and
automatic promotion to Normal remain forbidden. Standby creates no separate Passkey type or
registration path. Historical Emergency names in routes and challenge purposes are not renamed
by this ADR.

*(Superseded 2026-10-23: ORG requires discoverable credentials; no existing credentials remain after the database reset.)* ORG non-discoverable credentials MUST retain compatibility. Their existing `allowCredentials`
behavior requires investigation before any change. A response carrying real account-specific
credential IDs may enable enumeration even when padded. Pre-authentication Identity and credential
non-disclosure remains required; the implementation MUST demonstrate compatibility and
non-disclosure together. If it cannot, that portion is **Blocked pending an additional design
decision**. Neither exposing descriptors nor silently requiring discoverable ORG credentials is
an approved resolution. The APP/COM empty-list rule is not automatically imposed on ORG.

## Security Requirements

The server-side transaction MUST fix the surface, selected Identity, authentication purpose,
browser/session/admission context, RP ID, allowed Origin, challenge, expiry, one-time consumption
and applicable authentication/risk requirements. An unresolved negative transaction carries no
authority to authenticate. Verification MUST use retained server state, recheck authoritative
eligibility and credential status, and refuse stale or mismatched bindings.

Concurrent ceremonies MUST retain independent targets. A new options request MUST NOT retarget an
older challenge. Replay, expired state, wrong purpose, another browser/admission, or a transaction
losing one-time consumption MUST NOT establish a session or revoke the winner's valid session.

Preserve CSRF, Turnstile, rate limiting, signature verification, UP/UV, RP ID / Origin validation,
credential status/ownership, user-handle verification, sign-count/risk evaluation, session limits,
Security Audit and Chronicle. Dependency failure or uncertain authentication state MUST fail closed
and remain internally diagnosable without disclosing identifiers, credentials or secrets publicly.

Base → Auth → Base admission and establishment remain separated. Auth supplies ceremony evidence;
Base alone applies the existing session-establishment authority, limits, cooldown and commit rules.
Cross-surface credentials, state and sessions MUST remain isolated.

## Threat Model and Limitations

An attacker holding a lost physical authenticator and knowing its PIN may otherwise initiate a
usernameless ceremony and select an account. Prior Identity selection removes that entry path.
It does **not** prevent compromise when the attacker also knows the victim's Email, Telephone or
Employee Number. Identifier-first MUST NOT be presented as an additional MFA factor or a complete
defense against possession plus a known PIN.

Independent additional authentication could address a different threat requirement, but requires
a separate design decision. This ADR approves none. Enumeration, timing attacks, transaction
substitution, stale contact reuse, cross-surface confusion, replay and races remain explicit abuse
cases; real authenticator account-selection UI can also show other discoverable accounts locally.
Selecting one of those credentials cannot override server-side Identity binding.

## Alternatives Rejected

- Keeping usernameless account selection: conflicts with the adopted explicit-selection contract.
- Returning APP/COM real `allowCredentials`, even padded: restores the earlier enumeration channel.
- Selecting or replacing the Identity from `userHandle` or verification parameters: permits
  transaction substitution.
- Treating an identifier as a secret or extra MFA factor: misstates the protection provided.
- Requiring a particular slot, all registered Passkeys, or relaxing the `ADVANCED` minimum:
  confuses authentication evidence with credential inventory policy.
- Inventing an ORG Employee Number column or dropping non-discoverable compatibility without
  investigation: assumes missing authority and changes an independent credential contract.

## Consequences

Users explicitly name the intended Identity, and assertions for any other owner fail. APP/COM
retain discoverable authentication without pre-authentication credential descriptor disclosure.
Identifier resolution adds privacy and transaction-binding obligations; implementation is not
equivalent to adding an input field.

UI design SHOULD place identifier entry and the Passkey action on the same screen without an
unnecessary Continue step or page transition. The existing goal of at most three user-operated
application controls from Base into authentication remains a goal. Browser/authenticator system
UI is counted separately; this decision guarantees no unattainable total interaction count.

## Supersession

No ADR is fully superseded. Historical decisions and their rationale remain intact.

| Record | Relationship | Exact scope |
| --- | --- | --- |
| [Discoverable direct sign-in](webauthn-discoverable-direct-sign-in.md) | Partially Superseded | Replace usernameless account selection in decision 1 and actor-unbound issuance in decision 3; decision 4 gains mandatory equality with the selected Identity. Preserve descriptor non-disclosure, cryptographic checks, discoverable registration, UV, RP/Origin, replay protection and existing APP/COM compatibility exclusions. Its rejection of identifier-first is limited to the old real-descriptor design. |
| [User handle](webauthn-user-handle.md) | Amended | Usernameless wording is historical; server-fixed selection now precedes verification. Preserve opaque immutable handles, decoded comparison and prohibition on client-handle authority. |
| [Identity resolution and credential binding](identity-resolution-and-credential-binding.md) | Amended | Apply effective Contact Binding resolution to APP/COM Passkey selection and require transaction-fixed ownership equality. Preserve its four-slot target, binding lifecycle and other credential contracts. |
| [Passkey lifecycle and limit](passkey-current-state-limit-and-chronicle-outbox.md) | Partially Superseded | Replace ten-per-owner capacity and refusal of the eleventh with four-slot capacity. Do not infer a new database mechanism: enforcement design and existing-data transition require investigation. Preserve owner serialization, physical lifecycle, uniqueness and Chronicle/outbox contracts. |
| [Security Mode](authentication-security-mode.md) and [Security Cycle](authentication-security-cycle-consolidation-2026-10-15.md) | Preserved | Keep their existing precedence, two-active-Passkey holding minimum, mode gates, one-Passkey evidence, Step-Up and Pending recovery/lifetime decisions. |
| [Passkey UV](passkey-uv-policy.md) and [identifier contract](identifier-contract.md) | Preserved | No UV relaxation, handle reformatting or speculative Employee Number schema. |
| [Base/Secret/Core precedence](base-secret-core-contract-precedence.md) and [Base/Auth boundary](base-auth-ceremony-and-seven-rp-boundary.md) | Preserved | Keep admission, ceremony, session and authorization ownership, including subsequent accepted amendments. |
| [ORG Entra boundary](org-entra-id-sign-in-boundary.md) | Preserved | Normal Entra resolution and Operator-bound completion remain unchanged; this ADR supplies no authority to revive historical alternative methods. |

[WebAuthn invariants](../docs/security/webauthn-security-invariants.md) and
[ORG Emergency Access](../docs/security/org-emergency-access.md) remain implementation-facing
references, not proof of this target's delivery. Their usernameless wording, generic Standby
identifier selection and padding-based non-disclosure claims require reconciliation and verification
with the future implementation; they do not override this accepted target. This change leaves docs
and executable tests untouched.

## Implementation Requirements

Implementation MUST establish the selected Identity at the resolution/transaction boundary, carry
it through challenge consumption and shared assertion verification, and preserve Base establishment
ownership. Reuse authoritative effective-contact resolution without importing Secret, OTP or
Step-Up proof semantics. Evaluate lifecycle changes between issuance and completion under the
existing ownership and concurrency boundaries.

Pending implementation work includes the Employee Number authority audit, ORG descriptor privacy
and compatibility decision where necessary, four-slot enforcement/transition investigation, and
response/timing non-disclosure verification. These are not claims of discovered code defects.
No application, schema, migration, configuration, test or UI changes are authorized by this record.

## Verification Criteria

Future implementation acceptance MUST cover these public contracts with real WebAuthn validation
and appropriate integration/concurrency checks. None were executed by this ADR-only change.

1. APP/COM refuse missing/empty/malformed identifiers; effective Email and Telephone each select
   exactly one correct surface-local Identity. Unknown, unverified, released, expired, ambiguous
   and ineligible bindings cannot authenticate.
2. Identity A plus Identity B's valid Passkey fails; each valid Passkey of A can independently
   succeed. Disabled, revoked, deleted, unknown and foreign-surface credentials fail.
3. Authentication options disclose no real APP/COM credential descriptors. Existing and unknown
   identifiers have indistinguishable pre-authentication status, shape, sizes, redirects, cookie
   behavior and assessed timing distributions; failed paths never become authenticating later.
4. Reuse, expiry at and around its boundary, wrong purpose, RP ID, Origin, handle, signature,
   UP or UV fail. Browser/session/admission mismatch, replay and concurrent resubmission cannot
   retarget a transaction or establish more than one sign-in; losers preserve the winning session.
5. ORG Normal keeps its unique Entra-selected Operator. Standby requires authoritative Employee
   Number ownership and current eligibility, uses existing Passkeys including non-discoverable
   credentials, and demonstrates non-disclosure or remains blocked. Standby cannot Step-Up or
   become Normal through completion, refresh or renewal.
6. Base/Auth admission, establishment, session limits, cooldown, Security Mode gates, the
   `ADVANCED` two-credential minimum and audit continuity remain intact. Four-slot capacity covers
   the nearest reachable below/at/above-limit cases and concurrent last-slot registration without
   silently deleting existing credentials.
