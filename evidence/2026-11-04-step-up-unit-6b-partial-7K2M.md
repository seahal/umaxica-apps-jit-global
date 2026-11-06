# Step-up unit 6b: partial verification

Date: 2026-11-04. Commit: `b30345216886c98af1f04cbd434f067f12decf01`. The worktree had extensive
uncommitted changes affecting all results. Unit 6b was incomplete; O-9 and O-10 owner endpoints were
not connected, contact registration remained temporarily refused, and the full lock inventory was
incomplete.

- Before the shared-role switch,
  `RAILS_ENV=test PARALLEL_WORKERS=1 xargs -a /tmp/op-r15-unit6-files.txt bin/rails test` passed 772
  runs / 6,541 assertions. This does not establish post-switch behavior or O-9/O-10 completion.
- After the switch, the Avatar and step-up integration pair returned 50 runs / 226 assertions / 4
  failures (`/tmp/op-r15-role-regression7.log`), involving unimplemented Q-1 and contact
  registration. Earlier runs and a fixture contamination repair are recorded in `zero.md`.
- Targeted unconnected O-9 persistence/accounting/IAM tests passed 28 runs / 254 assertions
  (`/tmp/op-r15-o9-o10-persistence-tests3.log`). The APP/ORG temporary-route controller and
  transition tests passed 3 runs / 69 assertions (`/tmp/op-r15-sensitive-final2.log`). The
  unconnected attach and redemption concurrency tests passed 1 run / 6 assertions and 1 run / 8
  assertions respectively. These checks are not an end-to-end browser or final-write test.
- The IAM stop race and capability-revocation race each passed 1 run / 7 assertions; the target
  eligibility race and IAM primitive/audit tests passed 3 runs / 33 assertions. Commit
  acknowledgement failure injection passed 1 run / 18 assertions. These do not prove every lock or
  failure path.
- Secret signup lock ordering, APP owner endpoint redaction and IAM digest focused checks passed
  together 8 runs / 73 assertions (`/tmp/op-r15-secret-lock-race2.log`). The earlier failed race
  test and its correction are described in `zero.md`.
- `bun run check` and `bun run typecheck` did not pass due to unrelated existing lint/type findings
  identified in `zero.md`; scoped Step-Up frontend tests passed 33 tests.

Pending: O-9 browser transfer conflicts with the accepted POST-only condition and repository CSRF
rules; owner decision was requested. O-10 runtime integration, Q-1, contact registration, lock
inventory and the full shared-role browser journey remain unverified. Test-only migrations and exact
test residue cleanup are documented in `zero.md`; no development or production database was written.
