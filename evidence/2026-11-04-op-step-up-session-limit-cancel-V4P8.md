# O-10 session-limit cancellation lock order

- Commit: `b30345216886c98af1f04cbd434f067f12decf01`
- Worktree: extensively uncommitted; this implementation was part of the checked-out worktree.
- Date: 2026-11-04.

## Verification performed

`PARALLEL_WORKERS=1 bin/rails test test/services/base_auth_admission_cancellation_test.rb test/operations/session_limit_oidc_cancellation_committer_test.rb test/integration/oidc_rp_browser_flow_test.rb`
passed **20 runs / 275 assertions / 0 failures / 0 errors / 0 skips**.

`PARALLEL_WORKERS=1 bin/rails test test/integration/oidc_initiated_sign_in_completion_test.rb:759 test/integration/sign_entry_exit_org_flow_test.rb test/integration/admission_curfew_test.rb test/operations/oidc_step_up_authorization_cancellation_committer_test.rb`
passed **16 runs / 223 assertions / 0 failures / 0 errors / 0 skips**.

`PARALLEL_WORKERS=1 bin/rails test test/security/invariants/lifecycle_direct_state_write_invariant_test.rb test/unit/security/forbidden_rails_patterns_test.rb`
passed **7 runs / 13 assertions / 0 failures / 0 errors / 0 skips**. Scoped RuboCop passed for the
four changed/new operation/controller/test files. The coordinator passed scoped RuboCop with its two
pre-existing offenses in `create_or_reuse_binding!` (MethodLength and PerceivedComplexity) excluded.
`git diff --check` for the tracked changed service/controller/inventory files passed.

The APP independent-connection test proves the OIDC parent row remains lockable while the worker
waits for the actor lock; the new operation test also covers successful APP and ORG cancellation
bindings. This does not establish the full reverse-lock graph: ORG's independent-connection race and
other caller-held-lock paths remain open. The latest post-switch regression result is recorded
separately in `evidence/2026-11-04-op-step-up-lock-and-regression-rerun-J6N4.md` and was not rerun
for this change.

The Rails test runner used the configured test databases. No development or production database was
accessed or modified.
