# WU-A4 Email preference target-bound Step-Up

HEAD: `336811e5072a93c0523e484f905082635b28f48f`. The worktree contained staged, unstaged and
untracked changes affecting the result. Tests used local test databases; production and Neon were
not targeted.

Before the change an unbound `settings_email` Step-Up could update an owned Email preference. The
new operation case reproduced that behavior, then passed after requiring the owned Email's public
identifier as `resource_ref`. A separate target-specific proof cannot update another owned Email,
and an unbound proof cannot update either target.

The Base app Email edit/update guard resolves its owned Email before forming the requirement. Base
verification resolves that same target from a verified, session-bound signed return path for the
Email edit route and checks its ownership before issuing a Step-Up transaction. Public HTTP cases
cover transaction target binding, another owned Email, an unowned Email and a signed return path
for another actor's Email. Existing registration and removal requirements were not changed.

`PARALLEL_WORKERS=1 bin/rails test test/integration/step_up_authentication_test.rb
test/operations/identity_email_preference_committer_test.rb
test/concurrency/identity_email_preference_commit_order_test.rb
test/controllers/base/identity_sessions_and_email_preferences_test.rb
test/unit/security/standard_csrf_invariant_test.rb` passed: 28 runs, 127 assertions, no failures,
errors or skips. RuboCop found no offenses in the seven changed Ruby files. Scoped whitespace
checks passed. These checks do not establish XDB-03 completion: the same-Zenith-transaction
preference-change audit and the remaining independent-connection races are still open.

After target binding, the successful update redirect was changed to the Email list: redirecting
back to the protected edit page would immediately require another Step-Up because the update
consumes the evidence. The focused authenticated HTTP case passed again: 1 run, 10 assertions,
including the list destination and the existing 503 mapping case.
