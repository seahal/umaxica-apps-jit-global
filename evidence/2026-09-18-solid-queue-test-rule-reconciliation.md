# Solid Queue Test-Rule Reconciliation

Date: 2026-09-18 Branch: `feature` Baseline HEAD before this slice: `5716d7c5a`

## Finding

The repository's accepted `no-environment-tests` rule prohibits Minitest/Vitest cases whose subject
is environment or tooling construction. The earlier Solid Queue configuration contract test parsed
`config/queue.yml` and `config/recurring.yml` as a permanent setup test, which conflicts with that
rule even though the integrated queue requirement requested configuration checks.

## Resolution

- Removed `test/config/solid_queue_configuration_contract_test.rb`.
- Kept job behavior tests and the explicit queue/recurring configuration.
- Retained the static mapping audit and the installed `bin/jobs check` command as operational
  evidence, not product-test coverage.
- Recorded the conflict and bounded next action in `CF-012`.

This reconciliation changes no queue mapping, worker, scheduler, job, or runtime behavior. The
test-scoped `bin/jobs check` passed earlier with disposable variables; actual worker execution and
development/production boot checks remain unverified under `CF-005`/`CF-002`.

## Environment boot recheck

- On 2026-09-18, `RAILS_ENV=test` with explicit loopback PostgreSQL/Valkey test variables passed
  `bundle exec bin/jobs check` and reported `Solid Queue configuration is valid.` This is a
  configuration check only; no queue database or worker was running.
- A development check with `RUBY_DEBUG_ENABLE=0`, loopback cache/rate-limit/auth-state URLs,
  `TRUSTED_PROXIES=127.0.0.1`, and `JOB_CONCURRENCY=1` reached Solid Queue configuration inspection
  but stopped while loading recurring task models because the configured development PostgreSQL host
  `primary` could not be resolved. No fallback datastore was used.
- A production check stopped before application initialization because the required
  `TRUSTED_PROXIES` variable was absent. No production or shared datastore was contacted.
- These results leave development/production configuration validation, dispatcher/scheduler startup,
  queue transfer, worker execution, recurring enqueue, retry, and recovery unverified.
