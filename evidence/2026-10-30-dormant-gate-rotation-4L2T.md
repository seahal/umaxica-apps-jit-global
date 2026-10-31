# Dormant preference gate during refresh rotation

- Commit: `336811e5072a93c0523e484f905082635b28f48f`; uncommitted changes affected the checks.
- Updated the existing AppPreference rotation expectation: active display children move, while the dormant adult gate stays on the original preference. A fixture-independent public model test exercises the real app and org rotation methods and verifies the existing gate and its value remain on the original row, with no gate on the replacement.
- With automatic test schema maintenance disabled because the com binding migration is pending, the rotation test, dormant registry guard and com initialization integration test passed: 3 runs, 32 assertions. `bundle exec rubocop test/models/app_preference_test.rb test/models/dormant_preference_gate_rotation_test.rb` reported no offenses.
- The existing full-fixture AppPreference suite was not run; earlier full fixture preparation failed on an unrelated admission-binding foreign key. App/org sign-in adoption remains unverified end to end, and two.md remains incomplete.
