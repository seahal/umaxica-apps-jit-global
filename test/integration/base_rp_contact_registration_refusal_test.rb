# frozen_string_literal: true

require "test_helper"

class BaseRpContactRegistrationRefusalTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []
  include ActiveJob::TestHelper

  test "APP contact registration refuses local RP writes without side effects" do
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

    other_owner = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL,
      status_id: ClientStatus::VERIFIED_WITH_SIGN_UP,
      visibility_id: ClientVisibility::USER,
    )
    registered_email = other_owner.client_emails.create!(
      raw_address: "test@example.com",
      confirm_policy: true,
      user_email_status_id: ClientEmailStatus::VERIFIED,
      binding_finalized_at: ClientEmail.database_now,
    )
    registered_telephone = other_owner.client_telephones.create!(
      raw_number: "+15558675332",
      confirm_policy: true,
      confirm_using_mfa: true,
      user_telephone_status_id: ClientTelephoneStatus::VERIFIED,
      binding_finalized_at: ClientTelephone.database_now,
    )
    other_owner_facts = other_owner.reload.attributes
    registered_email_facts = registered_email.reload.attributes
    registered_telephone_facts = registered_telephone.reload.attributes
    before = [ClientEmail.count, ClientTelephone.count, ClientEmailCeremonyTransaction.count,
              ClientTelephoneCeremonyTransaction.count, enqueued_jobs.size,]
    RuntimeRole.stub(:current, "shared") do
      post(
        base_app_identity_emails_registration_path(ri: "jp"),
        params: { user_email: { raw_address: "test@example.com" } },
      )

      assert_response :service_unavailable
      post(
        base_app_identity_telephones_registration_path(ri: "jp"),
        params: { user_telephone: { raw_number: "+15558675332" } },
      )

      assert_response :service_unavailable
      get(edit_base_app_identity_emails_registration_path(ri: "jp"))

      assert_response :service_unavailable
      patch(base_app_identity_emails_registration_path(ri: "jp"))

      assert_response :service_unavailable

      post(base_app_identity_emails_registration_redelivery_path(ri: "jp"))

      assert_response :service_unavailable
      get(edit_base_app_identity_telephones_registration_path(ri: "jp"))

      assert_response :service_unavailable
      patch(base_app_identity_telephones_registration_path(ri: "jp"))

      assert_response :service_unavailable
    end
    assert_equal before, [ClientEmail.count, ClientTelephone.count, ClientEmailCeremonyTransaction.count,
                          ClientTelephoneCeremonyTransaction.count, enqueued_jobs.size,]
    assert_equal other_owner_facts, other_owner.reload.attributes
    assert_equal registered_email_facts, registered_email.reload.attributes
    assert_equal registered_telephone_facts, registered_telephone.reload.attributes
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

  test "ORG email registration refuses local RP writes without side effects" do
    actor = Operator.create!(
      security_mode_id: SecurityModeConfigurable::ADVANCED,
      status_id: OperatorStatus::ACTIVE,
      visibility_id: OperatorVisibility::STAFF,
    )
    OperatorPasskey.create!(
      staff: actor, webauthn_id: SecureRandom.uuid, external_id: SecureRandom.uuid,
      public_key: "shared-org-public-key", sign_count: 0, description: "Test passkey",
      status_id: OperatorPasskeyStatus::ACTIVE,
    )
    OperatorPasskey.create!(
      staff: actor, webauthn_id: SecureRandom.uuid, external_id: SecureRandom.uuid,
      public_key: "shared-org-second-public-key", sign_count: 0, description: "Test passkey",
      status_id: OperatorPasskeyStatus::ACTIVE,
    )
    root_token = OperatorToken.create!(
      authentication_epoch: 0, staff: actor, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
      staff_token_status_id: OperatorTokenStatus::ACTIVE, staff_token_binding_method_id: OperatorTokenBindingMethod::LEGACY,
      staff_token_dbsc_status_id: OperatorTokenDbscStatus::NOTHING,
    )
    host!(ENV.fetch("PUBLIC_BASE_STAFF_URL"))
    https!

    client_id = "base-org-ww"
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
          token_endpoint_uri: OidcIssuer.token_endpoint("operator"), code_verifier: verifier,
          expected_resource_type: "operator",
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

    grant = OpOrgGrant.find_by!(public_id: payload.fetch("sid"))
    now = Time.at(OpOrgGrant.database_now.to_i).utc
    cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] = AuthenticationTokenService.encode(
      actor, host: ENV.fetch("PUBLIC_BASE_STAFF_URL"), resource_type: "operator",
             session_public_id: root_token.public_id, base_session_public_id: root_token.public_id,
             oidc_sid: grant.public_id, oidc_jti: SecureRandom.uuid, expires_at: now + 10.minutes,
             scopes: %w(openid profile), acr: StepUpEvidenceResolver::STEP_UP_ACR, amr: ["passkey"],
             jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(client), issuer: OidcIssuer.for_client(client),
             audiences: [client.aud], subject: OidcSubject.for(actor, resource_type: "operator"),
             auth_time: now, client_id: client.client_id, authentication_context: AuthenticationContextValue::NORMAL_KEY,
    )
    before = [OperatorEmail.count, OperatorEmailCeremonyTransaction.count, enqueued_jobs.size]
    RuntimeRole.stub(:current, "shared") do
      post(
        base_org_identity_emails_registration_path(ri: "jp"),
        params: { staff_email: { raw_address: "test@example.com" } },
      )

      assert_response :service_unavailable
      get(edit_base_org_identity_emails_registration_path(ri: "jp"))

      assert_response :service_unavailable
      patch(base_org_identity_emails_registration_path(ri: "jp"))

      assert_response :service_unavailable

      root_token.update!(authentication_context: AuthenticationContextValue::STANDBY_KEY)
      cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] = AuthenticationTokenService.encode(
        actor, host: ENV.fetch("PUBLIC_BASE_STAFF_URL"), resource_type: "operator",
               session_public_id: root_token.public_id, base_session_public_id: root_token.public_id,
               oidc_sid: grant.public_id, oidc_jti: SecureRandom.uuid, expires_at: now + 10.minutes,
               scopes: %w(openid profile), acr: StepUpEvidenceResolver::STEP_UP_ACR, amr: ["passkey"],
               jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(client), issuer: OidcIssuer.for_client(client),
               audiences: [client.aud], subject: OidcSubject.for(actor, resource_type: "operator"),
               auth_time: now, client_id: client.client_id, authentication_context: AuthenticationContextValue::STANDBY_KEY,
      )
      post(
        base_org_identity_emails_registration_path(ri: "jp"),
        params: { staff_email: { raw_address: "test@example.com" } },
      )

      assert_response :forbidden

      cookies.delete(OidcRpBrowserCredentialContract::SESSION_COOKIE)
      post(
        base_org_identity_emails_registration_path(ri: "jp"),
        params: { staff_email: { raw_address: "test@example.com" } },
      )

      assert_not_equal 503, response.status
    end
    assert_equal before, [OperatorEmail.count, OperatorEmailCeremonyTransaction.count, enqueued_jobs.size]
  ensure
    if defined?(enrollment) && enrollment&.success?
      RpBaseOrgRecord.connected_to(role: :writing) do
        binding = RpBaseOrgOpSessionBinding.find(enrollment.session.op_session_binding_id)
        identity = RpBaseOrgIdentityBinding.find(binding.identity_binding_id)
        RpBaseOrgSession.where(id: enrollment.session.id).delete_all
        RpBaseOrgOpSessionBinding.where(id: binding.id).delete_all
        RpBaseOrgIdentityBinding.where(id: identity.id).delete_all
        RpBaseOrgPrincipal.where(id: enrollment.principal.id).delete_all

        assert_not RpBaseOrgSession.exists?(id: enrollment.session.id)
        assert_not RpBaseOrgOpSessionBinding.exists?(id: binding.id)
        assert_not RpBaseOrgIdentityBinding.exists?(id: identity.id)
        assert_not RpBaseOrgPrincipal.exists?(id: enrollment.principal.id)
      end
    end
    if defined?(root_token) && root_token&.persisted?
      OpBaseOrgRecord.connected_to(role: :writing) do
        device_id = root_token.reload.device_session_id
        OpOrgGrant.where(operator_token_id: root_token.id).delete_all
        OperatorDeviceSession.where(id: device_id, staff_id: actor.id).update_all(current_refresh_token_id: nil)
        OperatorToken.where(device_session_id: device_id, staff_id: actor.id).delete_all
        OperatorDeviceSession.where(id: device_id, staff_id: actor.id).delete_all

        assert_not OpOrgGrant.exists?(operator_token_id: root_token.id)
        assert_not OperatorToken.exists?(id: root_token.id)
        assert_not OperatorDeviceSession.exists?(id: device_id, staff_id: actor.id)
      end
    end
  end
end
