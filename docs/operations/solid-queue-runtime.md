# Solid Queue Runtime and Processing Inventory

This document is the current repository-level inventory for Active Job and Solid Queue. It is
intentionally explicit: a new job or queue must be added to this inventory, its configuration, and
the relevant contract tests together.

The inventory was rechecked on 2026-09-18 against the local `feature` worktree at the implementation
slice `0e9062de085e2d4ceba90199a03360d15fa7b7d2`. The installed versions are Rails `8.2.0.alpha`,
Solid Queue `1.7.0`, and Ruby `4.0.7`. The Solid Queue source and README in the installed gem were
used for configuration semantics and validation commands.

## Runtime boundary

`config/application.rb` selects `:solid_queue` as the Active Job adapter for the application
runtime. Development and production connect Solid Queue to the dedicated `queue` database; the test
environment keeps the Rails test adapter and does not start a scheduler or worker. The queue
database is infrastructure state, not an application or surface authority database.

The normal worker entrypoint is:

```sh
RAILS_ENV=development bin/jobs
RAILS_ENV=production bin/jobs
```

`bin/jobs` starts the Solid Queue supervisor, which starts the configured dispatcher, scheduler, and
workers. The web process does not need to start a second worker. The Puma Solid Queue plugin is not
enabled by default. A process that only runs the scheduler or only runs workers must use the
official `--only-recurring` or `--skip-recurring` options and must be documented as an operational
topology change; it must not silently use a different queue configuration.

Before starting a process, validate the environment-specific configuration without connecting to a
datastore:

```sh
RAILS_ENV=development bin/jobs check
RAILS_ENV=production bin/jobs check
```

The test environment has an explicit configuration section for isolated Solid Queue integration
checks, but ordinary Minitest runs use the test adapter and do not start it. No test may fall back
to a development, staging, or production queue database.

## Explicit queue topology

`config/queue.yml` contains three independently written environment sections. It has no YAML
anchors, aliases, merge keys, ERB loops, queue wildcards, or prefix wildcards. Every worker declares
its queue, thread count, process count, and polling interval.

| Environment | Dispatcher                                                       | Scheduler                                                              | Worker queues                                   | Processes and threads                                                                 |
| ----------- | ---------------------------------------------------------------- | ---------------------------------------------------------------------- | ----------------------------------------------- | ------------------------------------------------------------------------------------- |
| development | polling 1s, batch 500, concurrency and batch maintenance enabled | polling 5s, dynamic tasks disabled                                     | `default`, `retention`, `solid_queue_recurring` | `default`: `JOB_CONCURRENCY` processes, 3 threads; the other two: 1 process, 1 thread |
| test        | polling 1s, batch 500, concurrency and batch maintenance enabled | polling 5s, dynamic tasks disabled; no ordinary test process starts it | `default`, `retention`, `solid_queue_recurring` | one process and one thread per queue                                                  |
| production  | polling 1s, batch 500, concurrency and batch maintenance enabled | polling 5s, dynamic tasks disabled                                     | `default`, `retention`, `solid_queue_recurring` | `default`: `JOB_CONCURRENCY` processes, 3 threads; the other two: 1 process, 1 thread |

`JOB_CONCURRENCY` is required only when the environment needs a non-default value. Its default is
one process and the accepted range is 1 through 8; invalid values fail while the queue configuration
is rendered. The queue database pool is five for the isolated test configuration so the explicitly
configured one-thread worker has room for execution, polling, and heartbeat connections. Production
connection capacity must be reviewed together with the selected `JOB_CONCURRENCY` before increasing
it.

The `default` worker carries request-adjacent delivery and event work. The `retention` worker is
isolated so expiry, purge, reconciliation, and cleanup batches cannot occupy delivery capacity. The
`solid_queue_recurring` worker executes the command-job wrapper used by Solid Queue for command form
recurring entries.

## Recurring schedule

`config/recurring.yml` has separate `development`, `test`, and `production` sections. Development
and production intentionally contain the same business schedule. Test contains no recurring task.
Every class entry explicitly declares `class`, `queue`, `priority`, `args`, and `schedule`. The
single command entry uses only `command` and `schedule`, as required by Solid Queue 1.7.0.

The following fifteen entries are registered independently in both development and production:

| Entry                                          | Class or command                                                        | Queue                           | Arguments                   | Schedule            | Purpose                                                                 |
| ---------------------------------------------- | ----------------------------------------------------------------------- | ------------------------------- | --------------------------- | ------------------- | ----------------------------------------------------------------------- |
| `clear_solid_queue_finished_jobs`              | `SolidQueue::Job.clear_finished_in_batches(sleep_between_batches: 0.3)` | Solid Queue's command job queue | command form; no class args | hourly at minute 12 | Bound finished-job table growth                                         |
| `sign_up_expiry`                               | `SignUpExpiryJob`                                                       | `retention`                     | `[]`                        | every 15 minutes    | Terminalize expired app/com sign-up tickets and invoke existing cleanup |
| `email_ceremony_transaction_purge`             | `EmailCeremonyTransactionPurgeJob`                                      | `retention`                     | `{ batch_size: 1000 }`      | every 15 minutes    | Purge expired email ceremony transactions                               |
| `passkey_ceremony_transaction_purge`           | `PasskeyCeremonyTransactionPurgeJob`                                    | `retention`                     | `[]`                        | every 15 minutes    | Purge expired passkey ceremony transactions                             |
| `secret_credential_ceremony_transaction_purge` | `SecretCredentialCeremonyTransactionPurgeJob`                           | `retention`                     | `[]`                        | every 15 minutes    | Purge expired secret-credential ceremony transactions                   |
| `social_ceremony_transaction_purge`            | `SocialCeremonyTransactionPurgeJob`                                     | `retention`                     | `[]`                        | every 15 minutes    | Purge expired social ceremony transactions                              |
| `step_up_ceremony_transaction_purge`           | `StepUpCeremonyTransactionPurgeJob`                                     | `retention`                     | `{ batch_size: 500 }`       | every 15 minutes    | Purge expired step-up transactions                                      |
| `telephone_ceremony_transaction_purge`         | `TelephoneCeremonyTransactionPurgeJob`                                  | `retention`                     | `{ batch_size: 500 }`       | every 15 minutes    | Purge expired telephone ceremony transactions                           |
| `totp_ceremony_transaction_purge`              | `TotpCeremonyTransactionPurgeJob`                                       | `retention`                     | `[]`                        | every 15 minutes    | Purge expired TOTP ceremony transactions                                |
| `retention_purge`                              | `RetentionPurgeJob`                                                     | `retention`                     | `{ batch_size: 500 }`       | every 15 minutes    | Run the explicit application retention allowlist and pending cleanup    |
| `dpop_proof_state_purge`                       | `DpopProofStatePurgeJob`                                                | `retention`                     | `{ batch_size: 500 }`       | every 15 minutes    | Delete expired DPoP replay state                                        |
| `security_consumed_jti_purge`                  | `SecurityConsumedJtiPurgeJob`                                           | `retention`                     | `{ batch_size: 500 }`       | every 15 minutes    | Delete expired single-use replay records                                |
| `security_one_time_reveal_purge`               | `SecurityOneTimeRevealPurgeJob`                                         | `retention`                     | `{ batch_size: 500 }`       | every 15 minutes    | Delete expired one-time reveal records                                  |
| `enforcement_expiry`                           | `EnforcementExpiryJob`                                                  | `retention`                     | `{ batch_size: 200 }`       | every 15 minutes    | Converge expired enforcement cases                                      |
| `enforcement_reconciliation`                   | `EnforcementReconciliationJob`                                          | `retention`                     | `{ batch_size: 200 }`       | every 15 minutes    | Recover apply, ended-Case, and persisted appeal convergence             |

The request-time expiry and authorization checks remain authoritative when the scheduler is down.
The schedule is a recovery and cleanup mechanism, not an authorization boundary.

## Processing audit ledger

The following ledger names every concrete application job in `app/jobs`, the gem-owned jobs that
this application actually invokes, and the current decision for each execution path. `default` and
`retention` refer to the exact workers in `config/queue.yml`; `queue` refers to the dedicated Solid
Queue database; the final database write occurs on each model's configured surface or infrastructure
connection.

| Processing unit                               | Trigger and source                                                                 | Effective queue                                                       | Consumer                       | Retry / failure / recovery                                                                                                                                                                                                                             | Decision                                                                                 |
| --------------------------------------------- | ---------------------------------------------------------------------------------- | --------------------------------------------------------------------- | ------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ---------------------------------------------------------------------------------------- |
| `AppleNotificationProcessingJob`              | `ExternalAuthenticationAppleNotificationIngress` enqueues by event JTI             | `default`                                                             | `default` worker               | The event row is locked; its domain retry window schedules the next attempt or dead-letters and alerts.                                                                                                                                                | A — event-driven and connected                                                           |
| `ApplicationPushNotificationJob`              | ActionPush Native enqueues `ApplicationPushNotification` delivery                  | `default` (explicit in `ApplicationPushNotification`)                 | `default` worker               | Gem delivery/retry behavior applies; application suspension is checked at execution and returns a deliberate no-op. The application notification class pins the queue so a gem or global default change cannot silently route push work elsewhere.     | A — event-driven and connected                                                           |
| `DpopProofStatePurgeJob`                      | recurring entry `dpop_proof_state_purge`                                           | `retention`                                                           | `retention` worker             | Bounded batches selected by indexed `expires_at`; a failed job remains a failed queue execution.                                                                                                                                                       | A — explicit recurring maintenance                                                       |
| `EmailCeremonyTransactionPurgeJob`            | recurring entry `email_ceremony_transaction_purge`                                 | `retention`                                                           | `retention` worker             | Delegates to the existing surface-local purger with a bounded batch.                                                                                                                                                                                   | A — explicit recurring maintenance                                                       |
| `EnforcementExpiryJob`                        | recurring entry `enforcement_expiry`                                               | `retention`                                                           | `retention` worker             | Per-case failures are logged; request-time enforcement does not depend on this sweep.                                                                                                                                                                  | A — convergent maintenance                                                               |
| `EnforcementReconciliationJob`                | recurring entry `enforcement_reconciliation`                                       | `retention`                                                           | `retention` worker             | Reconciles active apply side effects, ended-Case release/audit work, and persisted submitted/approved/rejected appeals. Approved appeals retry Case ending before `appeal_approved`; Chronicle existence is checked on the writer under the Case lock. | C — current-state appeal/end recovery connected; worker runtime remains unverified       |
| `OidcBackchannelLogoutDeliveryJob`            | `OidcBackchannelLogoutNotifier` enqueues one encrypted envelope per registered URI | `default`                                                             | `default` worker               | 2xx is success; 408/425/429 and 5xx raise a bounded Active Job retry; other HTTP statuses and invalid registration are failures; network errors are re-raised for retry.                                                                               | B resolved in this worktree; runtime delivery remains unverified                         |
| `Outbound::SmsDeliveryJob`                    | `OutboundSms.deliver_later` from OTP and notification adapters                     | `default`                                                             | `default` worker               | Payload is encrypted; AWS/network errors have bounded retries; invalid or plaintext payloads are permanently discarded only after `ActiveSupport.error_reporter` records the producer/configuration failure.                                           | A — event-driven and connected                                                           |
| `PasskeyCeremonyTransactionPurgeJob`          | recurring entry `passkey_ceremony_transaction_purge`                               | `retention`                                                           | `retention` worker             | Delegates to the existing purger.                                                                                                                                                                                                                      | A — explicit recurring maintenance                                                       |
| `ProcessorErasureNotificationJob`             | privacy-erasure request flow enqueues a surface/public-id pair                     | `retention`                                                           | `retention` worker             | Surface and concrete model are allowlisted; terminal state is idempotent. No concrete processor adapter is currently allowlisted, so the job records explicit failure/manual follow-up rather than claiming provider delivery.                         | B — connected but no processor integration enabled                                       |
| `RetentionPurgeJob`                           | recurring entry `retention_purge`                                                  | `retention`                                                           | `retention` worker             | Explicit model allowlist, bounded batches, feature kill switch, legal-hold/enforcement checks, and existing cross-database cleanup.                                                                                                                    | A — explicit destructive maintenance; production execution requires operational controls |
| `SecretCredentialCeremonyTransactionPurgeJob` | recurring entry `secret_credential_ceremony_transaction_purge`                     | `retention`                                                           | `retention` worker             | Delegates to the existing purger.                                                                                                                                                                                                                      | A — explicit recurring maintenance                                                       |
| `SecurityConsumedJtiPurgeJob`                 | recurring entry `security_consumed_jti_purge`                                      | `retention`                                                           | `retention` worker             | Deletes only rows past the replay-protection `expires_at` in bounded batches.                                                                                                                                                                          | A — explicit recurring maintenance                                                       |
| `SecurityOneTimeRevealPurgeJob`               | recurring entry `security_one_time_reveal_purge`                                   | `retention`                                                           | `retention` worker             | Deletes only rows past the reveal `expires_at` in bounded batches.                                                                                                                                                                                     | A — explicit recurring maintenance                                                       |
| `SignUpExpiryJob`                             | recurring entry `sign_up_expiry`                                                   | `retention`                                                           | `retention` worker             | Re-discovers expired in-progress `ClientSignUpFlow` and `VisitorSignUpFlow` rows; delegates terminalization and cleanup; deadlocks retry and individual non-critical failures are recorded for later sweep.                                            | C — newly connected recovery sweep                                                       |
| `SocialCeremonyTransactionPurgeJob`           | recurring entry `social_ceremony_transaction_purge`                                | `retention`                                                           | `retention` worker             | Delegates to the existing purger.                                                                                                                                                                                                                      | A — explicit recurring maintenance                                                       |
| `StepUpCeremonyTransactionPurgeJob`           | recurring entry `step_up_ceremony_transaction_purge`                               | `retention`                                                           | `retention` worker             | Delegates with a bounded batch.                                                                                                                                                                                                                        | A — explicit recurring maintenance                                                       |
| `TelephoneCeremonyTransactionPurgeJob`        | recurring entry `telephone_ceremony_transaction_purge`                             | `retention`                                                           | `retention` worker             | Delegates with a bounded batch.                                                                                                                                                                                                                        | A — explicit recurring maintenance                                                       |
| `TotpCeremonyTransactionPurgeJob`             | recurring entry `totp_ceremony_transaction_purge`                                  | `retention`                                                           | `retention` worker             | Delegates to the existing purger.                                                                                                                                                                                                                      | A — explicit recurring maintenance                                                       |
| `UserWithdrawalFinalizeJob`                   | Explicit event/manual producer only; no current recurring entry                    | `default`                                                             | `default` worker               | Delegates to the existing finalization workflow; no automatic schedule was inferred from the class name.                                                                                                                                               | F — not scheduled without a current producer contract                                    |
| `SolidQueue::RecurringJob`                    | Solid Queue scheduler enqueues command-form recurring entries                      | `solid_queue_recurring`                                               | `solid_queue_recurring` worker | The recurring execution table and unique task/run key prevent duplicate scheduler enqueue for retained finished jobs.                                                                                                                                  | A — gem-owned scheduler path                                                             |
| `ActionMailer::MailDeliveryJob`               | `deliver_later` in OTP, notice, and promotion adapters                             | `default` in the current Rails configuration and integration contract | `default` worker               | Mailer delivery errors follow the mailer/Active Job contract. OTP codes and verification tokens are encrypted before enqueue; tests use the Rails test delivery method and never contact a provider.                                                   | A — gem-owned event path                                                                 |
| `Noticed::EventJob`                           | Noticed adapters enqueue non-OTP notices                                           | `default` from `Noticed::ApplicationJob`                              | `default` worker               | The Noticed event is the asynchronous boundary. OTP calls `deliver_now` inside its already asynchronous notification job; OTP codes and verification tokens are encrypted before `Notifier.with`.                                                      | E — synchronous inside an existing job by design                                         |

No current producer was found for a new recurring JWKS refresh, Shrine promotion/deletion job,
generic outbox consumer, or `OperatorSignUpFlow` expiry job. Those are classified F rather than
being inferred from filenames or future designs. Adding a new schedule requires a concrete producer,
idempotent domain operation, and a worker mapping first.

## Failure and operational rules

- Active Job retry is not exactly-once delivery. External logout, email, SMS, and push providers can
  receive a request before the client loses the response; delivery operations must remain safe for
  the existing provider contract and must not log tokens or message bodies.
- A request-time expiry or access restriction must not wait for a worker. The `SignUpExpiryJob` only
  catches up terminal state and cleanup after the domain operation has re-checked the row.
- A recurring purge is a bounded sweep, not permission to delete every table with a matching column.
  `RetentionPurgeJob` remains an explicit allowlist and is not expanded automatically.
- A queue or worker failure is observable through Solid Queue failed/stalled executions and the
  domain state or recovery sweep. It must not be “repaired” by marking a pending business row
  complete without doing the underlying work.
- The queue database has no application authority rows. A queue transaction is not a distributed
  transaction with a surface database; producer and recovery semantics must be designed from the
  durable application state.

## Verification and limitations

The explicit environment sections, worker-to-queue mapping, no wildcard/alias omission, recurring
entry shape, loadable class names, and effective job queues are verified by the Phase 0 static
configuration audit and the installed `bin/jobs check` command. They are intentionally not copied
into a Minitest configuration-construction case: the repository rule in
`adr/no-test-suite-for-environment-construction.md` requires operational setup to be established by
running it and recording the result in `evidence/`. The job tests cover the retention queue
assignment and the sign-up expiry operation. `bin/jobs check` is the installed Solid Queue 1.7.0
validation command and should be run for each deploy environment.

In the current worktree, bundled Ruby can load the PostgreSQL driver (`pg 1.6.3`). Rails tests
require `POSTGRESQL_TEST_HOST` and `VALKEY_KVS_HOST` from the environment contract, not
hand-exported `VALKEY_TEST_*` URLs. No development or production datastore was used as a fallback. Real worker
pickup, dispatcher movement, recurring scheduler enqueue, and external provider delivery therefore
remain unverified in this session; the evidence record names the exact failed preflight commands.

## Adding a job or queue

1. Identify the real producer, domain state, retry boundary, and owning database connection.
2. Choose `default` or `retention` only after considering delivery latency versus bounded
   maintenance work. Add a new queue only when the isolation requirement is demonstrated.
3. Add an exact worker entry for every supported environment, with explicit queue, threads,
   processes, and polling interval. Do not add a wildcard or YAML alias.
4. Add one explicit recurring entry only for a genuinely periodic process. Use the installed Solid
   Queue class/command schema and match the actual `perform` signature.
5. Add a public-boundary test for enqueue, success, retry/permanent failure, duplicate execution,
   and recovery where applicable. Add an isolated Solid Queue integration check before claiming
   worker execution.
6. Update this inventory, the relevant operational runbook, and an evidence file containing actual
   validation results.
