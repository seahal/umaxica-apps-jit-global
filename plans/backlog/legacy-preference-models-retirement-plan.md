# Legacy Preference Models Retirement Plan

## Issue

GitHub #691

## Doctrine Reference

This plan operates under `adr/preference-soft-bubble-doctrine.md` (2026-05-06):

- Preference databases stay **separate** (`principal` / `operator` / `com_preference`).
- Com actor-local preferences stay in `com_principal` per the 2026-05-18 placement update in
  `adr/preference-soft-bubble-doctrine.md`; the older customer-to-`com_preference` plan is archived
  at `plans/archive/customer-preferences-move-to-com-preference-db.md`.
- `Actor::Preference` is the **single runtime read interface**.
- Session-side families (`AppPreference` / `ComPreference` / `OrgPreference`) are **not retired**;
  they were introduced deliberately so the front-end side does not own preference state.

This rewrites the earlier 2026-04 version of this plan, which assumed full database consolidation
and retirement of all session-side models. Those assumptions are no longer correct.

## Goal

Reduce preference-model duplication and dead code without changing database boundaries.

What "retirement" means under the soft-bubble doctrine:

- **Retire**: schema duplication that has no behavioral need (e.g., 3 near-identical option tables;
  obsolete bridge / status / activity tables that no caller reads).
- **Retire**: Ruby class duplication where one shared abstraction is sufficient (e.g., collapsing
  per-prefix code that differs only by class name).
- **Retire**: legacy bridge tables (`user_app_preferences`, `staff_org_preferences`) if and when
  they have no behavioral purpose.
- **Keep**: `AppPreference` / `ComPreference` / `OrgPreference` themselves.
- **Keep**: User / Staff / Customer actor-side records.

## Current State (2026-05-06)

### Preference DBs and what lives there

| DB              | Session-side       | Actor-side                                   | Bridge                  | TLD |
| --------------- | ------------------ | -------------------------------------------- | ----------------------- | --- |
| `principal`     | `app_preference_*` | `user_preference_*`, `staff_preference_*` ⚠️ | `user_app_preferences`  | app |
| `operator`      | `org_preference_*` | (target for `staff_preference_*` after move) | `staff_org_preferences` | org |
| `com_setting`   | `com_preference_*` | —                                            | —                       | com |
| `com_principal` | —                  | `visitor_preference_*`                       | —                       | com |

Historical planned moves were later superseded or completed outside this retirement plan:

- `customer_preferences`: `guest` → `com_preference`
  (`plans/archive/customer-preferences-move-to-com-preference-db.md`, superseded by the 2026-05-18
  placement update)
- `staff_preference_*`: `principal` → `operator`
  (`plans/archive/staff-preference-move-to-operator-db.md`)

The current doctrine keeps session-side preferences in setting DBs and actor-local preferences in
principal DBs. `com_principal` retains the com actor-local preference family.

### Class registry (per-prefix duplication)

`app/services/preference/class_registry.rb` declares **6 prefixes** (`App`, `Com`, `Org`, `User`,
`Staff`, `Customer`), each with up to 8 sub-keys:

- `preference`, `status`, `cookie`, `audit`, `audit_event`, `audit_level`, `option_classes` (4),
  `record_classes` (4)

Concrete model count today (under `app/models/`):

- Session-side App / Com / Org families: ~16 classes each → ~48 classes
- Actor-side User / Staff / Customer families: ~7 classes each → ~21 classes
- Bridges: `UserAppPreference`, `OperatorOrgPreference`
- Total: ~70 preference-related classes

### Cross-bubble code paths

- `app/controllers/concerns/preference/adoption.rb` — login-time sync between session-side and
  actor-side. Active for App↔User and Org↔Staff. Visitor is not in `Adoption`; Com→Visitor sync goes
  through `Preference::ResourceSync` / `Preference::Core` across the `com_setting` → `com_principal`
  boundary.
- After both bubble-closure moves complete, `Preference::Adoption#resolve_cross_db_option_id`
  becomes dead code (no double-write path crosses bubbles anymore).
- `app/controllers/concerns/actor_support.rb` — already reads via the unified `Actor::Preference`
  interface; this part is the doctrine-aligned target shape.

## Migration Strategy

This plan stages work to align with the doctrine without committing to specifics that belong to
other plans.

### Phase 1 — Inventory and dead-code identification

Scope: read-only audit. No schema or model deletion yet.

1. List all 70-ish preference classes and group by:
   - Has callers outside the preference subsystem (controllers / views / services / models)?
   - Has migrations that reference it?
   - Is it referenced only by `ClassRegistry` and tests?
2. Classify into:
   - **Active** — has external callers
   - **Internal-only** — only used inside the preference subsystem
   - **Unreferenced** — no callers (deletion candidate)
3. Identify bridge tables (`user_app_preferences`, `staff_org_preferences`) usage and whether they
   carry information the actor-side records do not already hold.

### Phase 2 — Class registry abstraction (depends on C3)

Scope: code-only. No schema changes. **Blocked on C3 plan.**

The 6-prefix × 8-subkey registry contains heavy duplication. C3 (a separate plan) will design how to
abstract `ClassRegistry` so prefix-symmetric code is written once.

This Phase tracks the cleanup that becomes possible once C3's abstraction lands:

- Remove duplicated audit / option / record class declarations that the abstraction makes redundant.
- Remove per-prefix branching in concerns (`Preference::Core`, `Preference::Adoption`,
  `Preference::Base`) that survives only because of registry duplication.

### Phase 3 — Actor-side schema decision (depends on B2)

Scope: schema design decision. **Blocked on B2 plan.**

User / Staff use normalized child tables; Customer uses denormalized columns. Whatever B2 decides —
normalize Customer, denormalize User/Staff, or wrap with an adapter — this Phase implements the
resulting cleanup, including dropping the redundant tables on the side that loses.

### Phase 4 — Adoption role decision (depends on B3)

Scope: behavior change. **Blocked on B3 plan.**

If B3 reduces or removes `Preference::Adoption`, this Phase removes its support infrastructure
(`adoptable_preference_class?`, `find_or_create_resource_preference!`, cross-DB option-id resolution
helpers) and any tables that exist only to support adoption.

### Phase 5 — Schema cleanup

Scope: schema-level. Run after Phases 2-4 settle.

- Drop tables that Phase 1 marked unreferenced and Phases 2-4 confirmed not needed.
- Drop bridge tables (`user_app_preferences`, `staff_org_preferences`) if Phase 1 confirmed no
  behavioral use.
- Remove per-DB columns that no longer have callers.

### Phase 6 — Activity / chronicle table review

Scope: separate-but-related. Optional.

`*_preference_chronicle*` and `*_preference_activity*` tables exist per session-side family. Decide
whether they should consolidate (and where), or stay per-bubble. Out of scope for the first pass;
tracked as a follow-up.

## Out of Scope (handled by other plans)

- DB consolidation of any kind (rejected by doctrine)
- Moving `customer_preferences` from `guest` to `com_preference`
  (`plans/archive/customer-preferences-move-to-com-preference-db.md`, superseded)
- `ClassRegistry` redesign (C3 — separate plan)
- Actor-side schema asymmetry decision (B2 — separate plan)
- `Preference::Adoption` role re-evaluation (B3 — separate plan)
- Per-subdomain `Current` (jump / acme / sign) design (A5 — separate ADR)
- Stale historical item: auth access-token `prf` claim format changes. Current behavior no longer
  emits or reads auth access-token `prf`; preference snapshots belong to the Preference JWT.
- Cookie consent / token rotation behavior changes

## Blockers

- Phase 2 is blocked on the C3 plan (not yet authored).
- Phase 3 is blocked on the B2 plan (not yet authored).
- Phase 4 is blocked on the B3 plan (not yet authored).
- Phases 1, 5, 6 can proceed independently once approved.

## Acceptance Criteria

- [ ] Phase 1 inventory document committed (lists active / internal-only / unreferenced classes and
      bridge-table usage).
- [ ] Each soft bubble (`principal` / `operator` / `com_preference`) keeps its session-side and
      actor-side families and contains no preference-related dead tables.
- [ ] `guest` DB no longer contains preference tables (handled by separate plan; tracked here as a
      dependency).
- [ ] `Preference::ClassRegistry` no longer hard-codes 6 × 8 entries (handled by C3; tracked here as
      a dependency).
- [ ] Cookie consent, Preference JWT projection integrity, and preference edit flows have regression
      coverage. that survives the cleanup.
- [ ] No production read path bypasses `Actor::Preference` for preference values.

## References

- `adr/preference-soft-bubble-doctrine.md` — doctrine this plan obeys
- `plans/archive/customer-preferences-move-to-com-preference-db.md` — superseded com TLD bubble
  closure note
- `plans/archive/staff-preference-move-to-operator-db.md` — org TLD bubble closure
- GH issue #578 — `Actor::Preference` runtime consolidation status
- `plans/archive/actor-support-integration-test-coverage.md` — `ActorSupport` request-lifecycle test
  coverage
- `plans/archive/gh628-move-preferences-to-setting-db.md` — rejected predecessor (kept for
  traceability)
- `app/services/preference/class_registry.rb` — current registry
- `app/controllers/concerns/preference/adoption.rb` — current Adoption logic
- `app/controllers/concerns/actor_support.rb` — current `Actor::Preference` resolver

## 2026-05-07 What to leave as current differences and improvements

The DB movement assumptions in this document are older than the current tree.

Confirmed:

- The `customer_preferences` system has been moved to the `com_preference` DB side.
- `staff_preference_*` exists on the `operator` side.
- `Actor::Preference` has been implemented and is used as a runtime read interface.

Therefore, this document is rescoped as a deduplication plan around preferences rather than a DB
migration plan.

Improvements to leave:

- Inventory current callers and need for `UserAppPreference` / `OperatorOrgPreference` bridge.
- 6 prefix for `Preference::ClassRegistry` x Separate duplicate keys into those that can be deleted
  and those that should be abstracted.
- `AppPreference` / `ComPreference` / `OrgPreference` themselves are currently treated as retention
  targets.
- Deletion decisions are based on regression testing of `Actor::Preference`, cookie consent, JWT
  Preference JWT projection. Test the projection first and then fix it.
