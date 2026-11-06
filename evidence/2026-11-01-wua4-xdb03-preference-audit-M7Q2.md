# WU-A4 XDB-03 preference-change audit

- HEAD: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`.
- The worktree had pre-existing uncommitted changes and remains uncommitted. No unrelated work was
  reverted.
- Implemented the owner-approved `preferences_changed` contact audit event. The event stores contact
  kind, owner/contact/actor references, operation reference, and occurrence time; it stores no
  address or old/new preference values. A changed email preference writes the event in the same App
  Zenith transaction. A failed audit write rolls back the preference update while the independently
  committed OP Step-Up remains consumed.
- Added migrations `20261101174445` and `20261101174545` to add and validate the event-name
  constraint. The first migration's down path refuses to remove the event type while matching audit
  history exists.
- Both migrations are `up` in local Development and Test `app_zenith`. No Production or Neon
  database was accessed.
- Added a validated event-specific check requiring `preferences_changed` to be an Email event with a
  nonblank actor reference. Before that check, read-only local queries found zero matching rows in
  Development and Test. Migrations `20261101175512` and `20261101175522` are also `up` in both
  databases.
- Regenerated only `db/app_zenith_structure.sql` from the local Test database with
  `RAILS_ENV=test bin/rails db:schema:dump:app_zenith`. Its `client_contact_audit_event` constraint
  includes `finalized`, `released`, and `preferences_changed`;
  `client_contact_audit_preference_change_actor` enforces the event-specific contact and actor
  requirements.
- Targeted tests before the change: 16 runs, 107 assertions, 0 failures/errors/skips. The initial
  implementation selection passed at 19 runs/128 assertions; after the event-specific model/database
  guard, the same committer, commit-order and audit-delivery selection passed at 21 runs/133
  assertions, all with `PARALLEL_WORKERS=1`.
- Scoped RuboCop passed with no offenses on the original 6-file set and the 4-file guard follow-up.
  `ruby -c` and scoped `git diff --check` passed.
- Updated the Contact audit state diagram and both current transition inventories with the App Email
  preference source and the selected verification result. `four.md` now distinguishes the approved
  XDB-03 Email event from the still-pending XDB-04 TOTP event shape; the reviewable TOTP proposal is
  `plans/2026-11-01-wua4-totp-audit-shape-review.md`.
- `bin/rails db:verify_no_schema_drift` exited 1 and reported nine paths: `app_setting`,
  `app_zenith`, `avatar`, `chronicle`, `occurrence`, `op_base_app`, `op_base_org`, `org_setting`,
  and `org_zenith` structure dumps. This check remains unresolved; no unrelated dump was regenerated
  in this slice.
- The first Rails verification invocation lacked the local `PREFERENCE_COM_JWT_*` issuer
  configuration and stopped during boot. Re-running with those local values loaded without printing
  them completed the migration-status and drift checks.
- No full suite was run for this slice.
