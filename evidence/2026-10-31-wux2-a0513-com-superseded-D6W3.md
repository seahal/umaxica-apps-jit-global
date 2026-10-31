# Historical A05-13 disposition

HEAD: `336811e5072a93c0523e484f905082635b28f48f`. The worktree had uncommitted changes affecting the code and tests.

The archived A05-13 case required COM Email/telephone sign-in intent and shared finalization, with no COM social. `two.md` section 3.2 subsequently requires retiring the COM Auth credential surface and keeping Base COM anonymous. The original positive COM credential journey is therefore superseded by that later requested boundary; its historical positive behavior was not tested or treated as passing.

With the configured local test environment, `PARALLEL_WORKERS=1 bin/rails test test/integration/routes/com_social_boundary_test.rb test/integration/routes/auth_sign_ceremony_route_contract_test.rb test/integration/routes/base_authority_route_contract_test.rb -n '/A05-13|auth_com_claims_no_ceremony_route|base_authority_com_no_longer_routes/'` passed: 4 runs, 70 assertions, 0 failures and 0 errors. These route-recognition cases cover selected retired COM Auth, social, Base identity and Visa protocol paths. They do not establish all HTTP methods, paths, host configurations, deployed behavior or the rest of WU-3.
