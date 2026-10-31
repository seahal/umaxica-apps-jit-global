# Base COM translation namespace guard

HEAD: `336811e5072a93c0523e484f905082635b28f48f`. The worktree had extensive uncommitted changes, including the Base COM controller tree and the invariant test; results describe that worktree.

The existing Base ORG translation namespace guard passed before the change (1 run, 2 assertions). A source search found Base COM controller files and no quoted `sign.app`, `views.sign.app`, `base.app`, or `views.base.app` key in the scoped controller/helper trees. The existing guard now also scans the Base COM controller/helper trees for those quoted keys.

`PARALLEL_WORKERS=1 bin/rails test test/security/invariants/base_org_translation_namespace_invariant_test.rb test/security/invariants/auth_surface_translation_namespace_invariant_test.rb` passed: 4 runs, 8 assertions. A deliberately failing fixture was not introduced; dynamic keys and files outside the scoped Ruby controller/helper trees are not covered. This closes the specified guard slice, not all of WU-X1.
