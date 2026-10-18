# Frozen plan Phase 12 final repository audit

- Date: 2026-09-21 UTC
- Repository: `seahal/umaxica-apps-jit-global`
- Branch: `feature`
- HEAD observed: `ab4746f9d403021b3ea5fff53a0a6ae4b4e68ec9`
- Worktree: preserved; `git status --short` reported 145 entries at the audit
- External writes: none; no GitHub, AWS, Cloudflare, production, shared database, or real
  email/SMS delivery was used

## Independent contract checks

The final-code review was performed from the observable boundary back toward the implementation:

- Core route contract still rejects a Rails `/dashboard` route.
- `CoreBrowserApiBoundary` rejects a Bearer `Authorization` credential before cookie
  authentication, applies `Cache-Control: no-store`, and keeps CSRF verification for unsafe
  methods.
- RP browser credential cookies use `domain: false`, `HttpOnly`, configured Secure behavior, and
  the existing SameSite/Path contract.
- First-party Core/Side/Edit browser RP requests do not send a `screen_hint` choice. The remaining
  `screen_hint` branches are for non-first-party/Palm or actor-specific flows and were not removed
  by inference.
- App and com direct Passkey option tests require empty `allowCredentials`; org actor-known tests
  continue to require actor-scoped descriptors.
- Root controllers explicitly use Rails `header_or_legacy_token` protection with exceptions. The
  `header_only` OIDC coordinated-logout case and the CSP telemetry skip remain narrowly scoped and
  are covered by their existing boundary tests.
- The OTP expiry boundary now treats blank, both timestamp infinities, and non-comparable values as
  expired; the public record behavior cannot expose OTP material from a timeless malformed value.

## Verification

Focused OTP/security regression suite:

```text
PARALLEL_WORKERS=1 bin/rails test test/models/concerns/otp_lockable_test.rb test/models/concerns/email_test.rb test/models/concerns/telephone_test.rb test/services/sign_otp_ceremony_test.rb test/services/sign/in/otp_resend_policy_test.rb test/services/sign/in/otp_resend_service_test.rb test/services/sign_in_otp_resender_failures_test.rb test/controllers/auth/app/in/emails_controller_enumeration_test.rb test/controllers/auth/com/in/emails_controller_enumeration_test.rb test/jobs/outbound/sms_delivery_job_test.rb test/services/outbound_sms_audit_test.rb test/models/chronicle_test.rb test/subscribers/jwt_anomaly_subscriber_test.rb test/jobs/retention_purge_legal_hold_test.rb test/jobs/retention_purge_job_test.rb
```

Result: `154 runs, 588 assertions, 0 failures, 0 errors, 0 skips`.

Focused OTP expiry regression:

```text
PARALLEL_WORKERS=1 bin/rails test test/models/concerns/otp_lockable_test.rb
```

Result: `6 runs, 18 assertions, 0 failures, 0 errors, 0 skips`.

Full Rails suite after the change:

```text
bin/rails test
```

Result: `11469 runs, 73281 assertions, 0 failures, 0 errors, 6 skips`.
The six skips were reported by the existing suite; no skip was added for this change.

Additional checks:

- targeted RuboCop for `app/models/concerns/otp_lockable.rb` and its test: no offenses;
- `git diff --check`: passed;
- Brakeman 8.0.6 on Rails 8.2.0.alpha: 0 errors and 0 security warnings.

## Residual limits

- FREQ-0064 remains partial. Provider acceptance, delivery outcome, retry, and permanent-failure
  facts require an approved provider callback/retention contract. No provider taxonomy or external
  integration was invented.
- The repository-wide writer-clock migration is not claimed as complete for every historical
  timestamp use. The OTP issue, cooldown, expiry, and failed-attempt transition paths covered by
  this audit now use the owning writer database clock; unrelated historical timestamp uses and
  operational clock-drift bounds remain outside this slice. Rails time travel alone is not used to
  stand in for PostgreSQL time in the affected tests.
- Repository-wide coverage gates and three unrelated existing RuboCop offenses remain recorded in
  earlier evidence; no threshold, exclusion, assertion, or skip was weakened.
- Live Cloudflare/Tunnel, provider delivery, Solid Queue deployment, production RP registration,
  external keys, and deployment configuration remain unverified. These are not claimed as green by
  this repository-side audit.

Subsequent revalidation moved the Valkey settings cache to the existing thread-safe map primitive
and reran repository-wide RuboCop over 4,773 files with no offenses. The earlier coverage-gate
failure and external verification limits remain unchanged.
- The frozen plan file and its plan metadata were not rewritten to manufacture implementation or
  verification status.

## Latest OTP database-clock verification

After the follow-up migration and test corrections, the focused OTP and registration suite passed
with `283 runs, 1418 assertions, 0 failures, 0 errors, 0 skips`. The final full Rails suite passed
with `11472 runs, 73290 assertions, 0 failures, 0 errors, 6 skips`. The six skips were existing
suite skips; no skip was added for the DB-clock work.

## Subsequent revalidation

After the OIDC result-purpose binding correction and the OTP email enqueue audit, the focused
tests passed and the full Rails suite passed with `11475 runs, 73310 assertions, 0 failures,
0 errors, 6 skips`. The email paths now record successful enqueue facts without recipient or OTP
content. Provider receipt, delivery outcome, retry, permanent failure, archive, and legal-retention
contracts remain outside the approved repository-side scope.

## Latest gate revalidation

On the same Compose-backed test environment, the requested focused Valkey/settings regression
command passed with `34 runs, 142 assertions, 0 failures, 0 errors, 0 skips`, followed by the
full Rails suite with `11483 runs, 73355 assertions, 0 failures, 0 errors, 6 skips`.

Additional repository-side checks completed on 2026-09-21 UTC:

- `bun run test`: 85 files and 1,065 tests passed;
- repository-wide RuboCop: 4,773 files inspected, no offenses;
- bundled Brakeman 8.0.6: 0 errors and 0 security warnings;
- frozen-plan validator: 70 canonical source rows and 70 FREQ rows, zero mapping errors, `PASS`;
- `git diff --check`: passed.

The SimpleCov run remains below its existing line/branch/method thresholds. No threshold,
exclusion, assertion, or skip was changed. FREQ-0064 remains partial for provider receipt/
delivery/retry/permanent-failure and approved archive/retention contracts. A RetentionPurgeJob
dry-run result/argument shape was not added because its Before/After contract still requires
explicit data-shape approval.
