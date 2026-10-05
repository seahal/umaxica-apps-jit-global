# app legacy reveal retirement and signed-in Passkey Step-Up

Performed 2026-10-04, recorded after 04:09 UTC (Etc/UTC).
Rails branch `feature`, HEAD f313b126931cfe3c9ecf64bbb72fb1cd3a0aada5.
The shared worktree had 374 dirty paths at the final preceding capture.
Results include uncommitted concurrent work, not CI or a clean-commit result.

## Legacy reveal retirement

Removed only the app `/identity/recovery-secret` route, controller and old
controller tests. Removed unused app recovery-purpose/configuration branches;
com configuration and its single-delivery route remain. New public HTTP tests
verify anonymous GET/HEAD/OPTIONS return 404 and an authenticated old valid
reference neither discloses plaintext nor consumes its receipt.

Commands used the existing guarded disposable-DB wrapper:
`bundle exec ruby /tmp/umaxica-secret-db-task.rb test <test files>`.
The wrapper verified ownership of the task-only PostgreSQL database fleet.

- Red: new retirement test, 2 tests/2 assertions/2 failures. The old authenticated
  GET returned 200; anonymous GET redirected instead of returning 404.
- Green: retirement test, com reveal controller and parallel com reveal test,
  9 tests/92 assertions, zero failures/errors/skips.
- Regression: those files plus Base Dashboard guidance, app/com Passkey and org
  local login journeys, three Roots controller suites, region routing contract
  and forbidden Rails pattern tests: 74 tests/475 assertions, zero failures/errors/skips.
- RuboCop on routes, the two changed shared concerns and two integration files:
  5 files, no offenses after formatting correction.

## Signed-in Passkey registration

Removed `bootstrap: true` from app Passkey registration, options and verification
Step-Up declarations. Existing normal Client root sessions with no available
Step-Up method receive the existing inline error (JSON 422, document 403), avoiding
a registration setup redirect loop. Com/org and initial signup without a Client
root session do not enter that branch. `require_verification!` only records the
request-local requirement; it does not change the persistent session context.

- Red: the new Secret-session rejection test reached the REST registration
  business response instead of the Step-Up rejection: 1 test/2 assertions/1 failure.
  This reproduced a gate bypass, not successful creation of a new Passkey.
- Expanded HTTP test: 3 tests/23 assertions, zero failures/errors/skips. Covers
  all three POST entry points, refusal without a redirect loop and a separately
  bound Passkey Step-Up finalized through the actual Base committer. Ceremony
  verification evidence is synthetic; no WebAuthn signature or Secret login is
  claimed by this prepared-state authorization test.
- Final regression command selected the new HTTP test, app Secret Step-Up binding,
  ceremony freshness committer, Step-Up response shape and com/org Passkey controller
  suites: 78 tests/384 assertions, zero failures/errors/skips after refactoring.
- `bundle exec rubocop` on VerificationBase, the three app controllers and the new
  HTTP test: 5 files, no offenses. Initial complexity offenses were resolved by
  extracting private response/predicate methods; no suppression or threshold changed.
- `git diff --check`: PASS.

NOT_RUN: complete signup registration, cryptographic Step-Up browser ceremony,
complete Secret presentation/login, other bootstrap entry points, full suite,
Chronicle delivery and audited purge. This change does not prove that every
indirect credential self-addition path is closed. No new persistence shape,
production duration, refresh protocol, shared DB operation or deployment was introduced.
