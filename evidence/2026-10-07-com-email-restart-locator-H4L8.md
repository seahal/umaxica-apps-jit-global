# COM email restart locator

Commit: `6fa6867d44b5499632079775cb0fb22cbfddd339`. The worktree contains substantial inherited uncommitted changes and this local fix. Runs used the task-owned `20261006fresh1` disposable PostgreSQL manifest, one Rails process at a time.

- The restart HTTP regression failed before the fix: 1 run, 11 assertions, 1 failure, no errors or skips (seed 17796, preceding continuation). The predecessor remained CONTACT_PENDING instead of HALTED.
- Root cause: `enforce_email_flow!` called `reset_email_flow!`, clearing the durable locator before `create` called `supersede_active_sign_up_flow!`.
- After preserving that locator for create, `bin/rails test test/controllers/auth/com/up/emails_controller_test.rb -i /create_keeps_re-registration_inside/` passed: 1 run, 15 assertions, no failures, errors or skips, seed 26666. This verifies distinct flow IDs, predecessor halt, replacement nonterminality and stale signed-screen refusal without replacement mutation.
- The same file with the restart, authentication-copy, existing-binding, wrong-code and expired-session name filters passed: 5 runs, 69 assertions, no failures, errors or skips, seed 27341.
- `bin/rails test test/services/sign_up_termination_idempotence_test.rb test/services/sign_up/state_machine_test.rb test/services/sign_up_expiry_race_test.rb` passed: 22 runs, 71 assertions, no failures, errors or skips, seed 17140.
- Scoped RuboCop on the COM email controller and its test passed: 2 files, no offenses.
- Whole-worktree `git diff --check` failed on existing final blank lines in `db/search_structure.sql` and `db/storage_structure.sql`. Those dumps were not changed in this increment.

Updated the visitor signup and email-registration-session diagrams and transition inventory. No migration, new status, GET-side halt, recovery-distribution change or task checkbox completion. Full-suite and Final Verification remain outstanding.
