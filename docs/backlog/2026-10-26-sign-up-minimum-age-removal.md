# Sign-up minimum age reduced to one day on app and org

Status: Deferred by owner decision (2026-10-26). Not part of the com authentication retirement
cycle. No implementation change is authorized by this entry.

## Decision to carry out

- Account sign-up on `.app` (Client) and `.org` (Operator) accepts anyone whose birthdate is at
  least one day before the date of the check ("0 years 1 day"). A birthdate of today or later is
  still rejected.
- The birthdate is still collected and validated; only the minimum age changes.
- Age-based restrictions move out of sign-up and into the features that need them (for example
  avatars). That direction is not designed yet.
- `.com` is out of scope: the com authentication retirement cycle removes `.com` Visitor sign-up
  entirely.

## Current state (static reading, `aeb09ca9fb97ef1ca24c0195b2fa1d28d21245df`)

- `app/policies/sign_up_eligibility_policy.rb`: `APP_CLIENT_DIRECT_SIGN_UP_MINIMUM_AGE = 16`,
  `COM_VISITOR_ACCOUNT_SIGN_UP_MINIMUM_AGE = 13`. There is no `:org` entry; calling the policy with
  `surface: :org` raises `ArgumentError`.
- `app/controllers/concerns/sign_up_sequence_controller_support.rb:154` refuses sign-up through
  `SignUpEligibilityPolicy.minimum_age_reached?`.
- `app/models/concerns/has_birthdate.rb` rejects a future birthdate on persist.
- `docs/policy/signup-eligibility.md` documents app 16+, com 13+ and org invitation-only with no
  fixed minimum. The user-facing `.app` age-restricted copy refers to the 16th birthday.

## To decide when this is picked up

- Whether `.org` gets an explicit policy entry, or stays outside `SignUpEligibilityPolicy` with only
  the birthdate validation.
- What replaces the age-restricted copy and the `HALTED` refusal path for under-age sign-up.
- Where age-based restrictions live once they leave sign-up. A related item is the Preference
  `adult_content_gate`, whose sign-in age override (`force_underage_r18_stopper!`) the com
  retirement cycle removes.
