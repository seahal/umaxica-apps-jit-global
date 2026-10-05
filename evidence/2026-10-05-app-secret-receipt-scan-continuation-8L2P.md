# Canonical receipt scan continuation

Observed on 2026-10-05 (UTC), through 14:37:57+00:00, against HEAD
`e8f2371bc5cbefd2087c728aeeef4e318463d33f` with uncommitted job, test and
documentation changes. Unrelated work was preserved. No shared destructive
application, deployment, push, E2E or full-suite execution occurred.

`ClientSecretLifecycleJob#perform` now supports the `receipts` continuation phase.
The existing expired-flow receipt scope captures an upper ID horizon, visits at
most the requested bounded batch, and queues the next cursor past retained rows.
Each candidate still passes `ClientSecretSignInReceiptPurger.call!` with explicit
proof retention and existing Source/Ticket locks, deadlines, audit and hold guards.
No additional session issuer or receipt factory was introduced.

The new HTTP integration test creates two root logins through actual Secret Auth
evidence and Base canonical OIDC completion. It waits for explicit short fixture
deadlines, delivers real Source audits, physically collects the consumed credentials,
holds the first Client, and invokes the periodic lifecycle with batch size one.
It checks persisted continuation arguments, executes the queued public job,
retains the first receipt and hold, deletes only the second receipt and verifies
both root tokens remain currently usable. Root tokens and receipts are not
manufactured or success-mocked. The external Turnstile boundary remains a test stub.

Commands use `bundle exec ruby /tmp/umaxica-secret-recovery-db-task.rb` with the
OID/owner-guarded `codex_integrity_20261005recovery_*` fleet on PostgreSQL 17.7.

- Red reproduction was initially in the existing OIDC integration file:
  `test test/integration/oidc_initiated_sign_in_completion_test.rb
  --include '/receipt_scan_continues/'`, seed 30833: 1 run/15 assertions/1 failure.
  No lifecycle continuation was queued after the held first receipt.
- After implementation, the same public journey passed: seed 52666,
  1 run/20 assertions, 0 failures/errors/skips, 12.519267 seconds.
- Generated the dedicated test artifact with
  `generate integration_test AppSecretReceiptCollectionJourney`. Moved only the
  newly added test and framework job helpers into it, removed the generated
  placeholder and preserved the existing OIDC file unchanged. An existing
  45-assertion test in that old file exceeded its lint limit; no threshold or
  exclusion was added to conceal that unrelated baseline finding.
- `test test/integration/app_secret_receipt_collection_journey_test.rb
  test/jobs/client_secret_lifecycle_job_test.rb`, seed 35548:
  **4 runs/122 assertions, 0 failures/errors/skips**, 13.022638 seconds.
  The lifecycle boundary test includes the new valid receipt phase while retaining
  batch, type and cursor sentinel/boundary checks.
- After strengthening the root-token assertion from existence to current usability,
  `test test/integration/app_secret_receipt_collection_journey_test.rb`, seed 16089:
  **1 run/20 assertions, 0 failures/errors/skips**, 12.542011 seconds.
- `bundle exec rubocop` on `app/jobs/client_secret_lifecycle_job.rb`,
  `test/jobs/client_secret_lifecycle_job_test.rb` and the new integration file:
  3 files inspected, no offenses. Layout-only autocorrection preceded the final
  check. `git diff --check` exited 0.

Updated the receipt diagram, transition inventory and security document in the
same change. This proves traversal past a held real receipt and preservation of
its established root session; it does not prove every receipt race or crash case.
Replay-barrier retirement, remaining acceptance gaps and schema-drift resolution
still require work. The overall implementation goal remains active.
