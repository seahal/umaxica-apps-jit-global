# typed: false
# frozen_string_literal: true

require "test_helper"

class PreferenceWebCsrfTest < ActionDispatch::IntegrationTest
  test "app web preference PATCH endpoints reject missing CSRF token" do
    ActionController::Base.allow_forgery_protection = true

    host!(ENV.fetch("PUBLIC_BASE_SERVICE_URL"))

    patch(
      base_app_api_v0_preferences_theme_path, params: { theme: "dark" },
                                              headers: {
                                                "Accept" => "application/json",
                                                "Sec-Fetch-Site" => "cross-site",
                                              }, as: :json,
    )

    assert_response :forbidden

    patch(
      base_app_api_v0_preferences_cookie_path, params: { consented: true },
                                               headers: {
                                                 "Accept" => "application/json",
                                                 "Sec-Fetch-Site" => "cross-site",
                                               }, as: :json,
    )

    assert_response :forbidden
  ensure
    # Restore the environment default, not the value observed on entry: if the flag was
    # already leaked as true, restoring the observation would pin the leak for the rest
    # of the process.
    ActionController::Base.allow_forgery_protection =
      Rails.configuration.action_controller.allow_forgery_protection
  end

  test "com web preference PATCH endpoints reject missing CSRF token" do
    ActionController::Base.allow_forgery_protection = true

    host!(ENV.fetch("PUBLIC_BASE_CORPORATE_URL"))

    patch(
      base_com_api_v0_preferences_theme_path, params: { theme: "dark" },
                                              headers: {
                                                "Accept" => "application/json",
                                                "Sec-Fetch-Site" => "cross-site",
                                              }, as: :json,
    )

    assert_response :forbidden

    patch(
      base_com_api_v0_preferences_cookie_path, params: { consented: true },
                                               headers: {
                                                 "Accept" => "application/json",
                                                 "Sec-Fetch-Site" => "cross-site",
                                               }, as: :json,
    )

    assert_response :forbidden
  ensure
    # Restore the environment default, not the value observed on entry: if the flag was
    # already leaked as true, restoring the observation would pin the leak for the rest
    # of the process.
    ActionController::Base.allow_forgery_protection =
      Rails.configuration.action_controller.allow_forgery_protection
  end

  test "org web preference PATCH endpoints reject missing CSRF token" do
    ActionController::Base.allow_forgery_protection = true

    host!(ENV.fetch("PUBLIC_BASE_STAFF_URL"))

    patch(
      base_org_api_v0_preferences_theme_path, params: { theme: "dark" },
                                              headers: {
                                                "Accept" => "application/json",
                                                "Sec-Fetch-Site" => "cross-site",
                                              }, as: :json,
    )

    assert_response :forbidden

    patch(
      base_org_api_v0_preferences_cookie_path, params: { consented: true },
                                               headers: {
                                                 "Accept" => "application/json",
                                                 "Sec-Fetch-Site" => "cross-site",
                                               }, as: :json,
    )

    assert_response :forbidden
  ensure
    # Restore the environment default, not the value observed on entry: if the flag was
    # already leaked as true, restoring the observation would pin the leak for the rest
    # of the process.
    ActionController::Base.allow_forgery_protection =
      Rails.configuration.action_controller.allow_forgery_protection
  end

  test "same-origin preference mutations require valid tokens across Base surfaces" do
    ActionController::Base.allow_forgery_protection = true

    endpoints = [
      [ENV.fetch("PUBLIC_BASE_SERVICE_URL"), base_app_api_v0_preferences_theme_path],
      [ENV.fetch("PUBLIC_BASE_CORPORATE_URL"), base_com_api_v0_preferences_theme_path],
      [ENV.fetch("PUBLIC_BASE_STAFF_URL"), base_org_api_v0_preferences_theme_path],
    ]

    endpoints.each do |host, path|
      host!(host)
      [nil, "invalid-token"].each do |token|
        headers = {
          "Accept" => "application/json",
          "Origin" => "http://#{host}",
          "Sec-Fetch-Site" => "same-origin",
        }
        headers["X-CSRF-Token"] = token if token

        patch(path, params: { theme: "dark" }, headers:, as: :json)

        assert_response :forbidden
      end
    end
  ensure
    # Restore the environment default, not the value observed on entry: if the flag was
    # already leaked as true, restoring the observation would pin the leak for the rest
    # of the process.
    ActionController::Base.allow_forgery_protection =
      Rails.configuration.action_controller.allow_forgery_protection
  end

  test "same-site preference mutations without tokens are refused on base surfaces" do
    ActionController::Base.allow_forgery_protection = true

    [
      [ENV.fetch("PUBLIC_BASE_SERVICE_URL"), base_app_api_v0_preferences_theme_path],
      [ENV.fetch("PUBLIC_BASE_CORPORATE_URL"), base_com_api_v0_preferences_theme_path],
      [ENV.fetch("PUBLIC_BASE_STAFF_URL"), base_org_api_v0_preferences_theme_path],
    ].each do |host, path|
      host!(host)
      patch(
        path,
        params: { theme: "dark" },
        headers: {
          "Accept" => "application/json",
          "Origin" => "http://#{host}",
          "Sec-Fetch-Site" => "same-site",
        },
        as: :json,
      )

      assert_response :forbidden
    end
  ensure
    # Restore the environment default, not the value observed on entry: if the flag was
    # already leaked as true, restoring the observation would pin the leak for the rest
    # of the process.
    ActionController::Base.allow_forgery_protection =
      Rails.configuration.action_controller.allow_forgery_protection
  end

  test "same-site preference mutations without Origin still require tokens on base surfaces" do
    ActionController::Base.allow_forgery_protection = true

    [
      [ENV.fetch("PUBLIC_BASE_SERVICE_URL"), base_app_api_v0_preferences_theme_path],
      [ENV.fetch("PUBLIC_BASE_CORPORATE_URL"), base_com_api_v0_preferences_theme_path],
      [ENV.fetch("PUBLIC_BASE_STAFF_URL"), base_org_api_v0_preferences_theme_path],
    ].each do |host, path|
      host!(host)
      patch(
        path,
        params: { theme: "dark" },
        headers: {
          "Accept" => "application/json",
          "Sec-Fetch-Site" => "same-site",
        },
        as: :json,
      )

      assert_response :forbidden
    end
  ensure
    # Restore the environment default, not the value observed on entry: if the flag was
    # already leaked as true, restoring the observation would pin the leak for the rest
    # of the process.
    ActionController::Base.allow_forgery_protection =
      Rails.configuration.action_controller.allow_forgery_protection
  end

  test "cross-site POST from untrusted origin is forbidden" do
    ActionController::Base.allow_forgery_protection = true

    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    host!(host)

    patch(
      base_app_api_v0_preferences_theme_path,
      params: { theme: "dark" },
      headers: {
        "Accept" => "application/json",
        "Origin" => "https://evil.example",
        "Sec-Fetch-Site" => "cross-site",
      },
      as: :json,
    )

    assert_response :forbidden
  ensure
    # Restore the environment default, not the value observed on entry: if the flag was
    # already leaked as true, restoring the observation would pin the leak for the rest
    # of the process.
    ActionController::Base.allow_forgery_protection =
      Rails.configuration.action_controller.allow_forgery_protection
  end

  test "cross-site POST rejects trusted-origin suffix scheme and port confusion" do
    original_trusted_origins = Base::App::ApplicationController.forgery_protection_trusted_origins
    ActionController::Base.allow_forgery_protection = true
    Base::App::ApplicationController.forgery_protection_trusted_origins = [
      "https://#{ENV.fetch("PUBLIC_BASE_SERVICE_URL")}",
      "https://#{ENV.fetch("PUBLIC_AUTH_SERVICE_URL")}",
    ]

    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    host!(host)

    [
      "https://#{host}.evil.example",
      "http://#{ENV.fetch("PUBLIC_AUTH_SERVICE_URL")}",
      "https://#{ENV.fetch("PUBLIC_AUTH_SERVICE_URL")}:444",
    ].each do |origin|
      patch(
        base_app_api_v0_preferences_theme_path,
        params: { theme: "dark" },
        headers: {
          "Accept" => "application/json",
          "Origin" => origin,
          "Sec-Fetch-Site" => "cross-site",
        },
        as: :json,
      )

      assert_response :forbidden, origin
    end
  ensure
    # Restore the environment default, not the value observed on entry: if the flag was
    # already leaked as true, restoring the observation would pin the leak for the rest
    # of the process.
    ActionController::Base.allow_forgery_protection =
      Rails.configuration.action_controller.allow_forgery_protection
    Base::App::ApplicationController.forgery_protection_trusted_origins = original_trusted_origins
  end

  test "ordinary base app endpoint rejects cross-site POST from auth origin" do
    ActionController::Base.allow_forgery_protection = true

    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    host!(host)

    patch(
      base_app_api_v0_preferences_theme_path,
      params: { theme: "dark" },
      headers: {
        "Accept" => "application/json",
        "Origin" => "https://#{ENV.fetch("PUBLIC_AUTH_SERVICE_URL")}",
        "Sec-Fetch-Site" => "cross-site",
      },
      as: :json,
    )

    assert_response :forbidden
  ensure
    # Restore the environment default, not the value observed on entry: if the flag was
    # already leaked as true, restoring the observation would pin the leak for the rest
    # of the process.
    ActionController::Base.allow_forgery_protection =
      Rails.configuration.action_controller.allow_forgery_protection
  end

  test "ordinary base app endpoint rejects auth origin even with a real session-bound token" do
    ActionController::Base.allow_forgery_protection = true

    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    host!(host)
    https!

    user = Client.first
    session_record = ClientToken.create!(
      authentication_epoch: 0,
      user: user,
      user_token_status_id: ClientTokenStatus::ACTIVE,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      public_id: PublicId.generate,
      discard_at: 1.day.from_now,
    )
    auth_headers = {
      "Accept" => "text/html",
      "Authorization" => "Bearer #{jwt_access_token_for(
        user, host: host, session_public_id: session_record.public_id, resource_type: "client",
      )}",
      "X-TEST-SESSION-PUBLIC-ID" => session_record.public_id,
    }

    registered_rp = OidcClientRegistry.find!("base-app-ww")
    rp_session = OpAppGrant.create!(
      authentication_epoch: 0,
      client_token: session_record, oidc_client_id: registered_rp.client_id,
      oidc_scope: "openid profile", oidc_jti: SecureRandom.uuid, oidc_auth_time: Time.current,
      refresh_token_expires_at: 10.minutes.from_now,
    )
    cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] = AuthenticationTokenService.encode(
      user, host: host, resource_type: "client", session_public_id: session_record.public_id,
            base_session_public_id: session_record.public_id, oidc_sid: rp_session.public_id,
            oidc_jti: rp_session.oidc_jti, expires_at: 5.minutes.from_now, scopes: %w(openid profile),
            issuer: OidcIssuer.for_client(registered_rp), audiences: [registered_rp.aud],
            jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(registered_rp),
            subject: OidcSubject.for(user, resource_type: "client"), client_id: registered_rp.client_id,
    )

    get(base_app_identity_emails_path(ri: "jp"), headers: auth_headers)

    assert_response :success
    token = response.body[/name="csrf-token" content="([^"]+)"/, 1]
    cookies["csrf_token"] = token

    assert_predicate token, :present?

    patch(
      base_app_api_v0_preferences_theme_path(ri: "jp"),
      params: { theme: "dark" },
      headers: {
        "Accept" => "application/json",
        "Origin" => "https://#{host}",
        "X-CSRF-Token" => token,
        "Sec-Fetch-Site" => "same-origin",
      },
      as: :json,
    )

    assert_response :success

    patch(
      base_app_api_v0_preferences_theme_path(ri: "jp"),
      params: { theme: "dark" },
      headers: {
        "Accept" => "application/json",
        "Origin" => "https://#{ENV.fetch("PUBLIC_AUTH_SERVICE_URL")}",
        "Sec-Fetch-Site" => "cross-site",
        "X-CSRF-Token" => token,
      },
      as: :json,
    )

    assert_response :forbidden
  ensure
    # Restore the environment default, not the value observed on entry: if the flag was
    # already leaked as true, restoring the observation would pin the leak for the rest
    # of the process.
    ActionController::Base.allow_forgery_protection =
      Rails.configuration.action_controller.allow_forgery_protection
  end

  test "missing Sec-Fetch-Site remains fail-closed without a Rails session-bound token" do
    ActionController::Base.allow_forgery_protection = true

    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    token = "legacy-csrf-token"
    cookies["csrf_token"] = token
    host!(host)

    patch(
      base_app_api_v0_preferences_theme_path,
      params: { theme: "dark" },
      headers: {
        "Accept" => "application/json",
        "Origin" => "https://#{host}",
        "X-CSRF-Token" => token,
        # Empty means absent: the hybrid strategy uses this session-bound token fallback.
        "Sec-Fetch-Site" => "",
      },
      as: :json,
    )

    assert_response :forbidden
  ensure
    # Restore the environment default, not the value observed on entry: if the flag was
    # already leaked as true, restoring the observation would pin the leak for the rest
    # of the process.
    ActionController::Base.allow_forgery_protection =
      Rails.configuration.action_controller.allow_forgery_protection
  end

  test "missing Sec-Fetch-Site legacy fallback passes only with the same session-bound token" do
    ActionController::Base.allow_forgery_protection = true

    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    host!(host)
    https!

    user = Client.first
    session_record = ClientToken.create!(
      authentication_epoch: 0,
      user: user,
      user_token_status_id: ClientTokenStatus::ACTIVE,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      public_id: PublicId.generate,
      discard_at: 1.day.from_now,
    )
    auth_headers = {
      "Accept" => "text/html",
      "Authorization" => "Bearer #{jwt_access_token_for(
        user, host: host, session_public_id: session_record.public_id, resource_type: "client",
      )}",
      "X-TEST-SESSION-PUBLIC-ID" => session_record.public_id,
    }

    registered_rp = OidcClientRegistry.find!("base-app-ww")
    rp_session = OpAppGrant.create!(
      authentication_epoch: 0,
      client_token: session_record, oidc_client_id: registered_rp.client_id,
      oidc_scope: "openid profile", oidc_jti: SecureRandom.uuid, oidc_auth_time: Time.current,
      refresh_token_expires_at: 10.minutes.from_now,
    )
    cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] = AuthenticationTokenService.encode(
      user, host: host, resource_type: "client", session_public_id: session_record.public_id,
            base_session_public_id: session_record.public_id, oidc_sid: rp_session.public_id,
            oidc_jti: rp_session.oidc_jti, expires_at: 5.minutes.from_now, scopes: %w(openid profile),
            issuer: OidcIssuer.for_client(registered_rp), audiences: [registered_rp.aud],
            jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(registered_rp),
            subject: OidcSubject.for(user, resource_type: "client"), client_id: registered_rp.client_id,
    )

    get(base_app_identity_emails_path(ri: "jp"), headers: auth_headers)

    assert_response :success
    token = response.body[/name="csrf-token" content="([^"]+)"/, 1]
    cookies["csrf_token"] = token

    assert_predicate token, :present?

    patch(
      base_app_api_v0_preferences_theme_path(ri: "jp"),
      params: { theme: "dark" },
      headers: {
        "Accept" => "application/json",
        "Origin" => "https://#{host}",
        "X-CSRF-Token" => token,
        # Empty means absent. Base still requires the session-bound token for this request.
        "Sec-Fetch-Site" => "",
      },
      as: :json,
    )

    assert_response :success

    second_session = open_session
    second_session.host!(host)
    second_session.https!
    second_session.patch(
      base_app_api_v0_preferences_theme_path(ri: "jp"),
      params: { theme: "dark" },
      headers: {
        "Accept" => "application/json",
        "Origin" => "https://#{host}",
        "X-CSRF-Token" => token,
        "Sec-Fetch-Site" => "same-origin",
      },
      as: :json,
    )

    assert_equal 403, second_session.response.status

    patch(
      base_app_api_v0_preferences_theme_path(ri: "jp"),
      params: { theme: "dark" },
      headers: {
        "Accept" => "application/json",
        "Origin" => "https://#{host}",
        "X-CSRF-Token" => "invalid-token",
        # Empty means absent. Base requires a valid session-bound token for this request.
        "Sec-Fetch-Site" => "",
      },
      as: :json,
    )

    assert_response :forbidden

    patch(
      base_app_api_v0_preferences_theme_path(ri: "jp"),
      params: { theme: "dark" },
      headers: {
        "Accept" => "application/json",
        "Origin" => "https://#{host}",
        # Empty means absent. Base requires a valid session-bound token for this request.
        "Sec-Fetch-Site" => "",
      },
      as: :json,
    )

    assert_response :forbidden
  ensure
    # Restore the environment default, not the value observed on entry: if the flag was
    # already leaked as true, restoring the observation would pin the leak for the rest
    # of the process.
    ActionController::Base.allow_forgery_protection =
      Rails.configuration.action_controller.allow_forgery_protection
  end

  test "protocol exception endpoints remain tokenless but protected by protocol-specific guards" do
    ActionController::Base.allow_forgery_protection = true

    host!(visa_host_for_test_surface(:app))
    post(
      visa_app_oauth_token_path,
      params: { grant_type: "client_credentials" },
      headers: { "Accept" => "application/json", "Sec-Fetch-Site" => "cross-site" },
      as: :json,
    )

    assert_not_equal 403, response.status
  ensure
    # Restore the environment default, not the value observed on entry: if the flag was
    # already leaked as true, restoring the observation would pin the leak for the rest
    # of the process.
    ActionController::Base.allow_forgery_protection =
      Rails.configuration.action_controller.allow_forgery_protection
  end
end
