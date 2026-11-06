# WU-A3 Step-Up admission replay recheck

HEAD: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`. The worktree had 485 changed or untracked paths
and no staged changes. Existing work was preserved.

The earlier record `evidence/2026-10-31-wua2-stepup-admission-replay-J9D4.md` reported that an
admitted same-browser Step-Up replay returned 400. On the current worktree, after the approved local
App/Org Admission Binding, Auth Ceremony and OIDC parent status cutover, the existing public tests
exercise that replay in both realms and pass. The current source permits a redeemed binding only
through the same-browser admitted-session check and validates its parent with
`allow_redeemed: true`; the prior source explanation in J9D4 no longer describes this
implementation.

With `.env.container.devcontainer` loaded, ran:

`bin/rails test test/controllers/auth/app/verifications_controller_test.rb test/controllers/auth/org/verifications_controller_test.rb`

Result: 9 runs, 171 assertions, 0 failures, 0 errors, 0 skips. The selected paths include
same-browser replay, foreign-browser refusal, Fetch Metadata/HEAD refusal, and continuation-curfew
boundaries. The full suite was not run.
