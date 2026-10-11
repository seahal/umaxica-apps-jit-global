# Processor-erasure notification success-boundary verification

- Date: 2026-09-18 UTC
- Branch: `feature`
- Base commit for this slice: `afb98d0b4`
- Pre-existing working-tree changes were preserved and were not staged.

## Finding and change

`ProcessorErasureNotificationJob` previously marked several processor keys as `NOTIFIED` without
calling a processor adapter or observing a provider acceptance/receipt. That conflated an internal
queue request with delivery success. The success allowlist is now empty until a concrete adapter and
its retry/receipt contract are implemented. Current keys therefore become explicit
`FAILED`/manual-follow-up state with an occurrence record; no erasure-delivery success is claimed.

## Verification

- Ruby syntax checks for the changed job and test: passed.
- RuboCop for the changed job and test: passed.
- The focused Rails job test was not run to assertions because Rails schema boot cannot connect to
  PostgreSQL at `127.0.0.1:5432`. No external processor or production datastore was contacted.

## Remaining verification

The database-backed state transition and occurrence assertions remain unverified until the isolated
PostgreSQL test service is available. A future processor integration must add its own provider
acceptance, retry, duplicate-delivery, and permanent-failure evidence before entering the success
allowlist.
