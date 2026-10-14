# typed: false
# frozen_string_literal: true

require "test_helper"

class PalmJumpSignEntryTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  setup do
    @host = ENV.fetch("PUBLIC_PALM_SERVICE_URL")
    @jump_key_name = "JWT_PALM_APP_PRIVATE_KEY"
    @jump_kid_name = "JWT_PALM_APP_ACTIVE_KID"
    @gateway_name = "PUBLIC_JUMP_GATEWAY_URL"
    @original_jump_key = ENV[@jump_key_name]
    @original_jump_kid = ENV[@jump_kid_name]
    @original_gateway = ENV[@gateway_name]

    key = Base64.strict_encode64(OpenSSL::PKey::EC.generate("secp384r1").to_der)
    ENV[@jump_key_name] = key
    ENV[@jump_kid_name] = "palm-browser-test"
    ENV[@gateway_name] = "https://jump.umaxica.net"
    JitSecurityJwtRegistry.reload!
    host! @host
    https!
  end

  teardown do
    @original_jump_key.nil? ? ENV.delete(@jump_key_name) : ENV[@jump_key_name] = @original_jump_key
    @original_jump_kid.nil? ? ENV.delete(@jump_kid_name) : ENV[@jump_kid_name] = @original_jump_kid
    @original_gateway.nil? ? ENV.delete(@gateway_name) : ENV[@gateway_name] = @original_gateway
    JitSecurityJwtRegistry.reload!
  end

  test "GET /sign is passive and does not accept native request parameters" do
    get "/sign", params: {
      ri: "jp",
      client_id: "app-ios-rp",
      redirect_uri: "umaxica://oidc/callback",
      state: "untrusted-state",
    }

    assert_response :success
    assert_equal "no-store", response.headers["Cache-Control"]
    assert_select "form[method=post][action=?]", "/sign?ri=jp"
    assert_select 'input[name="client_id"]', count: 0
    assert_select 'input[name="redirect_uri"]', count: 0
    assert_select 'input[name="state"]', count: 0
    assert_nil session[OidcSsoInitiator::OIDC_PENDING_FLOWS_SESSION_KEY]
  end

  test "CSRF-protected POST starts the server-owned Palm browser flow through Jump" do
    with_forgery_protection do
      get "/sign", params: { ri: "jp" }
      csrf_token = css_select('input[name="authenticity_token"]').first["value"]

      post "/sign?ri=jp", params: { authenticity_token: csrf_token }, headers: {
        "Origin" => "https://#{@host}",
        "Sec-Fetch-Site" => "same-origin",
        "X-CSRF-Token" => csrf_token,
      }

      assert_response :see_other
      gateway = URI.parse(response.location)

      assert_equal "https://jump.umaxica.net", "#{gateway.scheme}://#{gateway.host}"

      rt = Rack::Utils.parse_nested_query(gateway.query).fetch("rt")
      payload, = JWT.decode(rt, nil, false)
      authorization_uri = URI.parse(payload.fetch("url"))
      authorization_query = Rack::Utils.parse_nested_query(authorization_uri.query)
      client = OidcClientRegistry.find!("palm-app")
      expected_redirect_uri = client.redirect_uris.find { |value| URI.parse(value).host == @host }

      assert_equal "/oauth/authorize", authorization_uri.path
      assert_equal "palm-app", authorization_query.fetch("client_id")
      assert_equal expected_redirect_uri, authorization_query.fetch("redirect_uri")
      assert_equal "code", authorization_query.fetch("response_type")
      assert_equal "S256", authorization_query.fetch("code_challenge_method")
      assert_match(/\A[A-Za-z0-9_-]{43}\z/, authorization_query.fetch("code_challenge"))
      assert_nil authorization_query["code_verifier"]

      state = authorization_query.fetch("state")
      flow = session.fetch(OidcSsoInitiator::OIDC_PENDING_FLOWS_SESSION_KEY).fetch(state)

      assert_equal authorization_query.fetch("nonce"), flow.fetch("nonce")
      assert_predicate flow.fetch("code_verifier"), :present?
      assert_operator response.headers["Set-Cookie"].to_s.bytesize, :<, 4096
    end
  end

  private

  def with_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    yield
  ensure
    ActionController::Base.allow_forgery_protection =
      Rails.configuration.action_controller.allow_forgery_protection
  end
end
