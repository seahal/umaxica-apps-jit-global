# Auth classification route guard

HEAD: `336811e5072a93c0523e484f905082635b28f48f`. The worktree contained uncommitted changes affecting the test and application.

The existing classification guard previously filtered out Auth routes whose controller could not be resolved, before checking their declarations. It now reports the route and missing controller instead of silently excluding it. It continues to require a declaration for each resolved route.

With the configured local test environment, `PARALLEL_WORKERS=1 bin/rails test test/unit/security/sign_entry_classification_guard_test.rb` passed before and after the change (7 runs, 29 assertions each). `bundle exec rubocop test/unit/security/sign_entry_classification_guard_test.rb --format simple` initially reported a string-style offense; after correcting the quote style, it passed. `git diff --check` passed for the guard file. The final style-only change was not followed by another Rails test run. No synthetic missing-controller route was injected, and this does not establish all WU-A1 runtime stop boundaries.

Follow-up mutation probe: a temporary copy of the guard forced resolution of the existing `auth/app/roots#index` route to return no controller. `PARALLEL_WORKERS=1 bin/rails test tmp/wua1_missing_controller_probe_test.rb -n /every_reachable_Auth_route_resolves/` failed as intended (1 run, 2 assertions, 1 failure), identifying the route as `controller not found`. The temporary copy was removed. This checks the failure branch using an existing route; it does not establish all WU-A1 runtime stop boundaries.
