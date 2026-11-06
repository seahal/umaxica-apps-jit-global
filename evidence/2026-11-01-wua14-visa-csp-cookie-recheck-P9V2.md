# WU-A14 BL-23 Visa CSP response-cookie recheck

HEAD: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`. The worktree had uncommitted changes; no
production code was changed for this check.
`test/controllers/csp_violation_reports_controller_test.rb` also had an unrelated uncommitted helper
deletion, which was not used by the selected test.

With Rails forgery protection enabled, the existing public HTTP case exercised valid and malformed
`application/csp-report` POSTs to both Visa APP and ORG, with and without `X-Requested-With`. It
asserted HTTP 204, no response cookies, no redirect, and no Client/Operator token changes. A normal
Base HTML GET in the same case still received `XSRF-TOKEN`.

Command:
`PARALLEL_WORKERS=1 bin/rails test test/controllers/csp_violation_reports_controller_test.rb:16`

Result: 1 run, 59 assertions, 0 failures, 0 errors, 0 skips. This recheck did not reproduce the
previously recorded Visa cookie emission in the current local test environment. It does not identify
why the earlier request emitted cookies or establish real-browser or deployed behavior.
