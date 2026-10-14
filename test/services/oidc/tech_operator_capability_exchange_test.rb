# typed: false
# frozen_string_literal: true

require "test_helper"

class OidcTechOperatorCapabilityExchangeTest < ActiveSupport::TestCase
  setup do
    @operator = operators(:one)
    @operator_token = OperatorToken.create!(staff: @operator, authentication_event_at: 1.minute.ago)
    @client = OidcClientRegistry.find!("tech-org")
    @redirect_uri = @client.redirect_uris_by_realm.fetch("operator").first
    @code_verifier = SecureRandom.urlsafe_base64(32)
    @code_challenge = Base64.urlsafe_encode64(Digest::SHA256.digest(@code_verifier), padding: false)
  end

  test "authorization code exchange refuses an operator without tech access before RP session issuance" do
    code = OidcAuthorizationCodeIssuer.call(
      client: @client,
      params: {
        client_id: @client.client_id,
        redirect_uri: @redirect_uri,
        code_challenge: @code_challenge,
        code_challenge_method: "S256",
        nonce: "tech-test-nonce",
        scope: "openid profile",
      },
      resource: @operator,
      session_token: @operator_token,
      authentication_event_at: @operator_token.authentication_event_at,
    )
    result =
      OidcClientRegistry.stub(
        :authenticate_assertion,
        ->(client_id, assertion, token_url:) { client_id == "tech-org" && assertion.present? && token_url.present? },
      ) do
        OidcTokenExchangeCoordinator.call(
          grant_type: "authorization_code",
          code: code.code,
          redirect_uri: @redirect_uri,
          client_id: "tech-org",
          client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
          client_assertion: "test-tech-assertion",
          token_endpoint_uri: "https://tech.umaxica.org/oauth/token",
          code_verifier: @code_verifier,
          expected_resource_type: "operator",
        )
      end

    assert_not result.success?
    assert_equal "access_denied", result.error
    assert_equal "issued", Valkey::AuthState::AuthorizationCodeStore.new.read(code.code).fetch("state")
    assert_nil OperatorRpSession.find_by(operator_token: @operator_token, oidc_client_id: "tech-org")
  end

  test "refresh is refused after tech access is revoked without rotating the RP credential" do
    grant = OperatorCapabilityGrant.create!(
      operator: @operator,
      granted_by_operator: operators(:two),
      origin: "grant",
      capability: OperatorCapabilityGrant::TECH_ACCESS,
      reason_code: "duty_assignment",
      starts_at: 1.minute.ago,
      expires_at: 1.day.from_now,
    )
    code = OidcAuthorizationCodeIssuer.call(
      client: @client,
      params: {
        client_id: @client.client_id,
        redirect_uri: @redirect_uri,
        code_challenge: @code_challenge,
        code_challenge_method: "S256",
        nonce: "tech-test-nonce",
        scope: "openid profile",
      },
      resource: @operator,
      session_token: @operator_token,
      authentication_event_at: @operator_token.authentication_event_at,
    )
    exchange_result =
      OidcClientRegistry.stub(
        :authenticate_assertion,
        ->(client_id, assertion, token_url:) { client_id == "tech-org" && assertion.present? && token_url.present? },
      ) do
        OidcTokenExchangeCoordinator.call(
          grant_type: "authorization_code",
          code: code.code,
          redirect_uri: @redirect_uri,
          client_id: "tech-org",
          client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
          client_assertion: "test-tech-assertion",
          token_endpoint_uri: "https://tech.umaxica.org/oauth/token",
          code_verifier: @code_verifier,
          expected_resource_type: "operator",
        )
      end

    assert_predicate exchange_result, :success?
    refresh_token = exchange_result.token_response.fetch(:refresh_token)
    grant.update!(revoked_at: Time.current, revoked_by_operator: operators(:two), revoke_reason_code: "duty_ended")
    refresh_result =
      OidcClientRegistry.stub(
        :authenticate_assertion,
        ->(client_id, assertion, token_url:) { client_id == "tech-org" && assertion.present? && token_url.present? },
      ) do
        OidcTokenExchangeCoordinator.call(
          grant_type: "refresh_token",
          refresh_token: refresh_token,
          client_id: "tech-org",
          client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
          client_assertion: "test-tech-refresh-assertion",
          token_endpoint_uri: "https://tech.umaxica.org/oauth/token",
          expected_resource_type: "operator",
        )
      end

    assert_not refresh_result.success?
    assert_equal "access_denied", refresh_result.error
    rp_session = OperatorRpSession.find_by!(operator_token: @operator_token, oidc_client_id: "tech-org")
    verifier = OperatorToken.parse_refresh_token(refresh_token).last

    assert rp_session.refresh_token_digest_matches?(verifier)
  end
end
