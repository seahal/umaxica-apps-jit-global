# typed: false
# frozen_string_literal: true

require "test_helper"

class VerificationBaseStepUpLoggingTest < ActionDispatch::IntegrationTest
  test "a real denied credential mutation logs policy properties without token or actor identifiers" do
    https!
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    host! host
    actor = clients(:one)
    headers = as_user_headers(actor, host: host)
    token = ClientToken.find_by!(public_id: headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
    BaseSelectorBootstrapAuthority.call(surface: :app, principal: actor)
    BaseSelectorAuthority.prepare(surface: :app, principal: actor, session: token)
    token.update!(
      last_step_up_at: Time.current, last_step_up_scope: "settings_passkey", last_step_up_method: "passkey",
      last_step_up_session_public_id: token.public_id, last_step_up_purpose: "step_up",
      last_step_up_audience: "step_up:app", last_step_up_credential_ref: SecureRandom.uuid,
      last_step_up_phishing_resistant: true, last_step_up_user_verified: true,
      last_step_up_full_reauthentication: false,
    )
    token.rotate_refresh_token!
    rp_client = OidcClientRegistry.find!("base-app-ww")
    rp_session = ClientRpSession.create!(
      client_token: token, oidc_client_id: rp_client.client_id, oidc_scope: "openid profile",
      oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: Time.current,
      refresh_token_expires_at: 10.minutes.from_now,
    )
    access = AuthenticationTokenService.encode(
      actor, host: host, resource_type: "client", session_public_id: token.public_id,
             base_session_public_id: token.public_id, oidc_sid: rp_session.public_id, oidc_jti: rp_session.oidc_jti,
             expires_at: 10.minutes.from_now, scopes: %w(openid profile), issuer: OidcIssuer.for_client(rp_client),
             audiences: [rp_client.aud], jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(rp_client),
             subject: OidcSubject.for(actor, resource_type: "client"), client_id: rp_client.client_id,
    )
    cookie = [
      headers.fetch("Cookie"),
      "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(access)}",
      "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(rp_session.issue_refresh_token!)}",
    ].join("; ")
    headers = headers.merge("Cookie" => cookie, "HTTP_COOKIE" => cookie)

    contact = actor.client_emails.create!(
      address: "log-#{SecureRandom.hex(8)}@example.test", confirm_policy: "1",
      user_email_status_id: ClientEmailStatus::VERIFIED,
    ).tap(&:finalize_binding!)
    logs = []
    Rails.logger.stub(:info, ->(message = nil, &block) { logs << (message || block.call) }) do
      delete base_app_identity_email_path(contact.public_id, ri: "jp"), headers: headers
    end

    assert_response :unauthorized
    assert_not_predicate contact.reload, :binding_released?
    event =
      logs.filter_map { |entry| JSON.parse(entry, symbolize_names: true) if entry.start_with?("{") }
        .find { |entry| entry[:event] == "auth.step_up.required" }

    assert event, "expected the diagnostic log from the refused public request"
    data = event.fetch(:data)

    assert_equal "Base::App::Identity::EmailsController", data[:controller]
    assert_equal "destroy", data[:action]
    assert_equal "DELETE", data[:method]
    assert_equal "text/html", data[:format]
    assert_equal "app", data[:surface]
    assert_equal "client", data[:actor_type]
    assert_equal "settings_email", data[:scope]
    assert_not data[:step_up_satisfied]
    assert data[:step_up_usable_token]
    assert_equal "passkey", data[:step_up_method]
    assert_equal "settings_email", data[:step_up_scope]
    assert_match(/\A\d{4}-\d{2}-\d{2}T/, data.fetch(:step_up_expires_at))
    assert_not data.key?(:required_aal)
    assert data.key?(:phishing_resistant_required)
    assert data.key?(:user_verification_required)
    assert data.key?(:full_reauthentication_required)
    serialized = event.to_json

    [token.public_id, actor.public_id, rp_session.public_id, access].each do |private_value|
      assert_not_includes serialized, private_value
    end
  end
end
