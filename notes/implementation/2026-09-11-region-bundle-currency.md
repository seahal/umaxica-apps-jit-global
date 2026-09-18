# Region Bundle Currency Implementation Notes

## Context

- Original request: setting region to `us` on `/preference/region/edit` rewrote language and clock
  (en / 12h) but left currency at `jpy` instead of `usd`. Same gap on `app`, `org`, and `com`.
- Related decisions/docs: `docs/architecture/preference.md` "Region is a regional-bundle reset",
  `adr/localization-preference-flow.md`, `notes/implementation/2026-09-09-ux-preference-asset-hostname-fixes.md`.
- Implementation date: 2026-09-11.

## Decisions Made During Implementation

- Decision: add `currency` to the existing regional-bundle reset (`REGIONAL_DEFAULT_OPTION_NAMES`
  and the child load in `set_region_preferences_update`), not a separate write.
  - Why: currency is already grouped under the region screen (`preference_group_screen` returns
    `:region` for `:currency`, same as date format and clock). The 2026-09-09 bundle reset extended
    language with date/clock and omitted currency; that was the gap.
  - Mapping: `us` → `USD`, `jp` → `JPY`. Each value stays overridable on the currency screen.
  - Alternatives considered: request-local `?cu` seeding on bootstrap only — rejected; the report
    is a `/preference/region` write, and bootstrap already seeds language from `?ri` without
    rewriting the other region-owned fields until that write.
  - Follow-up needed: none. Timezone is not region-owned (no single US timezone) and was not added.

## Deviations From Plan

- None. The 2026-09-09 bundle table is extended in place.

## Review Notes

- Tests run: `bin/rails test test/integration/acme_preference_test.rb test/controllers/concerns/preference/core_test.rb test/controllers/concerns/preference_write_authorization_refusal_test.rb test/controllers/concerns/preference/base_test.rb` — 260 runs, 0 failures.
- Tests not run: full `bin/rails test`. Browser verification was not available (no DevTools MCP).
- Documentation promotion needed: ADR clarification and `docs/architecture/preference.md` table
  already updated in this change.
