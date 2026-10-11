# JWT anomaly catalog audit

- Date: 2026-09-18 (UTC)
- Branch: `feature`
- Starting task HEAD: `742f5d85b95e25a6783ed5556860df4097c1757b`
- Implementation commits: `cbfdc356f`, `842900c7e`
- Pre-existing working-tree changes: present; they were preserved and were not staged.

## Findings

The runtime reporter in `app/services/jit_security_jwt_anomaly_reporter.rb` emits the authentication
contexts `AUTH_CLIENT`, `AUTH_OPERATOR`, and `AUTH_VISITOR`. The reference-data migration
`db/occurrences_migrate/20260311150200_insert_jwt_occurrence_reference_data.rb` seeds `AUTH_USER`
and `AUTH_STAFF` instead. The pre-fix `JwtAnomalySubscriber` performed an exact body lookup and
returned when no matching occurrence existed, so the context mismatch prevented a corresponding
`JwtAnomalyEvent` from being written. The current subscriber emits a bounded catalog-miss event for
that condition but still cannot persist an anomaly without a matching reference row.

The access-token codec also emits `CLAIM_INVALID` and `DECODE_FAILED`, while the seeded common
reason list contains `DECODE_ERROR` and `OTHER`, not those runtime codes. The reporter's missing
claim map omitted `nbf`, although the existing catalog already defines `MISSING_NBF`.

The current safe slice adds the `nbf` mapping and its regression test, wires the reporter to the
existing Active Support notification boundary, and makes a missing catalog row observable as
`jwt.anomaly.catalog_miss` without creating a fabricated occurrence row. Malformed code values are
represented only by `INVALID` and their byte length. Adding or renaming persisted occurrence rows is
deferred because it changes reference-data shape and historical compatibility. The proposed
before/after shape and acceptance criteria are recorded in `conflict.md` under CF-013; no catalog
migration was executed.

## Verification

- `ruby -c app/services/jit_security_jwt_anomaly_reporter.rb` — passed.
- `ruby -c app/subscribers/jwt_anomaly_subscriber.rb` — passed.
- `ruby -c config/initializers/jwt_anomaly_notifications.rb` — passed.
- `ruby -c test/services/anomaly_reporting_and_authorize_failures_test.rb` — passed.
- `ruby -c test/subscribers/jwt_anomaly_subscriber_test.rb` — passed.
- `bundle exec rubocop app/services/jit_security_jwt_anomaly_reporter.rb test/services/anomaly_reporting_and_authorize_failures_test.rb`
  — passed; 2 files inspected.
- `bundle exec rubocop app/subscribers/jwt_anomaly_subscriber.rb test/subscribers/jwt_anomaly_subscriber_test.rb`
  — passed; 2 files inspected.
- Combined scoped RuboCop for the five changed source/test/initializer files — passed; 5 files
  inspected.
- `git diff --check` — passed after the code, evidence, and conflict-ledger changes.
- An isolated Ruby check with stubbed occurrence persistence — passed: a valid unknown internal code
  produced `jwt.anomaly.catalog_miss`, and a malformed value produced only `INVALID` plus its length
  without leaking the value.
- An isolated Active Support notification check — passed: `report_auth` emitted
  `jwt.anomaly.detected` with `AUTH_CLIENT_MISSING_ISS` while retaining the structured log.
- An isolated initializer wiring check with stubbed occurrence persistence — passed: loading
  `config/initializers/jwt_anomaly_notifications.rb` caused the reporter notification to reach the
  subscriber and emit `jwt.anomaly.catalog_miss` without attempting to create an unknown row.
- `RAILS_ENV=test POSTGRESQL_TEST_HOST=127.0.0.1 POSTGRESQL_PORT=5432 VALKEY_TEST_HOST=127.0.0.1 VALKEY_TEST_PORT=6379 VALKEY_NAMESPACE_RUN_ID=jwt-anomaly-20260918 CACHE_REDIS_URL=redis://127.0.0.1:6379/3 RATE_LIMIT_REDIS_URL=redis://127.0.0.1:6379/4 AUTH_STATE_REDIS_URL=redis://127.0.0.1:6379/5 bundle exec bin/rails test test/services/anomaly_reporting_and_authorize_failures_test.rb`
  — blocked during test-schema boot by `ActiveRecord::ConnectionNotEstablished`/`PG::ConnectionBad`
  for `127.0.0.1:5432`; no fallback database was used.
- `RAILS_ENV=test POSTGRESQL_TEST_HOST=127.0.0.1 POSTGRESQL_PORT=5432 VALKEY_TEST_HOST=127.0.0.1 VALKEY_TEST_PORT=6379 VALKEY_NAMESPACE_RUN_ID=jwt-subscriber-20260918 CACHE_REDIS_URL=redis://127.0.0.1:6379/3 RATE_LIMIT_REDIS_URL=redis://127.0.0.1:6379/4 AUTH_STATE_REDIS_URL=redis://127.0.0.1:6379/5 bundle exec bin/rails test test/subscribers/jwt_anomaly_subscriber_test.rb test/services/jwt_anomaly_subscriber_coverage_test.rb`
  — blocked during test-schema boot by the same unavailable isolated PostgreSQL listener; no test
  assertions ran.
- `RAILS_ENV=test POSTGRESQL_TEST_HOST=127.0.0.1 POSTGRESQL_PORT=5432 VALKEY_TEST_HOST=127.0.0.1 VALKEY_TEST_PORT=6379 VALKEY_NAMESPACE_RUN_ID=jwt-anomaly-wiring-20260918 CACHE_REDIS_URL=redis://127.0.0.1:6379/3 RATE_LIMIT_REDIS_URL=redis://127.0.0.1:6379/4 AUTH_STATE_REDIS_URL=redis://127.0.0.1:6379/5 bundle exec bin/rails test test/services/anomaly_reporting_and_authorize_failures_test.rb test/subscribers/jwt_anomaly_subscriber_test.rb test/services/jwt_anomaly_subscriber_coverage_test.rb`
  — attempted after notification wiring and blocked during test-schema boot because PostgreSQL at
  `127.0.0.1:5432` was unavailable; no assertions ran.
- `RAILS_ENV=test POSTGRESQL_TEST_HOST=127.0.0.1 POSTGRESQL_PORT=5432 VALKEY_TEST_HOST=127.0.0.1 VALKEY_TEST_PORT=6379 VALKEY_NAMESPACE_RUN_ID=jwt-anomaly-final-20260918 CACHE_REDIS_URL=redis://127.0.0.1:6379/3 RATE_LIMIT_REDIS_URL=redis://127.0.0.1:6379/4 AUTH_STATE_REDIS_URL=redis://127.0.0.1:6379/5 bundle exec bin/jobs check`
  — passed: `Solid Queue configuration is valid.` This validates configuration only; no worker or
  database execution was claimed.
- A static repository search before this slice found no initializer or runtime call registering or
  publishing `JwtAnomalySubscriber` events. The new initializer and reporter instrumentation are
  therefore part of the current change; the DB-backed registration assertion remains blocked above.

The Rails test result is therefore unverified, not a passing test run. No production, staging, or
shared database was used, and no external service or GitHub write was performed.

## Follow-up: anomaly payload field boundary

- Commit `79324edf6` bounds the JWT anomaly payload at the existing `ChronicleRecordPolicy`
  boundary. Error messages are sanitized before structured logging, Active Support notification
  delivery, and subscriber persistence, so JWT-shaped values are replaced with `[FILTERED]` rather
  than retained.
- Reporter `extra` values and subscriber metadata now use explicit default-deny allowlists. Both
  allowlists are empty because the repository has no production caller that declares a safe extra
  field; arbitrary payload keys are no longer copied into the JSON metadata column or notification
  payload. No schema, catalog, or retention semantics were changed.
- Added regression coverage for raw JWT-shaped errors, unallowlisted reporter extras, and subscriber
  metadata. The committed pre-commit hook ran scoped RuboCop for all five changed files and passed.
- DB-free reporter and subscriber sanitizer smokes passed. The combined Rails test command was
  retried with explicit loopback PostgreSQL/Valkey test endpoints and remained blocked during schema
  boot by the unavailable PostgreSQL listener; no assertions ran and no fallback database was used.

## Follow-up: diagnostic cardinality boundary

- Commit `6930e7303` bounds untrusted JWT diagnostic strings to 255 characters and caps audience
  arrays at eight entries before the notification and structured-log boundary. Values also pass
  through the existing Chronicle sanitizer, so a raw JWT placed in a diagnostic header or claim is
  not copied into the emitted payload.
- Authentication verification, accepted claims, catalog rows, persistence schema, and retention
  behavior were not changed. The bound only limits anomaly diagnostics and keeps malformed input
  from causing unbounded log/notification payloads.
- The new regression test and DB-free bounds smoke passed. The focused Rails test was attempted with
  explicit isolated-service endpoints but remained blocked before assertions by PostgreSQL being
  unavailable at `127.0.0.1:5432`.

## Continuation verification

- Ruby syntax checks passed for the three surface authority migrations and the sign-up expiry and
  cleanup boundaries.
- `RUBY_DEBUG_ENABLE=0 bundle exec bin/rails zeitwerk:check` passed with the application reporting
  that eager loading was healthy. The explicit environment variable only disables the debugger's
  sandbox-incompatible UNIX socket; no application configuration was changed.
- A fresh process/listener probe still found no PostgreSQL, Valkey, Redis, container runtime,
  worker, or scheduler available in this workspace. No database-backed test, migration, or worker
  execution was attempted as a result.

## Follow-up: current runtime catalog transition (2026-09-18)

- Commit `172686b23` adds
  `db/occurrences_migrate/20260918150000_insert_current_jwt_anomaly_reference_data.rb`. The
  migration explicitly covers the three current authentication contexts (`AUTH_CLIENT`,
  `AUTH_OPERATOR`, and `AUTH_VISITOR`) with the existing common/authentication reasons plus
  `CLAIM_INVALID` and `DECODE_FAILED` (78 rows total).
- The transition is additive and forward-only. It retains the historical `AUTH_USER` and
  `AUTH_STAFF` rows, uses the existing active status and seven-year reference-row retention
  convention, allocates unique bounded public IDs, and fails if a same-body row already exists with
  a non-active status. It also fails loudly when its prerequisite occurrence tables are absent
  rather than marking a skipped migration as applied. Its `down` method intentionally does not
  delete reference rows because persisted anomaly events may refer to them.
- The subscriber regression creates current catalog rows through Active Record and verifies that
  representative current context/reason pairs persist anomaly events. This avoids modifying the
  ERB-generated legacy fixture, which the repository formatter cannot parse as a standalone YAML
  document.
- `ruby -c` for the migration and subscriber test passed. Scoped RuboCop inspected both files with
  no offenses. `git diff --check` passed. `RUBY_DEBUG_ENABLE=0 bundle exec bin/rails zeitwerk:check`
  passed.
- The focused `JwtAnomalySubscriberTest` was attempted with explicit loopback PostgreSQL/Valkey test
  endpoints and stopped during Rails test-schema boot with `PG::ConnectionBad` at `127.0.0.1:5432`;
  no assertions or migration execution occurred. No fallback, production, staging, or shared
  database was used.
- Required runtime follow-up remains: execute the migration only on a disposable occurrence
  database, verify migration rerun behavior and legacy-row identity, then run the persistence test
  and the supported codec paths. Until that happens, CF-013 remains `BLOCKS_SLICE` and #606 is not
  reported as complete.

## Follow-up: subscriber persistence boundary (2026-09-18)

- Commit `c9f5743ea` applies the existing `ChronicleRecordPolicy` sanitizer to every diagnostic
  string copied from the notification payload into `JwtAnomalyEvent`, not only the error message.
  This covers request host, key id, algorithm, type, issuer, jti, and error class at the persistence
  boundary. The code does not change JWT verification, catalog lookup, metadata allowlists, or
  authentication outcomes.
- A regression test supplies the same synthetic JWT-shaped value to each field and asserts that the
  persisted values contain the sanitizer marker and not the raw token. The Rails test remains
  unverified because the isolated PostgreSQL listener is unavailable; no fallback database was used.
- A DB-free subscriber smoke with stubbed occurrence/event persistence passed: all seven diagnostic
  fields contained `[FILTERED]` and none retained the synthetic JWT. This does not replace the
  database-backed Rails assertion.
- Ruby syntax, scoped RuboCop, and the pre-commit hook passed. The remaining database-backed proof
  must run together with CF-013 migration and subscriber verification on a disposable occurrence
  database.

## Follow-up: malformed notification payload boundary (2026-09-18)

- The subscriber now accepts only Hash-shaped notification payloads. A nil payload preserves the
  existing no-op behavior; a non-Hash payload is rejected without catalog lookup or event
  persistence and emits only its bounded Ruby class name as `jwt.anomaly.invalid_payload`.
- This is a persistence/observability boundary only. It does not change JWT verification, accepted
  claims, authentication outcomes, catalog rows, or authorization behavior, and it does not log
  malformed payload contents.
- The new regression test was added before the implementation. The Rails test was attempted with
  explicit loopback PostgreSQL/Valkey endpoints and remained blocked during schema boot because
  PostgreSQL was unavailable at `127.0.0.1:5432`; no assertions ran.
- `ruby -c` and scoped RuboCop passed after the test style correction. A DB-free smoke using a
  non-Hash payload confirmed that no event was persisted and that the bounded invalid-payload log
  was emitted.

## Follow-up: persistence failure-log sanitization (2026-09-18)

- The subscriber now applies the existing `ChronicleRecordPolicy` sanitizer and 1000-character bound
  to the `ActiveRecord` persistence failure message before structured logging. JWT-shaped exception
  content is therefore not copied into the failure log.
- The regression test was written before the implementation. A DB-free red check reproduced the
  raw-token leak, and the post-change smoke confirmed `[FILTERED]` with no raw token. Syntax and
  scoped RuboCop checks passed.
- The Rails test remains blocked before assertions because PostgreSQL is unavailable at
  `127.0.0.1:5432`; no fallback database or external service was used.

## Follow-up: reporter failure-log sanitization (2026-09-18)

- Commit `a8a0ef9f5` applies the existing bounded `ChronicleRecordPolicy` sanitizer to the
  `JitSecurityJwtAnomalyReporter` rescue path. A failure while emitting an anomaly can no longer
  copy a raw JWT-shaped exception message into `jwt.anomaly.reporting_failed`.
- The regression test was preceded by a DB-free red smoke that reproduced the raw token in the
  failure log. The green smoke confirmed `[FILTERED]` and no raw token; Ruby syntax and scoped
  RuboCop also passed. No authentication, authorization, catalog, or persistence behavior changed.
- The focused Rails test was attempted with explicit loopback PostgreSQL/Valkey test endpoints and
  stopped during schema boot because PostgreSQL was unavailable at `127.0.0.1:5432`; no assertions
  ran and no fallback database or external service was used.
