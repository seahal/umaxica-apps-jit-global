# Historical browser allowlist cases A09-1 and A09-2

HEAD: `336811e5072a93c0523e484f905082635b28f48f`. The worktree had extensive uncommitted changes, including the browser allowlist test and affected controllers; these results describe that worktree.

`PARALLEL_WORKERS=1 bin/rails test test/integration/sign_in_path_browser_allowlist_test.rb test/controllers/content_surface_browser_gate_test.rb` passed: 9 runs, 29 assertions. APP and ORG Auth sign-in and the Docs landing page returned 406 for the selected old Safari user agent. The tested Visa token endpoint, Core APP back-channel receiver, and Docs health endpoints did not return 406.

A temporary extra assertion in the Auth integration file requested `/health/liveness` with the same old user agent and expected neither 404 nor 406. The run failed on APP with 406 (4 runs, 8 assertions, 1 failure), before reaching the ORG request. `Auth::App::BareController` applies `allow_browser` to its liveness controller. The temporary failing assertion was removed; no application fix was made. A09-2 remains failed, ORG Auth liveness was not checked, and the health endpoints of other surfaces were not exhaustively checked.
