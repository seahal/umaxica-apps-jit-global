# typed: false
# frozen_string_literal: true

require "test_helper"

# RFC 6749 section 4.1.2.1 expects spec-level descriptions for a malformed authorization request,
# and the controller deliberately answers RecordNotFound with a fixed description so a bad
# result code cannot be used to probe stored data. Both halves are asserted here.
class Visa::Org::Oauth::AuthorizationsControllerTest < ActionDispatch::IntegrationTest
  include OidcAuthorizationResponseHelper

  setup do
    @host = visa_host_for_test_surface(:org)
  end

  test "a request with no parameters is refused as an invalid request" do
    get visa_org_oauth_authorization_url(host: @host), headers: host_headers(@host)

    assert_response :bad_request
    assert_equal "invalid_request", response.parsed_body["error"]
  end

  # D-147 N-1: after a valid client and redirect_uri, errors go back to the RP.
  test "a response_type other than code is returned to the RP as unsupported_response_type" do
    params = authorize_params(response_type: "token")
    get visa_org_oauth_authorization_url(host: @host, **params), headers: host_headers(@host)

    assert_oidc_error_redirect(
      error: "unsupported_response_type", redirect_uri: params[:redirect_uri],
      state: params[:state],
    )
  end

  test "a missing code challenge is returned to the RP as invalid_request" do
    params = authorize_params.except(:code_challenge)

    get visa_org_oauth_authorization_url(host: @host, **params), headers: host_headers(@host)

    assert_oidc_error_redirect(error: "invalid_request", redirect_uri: params[:redirect_uri], state: params[:state])
  end

  test "a code challenge method other than S256 is returned to the RP as invalid_request" do
    params = authorize_params(code_challenge_method: "plain")
    get visa_org_oauth_authorization_url(host: @host, **params), headers: host_headers(@host)

    assert_oidc_error_redirect(error: "invalid_request", redirect_uri: params[:redirect_uri], state: params[:state])
  end

  test "a scope without openid is returned to the RP as invalid_request" do
    params = authorize_params(scope: "profile")
    get visa_org_oauth_authorization_url(host: @host, **params), headers: host_headers(@host)

    assert_oidc_error_redirect(error: "invalid_request", redirect_uri: params[:redirect_uri], state: params[:state])
  end

  test "an unregistered client is refused without naming what was looked up" do
    get visa_org_oauth_authorization_url(host: @host, **authorize_params(client_id: "not-a-registered-client")),
        headers: host_headers(@host)

    assert_response :bad_request
    assert_equal "invalid_request", response.parsed_body["error"]
  end

  # The result branch resolves a stored transaction. An unknown one must not echo the
  # model or primary key that was looked up.
  test "a region identifier on the request is ignored rather than treated as unpermitted" do
    parameters = authorize_params
    assert_difference -> { OperatorOidcAuthorizationTransaction.pending.count }, +1 do
      get visa_org_oauth_authorization_url(host: @host, **parameters),
          params: { ri: "jp" }, headers: host_headers(@host)
    end

    assert_response :see_other
    transaction = OperatorOidcAuthorizationTransaction.find_by!(state: parameters.fetch(:state))

    assert_equal parameters.fetch(:client_id), transaction.client_id
  end

  test "an unknown result code is refused with a fixed description" do
    post visa_org_oauth_authorization_url(host: @host),
         params: { result: SecureRandom.uuid },
         headers: host_headers(@host).merge(
           "Origin" => "https://#{ENV.fetch("PUBLIC_AUTH_STAFF_URL")}",
           "Sec-Fetch-Site" => "same-site",
         )

    assert_response :bad_request
    assert_equal "invalid_request", response.parsed_body["error"]
    assert_equal "invalid authorization request", response.parsed_body["error_description"]
  end

  private

  def authorize_params(**overrides)
    {
      response_type: "code",
      client_id: "core-org-jp",
      redirect_uri: OidcClientRegistry.find!("core-org-jp").redirect_uris_by_realm.fetch("operator").first,
      code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
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
