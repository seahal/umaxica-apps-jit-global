# R1 authentication context implementation and scoped verification

Date: 2026-10-16 UTC. Branch: `feature`. Execution HEAD: `17903f7d121aa33efe29f2db9235c9aa5db4b001`.
The worktree was clean before implementation; ignored root specifications were present. Subsequent
application/test changes are uncommitted and are identified with their observed results below. No
commit or deployment is claimed.

## Authorization and execution boundary

The user explicitly granted I for R1-WU01 and then D for R1 tests on the twenty existing isolated
databases in `tmp/acceptance-isolated-20261016w6n2.json`, using one worker and allowing fixture
writes only. No creation, drop, reconstruction, migration, ordinary development/test database
mutation, credential cutoff or external state change was authorized or performed.

## Test-target preflight

- `bundle exec ruby` with `pg` and `json`: READ ONLY catalog comparison matched all twenty manifest
  database names, OIDs, owners and identifying comments. Manifest host/port/user bindings matched
  the configured test connection without printing credentials.
- An R1-only Rails boot with `PGOPTIONS='-c default_transaction_read_only=on'` found schema-dump
  digest mismatches for all twenty writers. A second guarded check using
  `ActiveRecord::Migration.check_all_pending!` was refused when the existing initializer attempted
  `CREATE TABLE IF NOT EXISTS` in READ ONLY mode. No schema write occurred.
- Direct READ ONLY `SELECT version FROM schema_migrations` compared with each configured migration
  path then matched exactly on all twenty writers: no missing or extra versions. This comparison
  avoids opening a Migrator that issues DDL. No database preparation task was run.

All test commands below use this common invocation, with explicit test file arguments:

```bash
RAILS_ENV=test PARALLEL_WORKERS=1 \
POSTGRESQL_ISOLATED_TEST_RUN_ID=20261016w6n2 \
POSTGRESQL_ISOLATED_TEST_MANIFEST=/home/global/workspace/tmp/acceptance-isolated-20261016w6n2.json \
bundle exec ruby -Itest -e 'require_relative "config/environment"; ActiveRecord.maintain_test_schema = false; require "rails/test_unit/runner"; Rails::TestUnit::Runner.run(ARGV)' <test-files>
```

The process-local maintenance setting prevents implicit schema reconstruction from stale dump
digests. DatabaseSafety remains active. Fixture writes and run-namespaced Valkey test state are
ordinary scoped test activity. The application, environment configuration and test helper are not
changed to weaken safety.

## Before application changes

- `test/values/authentication_context_value_test.rb`,
  `test/policies/emergency_authentication_context_policy_test.rb`,
  `test/controllers/auth/org/verification/emergency_step_up_prohibition_test.rb`: **21 runs, 115
  assertions, zero failures/errors/skips**, exit 0.
- `test/controllers/base/oauth_token_exchange_e1_test.rb`,
  `test/services/oidc_refresh_token_coalescing_test.rb`,
  `test/services/oidc_refresh_token_issuer_surface_test.rb`,
  `test/services/oidc_access_token_authenticator_test.rb`,
  `test/services/oidc_access_jwt_child_revoke_independence_test.rb`,
  `test/concerns/auth/org_emergency_session_continuity_test.rb`: **40 runs, 226 assertions, zero
  failures/errors/skips**, exit 0.

These existing regressions do not prove that the missing OIDC context defect is fixed. AT-R1-01
remains open until its actual applicable criteria have observed results. R1 release closure and
R2-R5 are not authorized by this record.

- `test/integration/org_oidc_auth_handoff_root_completion_test.rb`: **4 runs, 199 assertions, zero
  failures/errors/skips**, exit 0. Includes the current public Normal finalization/retry path; this
  is not Emergency reissue acceptance.
- Newly authored public endpoint regression in
  `test/controllers/base/oauth_token_exchange_e1_test.rb`
  (`public Code and Refresh exchange preserve the emergency root authentication context`) was run
  before application edits: **1 run, 2 assertions, 1 failure, zero errors/skips**, exit 1. The
  correctly signed Code-exchange Access decoded to `normal` instead of the root's `emergency`.
  Execution stopped at that assertion, so this red run did not reach the Refresh assertion.

## Concurrent work and specification clarifications

The user then requested a response to Luna Max's `six.md` escalations. Sol appended dispositions
there and reconciled `one.md`/`two.md` with existing user decisions: R5 successor logout ADR must be
Accepted before conflicting downstream code; JP runtime completion is WW5+JP7 while US runtime is
deferred; R1-WU01's current I and scoped D do not authorize R1-WU02 or later work. No ADR was edited
or deemed already superseded. The public reissue procedure now explicitly distinguishes GET
confirmation display from the protected POST that reissues credentials, matching current
`OidcAuthorizationResultPost` and the observed public integration test.

An unrelated concurrent modification to `src/features/auth/session/SignOutConfirmation.tsx` was
observed and preserved. It is not part of this R1 packet or its verification claim.
