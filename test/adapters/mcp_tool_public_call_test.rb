# typed: false
# frozen_string_literal: true

require "test_helper"

class McpToolPublicCallTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "liveness reports only the process status for its declared surface" do
    response = McpLivenessTool.call(
      server_context: { surface_identity: McpSurfaceIdentity.new(realm: "base", surface: "org") },
    )

    assert_equal [{ type: "text", text: { status: "ok" }.to_json }], response.content
  end

  test "service info reports the declared realm and surface" do
    response = McpServiceInfoTool.call(
      server_context: { surface_identity: McpSurfaceIdentity.new(realm: "warp", surface: "app") },
    )

    assert_equal [{ type: "text", text: { realm: "warp", surface: "app" }.to_json }], response.content
  end

  test "version reports only the configured application revision or null" do
    response = McpVersionTool.call(server_context: {})

    assert_equal [{ type: "text", text: { revision: Rails.application.revision&.to_s }.to_json }], response.content
  end
end
