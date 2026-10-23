# frozen_string_literal: true

require "test_helper"

class WarpComPreferenceAdoptionTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("PUBLIC_WARP_CORPORATE_URL")
    host! @host
    @visitor = visitors(:reserved_visitor)
    @token = VisitorToken.create!(authentication_epoch: 0, visitor: @visitor, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB)
    cookies[AuthenticationBase::REFRESH_COOKIE_KEY] = @token.rotate_refresh_token!
    client = OidcClientRegistry.find!("warp-com-jp")
    @rp_session = OpComGrant.create!(
      authentication_epoch: 0,
      visitor_token: @token, oidc_client_id: client.client_id,
      oidc_scope: "openid profile", oidc_jti: SecureRandom.uuid,
      oidc_nonce: SecureRandom.hex(16), oidc_auth_time: 1.minute.ago,
      refresh_token_expires_at: 10.minutes.from_now,
    )
    cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] = AuthenticationTokenService.encode(
      @visitor, host: @host, resource_type: "visitor",
                session_public_id: @token.public_id, base_session_public_id: @token.public_id,
                oidc_sid: @rp_session.public_id, oidc_jti: @rp_session.oidc_jti,
                expires_at: 10.minutes.from_now, scopes: %w(openid profile),
                issuer: OidcIssuer.for_client(client), audiences: [client.aud],
                jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(client),
                subject: OidcSubject.for(@visitor, resource_type: "visitor"), client_id: client.client_id,
    )
    cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE] = @rp_session.issue_refresh_token!
  end

  # The ordinary inherited callback bootstraps before the OIDC logout launch.
  # The launch itself neither revokes the sessions nor performs logout safe-copy.
  test "cookie-less authenticated launch creates a visitor mirror with the browser's stored values" do
    # A signed-in visitor cannot render the anonymous landing. This confirms
    # the RP credential reaches the ordinary authentication pipeline first.
    get warp_com_root_url(ri: "jp")

    assert_response :not_found

    mirror =
      lambda do
        ComZenithRecord.connected_to(role: :writing) do
          VisitorPreference.includes(
            visitor_preference_theme: :option, visitor_preference_language: :option,
            visitor_preference_timezone: :option, visitor_preference_region: :option,
          ).find_by(visitor_id: @visitor.id)
        end
      end

    assert_nil mirror.call

    assert_difference -> { ComPreference.count }, 1 do
      assert_difference -> { ComZenithRecord.connected_to(role: :writing) { VisitorPreference.count } }, 1 do
        post warp_com_sign_out_url(ri: "jp")
      end
    end

    assert_response :see_other
    assert_predicate cookies[PreferenceCookieName.refresh(surface: :com)], :present?
    browser = ComPreference.includes(
      com_preference_theme: :option, com_preference_language: :option,
      com_preference_timezone: :option, com_preference_region: :option,
    ).order(:created_at).last
    preference = mirror.call

    assert_not_nil preference
    ComZenithRecord.connected_to(role: :writing) do
      assert_equal browser.com_preference_theme.option.name, preference.visitor_preference_theme.option.name
      assert_equal browser.com_preference_language.option.name, preference.visitor_preference_language.option.name
      assert_equal browser.com_preference_timezone.option.name, preference.visitor_preference_timezone.option.name
      assert_equal browser.com_preference_region.option.name, preference.visitor_preference_region.option.name
    end
    assert_predicate @rp_session.reload, :active?
    assert_predicate @token.reload, :currently_usable?
  end

  test "bootstrap restores an existing visitor's explicit dark theme into the new browser preference" do
    ComZenithRecord.connected_to(role: :writing) do
      preference = VisitorPreference.create!(visitor_id: @visitor.id, theme: "dr")
      VisitorPreferenceThemeOption.ensure_defaults!
      VisitorPreferenceTheme.create!(preference: preference, option_id: VisitorPreferenceThemeOption::DARK)
      preference.mark_field_explicit!(:theme)
    end

    assert_difference -> { ComPreference.count }, 1 do
      post warp_com_sign_out_url(ri: "jp")
    end

    assert_response :see_other
    browser = ComPreference.includes(:com_preference_theme).order(:created_at).last

    assert_equal ComPreferenceThemeOption::DARK, browser.com_preference_theme.option_id
    ComZenithRecord.connected_to(role: :writing) do
      assert_equal "dr", VisitorPreference.find_by!(visitor_id: @visitor.id).theme
    end
  end

  test "anonymous launch does not create an actor-local preference" do
    cookies.delete(OidcRpBrowserCredentialContract::ACCESS_COOKIE)
    cookies.delete(OidcRpBrowserCredentialContract::REFRESH_COOKIE)
    cookies.delete(AuthenticationBase::REFRESH_COOKIE_KEY)

    assert_no_difference -> { ComZenithRecord.connected_to(role: :writing) { VisitorPreference.count } } do
      post warp_com_sign_out_url(ri: "jp")
    end

    assert_response :unauthorized
  end

  test "a parent refresh cookie alone cannot authenticate or synchronize a Warp visitor" do
    cookies.delete(OidcRpBrowserCredentialContract::ACCESS_COOKIE)
    cookies.delete(OidcRpBrowserCredentialContract::REFRESH_COOKIE)

    assert_no_difference -> { ComZenithRecord.connected_to(role: :writing) { VisitorPreference.count } } do
      post warp_com_sign_out_url(ri: "jp")
    end

    assert_response :unauthorized
    assert_predicate @rp_session.reload, :active?
    assert_predicate @token.reload, :currently_usable?
  end

  test "invalid preference refresh credential cannot bootstrap or synchronize a visitor mirror" do
    cookies[PreferenceCookieName.refresh(surface: :com)] = "invalid-preference-credential"

    assert_no_difference -> { ComPreference.count } do
      assert_no_difference -> { ComZenithRecord.connected_to(role: :writing) { VisitorPreference.count } } do
        post warp_com_sign_out_url(ri: "jp")
      end
    end

    assert_response :unauthorized
    assert_predicate @rp_session.reload, :active?
    assert_predicate @token.reload, :currently_usable?
  end

  test "visitor mirror persistence failure propagates instead of becoming a successful logout launch" do
    VisitorPreference.stub(:find_by, nil) do
      VisitorPreference.stub(:create!, ->(*) { raise ActiveRecord::ConnectionNotEstablished, "mirror unavailable" }) do
        assert_raises(ActiveRecord::ConnectionNotEstablished) do
          post warp_com_sign_out_url(ri: "jp")
        end
      end
    end

    assert_predicate @rp_session.reload, :active?
    assert_predicate @token.reload, :currently_usable?
  end
end
