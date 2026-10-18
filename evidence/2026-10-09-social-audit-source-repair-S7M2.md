# Social Source audit repair verification

- Date: 2026-10-09 UTC.
- Commit at verification: `13f27059c874e607bbe246cdf532b832691012fa`.
- Worktree: uncommitted social audit migrations, Source model, delivery job, link/unlink changes, tests, schema dumps, spec, and unrelated changes were present. The test databases were isolated by the verified `20261009accept1` and `20261008fix1` manifests; no shared database or external service was written.

The approved shape adds `client_social_audit_outboxes` to app Zenith and a nullable, unique event UUID to Chronicle's existing `client_chronicles`. The real identity table has no `public_id`, so the user approved using its persisted `id` serialized as the operation and identity reference. The link and unlink paths now commit their audit intent with the binding transition. `SocialAuditDeliveryJob` scans pending Source rows independently of enqueue, checks exact Chronicle identity, and acknowledges only after Chronicle persistence. Its scheduled production and development scans run every 15 minutes. Fixed social event and level rows are seeded by the Chronicle migration and by `db:seed` after a schema-only load; request paths no longer create them.

## Results

| Check | Observation |
| --- | --- |
| Initial public unlink regression | Failed with `NameError` for the absent Source outbox, as expected before implementation. The two additive migrations applied to the isolated test databases. |
| Focused link, unlink and delivery tests | 14 runs, 86 assertions, 0 failures/errors/skips. These include Source write failure rollback, Chronicle delivery failure and retry, UUID identity conflict, one-time delivery, and batch boundaries. |
| App social HTTP and use-case regression selection | 49 runs, 305 assertions, 0 failures/errors/skips. |
| Final serial Rails suite through `/tmp/four-fix-run-tests.rb` | 14,944 runs, 126,988 assertions, 0 failures, 0 errors, 0 skips; 948.75 seconds. One worker and the verified 20-database `20261009accept1` manifest were used. |
| Migration and dump workflow | The app Zenith and Chronicle migrations ran on isolated `20261008fix1` databases. Generated structure dumps contained only the intended 72 app Zenith and 10 Chronicle added lines against the previous tracked dumps. The repository's `SchemaDriftVerification.dump_matches?` comparison returned true for both current isolated catalogs and generated dumps. The top-level `db:verify_no_schema_drift` gate was not claimed because it additionally rejects uncommitted schema dump diffs. |
| `db:seed` on isolated `20261008fix1` | Exited 0, including the new fixed social Chronicle reference seeding. |
| `bin/rails zeitwerk:check`, scoped RuboCop, `git diff --check` | Exited 0. Zeitwerk noted the pre-existing `rails_db` vendor directory outside eager-load paths. |

This result verifies the named social audit slice only. Phase 23's full principal/Ticket/Chronicle, receipt, enqueue, notification and purge fault matrix has not been completed. A grant issued to another Client before a social subject's release can still be presented after release, and the broader `four.md` acceptance decision remains open. No deployment, real provider exchange or browser E2E was performed.
