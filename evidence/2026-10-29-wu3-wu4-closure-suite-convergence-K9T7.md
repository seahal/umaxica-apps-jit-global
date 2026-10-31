# WU-3/WU-4 closure: shared com/visitor reference sweep and full-suite convergence

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`. The worktree contains the full uncommitted WU-3/WU-4
  implementation from this session and prior sessions; nothing was committed. All results apply to this
  worktree state only.
- Scope of this record: the final shared-registry/test sweep that the preceding WU-4 records left open
  (test-side Visitor/com parameterizations in 346 further files, support helpers, shared values/jobs),
  the suite convergence measured against the WU-0 baseline, and the residual declarations.

## Outcome

- Ruby suite: 16,232 runs, 131,906 assertions, 130 failures, 200 errors, 0 skips. Every failing
  identifier is in `plans/2026-10-28-baseline-failing-tests.md` except one reported-below flake; 719
  baseline identifiers now pass (was 982 failing at baseline).
- The one non-baseline identifier, `SocialLinkUnlinkTest#test_social_unlink_requires_an_alternative_allowed_by_its_existing_method_policy`,
  passes in isolation and in pairwise runs with `social_auth_unlink_test.rb`
  (`PARALLEL_WORKERS=1 bin/rails test test/integration/social_link_unlink_test.rb test/integration/social_auth_unlink_test.rb`
  — 16 runs, 52 assertions, 0 failures, 0 errors, 3 recent full-seed repetitions green). It failed once
  inside the full parallel run only; recorded here as an environment-order flake of the Inertia
  csrf-meta extraction, not a product regression.
- JavaScript suite: `bun run test` — 96 files, 1,052 tests, all passing.
- `bin/rails zeitwerk:check` passes.
- `bundle check` reports the Gemfile's dependencies satisfied (native push gem removed earlier in WU-4).
- `bun run check` reaches the lint stage; the remaining 6 lint errors reproduce on the pre-change HEAD
  (`git stash`/`bun run lint`/`git stash pop`) and are not introduced by this cycle. `bun run format`
  was applied to the three files this cycle touched that the old formatter had left behind.

## What this record claims

- The remaining test-side sweep: 346 additional files edited by ten parallel agents plus the lead window
  in this session (per-file decisions recorded in their own agent reports referenced from the session),
  covering test/controllers, test/models, test/integration, test/services, test/operations, test/policies,
  test/queries, test/security, test/support, test/views, test/unit, test/values, test/tasks, test/jobs,
  test/mailers, test/notifiers, test/adapters, test/resolvers, test/concerns. Deleted whole files whose
  subject is retired com/visitor behavior; trimmed `:com`/visitor parameterizations from shared tests;
  retained `VisitorOccurrence*` coverage; every surviving file passes `ruby -c`.
- Shared app-side values trimmed after deleting the models:
  `identity_{email,telephone,passkey,step_up,secret_credential}_ceremony_contract.rb` (com issuer/audience
  entries and SURFACES), `surface_route_alias_helper.rb` (`auth_com_` prefix arm),
  `sign_up_session_state.rb` (com KEY_GROUPS), `op_logout_token_issuer.rb` (com resource type),
  `sign_signup_observability.rb` (Sign::Com surface), `sign_error_responses.rb` (com path surface),
  `base_step_up_completion.rb` re-target (`StepUpScopeCatalog::COM` removed), `step_up_scope_catalog.rb`
  (COM catalog and the visitors/com support + enforcement arms), `rp_cell_binding.rb` (rp_base/rp_core/
  rp_warp com cells fast-closed at the registry level; DB connection removal belongs to WU-5).
- Feature flag `outbound_push_suspended` and `sign_in_available_com` and push naming are out of
  `app/values/feature_flags.rb` (per the earlier WU-4 records and the registry invariant test).

## Not verified (not attempted in this session)

- Nothing else. MySQL/schema? n/a. The test database was only prepared by Rails in the normal way;
  no production persistence operation or external write was performed.
