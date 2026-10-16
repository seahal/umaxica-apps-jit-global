# PostgreSQL Version Tracking for Development

This procedure applies `adr/aurora-postgresql-minor-version-tracking.md`. The ADR holds the reasons;
this document holds the steps.

## Scope

- Development and test PostgreSQL: `podman/psql-pub/Containerfile` and
  `podman/psql-sub/Containerfile` (currently `postgres:18.6-bookworm`).
- Minor versions within the PostgreSQL major series in use.
- Not covered: production or staging upgrades, and major version upgrades (see the last two
  sections).

## When AWS Releases an Aurora PostgreSQL Minor Version

1. Confirm the release belongs to the major series used here.
2. Determine the corresponding community PostgreSQL version (next section).
3. On the same day, update both Containerfiles to the matching `postgres:<major>.<minor>` image.
4. Rebuild the database containers and run the verification below.
5. Record the result in `evidence/` with the Aurora version, the PostgreSQL version, the commit hash
   and the outcome of each check.

Do not wait for end of support to approach.

## Confirming the Version Mapping

- Use the AWS sources only: the Aurora PostgreSQL release notes and the Aurora version
  documentation linked under References.
- Keep the two numbers apart. Record the Aurora engine version and the community PostgreSQL version
  it is based on as separate values.
- Never read an Aurora-specific patch number as a PostgreSQL version.
- Confirm the community release is published (PostgreSQL release notes) and that an official
  `postgres` image tag exists for it.
- If the mapping cannot be confirmed, or the community release or image is not available, do not
  pick a version by inference. Treat it as a missed update.

## Verification After an Update

Use the existing suites and tooling; do not add tests for the version change itself.

- The Rails applications boot and `bin/rails test` passes (see `docs/operations/test-environment.md`).
- Active Record and the PostgreSQL adapter work with the new server version, including any
  version-gated adapter features.
- Migrations run and `db/*_structure.sql` regenerate without unexpected diffs
  (`docs/operations/db-workflow.md`).
- The extensions in use still load: `btree_gist`, `citext` and `pgcrypto` in the structure files,
  plus the preloaded `pg_stat_statements` and the `pg_cron` PoC on the local primary.
- Key SQL and database features behave as before: constraints, deferred constraints, triggers,
  read/write split to the replica.
- Read the PostgreSQL release notes for every minor version skipped over, and act on listed
  incompatibilities, behaviour changes, known issues and required post-upgrade steps.

## When the Update Cannot Be Made on Release Day

Write an `evidence/` record that states:

- the Aurora version and its release date;
- why the update was not made (mapping unconfirmed, image unavailable, verification failure, other);
- the risk while development lags Aurora;
- the next action.

Then complete the update as soon as the blocker clears.

## Relationship to Production

Same-day tracking applies to development only. Production is upgraded separately, after
development findings are resolved and verification has passed. Community PostgreSQL cannot verify
Aurora-specific behaviour (storage, replication, failover, Aurora parameters and extensions); those
need an Aurora environment, which does not exist yet (`adr/staging-aurora-postgresql-topology.md`).

## Major Version Upgrades

A new major version supported by Aurora does not change the development image. A major upgrade is
evaluated separately: compatibility, extensions, migration method and rollback.

## References

- `adr/aurora-postgresql-minor-version-tracking.md`
- `adr/staging-aurora-postgresql-topology.md`
- Amazon Aurora PostgreSQL release notes:
  <https://docs.aws.amazon.com/AmazonRDS/latest/AuroraPostgreSQLReleaseNotes/Welcome.html>
- PostgreSQL release notes: <https://www.postgresql.org/docs/release/>
- PostgreSQL versioning policy: <https://www.postgresql.org/support/versioning/>
