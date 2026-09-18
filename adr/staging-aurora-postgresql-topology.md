# Staging Database Topology on Aurora PostgreSQL

Accepted: 2026-09-14

## Context

`adr/fakecloud-podman-staging-environment.md` fixes staging as a Podman-hosted FakeCloud
environment provisioned with Terraform. FakeCloud emulates the AWS services this application uses
for object storage and streaming, but the relational database is not among them: staging needs a
real PostgreSQL, and the intended target is Amazon Aurora PostgreSQL.

The application already separates writes from reads. This is not a change being designed; it is the
shape of the current code:

- `config/database.yml` declares 20 logical databases in the `production:` section — `publishing`,
  `com_zenith`, `app_zenith`, `org_zenith`, `app_setting`, `org_setting`, `com_setting`, `search`,
  `chronicle`, `org_ticket`, `com_ticket`, `app_ticket`, `app_signal`, `org_signal`, `com_signal`,
  `storage`, `queue`, `occurrence`, `avatar`, and `primary` — each with a `*_replica` counterpart
  carrying `replica: true`, for 40 connection definitions.
- Each domain's abstract record class binds them, e.g.
  `connects_to database: { writing: :app_zenith, reading: :app_zenith_replica }`.
- `config/initializers/multi_db.rb` sets
  `database_selector = { delay: 10.seconds }` with `Resolver::Session`.

All 20 writers resolve to a single host and all 20 readers to a single host. Today those are
`NEON_PGHOST` and `NEON_REPLICA_PGHOST`. The structure therefore already matches what an Aurora
cluster exposes — one writer endpoint and one reader endpoint — so the move is a change of
environment variables and operator, not a change of connection topology.

Aurora as the destination was previously recorded only in passing:
`evidence/2026-09-04-neon-production-schema-imaging.md` notes that the Neon production tier is
disposable and slated for replacement by Amazon Aurora. No ADR and no document carried the decision.

## Decision

1. **Production stays on Neon for now.** The `NEON_*` variables in `config/database.yml` remain the
   production configuration. This ADR does not schedule a production migration.

2. **Aurora PostgreSQL is the direction for production, reached by way of staging.** Production
   moves to Aurora only after the staging environment is running. Until then, staging and production
   deliberately run different database backends.

   **Staging's own database backend is deferred** (revised 2026-09-14). FakeCloud emulates neither
   RDS nor Aurora, so staging cannot obtain PostgreSQL from it — see
   `adr/fakecloud-podman-staging-environment.md` decisions 9 and 10. Whether staging runs real
   Aurora, the existing `postgres:17.7-bookworm` containers, or something else is settled when
   staging implementation begins, at which point FakeCloud's service coverage is re-checked. Every
   decision below states the topology that applies **whenever Aurora is the backend**; none of them
   asserts that staging will be Aurora on day one.

3. **An Aurora staging deployment is one cluster with two DB instances**: one writer and one reader.
   The application consumes two hostnames — the cluster (writer) endpoint and the reader endpoint —
   exactly as it consumes two Neon hostnames today.

4. **The reader count is one, and never zero.** An Aurora cluster with no reader instance still
   answers on its reader endpoint by routing to the writer. A `replica: true` connection would then
   silently reach the writer, and staging would report a passing read/write split that was never
   exercised. One reader instance is the minimum that makes the split real.

5. **All 20 logical databases share the one staging cluster.** They are 20 databases inside it, not
   20 clusters. This mirrors the current Neon arrangement, where every logical database resolves to
   the same writer host and the same reader host.

6. **PostgreSQL major version alignment is out of scope.** Local development runs
   `postgres:17.7-bookworm` (`podman/psql-pub/Containerfile`). Staging takes whatever Aurora
   PostgreSQL major version is selected at provisioning time. Aligning the two is deferred, not
   decided against.

7. **`pg_cron` stays as an unused local PoC.** No migration, model, or initializer calls it; no
   `db/*_structure.sql` contains it. It is preloaded on the local primary
   (`shared_preload_libraries = 'pg_stat_statements,pg_cron'`) and created in the `db` database with
   `cron.database_name = 'db'`. `podman/pg-cron-poc/` is retained for future investigation because
   Neon does not offer `pg_cron` and Aurora does, so staging is the first environment where it can
   be evaluated for real.

8. **`pg_cron` is not wired into Rails.** No connection to the `db` database is added to
   `config/database.yml`. The PoC is driven through `psql` per `podman/pg-cron-poc/README.md`.
   `cron.database_name` is a single cluster-wide setting while Rails database names differ per
   environment (`development_primary_db` vs `test_primary_db`), so pointing it at a Rails database
   could match only one environment and would break the rule that behaviour is uniform across
   environments. A neutral `db` database is what keeps development and test identical.

## Consequences

- While staging runs Aurora and production runs Neon, staging validates the production Rails
  configuration against a different database engine. Engine-specific behaviour — planner choices,
  extension availability, connection limits, failover semantics — is not covered by staging during
  that window. This is accepted as the cost of migrating staging first.
- Replica lag characteristics change on the move. Aurora replicates through shared storage rather
  than streaming replication, so the `delay: 10.seconds` in `config/initializers/multi_db.rb` should
  be re-examined at migration time rather than carried over unread.
- Two DB instances is the floor, not a cost target. Dropping the reader to save money silently
  disables the only thing the second instance is there to prove (decision 4).
- Aurora enables `pg_cron` through the **cluster** parameter group (`shared_preload_libraries`,
  `cron.database_name`), not the instance parameter group. Expect this to be the first place a
  `pg_cron` attempt on Aurora fails.
- The local `pg_cron` job-execution mechanism does not carry over. As recorded in
  `podman/psql-pub/entrypoint.sh`, scheduled jobs authenticate as ordinary TCP clients and are made
  to work locally with a `.pgpass` file; Aurora exposes no OS-level file access, so job execution
  must be re-verified there by a different means.
- Migrating production to Aurora later is a swap of the `NEON_*` variable family for an Aurora
  equivalent in the `production:` section of `config/database.yml`. No `connects_to` declaration and
  no `replica: true` entry needs to change, provided decisions 3 and 5 hold.

## Open items

- **Staging's database backend is unchosen** (decision 2). Re-check FakeCloud's service coverage for
  RDS or Aurora when staging implementation begins; if it is still absent, choose between real
  Aurora and the existing local PostgreSQL containers. Note that an emulated RDS surface would very
  likely be an ordinary PostgreSQL behind an RDS-shaped API, which would not exercise the
  Aurora-specific behaviour listed under Consequences.
- The Aurora PostgreSQL major version for staging is unchosen (decision 6).
- The environment-variable names replacing `NEON_PGHOST` / `NEON_REPLICA_PGHOST` for Aurora are
  unchosen. The reader entries additionally read `NEON_REPLICA_PGSSLMODE` and
  `NEON_REPLICA_PGCHANNELBINDING`, which have no automatic Aurora counterpart.
- No SSL configuration for Aurora exists. `config/database.yml` reads `sslmode` and
  `channel_binding` from the `NEON_*` family and contains no `sslrootcert` anywhere; Aurora's
  `verify-full` needs the RDS CA bundle, and `channel_binding` has no Aurora counterpart.
- Connection sizing is unresolved. `config/database.yml` sets `pool` to `RAILS_MAX_THREADS` or 32,
  across 40 connection definitions, while `config/puma.rb` defaults the same variable to 3. Neon
  absorbs this with a built-in pooler; Aurora has none without RDS Proxy, so instance class and pool
  size have to be settled together.
- Database authentication method is unchosen — password (as today) or Aurora IAM database
  authentication, which changes how `config/database.yml` is written.
- Failover handling is unverified. Aurora switches the writer endpoint by DNS, and stale pooled
  connections are a known consequence; `config/database.yml` sets no `reaping_frequency`.
- Creating the 20 logical databases on Aurora has no procedure.
  `evidence/2026-09-04-neon-production-schema-imaging.md` records that
  `RAILS_ENV=production bin/rails db:migrate` aborts during boot in `config/initializers/jwt.rb`;
  the same wall stands in front of Aurora.
- No Terraform describes an Aurora cluster, subnet group, parameter group, or security group.
  `terraform/modules/` holds only `object_storage` and `streaming`.
- Nothing has been provisioned or verified. No Aurora cluster exists, and
  `terraform/environments/staging-development` currently provisions object storage buckets only.

## References

- `adr/fakecloud-podman-staging-environment.md` — the staging environment this database belongs to.
- `adr/global-regional-database-ownership.md` — which databases are Global versus Regional.
- `config/database.yml` — the 20 logical databases and their writer/reader pairs.
- `config/initializers/multi_db.rb` — the read/write split resolver and delay.
- `podman/pg-cron-poc/README.md` — the retained PoC procedure.
- `evidence/2026-09-04-neon-production-schema-imaging.md` — the prior, passing record of the Aurora
  intent.
