# WU-7 com realm and reader checks

HEAD: `336811e5072a93c0523e484f905082635b28f48f`. Staged, unstaged and untracked worktree
changes affected the result.

`PARALLEL_WORKERS=1 bin/rails test test/values/anonymous_com_preference_token_shape_test.rb
test/controllers/warp/com/roots_controller_test.rb` passed: 35 runs, 344 assertions, no failures,
errors or skips. The codec cases exercise com tokens on com sibling, app and org hosts, app and
org tokens on com, and rejection of signatures made with the other issuer's key. The Warp request
case exercises rendering a signed com preference without setting database access. The test uses
local configured keys and does not verify deployed key distribution.

The full-suite baseline comparison and actual collection approval remain unresolved; this does not
establish WU-7 completion. No production or Neon database was targeted.
