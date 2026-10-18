# typed: false
# frozen_string_literal: true

require "test_helper"

# The Restricted Mode indicator is published by the shared surface chrome, not
# by any page.
#
# That is the requirement, not an implementation detail: an operator in an
# Emergency session must see the indicator for the whole life of that session,
# and no screen may be able to drop it. Since no screen supplies it, no screen
# can forget it -- which is what the "another authenticated page" test below
# demonstrates.
class Auth::Org::RestrictedModeChromeTest < ActionDispatch::IntegrationTest
  fixtures :operators, :operator_statuses, :operator_tokens

  setup do
    https!
    @host = ENV.fetch("PUBLIC_BASE_STAFF_URL")
    host! @host
    @staff = operators(:one)
    @staff.update!(status_id: OperatorStatus::ACTIVE)
    @token = operator_tokens(:one)
    @token.update!(root_login_established_at: Time.current, established_authentication_method: "passkey")
    BaseSelectorBootstrapAuthority.call(surface: :org, principal: @staff)
    BaseSelectorAuthority.prepare(surface: :org, principal: @staff, session: @token)
    begin
      rp_cookie_pairs =
        begin
          rp_host = @host
          rp_token = @token
          rp_client = OidcClientRegistry.find!("base-org-ww")
          rp_key = [rp_client.client_id, rp_token.public_id]
          @base_browser_rp_credentials ||= {}
          if @base_browser_rp_credentials[rp_key] ||
              (rp_token.currently_usable? &&
                !(rp_token.device_session_id && OpOrgGrant.exists?(
                  device_session_id: rp_token.device_session_id, oidc_client_id: rp_client.client_id, revoked_at: nil,
                )))
            unless @base_browser_rp_credentials[rp_key]
              rp_token.rotate_refresh_token! unless rp_token.device_session_record.current_refresh_token_id
              rp_now = Time.current
              rp_session = OpOrgGrant.create!(
                contract_epoch: OpOrgProtocolEpoch.current_contract_epoch,
                operator_token: rp_token, oidc_client_id: rp_client.client_id, oidc_scope: "openid profile",
                oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: rp_now,
                refresh_token_expires_at: rp_now + 10.minutes,
              )
              rp_access = AuthenticationTokenService.encode(
                @staff, host: rp_host, resource_type: "operator",
                        session_public_id: rp_token.public_id, base_session_public_id: rp_token.public_id,
                        oidc_sid: rp_session.public_id, oidc_jti: rp_session.oidc_jti,
                        expires_at: rp_now + 10.minutes, scopes: %w(openid profile),
                        issuer: OidcIssuer.for_client(rp_client), audiences: [rp_client.aud],
                        jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(rp_client),
                        subject: OidcSubject.for(@staff, resource_type: "operator"), client_id: rp_client.client_id,
              )
              @base_browser_rp_credentials[rp_key] = [rp_access, rp_session.issue_refresh_token!]
            end
            rp_access, rp_refresh = @base_browser_rp_credentials.fetch(rp_key)
            [
              "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(rp_access)}",
              "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(rp_refresh)}",
            ]
          else
            []
          end
        end
      cookies.merge(rp_cookie_pairs, URI.parse("https://#{rp_host}/"))
    end
  end

  def headers_for(context)
    @token.update!(authentication_context: context)

    as_staff_headers(@staff, host: @host, session_public_id: @token.reload.public_id).except("Cookie", "HTTP_COOKIE")
  end

  test "a normal session renders no restricted mode indicator" do
    get base_org_identity_url(ri: "jp"), headers: headers_for(nil)

    assert_response :success
    assert_nil inertia_props.fetch("chrome").fetch("restricted_mode")
  end

  test "an emergency session renders the restricted mode indicator in the shared chrome" do
    get base_org_identity_url(ri: "jp"), headers: headers_for("standby")

    assert_response :success
    restricted = inertia_props.fetch("chrome").fetch("restricted_mode")

    assert_equal I18n.t("layouts.shared.restricted_mode.label"), restricted.fetch("label")
    assert_equal I18n.t("layouts.shared.restricted_mode.description"), restricted.fetch("description")
  end

  # The only offered way back to a normal session is to end this one. There is
  # no "leave restricted mode" operation, because there is no in-session
  # transition for such a control to perform.
  test "the indicator offers sign-out and nothing that claims to switch mode in place" do
    get base_org_identity_url(ri: "jp"), headers: headers_for("standby")

    restricted = inertia_props.fetch("chrome").fetch("restricted_mode")

    assert_equal I18n.t("layouts.shared.restricted_mode.sign_out"), restricted.dig("sign_out", "label")
    assert_equal new_auth_org_sign_out_path(ri: "jp"), restricted.dig("sign_out", "href")
    assert_no_match(/解除/, restricted.to_s)
  end

  # No page can omit the indicator because no page produces it. If a controller
  # or page component ever started publishing its own, that guarantee would be
  # gone and the indicator could go missing from one screen.
  test "only the shared chrome produces the restricted mode indicator" do
    producers =
      Rails.root.glob("app/controllers/**/*.rb").select do |path|
        next false if path.to_s.end_with?("app/controllers/concerns/surface_chrome.rb")

        path.read.match?(/^\s*restricted_mode:/)
      end

    assert_empty producers.map { |path| path.relative_path_from(Rails.root).to_s },
                 "Restricted Mode is session state published once by SurfaceChrome, not page props"

    page_producers = Rails.root.glob("src/pages/**/*.tsx").select { |path| path.read.include?("restricted_mode:") }

    assert_empty page_producers.map { |path| path.relative_path_from(Rails.root).to_s }
  end
end
