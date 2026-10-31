# WU-7 com consent and Web Push reads

HEAD: `336811e5072a93c0523e484f905082635b28f48f`. Staged, unstaged and untracked worktree changes
affected the result.

`PARALLEL_WORKERS=1 bin/rails test test/integration/anonymous_com_consent_receipt_test.rb
test/integration/anonymous_com_web_push_api_test.rb test/integration/anonymous_com_retired_consent_test.rb`
passed: 30 runs, 267 assertions, no failures, errors or skips. The cases exercise explicit consent
versus unanswered state, binding checks, refusal, retired and expired preference reads, Web Push
without a consent child, and database read failure. The com GET consent implementation was also
inspected for the active row, receipt and matching browser binding checks.

The test covers the listed cases in the local test environment, not all WU-7 acceptance conditions.
Actual purge approval and the full-suite baseline comparison remain unresolved. No production or
Neon database was targeted.
