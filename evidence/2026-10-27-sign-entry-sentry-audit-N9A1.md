# Sign Entry Sentry investigation

- Date: 2026-10-27 (UTC).
- Branch: `feature`.
- Full HEAD: `aeb09ca9fb97ef1ca24c0195b2fa1d28d21245df`.
- Worktree: extensive pre-existing uncommitted changes affected Admission, context and callback code. This audit used the current files; it did not change implementation. An independent process was using the shared test databases. Relevant source SHA-256 fingerprints are retained in the report.
- Report: `nine.md`, appended section “Sign Entry Sentry security audit — 2026-10-27”. That existing file is Git-ignored; it was not force-added.
- `git diff --shortstat develop...HEAD`: 3,340 files changed, 147,591 insertions, 71,553 deletions.
- Rails test-environment Route Set enumeration and host-aware recognition completed. All six normal entry classes report `auth/{app,com,org}/sign/{ins,ups}`, resolve to GET/show, inherit the Sentry callback, and miss the current namespace expression.
- Temporary runner command: `RAILS_ENV=test bin/rails runner /tmp/nine-runtime-checks.rb`. Result: 3 runs, 311 assertions, 0 failures, 0 errors, 0 skips; seed 46205. Checks covered real route/class metadata and the current expression, nested sign routes, and isolated Memory-adapter resolver missing/true/false states for all six pairs plus invalid intent rejection. No private classifier invocation, HTTP dispatch, shared flag write or database mutation was part of these checks.
- `bin/rails test test/integration/sign_entry_sentry_test.rb` exited 1 before tests: `test databases are in use by another test process`, `test/support/parallel_test_database_cloner.rb:44`.
- Two subsequent `PARALLEL_WORKERS=1 bin/rails test` attempts selecting the Sentry integration, WU29 blocked continuation, WU29 Root, resolver, ORG Emergency and ORG invitation files failed at the same exclusive-lock check. No selected suite ran; no lock was bypassed or removed.
- Confirmed from code: plural entry classification skips resolver; attached-confirmed ordinary GET has a direct consume/rotate/redeem path without Sentry. Database-backed reproduction of this state change remains unexecuted.
- Additional findings needing HTTP verification: APP/COM OTP resend omission, unresolved provider/binding intent, Auth result handoff continuity, Emergency Root completion/context propagation. No Root issuance bypass was demonstrated.
- No application, route, ADR, harness or test implementation changed. No destructive persistence operation, external write or commit performed.
