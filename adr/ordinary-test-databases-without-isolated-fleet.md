# Ordinary test databases without an isolated fleet

Accepted: 2026-10-20, repository owner instruction to stop using the isolated database/manifest
mode.

## Decision

Minitest and the Rails browser runner use the ordinary fixed `test_*` PostgreSQL configuration.
There is no PostgreSQL per-run fleet selector, parent manifest, worker ownership receipt or
isolated-fleet rebuild command. Fixed host/port/user and test-database checks remain mandatory. The
browser verifies live pool targets before serving HTTP and retains its existing CSRF, credential,
provider, transport and Valkey boundaries.

The existing ordinary parallel test cloner remains. SQL TEMPLATE copies preserve migrated reference
data and security-definer function ownership. Rails-standard schema-loading preparation cannot yet
reproduce these: see the
[reference-data backlog](../plans/backlog/2026-10-20-reference-data-outside-migrations.md). Retiring
isolated mode does not claim that the ordinary cloner is a Rails-standard implementation.

The browser and Minitest coordinate through `tmp/parallel-test-databases.lock`. Database preparation
and reset must also be scheduled outside active runs. The browser's current scenario is read-only;
it performs no PostgreSQL clone creation, reset or deletion. Future mutable browser scenarios need
an explicit synthetic-data lifecycle before adoption.

## Consequences and recovery

Avatar tests retain their real COMMIT and independent-connection assertions on ordinary test
databases. Committed data persists beyond test rollback, and ordinary clone caching checks schema
freshness rather than row cleanliness. Failed non-transactional tests can require an approved test
database reset. Introducing another manifest-based execution mode is not the recovery procedure.

No existing isolated database, cluster role, receipt or manifest is deleted by this retirement.
Cleanup requires separate inventory, explicit risk/recovery approval and verified ownership.
Historical evidence remains historical. The
[successor specification](../specs/retire-isolated-test-fleet/spec.md) replaces the PostgreSQL
ownership/lifecycle requirements of the closed
[browser foundation](../specs/rails-browser-e2e/spec.md); it preserves that document's original
result.
