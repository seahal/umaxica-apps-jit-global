# SNS Subject and Resource Boundary

Status: Deferred and excluded from the current Persona/Organization authority program (2026-09-17).

## Current contract

`Avatar` remains an existing SNS-facing domain boundary with its current storage, routes, bootstrap,
assignment, membership, handle, and social-edge behavior. This record is not an implementation plan
for changing that subsystem.

The current authority foundation does not add or redesign:

- Avatar functionality, Avatar RBAC, Avatar lifecycle, or ownership;
- organization hierarchy, Unit/Position/Appointment, or Persona–Organization membership;
- staff-forced ownership transfer or a new break-glass path; or
- a shared Persona/Organization model, cross-surface authority table, or cross-database foreign key.

The existing Avatar graph is compatibility evidence only. It must not be used to infer ownership,
grant authority, or provide a permanent fallback for the surface-local authority tables. The
mechanical `Persona` concrete-model rename is documented in
[`avatar-account-bridge.md`](avatar-account-bridge.md).

## URL boundary

The existing human-facing Avatar handle uses `@` as a fixed URL/display prefix and stores the handle
without `@`. The complete reserved-character allocation is in
[`docs/reference/url-identifier-policy.md`](../reference/url-identifier-policy.md). No new route is
introduced by this authority work.

## Future work gate

Any SNS/Avatar change requires a separate decision backed by a current model/data inventory,
cross-database consistency analysis, explicit authorization semantics, migration safety, and
regression tests. Earlier bridge and hierarchy alternatives remain in Git history rather than as
competing current guidance.
