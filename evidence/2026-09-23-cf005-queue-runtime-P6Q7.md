# CF-005 isolated queue runtime acceptance

Date: 2026-09-23

Repository commit: `91d71c6f61d60c13be350bff3b723e05d09adf37`

The worktree already contained uncommitted changes before this verification. No application
source, migration, queue configuration, external service, production database, or GitHub remote
was changed for the runtime probes. Temporary recurring definitions were created under `/tmp` and
removed after use. The only database rows created by the probes were isolated local test or
development records; the temporary test records were removed.

## Configuration and preflight

The explicit local Compose environment was selected without printing values:

```text
UMAXICA_ENV_FILE=/home/global/workspace/.env.devcontainer.example
POSTGRESQL_TEST_PREPARE_DATABASES=test_primary_db,test_app_ticket_db,test_com_ticket_db,test_org_ticket_db
```

`config/credentials/test.key` was present and its contents were not read. The required PostgreSQL
and Valkey variables were present. The repository preflight succeeded against the local Compose
services: PostgreSQL 17.7 was reachable at the resolved test target, and Valkey 7.2.4 returned
`PONG` for the rate-limit and auth-state logical databases. No localhost fallback or hosts-file
override was used.

The exact queue configuration validator passed for both local environments:

```text
RAILS_ENV=development bin/jobs check
RAILS_ENV=test bin/jobs check
```

Both rendered sections contained an explicit dispatcher, scheduler, and workers for `default`,
`retention`, and `solid_queue_recurring`. The ordinary test environment intentionally uses the Rails
test Active Job adapter, so a test-environment `bin/jobs` process does not prove business queue
execution. The execution probe therefore used the isolated development queue, where the configured
Solid Queue adapter is active.

## Scheduler, dispatcher, worker, and database mutation

Using a temporary recurring definition with a one-second schedule, the local default fork-mode
`RAILS_ENV=development bin/jobs start` supervisor was started and then stopped after the probe. The
recurring task was `SecurityConsumedJtiPurgeJob` on the explicit `retention` queue. An expired
`SecurityConsumedJti` row was inserted before the supervisor started. The earlier async-mode probe
had already passed the same path; the fork-mode run confirms the normal process topology as well.

Observed through the queue database and the owning application database:

```text
recurring task persisted: yes
recurring executions recorded: 5
SecurityConsumedJtiPurgeJob queue jobs observed: 5
completed queue jobs: 5
failed queue jobs in this run: 0
expired application row after execution: absent
```

This proves the local scheduler enqueue, dispatcher/worker pickup, forked worker execution, and
expected database mutation path. The normal repository schedule was restored after the temporary probe; the
development task schedule for `security_consumed_jti_purge` was verified as `every 15 minutes`, and
the test recurring-task table was returned to zero entries as required by `config/recurring.yml`.

## Controlled failure

An existing public job was enqueued with the invalid boundary `batch_size: 0`:

```text
SignUpExpiryJob.perform_later(batch_size: 0)
```

The isolated development worker processed it and recorded a terminal Solid Queue failed execution:

```text
job_finished: false
failed_execution: true
error_class: ArgumentError
error_message: batch_size must be positive
```

No successful business mutation was claimed. This is the fail-closed failure path for invalid job
input. Bounded retry and recovery behavior remains covered by the existing OIDC delivery and
processor-notification contract tests; no external provider was contacted for this runtime check.

## Acceptance decision

The repository-owned CF-005 pre-deployment conditions are satisfied:

- configuration is explicitly validated;
- the local supervisor has dispatcher, scheduler, and queue workers;
- a recurring task was scheduled and recorded;
- the worker picked up and completed the task;
- the owning database mutation was observed;
- an invalid controlled execution became a recorded failure rather than a false success;
- the normal test adapter and development Solid Queue adapter boundary remained intact.

**CF-005 status: CLOSED — PRE-DEPLOYMENT ACCEPTANCE SATISFIED.**

This does not claim production worker/process existence, production queue database connectivity,
heartbeat/monitoring, operational rollback, or external provider delivery. Those remain the separate
deployment/provider acceptance gates in the Frozen Plan.
