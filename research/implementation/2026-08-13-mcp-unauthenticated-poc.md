# MCP Unauthenticated PoC Implementation Notes

## Context

- Original plan/spec: add an unauthenticated Model Context Protocol endpoint at `POST /mcp` to the
  six Base and Side surfaces (app/com/org), reusing existing Rails services rather than building a
  new MCP-specific architecture.
- Related decisions/docs/plans: `adr/internal-health-endpoint-edge-isolation.md`,
  `adr/rails-routing-resourceful-policy.md`, `adr/two-base-authentication-mode-boundaries.md`,
  `docs/security/public-entrypoints.md`, `.agents/harnesses/rules/generic/routing.mdc`,
  `.agents/harnesses/rules/project/surfaces.mdc`,
  `.agents/harnesses/rules/generic/no-silent-fallback.mdc`.
- Implementation date: 2026-08-13.

## Decisions Made During Implementation

- Decision: kept `protect_from_forgery` exactly as every bare endpoint declares it; nothing skipped,
  disabled, or weakened for the MCP endpoint.
  - Why: it was expected from source reading that a non-browser POST (no `Sec-Fetch-Site`, no
    authenticity token) would be rejected under `:header_or_legacy_token`. Measured behavior
    contradicts that reading: with `allow_forgery_protection` explicitly enabled, and over both HTTP
    and HTTPS, a cookieless non-browser POST succeeds, while a request carrying
    `Sec-Fetch-Site: cross-site` is still rejected with 422. That is the desired posture, so no
    change to the CSRF architecture was needed.
  - Alternatives considered: basing the MCP controllers on `ActionController::API`, which omits
    `RequestForgeryProtection` entirely. Rejected as unnecessary once measurement showed the
    standard bare inheritance works; it would also have cost `allow_browser` and forced a
    replacement rate-limit responder, since `MimeResponds` is not part of `ActionController::API`.
  - Follow-up: the exact framework branch producing this outcome was not pinned down — a request
    with no `Sec-Fetch-Site` header emits no CSRF instrumentation at all, while
    `Sec-Fetch-Site: none` emits `csrf_token_fallback` and is blocked, which the Rails 8.2 source
    alone does not explain. Because the behavior is load-bearing and not fully understood, both
    properties are locked by `test/integration/mcp_forgery_protection_test.rb`. Revisit on any Rails
    upgrade.

- Decision: the health tool reuses `Health::LivenessCheck` only, and reports `status` alone.
  - Why: `adr/internal-health-endpoint-edge-isolation.md` treats dependency and topology detail as
    an internal reconnaissance surface that is blocked at the Cloudflare edge.
    `Health::SnapshotCheck` returns a dependency map, so exposing it on a public unauthenticated
    endpoint would contradict an accepted ADR. `LivenessCheck` returns only a boot-state status and
    a surface label.
  - Alternatives considered: a full `system.health` tool as originally proposed (rejected, conflicts
    with the ADR); omitting health entirely (viable, but liveness carries no topology and is
    useful).
  - Follow-up: none.

- Decision: `allowed_hosts` for the transport is derived from
  `Rails.configuration.x.boot_config.fetch(:hosts)` per surface.
  - Why: the SDK's DNS-rebinding protection defaults to loopback hosts only, which would return 403
    for all production traffic. Passing `dns_rebinding_protection: false` would be a silent fallback
    and is forbidden. Deriving the allowlist from the same contract the route constraint uses keeps
    the endpoint reachable exactly on the hosts it is routed under.
  - Alternatives considered: disabling the check (forbidden); allowing `request.host` (tautological,
    defeats the check).
  - Follow-up: none.

- Decision: tool names use underscores (`system_liveness`, `system_version`, `service_info`) rather
  than the dotted names in the original brief.
  - Why: dotted names are not accepted by all MCP clients, and the SDK enforces no naming pattern of
    its own, so the more conservative form was chosen.
  - Alternatives considered: `system.health` style dotted names.
  - Follow-up: none.

- Decision: controller integration with `stateless: true`, not a Rack `mount`.
  - Why: the SDK documents that `StreamableHTTPTransport` in mount mode holds session and SSE state
    in process memory and requires a single-process server, which is incompatible with multi-worker
    Puma. Controller integration also allows a per-surface `server_context`, and `mount` would have
    required a routing-policy exception.
  - Alternatives considered: `mount transport => "/mcp"` (rejected, see above).
  - Follow-up: none.

- Decision: added a `PUBLIC_MCP` category to `docs/security/public-entrypoints.md` and
  `test/unit/security/public_entrypoint_inventory_test.rb` together.
  - Why: the inventory test fails unless a public route matches a documented category; the two are
    required to move in lockstep. The matcher is restricted to `(base|side)/(app|com|org)/mcps` so
    an MCP route appearing under Auth or a content surface would be reported as undocumented rather
    than silently covered.
  - Alternatives considered: none.
  - Follow-up: none.

## Deviations From Plan

- Change: no `ActionController::API` base was introduced, and no CSRF exception was recorded.
  - Why: measurement showed the conforming inheritance already works.
  - Risk: low, and guarded by an explicit regression test that enables forgery protection.
  - Follow-up: re-run `test/integration/mcp_forgery_protection_test.rb` on Rails upgrades.

- Change: the cross-surface tests iterate a frozen `SURFACES` constant rather than being six fully
  hand-written files.
  - Why: `testing.mdc` forbids test helper methods and prefers DAMP, but the established precedent
    for cross-surface endpoint contracts in this repository is
    `test/integration/revision_endpoint_test.rb`, which iterates exactly such a constant. Setup,
    inputs, and assertions remain visible inside each test body; no helper methods were added.
  - Risk: low.
  - Follow-up: none.

- Change: `GET`/`DELETE /mcp` are not routed and therefore return Rails' 404 rather than 405.
  - Why: `resource :mcp, only: :create` stays inside the resourceful default and needs no routing
    ADR exception. In MCP `2026-07-28` the GET stream and DELETE session termination were removed
    from the transport entirely, and 405 is only a SHOULD for older clients.
  - Risk: low; a `2025-11-25` client probing GET sees 404 instead of 405.
  - Follow-up: revisit if a client is found that requires 405.

## Review Notes

- Tests run: `test/integration/mcp_endpoint_test.rb` (12 runs, 224 assertions),
  `test/integration/mcp_forgery_protection_test.rb` (3 runs, 15 assertions),
  `test/security/invariants/` (98 runs), `test/unit/security/public_entrypoint_inventory_test.rb`
  and `authentication_mode_inventory_test.rb` (15 runs), `test/integration/routes/` plus the
  revision, cross-surface isolation, health, read-only and security-header integration suites (120
  runs), `bundle exec rubocop` on all touched files (clean), `bundle exec brakeman` (0 warnings),
  and the full `bin/rails test` suite.
- Tests not run: no live MCP client was pointed at a deployed host; verification is request-level.
- Documentation promotion needed: if MCP outlives the PoC, the `PUBLIC_MCP` reasoning and the
  liveness-only disclosure boundary should graduate from this note into an ADR.
