# WU-A3 public Cancel and Switch recheck

HEAD: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`. The worktree contained existing uncommitted
changes, including the scoped test updates; no staged changes were present. The worktree was kept.

Ran the focused public contract selection with `.env.container.devcontainer` loaded and
`PARALLEL_WORKERS=1`:

`bin/rails test test/integration/sign_entry_exit_flow_test.rb test/integration/sign_entry_exit_org_flow_test.rb test/integration/acceptance_wua3_initial_attach_race_test.rb test/controllers/auth/verification_cancellations_controller_test.rb test/controllers/auth/ceremony_admission_boundary_test.rb test/integration/oidc_initiated_sign_in_completion_test.rb:65 test/controllers/auth/app/in/secrets_controller_test.rb:88`

Result: 57 runs, 1,310 assertions, 0 failures, 0 errors, 0 skips. The selection covers APP/ORG
Cancel and APP Switch, the AC-53 initial `auth_sid` race, cancellation/continuation boundaries, APP
Visa Cancel replay, and APP Secret Back without state change. The added ORG Cancel replay test also
passed separately: 1 run, 16 assertions, 0 failures, 0 errors, 0 skips.

The selection emitted the existing NanoID frozen-string warning. This is a focused public-boundary
recheck, not full-suite or deployment evidence, and does not alone close WU-A3 or `two.md`.
