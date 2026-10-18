# Regional RP canonical-source audit

- Date: 2026-09-23
- Repository HEAD: `91d71c6f61d60c13be350bff3b723e05d09adf37`
- Worktree: pre-existing uncommitted changes present.
- External activity: none.

## Findings

- `RegionalRootUrlRegistry` is an authoritative source for the six Core JP/US regional roots.
- The existing Side host family has one boot-config source per face, whose current canonical
  public values are the established JP `www-jp.umaxica.*` family. No independent Side US source
  exists in the repository.
- `OidcClientStoresStaticClientStore` has face-level seven-client audiences (`core-app`,
  `core-com`, `core-org`, `side-app`, `side-com`, `side-org`, and `edit-org`). It has no
  canonical regional audience mapping for the approved new IDs.
- No regional binding may be created from a request `Host` header, and no client ID was treated as
  an audience value.

## Disposition

`RegionalRpClientMatrix` remains the fail-closed expected contract for the approved thirteen
logical cells. The active compatibility registry remains unchanged until an authoritative Side US
host source and regional audience source exist. This is a repository contract contradiction, not a
production or deployment-evidence gap.
