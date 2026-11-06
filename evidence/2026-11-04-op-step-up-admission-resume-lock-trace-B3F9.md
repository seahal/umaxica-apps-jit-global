# O-10 admission and Visa resume lock trace

Date: 2026-11-04

## Scope

Read-only trace of Base/Auth admission binding, Step-Up admission, Auth switch, APP social-link and
Visa APP session-limit resume paths in the O-10 principal / OP lock inventory.

## Observed result

- APP and ORG Auth ceremony-binding controllers and Base confirmation delegate to
  `BaseAuthAdmissionCoordinator.with_admission_binding_lock!`. For a bound admission, the
  coordinator acquires the Base principal before OP device, token, parent, binding and Auth-session
  locks.
- `BaseStepUpAdmissionIssuer` acquires the actor before root/device and OP transaction locks. The
  conflict-parent selector's `FOR UPDATE` read has no enclosing transaction and releases its
  statement lock before the later issuer call.
- Auth's switch locks only the OP authorization parent and Auth ceremony; no principal row is
  acquired in that method.
- APP social-link completion and unlink take Client before OP candidate/device/token/grant locks.
  The order is actor-first, while O-9/O-11 migration and the O-10 source commit boundary remain
  separate unresolved work.
- Visa APP session-limit OIDC resume takes Client before finalizing the OP authorization parent and
  nested login follows the actor-first issuer.

No reverse actor / OP edge was found in these bounded paths. The inventory now names 26 of the 88
lexical candidate paths by full path; the remaining 62 are not a defect count, and the full graph
remains incomplete.

## Evidence and limits

- Inspected the controller / concern callsites and
  `app/services/base_auth_admission_coordinator.rb:616–637,1340–1368`,
  `app/operations/base_step_up_admission_issuer.rb:70–88`, and the Visa resume path.
- Recomputed the named-path count from the inventory's recorded search expressions.
- No tests, application code, or databases were changed or accessed.

HEAD: `b30345216886c98af1f04cbd434f067f12decf01`. The worktree was extensively uncommitted; this
read-only trace was against the worktree content.
