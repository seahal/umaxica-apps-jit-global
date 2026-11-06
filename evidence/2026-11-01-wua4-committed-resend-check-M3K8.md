# WU-A4 committed sign-in resend check

HEAD: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`. The worktree had 509 modified or untracked paths
and no staged changes; unrelated work was preserved.

The older `wua4-resend-additional-callers-P9J6` record says the queue-refusal/resend case still
needed committed Auth and Occurrence transactions. In the current tree, that case is in
`test/integration/sign_in_otp_resend_committed_http_test.rb`; the integration class disables
transactional tests, and the case exercises refusal followed by HTTP resend.

Command:
`PARALLEL_WORKERS=1 bin/rails test test/integration/sign_in_otp_resend_committed_http_test.rb:48`,
with `.env.container.devcontainer` loaded.

Result: 1 run, 14 assertions, 0 failures, 0 errors, 0 skips. The focused historical outstanding item
is verified in the current tree. The full suite and other WU-A4 items were not checked by this run.
