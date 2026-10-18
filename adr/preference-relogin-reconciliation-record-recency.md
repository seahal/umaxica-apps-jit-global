# Preference Re-Login Reconciliation Uses Record Recency

## Status

Accepted on 2026-05-10.

## Context

Re-login can see two preference sources for the same actor:

- session-side preference records such as `AppPreference` and `OrgPreference`
- actor-side preference records such as `UserPreference` and `OperatorPreference`

The current implementation in `Preference::Adoption` compares the two parent records' `updated_at`
values and copies all allowed preference fields from the newer side to the older side.

This can lose independent edits when the two sides change different fields while disconnected. For
example, one side may change `theme` while the other side changes `region`.

## Decision

Keep record-recency reconciliation as the accepted behavior for now.

On re-login, the newer parent preference record wins as a whole record. The copied fields remain the
allowlisted user-visible preference fields:

- language
- region
- timezone
- theme
- cookie consent fields

Do not attempt true field-level merge until the schema records per-field change metadata. Without
per-field timestamps or equivalent causality metadata, field-level merge would guess which side
changed each field and could silently preserve stale values.

## Consequences

- Re-login behavior is deterministic and easy to reason about: latest parent preference record wins.
- Users who edit different fields on different devices before re-login may see one side's complete
  preference set win.
- A future field-level merge requires a separate migration/design that records per-field metadata
  for language, region, timezone, theme, and cookie consent.
- Regression tests should assert the whole-record winner behavior so future cleanup does not
  accidentally introduce partial merge semantics.

## Related

- GH issue #629
- `docs/architecture/preference.md`
- `app/controllers/concerns/preference/adoption.rb`
