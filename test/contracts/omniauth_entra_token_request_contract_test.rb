# typed: false
# frozen_string_literal: true

require "test_helper"

# Pins the wire shape rack-oauth2 produces for the Entra token exchange.
#
# The strategy passes `client_auth_method: :client_secret_post`, which rack-oauth2
# has no named branch for: it reaches the `else` in
# Client#authenticated_context_from and merges the client credentials into the
# POST body. Asserting only on the symbol the strategy passes would not notice a
# rack-oauth2 upgrade that adds a branch for that name, or that changes the
# fall-through. This test drives the real Rack::OAuth2::Client and inspects the
# request it builds, with the HTTP call stubbed -- the suite makes no network
# call to login.microsoftonline.com.
class OmniauthEntraTokenRequestContractTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  TENANT_ID = "11111111-2222-3333-4444-555555555555"
  CLIENT_ID = "22222222-3333-4444-5555-666666666666"
  # Not a real credential: a fixed literal used only to prove it lands in the
  # body and not in an Authorization header.
  CLIENT_SECRET = "test-only-client-secret-value"

  test "the token request carries the client credentials in the POST body and no Authorization header" do
    headers, params = capture_token_request(client_auth_method: :client_secret_post)

    assert_equal CLIENT_ID, params[:client_id], "client_id must be in the token request body"
    assert_equal CLIENT_SECRET, params[:client_secret], "client_secret must be in the token request body"
    assert_not headers.key?("Authorization"), "client_secret_post must not send an Authorization header"
    assert_equal "authorization-code", params[:code]
    assert_equal "pkce-verifier-value", params[:code_verifier]
    assert_equal :authorization_code, params[:grant_type]
    assert_equal ExternalAuthenticationEntraRedirectUri.call, params[:redirect_uri]
  end

  test "no client assertion is generated for client_secret_post" do
    _headers, params = capture_token_request(client_auth_method: :client_secret_post)

    assert_not params.key?(:client_assertion)
    assert_not params.key?(:client_assertion_type)
  end

  # Regression detector: if a rack-oauth2 upgrade ever made the strategy's mode
  # behave like basic again, this pins what basic actually looks like, so the
  # test above fails for a legible reason rather than silently passing.
  test "client_secret_basic would instead send an Authorization header and omit the body credentials" do
    headers, params = capture_token_request(client_auth_method: :basic)

    assert headers.key?("Authorization"), "sanity check: :basic is still header-based in this rack-oauth2"
    assert_not params.key?(:client_secret)
  end

  test "the strategy asks for the client_secret_post mode" do
    source = Rails.root.join("lib/omniauth/strategies/umaxica_entra.rb").read

    assert_includes source, "client_auth_method: :client_secret_post"
    assert_not_includes source, "client_auth_method: :basic"
  end

  private

  # Sentinel raised from the stubbed transport. The assertions are about the
  # request rack-oauth2 builds, so the exchange is cut off at the wire instead of
  # faking a token response -- and nothing can reach the network.
  class RequestCaptured < StandardError; end

  # Runs the real Rack::OAuth2::Client through the token exchange with the HTTP
  # POST replaced, and returns the [headers, params] rack-oauth2 built.
  def capture_token_request(client_auth_method:)
    client = build_client
    captured_headers = nil
    captured_params = nil

    fake_http = Object.new
    fake_http.define_singleton_method(:post) do |_uri, params, headers|
      captured_params = params
      captured_headers = headers
      raise RequestCaptured
    end

    assert_raises(RequestCaptured) do
      Rack::OAuth2.stub(:http_client, fake_http) do
        client.access_token!(
          scope: %i(openid profile),
          client_auth_method: client_auth_method,
          code_verifier: "pkce-verifier-value",
        )
      end
    end

    [captured_headers || {}, captured_params || {}]
  end

  def build_client
    client = Rack::OAuth2::Client.new(
      identifier: CLIENT_ID,
      secret: CLIENT_SECRET,
      scheme: "https",
      host: "login.microsoftonline.com",
      port: 443,
      authorization_endpoint: "/#{TENANT_ID}/oauth2/v2.0/authorize",
      token_endpoint: "/#{TENANT_ID}/oauth2/v2.0/token",
      redirect_uri: ExternalAuthenticationEntraRedirectUri.call,
    )
    client.authorization_code = "authorization-code"
    client
  end
end
