# Anonymous Base COM runtime ownership

HEAD: `336811e5072a93c0523e484f905082635b28f48f`. The worktree had extensive uncommitted changes, including runtime role code and route tests; this observation applies to that worktree.

`Base::Com::RootsController#index` renders an anonymous preference entry. The current runtime role mapping nevertheless assigns `base/com/roots` to `rp-base-com-ww`; `PARALLEL_WORKERS=1 bin/rails test test/lib/runtime_role_route_ownership_test.rb:45` passed: 1 run, 5 assertions, including that mapping. `RuntimeRole.rp_private_env_names` treats this as an RP cell and derives client-assertion and surface JWT private-key names for it.

This is a source and unit-test observation, not proof of a running deployment or a boot failure. Changing the owner to a shared role would alter process routing and security boundaries; deleting the role is part of the broader WU-A8 role transition. No role or key requirement was changed.
