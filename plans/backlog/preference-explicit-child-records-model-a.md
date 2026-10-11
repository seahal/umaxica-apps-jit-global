# Backlog: Move Preference Child Records To The Explicit-Only Model A

Status: Backlog. Follow-up to the implemented Model B.

## Problem

Model B distinguishes an explicit setting from an unset default with two representations: every
child record always exists, and the parent carries an `explicit_fields` marker
(`app/models/concerns/preference_explicit_fields.rb`). The long-term model (Model A) is simpler: an
absent child record means unset, and `explicit_fields` is removed.

## Direction

- Preference bootstrap (`create_preference_options` in the preference base concern) does not create
  child records for types without an explicit value.
- Viewing an edit screen never persists a child; rendering uses an in-memory default, as
  `load_or_build_preference_child` already does.
- Every iteration over `CHILD_RECORD_TYPES` (adoption, resource sync, core) becomes nil-safe.
- The preferences payload omits unset keys instead of filling defaults.
- A migration removes `explicit_fields` from the app, com, and org preference databases.

## Decide before starting

- Existing data: whether default-valued child records already persisted are treated as unset and
  deleted. Deletion needs an irreversibility and rollback plan and a staged dual-read release.
- Much code assumes children always exist; strengthen regression tests first.
- Roll out per soft bubble (app, com, org databases separately).

## Done when

- Users without an explicit language are still region-seeded from `?ri` (same external behavior as
  Model B).
- `explicit_fields` is gone and child-record absence consistently means unset.
