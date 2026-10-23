# typed: false
# frozen_string_literal: true

require "test_helper"

# D-145, D-147, D-148: `redirect_uri` exact match, local errors before a valid redirect URI,
# redirected errors after it, direct 400 for unsupported `prompt`, `code_challenge` shape.
class BaseOauthRedirectUriConformanceTest < ActionDispatch::IntegrationTest
  include OidcAuthorizationResponseHelper

  CLIENT_ID = "core-app-jp"

  setup do
    @host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    host!(@host)
    @registered = OidcClientRegistry.find!(CLIENT_ID).redirect_uris_by_realm.fetch("client").first
  end

  test "a redirect_uri that differs from the registered string in any part is refused locally" do
    uri = URI.parse(@registered)
    variants = [
      "https://evil.example/oidc/callback",
      @registered.sub("https://", "http://"),
      "#{uri.scheme}://#{uri.host}:443#{uri.path}",
      "#{uri.scheme}://#{uri.host}:3001#{uri.path}",
      "#{@registered}/",
      @registered.sub("/oidc/callback", "/OIDC/callback"),
      "#{@registered}?x=1",
      "#{@registered}#frag",
      OidcClientRegistry.find!("core-com-jp").redirect_uris_by_realm.fetch("visitor").first,
    ]
    variants.each do |redirect_uri|
      get "/oauth/authorize", params: authorize_params(redirect_uri:), headers: { "Host" => @host }

      assert_equal [400, nil], [response.status, response.headers["Location"]], redirect_uri
    end
    get "/oauth/authorize", params: authorize_params.except(:redirect_uri), headers: { "Host" => @host }

    assert_equal [400, nil], [response.status, response.headers["Location"]]
  end

  test "an invalid redirect_uri combined with another error is still never redirected to" do
    get "/oauth/authorize", params: authorize_params(redirect_uri: "https://evil.example/cb", scope: "profile")
      .except(:state), headers: { "Host" => @host }

    assert_equal [400, nil], [response.status, response.headers["Location"]]
    get "/oauth/authorize", params: authorize_params(client_id: "not-registered"), headers: { "Host" => @host }

    assert_equal [400, nil], [response.status, response.headers["Location"]]
  end

  test "post-validation errors are redirected to the registered redirect_uri" do
    {
      { response_type: "token" } => "unsupported_response_type",
      { scope: "profile" } => "invalid_request",
      { scope: "openid palm.read" } => "invalid_scope",
      { code_challenge_method: "plain" } => "invalid_request",
      { nonce: "" } => "invalid_request",
      { max_age: "-1" } => "invalid_request",
    }.each do |overrides, error|
      get "/oauth/authorize", params: authorize_params(**overrides), headers: { "Host" => @host }

      assert_oidc_error_redirect(error:, redirect_uri: @registered)
    end
  end

  test "unsupported or combined prompt values get a direct 400 from the OP" do
    ["consent", "select_account", "unknown", "none login", "login create"].each do |prompt|
      get "/oauth/authorize", params: authorize_params(prompt:), headers: { "Host" => @host }

      assert_equal [400, nil], [response.status, response.headers["Location"]], prompt
      assert_equal "invalid_request", response.parsed_body["error"]
      assert_match(/prompt/, response.parsed_body["error_description"])
    end
  end

  test "code_challenge must be exactly 43 base64url characters" do
    valid = "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM"
    [valid[0, 42], "#{valid}A", "#{valid[0, 42]}=", "#{valid[0, 42]}+", "#{valid[0, 42]}/"].each do |challenge|
      get "/oauth/authorize", params: authorize_params(code_challenge: challenge), headers: { "Host" => @host }

      assert_oidc_error_redirect(error: "invalid_request", redirect_uri: @registered)
    end
  end

  test "Discovery advertises prompt_values_supported per realm" do
    assert_equal %w(none login create), OidcDiscoveryDocument.for_resource_type("client")[:prompt_values_supported]
    assert_equal %w(none login create), OidcDiscoveryDocument.for_resource_type("visitor")[:prompt_values_supported]
    assert_equal %w(none login), OidcDiscoveryDocument.for_resource_type("operator")[:prompt_values_supported]
  end

  test "the response keeps a registered query unchanged and appends the response parameters" do
    url = OidcAuthorizeCoordinator.rp_redirect_url(
      redirect_uri: "https://rp.example/cb?tenant=a%20b", resource_type: "client",
      response_params: [%w(code c1), %w(state s1)],
    )

    assert url.start_with?("https://rp.example/cb?tenant=a%20b&code=c1&state=s1&iss=")
  end

  private

  def authorize_params(**overrides)
    {
      response_type: "code",
      client_id: CLIENT_ID,
      redirect_uri: @registered,
      code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
      code_challenge_method: "S256",
      scope: "openid profile",
      state: "state",
      nonce: "nonce",
    }.merge(overrides)
  end
end
