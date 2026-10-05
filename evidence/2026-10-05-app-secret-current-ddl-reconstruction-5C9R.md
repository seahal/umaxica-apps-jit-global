# Current migration reconstruction and post-confirmation retry finding

Observed 2026-10-05 UTC, through 15:42:47+00:00, against HEAD
`e8f2371bc5cbefd2087c728aeeef4e318463d33f` with uncommitted changes.
No shared database operation, application source migration rewrite, manual dump
edit, full-suite or E2E run occurred.

Fresh reconstruction used new OID/owner-manifest-guarded
`codex_integrity_20261005currentfresh_*` databases:

- `bundle exec ruby /tmp/umaxica-secret-current-fresh-db-task.rb provision`:
  created 20 new task-owned databases, refused replacement of existing targets.
- Same runner `db:migrate`: exited 0. A subsequent read-only observation using
  Rails migration contexts verified **20 writing owners with no pending versions**,
  including app Source 371, app Ticket 98 and Chronicle 21 applied versions.
  Required credential/issuance/outbox/receipt and principal/Passkey/token/flow
  tables were present; old app kind/status tables and usage counters were absent.
- Same runner `test test/models/client_secret_credential_rebuild_test.rb
  test/models/client_secret_credential_test.rb test/queries/client_secret_lookup_query_test.rb
  test/values/client_secret_issuance_count_value_test.rb`: seed 43717,
  **29 runs, 283 assertions, no failures/errors/skips**, 1.284206 seconds.

Separate staged Source reconstruction used new guarded
`codex_integrity_20261005legacycore_*` databases and
`/tmp/umaxica-secret-current-legacy-rebuild-observation.rb`:

- Applied existing Source migrations through 20261003202225 and required all
  three old app Secret tables to exist. Ran exactly the existing authorized
  app-only `RebuildAppSecretCredentials` migration, version 20261003215326.
- The rebuilt credential table received a new OID; old kind/status tables were
  absent. All **114 unrelated Source table OIDs were preserved**, including
  clients and client_passkeys. Applied subsequent Source migrations: 371 versions,
  none pending. The runner exited 0.
- This is a schema/OID preservation observation with no legacy credential rows,
  not a data inheritance or restoration proof. The migration's down method remains
  explicitly irreversible.
- The first legacy runner identifier exceeded the existing 12-character suffix
  limit and boot rejected it before migrations. Its provisioned databases remain
  empty and untouched. A valid distinct legacycore identifier was then used;
  no safety check was weakened and no database was reset or dropped.

Fresh-fleet `db:verify_no_schema_drift` exited **1**. The only dump differences
remain one CHECK array-cast serialization change in each of app Ticket, app Source,
com Ticket and org Ticket. No additional schema files changed. The earlier
86-input HEAD/dump/live comparison establishes observed CHECK behavior; this
command still reports uncommitted artifact drift and is not counted as passed.

Independent HTTP finding:

- Added a post-confirmation resend to the actual manual delivery journey.
  Guarded recovery runner `test test/integration/app_secret_login_journey_test.rb
  --include '/manual HTTP delivery/'`: seed 12410, **1 run, 18 assertions,
  1 failure**, 1.287972 seconds. Resending create after saved confirmation added
  one issuance instead of retaining the existing result.
- This failing regression remains visible. Proposed nonsecret operation form
  data, session binding and Source-only authority snapshots are awaiting explicit
  shape approval. No production shape fix or new DDL was generated/applied.

Fresh and staged DDL reconstruction are now observed; schema drift review,
post-confirmation retransmission, live-owner barrier retirement and remaining
acceptance work keep the overall goal incomplete. TTL values are already accepted;
the pending approval concerns data/form shapes rather than operating durations.
