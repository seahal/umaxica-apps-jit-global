# frozen_string_literal: true

require "test_helper"
class BaseSharedWithdrawalLocalSessionTest < ActionDispatch::IntegrationTest
  test "deactivated APP local RP session redirects and cannot open withdrawal pages" do
    actor = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL,
      status_id: ClientStatus::ACTIVE,
      visibility_id: ClientVisibility::USER,
    )
    ClientPasskey.create!(
      user: actor, webauthn_id: SecureRandom.uuid, external_id: SecureRandom.uuid,
      public_key: "shared-app-public-key", sign_count: 0, description: "Test passkey",
      status_id: ClientPasskeyStatus::ACTIVE,
    )
    root_token = ClientToken.create!(
      authentication_epoch: 0, user: actor, user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      user_token_status_id: ClientTokenStatus::ACTIVE, user_token_binding_method_id: ClientTokenBindingMethod::LEGACY,
      user_token_dbsc_status_id: ClientTokenDbscStatus::NOTHING,
    )
    host!(ENV.fetch("PUBLIC_BASE_SERVICE_URL"))
    https!

    client_id = "base-app-ww"
    client = OidcClientRegistry.find!(client_id)
    cell = RpCellBinding.for_client(client_id)
    verifier = SecureRandom.urlsafe_base64(48)
    params = {
      client_id:,
      redirect_uri: client.redirect_uris.first,
      response_type: "code",
      scope: "openid",
      state: SecureRandom.hex(16),
      nonce: SecureRandom.hex(16),
      code_challenge_method: "S256",
      code_challenge: Base64.urlsafe_encode64(Digest::SHA256.digest(verifier), padding: false),
    }
    code = OidcAuthorizationCodeIssuer.call(
      client:, params:, resource: actor, session_token: root_token, authentication_event_at: 1.minute.ago,
    )
    result =
      OidcClientRegistry.stub(
        :verify_client_assertion,
        ->(asserted_client_id, *, **) {
          OidcClientRegistry::AssertionAuthenticationResult.new(
            authenticated: true, client: OidcClientRegistry.find(asserted_client_id),
            step_up_claims_state: :none, step_up_expectation: nil,
          )
        },
      ) do
        OidcTokenExchangeCoordinator.call(
          grant_type: "authorization_code", code: code.code, redirect_uri: code.redirect_uri, client_id:,
          client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE, client_assertion: "test-assertion",
          token_endpoint_uri: OidcIssuer.token_endpoint("client"), code_verifier: verifier,
          expected_resource_type: "client",
        )
      end

    assert_predicate result, :success?

    token_response = result.token_response
    payload, = JWT.decode(token_response.fetch(:id_token), nil, false)
    enrollment = RpCallbackCommitter.call(
      cell:, issuer: payload.fetch("iss"), subject: payload.fetch("sub"), sid: payload.fetch("sid"),
      absolute_expires_at: 1.hour.from_now,
    )

    assert_predicate enrollment, :success?

    cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] = token_response.fetch(:access_token)
    cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE] = token_response.fetch(:refresh_token)
    cookies[OidcRpBrowserCredentialContract::SESSION_COOKIE] = enrollment.session.public_id

    actor.reload.update!(
      withdrawal_started_at: 2.hours.ago, deactivated_at: 90.minutes.ago,
      discard_at: 31.days.from_now, purge_eligible_at: 31.days.from_now,
    )
    RuntimeRole.stub(:current, "shared") do
      get(base_app_identity_sessions_path(ri: "jp"))

      assert_redirected_to new_base_app_identity_withdrawal_session_path(ri: "jp")
      get(base_app_identity_sessions_path(ri: "jp"), headers: { "Accept" => "application/json" })

      assert_response :forbidden
      assert_equal "WITHDRAWAL_REQUIRED", response.parsed_body.fetch("error")

      get(new_base_app_identity_withdrawal_path(ri: "jp"))

      assert_response :unauthorized
      assert_equal enrollment.session.public_id, cookies[OidcRpBrowserCredentialContract::SESSION_COOKIE]
    end
  ensure
    if defined?(enrollment) && enrollment&.success?
      RpBaseAppRecord.connected_to(role: :writing) do
        binding = RpBaseAppOpSessionBinding.find(enrollment.session.op_session_binding_id)
        identity = RpBaseAppIdentityBinding.find(binding.identity_binding_id)
        RpBaseAppSession.where(id: enrollment.session.id).delete_all
        RpBaseAppOpSessionBinding.where(id: binding.id).delete_all
        RpBaseAppIdentityBinding.where(id: identity.id).delete_all
        RpBaseAppPrincipal.where(id: enrollment.principal.id).delete_all

        assert_not RpBaseAppSession.exists?(id: enrollment.session.id)
        assert_not RpBaseAppOpSessionBinding.exists?(id: binding.id)
        assert_not RpBaseAppIdentityBinding.exists?(id: identity.id)
        assert_not RpBaseAppPrincipal.exists?(id: enrollment.principal.id)
      end
    end
    if defined?(root_token) && root_token&.persisted?
      OpBaseAppRecord.connected_to(role: :writing) do
        device_id = root_token.reload.device_session_id
        OpAppGrant.where(client_token_id: root_token.id).delete_all
        ClientDeviceSession.where(id: device_id, user_id: actor.id).update_all(current_refresh_token_id: nil)
        ClientToken.where(device_session_id: device_id, user_id: actor.id).delete_all
        ClientDeviceSession.where(id: device_id, user_id: actor.id).delete_all

        assert_not OpAppGrant.exists?(client_token_id: root_token.id)
        assert_not ClientToken.exists?(id: root_token.id)
        assert_not ClientDeviceSession.exists?(id: device_id, user_id: actor.id)
      end
    end
  end
end
