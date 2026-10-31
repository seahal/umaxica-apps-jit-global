# Auth APP normal liveness response

HEAD: `336811e5072a93c0523e484f905082635b28f48f`. The worktree had extensive uncommitted changes, including the health controllers and tests; this result applies to that worktree.

`PARALLEL_WORKERS=1 bin/rails test test/integration/health_endpoints_test.rb:420` passed: 1 run, 3 assertions. Without the outdated User-Agent from the earlier probe, Auth APP liveness returned HTTP 200 with `text/plain` body `ok\n`. The test also makes database and readiness access fail if reached. This is a Rails integration request, not a deployed probe; it does not test the old User-Agent or establish the ORG response.

The old User-Agent APP response remains HTTP 406 as recorded in `evidence/2026-10-31-wux2-browser-health-A7Q4.md`. No response change was implemented in this check.
