# WU-A3 Switch handoff receipt clock

HEAD: `336811e5072a93c0523e484f905082635b28f48f`. Staged, unstaged and untracked worktree
changes affected the run. Tests used local test databases; production and Neon were not targeted.

A Switch handoff issued before the original admission curfew was still accepted by
`read_switch_handoff!` at the curfew when the OP database clock had advanced but the Rails clock
had not. The expanded public API test failed before the change. Handoff receipt now compares its
expiry against the owning transaction database clock. The test covers receipt and issuance one
second before, at and after the curfew; it also verifies that an attempted replacement admission
at or after the curfew is refused as expired without adding a binding.

`PARALLEL_WORKERS=1 bin/rails test test/services/admission_binding_deadline_intent_test.rb
test/integration/sign_entry_otp_admitted_order_test.rb test/services/base_auth_admission_coordinator_test.rb`
passed: 36 runs, 273 assertions, no failures, errors or skips. RuboCop reported no offenses in the
changed Ruby files after a formatting-only correction; scoped `git diff --check` passed. This does
not establish all WU-A3 acceptance or implement the switched binding lifecycle.
