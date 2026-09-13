# GUID Identifier Surface

## Status

Accepted (2026-09-09). Supersedes the 2026-09-08 revision of this ADR, which named the public host
`guid.umaxica.id`. That hostname is retired; do not admit it.

## Context

UMAXICA needs a stable domain-level identifier that can uniquely identify resources and entities
without coupling external consumers to a database primary key or an implementation-specific storage
model. No existing resource model or persistence boundary currently owns that identifier lifecycle.
Choosing an identifier encoding or fabricating storage during a surface bootstrap would turn an
unreviewed implementation detail into a difficult-to-reverse public compatibility obligation.

The service was first bootstrapped as `EID` ("Entity Identifier") on `eid.umaxica.net`. Its
responsibility is to name and resolve globally unique identifiers, so it is named `GUID`. A later
revision placed the public host on `guid.umaxica.id` so the TLD would "say what the service does."
That host was never the name the edge and tunnel actually present: requests arrive as
`guid.umaxica.net`, and Host Authorization therefore rejected them. The published host is the
contract the origin must answer.

`guid.umaxica.net` sits in the same public `.net` family as other infrastructure names
(`jump.umaxica.net`, `asset.umaxica.net`) and matches the former EID TLD. The development label
`guid.net.localhost` already uses `.net` as the internal surface-family token; the public host now
uses the same TLD rather than mixing `.id` and `.net`.

## Decision

Adopt **GUID = globally unique identifier** and establish **`guid.umaxica.net`** as the dedicated
public surface. The canonical development host remains `guid.net.localhost` (port `3000`).

A GUID is an opaque domain-level identifier. It identifies exactly one entity or resource, must not
be reused for another, and has no consumer-visible semantics in its display formatting. It is not
defined as a UUID, ULID, DOI, URI, or database primary key.

The Rails surface is isolated under the `Guid::Net` namespace and a host constraint. It provides a
minimal homepage; the repository-standard health and revision endpoints; CSP reporting; and
`GET /api/v0/resources/:guid` as the resource-resolution boundary. The route follows the existing
versioned, plural-resource API convention. Until an authoritative GUID store and resolver contract
are decided, transport-safe identifiers receive the standard `404` Problem Details response.

The resolver validates untrusted path input for transport safety and maximum size, returns no
internal identifier or target, disables response storage, and performs no redirect. The GUID health
profile has no database readiness check until GUID persistence exists.

### Hostname migration

`eid.umaxica.net`, `eid.net.localhost`, and `guid.umaxica.id` are retired in the same change, not
kept for a compatibility period: nothing outside this repository consumed them (the edge route table
is derived from `config/routes/*.rb`, and there is no external registration against the retired
hosts). The environment keys remain:

| Name                      | Role                                      |
| ------------------------- | ----------------------------------------- |
| `PUBLIC_GUID_SERVICE_URL` | Browser-facing site: `guid.umaxica.net`   |
| `PRIVATE_GUID_SERVICE_URL` | Development ingress: `guid.net.localhost` |
| `GUID_SERVICE_URL`        | Explicit compatibility input for boot     |
| boot host key `guid_service` | Host family member                     |

`config.hosts` admits `guid.umaxica.net` in production and `guid.net.localhost:3000` in development.
A request whose `Host` is `guid.umaxica.id` or `eid.umaxica.net` is rejected.

## Consequences

Positive consequences:

- Public identifiers are decoupled from storage implementation and internal primary keys.
- The origin answers on the hostname the tunnel and DNS actually present.
- The public TLD and the development surface-family label are both `.net`; they no longer disagree.
- Resolution and future identifier functionality have a dedicated host and controller boundary.
- The bootstrap reuses existing health, revision, error, CSP, host-gating, and security-header
  conventions.

Costs and risks:

- A public surface must be deployed, monitored, secured, and kept available on this host.
- Identifier lifecycle and permanence become explicit compatibility obligations.
- Careless changes to identifier meaning or reuse rules may be impossible to reverse.
- A resolver returning only `404` is intentionally incomplete and must not be represented as an
  issuance or persistence service.
- Issuance, revocation or tombstones, canonical resolution, and persistence policy require later
  decisions.
- The `.id` TLD no longer signals "identifier" in the hostname; the service name `GUID` carries that
  meaning.

## Deferred Decisions

The following are explicitly outside this decision:

- GUID binary and text formats;
- UUID, UUIDv7, ULID, or another implementation mechanism;
- identifier issuance mechanism;
- database schema and authoritative storage owner;
- public issuance API;
- authentication and authorization requirements for issuance;
- tombstone and deletion behavior;
- canonical resolver response and redirect behavior;
- federation and cross-system namespaces;
- DOI, Handle, and ARK interoperability;
- persistence guarantees and retention period.

None of these may be inferred from the bootstrap route, its 255-byte transport limit, or the current
not-found response.

## Related

- `docs/architecture/guid-surface.md`
- `docs/reference/api-design-standards.md`
- `docs/reference/health-endpoints.md`
- `adr/internal-health-endpoint-edge-isolation.md`
