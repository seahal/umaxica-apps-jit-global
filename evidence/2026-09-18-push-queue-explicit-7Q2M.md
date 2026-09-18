# Explicit push delivery queue verification

Date: 2026-09-18 UTC

Branch: `feature`

Verified local commit: `0e9062de085e2d4ceba90199a03360d15fa7b7d2`

The application push notification class now explicitly assigns `default` with `queue_as :default`.
This does not create a queue or change the current worker topology. It makes the existing contract
visible in application code instead of inheriting Action Push Native's Active Job default. The
`default` worker is declared in every supported `config/queue.yml` environment.

## Checks performed

Passed:

- `bundle exec rubocop app/models/application_push_notification.rb test/models/application_push_notification_test.rb`
- `ruby -c app/models/application_push_notification.rb`
- `ruby -c test/models/application_push_notification_test.rb`
- `git diff --check`

Attempted:

```text
RAILS_ENV=test POSTGRESQL_TEST_HOST=127.0.0.1 POSTGRESQL_PORT=5432 \
VALKEY_TEST_HOST=127.0.0.1 VALKEY_TEST_PORT=6379 \
VALKEY_NAMESPACE_RUN_ID=push-queue-20260918 \
CACHE_REDIS_URL=redis://127.0.0.1:6379/3 \
RATE_LIMIT_REDIS_URL=redis://127.0.0.1:6379/4 \
AUTH_STATE_REDIS_URL=redis://127.0.0.1:6379/5 \
bin/rails test test/models/application_push_notification_test.rb
```

The Rails test boot reached Active Record schema maintenance and failed before running assertions
because PostgreSQL was not listening at `127.0.0.1:5432` (`PG::ConnectionBad`). No development,
staging, or production datastore was used as a fallback. The new enqueue assertion is therefore
runtime-unverified until an isolated PostgreSQL/Valkey test boundary is available.

## Queue topology checks

Passed:

- `env -u RUBY_DEBUG_OPEN RAILS_ENV=test ... bundle exec bin/jobs check` —
  `Solid Queue configuration is valid.`
- ERB/YAML parsing with `YAML.safe_load(..., aliases: false)` for `config/queue.yml` and
  `config/recurring.yml`.
- Static exact-queue comparison for development, test, and production: each has exactly `default`,
  `retention`, and `solid_queue_recurring` workers.
- Static recurring comparison: development and production each have 15 entries with explicit
  class/queue/priority/args/schedule fields for class entries, and the same business schedule.
- Static class existence check for every class named by the recurring configuration.
- No queue wildcard, YAML anchor, alias, or merge pattern in either queue configuration file.

Development and production `bin/jobs check` were also attempted with explicit non-production test
endpoints. They reached Solid Queue's recurring-task validation but could not complete because the
configured PostgreSQL host `primary` was not resolvable/listening in this environment. No fallback
to a development, staging, or production datastore was used.

## Review result

The change keeps push delivery on the existing `default` worker, does not add request state or
credentials to job arguments, and does not alter suspension or provider delivery behavior. No new
queue or recurring task is required.
