# R5-WU17 cell local-session wiring (source side)

- Commit: 17903f7d121aa33efe29f2db9235c9aa5db4b001; worktree has the uncommitted R4/R5 changes that
  are the subject here.
- Date: 2026-10-17T13:13:34Z

## Delivered

- Route ownership: `RuntimeRole.route_owner` / `serves?` (lib/runtime_role.rb) and
  `RuntimeRoleRouteGuard` (empty 404 before any callback for a non-owned controller; unowned
  controllers refused). Base identity/credential/verification/withdrawal/recovery/selector paths
  belong to `op-base-<realm>` (user decision 2026-10-17).
- `rp-*` processes: callback commits the verified identity to the cell store (RpCallbackCommitter)
  and sets the `rp-session` cookie; requests authenticate via RpRequestAuthenticator; Refresh via
  RpRefreshCommitter; the same for the Core browser API. Base cells read the selection from the OP
  (`GET /api/v0/identity/selection`). `shared` and OP roles keep the OP-chain path.
- Edit/Tech cell schema constrained `client_id` to pre-R4 `edit-org`/`tech-org`; corrected in the
  uncommitted create migrations and structure dumps, and re-applied to the disposable test fleet and
  development databases.

## Results

- `test/integration/rp_cell_local_session_readiness_test.rb`: 12/12 cells authenticate from the
  local session, refuse the same Access JWT without it, and refuse after the local OP binding is
  revoked.
- Palm callback in cell mode (commit + page, tombstoned sid refused): pass.
- Route ownership/guard tests: pass.
- Full suite run 12 (fleet `codex_integrity_20261017c1a2_*`, 8 workers, seed 42061): 15465 runs,
  131925 assertions, 0 failures, 0 errors, 0 skips.

## Open / not done

- Core session API `actor.id` becomes the cell principal ID in a cell process: external contract
  change, approved by the user on 2026-10-17 (after this record was first written).
- Base support index (operator capability reads) and welcome (sign-in sequence) owners undecided.
- No HTTP server ran under an `rp-*` role; no cross-process Code Flow (see
  evidence/2026-10-17-runtime-role-provisioning-R3P7.md).
