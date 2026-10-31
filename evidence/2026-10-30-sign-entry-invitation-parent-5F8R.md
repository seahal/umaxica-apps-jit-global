# Sign Entry Sentry invitation parent

- Commit: `336811e5072a93c0523e484f905082635b28f48f`; uncommitted worktree changes affected the checks.
- The admission-binding Sentry resolves an authorization transaction for both authentication and invitation handoffs before deriving the entry intent. Unsupported binding purposes raise instead of being interpreted as a flow.
- With automatic schema maintenance disabled because the com binding migration is pending, `sign_entry_invitation_parent_test.rb`, `sign_entry_sentry_parent_failure_test.rb`, and `sign_entry_classification_guard_test.rb` passed: 9 runs, 63 assertions. The invitation integration test observes a parent SELECT before binding attachment for both app and org.
- `bundle exec rubocop app/controllers/concerns/sign_entry_sentry_enforcement.rb test/integration/sign_entry_invitation_parent_test.rb`: no offenses.
- The admitted-session authorization-transaction accessor still only accepts `authentication_handoff`; invitation continuation behavior requires further investigation. The result does not establish the complete WU-A1 contract or completion of two.md.
