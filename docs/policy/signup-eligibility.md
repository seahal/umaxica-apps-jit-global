# Sign-Up Eligibility Policy

## Scope

This policy defines birthdate eligibility for account creation. `.com` account sign-up is retired
with com authentication; `.app` and `.org` follow one shared rule and keep account sign-up separate
from feature-level age rules.

| Surface | Actor    | Account sign-up eligibility                                              |
| ------- | -------- | ------------------------------------------------------------------------ |
| `.app`  | Client   | Birthdate at least one calendar day before the service date.             |
| `.org`  | Operator | Invitation provisioning is currently closed; the one-day rule is available in the shared policy. |

The rule is
`adr/sign-up-one-day-minimum-age-and-feature-level-age-restrictions.md`: sign-up establishes the
identity that the OpenID Provider authenticates and does not gate by age.

## The One-Day Rule

A birthdate is eligible only when it is at least one calendar day before the service date of the
sign-up check.

- Yesterday is the closest eligible birthdate; a newborn can register from the day after birth.
- Today is refused deliberately: a birthdate equal to the current date is what an unattended or
  automated submission produces when nobody enters a date.
- Tomorrow and later stay invalid as before.

`SignUpEligibilityPolicy.eligible?` is the canonical named check for both surfaces. `HasBirthdate`
model validation independently refuses a birthdate on or after today. Feature-level age rules (for
example an adult-content gate) are each feature's own concern and are not part of sign-up
eligibility.

## `.app` Client Account Sign-Up

The explicit eligibility check applies to every `.app` entry method:

- Email OTP
- Telephone OTP
- Google social sign-up
- Apple social sign-up

There is no age threshold left; the former 16th-birthday copy and the under-age `HALTED` branch are
removed (ADR decision, R-AU-50). The only birthdate refusal is today or later, answered with
`sign.shared.birthdate.errors.not_before_today`.

## `.org` Operator Sign-Up

The invitation endpoint currently refuses all provisioning while the Bureau migration is pending.
The shared policy accepts `surface: :org` and applies the one-day rule without falling back to an
age threshold, but the closed invitation workflow does not establish an end-to-end birthdate check.
Reopening that workflow requires the invitation decision and the one-day check to both succeed.

## `.com` Intake

`.com` authentication and its Visitor accounts are retired (2026-10 com retirement cycle); the
former thirteen-year Visitor threshold is gone with them. Unauthenticated `.com` Guest / Reporter
intake is a separate, not-yet-implemented product surface and must not reject a submission solely
because of the age of the Reporter or the Data Subject.

## Age Calculation for Feature Rules

Feature-level rules that still need an age use the canonical `AgeEligibility` service:

- The birthday is considered reached when the current date is on or after the birthday anniversary.
- February 29 birthdays use the canonical leap-day handling.
- Features use the service timezone date at check time and set their own minimum.
- A calendar-impossible but structurally valid birthdate (for example `2000-02-31`) is accepted and
  stored by design (`docs/security/credential-abuse-rate-limits.md`); for age it counts as the first
  day of the following month (`2000-03-01`).

The current Rails code also exposes `HasBirthdate#minimum_age_reached?`, `#adult_for_nsfw?`, and
`#nsfw_unlockable?`. A 2026-10-31 source inventory found no application call sites for those
methods outside their definitions. Adult-content preference models and values remain in the
repository; their presence is not proof that a feature checks age. The inventory does not cover
external products or deployed code, so owners must verify each age-dependent feature before release.

## Refusal Handling

The date is decided on the validated, unsaved birthdate before it is written (D-178). An
ineligible birthdate is never stored. Under the one-day rule an ineligible birthdate answers
`422` with the public copy and keeps the checkpoint active; it no longer terminates the sign-up as
`HALTED` solely because of age. Other `HALTED` reasons (confirmation, eligibility, phase refusals)
keep their existing semantics.
