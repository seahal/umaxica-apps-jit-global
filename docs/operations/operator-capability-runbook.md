# Operator capability runbook

Procedures for the org administrative capabilities defined in
`adr/operator-capability-authorization.md`. Run commands from an operator shell with access to the
target environment; nothing here is exposed through the console.

## Prerequisite: Chronicle compliance retention policy

Support session revocation, IAM grant and revoke, and bootstrap write a Chronicle intent row first
and refuse to start (HTTP 503, or a raised error for the task) when they cannot. The intent needs a
`chronicle_retention_policies` row with code `compliance`. Migration
`db/chronicle_migrate/20260926130000_insert_compliance_chronicle_retention_policy.rb` inserts it with
365 days (decided 2026-09-26). A database built by loading `db/chronicle_structure.sql` instead of
running migrations does not get the row; running the migration inserts it. To change the period
later, add a migration that updates the row.

Enforcement operations audit to `enforcement_events` and do not need this row.

## Bootstrap

The IAM capabilities (`iam.capability.read`, `iam.capability.grant`, `iam.capability.revoke`) are
issued only here. Name one existing operator explicitly; there is no form that grants to all
operators or to whoever signs in first.

```bash
bin/rails operator_capabilities:bootstrap \
  OPERATOR=<operator public id> \
  CAPABILITIES=iam.capability.read,iam.capability.grant,iam.capability.revoke \
  TICKET=<change ticket id> \
  EXPIRES_AT=<ISO 8601 time, at most 366 days ahead>
```

See `docs/operations/org-control-plane-production-readiness.md` for the recommended initial
assignment. Run it first with `DRY_RUN=true`: that validates every input and every grant and writes nothing.

The task fails without granting anything when any input is missing; the operator is locked,
withdrawing, withdrawn, deactivated, or past retention; a capability is not in the catalog
(wildcards are not); `EXPIRES_AT` is malformed, in the past, or more than 366 days ahead; the
operator already holds one of the capabilities in force; or the Chronicle intent cannot be written.
Grants are all-or-nothing. On success it prints each grant's public id and the audit `event_uuid`,
and nothing else.

Bootstrap at least two operators with `iam.capability.grant` and `iam.capability.revoke`: the
console refuses to revoke the last in-force holder of either, but it cannot stop expiry or an
operator becoming ineligible. When nobody holds them any more, bootstrap again.

Grant every other capability through `/iam/grants/new`, which requires Step-Up and lets a granter
delegate only what they hold.

## Checking grants

```bash
bin/rails operator_capabilities:status              # every in-force grant
bin/rails operator_capabilities:status OPERATOR=<id> # one operator
```

`eligible=false` means the grant exists but confers nothing because of the operator's state.

## Revoking

Revoke from `/iam/grants/<grant id>/revocation/new`. The revocation takes effect for every operation
that starts after it commits; there is no cache to wait for. An operation already past its
authorization check completes.

## Audit reconciliation

The result page of a support revocation shows the Chronicle `result` for its operation id:

- `succeeded`: complete.
- `failed`: the operation raised; nothing was reported as done.
- `intent`: the operation may or may not have run; the result write did not happen.
- `manual_recovery_required`: the result write failed and the row was marked for recovery.

For the last two, check the target's current state (session list, `AccountAccessEvent` for the
account, or the grant's `revoked_at`) and record the finding against the `event_uuid` in the
incident ticket. Do not resubmit with a new operation id before checking: a revocation that did run
would be recorded twice. Resubmitting the same confirmation screen reuses its operation id and does
not run the operation again.

Enforcement Cases whose `audited_at` is null are completed by `EnforcementReconciliationJob`; the
Case page shows a warning until then.
