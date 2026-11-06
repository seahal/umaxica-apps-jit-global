# Chronicle Retention Policy Reference Rows Missing On A Fresh Database

Date: 2026-11-03

Status: Partially addressed on 2026-11-03. The `security` row is now migration-owned; `ephemeral`
and `permanent` remain undecided.

## Observation

After rebuilding the development databases with `bin/rails db:migrate:reset`, an email sign-up
completed, but the audit write for `notification.delivery.email.enqueued` failed:

- `chronicle.intent_write_failed`:
  `ActiveRecord::RecordNotFound: Couldn't find ChronicleRetentionPolicy with code = ...`
- `chronicle.guarantee_failed` with `manual_recovery_required: true`

`chronicle_retention_policies` held only `compliance` (inserted by
`db/chronicle_migrate/20260926130000_insert_compliance_chronicle_retention_policy.rb`).

## Why

`ChronicleRecordPolicy#retention_policy_code_for` (`app/policies/chronicle_record_policy.rb`)
resolves an action to `permanent`, `security`, `ephemeral` or `compliance`, and defaults unlisted
actions to `security`. Only `compliance` has a row on a fresh database.

- `security` is created only by `rake app_secret:provision_audit_policy`
  (`lib/tasks/app_secret_audit.rake`), which requires `CHRONICLE_SECURITY_RETENTION_DAYS` as an
  explicitly approved duration.
- No migration under `db/chronicle_migrate` inserts `permanent` or `ephemeral`; where they are meant
  to be created has not been confirmed.

## Open decisions

1. The retention duration for `security`, and for `ephemeral` if it is used. This is an audit policy
   decision (compare OQ-AUD-004 in `docs/vendor/identity/15_audit-log-integrity-requirement.md`).
2. Where fixed policy rows are owned: a migration (as for `compliance`) or the provisioning task.
3. Whether an unresolvable retention policy should fail the originating request, since the audit
   guarantee currently fails after the request has already proceeded.

## Not verified

- Whether existing environments receive these rows through a manual step.
- Whether other reference tables are empty on a database built from migrations alone.

## Owner decision 2026-11-03 (OP-mediated step-up, unit 2)

- `security`: 365 days, inserted by a Chronicle migration in the same form as `compliance`
  (`ON CONFLICT (code) DO NOTHING`, no-op `down`). Open decision 1 is closed for `security`; open
  decision 2 is closed in favor of a migration for this row.
- `ephemeral` and `permanent`: still undecided; step-up does not use them.
- Open decision 3 (failing the originating request) remains open.

## Implementation update 2026-11-03 (OP-mediated step-up, unit 2)

`db/chronicle_migrate/20261103183220_insert_security_chronicle_retention_policy.rb` now inserts the
owner-approved `security` policy at 365 days with `ON CONFLICT (code) DO NOTHING` and a no-op
`down`. It was applied to the test and development Chronicle databases. Step-up action retention
remains explicit in `ChronicleRecordPolicy`; `app_secret:provision_audit_policy` was not changed.

The remaining decisions are whether to provision `ephemeral` and `permanent`, and whether a missing
retention policy should fail the originating request. Neither is resolved by the step-up change.
