# Regional and authority runtime boundary

- Date: 2026-09-23
- Repository HEAD: `91d71c6f61d60c13be350bff3b723e05d09adf37`
- Worktree: already contained uncommitted implementation and documentation changes before this check; this evidence file is an additional uncommitted record.
- Scope: read-only repository-side verification. No GitHub, provider, AWS, Cloudflare, production, or shared external service write was performed.

## Environment

The required local Compose-backed preflight was run with `.env.devcontainer.example` selected explicitly. PostgreSQL and Valkey were reachable; the validator reported PostgreSQL 17.7 and Valkey 7.2.4 with successful PONG checks. No secret values were printed.

## Regional RP contract

Command:

```text
bundle exec rails auth:regional_rp_contract REPORT=tmp/auth/regional_rp_contract-current.json
```

The task completed without activating a client or generating a credential. It reported:

- `edit-org`: complete from the existing global host and registry contract.
- six Core regional cells: missing canonical regional audience.
- three Side JP cells: missing canonical regional audience.
- three Side US cells: missing canonical Side US host before audience evaluation.

This is the expected fail-closed result. No audience was derived from a client ID, no host was derived from a request header, and no regional registration was added to the active seven-client registry.

## Authority cutover guard

Command:

```text
RAILS_ENV=test bundle exec rails authority:cutover_guard
```

The isolated test database returned `ready: false` for all six approved families. Each family had zero resources and the explicit blocking reason `empty_resource_family`; no family was marked cut over.

The same read-only task was also attempted against the development environment. It failed closed with `AuthorityOwnerMigrationInventory::IncompleteAuthoritySchema` because the development database had the legacy ownership tables but not the lifecycle and cutover tables. This is not treated as acceptance evidence or as a reason to bypass the schema guard. It identifies a local development-schema preparation requirement; the test acceptance was run against the complete isolated test schema.

## Disposition

The observations do not justify inventing the missing Side US host or regional audience values, activating registrations, or treating an empty test inventory as a cutover. They are consistent with the current Frozen Plan: CF-007 remains `OPEN — CONTRACT CONTRADICTION`, while authority readiness remains fail-closed until reviewed resources and complete schema state exist.
