# Passkey registration owner availability

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree contained uncommitted changes affecting this result.
- The new focused case initially failed because the common registration operation accepted an unavailable owner. The operation now checks `login_allowed?` after acquiring the owner lock and before saving the Passkey or audit event.
- The focused APP/ORG case passed with reserved and withdrawn owners (1 run, 16 assertions); no credential or source audit row was created. An APP signup case verifies that an owner in `UNVERIFIED_WITH_SIGN_UP` can still register.
- Registration operation, APP/ORG finalizer, audit delivery and registration-writer invariant files passed together: 47 runs, 274 assertions, 0 failures, 0 errors. An initial attempt at this group named a nonexistent finalizer test file and did not run the tests; the corrected file name was used for the reported result.
- `test/operations/passkey_registration_operation_concurrency_test.rb` passed (2 runs, 7 assertions). In the added APP race, a separate connection waited on the owner lock until the owner became reserved, then registration refused without creating a key or audit row. An equivalent ORG independent-connection race was not run.
- RuboCop inspected the operation and both edited test files with no offenses; scoped `git diff --check` passed. The full suite and deployed behavior were not verified in this slice. Direct SQL insertion protection and the WU-A5 slot schema remain open.

## ORG independent-connection follow-up

- At the same HEAD with a dirty worktree, the prior APP race passed alone (1 run, 4 assertions). An additional ORG test then held an Operator row lock, committed a transition to reserved while a registration connection waited, and observed refusal without a Passkey or audit event.
- `PARALLEL_WORKERS=1 bin/rails test test/operations/passkey_registration_operation_concurrency_test.rb`: 3 runs, 11 assertions, 0 failures, 0 errors. RuboCop and scoped `git diff --check` passed for the edited test file.
- This supersedes the earlier statement that the ORG race was untested. Other transition types, HTTP callers, direct SQL insertion and deployed behavior remain unverified.
