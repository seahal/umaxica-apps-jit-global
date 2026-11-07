# Experience, Cookie Consent and Affinity redesign

## Status

Open design and implementation work. The owner approved the three-unit direction recorded in the
2026-11-04 decision log, but the log still contains unresolved design decisions. No new persistence
model, route or cookie for these units is authorized by this backlog entry alone.

## Scope

Replace the old Preference redesign with three explicit units:

- Browser Experience and Account Experience, with a derived Display Snapshot;
- Cookie Consent, with its own owner and lifecycle;
- Affinity, limited to non-authoritative browser guidance.

Keep APP, COM and ORG database and credential boundaries separate. Do not revive the old
sign-in/sign-out copy rules, dual writes, `localStorage` or `sessionStorage` design. The detailed
decision history and current item-level states are in
`plans/archive/0003-authentication-handoff-work-logs/five.md`, sections C0-C15. That archive is
historical context; accepted ADRs and any future accepted spec remain normative.

## Work before implementation

1. Resolve the remaining items in `five.md` C5: cookie and JWS shape/lifetime/recovery; Display
   Snapshot freshness and delivery failures; Affinity recording, retention and reset; independent
   Browser/Account resets; Cookie Consent evidence and identifier; route/method ownership and PUT
   behavior; accepted ADR amendments; legacy notification and Chronicle/adult-gate handling; Web
   Push binding and explicit disabled-vs-unset semantics; and the durable location/version of the
   accepted design.
2. Update the owning ADRs and create an accepted spec with observable acceptance tests, DB and
   cookie shapes, lock/write order, retention, reset behavior and recovery outcomes. Obtain the
   required data-shape approval before migrations or persisted/API shape changes.
3. Reconcile the spec with current code, schema, routes, localization and tests. Record the
   before-state and a per-acceptance verification plan.
4. Implement and verify each unit independently, then run the affected authentication boundaries
   and full suite. Keep failures classified against the captured baseline.

## Bounded work already recorded

`five.md` C9.1 records prior bounded UI and test slices: theme order, non-persisting notification
scaffolding, a method rename and `PreferenceSelect` synchronization. They do not implement any of
the three persistence units and must not be used as acceptance evidence for this redesign without
rechecking their cited tests in the implementation work.

## Open defect: region overlay overrides the saved language

Recorded 2026-11-07 during the two.md acceptance run; the owner assigned the fix to this redesign
(five.md) instead of the two.md acceptance work. Not fixed.

- Observed: on `https://www.umaxica.app/preference/language/edit`, `?ri=jp` renders Japanese even
  when English is saved, and `?ri=us` renders English even when Japanese is saved. A request without
  `ri` (for example the Auth `/social/google/callback`) uses the saved language.
- Cause: `PreferenceRequestOverlay#overlay_language`
  (`app/controllers/concerns/preference_request_overlay.rb`) resolves `lx`, then the language
  inferred from `ri` (`jp` → `ja`, `us` → `en`), then the saved `Actor.preferences.language`.
- Conflict: the Accepted `adr/localization-preference-flow.md` orders language as `?lx`, then the
  explicitly saved language, then `?ri` seeding only for users with no language set, then the
  default `ja`. The code places `ri` above the saved language.
- Design input: the `explicit_fields` marker that told a saved language from a default was removed
  by the WU-7 cutover, so the fix has to define what counts as a saved language in the new shape
  (for example, a language present in the verified Preference JWT) and check whether any writer
  stores a region-inferred language as if it were chosen.
- Acceptance for the fix: with a saved language, both `?ri=jp` and `?ri=us` render the saved
  language on Base, Auth and Visa; `?lx` still overrides for that request; without a saved language,
  `ri` still seeds the language; covered through public requests.

## Handoff

The detailed C5 list, C9.1 implementation state and C9.2 ADR conflicts are copied into the
handoff archive and summarized in `plans/2026-11-07-handoff-status.md`. Resume with design
decisions; do not infer owner approval from the old work log.
