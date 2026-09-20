# typed: false
# frozen_string_literal: true

require "test_helper"

# `POST /mcp` was withdrawn on 2026-09-19 (adr/mcp-endpoint-withdrawal.md): an unauthenticated
# JSON-RPC entry point on six user-facing hosts, kept in the repository but unrouted until a
# follow-up ADR records its authentication, transport review and tool-ownership rules. This pins
# that the entry point stays off on every host it used to answer, so restoring it has to be a
# deliberate route change reviewed against that ADR.
class McpEndpointWithdrawalTest < ActionDispatch::IntegrationTest
  WITHDRAWN_HOSTS = [
    ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost"),
    ENV.fetch("PUBLIC_BASE_CORPORATE_URL", "base.com.localhost"),
    ENV.fetch("PUBLIC_BASE_STAFF_URL", "base.org.localhost"),
    ENV.fetch("PUBLIC_SIDE_SERVICE_URL", "wide.app.localhost"),
    ENV.fetch("PUBLIC_SIDE_CORPORATE_URL", "wide.com.localhost"),
    ENV.fetch("PUBLIC_SIDE_STAFF_URL", "wide.org.localhost"),
  ].freeze

  test "POST /mcp is not routed on any host that used to serve it" do
    WITHDRAWN_HOSTS.each do |host|
      assert_raises(ActionController::RoutingError, host) do
        Rails.application.routes.recognize_path("http://#{host}/mcp", method: :post)
      end
    end
  end

  test "a JSON-RPC request to a withdrawn endpoint is answered not found" do
    WITHDRAWN_HOSTS.each do |host|
      host! host
      post "/mcp",
           params: { jsonrpc: "2.0", id: 1, method: "tools/list" }.to_json,
           headers: { "Host" => host, "CONTENT_TYPE" => "application/json", "HTTP_ACCEPT" => "application/json" }

      assert_response :not_found, host
    end
  end
end
