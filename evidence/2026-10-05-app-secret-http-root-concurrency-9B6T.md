# HTTP root completion and confirmation/claim concurrency

Observed 2026-10-05 UTC, through 15:20:28+00:00, against HEAD
`e8f2371bc5cbefd2087c728aeeef4e318463d33f` with uncommitted changes.
Used the guarded `codex_integrity_20261005recovery_*` PostgreSQL 17.7 fleet.
No shared database application, full suite or browser E2E run occurred.

The new case in `ClientSecretStorageConfirmationConcurrencyTest` uses public
reservation, candidate preparation and protected presentation, then real admitted
browser flow/ceremony creation. A pre-confirmation claim is refused. Queue barriers
race confirmation and claim on separate Source writer connections. If the early
claim misses the not-yet-committed confirmation, a subsequent normal claim is
accepted. Reconfirming that exact issuance preserves the claim and does not
restore eligibility. One declaration and one claim are persisted; A=R=0 after
claim, and this operation itself creates no receipt or session.

`AppSecretRootLoginConcurrencyTest` was created through the Rails integration-test
generator; its placeholder was removed. It uses actual Base entry HTTP, verified
jump JWT, Auth admission, Secret POST and handoff. CSRF is enabled, and only the
external Turnstile boundary is stubbed. It does not mock login or call private
controller methods. The initial management token's scoped Step-Up is a setup
fact; the new root token under test is issued exclusively by Base HTTP.

Two copies of the legitimate pre-completion browser submit the same result
concurrently on distinct PostgreSQL connections. The result is one 303, one 409,
one new usable root token, one matching receipt and one browser receiving the
login cookie. Cancellation and expiration cases wait for `pg_blocking_pids` to
prove that a pending HTTP callback is behind the Client lock before the public
Ticket transition is committed. After release, the blocked callback returns 400;
a second stale callback returns the existing authorization-denial 302 to `/`.
The test follows that redirect to the 200 guest landing page and verifies no
new token, receipt, login cookie or Secret reuse. Explicit claim finalization
records abandonment without consumption or resurrection.

Commands start with `bundle exec ruby /tmp/umaxica-secret-recovery-db-task.rb`:

- `test test/operations/client_secret_storage_confirmation_concurrency_test.rb`:
  seed 19739, **3 runs, 31 assertions, no failures/errors/skips**, 0.888851 seconds.
- Root-test generator: `generate integration_test app_secret_root_login_concurrency`,
  exited 0, generated only the integration-test file.
- Initial HTTP arrangement tried three Source connections against the existing
  two-connection pool: seed 6779 timed out; seed 49224 surfaced the pool checkout
  error. The revised arrangement preserves the configured pool: two simultaneous
  completions, or one observer plus one blocked terminal callback followed by the
  second stale callback. No application/test environment configuration changed.
- Focused root completion: seed 16119, 1 run, 11 assertions, no failures/errors/skips.
- First full root file: seed 65528, 3 runs, 15 assertions, 2 failures because the
  terminal follow-up used the existing 302 authorization handler rather than the
  anticipated 400. A focused diagnostic, seed 11032, confirmed `/` as the redirect
  path. Added redirect traversal, cookie checks and persisted issuance/receipt/
  claim assertions instead of changing production responses or only replacing
  status expectations.
- Final `test test/integration/app_secret_root_login_concurrency_test.rb`:
  seed 57833, **3 runs, 35 assertions, no failures/errors/skips**, 2.327583 seconds.
- RuboCop: confirmation file passed; root file formatting offenses corrected,
  final one-file run passed. `git diff --check` exited 0.

This proves these local-flow races and the confirmation/claim boundary. It does
not prove concurrent OIDC cancellation versus root issuance, every crash boundary,
current DDL reconstruction or live-owner replay-barrier collection. The separate
issuance-authority shape proposal remains pending; the overall goal stays active.
