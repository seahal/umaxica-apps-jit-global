# typed: false
# frozen_string_literal: true

require "test_helper"

# Two value objects that decide which surface something belongs to. Both are
# exhaustive by construction and both refuse an unmapped value rather than
# defaulting, because a default here silently serves one surface's data from
# another's endpoint.
class McpSurfaceIdentityAndTokenCodecTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "an MCP identity is refused for a realm or surface that does not exist" do
    realm_error = assert_raises(ArgumentError) { McpSurfaceIdentity.new(realm: "martian", surface: "app") }

    assert_match(/unsupported MCP realm: martian/, realm_error.message)

    surface_error = assert_raises(ArgumentError) { McpSurfaceIdentity.new(realm: "base", surface: "martian") }

    assert_match(/unsupported MCP surface: martian/, surface_error.message)
  end

  test "each surface reports its own health profile and server name" do
    {
      "app" => ::Health::Profiles::App,
      "com" => ::Health::Profiles::Com,
      "org" => ::Health::Profiles::Org,
    }.each do |surface, profile|
      identity = McpSurfaceIdentity.new(realm: "base", surface: surface)

      assert_equal profile, identity.health_profile
      assert_equal "umaxica-base-#{surface}", identity.server_name
      assert_equal({ realm: "base", surface: surface }, identity.as_public_json)
    end
  end

  # Identities are compared by value and used as hash keys, so two identities for
  # the same pair have to be interchangeable and two for different pairs must not.
  test "identities compare and hash by realm and surface" do
    base_app = McpSurfaceIdentity.new(realm: "base", surface: "app")
    same = McpSurfaceIdentity.new(realm: "base", surface: "app")
    other_surface = McpSurfaceIdentity.new(realm: "base", surface: "com")
    other_realm = McpSurfaceIdentity.new(realm: "side", surface: "app")

    assert_equal base_app, same
    assert_equal base_app.hash, same.hash
    assert_not_equal base_app, other_surface
    assert_not_equal base_app, other_realm
    assert_not_equal base_app, "base/app"
    assert_equal 1, [base_app, same].uniq.size
    assert_equal 3, [base_app, same, other_surface, other_realm].uniq.size
  end
end
