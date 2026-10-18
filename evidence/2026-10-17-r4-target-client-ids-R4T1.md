# R4 target Client IDs: source cutover and local credential cutoff

Date: 2026-10-17 UTC. HEAD `17903f7d121aa33efe29f2db9235c9aa5db4b001`; uncommitted worktree also
holds R1-R3, partial R5 and the R5-WU03A role-boot packet.

## Change

- `app/values/rp_deployment_binding_value.rb`: trusted `UMAXICA_DEPLOYMENT_REGION` (required, no
  default), 19-entry declared catalog (5 WW + 7 x JP/US), 12 active IDs for JP. All IDs 11 chars.
- All in-repository callers moved from `core-app`/`warp-*`/`palm-app`/`edit-org`/`tech-org` to the
  exact target IDs (265 files incl. tests/fixtures/seeds). App code resolves regional IDs through
  the binding; WW IDs are literal. Static client store derives ID, audience and key namespace
  (`CORE_APP_JP`, `EDIT_ORG_WW`, ...) from the binding; Base keeps `BASE_RP_*_WW`.
- OIDC client key namespaces renamed in `JitSecurityJwtRegistry`; surface namespaces
  (`surface:CORE_APP`) unchanged. Core Browser credential now names its surface issuer directly
  instead of borrowing the client namespace.
- `RegionalRpClientMatrix` (pre-deployment dual registry), its test and rake task removed; no dual
  profile remains.

## Results

- Full suite, fleet `20261017c1a2`, 8 workers, `--seed 42061`: 15,368 runs, 1 failure, 0 errors. The
  failure `SignUpExpiryJobTest#test_expires_overdue_in-progress_tickets_on_both_ticket_databases`
  passed 3/3 alone; it uses a 1-second expiry margin and is load-sensitive, unrelated to the rename.
- Development databases dropped, created, migrated and seeded (standing local D). Afterwards:
  `OpAppGrant` rows 0; `core-app-jp` resolves; `core-app` and `core-app-us` raise
  `OidcClientRegistry::ClientNotFound` (old and inactive-region IDs refused).
- RuboCop clean on changed files.

## Open

- CI workflow still names old databases (read-only path in this workspace).
- US runtime NOT_RUN (`US_ENVIRONMENT_NOT_PROVISIONED`). Jump/Edge contracts not re-probed (E).
- `JitSecurityJwtRegistry::OIDC_CLIENT_NAMESPACES` and `RpCellBinding` still list JP namespaces
  literally; they match the only provisioned region.
