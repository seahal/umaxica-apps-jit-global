# Database Names Carry No Region

**Status:** Accepted (2026-10-19)

## Context

The development and test names of the RP `core`, `warp` and `palm` cell databases carried a `_jp`
region suffix (for example `development_rp_core_app_jp_db`), while their connection names
(`rp_core_app`) and production names (`production_rp_core_app_db`) did not. The suffix made one
logical database appear under different identities per environment and encoded a deployment property
in a schema-level name.

## Decision

- Database names in every environment carry no region marker. A database is named after its
  connection: `<environment>_<connection>_db`, for example `development_rp_core_app_db`.
- Connection names, migration paths and structure dumps carry no region marker either.
- Region-bearing identifiers that describe a deployment rather than a database, such as OIDC client
  IDs (`core-app-jp`) and public hostnames (`www-jp.umaxica.app`), are outside this decision and
  keep their current values.

## Future Regional Deployment (not in current scope)

If regional deployments are introduced, each region is expected to run its own Rails repository
deployed in that region, with region-specific parameters supplied through environment variables
rather than through region-qualified database or connection names. No design work for this is
required now; the current repository does not anticipate it in names or configuration.

## Consequences

- `config/database.yml`, `config/ci.rb`, `.env.container.devcontainer` and
  `.github/workflows/ci.yml` must list the RP cell databases without `_jp`.
- Local databases created under the old names are orphaned after the rename; they are disposable and
  may be left in place or dropped.
