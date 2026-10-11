# typed: false
# frozen_string_literal: true

require "test_helper"

class BaseOauthTokenExchangeE1Test < ActionDispatch::IntegrationTest
  setup do
    @user = clients(:one)
    @user_session_token = ClientToken.create!(user: @user, authentication_event_at: Time.utc(2026, 1, 2, 3, 4, 5))
    @code_verifier = SecureRandom.urlsafe_base64(32)
    @code_challenge = Base64.urlsafe_encode64(Digest::SHA256.digest(@code_verifier), padding: false)
    @client = OidcClientRegistry.find("core-next-rp")
    @redirect_uri = @client.redirect_uris.first
    @host = ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost")
  end

  test "public token endpoint exchanges a bound code and rejects a different same-realm client replay" do
    code_record = issue_code!

    owner_body = nil
    OidcClientRegistry.stub(
      :authenticate_assertion,
      ->(cid, assertion, token_url:) { cid == "core-next-rp" && assertion.present? && token_url.present? },
    ) do
      post base_app_oauth_token_url(host: @host),
           params: {
             grant_type: "authorization_code",
             code: code_record.code,
             redirect_uri: @redirect_uri,
             client_id: "core-next-rp",
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
    owner_session = ClientRpSession.order(:created_at).last
    owner_digest = owner_session.refresh_token_digest
    side_client = OidcClientRegistry.find("side-app")

    OidcClientRegistry.stub(
      :authenticate_assertion,
      ->(cid, assertion, token_url:) { cid == "side-app" && assertion.present? && token_url.present? },
    ) do
      post base_app_oauth_token_url(host: @host),
           params: {
             grant_type: "authorization_code",
             code: code_record.code,
             redirect_uri: side_client.redirect_uris.first,
             client_id: "side-app",
             client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
             client_assertion: "side-app-client-assertion",
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
      ->(cid, assertion, token_url:) { cid == "core-next-rp" && assertion.present? && token_url.present? },
    ) do
      post base_app_oauth_token_url(host: @host),
           params: {
             grant_type: "authorization_code",
             code: code_record.code,
             redirect_uri: @redirect_uri,
             client_id: "core-next-rp",
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
             client_id: "core-next-rp",
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

  private

  def issue_code!
    OidcAuthorizationCodeIssuer.call(
      client: @client,
      params: {
        client_id: "core-next-rp",
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
