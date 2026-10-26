# typed: false
# frozen_string_literal: true

require "test_helper"

class Base::Com::Identity::Mfa::ChallengesControllerTest < ActionDispatch::IntegrationTest
  fixtures :visitors

  setup do
    @host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL")
    host! @host
    @visitor = visitors(:reserved_visitor)
    @visitor.update!(security_mode_id: SecurityModeConfigurable::NORMAL)
    @headers =
      begin
        rp_headers = as_visitor_headers(@visitor, host: @host)
        rp_host = rp_headers["Host"]
        rp_route =
          begin
            Rails.application.routes.recognize_path("https://#{rp_host}/") if rp_host.present?
          rescue ActionController::RoutingError
            nil
          end
        rp_family, rp_surface = rp_route&.fetch(:controller)&.split("/")
        if %w(base warp core edit).include?(rp_family) && rp_surface == "com"
          rp_client_id =
            case rp_family
            when "base" then "base-#{rp_surface}-ww"
            when "edit" then "edit-org-ww"
            when "tech" then "tech-org-ww"
            else "#{rp_family}-#{rp_surface}-jp"
            end
          rp_token = VisitorToken.find_by!(public_id: rp_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
          rp_client = OidcClientRegistry.find!(rp_client_id)
          rp_key = [rp_client.client_id, rp_token.public_id]
          @base_browser_rp_credentials ||= {}
          if !@base_browser_rp_credentials[rp_key] && rp_token.currently_usable? &&
              !(rp_token.device_session_id && OpComGrant.exists?(
                device_session_id: rp_token.device_session_id, oidc_client_id: rp_client.client_id, revoked_at: nil,
              ))
            rp_token.rotate_refresh_token! unless rp_token.device_session_record.current_refresh_token_id
            rp_now = Time.current
            rp_session = OpComGrant.create!(
              authentication_epoch: 0,
              visitor_token: rp_token, oidc_client_id: rp_client.client_id, oidc_scope: "openid profile",
              oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: rp_now,
              refresh_token_expires_at: rp_now + 10.minutes,
            )
            rp_access = AuthenticationTokenService.encode(
              rp_token.actor_record, host: rp_host, resource_type: "visitor",
                                     session_public_id: rp_token.public_id, base_session_public_id: rp_token.public_id,
                                     oidc_sid: rp_session.public_id, oidc_jti: rp_session.oidc_jti,
                                     expires_at: rp_now + 10.minutes, scopes: %w(openid profile),
                                     issuer: OidcIssuer.for_client(rp_client), audiences: [rp_client.aud],
                                     jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(rp_client),
                                     subject: OidcSubject.for(
                                       rp_token.actor_record,
                                       resource_type: "visitor",
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
    @token = VisitorToken.find_by!(public_id: @headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
  end

  test "show without a current Step-Up redirects to verification and changes nothing" do
    add_passkeys!(1)
    get base_com_identity_mfa_challenge_url(ri: "jp"), headers: @headers

    assert_response :redirect
    assert_equal "/verification", URI.parse(response.location).path
    assert_equal SecurityModeConfigurable::NORMAL, @visitor.reload.security_mode_id
  end

  test "with one Passkey the page offers no switch to ADVANCED" do
    add_passkeys!(1)
    satisfy_step_up!

    get base_com_identity_mfa_challenge_url(ri: "jp"), headers: @headers

    assert_response :success
    assert_nil inertia_props.fetch("form")
    assert_equal I18n.t("sign.app.settings.mfa.show.advanced_requires_two_passkeys"),
                 inertia_props.fetch("form_unavailable")
  end

  test "ADVANCED is refused with one Passkey and accepted with two, keeping the current session" do
    add_passkeys!(1)
    satisfy_step_up!
    patch base_com_identity_mfa_challenge_url(ri: "jp"),
          params: { user: { security_mode_id: SecurityModeConfigurable::ADVANCED } }, headers: @headers

    assert_response :unprocessable_content
    assert_equal SecurityModeConfigurable::NORMAL, @visitor.reload.security_mode_id

    add_passkeys!(1)
    patch base_com_identity_mfa_challenge_url(ri: "jp"),
          params: { user: { security_mode_id: SecurityModeConfigurable::ADVANCED } }, headers: @headers

    assert_response :redirect
    assert_equal SecurityModeConfigurable::ADVANCED, @visitor.reload.security_mode_id
    assert_predicate @token.reload, :currently_usable?
  end

  test "returning to NORMAL revokes the current session" do
    add_passkeys!(2)
    @visitor.reload.update!(security_mode_id: SecurityModeConfigurable::ADVANCED)
    satisfy_step_up!
    patch base_com_identity_mfa_challenge_url(ri: "jp"),
          params: { user: { security_mode_id: SecurityModeConfigurable::NORMAL } }, headers: @headers

    assert_response :redirect
    assert_equal SecurityModeConfigurable::NORMAL, @visitor.reload.security_mode_id
    assert_not_predicate @token.reload, :currently_usable?
  end

  test "an unsupported mode value is refused and changes nothing" do
    satisfy_step_up!
    [0, 5, "x"].each do |value|
      patch base_com_identity_mfa_challenge_url(ri: "jp"),
            params: { user: { security_mode_id: value } }, headers: @headers

      assert_response :unprocessable_content
      assert_equal SecurityModeConfigurable::NORMAL, @visitor.reload.security_mode_id
    end
  end

  private

  def add_passkeys!(count)
    count.times do
      VisitorPasskey.create!(
        visitor_id: @visitor.id, webauthn_id: SecureRandom.uuid, public_key: "mode-key", uv_verified_at: Time.current,
      )
    end
  end

  def satisfy_step_up!
    @token.update!(
      last_step_up_at: Time.current, last_step_up_scope: "settings_mfa", last_step_up_method: "passkey",
      last_step_up_session_public_id: @token.public_id, last_step_up_purpose: "step_up",
      last_step_up_audience: "step_up:com", last_step_up_credential_ref: "test-step-up",
      last_step_up_phishing_resistant: true, last_step_up_user_verified: true,
      last_step_up_full_reauthentication: false,
    )
  end
end
