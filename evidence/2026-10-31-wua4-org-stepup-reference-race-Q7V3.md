# APP and ORG Step-Up admission parent-reference race

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`. The worktree had substantial uncommitted changes affecting the tested implementation.
- The existing non-transactional admission race was extended from APP to ORG. In each case an independent worker was observed blocked on the original parent while another connection replaced the session's parent reference. Admission returned `session_binding_mismatch`, retained the new reference and left both parents pending.
- `PARALLEL_WORKERS=1 bin/rails test test/concurrency/base_step_up_admission_reference_race_test.rb test/operations/base_step_up_admission_issuer_test.rb test/controllers/auth/step_up_admission_test.rb`: 26 runs, 411 assertions, no failures, errors or skips. Scoped RuboCop passed after formatting.
- The replacement is a synthetic competing write. This does not establish that production exposes such a writer, nor does it cover all cancellation, nested transaction, or other Step-Up races. No production code was changed and no full suite was run in this check.
