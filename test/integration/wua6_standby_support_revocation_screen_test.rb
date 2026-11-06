# frozen_string_literal: true

require "test_helper"

class Wua6StandbySupportRevocationScreenTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  test "ORG read-only owner screens deny Standby and allow Normal with fresh matching Step-Up" do
    host = ENV.fetch("PUBLIC_BASE_STAFF_URL")
    operator = Operator.create!(
      security_mode_id: SecurityModeTestDefault.id_for(Operator),
      status_id: OperatorStatus::ACTIVE,
      visibility_id: OperatorVisibility::STAFF,
    )
    granter = Operator.create!(
      security_mode_id: SecurityModeTestDefault.id_for(Operator),
      status_id: OperatorStatus::ACTIVE,
      visibility_id: OperatorVisibility::STAFF,
    )
    client_account = Client.create!(
      security_mode_id: SecurityModeTestDefault.id_for(Client),
      status_id: ClientStatus::ACTIVE,
      visibility_id: ClientVisibility::USER,
    )
    [OperatorCapabilityGrant::SUPPORT_ACCOUNT_READ_APP,
     OperatorCapabilityGrant::SUPPORT_SESSION_REVOKE_APP,].each do |capability|
      OperatorCapabilityGrant.create!(
        operator:,
        granted_by_operator: granter,
        origin: "grant",
        capability:,
        reason_code: "duty_assignment",
        starts_at: 1.minute.ago,
        expires_at: 1.day.from_now,
      )
    end
    [OperatorCapabilityGrant::IAM_CAPABILITY_READ,
     OperatorCapabilityGrant::IAM_CAPABILITY_GRANT,].each do |capability|
      OperatorCapabilityGrant.create!(
        operator:,
        origin: "bootstrap",
        capability:,
        reason_code: "bootstrap",
        starts_at: 1.minute.ago,
        expires_at: 1.day.from_now,
      )
    end
    root_token = OperatorToken.create!(
      authentication_epoch: 0,
      staff_id: operator.id,
      root_login_established_at: Time.current,
      authentication_context: AuthenticationContextValue::STANDBY_KEY,
    )
    rp_client = OidcClientRegistry.find!("base-org-ww")
    rp_grant = OpOrgGrant.create!(
      authentication_epoch: 0,
      operator_token: root_token,
      oidc_client_id: rp_client.client_id,
      oidc_scope: "openid profile",
      oidc_jti: SecureRandom.uuid,
      oidc_auth_time: Time.current,
      refresh_token_expires_at: 10.minutes.from_now,
    )
    owner_screens = [
      ["/api/v0/support/app/accounts/#{client_account.public_id}/revocation-screen", "support_session_revoke",
       "account",],
      ["/api/v0/iam/grant-screen", "operator_capability", "grantable_capabilities"],
    ]

    owner_screens.each do |path, scope, response_key|
      token_url = "http://#{host}#{path}"
      standby_access_token = AuthenticationTokenService.encode(
        operator,
        host:,
        resource_type: "operator",
        session_public_id: root_token.public_id,
        base_session_public_id: root_token.public_id,
        oidc_sid: rp_grant.public_id,
        oidc_jti: rp_grant.oidc_jti,
        expires_at: 10.minutes.from_now,
        scopes: %w(openid profile),
        issuer: OidcIssuer.for_client(rp_client),
        audiences: [rp_client.aud],
        jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(rp_client),
        subject: OidcSubject.for(operator, resource_type: "operator"),
        client_id: rp_client.client_id,
        authentication_context: AuthenticationContextValue::STANDBY_KEY,
      )

      get(
        token_url,
        headers: {
          "Authorization" => "Bearer #{standby_access_token}",
          "X-Client-Assertion" => OidcClientAssertionJwt.issue(client_id: rp_client.client_id, token_url:),
        },
      )

      assert_response :forbidden, "Standby must not read #{path}"
      assert_equal "step_up_required", response.parsed_body.fetch("error")
      assert_equal scope, response.parsed_body.fetch("scope")
      assert_not_includes response.parsed_body, response_key
    end

    owner_screens.each do |path, scope, response_key|
      token_url = "http://#{host}#{path}"
      root_token.update!(
        authentication_context: AuthenticationContextValue::NORMAL_KEY,
        last_step_up_at: Time.current,
        last_step_up_scope: scope,
        last_step_up_aal: "aal2",
        last_step_up_method: "passkey",
        last_step_up_phishing_resistant: true,
        last_step_up_user_verified: true,
        last_step_up_credential_ref: "test-step-up-credential",
        last_step_up_full_reauthentication: false,
        last_step_up_session_public_id: root_token.public_id,
        last_step_up_purpose: "step_up",
        last_step_up_audience: "step_up:org",
      )
      normal_access_token = AuthenticationTokenService.encode(
        operator,
        host:,
        resource_type: "operator",
        session_public_id: root_token.public_id,
        base_session_public_id: root_token.public_id,
        oidc_sid: rp_grant.public_id,
        oidc_jti: rp_grant.oidc_jti,
        expires_at: 10.minutes.from_now,
        scopes: %w(openid profile),
        issuer: OidcIssuer.for_client(rp_client),
        audiences: [rp_client.aud],
        jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(rp_client),
        subject: OidcSubject.for(operator, resource_type: "operator"),
        client_id: rp_client.client_id,
        authentication_context: AuthenticationContextValue::NORMAL_KEY,
      )

      get(
        token_url,
        headers: {
          "Authorization" => "Bearer #{normal_access_token}",
          "X-Client-Assertion" => OidcClientAssertionJwt.issue(client_id: rp_client.client_id, token_url:),
        },
      )

      assert_response :success, "Normal with fresh proof must read #{path}"
      assert response.parsed_body.key?(response_key)
      if scope == "support_session_revoke"
        assert_equal client_account.public_id, response.parsed_body.dig("account", "public_id")
        assert_equal 0, response.parsed_body.dig("account", "active_sessions")
      elsif scope == "operator_capability"
        assert_predicate response.parsed_body.fetch("grantable_capabilities"), :any?
      else
        raise ArgumentError, "unsupported owner screen scope: #{scope.inspect}"
      end
    end
  end
end
