# WU-A4 XDB-14 APP Telephone OTP enqueue boundary

Date: 2026-11-01

HEAD: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`. The worktree had extensive pre-existing
uncommitted and untracked changes; 708 entries were present at the pre-evidence status check. No
commit was created.

The APP Telephone signup issuer now refuses an ambient Source or Ticket writer transaction before
OTP issuance. After issuance it checks the current parent, source, ceremony binding, generation and
code under the same locked authorization context used by delivery, then enqueues after those locks
are released. The actual SMS delivery job still performs the locked current-proof check immediately
before transport.

Verification:

- `UMAXICA_ENV_FILE=/home/global/workspace/.env.container.devcontainer PARALLEL_WORKERS=1 RUBYOPT=-W0 bin/rails test test/operations/sign_up_otp_delivery_concurrency_test.rb --name '/outer Source|queue refuses/'`:
  3 runs, 28 assertions, 0 failures/errors/skips.
- The same command without `--name`: 15 runs, 152 assertions, 0 failures/errors/skips. The queue
  callback asserted that neither writer transaction was open and read the newly issued generation
  through a distinct PostgreSQL backend before enqueue refusal.
- `UMAXICA_ENV_FILE=/home/global/workspace/.env.container.devcontainer PARALLEL_WORKERS=1 RUBYOPT=-W0 bin/rails test test/integration/telephone_signup_http_delivery_test.rb test/integration/telephone_sign_up_otp_delivery_test.rb`:
  10 runs, 0 assertions, 10 errors during fixture setup. PostgreSQL reported
  `client_authority_locks.client_id=980190963` missing from `clients`. This did not verify the
  HTTP/delivery cases; no cleanup was performed.
- Scoped RuboCop inspected four changed Ruby files with no offenses; `git diff --check` passed.

The first focused attempt exposed `connected_to` being called on a semantic abstract subclass
instead of its connection owner. The checks now use `Client.connection_class_for_self`; the focused
and full concurrency-file runs passed afterward.

No migration was run. No production or Neon database, external SMS provider, or full test suite was
exercised. Successful HTTP enqueue and actual transport remain unverified because the integration
test fixture setup failed.
