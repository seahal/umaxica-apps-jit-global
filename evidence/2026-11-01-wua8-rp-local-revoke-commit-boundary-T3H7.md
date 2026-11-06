# WU-A8 RP local revoke commit boundary

Work was performed against full HEAD `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`. The worktree had
657 staged, unstaged, or untracked entries before this evidence file was added. No commit,
migration, production/Neon operation, or live RFC 7009 request was made.

Updated the Core APP RP-cell sign-out integration case to inject an `ActiveRecord::StatementInvalid`
after the local session update has run inside its transaction and before that transaction commits.
The request returned HTTP 503; the transaction rolled the local session update back; all three RP
credential cookies remained; and the RFC 7009 adapter was not called. A later uninjected request in
the same case completed the logout handoff.

`PREFERENCE_COM_JWT_ISSUER=https://www.umaxica.com PREFERENCE_COM_JWT_AUDIENCE=com PREFERENCE_COM_JWT_REVOKED_KIDS='' bin/rails test test/integration/rp_cell_local_session_readiness_test.rb:60`
passed before the change (1 run, 33 assertions) and after the change (1 run, 33 assertions). The
whole file passed after the change (20 runs, 305 assertions, 0 failures, 0 errors, 0 skips).
`bundle exec rubocop test/integration/rp_cell_local_session_readiness_test.rb` and scoped
`git diff --check` passed.

The injected exception exercises rollback at the transaction boundary; it is not an outage of the
database or an independently observed database server commit failure. The full suite and other RP
cells' commit-failure behavior were not run.
