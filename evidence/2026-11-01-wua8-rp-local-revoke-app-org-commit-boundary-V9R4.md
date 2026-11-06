# WU-A8 Core APP and ORG RP local revoke commit boundary

Work was performed against full HEAD `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`. The worktree had
658 staged, unstaged, or untracked entries before this evidence file was added. No commit,
migration, production/Neon operation, or live RFC 7009 request was made.

The Core ORG RP-cell sign-out integration case now injects an `ActiveRecord::StatementInvalid` after
the local session update runs and before the local transaction commits. The request returned HTTP
503, the local transaction rolled the update back, all three RP credential cookies remained, and the
RFC 7009 adapter was not called. A subsequent uninjected request completed the logout handoff. The
earlier Core APP case covers the same rollback boundary.

The selected Core ORG case passed after the change (1 run, 31 assertions). The complete
`test/integration/rp_cell_local_session_readiness_test.rb` passed (20 runs, 307 assertions, 0
failures, 0 errors, 0 skips). Scoped RuboCop, Ruby syntax, and `git diff --check` passed.

The injected rollback models a failure at the transaction commit boundary; it is not a database
server outage. Other RP cells' local commit-failure behavior, WU-A8's remaining
authentication/management boundaries, and the full suite were not tested here.
