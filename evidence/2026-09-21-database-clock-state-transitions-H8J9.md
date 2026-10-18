# Database-clock state transition slice

Date: 2026-09-21 UTC

Repository: `seahal/umaxica-apps-jit-global`

Branch: `feature`

HEAD at verification: `ab4746f9d403`

The worktree also contained the previously active Phase 09 schema reconstruction and Action
Policy changes. Those changes were preserved. No commit, reset, cleanup, GitHub write, external
provider call, or production/shared database operation was performed.

## Change

The public Retainable state-changing methods now obtain the owning model's writer-database clock
when the caller does not supply a decision-unit time:

- `schedule_retention!` uses one evaluation time for both future-deadline checks;
- `discard_now!` uses the same time for the discard and purge deadlines;
- token status transitions use one writer-database time for the status update, revocation deadline,
  and `updated_at`.

Explicit `now:` values remain supported for callers that already acquired a lock and are carrying
one decision-unit time. The implementation does not change token/RP-session authority, CSRF,
cookie, bearer, route, or external-delivery behavior.

## TDD and verification

The new tests were run before the production change and failed for the intended reasons:

- Retainable used the application clock instead of the model's supplied writer-clock value;
- token revocation did not use the writer-clock value for the transition timestamp.

After implementation:

```text
PARALLEL_WORKERS=1 bin/rails test \
  test/models/concerns/retainable_test.rb \
  test/models/concerns/token_status_management_test.rb \
  test/models/application_record_test.rb \
  test/models/client_token_test.rb \
  test/models/visitor_token_test.rb \
  test/models/operator_token_test.rb \
  test/models/rp_session_test.rb \
  test/models/concerns/refresh_tokenable_test.rb \
  test/models/refresh_token_concurrency_test.rb \
  test/services/sign_up_termination_idempotence_test.rb \
  test/jobs/retention_purge_job_test.rb \
  test/jobs/retention_purge_legal_hold_test.rb \
  test/services/sign/refresh_token_service_test.rb \
  test/services/refresh_token_absolute_expiry_test.rb
```

Result: 197 runs, 748 assertions, 0 failures, 0 errors, 0 skips.

The supplemental schedule-boundary check also passed with the focused Retainable/token/clock
group: 51 runs, 168 assertions, 0 failures, 0 errors, 0 skips.

The first attempt at this related command named a nonexistent test file; Rails rejected the
command before loading tests. The command was corrected using repository-listed paths. This was
not a code failure.

```text
bin/rails test
```

Result: 11,444 runs, 73,155 assertions, 0 failures, 0 errors, 5 skips.

Targeted RuboCop for the four changed implementation/test files reported no offenses. `git
diff --check` passed.

## Adversarial review

- A future writer-clock value cannot violate the retention ordering check silently; the real test
  initially failed when its fixture placed `purge_eligible_at` before that clock.
- Rails automatic timestamping was found to overwrite the explicit revocation time in one path;
  the transition now assigns attributes and calls `save!(touch: false)`, preserving validation
  while retaining the already-selected decision time.
- Explicit caller-provided times remain available, so cleanup services that already select a clock
  per decision cycle do not acquire a second clock.
- No new fallback is used when a production model lacks `database_now`; the method fails loudly
  rather than silently reverting to an application clock.

## Refresh and RP-session follow-up

The follow-up refresh/RP-session slice was audited separately. Refresh-token rotation, device
session activity updates, OIDC connection touches, RP-session issue/rotate/revoke, and refresh
reuse family revocation now carry one writer-database decision time through the locked transition.
The expiry-boundary tests were changed to control the model's database clock explicitly; Rails
`travel_to` alone does not advance PostgreSQL time.

The focused refresh/RP-session set passed with 153 runs, 624 assertions, 0 failures, 0 errors,
and 0 skips. The repository full suite then passed with 11,450 runs, 73,177 assertions, 0
failures, 0 errors, and 5 pre-existing skips. Targeted RuboCop and `git diff --check` passed.

This does not claim that every historical timestamp use in the repository has been migrated, nor
that application and database clocks may drift without operational bounds. Read predicates that
explicitly use Rails time remain outside this transition slice.

## OTP writer-clock follow-up

The OTP lifecycle slice was subsequently migrated to the owning writer database clock for the
decision units that issue, expire, throttle, or count OTP attempts. A single selected time is now
carried through OTP storage and the associated sent/expiry or lockout state. Existing tests that
used Rails `travel` without advancing PostgreSQL were changed to stub the model's public
`database_now` boundary instead; no assertion was weakened and no test was skipped.

The first RED run after the production change exposed two stale model expectations that still
calculated lockout timestamps from the application clock. Those expectations were corrected to
assert against the injected database decision time. The broader focused run then passed:

```text
PARALLEL_WORKERS=1 bin/rails test \
  test/models/client_email_test.rb \
  test/models/client_telephone_test.rb \
  test/controllers/auth/sign_up_checkpoint_cancellation_test.rb \
  test/controllers/auth/app/sign/up/check/email/otps_controller_test.rb \
  test/controllers/auth/app/sign/up/check/telephone/otps_controller_test.rb \
  test/controllers/auth/com/up/emails_controller_test.rb \
  test/controllers/auth/com/up/telephones_controller_test.rb \
  test/controllers/auth/app/in/emails_controller_test.rb \
  test/controllers/auth/app/up/emails_controller_test.rb \
  test/controllers/auth/app/up/telephones_controller_test.rb \
  test/controllers/base/app/identity/emails/registrations_controller_test.rb
```

Result: `283 runs, 1418 assertions, 0 failures, 0 errors, 0 skips`.

The final full Rails suite was then executed against the designated PostgreSQL and Valkey
services:

```text
bin/rails test
```

Result: `11472 runs, 73290 assertions, 0 failures, 0 errors, 6 skips`.

The six skips are existing suite skips; none was added for this slice. The required preflight
reported PostgreSQL 17.7 and Valkey 7.2.4 reachable through the core-service network. No
application fallback, configuration rewrite, external-service write, or production/shared data
operation was used. Targeted RuboCop for the 20 changed implementation/test files reported no
offenses, and `git diff --check` passed.
