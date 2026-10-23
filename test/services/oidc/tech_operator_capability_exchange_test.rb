# typed: false
# frozen_string_literal: true

require "test_helper"

class OidcTechOperatorCapabilityExchangeTest < ActiveSupport::TestCase
  setup do
    @operator = operators(:one)
    @operator_token = OperatorToken.create!(
      authentication_epoch: 0, staff: @operator,
      authentication_event_at: 1.minute.ago,
    )
    @client = OidcClientRegistry.find!("tech-org-ww")
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
        ->(client_id, assertion, token_url:) { client_id == "tech-org-ww" && assertion.present? && token_url.present? },
      ) do
        OidcTokenExchangeCoordinator.call(
          grant_type: "authorization_code",
          code: code.code,
          redirect_uri: @redirect_uri,
          client_id: "tech-org-ww",
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
    assert_nil OpOrgGrant.find_by(operator_token: @operator_token, oidc_client_id: "tech-org-ww")
  end

  test "Tech capability does not bypass PKCE or exact callback binding with real client assertions" do
    OperatorCapabilityGrant.create!(
      operator: @operator, granted_by_operator: operators(:two), origin: "grant",
      capability: OperatorCapabilityGrant::TECH_ACCESS, reason_code: "duty_assignment",
      starts_at: 1.minute.ago, expires_at: 1.day.from_now,
    )
    token_url = OidcIssuer.token_endpoint("operator")
    [
      { verifier: "x" * 43, redirect_uri: @redirect_uri },
      { verifier: @code_verifier, redirect_uri: "#{@redirect_uri}/foreign" },
    ].each do |input|
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
        resource: @operator, session_token: @operator_token,
        authentication_event_at: @operator_token.authentication_event_at,
      )
      assertion = OidcClientAssertionJwt.issue(client_id: "tech-org-ww", token_url: token_url)
      result = OidcTokenExchangeCoordinator.call(
        grant_type: "authorization_code", code: code.code, client_id: "tech-org-ww",
        redirect_uri: input.fetch(:redirect_uri), code_verifier: input.fetch(:verifier),
        client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
        client_assertion: assertion, token_endpoint_uri: token_url, expected_resource_type: "operator",
      )

      assert_not_predicate result, :success?
      # RFC 6749 5.2 / RFC 7636 4.6 (D-147 N-3): a wrong verifier or a foreign redirect_uri.
      assert_equal "invalid_grant", result.error
      assert_not OpOrgGrant.exists?(operator_token: @operator_token, oidc_client_id: "tech-org-ww")
      assert_predicate @operator_token.reload, :currently_usable?
    end
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
        ->(client_id, assertion, token_url:) { client_id == "tech-org-ww" && assertion.present? && token_url.present? },
      ) do
        OidcTokenExchangeCoordinator.call(
          grant_type: "authorization_code",
          code: code.code,
          redirect_uri: @redirect_uri,
          client_id: "tech-org-ww",
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
        ->(client_id, assertion, token_url:) { client_id == "tech-org-ww" && assertion.present? && token_url.present? },
      ) do
        OidcTokenExchangeCoordinator.call(
          grant_type: "refresh_token",
          refresh_token: refresh_token,
          client_id: "tech-org-ww",
          client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
          client_assertion: "test-tech-refresh-assertion",
          token_endpoint_uri: "https://tech.umaxica.org/oauth/token",
          expected_resource_type: "operator",
        )
      end

    assert_not refresh_result.success?
    assert_equal "access_denied", refresh_result.error
    rp_session = OpOrgGrant.find_by!(operator_token: @operator_token, oidc_client_id: "tech-org-ww")
    verifier = OperatorToken.parse_refresh_token(refresh_token).last

    assert rp_session.refresh_token_digest_matches?(verifier)
  end
end
