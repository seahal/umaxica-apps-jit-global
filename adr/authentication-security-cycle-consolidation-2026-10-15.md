# ADR: Authentication Security Cycle Consolidation (2026-10-15)

**Status:** Accepted (2026-10-15). Decision record only. Nothing in this ADR is implemented by the
change that added it; every "decided" item below is a target for later implementation work, and
every "Pending" item remains undecided.

This ADR records which items of the authentication security audit are decided, which are deferred,
and how the earlier ADRs are partially superseded. Where this ADR and an earlier ADR conflict, this
ADR wins within the scope stated in "Supersession".

## Work-unit numbering

The audit numbers its work units `WU-1` to `WU-9`. Later design discussion kept `WU-1` and `WU-2`
and called items 3 to 9 `XU-3` to `XU-9`. `WU-N` and `XU-N` name the same audit item for every N
from 3 to 9; they are never tracked as two items. This ADR uses `WU-N`.

## Cycle scope

| Item | Subject                                     | Decision state                                                           | Implementation |
| ---- | ------------------------------------------- | ------------------------------------------------------------------------ | -------------- |
| WU-1 | CI repair                                   | Decided (section 1)                                                      | Not started    |
| WU-2 | Security Mode, sign-in, step-up             | Core decided (section 2); recovery and ORG sign-up details Pending       | Not started    |
| WU-3 | Credential change assurance, MFA toggle     | Deferred to the next cycle (section 3)                                   | Not started    |
| WU-4 | ORG Emergency                               | Design intent decided (section 4); implementation deferred               | Not started    |
| WU-5 | MFA reset and lockout                       | Deferred to the next cycle (section 3)                                   | Not started    |
| WU-6 | AAL and step-up                             | AAL usage and `required_aal` retirement decided; OIDC `acr`/`amr` Pending | Not started    |
| WU-7 | WebAuthn replay and race                    | Invariants and test-first approach decided (section 6)                   | Not started    |
| WU-8 | OIDC refresh and freshness                  | Pending (section 7)                                                      | Not started    |
| WU-9 | Ruby coverage                               | Deferred to a separate cycle (section 7)                                 | Not started    |

## 1. WU-1: CI architecture

- **1.1** The GitHub Actions Rails test and coverage jobs run through the current standard test
  path. Removed wrappers such as `scripts/test-isolated` are not restored.
- **1.2** CI prepares every database the Rails test environment requires.
- **1.3** The Valkey host and service layout used by CI match the test configuration.
- **1.4** Database safety stays fail-closed, and development database isolation is not weakened to
  make CI pass.
- **1.5** CI verifies the Rails test suite. Booting Rails in development or production is not added
  as a CI subject.
- **1.6** CI and CD are separate; CD steps not needed for this purpose are not kept in CI.
- **1.7** Stale Avatar-related tests are fixed in a way consistent with the current database layout
  and test execution path, not by restoring the old path.

## 2. WU-2: Security Mode, sign-in and step-up

### 2.1 Mode values

- `mfa_level_id` is migrated to `security_mode_id`.
- Valid modes are `NORMAL = 3` and `ADVANCED = 7` only.
- `NOTHING = 0` is not a valid authentication mode. Every other reserved value, unknown value and
  `NULL` permits neither authentication nor authorization.
- APP and COM sign up in `NORMAL`; the owner may move to `ADVANCED` by their own explicit action.
  ORG is `ADVANCED` only.
- The `WEAK`, `MEDIUM`, `FULL` and `STRICT` classification is retired.

### 2.2 `ADVANCED` passkey requirement

- `ADVANCED` requires at least **two** active, distinct passkey credentials at all times.
- "Two" counts credential records. It does not guarantee two independent physical devices.
- Email OTP, TOTP, Secret, Recovery Key, social login and Entra ID never count as passkeys.
- An ordinary deletion from two to one passkey is refused.
- A deletion from three to two passkeys is allowed only after the required authentication and
  authorization succeed. A purpose-limited re-authentication with user verification by the passkey
  being deleted is allowed. A successful authentication never waives the two-passkey minimum.
- The count check must be safe under concurrent requests; this is a mandatory implementation
  condition, and the mechanism is not chosen here.

### 2.3 Sign-in and step-up

- APP and COM `ADVANCED` sign-in requires a passkey. APP social sign-in cannot bypass it.
- Step-up method sets:

  | Mode       | APP                        | COM                 | ORG          |
  | ---------- | -------------------------- | ------------------- | ------------ |
  | `NORMAL`   | Email OTP / Passkey / TOTP | Email OTP / Passkey | not used     |
  | `ADVANCED` | Passkey                    | Passkey             | Passkey      |

- Maximum step-up validity: 15 minutes in `NORMAL`, 5 minutes in `ADVANCED`.
- Step-up evidence is bound to the actor, the session, the purpose, the target operation and the
  target resource. Evidence for an important operation is consumed once and cannot be reused for a
  different operation.
- The authorization decision is owned by the Base authorization boundary; Auth owns only credential
  ceremonies. The latest authority ADRs (`adr/base-auth-ceremony-and-seven-rp-boundary.md` and its
  successors) take precedence.

### 2.4 Passkey management and sessions

- Adding, deleting or replacing an individual passkey does not, as a rule, revoke all existing
  sessions.
- Future authentication with a deleted passkey is refused.
- Old step-up evidence cannot be reused for a different operation.
- Session revocation for Security Mode change, MFA reset, withdrawal and credential compromise
  follows separate rules.
- A `NORMAL` owner whose only method is Email OTP may register a first passkey after a
  purpose-limited Email OTP verification.

### 2.5 Owner-initiated `ADVANCED` → `NORMAL`

- Requires a purpose-limited, one-time step-up with one of the owner's registered active passkeys,
  under the `ADVANCED` 5 minute maximum.
- A second passkey, Recovery Key, Secret or other additional evidence is not required.
- After the change is committed, every existing session and refresh token is revoked and a new
  sign-in is required.
- The implementation must handle failure, retry and consistency of the cross-database update and
  revocation.
- No third party, including an Operator, may downgrade an Identity without the owner.

### 2.6 Pending under WU-2

The following remain undecided; none may be inferred from an earlier draft:

- Leaving `ADVANCED` and returning to `NORMAL` after losing every passkey.
- Recovery conditions depending on Secret, Recovery Key and Email OTP availability.
- The boundary between Operator approval and owner-held Identity management.
- ORG sign-up: state machine, invitation acceptance, Recovery Key, and Entra completion conditions.

**D-92/D-132 amendment (2026-10-23).** The previously pending handling of an `ADVANCED` actor
with fewer than two active passkeys is decided for ORG: every Operator is `ADVANCED`; one active
passkey may continue ordinary sign-in but is restricted to registering a second passkey and signing
out until it exists; zero active passkeys cannot complete ordinary sign-in. APP/COM start in
`NORMAL` and enter `ADVANCED` only by the owner's action. This decision does not decide the recovery
workflow after every passkey is lost.

Recovery proposals discussed earlier (24 hours with a Recovery Key, 72 hours without one) are not
final. The 72 hour MFA reset accepted in `adr/mfa-reset-account-recovery.md` is not applied
mechanically to these undecided `ADVANCED` recovery cases.

## 3. WU-3 and WU-5: deferred

WU-3 (credential change assurance and MFA toggle atomicity; audit IDs F02, F03, F04, MISC-0003) and
WU-5 (MFA reset and lockout; audit IDs F08, F09) are deferred to the next cycle. This ADR sets no new
rule for: write-time authorization of credential changes, MFA toggle atomicity, TOTP deletion and
credential revocation, recovery after losing every method, the Recovery Key / no Recovery Key cases,
lockout, unlock and re-registration, and multi-database consistency.

The WU-2 rules in section 2 still apply. In particular, first passkey registration by a `NORMAL`
Email-OTP-only owner (section 2.4) is not prohibited. The general safety principles of
`adr/mfa-reset-account-recovery.md` remain; its 72 hour wait and Operator approval are not
re-approved here as the final rule for every recovery case.

## 4. WU-4: ORG Emergency

Implementation changes are deferred. The design intent is:

- **4.1 Purpose.** Microsoft Entra ID / Microsoft 365 is a partial source of truth for Operator
  management. Emergency sign-in exists so ORG work does not stop entirely when Entra is unavailable.
  It is an independent sign-in path using existing passkeys. Operations that need Entra-side
  services, such as Microsoft Graph, are not guaranteed to work offline.
- **4.2 Authorization.** An Emergency session is authorized by the DB Operator roles and the
  ordinary Action Policy. Operations that do not require step-up are allowed when ordinary
  authorization allows them; Emergency alone does not make every operation read-only or
  recovery-only.
- **4.3 No step-up.** An Emergency session never succeeds at step-up, even with a valid registered
  passkey; it never reuses earlier step-up freshness; and it is never promoted to Normal. Operations
  that require step-up are therefore never allowed in Emergency.
- **4.4 Context retention.** `authn_ctx=emergency` remains the originating authentication context
  and is not lost through RP or refresh paths.
- **4.5 Lifetime (target).** An Emergency session ends at an absolute 2 hours from the first
  sign-in; refresh and rotation never extend it. This is a target decision and is not claimed to be
  implemented; if the current code uses the ordinary ORG lifetime, the current implementation and
  this target differ. Whether a new Emergency sign-in may start another session afterwards, and any
  further controls, are Pending.
- **4.6 Distinctions.** The Restricted state of `RestrictedSessionGuard` (the older session-limit
  mechanism) is unrelated to the Emergency `authentication_context`.
- **4.7 Known issues, not resolved here.**
  - `docs/security/org-emergency-access.md` states that an Emergency token carries `read:org` but
    not `write:org`. Whether that scope filter could block operations the ordinary Action Policy
    allows (4.2) is a recorded consistency question; no resolution is chosen here.
  - Important operations missing a step-up gate (GitHub issue `#884` and related) remain a known
    design issue. No inventory or controller change is made here.

## 5. WU-6: AAL and step-up

- NIST SP 800-63 terms AAL1, AAL2 and AAL3 are used for explanation and assessment only. UMAXICA
  does not claim NIST conformance beyond what is demonstrated.
- The name "Step-Up Authentication" is kept. A UMAXICA step-up success is not NIST AAL2.
- Runtime authorization does not use an AAL1/2/3 hierarchy. It uses concrete requirements such as
  `step_up_required`, `allowed_methods`, `phishing_resistant_required`,
  `user_verification_required`, `full_reauthentication_required`, `ttl`, `scope`, and
  session/token/actor/resource binding.
- `required_aal` is deprecated and will be removed completely in stages: the Ruby API, the database
  columns, the signed Ceremony Grant claim, legacy accessors and compatibility tests. Nothing is
  removed by this ADR. Compatibility and migration of in-flight transactions must be investigated
  before removal. An AAL requirement is never converted mechanically into step-up conditions.
- `required_aal` and the OIDC `acr` claim are different things and are not treated as one.

**Pending:** the meaning, issuance conditions and any change of OIDC `acr` and `amr`. Removing them,
changing `acr=aal1`/`acr=aal2`, and changing the `id_token` or `access_token` claim contract are not
decided. Issuer/RP consistency is the next item to study. Existing `acr`/`amr` values are not
substituted for step-up authorization conditions.

## 6. WU-7: WebAuthn replay and race

Invariants (implementation pending):

- Concurrent submissions of the same challenge or assertion consume the challenge successfully at
  most once and establish at most one sign-in.
- A request that loses the race does not revoke the winner's valid session.
- Normal authentication with a different challenge is not blocked.
- Purpose, surface, actor and session boundaries are preserved.
- Scope covers sign-in, registration, step-up and ORG Emergency.

Approach: first verify current behavior with concurrent HTTP integration tests, then make the
smallest fix for each demonstrated defect. The mechanism (PostgreSQL compare-and-set, row lock,
optimistic lock or other) is not chosen before verification. Core replay safety is not postponed.

## 7. WU-8 and WU-9

- **WU-8 (Pending).** OIDC refresh, `prompt`, `max_age`, `auth_time` and RP session
  synchronization. Existing refresh grant code is not evidence that every RP behaves correctly. This
  ADR does not override separate design work on RP source-of-truth polling intervals, logout
  synchronization or refresh token operation.
- **WU-9 (Deferred).** Ruby coverage re-measurement and improvement move to a separate cycle;
  coverage thresholds, waivers and test targets are unchanged.

## Supersession

| Earlier ADR | Superseded part | Replacement |
| --- | --- | --- |
| `adr/authentication-security-mode.md` | A4 and E1 (minimum of one passkey in `ADVANCED`) | Section 2.2: at least two |
| `adr/authentication-security-mode.md` | E2 (delete P1 of two) | Section 2.2: two to one is refused; three to two only |
| `adr/authentication-security-mode.md` | C3, the clause "never satisfies ... Persona/RP authorization" | Section 4.2–4.4; the scope question in 4.7 stays open |
| `adr/authentication-security-mode.md` | F1–F5 (recovery cases, 24/72 hours) | Returned to Pending (sections 2.6, 3) |
| `adr/authentication-security-mode.md` | G2 (ORG sign-up completion) | Returned to Pending (section 2.6) |
| `adr/authentication-security-mode.md` | Open decision 2 (downgrade re-authentication) | Decided in section 2.5 |
| `adr/mfa-reset-account-recovery.md` | The 2026-10-15 amendment adopting 24/72 hour `ADVANCED` recovery | Withdrawn; Pending (section 3). The base ADR is otherwise unchanged and not re-approved for all recovery cases |
| `adr/authentication-assurance-level-boundaries.md` | AAL1/AAL2/AAL3 as runtime authorization boundaries; "authorization policy owns the required AAL" | Section 5: concrete requirements; AAL vocabulary for assessment only |
| `adr/step-up-authentication-redesign.md` | Any runtime use of a required AAL level | Section 5 |

All other parts of these ADRs remain in force.

## Rationale

Recording decisions separately from Pending items keeps earlier drafts (one passkey minimum, 24/72
hour recovery, `ADVANCED`-only ORG sign-up conditions) from being implemented as if final, and keeps
`acr`/`amr` stable for RPs until issuer and consumer are studied together. Two passkeys make the
loss of one credential survivable without a recovery workflow. Concrete step-up requirements state
what an operation needs; an AAL label does not, and treating step-up success as AAL2 would overstate
assurance.

## Related

- `adr/authentication-security-mode.md`
- `adr/mfa-reset-account-recovery.md`
- `adr/step-up-authentication-redesign.md`
- `adr/authentication-assurance-level-boundaries.md`
- `adr/refresh-revoke-aal-downgrade-and-replay-hardening.md`
- `adr/oidc-claims-decision.md`
- `adr/operator-capability-authorization.md`
- `docs/security/org-emergency-access.md`
