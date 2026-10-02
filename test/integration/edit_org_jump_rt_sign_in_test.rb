# typed: false
# frozen_string_literal: true

require "test_helper"

class EditOrgJumpRtSignInTest < ActionDispatch::IntegrationTest
  test "canonical Edit starts its same-site OIDC admission without a Jump RT" do
    host! "edit.umaxica.org"
    https!
    get "/publishing/info/org/entries", params: { ri: "jp" }

    assert_response :found
    location = URI.parse(response.location)
    query = Rack::Utils.parse_nested_query(location.query)
    assert_equal "www.umaxica.org", location.host
    assert_equal "/oauth/authorize", location.path
    assert_equal "edit-org", query.fetch("client_id")
    assert_equal "https://edit.umaxica.org/sign/callback", query.fetch("redirect_uri")
    assert_equal "S256", query.fetch("code_challenge_method")
    assert_predicate query.fetch("state"), :present?
    assert_predicate query.fetch("nonce"), :present?
    assert_not query.key?("rt")
  end

  test "cross-site Edit admission raises rather than falling back to a Jump issuer" do
    host! "edit.org.localhost"
    assert_raises(JumpRtConfigurationError) do
      get "/publishing/info/org/entries", params: { ri: "jp" }
    end
  end
end
