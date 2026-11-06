# frozen_string_literal: true

require "test_helper"
require "minitest/mock"

class BaseSharedRpCellSelectionTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  test "shared Base APP requires its RP cell session" do
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
    host! ENV.fetch("PUBLIC_BASE_SERVICE_URL")
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

    RuntimeRole.stub(:current, "shared") do
      get base_app_verification_path(ri: "jp")

      assert_response :success

      auth_cookie_presence = [
        cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE].present?,
        cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE].present?,
        cookies[OidcRpBrowserCredentialContract::SESSION_COOKIE].present?,
      ]
      selection_owner = Minitest::Mock.new
      OrgAdminAuthorityClient.stub(:new, selection_owner) do
        get base_app_verification_path(ri: "jp")

        assert_response :success
        assert_equal auth_cookie_presence, [
          cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE].present?,
          cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE].present?,
          cookies[OidcRpBrowserCredentialContract::SESSION_COOKIE].present?,
        ]
      end
      selection_owner.verify

      post base_app_verification_path(ri: "jp"), params: { return_target: "/settings/birthdate" }

      assert_response :see_other

      authorization_uri = URI.parse(response.location)
      if authorization_uri.host == "jump.umaxica.net"
        jump_token = Rack::Utils.parse_nested_query(authorization_uri.query).fetch("rt")
        jump_claims, = JWT.decode(jump_token, nil, false)
        authorization_uri = URI.parse(jump_claims.fetch("url"))
      end
      expected_uri = URI.parse(OidcIssuer.authorization_endpoint("client"))

      assert_equal [expected_uri.scheme, expected_uri.host, expected_uri.port, expected_uri.path],
                   [authorization_uri.scheme, authorization_uri.host, authorization_uri.port, authorization_uri.path]
      assert_equal client_id, Rack::Utils.parse_query(authorization_uri.query).fetch("client_id")

      cookies.delete(OidcRpBrowserCredentialContract::SESSION_COOKIE)
      get base_app_verification_path(ri: "jp")

      assert_not response.successful?
    end
  end

  test "shared Base ORG requires its RP cell session" do
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
    root_token = OperatorToken.create!(
      authentication_epoch: 0, staff: actor, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
      staff_token_status_id: OperatorTokenStatus::ACTIVE, staff_token_binding_method_id: OperatorTokenBindingMethod::LEGACY,
      staff_token_dbsc_status_id: OperatorTokenDbscStatus::NOTHING,
    )
    host! ENV.fetch("PUBLIC_BASE_STAFF_URL")
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

    RuntimeRole.stub(:current, "shared") do
      get base_org_verification_path(ri: "jp")

      assert_response :success

      post base_org_verification_path(ri: "jp"), params: { return_target: "/settings/birthdate" }

      assert_response :see_other

      authorization_uri = URI.parse(response.location)
      if authorization_uri.host == "jump.umaxica.net"
        jump_token = Rack::Utils.parse_nested_query(authorization_uri.query).fetch("rt")
        jump_claims, = JWT.decode(jump_token, nil, false)
        authorization_uri = URI.parse(jump_claims.fetch("url"))
      end
      expected_uri = URI.parse(OidcIssuer.authorization_endpoint("operator"))

      assert_equal [expected_uri.scheme, expected_uri.host, expected_uri.port, expected_uri.path],
                   [authorization_uri.scheme, authorization_uri.host, authorization_uri.port, authorization_uri.path]
      assert_equal client_id, Rack::Utils.parse_query(authorization_uri.query).fetch("client_id")

      cookies.delete(OidcRpBrowserCredentialContract::SESSION_COOKIE)
      get base_org_verification_path(ri: "jp")

      assert_not response.successful?
    end
  end
end
