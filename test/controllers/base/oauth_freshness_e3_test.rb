# typed: false
# frozen_string_literal: true

require "test_helper"

class BaseOauthFreshnessE3Test < ActionDispatch::IntegrationTest
  include OidcAuthorizationResponseHelper

  setup { Rails.configuration.x.rate_limit.fetch(:store).clear }

  test "anonymous prompt=none returns login_required to the RP without starting a ceremony" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost")

    get base_app_oauth_authorization_url(host: host, **authorize_params.merge(prompt: "none")),
        headers: { "Host" => host }

    assert_oidc_error_redirect(
      error: "login_required",
      redirect_uri: OidcClientRegistry.find!("core-app").redirect_uris.first,
    )
  end

  test "prompt=login with an existing session starts a fresh ceremony" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost")
    user = clients(:one)

    get base_app_oauth_authorization_url(host: host, **authorize_params.merge(prompt: "login")),
        headers: as_user_headers(user, host: host)

    assert_response :redirect
    assert_predicate response.location, :present?
  end

  test "stale max_age with an existing session starts a fresh ceremony" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost")
    user = clients(:one)
    token = ClientToken.create!(user: user, authentication_event_at: 1.hour.ago)

    get base_app_oauth_authorization_url(host: host, **authorize_params.merge(max_age: "60")),
        headers: as_user_headers(user, host: host, session_public_id: token.public_id)

    assert_response :redirect
    assert_predicate response.location, :present?
  end

  test "com anonymous prompt=none returns login_required" do
    host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL")
    client = OidcClientRegistry.find!("core-com")

    get base_com_oauth_authorization_url(
      host: host,
      response_type: "code",
      client_id: "core-com",
      redirect_uri: client.redirect_uris_by_realm.fetch("visitor").first,
      code_challenge: "challenge",
      code_challenge_method: "S256",
      state: "state",
      nonce: "nonce",
      scope: "openid profile",
      prompt: "none",
    ), headers: { "Host" => host }

    assert_oidc_error_redirect(
      error: "login_required",
      redirect_uri: client.redirect_uris_by_realm.fetch("visitor").first,
    )
  end

  test "org anonymous prompt=none returns login_required" do
    host = ENV.fetch("PUBLIC_BASE_STAFF_URL")
    client = OidcClientRegistry.find!("core-org")

    get base_org_oauth_authorization_url(
      host: host,
      response_type: "code",
      client_id: "core-org",
      redirect_uri: client.redirect_uris_by_realm.fetch("operator").first,
      code_challenge: "challenge",
      code_challenge_method: "S256",
      state: "state",
      nonce: "nonce",
      scope: "openid profile",
      prompt: "none",
    ), headers: { "Host" => host }

    assert_oidc_error_redirect(
      error: "login_required",
      redirect_uri: client.redirect_uris_by_realm.fetch("operator").first,
    )
  end

  test "unsupported prompt is rejected as an invalid request" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost")

    get base_app_oauth_authorization_url(host: host, **authorize_params.merge(prompt: "consent")),
        headers: { "Host" => host }

    assert_response :bad_request
    assert_equal "invalid_request", response.parsed_body.fetch("error")
  end

  private

  def authorize_params
    client = OidcClientRegistry.find!("core-app")
    @client_callback_host = URI.parse(client.redirect_uris.first).host
    {
      response_type: "code",
      client_id: "core-app",
      redirect_uri: client.redirect_uris.first,
      code_challenge: "challenge",
      code_challenge_method: "S256",
      state: "state",
      nonce: "nonce",
      scope: "openid profile",
    }
  end
end
