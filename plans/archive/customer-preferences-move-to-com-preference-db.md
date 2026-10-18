# Move CustomerPreference Family to `com_preference` Database

## Status

Archived as superseded (verified 2026-05-19).

Do not implement this plan as written. The accepted placement update in
`adr/preference-soft-bubble-doctrine.md` now states that session-side surface preferences live in
`app_setting` / `org_setting` / `com_setting`, while actor-local preferences stay in the matching
principal database. The current runtime therefore uses `VisitorPreference < ComPrincipalRecord`
backed by `visitor_preferences` in `db/com_principal_schema.rb`.

## Summary

The `customer_preferences` series tables currently exist in the `guest` DB, but this is a role
mismatch.

`guest` DB is an actor-related DB for other purposes such as contact / communication rights, and
`com` Session side preference (`com_preferences` series) is already `com_preference` It's in the DB.
`customer_preferences` series, which is an actor preference corresponding to Com, is also
`com_preference` It should be aligned with the DB.

## Motivation

- `com_preference` DB already holds `com_preference_*` as a preference-only bubble.
- If you place `customer_preferences` in `com_preference` DB, Com side (session-side + (actor-side)
  preferences are completed within a single bubble, reducing the need for special cross-DB
  considerations.
- `guest` DB is reduced to contact-related responsibilities.
- `Preference::Adoption` is the same DB only for App ↔ User and Org ↔ Staff (`principal` /
  `operator`), the current asymmetry where only Com ↔ Customer crosses the DB will be resolved.

## Current State (2026-05-06)

### `guest` subordinate (target for movement)

- `customer_preferences` (Denormal: `language`, `region`, `timezone`, `theme`, cookie consent column
  directly)
- `customer_preference_languages`, `customer_preference_language_options`
- `customer_preference_regions`, `customer_preference_region_options`
- `customer_preference_timezones`, `customer_preference_timezone_options`
- `customer_preference_colorthemes`, `customer_preference_colortheme_options`

### Under `com_preference` (existing/nearby)

- `com_preferences` family (normalization, option_id foreign key method)

### code reference point

- `app/models/customer_preference.rb` — Comments and implicit destination for
  `# Database name: com_principal`
- `app/models/customer_preference_*.rb` 8 files
- `app/services/preference/class_registry.rb` — `"Customer"` entry
- `app/controllers/concerns/preference/core.rb` — `sync_to_resource_preference!` at `ComPreference`
  → `CustomerPreference` synchronization (cross-DB access)
- `app/controllers/concerns/preference/adoption.rb` — Customer is not applicable
  (`adoptable_preference_class?` is true only for App/Org)

## Target State

- All `customer_preferences` series exist in `com_preference` DB.
- `# Database name: ` comment in `app/models/customer_preference*.rb` points to `com_preference`.
- The parent class of the connection destination changes from `ComPrincipalRecord` to
  `ComPreferenceRecord` (or `ComPreferenceRecord` itself).
- Com → Customer synchronization of `Preference::Core#sync_to_resource_preference!` can be done
  within the same DB.
- `customer_preference_*` table is removed from `guest` DB (after cutover completes).

## Migration Steps (high level)

1. **Schema porting**:
   - `db/com_preferences_migrate/` to `customer_preferences` Added migration for creating system
     tables.
   - The structure will remain **as is** (denormal) for the time being. B2 (actor-side Separately
     implemented after the schema unification) is decided.
2. **Model connection destination change**:
   - Change the parent class of `app/models/customer_preference*.rb` from `ComPrincipalRecord`
     series. Changed to `ComPreferenceRecord`.
   - Updated schema comment (`# Database name: com_principal` → `com_preference`).
3. **Data migration**:
   - One-time migration that copies the entire data from the existing `guest` side to the
     `com_preference` side.
   - `customer_id` refers to `customers.id` present in `principal` / `guest` application-level
     Because it is an FK, it remains a cross-DB reference (no FK constraints). `SettingPreference`
     It follows the pattern that has already been adopted in advance.
4. **Cutover**:
   - Switch both reading and writing to `com_preference` side.
   - Added migration to `db/guests_migrate/` to delete the guest side table after switching.
5. **verification**:
   - Sign / Acme Edit preferences for each surface (region / language / timezone / colortheme /
     cookie) consent) integration test is green.
   - Com → Customer synchronization of `Preference::Core#sync_to_resource_preference!` does not
     regress.
   - JWT `prf` claims and `Actor::Preference` must be consistent.

## Out of Scope

- Change to normalization of `customer_preferences` (denormal column → option_id FK format). This is
  actor-side Independent as a schema unification (B2) issue.
- Organize `guest` DB tables other than `customer_preferences` (contact type, etc.).
- Add Customer to `Preference::Adoption`. This will be determined together with Adoption's role
  re-evaluation (B3).
- Added new preference keys.

## Risks / Notes

- The application-level FK to `customer_id` remains the same, but the `customers` table changes to
  `guest` If the cross-DB reference point is the same (or increases or decreases) before and after
  the move, set `customers` before moving. Locate the table.
- Depending on the number of production data of the existing `customer_preferences`, it is necessary
  to secure maintenance time.
- Delete the guest side table after completing data migration and confirming read path switching.

## Acceptance Criteria

- [ ] `customer_preferences` type tables exist in `com_preference` DB.
- [ ] The connection destination of `app/models/customer_preference*.rb` is `com_preference`.
- [ ] `Preference::Core#sync_to_resource_preference!` is completed within the same DB.
- [ ] The `customer_preference_*` table has been deleted from the `guest` DB.
- [ ] Preference editing / cookie consent / token rotation regression test is green.

## References

- Related policy (draft schedule): `adr/preference-soft-bubble-doctrine.md` (DB remains separate
  bubble, only interface unified with `Actor::Preference`)
- Related plan: `plans/backlog/legacy-preference-models-retirement-plan.md` (planned to be
  rewritten)
- Related plan: GH issue #578 (aggregation of `Actor::Preference`)
- Related ADR (existing): `adr/setting-preference-remove-polymorphic-owner.md`
  (`ComPreferenceRecord` precedent for adoption)

## 2026-05-07 What to leave as current differences and improvements

DB movement assumptions for this plan have been overwritten by subsequent decisions.

Confirmed:

- `app/models/visitor_preference.rb` inherits from `ComPrincipalRecord`.
- `db/com_principal_schema.rb` has `visitor_preferences` and child tables.
- 2026-05-18 placement update of `adr/preference-soft-bubble-doctrine.md` is actor-local The policy
  of placing preferences in the matching principal database is correct.

Therefore, this document will remain in the archive as superseded decision material, rather than as
a "migration plan awaiting implementation."

Improvements to leave:

- Remove old assumptions for `customer_preference*` from docs/plans.
- `Preference::Core#sync_to_resource_preference!` / `Preference::ResourceSync` Com -> Fix Visitor
  synchronization as current `com_setting` -> `com_principal` boundary in test.
- Whether or not to add a Visitor to `Preference::Adoption` is treated as a design decision separate
  from this migration.
- Do not mix with the name arrangement of `colortheme` -> `theme`.
