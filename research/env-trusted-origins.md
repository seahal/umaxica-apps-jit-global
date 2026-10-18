# Engine-prefixed trusted_origins naming

> **Status update (2026-05-19):** Obsolete. The engine-prefixed ENV naming scheme below belongs to
> the retired Rails Engine / four-app architecture. New runtime configuration in this repository
> should use the current surface or service naming already present in code.

The canonical trusted-origins contract follows the same naming rule as the canonical URL contract:

- `ENGINE_HOSTLABEL_AUDIENCE_TRUSTED_ORIGINS`

Examples:

- `IDENTITY_SIGN_APP_TRUSTED_ORIGINS`
- `ZENITH_ACME_COM_TRUSTED_ORIGINS`
- `FOUNDATION_BASE_ORG_TRUSTED_ORIGINS`
- `DISTRIBUTOR_POST_NET_TRUSTED_ORIGINS`

Legacy names such as `ACME_*_TRUSTED_ORIGINS`, `ACME_*_TRUSTED_ORIGINS`, `CORE_*_TRUSTED_ORIGINS`,
and `DOCS_*_TRUSTED_ORIGINS` are migration-source names only. They are not part of the target
design.

The fallback value for each key may keep localhost origins available in development and test during
the migration window, but runtime code should converge on engine-prefixed names only.
