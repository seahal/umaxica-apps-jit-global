# Phase 0 and Safe-Slice Verification

Date: 2026-09-17

Repository: `seahal/umaxica-apps-jit-global`

Branch: `feature`

Source HEAD for the checks: `3ff5241c4b876c2c828e772c0fd289c8aae5f850`

The checks in this record ran before the isolated local phase commits listed in the final handoff.
This record does not claim that runtime checks were repeated after those commits.

The starting worktree already contained a modified `README.md` and deleted `misc.md` and
`refactor.md`. Those paths were preserved and were not staged. No reset, clean, checkout, stash,
database reset, external provider call, deployment, push, or GitHub write was performed.

## Baseline

- Rails: `8.2.0.alpha`
- Ruby: `4.0.6`
- Solid Queue: `1.7.0`
- OpenTelemetry API: `1.11.0`; SDK: `1.13.0`; instrumentation: `0.96.0`
- Lograge: `0.15.0`
- Bundler: dependencies satisfied; PostgreSQL adapter `pg 1.6.3` is available.

The full Phase 0 inventory, rename matrix, source-owner mapping, connection notes, lifecycle
blockers, and requirement ledger are in `plans/backlog/2026-09-17-integrated-hardening-plan.md`. The
single conflict ledger is `conflict.md`.

## Checks performed

| Command or check                                                                                                             | Result                                                                                                                                         |
| ---------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------- |
| `bundle check`                                                                                                               | Passed.                                                                                                                                        |
| Ruby syntax check over the changed Ruby files                                                                                | Passed for all 19 checked files.                                                                                                               |
| `bundle exec rubocop --cache false` over the changed Ruby and test files                                                     | Passed: 36 files, no offenses.                                                                                                                 |
| `bun x oxfmt --check src/features/self_service/Shell.tsx`                                                                    | Passed.                                                                                                                                        |
| `bun x oxlint src/features/self_service/Shell.tsx`                                                                           | Passed.                                                                                                                                        |
| `bun x tsc --noEmit --pretty false`                                                                                          | Passed.                                                                                                                                        |
| ERB-rendered `config/queue.yml` and `config/recurring.yml` with `YAML.safe_load(..., aliases: false)` and Psych parsing      | Passed; both files are valid and contain no YAML alias expansion.                                                                              |
| Installed OpenTelemetry API construction/resolution check                                                                    | Passed; valid context returned lowercase 32-character trace and 16-character span IDs, invalid context returned empty values.                  |
| `RAILS_ENV=test ... VALKEY_NAMESPACE_RUN_ID=phase0-20260917 bundle exec bin/jobs check` with disposable local test variables | Passed: `Solid Queue configuration is valid.` This is configuration validation only; it did not prove worker/database execution.               |
| `bundle exec scripts/test-environment-check`                                                                                 | Not run successfully: `VALKEY_TEST_HOST` and `VALKEY_TEST_PORT` are not configured.                                                            |
| `bundle exec bin/rails test test/resolvers/observability_context_resolver_test.rb`                                           | Blocked during test boot because `VALKEY_TEST_HOST` is required. No test ran.                                                                  |
| `env -u RUBY_DEBUG_OPEN RAILS_ENV=development bundle exec bin/jobs check`                                                    | Blocked during boot because `PERFORMANCE_REDIS_URL` is required.                                                                               |
| `RAILS_ENV=production RUBY_DEBUG_OPEN=false bundle exec bin/jobs check`                                                      | Blocked during boot because `TRUSTED_PROXIES` is required.                                                                                     |
| Rails request/controller/job/integration tests and real Solid Queue worker execution                                         | Unverified because the isolated PostgreSQL/Valkey test boundary is unavailable. No development or production datastore was used as a fallback. |

## Static boundary checks

- `ActionDispatch::RequestId` remains the request-ID mechanism; no replacement middleware was added.
  The added regression tests cover incoming `X-Request-ID`, response propagation, and generated IDs.
- The repository search found no application implementation assigning `request.request_id` to
  `trace_id` or `Actor.trace_id`. The only remaining request-ID references are request-correlation
  fields or explicit regression assertions.
- OpenTelemetry resolution reads only a valid current `SpanContext`; it does not start the SDK or
  use analytics consent.
- Dashboard links use existing route helpers. Calendar, Clock, and Currency routes/controllers exist
  on all three Base surfaces. Identity Sessions was added only to the app Identity hub; com/org
  already exposed it. No tokenized promotional unsubscribe URL was added.
- `config/queue.yml` has explicit environment workers with exact `default`, `retention`, and
  `solid_queue_recurring` queues. `config/recurring.yml` has explicit development/production entries
  and an empty test schedule. The runtime ledger is in `docs/operations/solid-queue-runtime.md`.

The new behavior tests remain present but are not reported as passing until the Rails test
environment is supplied. No raw logs, credentials, tokens, cookies, request bodies, or production
data were written to this evidence file.
