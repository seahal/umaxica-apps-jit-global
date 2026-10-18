# Avatar finite starts and actual commit scope

HEAD: `151f2d4b7d4b4cf2146d0237644726d06c5fe7f3`, feature. Application, test, migration,
environment-adapter and generated-schema changes are uncommitted, together with unrelated
source-policy/OTP documents. A documentation commit is not a complete implementation snapshot.
Criteria: AV-1/AV-2/AV-3 and A03/A04/A13. No production, shared-database, remote or CI execution.

## Observed defect and correction

A direct Rails runner provisioned two fresh, run-owned workers through the existing cloner, verified
parent/worker OID receipts, and opened two independent PG connections to worker 0's Avatar catalog.
It used synthetic values and real COMMIT, without transactional fixtures or trigger suppression.
Before the change, a valid Enterprise period committed and was visible independently; ownerless
Avatar creation and an Enterprise period starting at negative infinity also committed. Cross-family
overlap and a gap rejected COMMIT with SQLSTATE 23514, leaving no Avatar visible. This establishes
two actual defects, not a complete concurrency proof.

The ownerless defect remains unresolved. The existing integrity triggers fire on period-table
writes, not Avatar-only INSERT. Creation-writer/fixture preparation and a deferred creation guard
remain required; no accepted invariant was weakened to excuse this gap.

Two new public bulk-write regression cases cover nonfinite starts in Enterprise and Bureau even when
a corrupted Avatar creation timestamp matches. An initial draft used an invalid Ruby constant and
produced two NameErrors; that run was not legitimate Red. After correcting the test expression, Red
was genuine: 10 runs, 25 assertions, two failures, zero errors/skips, 0.404121 seconds; the DB
accepted the prohibited writes.

Rails generated:

- `db/avatars_migrate/20261011041046_add_finite_concrete_avatar_ownership_period_starts.rb`
- `db/avatars_migrate/20261011041103_validate_finite_concrete_avatar_ownership_period_starts.rb`

The first adds NOT VALID `isfinite(valid_from)` CHECKs through the public migration API. The second
validates them separately. No trigger, raw migration execute, row rewrite or new authorization was
introduced. The existing interval and history constraints remain. Read-only preflight verified the
owned Avatar catalog's manifest identity and found zero rows/nonfinite starts in each concrete
table; this is not evidence about production or retained data elsewhere.

Both migrations applied, rolled back (only their new CHECKs), and reapplied successfully in that
owned catalog. Validation rollback is monotonic/no-op; the preceding addition owns constraint
removal. Read-only pg_constraint inspection found both named CHECKs validated with exact definition
`CHECK (isfinite(valid_from))`. Explicit schema dump produced only two CHECK lines and two migration
versions in `db/avatar_structure.sql`; the schema file remains uncommitted.

Green: `bundle exec rails test test/models/avatar_concrete_ownership_period_test.rb` — 10 runs, 29
assertions, zero failures/errors/skips, 0.403902 seconds. Scoped RuboCop inspected the test and both
migrations, zero offenses. No assertion/allowlist/threshold was weakened.

After reapplication, a second fresh-clone actual-COMMIT probe observed: valid Enterprise ownership
committed and visible independently; negative and positive infinite starts rejected with SQLSTATE
23514 and no Avatar leaked; overlap/gap still rejected; ownerless Avatar still committed. The runner
reported observations, not overall PASS. All connections closed, parent cleanup removed its forty
fresh worker databases, and a read-only check found all eighty planned worker names absent with
twenty parent OID/owner/comment rows unchanged. No ownership-history rows were deleted from
parent/shared catalogs.

## Commands and scope

Commands sourced existing local configuration without printing secrets, selected the verified
20261010p3d2 manifest/primary host/complete twenty-database preparation scope, and used test only.
Direct clone construction used two workers; ordinary suites used four.

- `bundle exec rails runner /tmp/avatar-real-commit-probe-20261011.rb`: before/after behavior
  observations, exit 0. The temporary runner is not a durable test path; reproduce through the
  owning DB procedure and investigate actual constraints/tests. Enterprise COMMIT coverage does not
  substitute for Bureau or isolation-level concurrency coverage.
- `bundle exec rails generate migration AddFiniteConcreteAvatarOwnershipPeriodStarts --database avatar`
  and
  `bundle exec rails generate migration ValidateFiniteConcreteAvatarOwnershipPeriodStarts --database avatar`:
  generated exactly the reviewed migration files above.
- `bundle exec rails db:migrate:avatar`, `bundle exec rails db:rollback:avatar STEP=2`,
  `bundle exec rails db:migrate:avatar`: exit 0 for each owned migration/metadata-only round trip.
- `bundle exec rails db:schema:dump:avatar`: exit 0; owned generated difference reviewed.
- `bundle exec ruby /tmp/avatar-finite-start-catalog-20261011.rb`: identity/aggregate/validated
  constraint read-only checks, exit 0.
- `bundle exec ruby /tmp/isolated-clone-cleanup-catalog-20261011.rb`: cleanup/parent identity
  checks, exit 0.
- `bundle exec rubocop test/models/avatar_concrete_ownership_period_test.rb db/avatars_migrate/20261011041046_add_finite_concrete_avatar_ownership_period_starts.rb db/avatars_migrate/20261011041103_validate_finite_concrete_avatar_ownership_period_starts.rb`:
  three files, zero offenses after reducing assert_raises to its raising statement.

Both full Gate 2 suites started after the final source state. `bun run test` exited 0: 99 files,
1,140 tests, 13.51 seconds. `bundle exec rails test` remains running. No next feature implementation
is permitted before its outcome is known. READ COMMITTED/REPEATABLE READ/SERIALIZABLE races, stale
snapshots, ownership creation protection, all four concrete transfers/cutover and full nine.md
acceptance remain incomplete.

Documentation verification: `bundle exec scripts/check-repository-knowledge` with this evidence,
`docs/checklists/avatar-ownership.md` and `adr/database-trigger-usage-boundary.md` passed: 8
Skills/adapters, 68 documents, 1 evidence record, exit 0. `git diff --check` passed, exit 0. Only
owned documentation is authorized for local commit; source/test/migration/schema work remains
uncommitted and no push occurred.
