# MCP Endpoint Withdrawal

Accepted: 2026-09-19

## Context

`POST /mcp` was served unauthenticated on six hosts: Base and Side, each for the app, com, and org
surfaces (`config/routes/base.rb`, `config/routes/side.rb`). The endpoint used the `mcp` gem's
stateless Streamable HTTP transport through `McpEndpoint`, and it exposed three read-only tools:
`McpLivenessTool`, `McpVersionTool`, and `McpServiceInfoTool`.

The OWASP ASVS 5.0 review of 2026-09-19
(`evidence/2026-09-19-owasp-asvs-5-checklist-review-V5R8.md`, finding F7) listed the endpoint as an
unauthenticated public entry point. The tools themselves disclose little: the deployment revision
is already public through `GET /revision`, which is an accepted exposure. The concern is the
entry point itself:

- It is an unauthenticated JSON-RPC surface on every user-facing host. Every future tool added to
  `McpEndpoint#mcp_server` would be reachable by anyone unless the author also designs
  authentication, authorization, and surface isolation for it.
- The protocol, the transport's host and origin handling, and the gem's security model have not
  been reviewed with the depth that an unauthenticated entry point requires. The team does not yet
  have the implementation expertise to extend this surface safely.
- It serves no current product requirement: no client depends on it.

## Decision

Withdraw the MCP entry point by commenting out the six `resource :mcp, only: :create` routes. Each
commented line points to this ADR.

- The controllers (`Base::*::McpsController`, `Side::*::McpsController`), the `McpEndpoint` concern,
  the tools, and the `mcp` gem stay in the repository, so the endpoint can be restored by
  uncommenting the routes once the conditions below are met.
- `docs/security/public-entrypoints.md` marks `PUBLIC_MCP` as withdrawn.
- `GET /revision` and `/api/v0/revision.json` are unaffected and remain an accepted disclosure.

## Conditions for restoring the endpoint

Re-enable the routes only after a follow-up ADR records:

- whether the endpoint is authenticated and, if so, how it binds to the surface's actor and session
  under the existing Action Policy and surface-isolation rules
- a review of the `mcp` gem transport (host and origin validation, request size limits, error
  output) against the ASVS V4 and V13 requirements
- the ownership rule for adding tools, including who reviews each tool's data exposure

## Consequences

- `POST /mcp` returns the router's not-found response on all six hosts.
- The former live-endpoint tests were retired with the route contract and replaced by
  `test/integration/mcp_endpoint_withdrawal_test.rb`, which asserts both route recognition failure
  and a not-found response on all six former hosts. The public-entrypoint inventory and seam
  contract tests record the withdrawn boundary. The current focused withdrawal, identity, inventory,
  and seam contract set passed with 11 runs / 100 assertions / 0 failures / 0 errors / 0 skips on
  2026-09-22; historical proof is recorded in
  `evidence/2026-09-22-mcp-withdrawal-revalidation-K6L7.md`.
- Keeping unreachable controllers is a transitional state bounded by this ADR. If the endpoint is not
  restored, delete the controllers, concern, tools, gem, and tests together.
