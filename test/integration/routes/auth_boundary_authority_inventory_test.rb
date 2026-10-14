# typed: false
# frozen_string_literal: true

require "test_helper"

# P1 inventory lock: preserved global OAuth/JWKS/health and the written authority map.
# Live retirement of shared clients and deprecated paths is enforced in later phases against
# AuthBoundaryAuthorityMap as the source of truth.
class AuthBoundaryAuthorityInventoryTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  BASE_APP_HOST = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
  AUTH_APP_HOST = ENV.fetch("PRIVATE_AUTH_SERVICE_URL")

  test "authority map lists nine independent RPs and three separate Base self RPs without retired clients" do
    assert_equal %w(base-app-ww base-com-ww base-org-ww), AuthBoundaryAuthorityMap.base_self_rp_client_ids
    assert_equal %w(core-app core-com core-org warp-app warp-com warp-org edit-org palm-app tech-org),
                 AuthBoundaryAuthorityMap.first_party_rp_client_ids - AuthBoundaryAuthorityMap.base_self_rp_client_ids
    assert_equal 12, AuthBoundaryAuthorityMap.first_party_rp_client_ids.size
    assert_predicate AuthBoundaryAuthorityMap, :unique_client_ids?
    assert_predicate AuthBoundaryAuthorityMap, :no_overlap_with_deprecated_ids?
    AuthBoundaryAuthorityMap.retired_browser_paths.each do |path|
      assert_operator path, :start_with?, "/"
    end
  end

  test "base preserves global OAuth authorization token and discovery JWKS" do
    assert_recognizes(
      { controller: "base/app/oauth/authorizations", action: "show" },
      { path: "http://#{BASE_APP_HOST}/oauth/authorize", method: :get },
    )
    assert_recognizes(
      { controller: "base/app/oauth/tokens", action: "create" },
      { path: "http://#{BASE_APP_HOST}/oauth/token", method: :post },
    )
    assert_recognizes(
      { controller: "base/app/well_known/jwks", action: "show" },
      { path: "http://#{BASE_APP_HOST}/.well-known/jwks.json", method: :get },
    )
    assert_recognizes(
      { controller: "base/app/well_known/discoveries", action: "show" },
      { path: "http://#{BASE_APP_HOST}/.well-known/openid-configuration", method: :get },
    )
  end

  test "auth preserves Jump JWKS and health contracts" do
    assert_recognizes(
      { controller: "auth/app/well_known/jwks", action: "show" },
      { path: "http://#{AUTH_APP_HOST}/.well-known/jwks.json", method: :get },
    )
    assert_recognizes(
      { controller: "auth/app/healths", action: "show" },
      { path: "http://#{AUTH_APP_HOST}/health", method: :get },
    )
  end

  test "three actor faces exist on the written map for Auth and Base" do
    assert_equal %w(app com org), AuthBoundaryAuthorityMap::AUTH_CEREMONY_FACES
    assert_equal %w(app com org), AuthBoundaryAuthorityMap::BASE_AUTHORITY_FACES
    assert_equal "base", AuthBoundaryAuthorityMap.authority_surface
    assert_equal "auth", AuthBoundaryAuthorityMap.ceremony_surface
  end
end
