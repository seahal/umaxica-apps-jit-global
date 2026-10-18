# typed: false
# frozen_string_literal: true

require "test_helper"

class AuthBoundaryAuthorityMapTest < ActiveSupport::TestCase
  test "first-party RP client ids are unique and named" do
    ids = AuthBoundaryAuthorityMap.first_party_rp_client_ids

    assert_equal 12, ids.size
    assert_predicate AuthBoundaryAuthorityMap, :unique_client_ids?
    assert_includes ids, "core-app-jp"
    assert_includes ids, "edit-org-ww"
    assert_includes ids, "warp-com-jp"
    assert_includes ids, "palm-app-jp"
    assert_includes ids, "tech-org-ww"
  end

  test "deprecated shared browser client ids do not overlap the first-party RPs" do
    deprecated = AuthBoundaryAuthorityMap.deprecated_shared_browser_client_ids

    assert_includes deprecated, "sign-rp"
    assert_includes deprecated, "base-rails-rp"
    assert_predicate AuthBoundaryAuthorityMap, :no_overlap_with_deprecated_ids?
  end

  test "approved map contains regional clients plus global Edit, Palm, and Tech clients" do
    assert_equal 15, AuthBoundaryAuthorityMap.approved_rp_client_ids.size
    assert_equal 12, AuthBoundaryAuthorityMap::REGIONAL_RP_CLIENT_IDS.size
    assert_equal %w(edit-org-ww palm-app-jp tech-org-ww), AuthBoundaryAuthorityMap.approved_rp_client_ids.last(3)
    assert_equal AuthBoundaryAuthorityMap.approved_rp_client_ids.sort,
                 AuthBoundaryAuthorityMap.approved_rp_faces.keys.sort
    regions = AuthBoundaryAuthorityMap::REGIONAL_RP_CLIENT_IDS.map do |client_id|
      AuthBoundaryAuthorityMap.approved_rp_faces.fetch(client_id).fetch(:region)
    end.uniq.sort

    assert_equal %w(jp us), regions

    assert_nil AuthBoundaryAuthorityMap.approved_rp_faces.fetch("edit-org-ww").fetch(:region)
    assert_equal "palm", AuthBoundaryAuthorityMap.approved_rp_faces.fetch("palm-app-jp").fetch(:surface)
    assert_equal "client", AuthBoundaryAuthorityMap.approved_rp_faces.fetch("palm-app-jp").fetch(:actor)
    assert_equal "tech", AuthBoundaryAuthorityMap.approved_rp_faces.fetch("tech-org-ww").fetch(:surface)
    assert_equal "operator", AuthBoundaryAuthorityMap.approved_rp_faces.fetch("tech-org-ww").fetch(:actor)
  end

  test "approved regional client metadata never crosses surface or region" do
    metadata = AuthBoundaryAuthorityMap.approved_rp_faces

    assert_equal %w(client visitor operator),
                 %w(app com org).map { |face| metadata.fetch("core-#{face}-jp").fetch(:actor) }
    assert_equal "jp", metadata.fetch("core-app-jp").fetch(:region)
    assert_equal "us", metadata.fetch("core-app-us").fetch(:region)
    assert_equal "core", metadata.fetch("core-app-jp").fetch(:surface)
    assert_equal "warp", metadata.fetch("warp-app-us").fetch(:surface)
    assert_equal "operator", metadata.fetch("edit-org-ww").fetch(:actor)
  end

  test "every RP face maps to surface face and actor" do
    AuthBoundaryAuthorityMap.rp_faces.each do |client_id, meta|
      # Every exact Client ID is `<family>-<realm>-<scope>`.
      expected_surface, expected_face, = client_id.split("-")

      assert_equal expected_surface, meta.fetch(:surface)
      assert_equal expected_face, meta.fetch(:face)
      assert_includes %w(client visitor operator), meta.fetch(:actor)
      assert_equal "/oidc/callback", AuthBoundaryAuthorityMap.callback_path_for(client_id)
      assert_equal "/sign/out/completion", AuthBoundaryAuthorityMap.sign_out_path_for(client_id)
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
