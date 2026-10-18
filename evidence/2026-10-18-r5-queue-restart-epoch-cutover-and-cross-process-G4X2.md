# R5: real-worker queue restart, contract-epoch cutover rehearsal, cross-process feasibility

- Date: 2026-10-18 UTC. Commit `17903f7d121aa33efe29f2db9235c9aa5db4b001`; the uncommitted R1-R5
  worktree is present and the epoch fix below is part of it.
- Environment: `RAILS_ENV=test`, isolated fleet `20261017c1a2` (32 databases, PostgreSQL 18.6,
  `10.89.0.3/32:5432`) with its manifest-derived `POSTGRESQL_TEST_PREPARE_DATABASES`.
- R5-WU03A is stopped by user decision; nothing here touches roles or credentials.

## 1. Stopped-Queue restart against a real Solid Queue worker (TC-R5-09-001 / 10-001)

Setup by `bin/rails runner`: one committed `OpLogoutCommitter` flow for `core-app-jp`, its outbox
row (id 96) redirected to `https://core-jp.invalid/oidc/backchannel-logout`, and a stale lease
(attempts 1, lease 20 s ahead) standing in for a worker that crashed mid-send. One
`OpOutboxDispatchJob` was enqueued while no worker ran. The registered endpoint
(`https://jp.umaxica.app/...`) resolves to a public host; the `.invalid` redirect kept every
delivery attempt off the network. Boot-time configuration refuses loopback and `.invalid` hosts, so
the row was changed rather than the environment.

| Step                                                                                          | Observation                                                                                |
| --------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------ |
| `bin/jobs` started (5 processes)                                                              | queued job finished; row untouched under the live lease (attempts 1)                       |
| lease expired, job enqueued                                                                   | row reclaimed: attempts 2, `transport_failure`, backoff `next_attempt_at`, not completed   |
| `kill -KILL` of the whole worker process group, job enqueued while down, `bin/jobs` restarted | job ran after restart: attempts 3, `transport_failure`, not completed, 0 failed executions |

Cleanup: outbox row, participant, receipt, flow, Grant, root token, device session, the dispatch
jobs and the five dead process registrations were deleted; outbox and flow counts returned to 0.
`test/jobs/op_outbox_dispatch_job_test.rb` and `test/operations/op_logout_committer_test.rb`
afterwards: 13 runs, 63 assertions, 0 failures.

Not shown: an acknowledged delivery through real HTTPS (no reachable registered endpoint), and the
development recurring schedule (the test environment has no recurring tasks; jobs were enqueued by
hand in the scheduler's place).

## 2. Contract-epoch cutover rehearsal (TC-R5-19-001, adapted)

Defect found: OP Refresh did not compare the Grant's `contract_epoch` with the realm's current
epoch, so a pre-R5 Grant (NULL) or a Grant from an older epoch rotated and received Access stamped
with the current epoch, contrary to `one.md` section 6.3. The new test in
`test/services/oidc/token_exchange_service_test.rb` failed before the fix
(`Expected "invalid_grant", Actual nil`). `OidcTokenExchangeCoordinator#exchange_refresh_token!` now
refuses with `invalid_grant` unless the Grant epoch equals the current one; the refused Grant is not
modified.

Fourteen existing test files built current-profile Grants without `contract_epoch` and failed after
the fix (30 failures across 3,753 runs). Their setups now state the current epoch explicitly; no
application default was added. Those 14 files: 1,493 runs, 0 failures.

RP side: a new case in `test/services/rp_request_authenticator_test.rb` refuses a validly signed
Access JWT without `umx_contract_epoch`, and an epoch-1 token after the cell moved to epoch 2, also
when the local session row is forged to epoch 2 (8 runs, 0 failures).

Residual: an authorization-code exchange from a root with a NULL or older `contract_epoch` still
creates a Grant at the current epoch. Roots are not compared because most test roots and the
pre-cutover data cutoff are handled by the 19-COMMON batch; this remains open.

## 3. Cross-process paused-after-OP-commit Refresh race (TC-R5-07-003): NOT_RUN

`OidcIssuer.token_endpoint("client")` is `https://www.umaxica.app/oauth/token`, which resolves to
the development ingress (10.89.2.4). That ingress fronts the development OP on development
databases, not a process on the isolated fleet, and pausing an OP process after its commit would
require test-only code in the application. The case was not run.

## Full suite

- First run, `bin/rails test --seed 42061`, 8 workers: 15,528 runs, 10 failures, 6 errors, all in
  Passkey slot tests. An unrelated, unintended Passkey registration-slot change (three models, two
  new files, three empty migrations recorded in the fleet's `app_zenith` `schema_migrations`) had
  been written to the worktree during this work. At the user's request it was rolled back: models
  restored with `git restore`, new files removed, the three version rows deleted from the isolated
  fleet. The development database had none of them. A backup was kept outside the repository.
- Second run, same command: 15,528 runs, 132,444 assertions, 1 failure, 0 errors:
  `OpOutboxDispatchJobTest` "a delayed failed worker leaves a newer live lease ..." compared Float
  epoch seconds with a one-microsecond delta and observed 1.19e-6. It passed alone three times. The
  assertion now compares the time truncated to the stored microsecond precision; the file passed
  five consecutive runs. The full suite was not re-run after this test-only change.
