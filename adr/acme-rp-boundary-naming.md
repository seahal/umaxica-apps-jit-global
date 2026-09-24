# Acme RP Boundary Naming

**Status:** Accepted (2026-05-26)

> **Supersession (2026-06-02):** This ADR's IdP/RP-centered authority model is superseded by
> `adr/identity-authority-boundary.md`. `acme/www` is now the Session, Token, Account, Preference,
> and Authorization Authority. `sign/id` is no longer the IdP; it is a Credential Gateway and
> Credential Ceremony Zone only. Historical implementation details in this ADR must not be used to
> reintroduce sign-side sessions, refresh tokens, preference writes, dashboards, account lifecycle,
> downstream token issuance, authorization decisions, or step-up freshness. The historical
> `base-rails-rp` statement below is also not a current local registry contract; consult
> `adr/base-auth-ceremony-and-seven-rp-boundary.md` before changing RP registrations.

> **Historical-reading rule:** Every subsequent `base-rails-rp`, Acme/Sign authority, and shared-RP
> statement in this superseded ADR is historical migration context. In particular, the later
> sentences that describe `base-rails-rp` as live must not be read as an instruction to restore or
> register that client. The current local browser RP contract is defined only by the Base/Auth ADR
> named above.

## Context

The global Rails application hosts both the IdP face and the RP face:

- `sign` is the IdP.
- The RP-facing global application boundary was historically named `acme`.
- `app`, `com`, and `org` are the domain family and database boundaries.
- `core` is internal foundation and shared infrastructure.
- `visitor`, `client`, and `operator` are persona / actor boundaries.

The word `acme` is overloaded. In DNS and URL discussions, an apex domain means the bare domain such
as `example.com`, without a subdomain. Using `Acme` as a Rails namespace, route helper prefix, OIDC
client id prefix, and RP boundary name makes DNS and application-boundary discussions easy to
misread.

This repository does not have staging or production deployments that require preserving the old
`acme` operational names. OIDC client ids and audiences are internal to this Rails application and
its paired IdP/RP configuration, so they can be renamed as part of the same implementation pass.

The database inventory found no `acme` table, column, foreign key, index, constraint, schema dump,
or database connection names. The rename is therefore an application, routing, configuration, OIDC,
i18n, test, and documentation rename, not a database schema rename.

## Decision

Rename the RP-facing global application boundary from `acme` / `Acme` to `acme` / `Acme`.

The accepted naming rules are:

- Ruby constants use `Acme`.
- paths, namespaces, route helpers, file names, and route fragment names use `acme`.
- OIDC client ids use `acme_app`, `acme_com`, and `acme_org`.
- OIDC audiences use the `acme` vocabulary, for example `umaxica-acme-app`.
- configuration and environment variables use `ACME_*`.
- i18n keys use the `acme.*` namespace.
- database table, column, foreign key, index, and constraint names would use `acme` if any are
  introduced later.
- DNS terminology remains `acme` when it specifically means an apex domain or apex-scoped cookie
  domain.

The `base-rails-rp` client id remains the shared browser RP client for Acme's local browser flow and
the Base launcher surfaces. The historical name is preserved because the client is still registered
and used, but it does not mean Base owns Acme's `/oidc/callback` route family.

The previous structural grammar:

```text
{App,Com,Org}{Acme,Core}{Visitor,Client,Operator}
```

is replaced by:

```text
{App,Com,Org}{Acme,Core}{Visitor,Client,Operator}
```

## Consequences

- `app/controllers/acme/**`, `app/views/acme/**`, `app/views/layouts/acme/**`, and related test
  paths are renamed to `acme`.
- `Acme::*` controller constants become `Acme::*`.
- `config/routes/acme.rb` becomes `config/routes/acme.rb`, and route helper prefixes change from
  `acme_*` to `acme_*`.
- `ACME_SERVICE_URL`, `ACME_CORPORATE_URL`, `ACME_STAFF_URL`, `ACME_NETWORK_URL`, and
  `ACME_DEVELOPER_URL` become `ACME_*` equivalents.
- OIDC client registry entries and tests change from `acme_app`, `acme_com`, and `acme_org` to
  `acme_app`, `acme_com`, and `acme_org`.
- Because there is no staging or production compatibility requirement, the implementation does not
  need long-lived compatibility aliases for the old `acme` OIDC or environment names.
- Because the database inventory found no physical `acme` names, no schema migration is required for
  this rename.
- Documentation must keep DNS apex-domain usage unchanged. In particular, `apex-scoped` cookie
  domain language remains correct when it describes `.example.com` style domain scope.
- `base-rails-rp` remains a live client id and should not be treated as dead code while Acme app and
  Base launcher flows still depend on it.

## Migration Notes

Implementation should proceed in small commits:

1. Rename routes, controller namespace, view paths, layouts, and assets.
2. Remove `core` controller inheritance from the RP boundary instead of carrying it forward to
   `Acme::*`.
3. Rename OIDC client ids, audiences, callback configuration, and sign-to-RP links.
4. Rename `ACME_*` configuration to `ACME_*`.
5. Rename i18n keys and UI strings from `acme.*` / `Acme` to `acme.*` / `Acme`.
6. Rename tests and documentation.

The implementation should not rename DNS apex-domain terminology, cookie domain scope language, or
`.example.com` style test hosts.

## Related

- `adr/split-into-regional-and-global-repos.md`
- `adr/surface-database-connection-naming.md`
- `docs/security/cookie-domain-scope.md`
