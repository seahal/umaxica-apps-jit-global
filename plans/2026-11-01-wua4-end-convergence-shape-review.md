# WU-A4 Enforcement end convergence state shape review

## Observed contract defect

`EnforcementCaseApplicable#write_audit_event!` writes `audited_at` for every Enforcement event. An
earlier `approved` event therefore leaves `audited_at` present before a later end. If the end
transaction commits and principal-lock release then fails, `pending_end_convergence` excludes that
Case because it filters on `audited_at IS NULL`; the reconciliation job cannot retry the failed
release. The current end operation deliberately commits the end before attempting release, so this
is a reachable partial-success boundary.

## Shape proposal

Before, both `app_enforcement_cases` and `org_enforcement_cases` have `state`, `ended_at`, and
`audited_at`, with no separate end-convergence state. The query infers pending work from `ended_at`
being present and `audited_at` being absent:

```text
{state: "active", ended_at: timestamp, audited_at: timestamp_from_prior_approval}
```

After, add a NOT NULL reference `end_convergence_status_id` to each realm's Zenith Enforcement Case
table and realm-local reference rows:

```text
{end_convergence_status_id: 10 | 20 | 30}
10 = not_ended
20 = pending
30 = completed
```

The Case end writer is the only transition writer: `not_ended -> pending` in the Case end
transaction; `pending -> completed` only after principal-access release/reconciliation and the end
audit have succeeded. Retries leave `pending` until both effects complete. The job selects `pending`
directly; `audited_at` remains a timestamp for the most recent audit and is not used as a
convergence decision.

## Migration mapping and impact

- New/active Case rows receive `not_ended`.
- Every pre-existing ended Case receives `pending`, because existing `audited_at` cannot establish
  that the specific end release and end audit both completed. The existing release event and
  `write_audit_event_once!` checks make retries idempotent.
- Current local read-only inventory returned 0 APP and 0 ORG Enforcement Cases in both development
  and test databases; therefore measured local backfill counts are zero. No production or Neon query
  was made.
- This shape does not delete or rewrite existing columns or audit facts. Rollback after runtime has
  marked Cases completed is not lossless; rollback must be limited to before the new writer is
  deployed, or use a forward fix. No automatic down migration should infer completed from
  `audited_at`.

## Verification proposed

- A previously audited active Case whose end commits but release fails remains `pending` and is
  selected by the reconciliation job.
- Retry after principal release succeeds records the end audit and marks `completed`; a repeated job
  does not release twice or duplicate audit events.
- Missing principal/operator remains pending and does not claim successful release.
- Both APP and ORG models, end paths, expiry/appeal paths, diagrams, and `pending_end_convergence`
  are covered.

No implementation or migration is authorized by this proposal alone. Production and Neon remain
excluded.
