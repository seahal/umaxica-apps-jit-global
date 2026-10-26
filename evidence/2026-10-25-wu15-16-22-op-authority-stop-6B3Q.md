# WU-15, WU-16 and WU-22 local implementation

Date: 2026-10-25  
Full git commit: `bde2346c17e2aa911acc95de1f6035f80498f2da`  
Worktree: uncommitted changes were present. `git status --short` showed 621 paths at the end of this work; 620 were already present at the start of this continuation. No changes were staged by this work. Unrelated work was preserved.

## Implemented

- WU-15: the three OP realm stores write durable participant rows; `OpOutboxDispatchJob` and the recurring sweep dispatch/recover them; the sender validates and pins public DNS addresses and does not follow redirects; all twelve RP cells expose `POST /oidc/closures`. Receiver behavior includes signature/issuer/audience/claim checks, JWKS outage handling, per-`sid` tombstones, callback ordering and preservation of a newer session.
- WU-16: `OpAuthorityStopCommitter` owns OP root and grant revocations, validates the cause/scope and authority evidence, takes the agreed locks, writes stop/target/cutoff/participant/browser receipt rows, is idempotent, and enqueues dispatch after commit. Identity invalidation and risk actor-side event ordering route into this boundary. Static guards enforce the single-writer rule.
- WU-22: realm-specific stop schemas and sign-out models express required associations; restrictive target foreign keys preserve history; physical purge is child-first and waits for root retention and final participants. Mermaid lifecycle inventory and the WU status descriptions were updated.
- Nontransactional session-limit tests now watermark and clean stop rows created by each test. Parent sign-out tests expect one durable dispatch job for each tested principal stop.

WU-44/30/38 were not changed. This implementation does not close G-16 or the D-166/A44-1/A44-2 prerequisites, and does not establish browser or external-RP acceptance.

## Verification performed

- Focused logout, receiver, outbox, identity invalidation, stop committer/purger, concurrency, static invariant and protocol suites: **199 runs, 1,055 assertions, 0 failures, 0 errors**.
- Supplementary outbound adapter, RP callback/session revoker, client registry, receiver-gating and cookie-purge suites: **59 runs, 324 assertions, 0 failures, 0 errors**.
- Latest delayed-logout / early-tombstone receiver and RP callback suites: **20 runs, 80 assertions, 0 failures, 0 errors**.
- `bin/rubocop` over 86 touched authority-stop, logout, receiver, migration, support and test files: **86 inspected, no offenses**.
- `bin/rails db:schema:dump:op_base_app`, `bin/rails db:schema:dump:op_base_com` and `bin/rails db:schema:dump:op_base_org`: each exited successfully after the migration refactor.
- The focused 199-run command covered `test/controllers/concerns/authentication/logout_all_sessions_test.rb`, `logout_current_session_test.rb`, `logout_resolver_round_trip_test.rb`, `test/controllers/tech/org/oidc/callbacks_controller_test.rb`, `test/integration/rp_backchannel_logout_receiver_test.rb`, `rp_backchannel_logout_jwks_outage_test.rb`, `test/jobs/op_outbox_dispatch_job_test.rb`, `test/models/rp_session_test.rb`, `rp_session_retirement_window_test.rb`, `test/operations/op_authority_stop_committer_test.rb`, `op_authority_stop_purger_test.rb`, `op_identity_event_invalidator_test.rb`, `rp_session_revoker_test.rb`, `rp_refresh_logout_concurrency_test.rb`, `test/services/oidc_refresh_token_issuer_result_test.rb`, `oidc_token_exchange_boundary_test.rb`, `oidc_token_revoker_surface_lookup_test.rb`, `oidc_access_jwt_child_revoke_independence_test.rb`, `test/concurrency/op_authority_stop_concurrency_test.rb`, the authority-stop and lifecycle single-writer guards, and the related CSRF, identity inversion and WebAuthn invariant suites. It ran with `PARALLEL_WORKERS=1`.

## Failures and limits

- A broader cause-writer regression command reported **63 runs, 93 assertions, 5 failures and 45 errors**. The parent sign-out cases still expected no dispatch job under the previous outbox contract; those assertions have since been updated but could not be rerun. Fixture setup errors reported a foreign-key violation in `op_app_authority_stop_root_targets` for root id `980190963`.
- After adding cleanup for newly created stop records, rerunning `test/models/session_limit_resolution_transactionable_test.rb` produced **19 setup errors before assertions** because the same old stop-target row remains in the existing test database. A read-only query found stop 509 targeting root id `980190963`; the base test database still has that fixture-key token outside fixture loading. During fixture reload, the parent row is removed while the stale target is retained, so PostgreSQL rejects fixture FK revalidation.
- `test/support/parallel_test_database_cloner.rb` documents that committed tests can leave rows behind and that resetting a dirty ordinary test database requires explicit authorization. No test database reset or direct row deletion was performed. The edited cleanup and updated parent job expectations therefore remain unverified against a clean test database.
- A prior exploratory Base-host sign-in test returned 404 at the token endpoint after Visa separation (WU-02); it is outside this WU scope. WU-14/G-16 and A44-1/A44-2 were not run or changed. No full-suite run, browser E2E, deployment, or external RP test was performed.

## Commands represented

The focused Rails suite used `PARALLEL_WORKERS=1 bin/rails test` on the file list above. The two new receiver ordering cases were run with `test/integration/rp_backchannel_logout_receiver_test.rb`, `test/operations/rp_cell_session_revoker_test.rb` and `test/operations/rp_callback_committer_test.rb`. Schema dumps used the three commands listed above. RuboCop was run on 86 scoped Ruby files, including all authority-stop models/operations/migrations and the edited tests/support files.
