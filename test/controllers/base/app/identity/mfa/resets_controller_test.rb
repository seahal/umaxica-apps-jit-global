# typed: false
# frozen_string_literal: true

require "test_helper"

class Base::App::Identity::Mfa::ResetsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    host! @host
    @client = clients(:one)
    @client.update_columns(mfa_level_id: ClientMfaLevel::FULL, mfa_level_enabled: true)
  end

  test "reset with fresh step-up clears the MFA level" do
    post base_app_identity_mfa_reset_url(ri: "jp", host: @host), headers: client_headers(step_up_scope: "settings_mfa")

    assert_response :see_other
    assert_equal ClientMfaLevel::NOTHING, @client.reload.mfa_level_id
  end

  test "reset without fresh step-up is refused and keeps MFA enabled" do
    post base_app_identity_mfa_reset_url(ri: "jp", host: @host), headers: client_headers(step_up_scope: nil)

    assert_response :unauthorized
    assert_equal ClientMfaLevel::FULL, @client.reload.mfa_level_id
    assert @client.mfa_level_enabled
  end

  private

  def client_headers(step_up_scope:)
    token = ClientToken.create!(
      user: @client, user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      user_token_status_id: ClientTokenStatus::ACTIVE, discarded_at: 1.day.from_now,
    )
    BaseSelectorBootstrapAuthority.call(surface: :app, principal: @client)
    BaseSelectorAuthority.prepare(surface: :app, principal: @client, session: token)
    if step_up_scope
      token.update!(
        last_step_up_at: Time.current, last_step_up_scope: step_up_scope,
        last_step_up_aal: "aal2", last_step_up_method: "passkey",
        last_step_up_session_public_id: token.public_id, last_step_up_purpose: "step_up",
        last_step_up_audience: "step_up:app",
      )
    end
    access_token = AuthenticationToken.encode(
      @client, host: @host, session_public_id: token.public_id,
               resource_type: "client", jwt_issuer_id: "surface:BASE_APP",
    )
    cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = access_token

    {
      "Authorization" => "Bearer #{access_token}",
      "Client-Agent" => "Mozilla/5.0",
      "Host" => @host,
      "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
    }
  end
end
