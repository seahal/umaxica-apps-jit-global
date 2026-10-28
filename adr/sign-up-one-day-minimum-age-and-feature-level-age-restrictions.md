# Sign-up One-Day Minimum Age and Feature-Level Age Restrictions

## Status

**Accepted (2026-10-28, owner decision; `one.md` D-48 and R-AU-50 of the 2026-10 COM retirement
cycle). Not implemented.** Replaces the age thresholds described in
`docs/policy/signup-eligibility.md` once implemented; that document is updated in the implementing
change, not here.

**Amended (2026-10-28, owner decision):** decision 7 classifies the Preference adult-content gate as
a dormant, browser-scoped setting of the same kind as cookie consent.

## Context

Account sign-up currently gates on age. `SignUpEligibilityPolicy` requires 16 years for an `.app`
Client and 13 years for a `.com` Visitor; `.org` has no entry and is invitation-only. Under-age
sign-up ends as `HALTED`, and the `.app` copy asks the person to return after their 16th birthday.

The age machinery was put in place for a guest-support capability planned on `.org`. Keeping it
correct demanded continuous security work, and the recent stream of vulnerability fixes made it
impossible to maintain sustainably for that purpose alone.

The owner therefore decided to keep authentication and authorization on two surfaces only, `.app`
and `.org`, and to retire `.com` authentication entirely (the 2026-10 COM retirement cycle,
`one.md` D-1 and D-4). With `.com` accounts gone and the guest-support capability no longer built on
this machinery, an age threshold at sign-up no longer serves its original purpose.

## Decision

1. **The identity is the OP's foundation, not an age gate.** Account sign-up on `.app` (Client) and
   `.org` (Operator) does not decide what a person may do by age. It establishes the identity that
   the OpenID Provider authenticates.
2. **Minimum age at sign-up is one day.** Sign-up on `.app` and `.org` accepts any birthdate that is
   at least one calendar day before the date of the check, so a newborn can register from the day
   after birth. `.org` follows the same rule as `.app`. On `.org` the organization that takes the
   Operator on can still refuse that person; that decision belongs to the organization, not to the
   sign-up age rule.
3. **A birthdate of today or later is refused.** Today is refused deliberately: a birthdate equal to
   the current date is what an unattended or automated sign-up produces when nobody enters a date,
   so accepting it would admit sign-ups that no person completed. Future dates remain invalid as
   before.
4. **The birthdate is still collected and validated.** Only the minimum age changes.
5. **Age-based restrictions move to the features that need them.** Avatars and other features decide
   whether a person may use them according to age. Those rules belong to each feature and are not
   designed by this decision.
6. **`.com` is out of scope.** Its Visitor sign-up is removed with COM authentication, together with
   the 13-year threshold.
7. **The adult-content gate is a dormant, browser-scoped setting in the consent class.**
   - *Dormant.* No controller uses the Preference `adult_content_gate` today, and none is added now:
     no screen sets it, no request reads it, and the Preference class registry does not list it.
     The model layer keeps it: the child and option models, their tables and the read accessors on
     the Preference models stay, because earlier decisions had to account for it and a feature may
     need it again.
   - *Kind of setting.* It is set per browser and must be checked on every request that depends on
     it. It is therefore the same kind of setting as cookie consent, not a display setting such as
     theme or language. It belongs with the values the retired assurance cookie used to carry
     (consent, region, Web Push opt-in): their authority is Base's database row for this browser,
     never the shared display cookie and never a value the browser can supply.
   - *Consequences of that classification, binding on any future use.* The value is not placed in
     the shared display cookie (`__Secure-experience`). It is not copied to or from the account's
     actor-local preference, at sign-in or on save, because it belongs to the browser and not to
     the person. A host that cannot read Base's row treats the value as unknown and applies the
     restrictive default, as non-Base hosts treat consent as absent. It is never derived from the
     sign-up birthdate, which no longer filters by age (decision 2).
   - *Changing this.* Putting the gate back into use, including adding a screen, a reader or a
     registry entry, requires a new owner decision that amends this record. That decision also
     settles how the gate relates to the feature-level age rules of decision 5.

## Consequences

- `SignUpEligibilityPolicy` no longer carries per-surface age thresholds of 16 and 13. Whether `.org`
  receives an explicit policy entry or relies only on the birthdate validation is decided in the
  implementing design.
- The under-age refusal path and its "16th birthday" copy are replaced: the only refusal left is a
  birthdate of today or later.
- The date boundary must be defined explicitly (service timezone date, as in the current age
  calculation, or another reference) and tested immediately below, at and above it: yesterday
  accepted, today refused, tomorrow refused.
- A person who was under the former thresholds can now hold an identity. Any feature with an age
  requirement must enforce it itself before this change ships to production; until such rules
  exist, no feature may assume that sign-up filtered by age.
- The Preference `adult_content_gate` sign-in override (`force_underage_r18_stopper!`) is removed in
  the same cycle (`one.md` D-31). Where age-based content restrictions live afterwards is an open
  item (`one.md` BL-9).
- Decision 7 removes the gate from every code path outside the model layer: the
  `PreferenceClassRegistry` entries (which today make preference creation, snapshots and sign-in
  reconciliation iterate it), the sign-in override above and the sign-out rotation's exclusion
  branch. A static invariant keeps references to `adult_content_gate` and `AdultContentGate` inside
  the model layer. `Actor::Preference` already omits the field, and its test asserts that.
- Existing child rows, if any, are left in place; removing the tables would need its own decision
  and an approved destructive migration.

## Related

- `docs/policy/signup-eligibility.md` — current thresholds, to be updated when implemented.
- `docs/backlog/2026-10-26-sign-up-minimum-age-removal.md` — the backlog record this decision picks
  up.
- `app/policies/sign_up_eligibility_policy.rb`,
  `app/controllers/concerns/sign_up_sequence_controller_support.rb`,
  `app/models/concerns/has_birthdate.rb` — current enforcement points.
- `app/controllers/concerns/preference_class_registry.rb`, `app/models/*_preference_adult_content_gate*.rb`
  — the registry entries removed by decision 7 and the models it keeps.
- `adr/xper-phase-zero-bootstrap.md` — records the gate's option codes (`0` no choice, `1` approved,
  `2` deny), which remain valid for the retained tables.
