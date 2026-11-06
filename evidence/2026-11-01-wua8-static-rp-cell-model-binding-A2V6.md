# WU-A8 static RP-cell model binding

Work was performed against full HEAD `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`. The worktree had
659 staged, unstaged, or untracked entries before this evidence file was added. No commit,
migration, production/Neon operation, or external network request was made.

`RpRequestAuthenticator` now selects each of the nine fixed RP record/session model pairs from a
closed static map keyed by the trusted `RpCellBinding` connection. It no longer constructs model
constants from a record-prefix string or calls `constantize`. Unknown connection keys raise through
`Hash#fetch`.

Using the explicit local Preference COM JWT process settings,
`test/services/rp_request_authenticator_test.rb` passed (8 runs, 17 assertions, 0 failures, 0
errors, 0 skips). `test/integration/rp_cell_local_session_readiness_test.rb` passed (20 runs, 307
assertions, 0 failures, 0 errors, 0 skips), including the nine configured RP-cell journeys. Scoped
RuboCop, Ruby syntax, and `git diff --check` passed.

This verifies the local nine-cell test harness and static model selection. It does not establish
deployed RP processes or close WU-A8's remaining RuntimeRole, Base management/Step-Up, and
shared-role contract gaps. No full suite was run.
