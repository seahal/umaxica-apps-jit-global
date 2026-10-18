# MCP endpoint withdrawal revalidation

Date: 2026-09-22
Branch: `feature`
HEAD: `91d71c6f61d60c13be350bff3b723e05d09adf37`
Worktree: contained pre-existing and related uncommitted changes; no unrelated changes were reset.

## Disposition

The accepted MCP withdrawal remains implemented. The six Base/Side app/com/org `POST /mcp` routes
are commented out, the controllers/tools remain unreachable transitional code, and the public
entrypoint inventory records `PUBLIC_MCP` as withdrawn. The stale ADR wording that said the
withdrawal tests had not been reconciled was corrected; no route or authentication behavior changed.

## Verification

Command:

```text
PARALLEL_WORKERS=1 bin/rails test test/integration/mcp_endpoint_withdrawal_test.rb test/values/mcp_surface_identity_and_token_codec_test.rb test/unit/security/public_entrypoint_inventory_test.rb test/controllers/concerns/surface_seam_contracts_test.rb
```

Result: 11 runs, 100 assertions, 0 failures, 0 errors, 0 skips.

The focused set verified route recognition failure and not-found responses on all six former hosts,
surface identity behavior, entrypoint inventory, and concern seam contracts. No external service or
GitHub state was accessed or changed.
