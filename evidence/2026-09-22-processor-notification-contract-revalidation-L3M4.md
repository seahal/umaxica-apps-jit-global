# Processor notification contract revalidation

Date: 2026-09-22

Repository: `seahal/umaxica-apps-jit-global`

HEAD: `91d71c6f61d60c13be350bff3b723e05d09adf37`

Worktree: dirty before and after verification. Existing changes were preserved. No provider,
AWS, Cloudflare, GitHub, or other external service was contacted.

## Current boundary

`ProcessorErasureNotificationJob` has no concrete processor adapter in this repository. Its success
allowlist is intentionally empty, so a requested notification becomes the explicit
`processor_unavailable` failure state rather than the false `NOTIFIED` state. `NOTIFIED` remains
reserved for a future approved dispatch contract that distinguishes request acceptance, provider
receipt, delivery outcome, retry exhaustion, and permanent failure.

The current local state model and job preserve terminal-state guards and retry-window behavior.
No provider adapter, receipt ledger, retry limit, or new permanent-failure status was invented in
this revalidation because those contracts are not defined by the current repository or approved
plan.

## Verification

Command:

```text
PARALLEL_WORKERS=1 bin/rails test test/jobs/processor_erasure_notification_job_test.rb test/models/processor_erasure_notification_state_test.rb test/jobs/retention_purge_job_test.rb test/integration/routes/core_route_contract_test.rb
```

Result: `31 runs, 287 assertions, 0 failures, 0 errors, 0 skips`.

The result verifies the current unavailable-processor, terminal-state, retry-window, retention,
and Core route contracts only. It does not prove provider delivery, receipt callbacks, retry
exhaustion, permanent-failure policy, or production worker/provider behavior.

## Remaining decision gate

CF-011 remains open. Before implementation, the owner and contract for provider dispatch, receipt
authentication, delivery outcome semantics, bounded retry/exhaustion, permanent failure, replay,
and retention must be approved. No production behavior was changed to guess those semantics.
