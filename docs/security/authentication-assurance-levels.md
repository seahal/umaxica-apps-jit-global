# Authentication Assurance Levels

> **Partially superseded by Identity Authority inversion:** The AAL vocabulary in this document
> remains useful only where it does not assign session, token, authorization, or step-up freshness
> authority to `sign/id`. `acme/www` is the Session, Token, Account, Preference, Authorization, and
> downstream-token Authority. `sign/id` is ceremony-only. Existing sign-side physical tables/models
> do not imply sign-side authority. Do not use this document to reintroduce sign-side sessions,
> refresh, preference, dashboard, account lifecycle, token issuance, logout, or step-up freshness.

Fresh Umaxica step-up, achieved AAL, phishing resistance, allowed methods, and freshness are
independent conditions. Email OTP may complete APP/COM normal step-up but has no achieved NIST AAL;
TOTP alone and current UV passkey ceremonies record AAL1, while passkey is phishing-resistant.

## Surface policy

| surface | sign-up / sign-in                                                | normal step-up                                         | passkey UV                                             |
| ------- | ---------------------------------------------------------------- | ------------------------------------------------------ | ------------------------------------------------------ |
| APP     | Email OTP and passkey (plus existing documented primary methods) | Passkey preferred; TOTP and Email OTP are alternatives | required for registration and sign-in                  |
| COM     | Email OTP and passkey (plus existing documented primary methods) | Passkey and Email OTP                                  | required for registration and sign-in                  |
| ORG     | Passkey, Secret Credential, and Microsoft Entra ID               | Passkey only                                           | required for registration where applicable and sign-in |

Email OTP on APP and COM is an explicit Umaxica product exception. It completes normal step-up
freshness, but neither Email OTP nor TOTP alone satisfies NIST AAL2. ORG does not use Email OTP for
sign-up, sign-in, or step-up. A future operation may independently require an AAL, phishing
resistance, a restricted method set, and a freshness window.

This product uses `AAL1`, `AAL2`, and `AAL3` as authentication-boundary terms.

The terminology is inspired by NIST SP 800-63, but this document does not claim strict NIST
conformance. The terms are used so implementation, review, and operations have a shared vocabulary.
No other local AAL levels, such as `AAL0` or `AAL4`, are used.

## Levels

| level  | product meaning                                                                | implementation status                                                                         |
| ------ | ------------------------------------------------------------------------------ | --------------------------------------------------------------------------------------------- |
| `AAL1` | Baseline signed-in session. Methods that can establish login/session state.    | Current                                                                                       |
| `AAL2` | Achieved assurance evaluated from the complete authentication ceremony.        | Supported as a requirement; no current normal step-up method is automatically promoted to it. |
| `AAL3` | Reserved for highest-impact operational control, such as system-shutdown keys. | Future                                                                                        |

## AAL1

AAL1 is the normal authentication boundary. A method that can sign an actor in, or maintain a normal
signed-in session, is an AAL1 method.

Current AAL1 sign-in methods are surface-aware:

| surface | AAL1 sign-in methods                                            |
| ------- | --------------------------------------------------------------- |
| `app`   | email OTP, passkey, TOTP, Google social, Apple social, passcode |
| `com`   | email OTP, passkey, passcode                                    |
| `org`   | passkey, passcode                                               |

`passcode` means the current sign-in code path implemented by the existing secret-backed models and
routes.

Email address is not an authenticator. Successful Email OTP may establish APP/COM authentication or
normal step-up, but it does not achieve NIST AAL2.

Telephone is not an AAL method in this product. A telephone number may be used as a personal
identifier, contact identifier, recovery input, or an entry point that starts an AAL1 sign-in flow,
but the telephone credential itself does not satisfy AAL1, AAL2, or AAL3. Knowing the telephone
number can route the actor to an actual verifier, such as TOTP, passcode, or passkey; that verifier
is the AAL method, not possession of the telephone number.

AAL1 does not permit sensitive configuration, credential removal, session revoke-all, withdrawal, or
other actions that require step-up.

## Credential Inventory

Immediate credential counts come from `Authentication::CredentialInventory`.

Actor convenience methods and controller / concern helpers may expose the inventory, but they must
call the same service. Security-sensitive checks, such as deleting an email or telephone, should use
the DB-backed inventory with the candidate credential excluded instead of relying only on a
request-local `Actor` snapshot.

Persisted actor status columns are materialized availability state for coarse gates and routing.
They must be maintained from the same inventory rules and must not introduce separate classification
logic.

### AAL1 Availability State

The actor record should persist whether the actor has any AAL1 credential. The persisted state is a
materialized availability value; immediate deletion checks still use credential inventory.

The AAL1 availability state follows the same reference-value shape as AAL2 availability:

| value | name           | meaning                                                 |
| ----- | -------------- | ------------------------------------------------------- |
| `0`   | `NOTHING`      | Placeholder only. Runtime use is an implementation bug. |
| `1`   | `ACTIVE`       | At least one AAL1 credential exists for the actor.      |
| `5`   | `UNCONFIGURED` | No AAL1 credential exists for the actor.                |

### AAL1 Credential Transitions

| transition | behavior                                                                                                                                                                                                                                                                       |
| ---------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `0 -> 1`   | Allowed only through explicit entry points. For `Client` and `Visitor`, this is normally sign-up or approved recovery bootstrap. For `Operator`, provisioning or another authorized flow must approve the creation, and ordinary self-service operator creation requires AAL2. |
| `1 -> N`   | Allowed after fresh normal step-up. Specific bootstrap, sign-up, or recovery routes may be explicitly exempted.                                                                                                                                                                |
| `N -> 1`   | Allowed after fresh normal step-up, provided at least one AAL1 credential remains after removal.                                                                                                                                                                               |
| `1 -> 0`   | Forbidden from ordinary UI and credential-management flows. Allowed only for account deletion, withdrawal, operator-approved recovery, or explicit destructive administrative processes.                                                                                       |

Removing an AAL1 credential is a sensitive operation. The normal removal path requires recent normal
step-up even when the actor will still have one or more AAL1 credentials afterward.

Adding Google or Apple to an already-established `app` account is a post-enrollment `1 -> N`
credential transition and requires fresh Step-Up. The provider ceremony alone does not authorize
binding that identity to the current UMAXICA account. Initial provider enrollment remains governed by
the sign-up transaction, and social-identity removal retains its Step-Up and no-lockout guards. See
[`adr/social-identity-linking-requires-step-up.md`](../../adr/social-identity-linking-requires-step-up.md).

Social-login unlink has a narrower no-lockout rule than the general AAL1 inventory. For `app`,
removing Google or Apple social login must leave at least one verified email OTP, active passkey, or
active social login provider other than the removed provider. Passcode remains an AAL1 method, but
it is not counted as the remaining method for Google / Apple unlink.

## Achieved Assurance And Step-Up

Umaxica step-up completion and NIST achieved AAL are independent facts. A normal protected operation
may require fresh, scope-bound reauthentication without requiring AAL2. Its requirement can
independently constrain `step_up_required`, `required_aal`, `phishing_resistant_required`,
`allowed_methods`, and freshness.

The current ceremony evidence is recorded as follows:

| method    | completes normal step-up | achieved AAL | phishing-resistant |
| --------- | ------------------------ | ------------ | ------------------ |
| Email OTP | APP and COM              | `none`       | no                 |
| TOTP      | APP                      | `aal1`       | no                 |
| Passkey   | APP, COM, and ORG        | `aal1`       | yes                |

Email OTP is an explicit Umaxica exception. It can establish APP/COM authentication and complete
normal step-up, but it is never silently promoted to NIST AAL2. TOTP alone also does not achieve
AAL2. Passkey assurance is derived from the verified WebAuthn ceremony; the current UV-required
ceremony records AAL1 and phishing resistance rather than assuming AAL2.

Step-up scope, freshness, purpose, audience, session binding, token binding, method policy, achieved
AAL, and phishing resistance are checked separately. A signed ceremony result cannot satisfy a
transaction whose required AAL or phishing-resistance condition exceeds its recorded evidence.

Credential registration is not step-up satisfaction. Adding a credential may change available
methods, but it must not update token freshness. The `multi_factor_status_id` materialized state
means that a normal step-up method is configured; it is not proof of achieved AAL2.

## Personal And Contact Identifiers

Personal identifiers are identifiers used to locate or disambiguate an account candidate during
login. A sign-in flow that requires a personal identifier must not allow login when the actor knows
only an AAL1 verifier but cannot supply the required personal identifier. It also must not allow
login when the actor knows only the personal identifier but cannot satisfy an AAL1 verifier.

Contact identifiers are personal identifiers that can also be used to reach, notify, or recover an
account. Contact identifiers are a subset of personal identifiers. Neither personal identifiers nor
contact identifiers are AAL levels.

Current personal identifiers:

| credential       | personal identifier | contact identifier | AAL relationship                                                                                                  |
| ---------------- | ------------------- | ------------------ | ----------------------------------------------------------------------------------------------------------------- |
| email address    | yes                 | yes                | Not AAL by itself. Email OTP may authenticate or complete APP/COM normal step-up, but does not achieve NIST AAL2. |
| telephone number | yes                 | yes                | Not AAL1, AAL2, or AAL3. It is an entry point, contact point, or recovery input only.                             |
| Google identity  | yes                 | no                 | Google provider authentication may satisfy AAL1 on supported surfaces.                                            |
| Apple identity   | yes                 | no                 | Apple provider authentication may satisfy AAL1 on app.                                                            |

Current contact identifiers:

| credential       | contact identifier | AAL relationship                                                                                                  |
| ---------------- | ------------------ | ----------------------------------------------------------------------------------------------------------------- |
| email address    | yes                | Not AAL by itself. Email OTP may authenticate or complete APP/COM normal step-up, but does not achieve NIST AAL2. |
| telephone number | yes                | Not AAL1, AAL2, or AAL3. It is an entry point, contact point, or recovery input only.                             |

Ordinary credential-management flows must preserve at least one usable contact identifier after a
removal. Moving from one contact identifier to zero is forbidden from ordinary UI flows. It is
allowed only through account deletion, withdrawal, approved recovery, or explicit destructive
administrative processes.

Contact-identifier deletion is sensitive because it changes the account's notification and recovery
surface. The normal path requires recent normal step-up before deletion, and the deletion guard must
evaluate the post-removal inventory with the credential excluded.

Email deletion may reduce contact identifier count, AAL1 availability, and normal step-up
availability at the same time. Telephone deletion reduces contact identifier count only; it must not
be treated as reducing AAL1, AAL2, or AAL3 availability.

Contact-identifier counts are immediate DB-backed inventory values. They are not token/session
state, and they should not be read from `Actor.authn`.

## Authentication And Step-Up Matrix

| surface | sign-up / sign-in                                                                                              | normal step-up                              |
| ------- | -------------------------------------------------------------------------------------------------------------- | ------------------------------------------- |
| APP     | Email OTP and passkey are allowed; existing social and other primary flows remain governed by their own policy | Passkey, TOTP, Email OTP; passkey preferred |
| COM     | Email OTP and passkey are allowed                                                                              | Passkey, Email OTP                          |
| ORG     | Passkey, Secret Credential, Microsoft Entra ID                                                                 | Passkey only                                |

ORG Email OTP is not an authentication or step-up method. COM does not gain a Visitor TOTP lifecycle
in this change. Surface policy and the signed transaction method set are intersected server-side, so
a direct request cannot expand the permitted methods.

## AAL3

AAL3 is reserved. It is not implemented.

The intended future use is for operations where AAL2 is not enough, such as approving a key that can
shut down or materially disable the system. AAL3 should be treated as strong authentication plus a
strong approval workflow, not simply as another MFA prompt.

The expected surface for AAL3 is `org`, because the likely use cases are operator-only operational
controls. No app/com AAL3 behavior is planned.

Future AAL3 design should include separate request, approval, and execution steps; non-self
approval; audit logs; notification; and, where appropriate, quorum, cooldown, abort, or rollback
behavior.

## Implementation Notes

- AAL1 inventory answers whether an actor retains a baseline sign-in method.
- Normal step-up inventory answers whether an actor retains a method permitted by the surface
  policy. It is not an AAL2 inventory.
- `uv_verified_at` records successful use in a UV-required ceremony. A legacy passkey with a NULL
  value remains selectable so successful UV can establish compatibility, but credential-removal
  guards do not treat it as the final guaranteed UV-capable fallback.
- AAL3 remains unsupported until a future ADR defines it.
- Contact-identifier inventory is independent from authentication assurance.

## WebAuthn User Verification Policy

Passkey ceremonies resolve their `userVerification` requirement through the closed
`Webauthn::UvPolicy` registry (`app/values/webauthn/uv_policy.rb`); call sites never pass raw policy
strings. Server-side enforcement (`verify(..., user_verification: true)` plus explicit
`user_verified?` / `user_present?` re-checks) follows the same policy.

| Purpose             | Flow                                          | Policy   |
| ------------------- | --------------------------------------------- | -------- |
| `registration`      | sign-up and settings passkey registration     | required |
| `direct_sign_in`    | identifier-first passkey sign-in              | required |
| `mfa_challenge`     | passkey as second factor after another factor | required |
| `ordinary_step_up`  | step-up verification for sensitive settings   | required |
| `high_risk_step_up` | reserved for future high-risk operations      | required |

The purposes are deliberately distinct so a future decision can relax exactly one of them (e.g.
`ordinary_step_up`) without changing the UV-required sign-in and registration paths; any such change
requires updating `docs/security/webauthn-security-invariants.md` and `adr/passkey-uv-policy.md`
first. Only a user-verified, user-present assertion supports the AAL2-aligned claim
(`Webauthn::AuthenticationContext#aal2_aligned?`).
