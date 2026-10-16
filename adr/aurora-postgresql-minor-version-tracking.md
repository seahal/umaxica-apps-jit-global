# Aurora PostgreSQL Minor Version Tracking in Development

Status: Accepted (2026-10-16)

## Context

`adr/staging-aurora-postgresql-topology.md` makes Amazon Aurora PostgreSQL the direction for
production, reached by way of staging. Local development and the Minitest suite run community
PostgreSQL images (`podman/psql-pub/Containerfile` and `podman/psql-sub/Containerfile`, currently
`postgres:18.6-bookworm`).

A PostgreSQL minor release can still break an application. Minor releases fix bugs and security
issues, but release notes regularly list behaviour changes, catalog or planner changes, and
extension fixes that require action after upgrade. Rails and its PostgreSQL adapter also gate
features on the server version; `adr/pgmem-test-database-backend.md` records one such case, where
`NOT ENFORCED` foreign key toggling depends on PostgreSQL 18.4 or later.

Every Aurora PostgreSQL minor version has an end-of-support date. If upgrade work starts only when
that date is near, there is no time left to find a problem, diagnose it, fix it and verify the fix.

Aurora engine versions and community PostgreSQL versions are not the same thing. Aurora publishes
its own engine versions and patch levels on top of a PostgreSQL base version, and the mapping
between them is defined only by AWS release notes.

## Decision

1. **The trigger is the AWS release.** When AWS releases a new Aurora PostgreSQL minor version in
   the PostgreSQL major series this application uses, development PostgreSQL is updated to the
   matching community PostgreSQL minor version.
2. **Same-day update is the operating principle.** The development update is made on the day the
   Aurora version is released. Upgrade work is never deliberately held back toward end of support.
3. **A missed day is recorded, not silently absorbed.** If the update cannot be made on release day,
   the reason and the unaddressed risk are recorded and the update follows promptly.
4. **The version is taken from AWS sources, never guessed.** The community PostgreSQL version that
   corresponds to an Aurora release is read from the AWS release notes and version documentation.
   An Aurora-specific patch number is never used as a PostgreSQL version number. If the
   corresponding community release is not yet published, or the mapping cannot be confirmed, no
   version is chosen by inference; the gap is recorded under decision 3.
5. **A minor update is not assumed compatible.** It is verified with the existing test suite and the
   checks listed in `docs/operations/postgresql-version-tracking.md`. This ADR adds no tests.
6. **Development and production are separate decisions.** Same-day tracking applies to development
   only. Production is not required to upgrade on the same day; it is upgraded after problems found
   in development are resolved and the required verification has passed.
7. **Major versions are out of scope.** Aurora supporting a new PostgreSQL major version does not
   move development to it. A major upgrade is evaluated separately, covering compatibility,
   extensions, migration method and rollback.

## Consequences

- Incompatibilities surface in development while the previous Aurora minor version is still fully
  supported, which leaves time to fix them before production must move.
- Development pays a recurring cost: an image change and a verification pass for every Aurora minor
  release, on short notice.
- Development tracks Aurora releases, not community releases. A community minor release that Aurora
  has not adopted is not picked up by this decision.
- Community PostgreSQL cannot reproduce Aurora's storage layer, replication, failover or
  Aurora-only parameters and extensions. Development verification therefore lowers, but does not
  remove, the risk of a production minor upgrade. Aurora-specific behaviour needs an Aurora
  environment, which does not exist yet (`adr/staging-aurora-postgresql-topology.md`).
- While production stays on Neon, the Aurora release stream is a forward-looking signal: it keeps
  development aligned with the target engine rather than the current production engine.

## Alternatives Considered

- **Upgrade only when end of support approaches.** Rejected. It concentrates discovery, diagnosis,
  fixing and re-verification into the period with the least slack.
- **Track every community PostgreSQL minor release.** Rejected as the trigger. It could move
  development to versions Aurora does not offer, so development would test a combination
  production cannot run.
- **Assume minor releases are compatible and skip verification.** Rejected. Release notes document
  behaviour changes and post-upgrade actions within minor releases.
- **Upgrade development and production together on release day.** Rejected. It removes the window
  in which development findings protect production.

## Relationship to Other Decisions

- `adr/staging-aurora-postgresql-topology.md` — complemented, not superseded. Its decision 6 leaves
  major version alignment deferred, which decision 7 here keeps. Its decision 6 names
  `postgres:17.7-bookworm`; the local images are now `postgres:18.6-bookworm`, so that version text
  is historical.
- `adr/pgmem-test-database-backend.md` — rejected backend; its 18.3/18.4 finding illustrates why a
  minor version difference matters.

## Open Items

- The Aurora PostgreSQL major version for production and staging is still unchosen.
- Who watches the AWS release feed, and through which channel, is not assigned.
- The production upgrade procedure and its approval gate are not written.

## References

- `docs/operations/postgresql-version-tracking.md` — the operating procedure for this decision.
- Amazon Aurora PostgreSQL release notes:
  <https://docs.aws.amazon.com/AmazonRDS/latest/AuroraPostgreSQLReleaseNotes/Welcome.html>
- PostgreSQL release notes: <https://www.postgresql.org/docs/release/>
- PostgreSQL versioning policy: <https://www.postgresql.org/support/versioning/>
