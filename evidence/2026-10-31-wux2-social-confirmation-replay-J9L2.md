# WU-X2 repeated social confirmation probe

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`. The worktree contained uncommitted changes affecting the implementation and tests.
- Baseline: `PARALLEL_WORKERS=1 bin/rails test test/integration/social_login_admission_test.rb:272` passed (1 run, 42 assertions).
- A temporary extension replayed the Google confirmation PATCH after the first successful confirmation. The replay added no Client, external identity or token, returned 409 and left the Flow HALTED (status 930); the original journey's later identity-count assertion failed because the Flow could no longer finalize (1 run, 37 assertions, 1 failure). The extension was removed. One intermediate diagnostic run errored because the probe called a nonexistent method; it provided no behavioral evidence.
- The explicit step controller's existing phase-violation handling halts a bound Flow on a state-changing request for an earlier step. The probe did not establish Apple behavior, simultaneous confirmations or concurrent cleanup. The historical P2 definition allows a second confirmation to be refused; this probe does not establish the other A05-6 requirements.
- After removal, the same focused test passed again (1 run, 42 assertions, 0 failures, 0 errors, 0 skips).
