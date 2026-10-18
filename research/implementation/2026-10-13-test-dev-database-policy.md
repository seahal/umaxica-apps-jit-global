# Rails Development and Test Database Policy — Implementation Notes

## Context

- Original plan/spec: `one.md` database working rule, Frozen string (REQ-039), and Avatar transition
  (REQ-072); acceptance in `two.md` AT-039 and AT-072.
- Related decisions/docs/plans: `three.md` CHG-001 through CHG-003; `AGENTS.md` database safety
  requirements; `config/database.yml`; `lib/tasks/db_verify_no_schema_drift.rake`.
- Implementation date: 2026-10-13.

## Decisions Made During Implementation

- Decision: use only the repository's Rails `development` and `test` configurations as application
  data and migration targets in this implementation, as recorded in CHG-003. The standard test
  configuration is the target for database verification; the development configuration is reserved
  for checks that require development behavior. The existing test-preparation task also performs a
  read-only catalog check through its configured admin connection before preparing test databases.
  - Why: the user directed that an isolated database could produce an implementation that does not
    match normal Rails behavior and asked for the Rails workflow.
  - Alternatives considered: the isolated PostgreSQL fleet required by the frozen plan was rejected
    by the user for this implementation.
  - Follow-up needed: none for read-only checks. Any destructive reset still requires the risk and
    recovery-plan approval in `AGENTS.md`.

## Deviations From Plan

- Change: replace isolated-fleet acceptance targets for AT-039 and AT-072 with the standard Rails
  test database and Rails database tasks.
  - Why: user instruction recorded in `three.md` CHG-003.
  - Risk: replaying migrations from scratch requires destructive test-database preparation; no such
    operation was run in this session.
  - Follow-up: request explicit risk and recovery approval before a test-database reset if that
    remains necessary after the writable source files are available.

## Review Notes

- Tests run: targeted existing route tests passed after correcting the stale Device route
  expectation: 154 runs, 2,766 assertions, 0 failures, 0 errors, 0 skips. The test used
  `PARALLEL_WORKERS=1` against standard `test_*` databases. Rails `db:test:prepare` also queried the
  configured admin database `db` read-only for test-catalog verification; the test and migration
  targets remained the standard test databases.
- Tests not run: full Minitest or Vitest suite; no test-database reset or migration replay.
- Documentation promotion needed: current implementation change is recorded in `three.md`; this
  note preserves the verification decision and limitation.
