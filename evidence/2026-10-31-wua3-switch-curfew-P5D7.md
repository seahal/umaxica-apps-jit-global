# WU-A3 Switch handoff curfew

HEAD: `336811e5072a93c0523e484f905082635b28f48f`. Staged, unstaged and untracked worktree
changes affected the run. Tests used local test databases; production and Neon were not targeted.

The public `issue_switch_handoff!` boundary accepted a handoff at the original admission curfew
when the parent transaction remained valid. A new test using an actual redeemed binding and the
OP database-clock seam failed at equality before the change. The implementation now refuses a
missing deadline and any issuance at or after it, while still capping an earlier handoff at the
original deadline. The focused test passed for one second before, at, and one second after the
curfew: 1 run, 4 assertions.

`PARALLEL_WORKERS=1 bin/rails test test/services/admission_binding_deadline_intent_test.rb
test/integration/sign_entry_otp_admitted_order_test.rb test/services/base_auth_admission_coordinator_test.rb`
passed: 36 runs, 262 assertions, no failures, errors or skips. RuboCop reported no offenses in the
changed Ruby files; scoped `git diff --check` passed. This change does not implement the separate
switched binding state or establish all WU-A3 acceptance.
