# typed: false
# frozen_string_literal: true

require "test_helper"

class AuthBoundaryAuthorityMapTest < ActiveSupport::TestCase
  test "seven first-party RP client ids are unique and named" do
    ids = AuthBoundaryAuthorityMap.first_party_rp_client_ids

    assert_equal 7, ids.size
    assert_predicate AuthBoundaryAuthorityMap, :unique_client_ids?
    assert_includes ids, "core-app"
    assert_includes ids, "edit-org"
    assert_includes ids, "side-com"
  end

  test "deprecated shared browser client ids do not overlap the seven RPs" do
    deprecated = AuthBoundaryAuthorityMap.deprecated_shared_browser_client_ids

    assert_includes deprecated, "sign-rp"
    assert_includes deprecated, "base-rails-rp"
    assert_predicate AuthBoundaryAuthorityMap, :no_overlap_with_deprecated_ids?
  end

  test "approved regional target contains twelve regional clients and one global edit client" do
    assert_equal 13, AuthBoundaryAuthorityMap.approved_rp_client_ids.size
    assert_equal 12, AuthBoundaryAuthorityMap::REGIONAL_RP_CLIENT_IDS.size
    assert_equal "edit-org", AuthBoundaryAuthorityMap.approved_rp_client_ids.last
    assert_equal AuthBoundaryAuthorityMap.approved_rp_client_ids.sort,
                 AuthBoundaryAuthorityMap.approved_rp_faces.keys.sort
    regions = AuthBoundaryAuthorityMap::REGIONAL_RP_CLIENT_IDS.map do |client_id|
      AuthBoundaryAuthorityMap.approved_rp_faces.fetch(client_id).fetch(:region)
    end.uniq.sort

    assert_equal %w(jp us), regions

    assert_nil AuthBoundaryAuthorityMap.approved_rp_faces.fetch("edit-org").fetch(:region)
  end

  test "approved regional client metadata never crosses surface or region" do
    metadata = AuthBoundaryAuthorityMap.approved_rp_faces

    assert_equal %w(client visitor operator),
                 %w(app com org).map { |face| metadata.fetch("core-#{face}-jp").fetch(:actor) }
    assert_equal "jp", metadata.fetch("core-app-jp").fetch(:region)
    assert_equal "us", metadata.fetch("core-app-us").fetch(:region)
    assert_equal "core", metadata.fetch("core-app-jp").fetch(:surface)
    assert_equal "warp", metadata.fetch("side-app-us").fetch(:surface)
    assert_equal "operator", metadata.fetch("edit-org").fetch(:actor)
  end

  test "every RP face maps to surface face and actor" do
    AuthBoundaryAuthorityMap.rp_faces.each do |client_id, meta|
      expected_surface = client_id.start_with?("side-") ? "warp" : client_id.split("-").first

      assert_equal expected_surface, meta.fetch(:surface)
      assert_equal client_id.split("-").last, meta.fetch(:face)
      assert_includes %w(client visitor operator), meta.fetch(:actor)
      assert_equal "/sign/callback", AuthBoundaryAuthorityMap.callback_path_for(client_id)
      assert_equal "/sign/out", AuthBoundaryAuthorityMap.sign_out_path_for(client_id)
    end
  end

  test "retired browser paths are listed for inventory enforcement" do
    paths = AuthBoundaryAuthorityMap.retired_browser_paths

    assert_includes paths, "/lobby"
    assert_includes paths, "/sign/out/complete"
    assert_includes paths, "/sign/in"
    assert_includes paths, "/sign/in/callback"
    assert_includes AuthBoundaryAuthorityMap.retired_auth_browser_paths, "/dashboard"
  end

  test "Base is the authority surface and Auth is the ceremony surface" do
    assert_equal "base", AuthBoundaryAuthorityMap.authority_surface
    assert_equal "auth", AuthBoundaryAuthorityMap.ceremony_surface
    assert_equal %w(app com org), AuthBoundaryAuthorityMap::BASE_AUTHORITY_FACES
    assert_equal %w(app com org), AuthBoundaryAuthorityMap::AUTH_CEREMONY_FACES
  end
end
