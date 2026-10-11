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

  test "every RP face maps to surface face and actor" do
    AuthBoundaryAuthorityMap.rp_faces.each do |client_id, meta|
      assert_equal client_id.split("-").first, meta.fetch(:surface)
      assert_equal client_id.split("-").last, meta.fetch(:face)
      assert_includes %w(client visitor operator), meta.fetch(:actor)
      assert_equal "/sign/in/callback", AuthBoundaryAuthorityMap.callback_path_for(client_id)
      assert_equal "/sign/out", AuthBoundaryAuthorityMap.sign_out_path_for(client_id)
    end
  end

  test "retired browser paths are listed for inventory enforcement" do
    paths = AuthBoundaryAuthorityMap.retired_browser_paths

    assert_includes paths, "/dashboard"
    assert_includes paths, "/lobby"
    assert_includes paths, "/sign/out/complete"
  end

  test "Base is the authority surface and Auth is the ceremony surface" do
    assert_equal "base", AuthBoundaryAuthorityMap.authority_surface
    assert_equal "auth", AuthBoundaryAuthorityMap.ceremony_surface
    assert_equal %w(app com org), AuthBoundaryAuthorityMap::BASE_AUTHORITY_FACES
    assert_equal %w(app com org), AuthBoundaryAuthorityMap::AUTH_CEREMONY_FACES
  end
end
