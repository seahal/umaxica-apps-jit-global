# typed: false
# frozen_string_literal: true

require "test_helper"

# RFC 6749 section 4.1.2.1 expects spec-level descriptions for a malformed authorization request,
# and the controller deliberately answers RecordNotFound with a fixed description so a bad
# login_challenge cannot be used to probe stored data. Both halves are asserted here.
class Base::Com::Oauth::AuthorizationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = configured_host(:base_corporate)
  end

  test "a request with no parameters is refused as an invalid request" do
    get base_com_oauth_authorization_url(host: @host), headers: host_headers(@host)

    assert_response :bad_request
    assert_equal "invalid_request", response.parsed_body["error"]
  end

  test "a response_type other than code is refused" do
    get base_com_oauth_authorization_url(host: @host, **authorize_params(response_type: "token")),
        headers: host_headers(@host)

    assert_response :bad_request
    assert_equal "invalid_request", response.parsed_body["error"]
    assert_equal "response_type must be 'code'", response.parsed_body["error_description"]
  end

  test "a missing code challenge is refused" do
    params = authorize_params.except(:code_challenge)

    get base_com_oauth_authorization_url(host: @host, **params), headers: host_headers(@host)

    assert_response :bad_request
    assert_equal "code_challenge is required", response.parsed_body["error_description"]
  end

  test "a code challenge method other than S256 is refused" do
    get base_com_oauth_authorization_url(host: @host, **authorize_params(code_challenge_method: "plain")),
        headers: host_headers(@host)

    assert_response :bad_request
    assert_equal "code_challenge_method must be 'S256'", response.parsed_body["error_description"]
  end

  test "a scope without openid is refused" do
    get base_com_oauth_authorization_url(host: @host, **authorize_params(scope: "profile")),
        headers: host_headers(@host)

    assert_response :bad_request
    assert_equal "scope must include openid", response.parsed_body["error_description"]
  end

  test "an unregistered client is refused without naming what was looked up" do
    get base_com_oauth_authorization_url(host: @host, **authorize_params(client_id: "not-a-registered-client")),
        headers: host_headers(@host)

    assert_response :bad_request
    assert_equal "invalid_request", response.parsed_body["error"]
  end

  # The login_challenge branch resolves a stored transaction. An unknown one must not echo the
  # model or primary key that was looked up.
  test "a region identifier on the request is ignored rather than treated as unpermitted" do
    assert_difference -> { VisitorOidcAuthorizationTransaction.pending.count }, +1 do
      get base_com_oauth_authorization_url(host: @host, **authorize_params),
          params: { ri: "jp" },
          headers: host_headers(@host)
    end
  end

  test "an unknown login challenge is refused with a fixed description" do
    get base_com_oauth_authorization_url(host: @host, login_challenge: SecureRandom.uuid),
        headers: host_headers(@host)

    assert_response :bad_request
    assert_equal "invalid_request", response.parsed_body["error"]
    assert_equal "invalid authorization request", response.parsed_body["error_description"]
  end

  private

  def authorize_params(**overrides)
    {
      response_type: "code",
      client_id: "base-rails-rp",
      redirect_uri: "https://#{@host}/oidc/callback",
      code_challenge: "a" * 43,
      code_challenge_method: "S256",
      scope: "openid",
      state: SecureRandom.hex(8),
      nonce: SecureRandom.hex(8),
    }.merge(overrides)
  end

  # DAMP local helper copy for former shared test support.
  def configured_host(surface_name)
    Rails.configuration.x.boot_config.fetch(:hosts).public_send(surface_name).host
  end
end
