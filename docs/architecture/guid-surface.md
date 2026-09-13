# GUID Surface

## Purpose

`guid.umaxica.net` is the dedicated UMAXICA globally-unique-identifier service surface. A GUID is a
domain-level identifier for one entity or resource in the UMAXICA ecosystem. The surface exists so
consumers can eventually resolve that stable identifier without depending on a database primary key
or a particular storage model.

A GUID here does not mean UUIDv4, ULID, DOI, URI, or database primary key. One of those mechanisms may
later support an implementation, but none is part of the GUID domain contract today. This bootstrap
also defines no DOI-, Handle-, or ARK-compatible protocol.

## Identifier Invariants

- One GUID identifies one entity or resource.
- A GUID must never be reused for a different entity or resource.
- Consumers treat the identifier as opaque unless a future accepted specification says otherwise.
- Display formatting carries no semantics and must not be parsed for meaning.
- The binary/text format and issuance algorithm remain deliberately unspecified.

The underlying resource owns its domain data and lifecycle. GUID is the stable reference concept and
future resolution boundary; it is not a copy of the resource and does not expose its internal row
identifier.

## Implemented Endpoints

All routes are constrained to the GUID host and handled under the independent `Guid::Net` controller
namespace.

| Method | Path                     | Contract                                                                                           |
| ------ | ------------------------ | -------------------------------------------------------------------------------------------------- |
| `GET`  | `/`                      | Minimal HTML service identification page.                                                          |
| `GET`  | `/health`                | Shared text health aggregate. Internal-only at the public edge.                                    |
| `GET`  | `/health/liveness`       | Shared dependency-free text liveness probe. Internal-only at the public edge.                      |
| `GET`  | `/health/readiness`      | Shared text readiness probe. It has no storage dependency until an authoritative GUID store exists. |
| `GET`  | `/health/startup`        | Shared text startup probe. Internal-only at the public edge.                                       |
| `GET`  | `/revision`              | Shared text deployment revision response.                                                          |
| `GET`  | `/api/v0/health.json`    | Shared JSON health aggregate and negotiation behavior.                                             |
| `GET`  | `/api/v0/revision.json`  | Shared JSON deployment revision response.                                                          |
| `GET`  | `/api/v0/resources/:guid` | Initial GUID-to-resource resolution boundary.                                                       |
| `POST` | `/csp-violation-report`  | Existing bounded CSP report intake used by the page security policy.                               |

The resolver accepts a GUID only as untrusted opaque path input. Its transport boundary rejects an
empty value, whitespace or control characters, invalid encoding, and values over 255 bytes. These
rules protect HTTP processing; they do not specify the future issued identifier format. Because no
authoritative GUID model or store exists, every transport-safe GUID currently returns the standard
`404` Problem Details response. Resolver responses use `Cache-Control: no-store` so this temporary
negative result cannot become a durable cached answer. The endpoint never redirects to a caller-
controlled target.

## Host and Deployment Contract

Production sets `PUBLIC_GUID_SERVICE_URL=guid.umaxica.net` (or the explicit compatibility input
`GUID_SERVICE_URL`) before Rails boots. Development may additionally set
`PRIVATE_GUID_SERVICE_URL=guid.net.localhost`; the checked-in Compose environment supplies both names.
Host Authorization, route constraints, and the FQDN availability registry all list this surface. The
corresponding `fqdn_available_guid_service` availability flag therefore fails closed under the same
policy as other public surfaces.

The Cloudflare edge must route `guid.umaxica.net` to the Rails origin and must block public access to
`/health`, `/health/*`, `/api/v0/health.json`, and `/api/v0/revision.json` under the existing health
isolation policy. Edge configuration is external to this repository and must be completed before
launch.

## Deferred Functionality

This bootstrap does not decide or implement identifier format, issuance, storage, public issuance
APIs, issuance authentication or authorization, tombstones, deletion behavior, canonical resolver
behavior, redirects, federation, interoperability, persistence guarantees, or retention. Those
choices require later specifications and accepted architectural decisions before the resolver can
return a resource.

See [the GUID ADR](../../adr/guid-identifier-surface.md) for the decision and compatibility
consequences.
