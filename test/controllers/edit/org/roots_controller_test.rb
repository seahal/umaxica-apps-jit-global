# frozen_string_literal: true

require "test_helper"

class Edit::Org::RootsControllerTest < ActionDispatch::IntegrationTest
  fixtures :operators, :operator_statuses

  setup do
    host! ENV.fetch("PUBLIC_EDIT_STAFF_URL")
  end

  test "anonymous landing provides publishing sign in and base registration entry with region" do
    get edit_org_root_path(ri: "jp")

    assert_response :success
    assert_select "main#main h1", text: "UMAXICA Edit"
    assert_select "nav[aria-label=?] a[href=?]", I18n.t("ui_presentation.navigation.authentication"),
                  edit_org_dashboard_path(ri: "jp"), text: "Sign in"
    assert_select "nav[aria-label=?] a[href=?]", I18n.t("ui_presentation.navigation.authentication"),
                  base_org_root_url(host: ENV.fetch("PUBLIC_BASE_STAFF_URL"), ri: "jp"), text: "Sign up"
    assert_select "html[lang='ja']"
    assert_equal "private, no-store", response.headers["Cache-Control"]
  end

  test "landing settings link uses the base org authority" do
    get edit_org_root_path(ri: "jp")

    assert_response :success
    assert_select "footer a[href=?]",
                  base_org_preference_url(host: ENV.fetch("PUBLIC_BASE_STAFF_URL"), ri: "jp")
  end

  test "signed in operator sees the publishing dashboard entry without registration" do
    host = ENV.fetch("PUBLIC_EDIT_STAFF_URL")
    http_headers_0 =
      begin
        rp_headers = as_staff_headers(operators(:one), host: host)
        rp_host = rp_headers["Host"]
        rp_route =
          begin
            Rails.application.routes.recognize_path("https://#{rp_host}/") if rp_host.present?
          rescue ActionController::RoutingError
            nil
          end
        rp_family, rp_surface = rp_route&.fetch(:controller)&.split("/")
        if %w(base warp core edit).include?(rp_family) && rp_surface == "org"
          rp_client_id =
            case rp_family
            when "base" then "base-#{rp_surface}-ww"
            when "edit" then "edit-org-ww"
            when "tech" then "tech-org-ww"
            else "#{rp_family}-#{rp_surface}-jp"
            end
          rp_token = OperatorToken.find_by!(public_id: rp_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
          rp_client = OidcClientRegistry.find!(rp_client_id)
          rp_key = [rp_client.client_id, rp_token.public_id]
          @base_browser_rp_credentials ||= {}
          if !@base_browser_rp_credentials[rp_key] && rp_token.currently_usable? &&
              !(rp_token.device_session_id && OpOrgGrant.exists?(
                device_session_id: rp_token.device_session_id, oidc_client_id: rp_client.client_id, revoked_at: nil,
              ))
            rp_token.rotate_refresh_token! unless rp_token.device_session_record.current_refresh_token_id
            rp_now = Time.current
            rp_session = OpOrgGrant.create!(
              authentication_epoch: 0,
              operator_token: rp_token, oidc_client_id: rp_client.client_id, oidc_scope: "openid profile",
              oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: rp_now,
              refresh_token_expires_at: rp_now + 10.minutes,
            )
            rp_access = AuthenticationTokenService.encode(
              rp_token.actor_record, host: rp_host, resource_type: "operator",
                                     session_public_id: rp_token.public_id, base_session_public_id: rp_token.public_id,
                                     oidc_sid: rp_session.public_id, oidc_jti: rp_session.oidc_jti,
                                     expires_at: rp_now + 10.minutes, scopes: %w(openid profile),
                                     issuer: OidcIssuer.for_client(rp_client), audiences: [rp_client.aud],
                                     jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(rp_client),
                                     subject: OidcSubject.for(
                                       rp_token.actor_record,
                                       resource_type: "operator",
                                     ), client_id: rp_client.client_id,
            )
            @base_browser_rp_credentials[rp_key] = [rp_access, rp_session.issue_refresh_token!]
          end
          if @base_browser_rp_credentials[rp_key]
            rp_access, rp_refresh = @base_browser_rp_credentials.fetch(rp_key)
            rp_cookie = [
              rp_headers.fetch("Cookie"),
              "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(rp_access)}",
              "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(rp_refresh)}",
            ].join("; ")
            rp_headers = rp_headers.merge("Cookie" => rp_cookie, "HTTP_COOKIE" => rp_cookie)
          end
        end
        rp_headers
      end
    get edit_org_root_path(ri: "jp"), headers: http_headers_0

    assert_response :success
    assert_select "nav[aria-label=?] a[href=?]", I18n.t("ui_presentation.navigation.authentication"),
                  edit_org_dashboard_path(ri: "jp"), text: "Publishing"
    assert_select "nav[aria-label=?] a", I18n.t("ui_presentation.navigation.authentication"), count: 1
    assert_equal "private, no-store", response.headers["Cache-Control"]
  end
end
