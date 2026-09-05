# typed: false
# frozen_string_literal: true

require "test_helper"

# Contract for the Model Context Protocol endpoint. Base and Side each expose POST /mcp on their
# app, com, and org hosts. Every endpoint speaks the same protocol and offers the same three
# read-only tools, but must report its own realm and surface and must never answer for another.
class McpEndpointTest < ActionDispatch::IntegrationTest
  counts_rate_limits!
  JSON_HEADERS = {
    "CONTENT_TYPE" => "application/json",
    "HTTP_ACCEPT" => "application/json, text/event-stream",
  }.freeze

  SURFACES = [
    { host: ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost"),
      controller: "base/app/mcps",
      realm: "base",
      surface: "app", },
    { host: ENV.fetch("PUBLIC_BASE_CORPORATE_URL", "base.com.localhost"),
      controller: "base/com/mcps",
      realm: "base",
      surface: "com", },
    { host: ENV.fetch("PUBLIC_BASE_STAFF_URL", "base.org.localhost"),
      controller: "base/org/mcps",
      realm: "base",
      surface: "org", },
    { host: ENV.fetch("PUBLIC_SIDE_SERVICE_URL", "side.app.localhost"),
      controller: "side/app/mcps",
      realm: "side",
      surface: "app", },
    { host: ENV.fetch("PUBLIC_SIDE_CORPORATE_URL", "side.com.localhost"),
      controller: "side/com/mcps",
      realm: "side",
      surface: "com", },
    { host: ENV.fetch("PUBLIC_SIDE_STAFF_URL", "side.org.localhost"),
      controller: "side/org/mcps",
      realm: "side",
      surface: "org", },
  ].freeze

  test "every surface host routes POST /mcp to its own mcps controller" do
    SURFACES.each do |surface|
      recognized = Rails.application.routes.recognize_path("http://#{surface[:host]}/mcp", method: :post)

      assert_equal surface[:controller], recognized[:controller]
      assert_equal "create", recognized[:action]
    end
  end

  test "no surface host routes /mcp to another surface's controller" do
    routed =
      SURFACES.to_h do |surface|
        [surface[:host],
         Rails.application.routes.recognize_path("http://#{surface[:host]}/mcp", method: :post)[:controller],]
      end

    assert_equal SURFACES.pluck(:controller).sort, routed.values.sort
    assert_equal routed.values.uniq.size, routed.values.size, "two hosts share one MCP controller"
  end

  test "every mcps controller is bare and uses the shared transport concern" do
    SURFACES.each do |surface|
      controller_class = "#{surface[:controller]}_controller".camelize.constantize

      assert_equal :bare, controller_class.const_get(:AUTHENTICATION_MODE, false)
      assert_includes controller_class.ancestors, McpEndpoint
    end
  end

  test "every surface lists the same three read-only tools" do
    SURFACES.each do |surface|
      host!(surface[:host])

      post("/mcp", params: { jsonrpc: "2.0", id: 1, method: "tools/list" }.to_json, headers: JSON_HEADERS)

      assert_response :success
      tools = response.parsed_body.dig("result", "tools")

      assert_equal %w(service_info system_liveness system_version), tools.map { |tool| tool["name"] }.sort
      tools.each do |tool|
        assert tool.dig("annotations", "readOnlyHint"), "#{tool["name"]} must be read-only"
        assert_not tool.dig("annotations", "destructiveHint"), "#{tool["name"]} must not be destructive"
      end
    end
  end

  test "service_info reports the realm and surface of its own endpoint" do
    SURFACES.each do |surface|
      host!(surface[:host])

      post(
        "/mcp",
        params: { jsonrpc: "2.0",
                  id: 2,
                  method: "tools/call",
                  params: { name: "service_info", arguments: {} }, }.to_json,
        headers: JSON_HEADERS,
      )

      assert_response :success
      result = response.parsed_body.fetch("result")

      assert_not result["isError"], "service_info must not report a tool error"
      assert_equal(
        { "realm" => surface[:realm], "surface" => surface[:surface] },
        JSON.parse(result.fetch("content").first.fetch("text")),
      )
    end
  end

  test "system_liveness reports process status without dependency or topology detail" do
    SURFACES.each do |surface|
      host!(surface[:host])

      post(
        "/mcp",
        params: { jsonrpc: "2.0",
                  id: 3,
                  method: "tools/call",
                  params: { name: "system_liveness", arguments: {} }, }.to_json,
        headers: JSON_HEADERS,
      )

      assert_response :success
      payload = JSON.parse(response.parsed_body.dig("result", "content").first.fetch("text"))

      assert_equal %w(status), payload.keys
      assert_equal "ok", payload.fetch("status")
    end
  end

  test "system_version reports only the deployment revision" do
    SURFACES.each do |surface|
      host!(surface[:host])

      post(
        "/mcp",
        params: { jsonrpc: "2.0",
                  id: 4,
                  method: "tools/call",
                  params: { name: "system_version", arguments: {} }, }.to_json,
        headers: JSON_HEADERS,
      )

      assert_response :success
      payload = JSON.parse(response.parsed_body.dig("result", "content").first.fetch("text"))

      assert_equal %w(revision), payload.keys
      assert_equal Rails.application.revision&.to_s, payload.fetch("revision")
    end
  end

  test "an unknown tool is refused on every surface" do
    SURFACES.each do |surface|
      host!(surface[:host])

      post(
        "/mcp",
        params: { jsonrpc: "2.0",
                  id: 5,
                  method: "tools/call",
                  params: { name: "drop_everything", arguments: {} }, }.to_json,
        headers: JSON_HEADERS,
      )

      body = response.parsed_body

      assert body.key?("error") || body.dig("result", "isError"),
             "unknown tool must not succeed on #{surface[:host]}"
    end
  end

  test "an unsupported JSON-RPC method returns a protocol error on every surface" do
    SURFACES.each do |surface|
      host!(surface[:host])

      post(
        "/mcp", params: { jsonrpc: "2.0", id: 6, method: "nonexistent/method" }.to_json,
                headers: JSON_HEADERS,
      )

      assert_equal(-32_601, response.parsed_body.dig("error", "code"))
    end
  end

  test "malformed JSON is refused without leaking internals on every surface" do
    SURFACES.each do |surface|
      host!(surface[:host])

      post("/mcp", params: "{not json", headers: JSON_HEADERS)

      assert_not_includes response.body, "ActionDispatch"
      assert_not_includes response.body, "/home/"
      assert_no_match(/backtrace/i, response.body)
    end
  end

  test "a request carrying a foreign Origin is refused on every surface" do
    SURFACES.each do |surface|
      host!(surface[:host])

      post(
        "/mcp", params: { jsonrpc: "2.0", id: 7, method: "tools/list" }.to_json,
                headers: JSON_HEADERS.merge("HTTP_ORIGIN" => "https://attacker.example.com"),
      )

      assert_response :forbidden
    end
  end

  test "the endpoint is stateless: repeated requests succeed without a session identifier" do
    SURFACES.each do |surface|
      host!(surface[:host])

      3.times do |attempt|
        post(
          "/mcp", params: { jsonrpc: "2.0", id: attempt, method: "tools/list" }.to_json,
                  headers: JSON_HEADERS,
        )

        assert_response :success
        assert_nil response.headers["Mcp-Session-Id"]
      end
    end
  end

  # These endpoints are unauthenticated and inherit from `BareController`, which deliberately
  # bypasses the application-wide default rule, so the limiter each controller declares is the only
  # thing bounding an anonymous caller. The store is shared across the suite, so it is cleared on
  # both ends: without the trailing clear, the exhausted budget would leak into whichever test the
  # random order runs next.
  test "an anonymous caller is rate limited per endpoint once the budget is spent" do
    Rails.configuration.x.rate_limit.fetch(:store).clear
    host!(SURFACES.first.fetch(:host))

    60.times do |attempt|
      post("/mcp", params: { jsonrpc: "2.0", id: attempt, method: "tools/list" }.to_json, headers: JSON_HEADERS)

      assert_response :success, "request #{attempt + 1} of the allowed budget was refused"
    end

    post("/mcp", params: { jsonrpc: "2.0", id: 61, method: "tools/list" }.to_json, headers: JSON_HEADERS)

    # A 429 is refused before the MCP transport runs, so it is not a JSON-RPC response and the
    # protocol exemption does not cover it. Which rule fired is deliberately not disclosed; the
    # per-endpoint budget is proven by the sibling test instead.
    assert_response :too_many_requests
    assert_equal "60", response.headers["Retry-After"]
    assert_equal "application/problem+json", response.media_type
    assert_equal "urn:umaxica:problem:rate-limited", response.parsed_body.fetch("type")
    assert_not_includes response.body, "base_app_mcp_request_ip"
  ensure
    Rails.configuration.x.rate_limit.fetch(:store).clear
  end

  test "each endpoint has its own rate limit budget" do
    Rails.configuration.x.rate_limit.fetch(:store).clear
    host!(SURFACES.first.fetch(:host))

    61.times do |attempt|
      post("/mcp", params: { jsonrpc: "2.0", id: attempt, method: "tools/list" }.to_json, headers: JSON_HEADERS)
    end

    assert_response :too_many_requests

    SURFACES.drop(1).each do |surface|
      host!(surface.fetch(:host))

      post("/mcp", params: { jsonrpc: "2.0", id: 1, method: "tools/list" }.to_json, headers: JSON_HEADERS)

      assert_response :success, "#{surface[:host]} shares a budget with #{SURFACES.first.fetch(:host)}"
    end
  ensure
    Rails.configuration.x.rate_limit.fetch(:store).clear
  end
end
