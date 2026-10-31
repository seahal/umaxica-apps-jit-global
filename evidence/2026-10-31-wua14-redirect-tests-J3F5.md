# BL-19 redirect checks

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree contained uncommitted changes affecting this result.
- `PARALLEL_WORKERS=1 bin/rails test test/resolvers/redirects/path_target_resolver_test.rb test/resolvers/redirects/navigation_target_resolver_test.rb test/services/redirects_path_target_resolver_security_test.rb test/resolvers/post_authentication_routing_resolver_test.rb test/integration/step_up_authentication_test.rb` passed: 54 runs, 279 assertions, 0 failures, 0 errors, 0 skips.
- These checks exercise invalid external/path targets and several signed Step-Up return paths. The historical triage's precise `signed_return_path_hardening` test and its reported input were not located in the current test tree; this run alone does not prove that exact historical defect is resolved.
- Subsequently, the APP and ORG Base cancellation tests that ignore client-supplied `return_to` values, including an external `https://evil.example/steal` value in ORG, passed: 2 runs, 34 assertions, 0 failures, 0 errors, 0 skips. They do not identify or reproduce the exact removed historical test.
