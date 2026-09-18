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
      redirect_uri: OidcClientRegistry.find!("core-next-rp").redirect_uris.first,
    )
  end

  test "prompt=login with an existing session starts reauthentication instead of issuing a code" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost")
    user = clients(:one)

    get base_app_oauth_authorization_url(host: host, **authorize_params.merge(prompt: "login")),
        headers: as_user_headers(user, host: host)

    assert_response :redirect
    location = URI.parse(response.location)

    assert_not_includes location.query.to_s, "code="
    assert_not_equal @client_callback_host, location.host
  end

  test "stale max_age with an existing session does not issue a code" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost")
    user = clients(:one)
    token = ClientToken.create!(user: user, authentication_event_at: 1.hour.ago)

    get base_app_oauth_authorization_url(host: host, **authorize_params.merge(max_age: "60")),
        headers: as_user_headers(user, host: host, session_public_id: token.public_id)

    assert_response :redirect
    assert_not_includes URI.parse(response.location).query.to_s, "code="
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

  test "shared freshness decision treats login and stale max_age as unsatisfied" do
    event = Time.utc(2026, 9, 13, 9, 0)

    assert_not OidcAuthorizeRequestResolver.authentication_satisfied?(
      prompt: "login", max_age: nil, authenticated_at: event, now: event + 1.second,
    )
    assert_not OidcAuthorizeRequestResolver.authentication_satisfied?(
      prompt: nil, max_age: 60, authenticated_at: event, now: event + 2.minutes,
    )
    assert OidcAuthorizeRequestResolver.authentication_satisfied?(
      prompt: nil, max_age: 120, authenticated_at: event, now: event + 1.minute,
    )
    assert_not OidcAuthorizeRequestResolver.authentication_satisfied?(
      prompt: nil, max_age: 60, authenticated_at: nil, now: event,
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
    client = OidcClientRegistry.find!("core-next-rp")
    @client_callback_host = URI.parse(client.redirect_uris.first).host
    {
      response_type: "code",
      client_id: "core-next-rp",
      redirect_uri: client.redirect_uris.first,
      code_challenge: "challenge",
      code_challenge_method: "S256",
      state: "state",
      nonce: "nonce",
      scope: "openid profile",
    }
  end
end
