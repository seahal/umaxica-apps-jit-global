# Base RP cell actor resolution source review

HEAD: `336811e5072a93c0523e484f905082635b28f48f`. The worktree had extensive uncommitted changes, including Base controllers and browser RP authentication; the observations describe that worktree.

In RP-cell mode, `BrowserRpAuthentication#resolve_rp_cell_access` places the local principal returned by `RpRequestAuthenticator` in its access state. `current_resource` returns that state resource and `current_client` returns it for the client realm. Base APP includes this concern and uses `current_client` in its identity workflow. `RpBaseAppPrincipal` is a cell-local model, while two.md section 6.4 calls for Base to resolve the verified canonical subject to the Zenith Client. No `BaseZenithIdentityResolver` implementation was found under `app/resolvers` in this source search.

The existing Base APP local-session readiness case passed: `PARALLEL_WORKERS=1 bin/rails test test/integration/rp_cell_local_session_readiness_test.rb -n '/base-app-ww/'` returned 1 run, 3 assertions. Its `/accounts` case accepts the selector redirect as an authenticated result; it does not establish that identity management receives the canonical Zenith Client. No source implementation or data was changed.
