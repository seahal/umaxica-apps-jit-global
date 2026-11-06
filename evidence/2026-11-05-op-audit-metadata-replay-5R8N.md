# OP Step-Up follow-through: replay metadata and regression recheck

Date: 2026-11-05

Commit: `b30345216886c98af1f04cbd434f067f12decf01`. The worktree contained extensive uncommitted
changes that affected the checked source and tests.

## Changes and source trace

- `OrgAdministrativeAudit#recorded_administrative_operation` now compares sanitized request metadata
  with the persisted Chronicle metadata before returning an existing operation as a replay. Reusing
  an operation ID with a changed ticket ID is therefore a conflict; exact replay remains idempotent.
- The Support session-revocation test covers exact replay and changed metadata, and verifies that
  the conflicting retry creates no second access event or Chronicle row.
- `contracts/lock-order-inventory.md` records the current Support account-revocation call path. No
  Operator or target-Client Zenith lock is taken in the traced writer, so this trace establishes no
  reverse OP-to-Zenith row-lock edge. It also identifies the missing evidence recheck/source receipt
  and the possibility of partial per-root stops before the access event. O-10 remains inactive.
- Re-read `five.md` (SHA-256 `ab191cb1d6d1099dbf38d6c4c85faa68b5850733ba3483e9e2425860d211ab45`).
  Its closed C9 slices are already implemented. Remaining C5 decisions govern persistence, recovery,
  cookie/JWT and route ownership; no further five.md behavior was safe to infer. The existing
  implementation dilemma is recorded in `six.md`.

## Verification

- `RAILS_ENV=test PARALLEL_WORKERS=1 bin/rails test test/controllers/base/org/support/session_revocations_test.rb`:
  **21 runs, 116 assertions, 0 failures, 0 errors, 0 skips**.
- `RAILS_ENV=test PARALLEL_WORKERS=1 bin/rails test test/controllers/base/app/avatar_ownership_transfers_controller_test.rb test/integration/step_up_authentication_test.rb test/integration/base_rp_contact_registration_refusal_test.rb`:
  **52 runs, 265 assertions, 3 failures, 0 errors, 0 skips**. Failures: Security Mode downgrade
  returned 422; email-registration completion and the unsatisfied-step-up action returned 503. These
  are the existing Q-1 and fail-closed contact/owner-boundary gaps, not failures in the Support
  replay test. The refusal boundary remains covered by the same run.
- `bundle exec rubocop app/controllers/concerns/org_administrative_audit.rb test/controllers/base/org/support/session_revocations_test.rb`:
  2 files inspected, no offenses.
- `ruby -c` passed for both changed Ruby files. `git diff --check` passed for the tracked scoped
  changes; the new inventory was checked for trailing whitespace and none was found.

Only configured test databases were used by the test runs. No manual data cleanup, schema change,
production database access, O-9 endpoint wiring, or five.md product/schema change occurred.
