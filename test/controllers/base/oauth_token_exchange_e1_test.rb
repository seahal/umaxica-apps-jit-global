# typed: false
# frozen_string_literal: true

require "test_helper"

class BaseOauthTokenExchangeE1Test < ActionDispatch::IntegrationTest
  setup do
    @user = clients(:one)
    @user_session_token = ClientToken.create!(user: @user, authentication_event_at: Time.utc(2026, 1, 2, 3, 4, 5))
    @code_verifier = SecureRandom.urlsafe_base64(32)
    @code_challenge = Base64.urlsafe_encode64(Digest::SHA256.digest(@code_verifier), padding: false)
    @client = OidcClientRegistry.find("core-app-jp")
    @redirect_uri = @client.redirect_uris.first
    @host = ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost")
  end

  test "public token endpoint exchanges a bound code and rejects a different same-realm client replay" do
    code_record = issue_code!

    owner_body = nil
    OidcClientRegistry.stub(
      :authenticate_assertion,
      ->(cid, assertion, token_url:) { cid == "core-app-jp" && assertion.present? && token_url.present? },
    ) do
      post base_app_oauth_token_url(host: @host),
           params: {
             grant_type: "authorization_code",
             code: code_record.code,
             redirect_uri: @redirect_uri,
             client_id: "core-app-jp",
             client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
             client_assertion: "test-client-assertion",
             code_verifier: @code_verifier,
           }
      owner_body = response.parsed_body
    end

    assert_response :ok
    assert_predicate owner_body["access_token"], :present?
    event_at = Time.utc(2026, 1, 2, 3, 4, 5).to_i
    access_token = AuthenticationTokenService.decode(
      owner_body.fetch("access_token"),
      host: OidcIssuer.host_for_client(@client),
      resource_type: "client",
      issuer: OidcIssuer.for_client(@client),
      audiences: [@client.aud],
      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(@client),
    )
    id_token = JWT.decode(owner_body.fetch("id_token"), nil, false).first

    assert_equal event_at, access_token.fetch("auth_time")
    assert_equal event_at, id_token.fetch("auth_time")
    assert_operator access_token.fetch("iat"), :>=, event_at
    owner_session = OpAppGrant.order(:created_at).last
    owner_digest = owner_session.refresh_token_digest
    warp_client = OidcClientRegistry.find("warp-app-jp")

    OidcClientRegistry.stub(
      :authenticate_assertion,
      ->(cid, assertion, token_url:) { cid == "warp-app-jp" && assertion.present? && token_url.present? },
    ) do
      post base_app_oauth_token_url(host: @host),
           params: {
             grant_type: "authorization_code",
             code: code_record.code,
             redirect_uri: warp_client.redirect_uris.first,
             client_id: "warp-app-jp",
             client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
             client_assertion: "warp-app-client-assertion",
             code_verifier: @code_verifier,
           }
    end

    assert_response :bad_request
    assert_includes %w(invalid_grant invalid_request), response.parsed_body.fetch("error")
    owner_session.reload

    assert_nil owner_session.revoked_at
    assert_equal owner_digest, owner_session.refresh_token_digest
    assert_predicate @user_session_token.reload, :currently_usable?
    payload = Valkey::AuthState::AuthorizationCodeStore.new.read(code_record.code)

    assert_equal "consumed", payload.fetch("state")
  end

  test "public token endpoint keeps a consumed code consumed after a lost-response replay" do
    code_record = issue_code!

    OidcClientRegistry.stub(
      :authenticate_assertion,
      ->(cid, assertion, token_url:) { cid == "core-app-jp" && assertion.present? && token_url.present? },
    ) do
      post base_app_oauth_token_url(host: @host),
           params: {
             grant_type: "authorization_code",
             code: code_record.code,
             redirect_uri: @redirect_uri,
             client_id: "core-app-jp",
             client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
             client_assertion: "test-client-assertion",
             code_verifier: @code_verifier,
           }

      assert_response :ok

      post base_app_oauth_token_url(host: @host),
           params: {
             grant_type: "authorization_code",
             code: code_record.code,
             redirect_uri: @redirect_uri,
             client_id: "core-app-jp",
             client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
             client_assertion: "test-client-assertion",
             code_verifier: @code_verifier,
           }
    end

    assert_response :bad_request
    assert_equal "invalid_grant", response.parsed_body.fetch("error")
    payload = Valkey::AuthState::AuthorizationCodeStore.new.read(code_record.code)

    assert_equal "consumed", payload.fetch("state")
  end

  test "public Code and Refresh exchange preserve the emergency root authentication context" do
    operator = operators(:one)
    operator.update!(status_id: OperatorStatus::ACTIVE)
    root_token = operator_tokens(:one)
    root_token.update!(authentication_context: AuthenticationContextValue::STANDBY_KEY)
    client = OidcClientRegistry.find!("core-org-jp")
    base_host = ENV.fetch("PUBLIC_BASE_STAFF_URL")
    token_url = base_org_oauth_token_url(host: base_host)
    redirect_uri = client.redirect_uris_by_realm.fetch("operator").first
    code_verifier = SecureRandom.urlsafe_base64(32)
    code_challenge = Base64.urlsafe_encode64(Digest::SHA256.digest(code_verifier), padding: false)
    authentication_event_at = Time.current
    original_active_kid = ENV["OIDC_CLIENT_CORE_ORG_JP_ACTIVE_KID"]
    original_private_key = ENV["OIDC_CLIENT_CORE_ORG_JP_PRIVATE_KEY"]
    assertion_key = OpenSSL::PKey::EC.generate("secp384r1")
    ENV["OIDC_CLIENT_CORE_ORG_JP_ACTIVE_KID"] = "core-org-r1-test"
    ENV["OIDC_CLIENT_CORE_ORG_JP_PRIVATE_KEY"] = Base64.strict_encode64(assertion_key.to_der)
    JitSecurityJwtRegistry.reload!
    code = OidcAuthorizationCodeIssuer.call(
      client: client,
      params: {
        client_id: client.client_id,
        redirect_uri: redirect_uri,
        code_challenge: code_challenge,
        code_challenge_method: "S256",
        nonce: "operator-code-nonce",
        scope: "openid profile",
      },
      resource: operator,
      session_token: root_token,
      auth_method: "passkey",
      authentication_event_at: authentication_event_at,
    )

    post(
      token_url,
      params: {
        grant_type: "authorization_code",
        code: code.code,
        redirect_uri: redirect_uri,
        client_id: client.client_id,
        client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
        client_assertion: OidcClientAssertionJwt.issue(client_id: client.client_id, token_url: token_url),
        code_verifier: code_verifier,
      },
    )

    assert_response :ok
    code_response = response.parsed_body
    code_access_claims = AuthenticationTokenService.decode(
      code_response.fetch("access_token"),
      host: OidcIssuer.host_for_resource_type("operator"),
      resource_type: "operator",
      issuer: OidcIssuer.for_resource_type("operator"),
      audiences: [client.aud],
      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(client),
    )

    assert_equal AuthenticationContextValue::STANDBY_KEY,
                 code_access_claims.fetch(AuthenticationContextValue::CLAIM)

    refresh_token = code_response.fetch("refresh_token")
    previous_refresh_claims = code_access_claims
    3.times do
      post(
        token_url,
        params: {
          grant_type: "refresh_token",
          refresh_token: refresh_token,
          client_id: client.client_id,
          client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
          client_assertion: OidcClientAssertionJwt.issue(client_id: client.client_id, token_url: token_url),
        },
      )

      assert_response :ok
      refresh_response = response.parsed_body
      refreshed_claims = AuthenticationTokenService.decode(
        refresh_response.fetch("access_token"),
        host: OidcIssuer.host_for_resource_type("operator"),
        resource_type: "operator",
        issuer: OidcIssuer.for_resource_type("operator"),
        audiences: [client.aud],
        jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(client),
      )

      assert_equal AuthenticationContextValue::STANDBY_KEY,
                   refreshed_claims.fetch(AuthenticationContextValue::CLAIM)
      assert_equal previous_refresh_claims.fetch("acr"), refreshed_claims.fetch("acr")
      assert_equal previous_refresh_claims.fetch("amr"), refreshed_claims.fetch("amr")
      refresh_token = refresh_response.fetch("refresh_token")
      previous_refresh_claims = refreshed_claims
    end

    assert_equal AuthenticationContextValue::STANDBY_KEY, root_token.reload.authentication_context
  ensure
    if original_active_kid.nil?
      ENV.delete("OIDC_CLIENT_CORE_ORG_JP_ACTIVE_KID")
    else
      ENV["OIDC_CLIENT_CORE_ORG_JP_ACTIVE_KID"] = original_active_kid
    end
    if original_private_key.nil?
      ENV.delete("OIDC_CLIENT_CORE_ORG_JP_PRIVATE_KEY")
    else
      ENV["OIDC_CLIENT_CORE_ORG_JP_PRIVATE_KEY"] = original_private_key
    end
    JitSecurityJwtRegistry.reload!
  end

  private

  def issue_code!
    OidcAuthorizationCodeIssuer.call(
      client: @client,
      params: {
        client_id: "core-app-jp",
        redirect_uri: @redirect_uri,
        code_challenge: @code_challenge,
        code_challenge_method: "S256",
        nonce: "test_nonce",
        scope: "openid profile email",
      },
      resource: @user,
      session_token: @user_session_token,
      authentication_event_at: Time.utc(2026, 1, 2, 3, 4, 5),
    )
  end
end
