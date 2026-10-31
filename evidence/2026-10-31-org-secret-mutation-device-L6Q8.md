# ORG Secret update and removal device binding

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`; the worktree contained uncommitted changes affecting this result.
- Before the change, the update test file had 1 failure in 11 runs and 26 assertions: a revoked device could rename a Secret. The test reached the rename assertion first, so it did not independently establish the pre-change removal result.
- Update and removal now lock the operator, device and token in that order and recheck device usability and current-token binding before applying Step-Up and credential mutation.
- The create, update and removal service files passed together: 22 runs, 87 assertions, no failures or errors. Cases include revoked devices and superseded tokens for update and removal. RuboCop passed for both changed services and the updated test.
- Tests use transactional fixtures. Independent-connection races, end-to-end browser behavior and cross-database failure ordering remain unverified; this change does not resolve the missing same-principal-database audit fact.
