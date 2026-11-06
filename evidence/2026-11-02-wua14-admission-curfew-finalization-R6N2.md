# WU-A14 BL-19 Passkey termination curfew recheck

HEAD: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`. The worktree contained 546 changed tracked paths
and 265 untracked paths at the final snapshot; none were staged. Existing work was preserved. This
slice changed the sign-up controller concern and its regression test; no schema, migration or
persistent development data was changed.

The A06-6b Passkey-termination HTTP test reached the post-curfew sign-up finalization path and found
that `exit_attempt_after_curfew!` was called without its required Admission Binding. The controller
now strictly loads the sign-up Flow's binding and passes it to the existing curfew exit, which locks
and rechecks the binding before canceling the Auth ceremony. Missing binding state now raises
instead of being treated as an ordinary curfew miss. The concurrency test also re-raises worker
exceptions so a future failure retains its original stack trace.

Verification:

- Before the fix, the selected social and Passkey files produced 7 runs, 247 assertions and one
  Passkey termination failure. The isolated failure identified
  `AuthAdmissionCurfewGate#exit_attempt_after_curfew!` as the missing-keyword call site.
- After the fix,
  `PARALLEL_WORKERS=1 bin/rails test test/services/social_pending_client_termination_test.rb test/concurrency/sign_up_passkey_termination_http_test.rb test/integration/admission_curfew_test.rb`:
  15 runs, 307 assertions, 0 failures, 0 errors, 0 skips. This includes the real principal-lock wait
  crossing the curfew and confirms completed registration is retained without issuing a Root
  session.
- Scoped RuboCop reported no offenses. Ruby syntax checks and `git diff --check` passed.
- The full Rails suite was not run.
