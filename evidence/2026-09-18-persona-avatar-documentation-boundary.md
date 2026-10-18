# Persona and Avatar Documentation Boundary

Date: 2026-09-18 Branch: `feature` Baseline HEAD before this documentation slice: `2c84285dd`

## Checks performed

- Read the accepted naming ADR, the current authority implementation reference, the identity/
  account/organization/avatar dictionary, the Collective hierarchy ADR, and the Avatar bridge/SNS
  decision documents.
- Searched the scoped current references for obsolete claims that Persona is a concrete shared
  Account model, that Collective is the adopted shared authority hierarchy, or that the Avatar
  bridge is part of the current authority rollout.
- Updated the dictionary to the surface-local `ClientPersona` / `Individual` / `Agent` and
  `Enterprise` / `Company` / `Bureau` mappings.
- Replaced the old Collective hierarchy and Avatar bridge/SNS proposals with concise superseded or
  deferred boundary records. Existing Avatar code, routes, tables, and bootstrap behavior were not
  changed.
- Updated the ADR and documentation indexes to distinguish current authority references from
  deferred historical records.
- `git diff --check` — passed.

## Result

The current documentation no longer presents shared Collective authority, Identity-owned resources,
or an Avatar bridge redesign as an active requirement. The existing Avatar boundary remains
excluded; only the already-implemented `ClientPersona` mechanical mapping is documented.
