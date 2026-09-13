# Step-Up MFA Status

> **Partially superseded by Identity Authority inversion:** The credential availability vocabulary
> in this document remains useful only where it does not assign step-up freshness, session, token,
> or settings authority to `sign/id`. `acme/www` is the Session, Token, Account, Preference,
> Authorization, and downstream-token Authority. `sign/id` is ceremony-only. Existing sign-side
> physical tables/models do not imply sign-side authority. Do not use this document to reintroduce
> sign-side sessions, refresh, preference, dashboard, account lifecycle, token issuance, logout, or
> step-up freshness.

This document describes the current step-up gate used by the `app`, `com`, and `org` sign
configuration surfaces.

`/verification` is intentionally shared by Acme and Sign. On Acme, `/verification` is the
authority-side request, completion, and cancellation gate. On Sign, `/verification` is the
credential-side ceremony and cancellation surface. Passkey/WebAuthn ceremony belongs to `sign/id`,
and cancellation closes a pending verification request without granting step-up freshness.

Step-up is the product's current `AAL2` boundary. The broader AAL terminology is defined in
`docs/security/authentication-assurance-levels.md`.

## Purpose

Step-up protects sensitive signed-in pages, such as personal information, credential management,
session revocation, and withdrawal. Lightweight users may sign up without being forced to register
MFA immediately, but sensitive pages either require recent step-up or route the actor into MFA
registration when no step-up method exists.

## Columns

`multi_factor_id` is the actor policy level. It describes the requested MFA strength and must not be
used as the credential-availability cache.

`multi_factor_status_id` is the credential-availability cache:

| value | name           | meaning                                                                       |
| ----- | -------------- | ----------------------------------------------------------------------------- |
| `0`   | `NOTHING`      | Placeholder only. Runtime checks raise because this is an implementation bug. |
| `1`   | `ACTIVE`       | At least one surface-counting step-up method exists.                          |
| `5`   | `UNCONFIGURED` | No surface-counting step-up method exists. New actors default here.           |

## Surface Criteria

The status is recalculated from surface-specific step-up methods:

| surface | `ACTIVE` when any of these exist                              |
| ------- | ------------------------------------------------------------- |
| `app`   | verified user email, active user passkey, or active user TOTP |
| `com`   | verified visitor email or active visitor passkey              |
| `org`   | active operator passkey                                       |

When multiple app step-up methods are available, prefer passkey, then TOTP, then email OTP.

Telephone numbers, social identities, and passcodes do not count as step-up methods. Telephone is
also not an AAL1 method by itself; it may be an entry point into an AAL1 sign-in flow, but the
verifier used after that entry point is the AAL method.

Email addresses and telephone numbers are contact identifiers. Contact identifiers are PII used for
notification, reachability, or recovery, and ordinary credential-management flows must preserve at
least one usable contact identifier. This contact-identifier minimum is separate from AAL2
availability: deleting a telephone can violate the contact-identifier minimum even though telephone
is not a step-up method.

## Page Classes

Pages fall into three classes:

| class                         | behavior                                                                                                                  |
| ----------------------------- | ------------------------------------------------------------------------------------------------------------------------- |
| No step-up                    | The page does not read `multi_factor_status_id`.                                                                          |
| Sensitive                     | The page requires step-up. If status is `UNCONFIGURED`, it redirects to setup first.                                      |
| Bootstrap-exempt registration | The page allows access without step-up only while status is `UNCONFIGURED`; once status is `ACTIVE`, it requires step-up. |

Bootstrap-exempt registration actions are:

| surface | bootstrap-exempt actions                                    |
| ------- | ----------------------------------------------------------- |
| `app`   | email registration, passkey registration, TOTP registration |
| `com`   | email registration, passkey registration                    |
| `org`   | passkey registration                                        |

For `org`, email registration is credential management, not bootstrap. The first step-up method is
operator passkey.

## Runtime Rule

Controllers use `multi_factor_status_id` through the shared verification concern. They do not decide
bootstrap by checking only their own credential type. For example, an `app` user with a verified
email has status `ACTIVE`, so `/settings/totps` requires step-up even if the user has no TOTP.

Successful credential registration updates the status through model callbacks. The standard
credential registration audit events continue to record the actual registration.

## MFA Reset Recovery

MFA reset is not a step-up method and must not bypass step-up. When an actor loses all usable MFA
material, the reset path follows the account-recovery design in
`docs/security/mfa-reset-account-recovery.md`.

After an approved reset revokes the actor's surface-counting credentials, `multi_factor_status_id`
is recalculated. If no step-up method remains, the actor returns to `UNCONFIGURED` and must use the
existing bootstrap-exempt registration flow before sensitive actions can pass normal step-up again.

## Restricted Mode

A session established through org Emergency Access is not eligible to perform step-up-protected
operations at all, regardless of the credentials the Operator holds. This is an authentication
context decision rather than a freshness one: the ceremony entry is refused, `StepUpResolver` never
reports satisfaction, and the freshness committer refuses to write. There is no separate Emergency
step-up mechanism, and normal step-up behaviour is unchanged. See
`docs/security/org-emergency-access.md`.
