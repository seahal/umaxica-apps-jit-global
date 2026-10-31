# WU-7 full-suite candidate isolation

HEAD: `336811e5072a93c0523e484f905082635b28f48f`. Staged, unstaged and untracked worktree changes
affected the tests. The local test environment was used; production and Neon were not targeted.

After the full-suite name comparison in `2026-10-31-wu7-display-cookie-log-P8N4.md`, ran
`PARALLEL_WORKERS=1 bin/rails test test/controllers/auth/app/up/emails_controller_test.rb:1719
test/controllers/auth/app/sign_up_csrf_failure_test.rb:21 test/integration/social_link_unlink_test.rb:155`.
The three cases produced 21 assertions, one failure, no errors and no skips. The CSRF and social
unlink cases passed in this selection; the leap-day signup case still returned 400 instead of the
expected success.

The leap-day case starts its signup flow at the current clock and then travels to 2024-02-29 before
requesting the birthdate page. The run date was 2026-10-31. This observation suggests a temporal
ordering issue but does not establish its cause or whether the failure is related to WU-7. The
full-suite zero-baseline-external-failures condition remains unverified.

A later file-isolated run of
`PARALLEL_WORKERS=1 bin/rails test test/controllers/auth/app/sign/up/check/email/birthdates_controller_test.rb`
passed: 13 runs, 335 assertions, no failures, errors or skips. Four date-related candidate names
from the full run belong to this file and did not reproduce in this file-isolated execution. The
original full-suite seed was 51870. This supports investigating cross-test state or ordering but
does not identify a responsible test or establish full-suite success.

A subsequent experiment moved the leap-day clock change before the test's first signup request.
The selected case then errored before assertions: `initial Email signup challenge was refused`
from the Email signup controller. That experimental edit was reverted. Moving the Rails clock
alone is therefore not a verified repair; the actual failure remains unresolved.
