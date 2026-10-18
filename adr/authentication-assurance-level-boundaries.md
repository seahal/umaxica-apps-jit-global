# ADR: Authentication Assurance Level Boundaries

**Status:** Partially superseded (2026-08-31)

> **Partial supersession (2026-10-15):** `adr/authentication-security-cycle-consolidation-2026-10-15.md` section 5 makes
> AAL1/AAL2/AAL3 explanation and assessment vocabulary only. Runtime authorization uses concrete
> requirements, not an AAL hierarchy, and a UMAXICA step-up is not NIST AAL2. OIDC `acr`/`amr`
> remain Pending.

> **Partial supersession (2026-08-31):** Email OTP is never achieved NIST AAL; TOTP alone and
> current UV passkey ceremonies are recorded as AAL1; fresh Umaxica step-up, achieved AAL, phishing
> resistance, method policy, and freshness are independent.
>
> **Earlier partial supersession (2026-06-02):** The vocabulary and security properties in this ADR
> remain useful, but authority ownership is superseded by `adr/identity-authority-boundary.md`.
> `acme/www` owns session, token, account, preference, authorization, downstream-token trust, and
> step-up freshness. `sign/id` owns only credential inventory and short-lived credential ceremony
> state.

## Context

The authentication and step-up code already uses the terms `aal1` and `aal2` in token claims and
refresh behavior. The product also needs a clear future boundary for extremely sensitive operational
actions, such as approving keys that can shut down or materially disable the system.

The system is not claiming strict NIST SP 800-63 conformance. However, the NIST AAL vocabulary is a
useful shared language for separating authentication boundaries. Using only `AAL1`, `AAL2`, and
`AAL3` avoids inventing local levels such as `AAL0` or `AAL4`, which are not part of the NIST
conceptual model.

## Decision

Use `AAL1`, `AAL2`, and `AAL3` as product authentication-boundary terms.

- **AAL1** is the baseline signed-in boundary. Methods that can establish a normal login/session are
  AAL1 methods.
- **AAL2** is the step-up boundary for sensitive signed-in actions. Methods that can satisfy the
  step-up authentication gate are AAL2 methods.
- **AAL3** is reserved for future high-impact operational control, including system-shutdown or
  materially destructive administrative actions. AAL3 is not implemented yet.

No product behavior should introduce or depend on `AAL0`, `AAL4`, or other local AAL values.

Credential inventory is the source of truth for immediate credential counts. Persisted actor status
columns are materialized availability state for coarse gates and routing; they must be maintained
from the same inventory rules and must not introduce separate classification logic.

Persist materialized AAL credential availability on the actor record and session freshness on the
token record. Authorization policy is the source of truth for which assurance boundary, method set,
and scope a sensitive action requires. Controllers may carry inventory or assertion metadata for
CI/review, but runtime enforcement must not treat controller metadata as the source of truth for
step-up requirements. Controllers must not be the source of truth for whether an actor has AAL1,
AAL2, or contact-identifier credentials.

- `Authentication::CredentialInventory` owns immediate DB-backed classification and counts.
- Actor records (`Client`, `Visitor`, `Operator`) own materialized credential-availability status.
- Token records (`ClientToken`, `VisitorToken`, `OperatorToken`) own recent AAL2 completion state.
- Step-up session records own temporary step-up workflow state.
- Actor convenience methods and controller / concern helpers must call the same inventory service.
- Authorization policies own action/resource-specific step-up requirements.
- Step-up gates own challenge issuance, redirects, return targets, continuation, and session/ticket
  mutation. Policies must not perform those HTTP or session side effects.

## Boundary Definitions

### AAL1

AAL1 covers authentication sufficient to create or maintain a normal signed-in session.

Current AAL1 sign-in methods are surface-aware:

| surface | AAL1 sign-in methods                                            |
| ------- | --------------------------------------------------------------- |
| `app`   | email OTP, passkey, TOTP, Google social, Apple social, passcode |
| `com`   | email OTP, passkey, passcode                                    |
| `org`   | passkey, Google social, passcode                                |

`passcode` means the current sign-in code path implemented by the existing secret-backed models and
routes.

The existing implementation names `UserSecret`, `ClientSecret`, `VisitorSecret`, and the related
`secrets` routes are intentionally not renamed by this ADR. `passcode` is only the current
documentation term for the authentication method. It is not treated as a settled common noun, and
the product may rename the method again if a clearer term emerges. Current routing and UI/UX copy
also use names that do not perfectly match the documentation term. That mismatch is acceptable for
now because no single term has proven correct enough to justify a broad implementation rename.
Implementation names, documentation terms, and UI/UX labels may therefore differ until the product
settles the language.

Email address is not an AAL method by itself. Email functions as AAL1 or AAL2 only when email OTP
verification succeeds.

Telephone is not an AAL method in this product. A telephone number may be used as a personal
identifier, contact identifier, recovery input, or an entry point that starts an AAL1 sign-in flow,
but the telephone credential itself does not satisfy AAL1, AAL2, or AAL3. Knowing the telephone
number can route the actor to an actual verifier, such as TOTP, passcode, or passkey; that verifier
is the AAL method, not possession of the telephone number.

AAL1 does not imply permission to perform sensitive configuration or destructive actions.

The actor record must persist whether at least one AAL1 credential exists. The exact column name is
an implementation detail, but the state model must match the existing AAL2 availability model:

| value | name           | meaning                                                   |
| ----- | -------------- | --------------------------------------------------------- |
| `0`   | `NOTHING`      | Placeholder only. Runtime use is an implementation bug.   |
| `1`   | `ACTIVE`       | At least one surface-counting AAL1 credential exists.     |
| `5`   | `UNCONFIGURED` | No surface-counting AAL1 credential exists for the actor. |

AAL1 credential lifecycle transitions are:

| transition | decision                                                                                                                                                                                                                                                                                |
| ---------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `0 -> 1`   | Allowed only through explicit creation entry points. For `Client` and `Visitor`, this is normally sign-up or approved recovery bootstrap. For `Operator`, provisioning or another authorized flow must approve the creation, and ordinary self-service operator creation requires AAL2. |
| `1 -> N`   | Allowed after AAL2 step-up. Specific bootstrap, sign-up, or recovery routes may be explicitly exempted.                                                                                                                                                                                 |
| `N -> 1`   | Allowed after AAL2 step-up, provided at least one AAL1 credential remains after removal.                                                                                                                                                                                                |
| `1 -> 0`   | Forbidden from ordinary UI and credential-management flows. Allowed only for account deletion, withdrawal, operator-approved recovery, or explicit destructive administrative processes.                                                                                                |

Removing an AAL1 credential is a sensitive operation even when other AAL1 credentials remain. The
normal path therefore requires recent AAL2 before the removal proceeds.

### AAL2

AAL2 covers explicit step-up verification for sensitive actions.

Current surface-aware AAL2 methods are:

| surface | AAL2 methods             |
| ------- | ------------------------ |
| `app`   | email OTP, passkey, TOTP |
| `com`   | email OTP, passkey       |
| `org`   | passkey                  |

AAL2 method preference is surface-aware. For `app`, prefer phishing-resistant methods first:
passkey, then TOTP, then email OTP.

AAL2 state is short-lived and scope-bound. It is not sticky across refresh-token rotation; refreshed
access tokens return to the default AAL1 context.

Passcodes, social login, and telephone credentials do not count as AAL2 methods.

Actor `multi_factor_status_id` is the persisted AAL2 credential-availability status. It means
whether the actor currently has any surface-counting AAL2 credential; it does not mean the current
session has recently completed AAL2. Token `last_step_up_at` and `last_step_up_scope` hold the
session freshness state.

Step-up requirement is an authorization requirement. A policy decides whether a given actor may
perform a given action on a given resource and may require a recent AAL2 completion with an exact
scope and method set. The step-up gate then checks or obtains that proof. The gate may redirect,
issue challenges, create or consume step-up tickets, validate return targets, and mutate session or
ticket state. The policy must not redirect, write sessions, issue challenges, or consume return
targets.

If controller/action metadata exists for step-up, it is inventory/assertion metadata only. Runtime
behavior must fail closed when policy requirements and metadata disagree; it must not choose the
weaker requirement or merge them opportunistically. This prevents stale metadata from bypassing a
policy change.

AAL2 credential lifecycle transitions are:

| transition | decision                                                                                                                                                    |
| ---------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `0 -> 1`   | Allowed only through the AAL2 bootstrap flow, such as `/verification/setup` leading to email, passkey, or TOTP registration where that method is supported. |
| `1 -> N`   | Allowed only after recent AAL2 step-up.                                                                                                                     |
| `N -> 1`   | Allowed only after recent AAL2 step-up, provided at least one AAL2 credential remains after removal.                                                        |
| `1 -> 0`   | Forbidden from ordinary UI and credential-management flows. Allowed only through the approved MFA reset flow.                                               |

Removing an AAL2 credential requires AAL2 even when the result is still `ACTIVE`. Resetting the
actor to zero AAL2 credentials is account recovery, not credential management.

### Personal And Contact Identifiers

Personal identifiers are identifiers used to locate or disambiguate an account candidate during
login. A sign-in flow that requires a personal identifier must not allow login when the actor knows
only an AAL1 verifier but cannot supply the required personal identifier. It also must not allow
login when the actor knows only the personal identifier but cannot satisfy an AAL1 verifier.

Contact identifiers are personal identifiers that can also be used to reach, notify, or recover an
account. Contact identifiers are a subset of personal identifiers. Neither personal identifiers nor
contact identifiers are AAL levels.

The current personal identifiers are:

| credential       | personal identifier | contact identifier | AAL relationship                                                                            |
| ---------------- | ------------------- | ------------------ | ------------------------------------------------------------------------------------------- |
| email address    | yes                 | yes                | Not AAL by itself. Email OTP success may satisfy app/com AAL1 or AAL2 depending on context. |
| telephone number | yes                 | yes                | Not AAL1, AAL2, or AAL3. It is an entry point, contact point, or recovery input only.       |
| Google identity  | yes                 | no                 | Google provider authentication may satisfy AAL1 on supported surfaces.                      |
| Apple identity   | yes                 | no                 | Apple provider authentication may satisfy AAL1 on app.                                      |

The current contact identifiers are:

| credential       | contact identifier | AAL relationship                                                                            |
| ---------------- | ------------------ | ------------------------------------------------------------------------------------------- |
| email address    | yes                | Not AAL by itself. Email OTP success may satisfy app/com AAL1 or AAL2 depending on context. |
| telephone number | yes                | Not AAL1, AAL2, or AAL3. It is an entry point, contact point, or recovery input only.       |

Ordinary credential-management flows must preserve at least one usable contact identifier after a
removal. Moving from one contact identifier to zero is forbidden from ordinary UI flows. It is
allowed only through account deletion, withdrawal, approved recovery, or explicit destructive
administrative processes.

Contact-identifier deletion is sensitive because it changes the account's notification and recovery
surface. The normal path requires recent AAL2 before deletion, and the deletion guard must evaluate
the post-removal inventory with the credential excluded.

Email deletion may affect multiple dimensions at once: contact identifier count, AAL1 availability,
and AAL2 availability for surfaces where email OTP is an AAL2 method. Telephone deletion affects
contact identifier count but must not be treated as reducing AAL1, AAL2, or AAL3 availability.

Contact-identifier counts are immediate DB-backed inventory values. They are not token/session
state, and they should not be read from `Actor.authn`.

### Reverse Lookup

| method              | `app`   | `com`       | `org`       | notes                                            |
| ------------------- | ------- | ----------- | ----------- | ------------------------------------------------ |
| email OTP sign-in   | AAL1    | AAL1        | not current | Primary sign-in on app/com.                      |
| email OTP step-up   | AAL2    | AAL2        | not AAL2    | Org email is credential management, not step-up. |
| passkey sign-in     | AAL1    | AAL1        | AAL1        | Sign-in remains AAL1 until explicit step-up.     |
| passkey step-up     | AAL2    | AAL2        | AAL2        | Current phishing-resistant AAL2 method.          |
| TOTP sign-in        | AAL1    | not current | not current | Current only on app.                             |
| TOTP step-up        | AAL2    | not current | not current | Current only on app.                             |
| Google social login | AAL1    | not current | AAL1        | Current on app and org only.                     |
| Apple social login  | AAL1    | not current | not current | Current on app only.                             |
| passcode            | AAL1    | AAL1        | AAL1        | Primary or fallback sign-in code, not step-up.   |
| telephone           | not AAL | not AAL     | not AAL     | Entry point or contact credential only.          |

### AAL3

AAL3 is reserved for actions where ordinary step-up is not enough. The first expected use case is a
key or approval path that can authorize system shutdown or equivalent high-impact operational
control.

The expected surface for AAL3 is `org`, because the likely use cases are operator-only operational
controls. No app/com AAL3 behavior is planned.

AAL3 must not be modeled as "AAL2 but stronger MFA only." It should combine a stronger
authentication requirement with a stronger authorization and approval workflow.

Future AAL3 design should consider:

- dedicated AAL3-capable credentials or keys;
- approval by an operator who is not the requester;
- quorum approval, such as 2-of-N, when appropriate;
- separation between request, approval, and execution;
- audit logs for request, approval, denial, cancellation, expiry, and execution;
- notification to affected operators or security channels;
- cooldown, execution delay, abort, or rollback behavior where the operation permits it.

## Consequences

- New authentication and authorization code must describe its required boundary as AAL1, AAL2, or
  AAL3.
- Step-up implementation remains the AAL2 mechanism.
- Sensitive-action step-up requirements are policy-owned. Controller/action metadata is optional
  inventory/assertion data and must not become a second runtime source of truth.
- Policies may express assurance requirements, but step-up gates perform challenge, redirect, return
  target, continuation, and ticket/session mutation.
- Credential inventory may expose AAL and contact-identifier terminology, but AAL3 methods must
  remain empty or unsupported until an explicit AAL3 ADR and implementation exist.
- Security-sensitive deletion checks must use immediate inventory counts, including an `excluding:`
  credential, rather than relying only on request-local actor snapshots.
- Documentation should state clearly that these are product boundaries inspired by NIST language,
  not a formal compliance claim.

## Related

- `adr/step_up-step-up-redesign.md`
- `adr/refresh-revoke-aal-downgrade-and-replay-hardening.md`
- `docs/security/authentication-assurance-levels.md`
- `docs/security/step-up-mfa-status.md`

## Delivered reconciliation (2026-10-06)

This ADR's AAL vocabulary is a label ledger, not an authorization API. The explicit step-up
requirement, phishing resistance, user verification, method, scope, actor/resource binding and
freshness are evaluated independently and are carried through the delivered ceremony. Unsupported
legacy AAL demands are refused rather than translated. `docs/security/step-up-operation-inventory.md`
is the current operation matrix; older statements that make AAL the policy authority are
superseded.
