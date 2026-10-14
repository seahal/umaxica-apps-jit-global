# First-party RP completion URI matrix

Recorded 2026-10-13 against full commit `aa92265b7e63bf874fddd0aa8f278d5ed19de6b5`, branch
`feature`. The worktree had extensive unrelated staged, unstaged and untracked changes. This record
covers the first-party Browser RP completion continuation and the associated strict-loading repair.

The user's approved URI update is applied to all 12 first-party client registrations: each uses its
own host's `/sign/out/completion?ri=jp` and `?ri=us` destinations. The Rails integration matrix
starts from same-realm parent and RP-session revocation, verifies that challenge GET does not advance
the transaction, submits the protected POST with the rendered Rails token, and checks one-shot final
notice behavior. It covers all 12 client IDs, HTML and Inertia response forms at `ri=jp`, and exact
registration/route entries at both allowed `ri` values. The user's stricter Base/Auth CSRF decision
is reflected: unsafe requests require the Rails token even when Fetch Metadata is same-origin.

The matrix exposed `RpSessionRevoker` dereferencing `current_refresh_token` while strict loading was
enabled. Its current-token lookup now uses each supported realm's explicit token foreign key and
device-session ID, and raises for an unsupported Device Session class. The public operation tests
and the integration matrix pass through that lookup.

Verification used the ordinary Rails `test` database configuration. The environment variable
`POSTGRESQL_ISOLATED_TEST_RUN_ID` was unset, the Rails test database manifest listed only
`test_*` databases, and no database reset or migration was run.

The focused Rails command was:

```sh
env -u POSTGRESQL_ISOLATED_TEST_RUN_ID RAILS_ENV=test PARALLEL_WORKERS=1 bin/rails test \
  test/values/oidc_client_registry_test.rb \
  test/values/auth_boundary_authority_map_test.rb \
  test/values/regional_rp_client_matrix_test.rb \
  test/services/acme_logout_transaction_coordinator_test.rb \
  test/services/oidc/client_registry_test.rb \
  test/integration/routes/sign_out_oneshot_contract_test.rb \
  test/integration/oidc_rp_authority_first_logout_test.rb \
  test/integration/oidc_rp_completion_matrix_test.rb \
  test/operations/rp_session_revoker_test.rb \
  test/controllers/core/app/sign/outs_controller_test.rb \
  test/controllers/core/com/sign/outs_controller_test.rb \
  test/controllers/core/org/sign/outs_controller_test.rb \
  test/controllers/warp/app/sign/outs_controller_test.rb \
  test/controllers/warp/com/sign/outs_controller_test.rb \
  test/controllers/warp/org/sign/outs_controller_test.rb \
  test/controllers/base/app/sign_outs_controller_test.rb \
  test/controllers/base/com/sign_outs_controller_test.rb \
  test/controllers/base/org/sign_outs_controller_test.rb \
  test/controllers/palm/app/sign/out/completions_controller_test.rb \
  test/controllers/tech/org/sign/out/completions_controller_test.rb
```

Result: **147 runs, 1,701 assertions, 0 failures, 0 errors, 0 skips**. The static guard command was:

```sh
env -u POSTGRESQL_ISOLATED_TEST_RUN_ID RAILS_ENV=test PARALLEL_WORKERS=1 bin/rails test \
  test/security/invariants/csrf_verification_strategy_invariant_test.rb \
  test/security/invariants/lifecycle_direct_state_write_invariant_test.rb \
  test/unit/security/standard_csrf_invariant_test.rb \
  test/unit/security/identity_authority_inversion_guard_test.rb
```

It passed with **16 runs, 117 assertions, 0 failures, 0 errors, 0 skips**.
`bin/rubocop app/operations/rp_session_revoker.rb test/integration/oidc_rp_completion_matrix_test.rb
test/operations/rp_session_revoker_test.rb` reported **3 files inspected, no offenses**.
`bin/rails routes | rg '/sign/out/completion'` listed **12 host-local GET routes and 12 host-local
POST routes**. `git diff --check` passed.

The checks do not execute the full IdP authority flow or real-browser/manual acceptance. They do not
verify the global parent-and-all-RP transaction, first-party BCL removal, or production behavior.
Those gates remain open; Steps 15 and 18 are incomplete, and Step 19 remains gated by Steps 5, 6, 8
and outstanding Step 17 evidence. The frozen `one.md` and `two.md` were not changed.
