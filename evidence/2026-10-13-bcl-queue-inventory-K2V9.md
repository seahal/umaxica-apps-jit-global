# BCL Queue Inventory Follow-up

## Revision and worktree

- Full commit: `40c22179243f1970a139c89642d98f132b8735ea` on branch `feature`.
- The worktree remained dirty with previously deferred Step 5 work and in-progress Frozen string
  changes. No BCL source was changed or staged for this check.
- The isolated test run ID and manifest were not used. The target was verified through the standard
  Rails `development` queue configuration as `development_queue_db`.

## Checks performed

- `POSTGRESQL_QUEUE_PUB` resolved to a private address, and `pg_isready` reported that PostgreSQL
  was accepting connections.
- `RUBY_DEBUG_ENABLE=0 RAILS_ENV=development bin/rails runner` verified the Rails queue config,
  `SolidQueue::Job` connection config and connected `current_database()` were all
  `development_queue_db`.
- In a read-only transaction, the query counted unfinished
  `OidcBackchannelLogoutDeliveryJob` rows by Solid Queue execution status and JSON argument shape.
  Result: `pending_delivery_jobs=0`; there were no argument shapes or execution statuses to
  classify. No job arguments or identifiers were printed or retained.
- A preliminary probe using the deprecated `ActiveRecord::Base.connection` accessor stopped before
  its SELECT. The inventory was rerun through `connection_pool.with_connection` and completed; both
  probes were read-only.
- Source search found one notifier call from `SignOidcLogout`, four receiver controllers (Core app,
  Core com, Core org and Edit org), and the existing BCL codec, delivery job, client registrations
  and discovery declarations.

## Limits

- No job was drained, deleted, retried or otherwise changed.
- The empty development queue does not establish whether a production or external RP has sent BCL
  to a public receiver. That external-consumer confirmation remains unavailable, so AT-007 remains
  **BLOCKED** and no BCL code was removed.
- No Minitest or Vitest test was run for this inventory.
