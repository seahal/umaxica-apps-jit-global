# Warp Com Preference Adoption: Partial Verification

- Revision: `aa92265b7e63bf874fddd0aa8f278d5ed19de6b5`, branch `feature`.
- The worktree contained extensive uncommitted changes, including Preference Registry migration,
  Xper retirement, and `config/environments/test.rb` changing strict loading from
  `:n_plus_one_only` to `:all`. These changes affected the results below.
- Outcome: PARTIAL. The include correction is present; successful Warp Com synchronization has
  not been established. Assertions were preserved, and failing behavior was not reported as success.

## Local change and preservation

- Added `include ::PreferenceAdoption` immediately after `PreferenceGlobal` in
  `app/controllers/warp/com/application_controller.rb`, matching Warp App and Org.
- Added `test/integration/warp_com_preference_adoption_test.rb` with HTTP checks for mirror creation
  and stored-value equality, existing explicit theme restoration, anonymous requests, parent-only
  authentication refusal, invalid preference credentials, and mirror persistence failure propagation.
- The original three Warp sign-out test files are byte-for-byte identical to saved pre-edit copies.
- SHA-256 comparison of previously dirty files found no content changes to those files. No shared
  Concern, model, migration, credential transport, Xper, or other surface implementation was edited.
- `ruby -c` on both changed Ruby files: Syntax OK. `git diff --check`: exit 0.

## Executed comparison

The following command ran with the include absent, and again with it present:

```sh
PARALLEL_WORKERS=1 bin/rails test test/integration/warp_com_preference_adoption_test.rb test/controllers/warp/app/sign/outs_controller_test.rb test/controllers/warp/com/sign/outs_controller_test.rb test/controllers/warp/org/sign/outs_controller_test.rb
```

- Before: seed 54933; 21 runs, 130 assertions, 6 failures, 0 errors, 0 skips.
- After: seed 52902; 21 runs, 130 assertions, 6 failures, 0 errors, 0 skips.
- Both runs used the initial five-case version of the new integration test. Its association reads
  explicitly eager-load the option records; an earlier diagnostic run had a test-side strict loading
  error, which was corrected without changing the expected values.
- All three original mirror-creation tests failed with a nil actor-local preference, rather than a
  setup exception. The new Com creation, explicit theme restoration, and failure-propagation cases
  also failed. Anonymous and malformed preference-refresh refusal cases passed.
- The other original sign-out cases passed: 303 authority launch, parent/RP session preservation,
  and the existing confirmation and notice boundaries. This does not verify completed sign-out's
  safe-copy behavior.
- After-run adoption log entries confirmed `ActiveRecord::StrictLoadingViolationError` on
  `Client#user_preference`, `Operator#staff_preference`, and `Visitor#visitor_preference`.
  `PreferenceAdoption#find_resource_preference` accesses these associations lazily;
  `adopt_preference_for!` rescues `StandardError`, logs `preference.adoption.error`, and continues.
  `adopt_rotated_preference!` also rescues `StandardError`. Neither was changed.

## HTTP path and limitations

The normal inherited callback on a cookie-less authenticated `POST /sign/out` creates the browser
preference and calls `PreferenceTransport#restore_preference_from_resource!` before the action
launches the OIDC logout transaction. The transaction launcher itself does not perform preference
adoption or logout safe-copy. The original tests exercise bootstrap, but only assert mirror presence
and cannot establish value equality or isolate the include defect from shared adoption failures.
The Warp theme API skips `set_preferences_cookie` and uses independent dual-write behavior, so it
would not isolate this include correction.

After the comparison, the new test setup was aligned with the original Com root-refresh setup;
an ordinary landing GET was added to confirm RP authentication, and a parent-only credential refusal
case was added. The final six-case test version has passed syntax checking but has not executed.

## Blocked executions

- The first sandboxed Com command failed resolving database host `primary`.
- Escalated commands connected to the configured test databases but waited in
  `ParallelTestDatabaseCloner.acquire_test_process_lock!` at line 87. `lslocks` identified another
  Ruby process owning `tmp/parallel-test-databases.lock`. Only this task's waiting commands were
  interrupted; the owner was left intact.
- A 16-worker attempt failed before cases ran with `PG::ObjectInUse`: another session was using
  template database `test_org_zenith_db`. The existing `PARALLEL_WORKERS=1` setting permitted the
  executed comparison above without changing test infrastructure.
- A subsequent single-worker run containing the final Warp tests and existing integration tests
  again waited on the existing process lock and was interrupted before cases ran. Its extra targets
  were `preference_adoption_on_sign_in_test.rb`, `preference_rotation_adoption_test.rb`,
  `preference_logout_downgrade_test.rb`, `preference_credential_recovery_matrix_test.rb`, and
  `preference_signed_in_dual_write_test.rb` under `test/integration/`.
- Completed logout safe-copy, broader dual-write/rotation behavior, and App/Org preference value
  equality remain unverified in this session.

## Deferred contract conflict

`adr/preference-relogin-reconciliation-record-recency.md` accepts a parent-record-recency winner.
The current `PreferenceAdoption#reconcile_preference_key!` implements explicit-field and per-key
reconciliation. This conflict was identified and left unchanged as requested. Shared adoption's
strict-loading incompatibility and exception swallowing also require work outside this limited scope.
