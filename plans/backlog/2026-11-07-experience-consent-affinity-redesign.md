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

## Handoff

The detailed C5 list, C9.1 implementation state and C9.2 ADR conflicts are copied into the
handoff archive and summarized in `plans/2026-11-07-handoff-status.md`. Resume with design
decisions; do not infer owner approval from the old work log.
