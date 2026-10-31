# WU-A4 TOTP rename target-bound Step-Up

HEAD: `336811e5072a93c0523e484f905082635b28f48f`. The worktree contained staged, unstaged and
untracked changes affecting the result. Tests used local test databases; production and Neon were
not targeted.

An unbound `settings_totp` Step-Up could rename an owned TOTP credential before this change. The
new operation case reproduced it and then passed with `resource_ref` bound to the credential's
public ID. A proof for one credential cannot rename another, and failures preserve the proof and
both names. The TOTP detail, update and removal controller guard now requires the owned target;
the signed verification return path is resolved to the same owned credential. After a successful
rename the browser returns to the list, because the single-use Step-Up was consumed.

Public HTTP tests covered initiation and persisted transaction target, successful rename and
return, another owned credential, and another actor's credential. A separate signed-return-path
test for another actor's TOTP passed: 1 run, 4 assertions, no failures or errors.
The integration, operation, independent-connection and removal-related files passed together:
40 runs, 197 assertions, no failures, errors or skips. Two existing removal tests needed their
Step-Up fixtures bound to the target after the controller guard became target-specific. RuboCop
reported no offenses in the seven changed Ruby files after the additional focused negative test;
scoped `git diff --check` also passed.

This is not XDB-04 closure: the same-Zenith-transaction audit, public HTTP dependency-failure
coverage and remaining independent-connection races are still open. Strengthening the controller
guard alone does not establish the credential-removal writer's complete contract.
