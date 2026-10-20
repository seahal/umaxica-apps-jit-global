# Full isolated Ruby verification

- Revision: `87c15e1e5d89344db7dcaaa85ebb1f6972c0c829`; uncommitted C1/C4/C5/C6/C7 model, locale and
  test changes were loaded. Concurrent unrelated configuration and empty structure dumps were
  retained. Projection and nullable-evidence tests drafted after discovery began were not included
  in this run.
- Command: `python3 tmp/database-consistency-20261019/run_isolated_tests.py full-isolated`
  (`bin/rails test`, RAILS_ENV=test, PARALLEL_WORKERS=2, existing identity-verified isolated
  manifest).
- Terminal exit 1: **15,774 runs, 137,348 assertions, eight failures, four errors, zero skips**,
  717.754 seconds reported by Minitest. Worker processes and runner exited; this is a completed
  failing run.
- Failure classes: three DatabaseReconstructionAuthorityTest assertions reading empty structure
  dumps; three BaseIdentityActivityLogPresenterTest assertions; RuntimeRoleRouteOwnershipTest
  controller ownership; Security::AuthenticationModeInventoryTest local declarations.
- Errors: three KeyError(clearHistory) in
  InertiaPageContractTest/AuthenticatedResponseCachePolicyTest; one RuntimeRole::UnownedRoute in
  RuntimeRoleRouteOwnershipTest. No NoDatabaseError and no missing worker-receipt errors in this
  completed isolated run.
- These failures were not suppressed, skipped or attributed wholesale to remediation. Several
  overlap the earlier failing normal run; the empty dump assertions reflect the currently retained
  unrelated dump changes. Presenter empty-owner assertion needs separate reproduction before
  attribution.
- Full stdout SHA-256: `5361a5017d245afe4e66cec659a559959d3d3269acdfc0816ae0f4ee5dfdee2c`. Raw logs,
  exit receipt and deduplicated case IDs: ignored
  `tmp/database-consistency-20261019/full-isolated*`.
- Whole-suite success, final C7 projection compatibility, schema drift and production migration
  applicability remain unestablished. No new DDL/dump regeneration or unrelated fix was made to
  manufacture a passing result.
