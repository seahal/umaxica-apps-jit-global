# WU-A3 coupled state focused recheck

HEAD: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`. The worktree had 421 modified tracked files, 178
untracked files, and no staged files. Existing changes were preserved; no commit was created.

Owner approval for the App/Org Admission Binding, Auth Ceremony, and OIDC coupled status shapes and
local migrations is recorded in the conversation. The four local development/test OP Base migrations
were already up at the preceding read-only status check and were not reapplied in this recheck. The
pre-cutover custom-format snapshots do exist under
`/tmp/wua3-coupled-state-final-20261101T035605Z/`; their SHA-256 values are recorded in
`evidence/2026-11-01-wua3-coupled-status-local-cutover-C7N5.md`. This resolves the later observation
that the snapshots were absent; it does not establish who applied the migrations.

Ran the focused App/Org Admission Binding, Auth Ceremony, OIDC cancellation/purger, and AC-53
initial-attach suites against the current local test databases: 61 runs, 717 assertions, 0 failures,
0 errors, 0 skips. The first invocation named a nonexistent test path and stopped before loading
tests; the corrected invocation used `test/integration/acceptance_wua3_initial_attach_race_test.rb`
and completed. No code was edited while the successful run was active.

This confirms the selected status transition, cancellation, retention, and AC-53 cases after the
local cutover. WU-A3 remains open: the ORG Switch statement still conflicts with the accepted
sign-up contract, and the shared AC-40/50/51 portions and full `two.md` acceptance matrix are not
closed by this run. No full suite was run.
