# Processor notification retry-window guard

- Date: 2026-09-22 UTC
- Repository HEAD: `277673d13547d722fc88f830711eee69b923a7e8`
- Worktree: pre-existing plan/evidence changes were preserved; this slice also changes the
  processor notification job and its public regression test. No commit, reset, staging, or
  external write was performed.
- External writes: none; no processor, email, SMS, AWS, Cloudflare, production, shared database,
  or GitHub service was contacted.

## Finding

`ProcessorErasureNotificationJob#perform` checked only terminal state before processing. A stale
duplicate invocation for a persisted `FAILED` notification could therefore run before its existing
`next_retry_at`, record another request, and increment the failure state again. This was a local
retry-window defect and did not require a provider adapter or a new notification state.

## Change

The job now compares a persisted `next_retry_at` with the notification model's database clock and
returns without side effects while the retry window is still open. The public job regressions cover
both sides of the boundary: a future retry time is a no-op, while an already due retry is processed.
`NOTIFIED` remains reserved for an actual provider contract; receipt, delivery outcome, retry
exhaustion, and permanent-failure semantics remain the independent CF-011 boundary.

## Verification

- The first focused attempt in the restricted shell stopped during Rails schema boot because
  `primary` could not resolve. No localhost or alternate datastore was used.
- A subsequent local Compose-service check resolved `primary` and `valkey-kvs` without exposing
  credentials. The focused job test passed with `6 runs, 20 assertions, 0 failures, 0 errors, 0
  skips`.
- The focused job/model regression set passed with `38 runs, 321 assertions, 0 failures, 0 errors,
  0 skips`.
- The full Rails suite, run after the focused set, passed with `11,505 runs, 73,310 assertions, 0
  failures, 0 errors, 5 skips`. The skips were pre-existing; no test, assertion, coverage gate, or
  security check was weakened.
- Ruby syntax checks passed for the changed job and test. Targeted RuboCop reported no offenses for
  both files. `git diff --check` passed.
- The required test-environment preflight then passed against PostgreSQL `10.89.0.3/32:5432`
  (server 17.7) and Valkey `7.2.4` (`PONG` on the rate-limit and auth-state databases).
  `config/credentials/test.key` was present, all required test variable names were present after
  loading `.env.devcontainer.example`, and `primary`/`valkey-kvs` resolved. No variable values or
  credential contents were printed.
- No processor, email, SMS, AWS, Cloudflare, production, shared database, or GitHub service was
  contacted. Coverage was not used as a release gate.

## Remaining boundary

This slice only prevents early duplicate processing. It does not define provider dispatch, receipt or
delivery semantics, bounded retry exhaustion, permanent-failure classification, or production worker
topology. The `next_retry_at` check is an advisory read before the state transition; two jobs that
become due concurrently still require an approved claim/lease or equivalent provider-dispatch
contract before exactly-once request emission can be claimed. Those semantics remain open and must
not be reported as closed.
