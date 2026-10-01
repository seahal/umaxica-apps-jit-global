# Home and Dashboard boundary verification

- Commit: `f8c93e4a9a50e22a942976a5810962f039662206`.
- Worktree: uncommitted changes were present before this work, including overlapping Base and Warp root/dashboard changes; the checks below ran with additional uncommitted changes for this task.
- `bin/rails test test/controllers/warp/app/dashboards_controller_test.rb -n '/anonymous direct dashboard/'` was attempted after the first failing-test edit. Minitest rejected `-n` in favor of `-i`, and test setup could not connect to PostgreSQL host `primary` (`ActiveRecord::DatabaseConnectionError`). No request assertions executed. No Rails test result is claimed.
- A retry with `-i '/anonymous direct dashboard/'` reached the same PostgreSQL connection failure before assertions. Output was truncated with `head`; the shell pipeline's exit status is not a test pass.
- `ruby -c` completed successfully for the 16 edited root, dashboard, Warp callback, Warp sign-out, and exception-renderer source files checked in this session.
- `ruby -c` also completed successfully for every tracked modified Ruby file in the worktree; this includes pre-existing uncommitted edits.
- `git diff --check` reported no whitespace errors.
- Static review found the route remains registered; rejected requests raise `ActiveRecord::RecordNotFound`; Dashboard actions retain `authorize!`; both accepted pages set `Cache-Control: private, no-store`; standard HTML 404 responses are marked `private, no-store` in the existing exceptions app.
- The twelve per-surface request outcomes, sign-in and sign-out browser flows, and the full Rails suite remain unverified because the test database was unavailable.
