# typed: false
# frozen_string_literal: true

module Warp
  module Org
    # Model Context Protocol endpoint hosted by Warp; its established realm identifier remains side.
    #
    # Unauthenticated by design: it exposes only liveness, deployment revision, and this endpoint's
    # own realm/surface labels. No database, session, actor, or environment data is reachable
    # through it, and it offers no write tool.
    class McpsController < BareController
      include ::McpEndpoint

      AUTHENTICATION_MODE = :bare

      rate_limit_mcp_endpoint(realm: "side", surface: "org")

      def create
        render_mcp_response
      end

      private

      def mcp_surface_identity
        McpSurfaceIdentity.new(realm: "side", surface: "org")
      end
    end
  end
end
