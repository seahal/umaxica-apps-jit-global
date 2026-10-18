# Cancellation race and decision clock

Commit `f313b126931cfe3c9ecf64bbb72fb1cd3a0aada5`, with uncommitted authentication changes and unrelated parallel work.

Added independent-writer finalization/cancellation races for APP, COM and ORG. Each checks distinct PostgreSQL backend IDs and accepts either serialization order. Successful Base finalization retains the original event and refuses cancellation; successful cancellation leaves no freshness and rejects result finalization/reuse. The original root token remains usable. Cleanup targets each test's created rows only. Evidence is synthetic at the assertion layer to isolate ticket finalization, not to prove WebAuthn assurance.

Also reproduced cancellation's decision-clock mismatch with actual token expiry. At and one microsecond after the deadline, cancellation previously accepted a token because application time lagged writer time. Cancellation now evaluates token usability using writer time after locking the exact parent. Boundary tests cover one microsecond before, at and after expiry, and verify that rejected cancellation preserves pending verified evidence.

All Rails runs used owned manifest `tmp/auth-boundary-isolated-20261003auth6f3.json`, run ID `20261003auth6f3`, one worker and preparation restricted to `codex_integrity_20261003auth6f3_app_ticket`.

- Expanded concurrency file: 12 runs, 141 assertions, no failures/errors/skips (seed 20381).
- Cancellation clock tests before the correction: freshness committer test file, 19 runs, 121 assertions, two failures (seed 62886).
- Final command: `bin/rails test test/operations/identity_step_up_ceremony_freshness_committer_test.rb test/models/auth_ceremony_revocation_concurrency_test.rb test/controllers/auth/step_up_admission_test.rb test/controllers/auth/org/verification/emergency_step_up_prohibition_test.rb`.
- Final result: 48 runs, 462 assertions, no failures/errors/skips (seed 54914).
- RuboCop on three changed Ruby files passed after assertion spacing; `git diff --check` passed.

The races do not force both serialization orders in every run. Browser verification, OTP logging remediation and full-plan completion are not claimed. No schema changes or deployment occurred.
