# Auth switch progress race

Commit: `336811e5072a93c0523e484f905082635b28f48f`. The worktree contained uncommitted changes affecting this check.

With automatic test schema maintenance disabled, `test/integration/sign_entry_otp_admitted_order_test.rb` passed: 6 runs, 71 assertions, no failures, errors, or skips. The test starts an email challenge at the first parent clock read after the initial first-page check and verifies that Switch preserves the challenge, ceremony, parent, and SID. This is a deterministic interleaving, not a concurrent database stress test.

The switch currently locks the parent before the ceremony, matching the existing email challenge writer. The broader lock-order requirements and the signup-flow race remain open.
