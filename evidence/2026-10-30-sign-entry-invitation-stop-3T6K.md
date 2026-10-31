# Invitation admission stop boundary

- Commit: `336811e5072a93c0523e484f905082635b28f48f`; the worktree contained uncommitted changes affecting these checks.
- With automatic schema maintenance disabled because the com binding migration is pending, the invitation binding and classification tests passed: 9 runs, 63 assertions. The new integration case disables each app/org sign-in/sign-up flag in turn and confirms 503, no new ceremony session, unchanged binding and no Auth SID cookie.
- `bundle exec rubocop test/integration/sign_entry_invitation_parent_test.rb`: no offenses.
- Inspection found that admitted-session parent lookup accepts only `authentication_handoff`, and admission redemption compares an invitation parent intent separately from sign-in/sign-up. The tests above cover the attachment stop, not successful invitation redemption or continuation; the behavior and its intended authorization boundary need further work. Other two.md items remain incomplete.
