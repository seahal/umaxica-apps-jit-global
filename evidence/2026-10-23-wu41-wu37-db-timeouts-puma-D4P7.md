# WU-41 effective database timeouts; WU-37 Puma workers and threads

- Date: 2026-10-23. Base commit `6e4d70d0b0799a4ef9bd9fc4cea2c21d4b3eca72`; changes uncommitted.
  Other uncommitted work of this cycle (WU-03/04/09/31/32/40) was present during the full run.
- Decisions: D-142 (WU-41), D-120 (WU-37). Environment construction: observations only, no Minitest.

## WU-41

Change: `lock_timeout` / `statement_timeout` moved under `variables:` in `config/database.yml`
(`default` 2 s / 15 s; `test_default` 2 s / 10 s next to its existing variables).

- A41-1: `SHOW lock_timeout`, `SHOW statement_timeout` on every writable configured connection:
  development 32 × `2s` / `15s`; test 32 × `2s` / `10s` (before the change: `0` / `0`, H18).
- A41-2: full `bin/rails test` with the timeouts in force: 18463 runs, 61 failures, 2 errors; compared
  with the G-1 baseline (`evidence/2026-10-22-g1-full-test-baseline-B7G1.md`) no new failing test,
  16 baseline failures fixed (WU-04's telephone integration tests). No `LockWaitTimeout` /
  `QueryCanceled` appeared.
- A41-3: development `perform_now`: `RetentionPurgeJob` 0.43 s, `SignUpExpiryJob` 0.00 s,
  `ClientSecretLifecycleJob` 0.02 s; no statement cancelled (development data volume is small).
- Production values: to be recorded after the first deploy.

## WU-37

Change: `config/puma.rb` reads `RAILS_MAX_THREADS` and `WEB_CONCURRENCY` with one-argument
`ENV.fetch` (no code-side default) and starts that many workers. `.env.container.devcontainer` sets
`WEB_CONCURRENCY=2`, `RAILS_MAX_THREADS=5` (was one process × 3 threads).

- Observed: `bundle exec puma -C config/puma.rb` with those values printed "Min threads: 5, Max
  threads: 5, Workers: 2" and booted both workers. Without `WEB_CONCURRENCY` the boot fails with
  `KeyError: key not found: "WEB_CONCURRENCY"` (fail fast).
- Load estimate (A37-1): **provisional, not measured.** A sign-in callback thread can wait on the
  OP token endpoint and, through it, on JWKS of the same server (nesting depth 2), so a stall needs
  every slot waiting at once; 10 slots in development tolerate about three concurrent callbacks
  even in the worst nesting. The development pool (`pool: RAILS_MAX_THREADS`) is per process, so 5
  connections per worker match the threads.
- **Not done:** production values. There is no production load data in the repository; the
  deployment must set `WEB_CONCURRENCY` and `RAILS_MAX_THREADS` (the image no longer boots
  without them). A37-2 (measured self-call latency under load) **Not run** — no load test exists.
