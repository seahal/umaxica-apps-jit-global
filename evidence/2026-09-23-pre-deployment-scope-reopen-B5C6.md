# Pre-deployment scope reopen and test-environment check

- Date: 2026-09-23
- Repository: `seahal/umaxica-apps-jit-global`
- HEAD before this documentation update: `91d71c6f61d60c13be350bff3b723e05d09adf37`
- Worktree: pre-existing staged, unstaged, and untracked changes were preserved.
- External access: no AWS, Cloudflare, GitHub write, production data, deployed caller, or provider access.

## Scope decision

The repository is not deployed to production. Production runtime/data, deployed callers, real Base
registrations, credential fingerprints, and provider E2E were moved from current blocker closure
criteria into the Frozen Plan's `PRE-DEPLOYMENT / DEPLOYMENT ACCEPTANCE GATE`. Their absence is not
treated as a current defect or evidence failure.

The current pre-deployment statuses are:

- `CF-003/CF-004`: `OPEN — DECISION REQUIRED` for the exact owner mapping and lifecycle/conflict
  disposition contract.
- `CF-005`: `OPEN — EVIDENCE REQUIRED`; the repository configuration and queue entrypoint are
  present, but local recurring enqueue and controlled failure/retry/recovery acceptance could not
  be run without the queue/primary services.
- `CF-007`: `OPEN — DECISION REQUIRED` for the conflicting seven-client versus JP/US regional
  logical RP matrix.
- `CF-011`: `OPEN — EVIDENCE REQUIRED`; the provider-neutral authenticated receipt, bounded retry
  exhaustion, immutable permanent-failure, and authorized recovery contract is implemented, but
  PostgreSQL-backed migration, constraint, concurrency, and focused-test evidence is unavailable.

## Test environment check

The required variables were loaded from `.env.devcontainer.example`; presence was checked without
printing values. `config/credentials/test.key` was present. The required preflight command was run:

```text
bundle exec ruby -r ./lib/local_environment -e 'LocalEnvironment.load!; load "scripts/test-environment-check"'
```

It failed before the application checks because PostgreSQL host `primary` could not be resolved:

```text
PG::ConnectionBad: could not translate host name "primary" to address: Temporary failure in name resolution
```

`getent hosts primary` and `getent hosts valkey-kvs` returned no records. No fallback host, `/etc/hosts`
edit, Compose edit, or application edit was used. The focused Rails test command consequently did
not run in this session.

This environment failure is separate from the corrected deployment-scope decision. It blocks new
database-backed TDD evidence, but does not justify weakening tests or claiming acceptance.

The non-database Solid Queue configuration check was also run:

```text
RAILS_ENV=test bin/jobs check
```

Result: `Solid Queue configuration is valid.` This validates rendered configuration only; it does
not prove dispatcher pickup, scheduler execution, worker mutation, production topology, or
heartbeat monitoring.

A development `bin/jobs check` was then attempted with `RUBY_DEBUG_ENABLE=0` to avoid the
environment's debugger socket bootstrap. It reached Solid Queue's recurring-task validation but
failed when Active Record tried to inspect the queue schema because `primary` remained unresolved:

```text
ActiveRecord::DatabaseConnectionError: There is an issue connecting with your hostname: primary.
PG::ConnectionBad: could not translate host name "primary" to address: Temporary failure in name resolution
```

This confirms that the development queue check is also database-dependent in the current process;
it is not a configuration-validation success.

## Continuation recheck

The same isolated process boundary was rechecked after the next implementation continuation. The
container still exposed `/run/.containerenv`, but both service names remained unresolved:

```text
getent hosts primary      # no records
getent hosts valkey-kvs   # no records
```

The focused Rails command was not retried after the identical boot prerequisite remained absent.
No hostname, environment value, `/etc/hosts` entry, Compose service, or application configuration
was changed to bypass the failure.

## Boot dependency classification

The test boot dependency was inspected before any repository change. `config/database.yml` uses
`POSTGRESQL_TEST_HOST` for the test PostgreSQL connections and the devcontainer environment maps
that variable to the Compose service `primary`. `config/valkey.yml` declares test cache as an
in-process MemoryStore, while test rate-limit and auth-state intentionally use the KVS service
through logical databases 4 and 6. `config/environments/test.rb` constructs that rate-limit
client during boot; this is not an accidental cache connection or a silent fallback.

The configured variables are present in `.env.devcontainer.example`, but the current process has
no resolver entries for `primary` or `valkey-kvs`. `/run/.containerenv` is present, but the required
Compose service aliases are not available to this process. The repository configuration therefore
does not justify changing either hostname, substituting localhost, or adding a fake Valkey service.

Classification: `BLOCKED — ENVIRONMENT_UNAVAILABLE`. The minimum local recovery action is to run
the same preflight inside a core service attached to the Compose backend network after the
`primary` and `valkey-kvs` services are healthy. No application, test, or configuration change
was made to bypass this dependency.

## CF-011 implementation continuation

The approved pre-deployment CF-011 contract was implemented as a local slice: surface-local
notification attempts, monotonic delivery generations, durable idempotency digests, verified
receipt binding, bounded retry policy, immutable permanent failure, and authorized manual
recovery. No concrete processor, provider credential, provider protocol, or external service was
added. The default empty adapter registry remains fail-closed and records an unconfigured
processor as `PERMANENT_FAILURE`; it cannot produce `NOTIFIED`.

The focused RED/verification command was attempted after the slice:

```text
export UMAXICA_ENV_FILE=/home/global/workspace/.env.devcontainer.example
export POSTGRESQL_TEST_PREPARE_DATABASES=test_primary_db,test_app_ticket_db,test_com_ticket_db,test_org_ticket_db
export RAILS_ENV=test
PARALLEL_WORKERS=1 bin/rails test test/models/processor_erasure_notification_delivery_contract_test.rb
```

It did not reach a test assertion. Rails stopped while checking the test schema because PostgreSQL
host `primary` remained unresolved; the terminal error was:

```text
PG::ConnectionBad: could not translate host name "primary" to address: Temporary failure in name resolution
```

This is an environment failure, not a passing test result. Ruby syntax checks for the changed Ruby
files and `git diff --check` passed. Migration execution, structure-dump regeneration, focused
Minitest, queue E2E, and the full Rails suite remain unverified until the Compose backend aliases
are available.

## CF-011 contract implementation review

The pre-deployment contract was implemented without adding a provider or contacting an external
service. `NOTIFIED` now requires a verified adapter receipt bound to the notification public ID,
processor key, delivery generation, and attempt idempotency digest. Attempts persist outcome and
error state; retry exhaustion is terminal `PERMANENT_FAILURE`; authorized recovery increments the
generation without mutating prior attempts. The adapter registry remains empty by default and is
fail-closed.

The following non-runtime checks were executed against HEAD
`91d71c6f61d60c13be350bff3b723e05d09adf37` with pre-existing worktree changes preserved:

```text
ruby -c <changed Ruby and migration files>       # all Syntax OK
git diff --check                                  # passed
bundle exec rubocop <CF-011 changed files>       # 21 files, no offenses
```

The focused contract test could not boot for the environment reason recorded above, so CF-011 is
not closed. Its current Frozen Plan status is `OPEN — EVIDENCE REQUIRED`; PostgreSQL-backed
migration, constraint, concurrency, and focused test evidence remain required. Provider
authentication, provider receipt protocol, and provider E2E remain deployment/provider gates.

## Retry scheduling continuation

Review of the implemented state machine found that persisting `RETRYABLE_FAILURE` without a
re-enqueue path would not be an executable bounded-retry contract. The implementation therefore
re-enqueues a due attempt after a retryable or accepted-pending result and adds the bounded
`ProcessorErasureNotificationRetryJob` sweep in the existing `retention` queue for interrupted
enqueue recovery. The sweep covers only app/com notification allowlists and relies on the
notification row lock for attempt ownership; terminal rows are not retried.

The recurring YAML, changed Ruby/migration files, and targeted RuboCop were rechecked:

```text
ruby -c <changed Ruby and migration files>       # all Syntax OK
ruby -e '<load config/recurring.yml and queue.yml>' # queue-yaml-ok
git diff --check                                  # passed
bundle exec rubocop <23 CF-011 changed files>   # 23 files, no offenses
```

The repository-wide security scan was also run after the CF-011 continuation:

```text
bundle exec brakeman -q
```

Result: 0 errors and 0 security warnings. This static result does not replace the unavailable
PostgreSQL-backed state, migration, concurrency, or queue acceptance evidence.

A DB-free provider-neutral value-contract smoke check was also run:

```text
bundle exec ruby -Iapp -e '<retry-policy and verified-receipt/dispatch-result boundary checks>'
```

Result: `processor-value-contract-ok`. This covers only value construction and finite retry
classification; it does not prove Rails autoloading, persistence, locking, queue execution, or
provider receipt authentication.

The PostgreSQL-backed tests and queue execution evidence remain unverified because the required
`primary` and `valkey-kvs` service names are unavailable in this process. No local host fallback,
mocked runtime, or external service was used.

The CF-011 regression surface was strengthened with an independent-connection concurrency test for
at-most-one attempt claim and idempotent concurrent application of one verified receipt. The new
test is syntax-valid and passes scoped RuboCop, but it was not executed because it requires the
unavailable PostgreSQL test topology. It is therefore evidence to be collected, not acceptance
evidence already obtained.

## Boot dependency recheck

The requested environment-file selection and preflight were rerun in the current process on
2026-09-23. After `LocalEnvironment.load!`, all required variable names were present, and
`config/credentials/test.key` existed without reading its contents. The exact preflight then
failed before the Valkey checks while PostgreSQL attempted to resolve `primary`:

```text
PG::ConnectionBad: could not translate host name "primary" to address: Temporary failure in name resolution
```

The process has `/run/.containerenv`, but `podman` is not available and both `getent hosts primary`
and `getent hosts valkey-kvs` return no records. Repository inspection confirms this is not an
accidental cache dependency: `config/valkey.yml` selects an in-process MemoryStore for test cache,
while `config/environments/test.rb` intentionally constructs the test rate-limit Redis store from
the KVS responsibility (logical DB 4); auth-state also uses the KVS responsibility (logical DB 6).
Changing either hostname, substituting localhost, or adding a silent fallback would therefore
weaken the established test isolation and security contract. Classification remains
`BLOCKED — ENVIRONMENT_UNAVAILABLE`; the minimum recovery action is to rerun the same preflight
inside a core service attached to the Compose network after `primary` and `valkey-kvs` are healthy.

## Retention-purge boundary recheck

The existing `RetentionPurgeJob` explicitly includes app/com processor-erasure notifications and
uses set-based `delete_all`, which bypasses Active Record `dependent: :delete_all`. The new attempt
ledger therefore uses an intentional database `ON DELETE CASCADE`: attempt rows have no independent
retention window and inherit the parent notification's retention eligibility. The cascade does not
choose purge candidates and cannot bypass the parent's allowlist, retention hold, enforcement
guard, or kill switch. The app/com migrations, structure dumps, and delivery contract ADR document
this boundary, and a public DB-contract test covers parent deletion removing its subordinate
attempt row. The test remains unverified until PostgreSQL is available.

The retry sweep now rejects batch sizes outside `1..500`; the recurring configuration remains at
100 per surface. This is a finite upper bound in addition to the existing indexed due-work scope.
The recurring configuration contract test now checks the same retry task in both development and
production; this remains a static configuration assertion until an isolated queue runtime is
available.

The retry sweep test now also fixes the public behavior that only due app notifications within the
requested batch are enqueued. This is repository-level contract coverage and does not count as queue
runtime evidence.

## Latest static regression check

After adding the independent-connection CF-011 concurrency regression test, the following local checks
were rerun against the same HEAD and dirty worktree:

```text
ruby -c <new CF-011 test files>                                         # Syntax OK
bundle exec rubocop <new tests and CF-011 implementation files>         # no offenses
git diff --check                                                       # passed
bundle exec brakeman -q                                                # 0 errors, 0 security warnings
```

No Rails test, migration execution, PostgreSQL constraint test, independent-connection runtime test,
queue execution, or full suite was claimed from this process because the preflight still fails at
`primary` name resolution.

## Latest continuation audit

The BLOCKED record was re-evaluated without treating repeated observation as a permanent stop.
After loading `/home/global/workspace/.env.devcontainer.example`, all required test variable names
were present and `config/credentials/test.key` existed without reading its contents. The repository
boot path was rechecked before considering any workaround:

- `config/valkey.yml` selects `MemoryStore` only for the test cache;
- `config/environments/test.rb` intentionally builds the test rate-limit Redis store from Valkey
  logical database 4;
- test auth-state uses the same KVS service on logical database 6;
- `test/support/valkey_test_isolation.rb` requires the live KVS service for namespaced isolation and
  cleanup.

The exact preflight was run again with the explicit test environment and failed before its Valkey
checks because the current process could not resolve the configured PostgreSQL service:

```text
PG::ConnectionBad: could not translate host name "primary" to address:
Temporary failure in name resolution
```

`getent hosts primary` and `getent hosts valkey-kvs` returned no records, and `pg_isready -h primary
-p 5432` reported `primary:5432 - no response`. `/run/.containerenv` is present, but no Compose
service aliases are available to this process. No hostname, `/etc/hosts`, application setting,
fallback datastore, or test behavior was changed.

The repository-only continuation checks passed:

```text
bundle exec ruby -Itest test/values/processor_erasure_retry_policy_test.rb
3 runs, 11 assertions, 0 failures, 0 errors, 0 skips

bundle exec ruby -Itest test/values/processor_erasure_delivery_values_test.rb
3 runs, 14 assertions, 0 failures, 0 errors, 0 skips

bundle exec rubocop <latest processor value/migration files>
8 files inspected, no offenses detected

bundle exec brakeman -q
0 errors, 0 security warnings

git diff --check
passed

## Current status supersession (2026-09-23)

The earlier `CF-005: OPEN — EVIDENCE REQUIRED` entry in this historical record predates the
isolated local queue-runtime verification. It is superseded by
`evidence/2026-09-23-cf005-queue-runtime-P6Q7.md`, which records scheduler enqueue, dispatcher and
worker pickup, expected database mutation, and controlled failure handling. The current
pre-deployment status for CF-005 is therefore `CLOSED — PRE-DEPLOYMENT ACCEPTANCE SATISFIED`; its
production worker, heartbeat, monitoring, and operational rollback checks remain deployment gates.

The CF-011 implementation was subsequently extended with provider permanent-failure, locked-actor
recovery, terminal-notification recovery, and manual-recovery audit-event regression assertions.
Those latest DB-backed assertions remain `UNVERIFIED` in the current process because `primary` and
`valkey-kvs` are still not resolvable. The current CF-011 status remains `OPEN — EVIDENCE REQUIRED`.
This evidence file is historical input and must be read together with the current status table in
`plans/backlog/2026-09-17-integrated-hardening-plan.md` and the later CF-011 evidence records.
Classification remains `BLOCKED — ENVIRONMENT_UNAVAILABLE` for the current-process database-backed
revalidation only. The minimum next verification is the same preflight and focused/full Rails
commands inside a core service attached to the Compose network. This does not reopen the approved
pre-deployment CF-005/CF-011 design, and it does not provide any new input for the independent
CF-003/CF-004 or CF-007 decision gates.

## Current continuation check

The same required preflight was rerun before the next CF-011 state-transition verification. It
still failed before Rails boot with:

```text
PG::ConnectionBad: could not translate host name "primary" to address:
Temporary failure in name resolution
```

The focused DB-backed command was attempted and produced the same connection failure before test
assertions:

```text
PARALLEL_WORKERS=1 bundle exec bin/rails test \
  test/models/processor_erasure_notification_state_test.rb

ActiveRecord::DatabaseConnectionError: There is an issue connecting with your hostname: primary.
```

No test was deleted, skipped, mocked, or weakened. The newly added state-transition tests remain
unverified until the isolated PostgreSQL/Valkey topology is reachable. DB-free verification after
the state-boundary correction remains green:

```text
bundle exec ruby -Itest test/values/processor_erasure_delivery_values_test.rb
5 runs, 23 assertions, 0 failures, 0 errors, 0 skips

bundle exec rubocop
4773 files inspected, no offenses detected

bundle exec brakeman -q
0 errors, 0 security warnings

git diff --check
passed
```

The current status remains `CF-005: CLOSED — PRE-DEPLOYMENT ACCEPTANCE SATISFIED` and
`CF-011: OPEN — EVIDENCE REQUIRED`; the historical `CF-003/CF-004` and `CF-007` decision gates
remain open. This record contains historical observations and is not a replacement for the
current status table in the Frozen Plan.
