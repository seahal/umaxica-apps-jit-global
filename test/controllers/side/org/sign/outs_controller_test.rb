# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class Side::Org::Sign::OutsControllerTest < ActionDispatch::IntegrationTest
  fixtures :clients, :client_token_kinds

  setup do
    host! ENV.fetch("PUBLIC_SIDE_STAFF_URL")
  end

  test "get sign out renders confirmation without mutation" do
    user = clients(:one)
    token = ClientToken.create!(user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)

    get edit_side_org_sign_out_url(ri: "jp"), headers: session_headers(user, token)

    assert_response :success
    assert_select "form[action*=?][method=?]", side_org_sign_out_path, "post"
    assert_predicate token.reload, :currently_usable?
  end

  test "post sign out redirects to base oidc logout with completion state" do
    user = clients(:one)
    token = ClientToken.create!(user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    cookies[AuthenticationBase::REFRESH_COOKIE_KEY] = token.rotate_refresh_token!

    post side_org_sign_out_url(ri: "jp"), headers: session_headers(user, token)

    assert_response :success
    assert_select "form#sign-out-handoff-form[method=?]", "post", count: 1
    location = URI.parse(css_select("form#sign-out-handoff-form").first["action"])
    query = Rack::Utils.parse_nested_query(location.query.to_s)

    assert_equal ENV.fetch("PUBLIC_BASE_STAFF_URL", "www.org.localhost"), location.host
    assert_equal "/oidc/logout", location.path
    assert_predicate query["id_token_hint"], :present?
    assert_equal side_org_sign_out_url(ri: "jp", protocol: "https"), query["post_logout_redirect_uri"]
    assert_predicate query["logout_challenge"], :present?
  end

  test "get sign out without a one-shot notice is not found" do
    get side_org_sign_out_url(ri: "jp")

    assert_response :not_found
  end

  private

  def session_headers(user, token)
    host = ENV.fetch("PUBLIC_SIDE_STAFF_URL")
    token_encoded = AuthenticationToken.encode(
      user, host: host, session_public_id: token.public_id, resource_type: "client",
            jwt_issuer_id: "surface:SIGN_APP",
    )
    { "Authorization" => "Bearer #{token_encoded}" }
  end
end
