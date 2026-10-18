# typed: false
# frozen_string_literal: true

# Shared MCP transport adapter for the Base and Warp surfaces.
#
# The six MCP endpoints share one protocol adapter and one tool set; what differs between them is
# the `McpSurfaceIdentity` each concrete controller declares. Surface separation is preserved by
# routing (each endpoint is reachable only under its own host constraint) and by passing the
# identity explicitly through `server_context`, never by inspecting the request inside a tool.
#
# The server is built per request with `stateless: true`. The alternative mount-style integration
# keeps session and SSE state in process memory and requires a single-process server, which is
# incompatible with this deployment's multi-worker Puma.
module McpEndpoint
  extend ActiveSupport::Concern

  # Surface to host-family suffix. `boot_config` names host families by audience rather than by the
  # app/com/org surface labels used in routing.
  HOST_FAMILY_SUFFIXES = { "app" => "service", "com" => "corporate", "org" => "staff" }.freeze

  class_methods do
    # Rails-native per-IP limiter for the unauthenticated MCP endpoint.
    #
    # `BareController` deliberately bypasses the application-wide default rule that
    # `ApplicationController` declares, so an MCP endpoint carries no limit unless it declares one.
    # The scope is per realm and surface, so traffic against one endpoint cannot exhaust another's
    # budget. The ceiling is generous because a single MCP session legitimately issues several
    # requests in a row (`initialize`, `tools/list`, then tool calls).
    def rate_limit_mcp_endpoint(realm:, surface:)
      rule_scope = "#{realm}_#{surface}_mcp"

      rate_limit(
        to: 60,
        within: 1.minute,
        by: -> { request.remote_ip },
        scope: rule_scope,
        name: "request_ip",
        store: rate_limit_store,
        only: :create,
        with: -> { render_rate_limited(retry_after: 60) },
      )
    end
  end

  private

  def render_mcp_response
    transport = MCP::Server::Transports::StreamableHTTPTransport.new(
      mcp_server, stateless: true, allowed_hosts: mcp_allowed_hosts,
    )
    status, headers, body = transport.handle_request(request)

    headers.each { |name, value| response.set_header(name, value) }
    response.set_header("Cache-Control", "no-store")

    payload = Array(body).first

    return head(status) if payload.blank?

    render(json: payload, status: status)
  end

  def mcp_server
    MCP::Server.new(
      name: mcp_surface_identity.server_name,
      version: Rails.application.revision&.to_s,
      tools: [McpLivenessTool, McpVersionTool, McpServiceInfoTool],
      server_context: { surface_identity: mcp_surface_identity },
    )
  end

  # The transport rejects a `Host` outside this list with 403 to block DNS rebinding. The list
  # mirrors the host constraint that already guards the route, so an endpoint accepts exactly the
  # hosts it is routed under. Disabling the check instead would be a silent fallback.
  def mcp_allowed_hosts
    suffix = HOST_FAMILY_SUFFIXES.fetch(mcp_surface_identity.surface)
    boot_host = Rails.configuration.x.boot_config.fetch(:hosts)
      .public_send("#{mcp_surface_identity.realm}_#{suffix}").host

    [boot_host, "#{mcp_surface_identity.realm}.#{mcp_surface_identity.surface}.localhost"].compact
  end

  # Declared by each concrete controller; there is no default, so an endpoint that forgets to name
  # its surface fails loudly rather than answering for an arbitrary one.
  def mcp_surface_identity
    raise NotImplementedError, "#{self.class.name} must define #mcp_surface_identity"
  end
end
