# Sign-Up Eligibility Policy

## Scope

This policy defines age eligibility for account creation. It separates account sign-up from
unauthenticated public intake on `.com`.

| Surface | Actor    | Account sign-up eligibility                                             |
| ------- | -------- | ----------------------------------------------------------------------- |
| `.app`  | Client   | Minimum age 16.                                                         |
| `.com`  | Visitor  | Minimum age 13 for authenticated Visitor account creation.              |
| `.org`  | Operator | Invitation-only. No fixed repository-level minimum age is defined here. |

## `.app` Client Account Sign-Up

Direct `.app` Client account creation is restricted to users who have reached their 16th birthday by
the date the sign-up finalization check runs.

This applies to every `.app` Client direct sign-up entry method:

- Email OTP
- Telephone OTP
- Google social sign-up
- Apple social sign-up

The implementation is resolved for these paths through `SignUpEligibilityPolicy` with
`surface: :app`, and the user-facing `.app` age-restricted copy says to try again after the 16th
birthday.

## `.com` Visitor Account Sign-Up

Authenticated `.com` Visitor account sign-up intentionally remains 13+. This is separate from `.app`
Client account creation and separate from unauthenticated `.com` intake.

The implementation is `SignUpEligibilityPolicy` with `surface: :com`.

## `.com` Guest / Reporter Intake

Unauthenticated `.com` Guest / Reporter intake must not reject a submission solely because of the
age of the Reporter or the Data Subject. Guest / Reporter intake is not the same as creating an
authenticated Visitor account.

Current product gap: the `.com` Guest / Reporter intake endpoint is not implemented yet. Do not
create that endpoint as part of account sign-up eligibility work.

## Age Calculation

Age is calculated from the submitted birthdate using the canonical `AgeEligibility` service.

- The birthday is considered reached when the current date is on or after the birthday anniversary.
- February 29 birthdays use the service's canonical leap-day handling.
- The sign-up check uses the service timezone date at finalization time.
- A calendar-impossible but structurally valid birthdate (for example `2000-02-31`) is accepted and
  stored by design (`docs/security/credential-abuse-rate-limits.md`); for age it counts as the first
  day of the following month (`2000-03-01`).

## Refusal Handling

The age is decided on the validated, unsaved birthdate before it is written (D-178). A birthdate
below the minimum age is never stored. The refusal ends the sign-up attempt as `HALTED` through
`SignUpTermination`, which removes the pending principal, contact, Passkey and Secret reservation in
the same request. If that removal fails, the existing cleanup-pending state keeps the contact held
(D-177) and the retention cleanup retries it; no further mechanism is added. All six `.app` and
`.com` entry paths share this one check (`SignUpSequenceControllerSupport`); `.org` collects no
sign-up birthdate.

## Known Implementation Gaps

Resolved:

- `.app` Client email, telephone, Google, and Apple sign-up now use the 16+ eligibility policy.
- `.app` age-restricted copy now uses 16th-birthday wording.

Intentional policy:

- `.com` authenticated Visitor account sign-up remains 13+.

Remaining product gap:

- `.com` Guest / Reporter intake is not implemented.
