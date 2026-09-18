# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class OidcTokenExchangeCoordinatorTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

  setup do
    @user = clients(:one)
    @user_session_token = ClientToken.create!(user: @user)
    @code_verifier = SecureRandom.urlsafe_base64(32)
    @code_challenge = Base64.urlsafe_encode64(
      Digest::SHA256.digest(@code_verifier),
      padding: false,
    )
    @client = OidcClientRegistry.find("core-next-rp")
    @redirect_uri = @client.redirect_uris.first
    @client_secret = "test_secret_credential_for_core_app"
  end

  test "exchanges valid code for tokens" do
    code_record = issue_code!

    result =
      with_authenticated_client do
        OidcTokenExchangeCoordinator.call(
          grant_type: "authorization_code",
          code: code_record.code,
          redirect_uri: @redirect_uri,
          client_id: "core-next-rp",
          client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
          client_assertion: "test-client-assertion",
          token_endpoint_uri: "https://log.umaxica.app/oauth/token",
          code_verifier: @code_verifier,
          expected_resource_type: "client",
        )
      end

    assert_predicate result, :success?
    assert_predicate result.token_response[:access_token], :present?
    assert_predicate result.token_response[:refresh_token], :present?
    assert_predicate result.token_response[:id_token], :present?
    assert_equal "Bearer", result.token_response[:token_type]
    assert_kind_of Integer, result.token_response[:expires_in]
  end

  test "refresh grant rotates the RP refresh token and reissues tokens with the original auth time" do
    authentication_event_at = Time.utc(2026, 1, 2, 3, 4, 5)
    @user_session_token.update!(authentication_event_at: authentication_event_at)
    code_record = issue_code!

    initial_result =
      with_authenticated_client do
        OidcTokenExchangeCoordinator.call(
          grant_type: "authorization_code",
          code: code_record.code,
          redirect_uri: @redirect_uri,
          client_id: "core-next-rp",
          client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
          client_assertion: "test-client-assertion",
          token_endpoint_uri: "https://log.umaxica.app/oauth/token",
          code_verifier: @code_verifier,
          expected_resource_type: "client",
        )
      end

    assert_predicate initial_result, :success?

    refreshed_result =
      with_authenticated_client do
        OidcTokenExchangeCoordinator.call(
          grant_type: "refresh_token",
          refresh_token: initial_result.token_response.fetch(:refresh_token),
          client_id: "core-next-rp",
          client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
          client_assertion: "test-client-assertion",
          token_endpoint_uri: "https://log.umaxica.app/oauth/token",
          expected_resource_type: "client",
        )
      end

    assert_predicate refreshed_result, :success?
    assert_predicate refreshed_result.token_response[:access_token], :present?
    assert_predicate refreshed_result.token_response[:refresh_token], :present?
    assert_predicate refreshed_result.token_response[:id_token], :present?
    assert_not_equal initial_result.token_response.fetch(:refresh_token),
                     refreshed_result.token_response.fetch(:refresh_token)

    access_payload = AuthenticationTokenService.decode(
      refreshed_result.token_response.fetch(:access_token),
      host: OidcIssuer.host_for_client(@client),
      resource_type: "client",
      issuer: OidcIssuer.for_client(@client),
      audiences: [@client.aud],
      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(@client),
    )
    id_payload = JWT.decode(refreshed_result.token_response.fetch(:id_token), nil, false).first

    assert_equal authentication_event_at.to_i, access_payload.fetch("auth_time")
    assert_equal authentication_event_at.to_i, id_payload.fetch("auth_time")
    assert_operator access_payload.fetch("iat"), :>, authentication_event_at.to_i
  end

  test "refresh grant rejects a different registered client without rotating the usage" do
    @user_session_token.update!(authentication_event_at: Time.utc(2026, 1, 2, 3, 4, 5))
    code_record = issue_code!
    initial_result =
      with_authenticated_client do
        OidcTokenExchangeCoordinator.call(
          grant_type: "authorization_code",
          code: code_record.code,
          redirect_uri: @redirect_uri,
          client_id: "core-next-rp",
          client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
          client_assertion: "test-client-assertion",
          token_endpoint_uri: "https://log.umaxica.app/oauth/token",
          code_verifier: @code_verifier,
          expected_resource_type: "client",
        )
      end
    refresh_token = initial_result.token_response.fetch(:refresh_token)

    OidcClientRegistry.stub(
      :authenticate_assertion, ->(_client_id, assertion, token_url:) { assertion.present? && token_url.present? },
    ) do
      result = OidcTokenExchangeCoordinator.call(
        grant_type: "refresh_token",
        refresh_token: refresh_token,
        client_id: "side-app",
        client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
        client_assertion: "different-client-assertion",
        token_endpoint_uri: "https://wide.app.localhost/oauth/token",
        expected_resource_type: "client",
      )

      assert_not result.success?
      assert_equal "invalid_grant", result.error
    end

    follow_up =
      with_authenticated_client do
        OidcTokenExchangeCoordinator.call(
          grant_type: "refresh_token",
          refresh_token: refresh_token,
          client_id: "core-next-rp",
          client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
          client_assertion: "test-client-assertion",
          token_endpoint_uri: "https://log.umaxica.app/oauth/token",
          expected_resource_type: "client",
        )
      end

    assert_predicate follow_up, :success?
  end

  test "refresh grant fails closed when the RP session has no authentication event" do
    usage = ClientRpSession.create!(
      client_token: @user_session_token,
      oidc_client_id: "core-next-rp",
      oidc_scope: "openid profile",
      oidc_jti: SecureRandom.uuid,
      oidc_nonce: "refresh_nonce",
      refresh_token_expires_at: 1.hour.from_now,
    )
    refresh_token = usage.issue_refresh_token!

    result =
      with_authenticated_client do
        OidcTokenExchangeCoordinator.call(
          grant_type: "refresh_token",
          refresh_token: refresh_token,
          client_id: "core-next-rp",
          client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
          client_assertion: "test-client-assertion",
          token_endpoint_uri: "https://log.umaxica.app/oauth/token",
          expected_resource_type: "client",
        )
      end

    assert_not result.success?
    assert_equal "invalid_grant", result.error
    assert usage.reload.refresh_token_digest_matches?(ClientToken.parse_refresh_token(refresh_token).last)
  end

  test "refresh grant rejects a missing refresh token before resolving storage" do
    result =
      with_authenticated_client do
        OidcTokenExchangeCoordinator.call(
          grant_type: "refresh_token",
          client_id: "core-next-rp",
          client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
          client_assertion: "test-client-assertion",
          token_endpoint_uri: "https://log.umaxica.app/oauth/token",
          expected_resource_type: "client",
        )
      end

    assert_not result.success?
    assert_equal "invalid_grant", result.error
  end

  test "refresh grant rejects an unknown refresh token" do
    result =
      with_authenticated_client do
        OidcTokenExchangeCoordinator.call(
          grant_type: "refresh_token",
          refresh_token: "not-a-refresh-token",
          client_id: "core-next-rp",
          client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
          client_assertion: "test-client-assertion",
          token_endpoint_uri: "https://log.umaxica.app/oauth/token",
          expected_resource_type: "client",
        )
      end

    assert_not result.success?
    assert_equal "invalid_grant", result.error
  end

  test "refresh grant rejects a scope that no longer contains openid" do
    @user_session_token.update!(authentication_event_at: Time.utc(2026, 1, 2, 3, 4, 5))
    initial_result =
      with_authenticated_client do
        OidcTokenExchangeCoordinator.call(
          grant_type: "authorization_code",
          code: issue_code!.code,
          redirect_uri: @redirect_uri,
          client_id: "core-next-rp",
          client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
          client_assertion: "test-client-assertion",
          token_endpoint_uri: "https://log.umaxica.app/oauth/token",
          code_verifier: @code_verifier,
          expected_resource_type: "client",
        )
      end
    usage = ClientRpSession.find_by!(client_token: @user_session_token, oidc_client_id: "core-next-rp")
    usage.update!(oidc_scope: "profile")

    result =
      with_authenticated_client do
        OidcTokenExchangeCoordinator.call(
          grant_type: "refresh_token",
          refresh_token: initial_result.token_response.fetch(:refresh_token),
          client_id: "core-next-rp",
          client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
          client_assertion: "test-client-assertion",
          token_endpoint_uri: "https://log.umaxica.app/oauth/token",
          expected_resource_type: "client",
        )
      end

    assert_not result.success?
    assert_equal "invalid_grant", result.error
    assert_predicate usage.reload.refresh_token_digest, :present?
  end

  test "refresh grant rejects an inactive root session" do
    @user_session_token.update!(authentication_event_at: Time.utc(2026, 1, 2, 3, 4, 5))
    initial_result =
      with_authenticated_client do
        OidcTokenExchangeCoordinator.call(
          grant_type: "authorization_code",
          code: issue_code!.code,
          redirect_uri: @redirect_uri,
          client_id: "core-next-rp",
          client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
          client_assertion: "test-client-assertion",
          token_endpoint_uri: "https://log.umaxica.app/oauth/token",
          code_verifier: @code_verifier,
          expected_resource_type: "client",
        )
      end
    @user_session_token.update!(discarded_at: Time.current)

    result =
      with_authenticated_client do
        OidcTokenExchangeCoordinator.call(
          grant_type: "refresh_token",
          refresh_token: initial_result.token_response.fetch(:refresh_token),
          client_id: "core-next-rp",
          client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
          client_assertion: "test-client-assertion",
          token_endpoint_uri: "https://log.umaxica.app/oauth/token",
          expected_resource_type: "client",
        )
      end

    assert_not result.success?
    assert_equal "invalid_grant", result.error
  end

  test "exchanged OIDC access id and refresh tokens end by the root session expiry" do
    travel_to(@user_session_token.created_at + 1.second) do
      absolute_expiry = 2.minutes.from_now
      @user_session_token.update!(discarded_at: absolute_expiry)
      code_record = issue_code!

      result =
        with_authenticated_client do
          OidcTokenExchangeCoordinator.call(
            grant_type: "authorization_code",
            code: code_record.code,
            redirect_uri: @redirect_uri,
            client_id: "core-next-rp",
            client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
            client_assertion: "test-client-assertion",
            token_endpoint_uri: "https://log.umaxica.app/oauth/token",
            code_verifier: @code_verifier,
            expected_resource_type: "client",
          )
        end

      assert_predicate result, :success?
      access_token = AuthenticationTokenService.decode(
        result.token_response.fetch(:access_token),
        host: OidcIssuer.host_for_client(@client),
        resource_type: "client",
        issuer: OidcIssuer.for_client(@client),
        audiences: [@client.aud],
        jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(@client),
      )
      id_token = JWT.decode(result.token_response.fetch(:id_token), nil, false).first
      usage = ClientRpSession.find_by!(client_token: @user_session_token, oidc_client_id: @client.client_id)

      assert_operator Time.zone.at(access_token.fetch("exp")), :<=, absolute_expiry
      assert_operator Time.zone.at(id_token.fetch("exp")), :<=, absolute_expiry
      assert_operator result.token_response.fetch(:expires_in), :<=, (absolute_expiry - Time.current).to_i
      assert_operator usage.refresh_token_expires_at, :<=, absolute_expiry
    end
  end

  test "exchanges valid code with private_key_jwt client assertion" do
    code_record = issue_code!
    token_url = "https://log.umaxica.app/oauth/token"

    with_oidc_client_key("CORE_APP") do
      assertion = OidcClientAssertionJwt.issue(client_id: "core-next-rp", token_url: token_url)

      result = OidcTokenExchangeCoordinator.call(
        grant_type: "authorization_code",
        code: code_record.code,
        redirect_uri: @redirect_uri,
        client_id: "core-next-rp",
        client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
        client_assertion: assertion,
        code_verifier: @code_verifier,
        token_endpoint_uri: token_url,
        expected_resource_type: "client",
      )

      assert_predicate result, :success?
      assert_predicate result.token_response[:id_token], :present?
    end
  end

  test "rejects private_key_jwt client assertion with wrong token endpoint audience" do
    code_record = issue_code!

    with_oidc_client_key("CORE_APP") do
      assertion = OidcClientAssertionJwt.issue(
        client_id: "core-next-rp",
        token_url: "https://log.umaxica.app/oauth/token",
      )

      result = OidcTokenExchangeCoordinator.call(
        grant_type: "authorization_code",
        code: code_record.code,
        redirect_uri: @redirect_uri,
        client_id: "core-next-rp",
        client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
        client_assertion: assertion,
        code_verifier: @code_verifier,
        token_endpoint_uri: "https://log.umaxica.app/oauth/token-alt",
        expected_resource_type: "client",
      )

      assert_not result.success?
      assert_equal "invalid_client", result.error
    end
  end

  test "rejects reused private_key_jwt client assertion before exchanging a second code" do
    first_code_record = issue_code!
    second_code_record = issue_code!
    token_url = "https://log.umaxica.app/oauth/token"

    with_oidc_client_key("CORE_APP") do
      assertion = OidcClientAssertionJwt.issue(client_id: "core-next-rp", token_url: token_url)

      first_result = OidcTokenExchangeCoordinator.call(
        grant_type: "authorization_code",
        code: first_code_record.code,
        redirect_uri: @redirect_uri,
        client_id: "core-next-rp",
        client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
        client_assertion: assertion,
        code_verifier: @code_verifier,
        token_endpoint_uri: token_url,
        expected_resource_type: "client",
      )
      second_result = OidcTokenExchangeCoordinator.call(
        grant_type: "authorization_code",
        code: second_code_record.code,
        redirect_uri: @redirect_uri,
        client_id: "core-next-rp",
        client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
        client_assertion: assertion,
        code_verifier: @code_verifier,
        token_endpoint_uri: token_url,
        expected_resource_type: "client",
      )

      assert_predicate first_result, :success?
      assert_not second_result.success?
      assert_equal "invalid_client", second_result.error
    end
  end

  test "rejects client assertion unless private_key_jwt is explicitly registered" do
    docs_client = OidcClientRegistry.find!("docs_app")
    code_record = issue_code!(client_id: "docs_app", redirect_uri: docs_client.redirect_uris.first)

    result = OidcTokenExchangeCoordinator.call(
      grant_type: "authorization_code",
      code: code_record.code,
      redirect_uri: docs_client.redirect_uris.first,
      client_id: "docs_app",
      client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
      client_assertion: "assertion",
      code_verifier: @code_verifier,
      token_endpoint_uri: "https://log.umaxica.app/oauth/token",
      expected_resource_type: "client",
    )

    assert_not result.success?
    assert_equal "invalid_client", result.error
  end

  test "rejects private_key_jwt client when client_secret is supplied instead of assertion" do
    code_record = issue_code!
    client = Struct.new(:registered_token_endpoint_auth_method).new("private_key_jwt")

    OidcClientRegistry.stub(:find, client) do
      result = OidcTokenExchangeCoordinator.call(
        grant_type: "authorization_code",
        code: code_record.code,
        redirect_uri: @redirect_uri,
        client_id: "core-next-rp",
        client_secret: @client_secret,
        code_verifier: @code_verifier,
        expected_resource_type: "client",
      )

      assert_not result.success?
      assert_equal "invalid_client", result.error
    end
  end

  test "rejects client_secret_post client when an assertion is supplied" do
    code_record = issue_code!
    client = Struct.new(:registered_token_endpoint_auth_method).new("client_secret_post")

    OidcClientRegistry.stub(:find, client) do
      result = OidcTokenExchangeCoordinator.call(
        grant_type: "authorization_code",
        code: code_record.code,
        redirect_uri: @redirect_uri,
        client_id: "core-next-rp",
        client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
        client_assertion: "assertion",
        code_verifier: @code_verifier,
        token_endpoint_uri: "https://log.umaxica.app/oauth/token",
        expected_resource_type: "client",
      )

      assert_not result.success?
      assert_equal "invalid_client", result.error
    end
  end

  test "marks code as consumed after exchange" do
    code_record = issue_code!

    with_authenticated_client do
      OidcTokenExchangeCoordinator.call(
        grant_type: "authorization_code",
        code: code_record.code,
        redirect_uri: @redirect_uri,
        client_id: "core-next-rp",
        client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
        client_assertion: "test-client-assertion",
        token_endpoint_uri: "https://log.umaxica.app/oauth/token",
        code_verifier: @code_verifier,
        expected_resource_type: "client",
      )
    end

    payload = authorization_code_store.read(code_record.code)

    assert_equal "consumed", payload.fetch("state")
  end

  test "fails for wrong grant_type" do
    code_record = issue_code!

    result =
      with_authenticated_client do
        OidcTokenExchangeCoordinator.call(
          grant_type: "implicit",
          code: code_record.code,
          redirect_uri: @redirect_uri,
          client_id: "core-next-rp",
          client_secret: @client_secret,
          code_verifier: @code_verifier,
          expected_resource_type: "client",
        )
      end

    assert_not result.success?
    assert_equal "invalid_request", result.error
  end

  test "fails for wrong client_secret_credential" do
    code_record = issue_code!

    result =
      with_oidc_client_secret_credentials(OIDC_CLIENT_SECRETS_CORE_APP: @client_secret) do
        OidcTokenExchangeCoordinator.call(
          grant_type: "authorization_code",
          code: code_record.code,
          redirect_uri: @redirect_uri,
          client_id: "core-next-rp",
          client_secret: "wrong_secret_credential",
          code_verifier: @code_verifier,
          expected_resource_type: "client",
        )
      end

    assert_not result.success?
    assert_equal "invalid_client", result.error
  end

  test "fails invalid_client for missing confidential client secret" do
    code_record = issue_code!

    result = OidcTokenExchangeCoordinator.call(
      grant_type: "authorization_code",
      code: code_record.code,
      redirect_uri: @redirect_uri,
      client_id: "core-next-rp",
      code_verifier: @code_verifier,
      expected_resource_type: "client",
    )

    assert_not result.success?
    assert_equal "invalid_client", result.error
  end

  test "fails invalid_client for blank configured confidential client secret" do
    code_record = issue_code!

    result =
      with_oidc_client_secret_credentials(OIDC_CLIENT_SECRETS_CORE_APP: "") do
        OidcTokenExchangeCoordinator.call(
          grant_type: "authorization_code",
          code: code_record.code,
          redirect_uri: @redirect_uri,
          client_id: "core-next-rp",
          client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
          client_assertion: "test-client-assertion",
          token_endpoint_uri: "https://log.umaxica.app/oauth/token",
          code_verifier: @code_verifier,
          expected_resource_type: "client",
        )
      end

    assert_not result.success?
    assert_equal "invalid_client", result.error
  end

  test "unregistered docs app does not enable public token exchange" do
    docs_client = OidcClientRegistry.find!("docs_app")
    code_record = issue_code!(client_id: "docs_app", redirect_uri: docs_client.redirect_uris.first)

    result = OidcTokenExchangeCoordinator.call(
      grant_type: "authorization_code",
      code: code_record.code,
      redirect_uri: docs_client.redirect_uris.first,
      client_id: "docs_app",
      code_verifier: @code_verifier,
      expected_resource_type: "client",
    )

    assert_not result.success?
    assert_equal "invalid_client", result.error
  end

  test "diagnostic metadata none does not enable public token exchange" do
    client = visitor_account(
      client_id: "metadata_none_test",
      client_secret: nil,
      registered_token_endpoint_auth_method: nil,
      metadata_token_endpoint_auth_method: "none",
    )
    code_record = issue_code!(client_id: "metadata_none_test", redirect_uri: client.redirect_uris.first)

    OidcClientRegistry.stub(:find, ->(client_id) { (client_id == "metadata_none_test") ? client : nil }) do
      result = OidcTokenExchangeCoordinator.call(
        grant_type: "authorization_code",
        code: code_record.code,
        redirect_uri: client.redirect_uris.first,
        client_id: "metadata_none_test",
        code_verifier: @code_verifier,
        expected_resource_type: "client",
      )

      assert_not result.success?
      assert_equal "invalid_client", result.error
    end
  end

  test "explicit registered none public client exchanges valid code with pkce" do
    public_client = visitor_account(
      client_id: "public_test",
      client_secret: nil,
      registered_token_endpoint_auth_method: "none",
      metadata_token_endpoint_auth_method: "none",
    )
    code_record = issue_code!(client_id: "public_test", redirect_uri: public_client.redirect_uris.first)

    with_public_client(public_client) do
      result = OidcTokenExchangeCoordinator.call(
        grant_type: "authorization_code",
        code: code_record.code,
        redirect_uri: public_client.redirect_uris.first,
        client_id: "public_test",
        code_verifier: @code_verifier,
        expected_resource_type: "client",
      )

      assert_predicate result, :success?
      assert_predicate result.token_response[:access_token], :present?
      assert_predicate result.token_response[:refresh_token], :present?
      assert_equal "Bearer", result.token_response[:token_type]
    end
  end

  test "explicit public client fails without client_id" do
    public_client = public_visitor_account
    code_record = issue_code!(client_id: public_client.client_id, redirect_uri: public_client.redirect_uris.first)

    with_public_client(public_client) do
      result = OidcTokenExchangeCoordinator.call(
        grant_type: "authorization_code",
        code: code_record.code,
        redirect_uri: public_client.redirect_uris.first,
        client_id: nil,
        code_verifier: @code_verifier,
        expected_resource_type: "client",
      )

      assert_not result.success?
      assert_equal "invalid_client", result.error
    end
  end

  test "explicit public client fails without code" do
    public_client = public_visitor_account

    with_public_client(public_client) do
      result = OidcTokenExchangeCoordinator.call(
        grant_type: "authorization_code",
        code: nil,
        redirect_uri: public_client.redirect_uris.first,
        client_id: public_client.client_id,
        code_verifier: @code_verifier,
        expected_resource_type: "client",
      )

      assert_not result.success?
      assert_equal "invalid_grant", result.error
    end
  end

  test "explicit public client fails without redirect_uri" do
    public_client = public_visitor_account
    code_record = issue_code!(client_id: public_client.client_id, redirect_uri: public_client.redirect_uris.first)

    with_public_client(public_client) do
      result = OidcTokenExchangeCoordinator.call(
        grant_type: "authorization_code",
        code: code_record.code,
        redirect_uri: nil,
        client_id: public_client.client_id,
        code_verifier: @code_verifier,
        expected_resource_type: "client",
      )

      assert_not result.success?
      assert_equal "invalid_request", result.error
      assert_equal "redirect_uri mismatch", result.error_description
    end
  end

  test "explicit public client fails without code_verifier" do
    public_client = public_visitor_account
    code_record = issue_code!(client_id: public_client.client_id, redirect_uri: public_client.redirect_uris.first)

    with_public_client(public_client) do
      result = OidcTokenExchangeCoordinator.call(
        grant_type: "authorization_code",
        code: code_record.code,
        redirect_uri: public_client.redirect_uris.first,
        client_id: public_client.client_id,
        code_verifier: nil,
        expected_resource_type: "client",
      )

      assert_not result.success?
      assert_equal "invalid_request", result.error
      assert_equal "code_verifier is required", result.error_description
    end
  end

  test "explicit public client fails with wrong code_verifier" do
    public_client = public_visitor_account
    code_record = issue_code!(client_id: public_client.client_id, redirect_uri: public_client.redirect_uris.first)

    with_public_client(public_client) do
      result = OidcTokenExchangeCoordinator.call(
        grant_type: "authorization_code",
        code: code_record.code,
        redirect_uri: public_client.redirect_uris.first,
        client_id: public_client.client_id,
        code_verifier: "wrong-verifier",
        expected_resource_type: "client",
      )

      assert_not result.success?
      assert_equal "invalid_request", result.error
      assert_equal "PKCE verification failed", result.error_description
    end
  end

  test "explicit public client rejects plain pkce code" do
    public_client = public_visitor_account
    code_record = plant_authorization_code!(
      client_id: public_client.client_id,
      redirect_uri: public_client.redirect_uris.first,
      code_challenge: @code_verifier,
      code_challenge_method: "plain",
    )

    with_public_client(public_client) do
      result = OidcTokenExchangeCoordinator.call(
        grant_type: "authorization_code",
        code: code_record.code,
        redirect_uri: public_client.redirect_uris.first,
        client_id: public_client.client_id,
        code_verifier: @code_verifier,
        expected_resource_type: "client",
      )

      assert_not result.success?
      assert_equal "invalid_request", result.error
      assert_equal "PKCE verification failed", result.error_description
    end
  end

  test "explicit public client fails with redirect_uri mismatch" do
    public_client = public_visitor_account
    code_record = issue_code!(client_id: public_client.client_id, redirect_uri: public_client.redirect_uris.first)

    with_public_client(public_client) do
      result = OidcTokenExchangeCoordinator.call(
        grant_type: "authorization_code",
        code: code_record.code,
        redirect_uri: "https://client.example/other/callback",
        client_id: public_client.client_id,
        code_verifier: @code_verifier,
        expected_resource_type: "client",
      )

      assert_not result.success?
      assert_equal "invalid_request", result.error
      assert_equal "redirect_uri mismatch", result.error_description
    end
  end

  test "token exchange rejects a core-next-rp code whose stored redirect_uri belongs to a different realm than " \
       "the code's resource_type" do
    org_redirect_uri = @client.redirect_uris_by_realm.fetch("operator").first
    code_record = issue_code!(client_id: "core-next-rp", redirect_uri: org_redirect_uri)

    with_authenticated_client do
      result = OidcTokenExchangeCoordinator.call(
        grant_type: "authorization_code",
        code: code_record.code,
        redirect_uri: org_redirect_uri,
        client_id: "core-next-rp",
        client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
        client_assertion: "test-client-assertion",
        token_endpoint_uri: "https://log.umaxica.app/oauth/token",
        code_verifier: @code_verifier,
        expected_resource_type: "client",
      )

      assert_not result.success?
      assert_equal "invalid_request", result.error
      assert_equal "redirect_uri is not registered for this authorization code's realm", result.error_description
    end
  end

  test "explicit public client fails with client_id mismatch" do
    public_client = public_visitor_account
    code_record = issue_code!(client_id: public_client.client_id, redirect_uri: public_client.redirect_uris.first)

    other_client = public_visitor_account(client_id: "other_public_test")
    with_public_clients(public_client, other_client) do
      result = OidcTokenExchangeCoordinator.call(
        grant_type: "authorization_code",
        code: code_record.code,
        redirect_uri: public_client.redirect_uris.first,
        client_id: other_client.client_id,
        code_verifier: @code_verifier,
        expected_resource_type: "client",
      )

      assert_not result.success?
      assert_equal "invalid_request", result.error
      assert_equal "client_id mismatch", result.error_description
    end
  end

  test "app-ios-rp cannot exchange an authorization code issued to app-android-rp" do
    code_record = issue_code!(client_id: "app-android-rp", redirect_uri: "com.umaxica.app:/oidc/callback")

    result = OidcTokenExchangeCoordinator.call(
      grant_type: "authorization_code",
      code: code_record.code,
      redirect_uri: "com.umaxica.app:/oidc/callback",
      client_id: "app-ios-rp",
      code_verifier: @code_verifier,
      expected_resource_type: "client",
    )

    assert_not result.success?
    assert_equal "invalid_request", result.error
    assert_equal "client_id mismatch", result.error_description
    assert_code_unconsumed(code_record)
  end

  test "token exchange rejects codes with disallowed scopes" do
    code_record = issue_code!(scope: "openid admin")

    result =
      with_authenticated_client do
        OidcTokenExchangeCoordinator.call(
          grant_type: "authorization_code",
          code: code_record.code,
          redirect_uri: @redirect_uri,
          client_id: "core-next-rp",
          client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
          client_assertion: "test-client-assertion",
          token_endpoint_uri: "https://log.umaxica.app/oauth/token",
          code_verifier: @code_verifier,
          expected_resource_type: "client",
        )
      end

    assert_not result.success?
    assert_equal "invalid_grant", result.error
    assert_equal "Authorization code scope is invalid", result.error_description
    assert_code_unconsumed(code_record)
  end

  test "explicit public client fails with expired code" do
    public_client = public_visitor_account
    code_record = issue_code!(client_id: public_client.client_id, redirect_uri: public_client.redirect_uris.first)

    travel Valkey::AuthState::AuthorizationCodeStore::CODE_TTL + 1.second do
      with_public_client(public_client) do
        result = OidcTokenExchangeCoordinator.call(
          grant_type: "authorization_code",
          code: code_record.code,
          redirect_uri: public_client.redirect_uris.first,
          client_id: public_client.client_id,
          code_verifier: @code_verifier,
          expected_resource_type: "client",
        )

        assert_not result.success?
        assert_equal "invalid_grant", result.error
        assert_equal "Authorization code expired", result.error_description
      end
    end
  end

  test "explicit public client fails with reused code" do
    public_client = public_visitor_account
    code_record = issue_code!(client_id: public_client.client_id, redirect_uri: public_client.redirect_uris.first)
    consume_issued_code!(code_record)

    with_public_client(public_client) do
      result = OidcTokenExchangeCoordinator.call(
        grant_type: "authorization_code",
        code: code_record.code,
        redirect_uri: public_client.redirect_uris.first,
        client_id: public_client.client_id,
        code_verifier: @code_verifier,
        expected_resource_type: "client",
      )

      assert_not result.success?
      assert_equal "invalid_grant", result.error
      assert_equal "Authorization code already consumed", result.error_description
    end
  end

  test "explicit public client rejects client_secret authentication" do
    public_client = public_visitor_account
    code_record = issue_code!(client_id: public_client.client_id, redirect_uri: public_client.redirect_uris.first)

    with_public_client(public_client) do
      result = OidcTokenExchangeCoordinator.call(
        grant_type: "authorization_code",
        code: code_record.code,
        redirect_uri: public_client.redirect_uris.first,
        client_id: public_client.client_id,
        client_secret: "unexpected-secret",
        code_verifier: @code_verifier,
        expected_resource_type: "client",
      )

      assert_not result.success?
      assert_equal "invalid_client", result.error
    end
  end

  test "explicit public client rejects client assertion authentication" do
    public_client = public_visitor_account
    code_record = issue_code!(client_id: public_client.client_id, redirect_uri: public_client.redirect_uris.first)

    with_public_client(public_client) do
      result = OidcTokenExchangeCoordinator.call(
        grant_type: "authorization_code",
        code: code_record.code,
        redirect_uri: public_client.redirect_uris.first,
        client_id: public_client.client_id,
        client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
        client_assertion: "assertion",
        code_verifier: @code_verifier,
        token_endpoint_uri: "https://log.umaxica.app/oauth/token",
        expected_resource_type: "client",
      )

      assert_not result.success?
      assert_equal "invalid_client", result.error
    end
  end

  test "confidential client cannot use public path by omitting secret" do
    code_record = issue_code!

    result = OidcTokenExchangeCoordinator.call(
      grant_type: "authorization_code",
      code: code_record.code,
      redirect_uri: @redirect_uri,
      client_id: "core-next-rp",
      code_verifier: @code_verifier,
      expected_resource_type: "client",
    )

    assert_not result.success?
    assert_equal "invalid_client", result.error
  end

  test "fails for nonexistent code" do
    result =
      with_authenticated_client do
        OidcTokenExchangeCoordinator.call(
          grant_type: "authorization_code",
          code: "nonexistent_code",
          redirect_uri: @redirect_uri,
          client_id: "core-next-rp",
          client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
          client_assertion: "test-client-assertion",
          token_endpoint_uri: "https://log.umaxica.app/oauth/token",
          code_verifier: @code_verifier,
          expected_resource_type: "client",
        )
      end

    assert_not result.success?
    assert_equal "invalid_grant", result.error
  end

  test "fails for expired code" do
    code_record = issue_code!

    travel Valkey::AuthState::AuthorizationCodeStore::CODE_TTL + 1.second do
      result =
        with_authenticated_client do
          OidcTokenExchangeCoordinator.call(
            grant_type: "authorization_code",
            code: code_record.code,
            redirect_uri: @redirect_uri,
            client_id: "core-next-rp",
            client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
            client_assertion: "test-client-assertion",
            token_endpoint_uri: "https://log.umaxica.app/oauth/token",
            code_verifier: @code_verifier,
            expected_resource_type: "client",
          )
        end

      assert_not result.success?
      assert_equal "invalid_grant", result.error
    end
  end

  test "fails for already consumed code" do
    code_record = issue_code!
    consume_issued_code!(code_record)

    result =
      with_authenticated_client do
        OidcTokenExchangeCoordinator.call(
          grant_type: "authorization_code",
          code: code_record.code,
          redirect_uri: @redirect_uri,
          client_id: "core-next-rp",
          client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
          client_assertion: "test-client-assertion",
          token_endpoint_uri: "https://log.umaxica.app/oauth/token",
          code_verifier: @code_verifier,
          expected_resource_type: "client",
        )
      end

    assert_not result.success?
    assert_equal "invalid_grant", result.error
  end

  test "fails closed when replay family revocation cannot be completed" do
    code_record = issue_code!
    store = authorization_code_store
    payload = store.read(code_record.code).merge(
      "state" => "consumed",
      "rp_session_ref" => "rp-session-for-replay",
    )
    store.instance_variable_get(:@connection).call(
      "SET",
      store.storage_key(code_record.code),
      JSON.generate(payload),
      "EX",
      60,
    )

    result =
      ClientRpSession.stub(:find_by, Object.new) do
        RpSessionRevoker.stub(:call, ->(**) { raise ActiveRecord::ConnectionNotEstablished }) do
          with_authenticated_client do
            OidcTokenExchangeCoordinator.call(
              grant_type: "authorization_code",
              code: code_record.code,
              redirect_uri: @redirect_uri,
              client_id: "core-next-rp",
              client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
              client_assertion: "test-client-assertion",
              token_endpoint_uri: "https://log.umaxica.app/oauth/token",
              code_verifier: @code_verifier,
              expected_resource_type: "client",
            )
          end
        end
      end

    assert_not result.success?
    assert_equal "server_error", result.error
    assert_equal "authorization code replay revocation failed", result.error_description
    assert_nil result.token_response
    assert_equal "consumed", store.read(code_record.code).fetch("state")
  end

  test "preserves same-owner replay cleanup for a consumed code without auth_time" do
    code_record = issue_code!
    store = authorization_code_store
    payload = store.read(code_record.code).except("auth_time").merge(
      "state" => "consumed",
      "rp_session_ref" => "rp-session-for-replay",
    )
    store.instance_variable_get(:@connection).call(
      "SET",
      store.storage_key(code_record.code),
      JSON.generate(payload),
      "EX",
      60,
    )

    result =
      ClientRpSession.stub(:find_by, Object.new) do
        RpSessionRevoker.stub(:call, ->(**) { }) do
          with_authenticated_client do
            OidcTokenExchangeCoordinator.call(
              grant_type: "authorization_code",
              code: code_record.code,
              redirect_uri: @redirect_uri,
              client_id: "core-next-rp",
              client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
              client_assertion: "test-client-assertion",
              token_endpoint_uri: "https://log.umaxica.app/oauth/token",
              code_verifier: @code_verifier,
              expected_resource_type: "client",
            )
          end
        end
      end

    assert_not result.success?
    assert_equal "invalid_grant", result.error
    assert_equal "Authorization code already consumed", result.error_description
  end

  test "replay cleanup revokes the linked RP session once" do
    code_record = issue_code!
    store = authorization_code_store
    payload = store.read(code_record.code).merge(
      "state" => "consumed",
      "rp_session_ref" => "rp-session-for-replay",
    )
    store.instance_variable_get(:@connection).call(
      "SET",
      store.storage_key(code_record.code),
      JSON.generate(payload),
      "EX",
      60,
    )
    revoke_calls = 0

    result =
      ClientRpSession.stub(:find_by, Object.new) do
        RpSessionRevoker.stub(:call, ->(**) { revoke_calls += 1 }) do
          with_authenticated_client do
            OidcTokenExchangeCoordinator.call(
              grant_type: "authorization_code",
              code: code_record.code,
              redirect_uri: @redirect_uri,
              client_id: "core-next-rp",
              client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
              client_assertion: "test-client-assertion",
              token_endpoint_uri: "https://log.umaxica.app/oauth/token",
              code_verifier: @code_verifier,
              expected_resource_type: "client",
            )
          end
        end
      end

    assert_not result.success?
    assert_equal "invalid_grant", result.error
    assert_equal 1, revoke_calls
  end

  test "fails closed when consumed code family linkage does not succeed" do
    code_record = issue_code!
    delegate = authorization_code_store
    missing_link = Struct.new(:status).new(:missing)
    code_store = Object.new
    code_store.define_singleton_method(:read) { |raw_code| delegate.read(raw_code) }
    code_store.define_singleton_method(:consume!) do |**arguments|
      delegate.consume!(**arguments)
    end
    code_store.define_singleton_method(:link_family!) { |**| missing_link }

    result =
      with_authenticated_client do
        OidcTokenExchangeCoordinator.call(
          grant_type: "authorization_code",
          code: code_record.code,
          redirect_uri: @redirect_uri,
          client_id: "core-next-rp",
          client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
          client_assertion: "test-client-assertion",
          token_endpoint_uri: "https://log.umaxica.app/oauth/token",
          code_verifier: @code_verifier,
          code_store: code_store,
          expected_resource_type: "client",
        )
      end

    assert_not result.success?
    assert_equal "server_error", result.error
    assert_nil result.token_response
    assert_equal "consumed", delegate.read(code_record.code).fetch("state")
  end

  test "fails closed when consumed code family linkage returns invalid_state" do
    code_record = issue_code!
    delegate = authorization_code_store
    invalid_link = Struct.new(:status).new(:invalid_state)
    code_store = Object.new
    code_store.define_singleton_method(:read) { |raw_code| delegate.read(raw_code) }
    code_store.define_singleton_method(:consume!) do |**arguments|
      delegate.consume!(**arguments)
    end
    code_store.define_singleton_method(:link_family!) { |**| invalid_link }
    rp_session_count = ClientRpSession.count

    result =
      with_authenticated_client do
        OidcTokenExchangeCoordinator.call(
          grant_type: "authorization_code",
          code: code_record.code,
          redirect_uri: @redirect_uri,
          client_id: "core-next-rp",
          client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
          client_assertion: "test-client-assertion",
          token_endpoint_uri: "https://log.umaxica.app/oauth/token",
          code_verifier: @code_verifier,
          code_store: code_store,
          expected_resource_type: "client",
        )
      end

    assert_not result.success?
    assert_equal "server_error", result.error
    assert_nil result.token_response
    assert_equal rp_session_count, ClientRpSession.count
    assert_equal "consumed", delegate.read(code_record.code).fetch("state")
  end

  test "fails closed when family linkage raises a Valkey unavailable error" do
    code_record = issue_code!
    delegate = authorization_code_store
    code_store = Object.new
    code_store.define_singleton_method(:read) { |raw_code| delegate.read(raw_code) }
    code_store.define_singleton_method(:consume!) do |**arguments|
      delegate.consume!(**arguments)
    end
    code_store.define_singleton_method(:link_family!) do |**|
      raise Umaxica::Valkey::Unavailable, "authorization code family link unavailable"
    end
    rp_session_count = ClientRpSession.count

    result =
      with_authenticated_client do
        OidcTokenExchangeCoordinator.call(
          grant_type: "authorization_code",
          code: code_record.code,
          redirect_uri: @redirect_uri,
          client_id: "core-next-rp",
          client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
          client_assertion: "test-client-assertion",
          token_endpoint_uri: "https://log.umaxica.app/oauth/token",
          code_verifier: @code_verifier,
          code_store: code_store,
          expected_resource_type: "client",
        )
      end

    assert_not result.success?
    assert_equal "server_error", result.error
    assert_nil result.token_response
    assert_equal rp_session_count, ClientRpSession.count
    assert_equal "consumed", delegate.read(code_record.code).fetch("state")
  end

  test "a different same-realm client cannot revoke the code owner's RP session on replay" do
    code_record = issue_code!
    owner_result =
      with_authenticated_client do
        OidcTokenExchangeCoordinator.call(
          grant_type: "authorization_code",
          code: code_record.code,
          redirect_uri: @redirect_uri,
          client_id: "core-next-rp",
          client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
          client_assertion: "test-client-assertion",
          token_endpoint_uri: "https://log.umaxica.app/oauth/token",
          code_verifier: @code_verifier,
          expected_resource_type: "client",
        )
      end

    assert_predicate owner_result, :success?

    owner_session = ClientRpSession.order(:created_at).last
    owner_session_id = owner_session.id
    owner_public_id = owner_session.public_id
    owner_refresh_digest = owner_session.refresh_token_digest
    @user_session_token.reload
    root_family_id = @user_session_token.refresh_token_family_id
    root_discarded_at = @user_session_token.discarded_at
    side_client = OidcClientRegistry.find("side-app")
    side_redirect_uri = side_client.redirect_uris.first

    replay_result =
      OidcClientRegistry.stub(
        :authenticate_assertion,
        ->(cid, assertion, token_url:) { cid == "side-app" && assertion.present? && token_url.present? },
      ) do
        OidcTokenExchangeCoordinator.call(
          grant_type: "authorization_code",
          code: code_record.code,
          redirect_uri: side_redirect_uri,
          client_id: "side-app",
          client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
          client_assertion: "side-app-client-assertion",
          token_endpoint_uri: "https://wide.app.localhost/oauth/token",
          code_verifier: @code_verifier,
          expected_resource_type: "client",
        )
      end

    assert_not replay_result.success?
    assert_includes %w(invalid_grant invalid_request), replay_result.error
    assert_nil replay_result.token_response

    owner_session.reload
    @user_session_token.reload

    assert_equal owner_session_id, owner_session.id
    assert_equal owner_public_id, owner_session.public_id
    assert_equal owner_refresh_digest, owner_session.refresh_token_digest
    assert_nil owner_session.revoked_at
    assert_equal root_family_id, @user_session_token.refresh_token_family_id
    assert_equal root_discarded_at, @user_session_token.discarded_at
    assert_predicate @user_session_token, :currently_usable?
    assert_equal "consumed", authorization_code_store.read(code_record.code).fetch("state")
  end

  test "fails closed when family linkage returns an unknown completion status" do
    code_record = issue_code!
    delegate = authorization_code_store
    unknown_link = Struct.new(:status).new(:timeout)
    code_store = Object.new
    code_store.define_singleton_method(:read) { |raw_code| delegate.read(raw_code) }
    code_store.define_singleton_method(:consume!) do |**arguments|
      delegate.consume!(**arguments)
    end
    code_store.define_singleton_method(:link_family!) { |**| unknown_link }
    rp_session_count = ClientRpSession.count

    result =
      with_authenticated_client do
        OidcTokenExchangeCoordinator.call(
          grant_type: "authorization_code",
          code: code_record.code,
          redirect_uri: @redirect_uri,
          client_id: "core-next-rp",
          client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
          client_assertion: "test-client-assertion",
          token_endpoint_uri: "https://log.umaxica.app/oauth/token",
          code_verifier: @code_verifier,
          code_store: code_store,
          expected_resource_type: "client",
        )
      end

    assert_not result.success?
    assert_equal "server_error", result.error
    assert_nil result.token_response
    assert_equal rp_session_count, ClientRpSession.count
    assert_equal "consumed", delegate.read(code_record.code).fetch("state")
  end

  test "concurrent exchanges of one code produce a single token response" do
    code_record = issue_code!
    results = Array.new(2)

    with_authenticated_client do
      threads =
        2.times.map do |index|
          Thread.new do # rubocop:disable ThreadSafety/NewThread
            results[index] =
              OidcTokenExchangeCoordinator.call(
                grant_type: "authorization_code",
                code: code_record.code,
                redirect_uri: @redirect_uri,
                client_id: "core-next-rp",
                client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
                client_assertion: "test-client-assertion-#{index}",
                token_endpoint_uri: "https://log.umaxica.app/oauth/token",
                code_verifier: @code_verifier,
                expected_resource_type: "client",
              )
          end
        end
      threads.each(&:join)
    end

    successes = results.select(&:success?)
    denials = results.reject(&:success?)

    assert_equal 1, successes.size
    assert_equal 1, denials.size
    assert_equal "invalid_grant", denials.first.error
    assert_equal "consumed", authorization_code_store.read(code_record.code).fetch("state")
    assert_equal 1, ClientRpSession.where(oidc_client_id: "core-next-rp", client_token_id: @user_session_token.id).count
  end

  test "same-owner replay after a lost HTTP response does not unconsume the code or mint a second family" do
    code_record = issue_code!
    first =
      with_authenticated_client do
        OidcTokenExchangeCoordinator.call(
          grant_type: "authorization_code",
          code: code_record.code,
          redirect_uri: @redirect_uri,
          client_id: "core-next-rp",
          client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
          client_assertion: "test-client-assertion",
          token_endpoint_uri: "https://log.umaxica.app/oauth/token",
          code_verifier: @code_verifier,
          expected_resource_type: "client",
        )
      end

    assert_predicate first, :success?
    usage = ClientRpSession.order(:created_at).last
    digest = usage.refresh_token_digest

    lost_response_retry =
      with_authenticated_client do
        OidcTokenExchangeCoordinator.call(
          grant_type: "authorization_code",
          code: code_record.code,
          redirect_uri: @redirect_uri,
          client_id: "core-next-rp",
          client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
          client_assertion: "test-client-assertion",
          token_endpoint_uri: "https://log.umaxica.app/oauth/token",
          code_verifier: @code_verifier,
          expected_resource_type: "client",
        )
      end

    assert_not lost_response_retry.success?
    assert_equal "invalid_grant", lost_response_retry.error
    assert_nil lost_response_retry.token_response
    assert_equal "consumed", authorization_code_store.read(code_record.code).fetch("state")
    usage.reload

    assert_equal digest, usage.refresh_token_digest
    assert_equal 1, ClientRpSession.where(client_token_id: @user_session_token.id, oidc_client_id: "core-next-rp").count
  end

  test "a new authorization code cannot replace an unretired RP session" do
    first_code = issue_code!
    first_result =
      with_authenticated_client do
        OidcTokenExchangeCoordinator.call(
          grant_type: "authorization_code",
          code: first_code.code,
          redirect_uri: @redirect_uri,
          client_id: "core-next-rp",
          client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
          client_assertion: "test-client-assertion",
          token_endpoint_uri: "https://log.umaxica.app/oauth/token",
          code_verifier: @code_verifier,
          expected_resource_type: "client",
        )
      end

    assert_predicate first_result, :success?
    usage = ClientRpSession.find_by!(client_token: @user_session_token, oidc_client_id: "core-next-rp")
    original_jti = usage.oidc_jti
    original_scope = usage.oidc_scope
    second_code = issue_code!(scope: "openid email")

    second_result =
      with_authenticated_client do
        OidcTokenExchangeCoordinator.call(
          grant_type: "authorization_code",
          code: second_code.code,
          redirect_uri: @redirect_uri,
          client_id: "core-next-rp",
          client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
          client_assertion: "test-client-assertion",
          token_endpoint_uri: "https://log.umaxica.app/oauth/token",
          code_verifier: @code_verifier,
          expected_resource_type: "client",
        )
      end

    assert_not second_result.success?
    assert_equal "invalid_grant", second_result.error
    assert_equal "consumed", authorization_code_store.read(second_code.code).fetch("state")
    assert_equal original_jti, usage.reload.oidc_jti
    assert_equal original_scope, usage.oidc_scope
  end

  test "fails closed and rolls back the rp session when token issuance fails after consume" do
    code_record = issue_code!
    rp_session_count = ClientRpSession.count

    result =
      AuthenticationTokenService.stub(:encode, nil) do
        with_authenticated_client do
          OidcTokenExchangeCoordinator.call(
            grant_type: "authorization_code",
            code: code_record.code,
            redirect_uri: @redirect_uri,
            client_id: "core-next-rp",
            client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
            client_assertion: "test-client-assertion",
            token_endpoint_uri: "https://log.umaxica.app/oauth/token",
            code_verifier: @code_verifier,
            expected_resource_type: "client",
          )
        end
      end

    assert_not result.success?
    assert_equal "server_error", result.error
    assert_equal "token issuance failed", result.error_description
    assert_nil result.token_response
    assert_equal rp_session_count, ClientRpSession.count
    assert_equal "consumed", authorization_code_store.read(code_record.code).fetch("state")
  end

  test "fails for wrong redirect_uri" do
    code_record = issue_code!

    result =
      with_authenticated_client do
        OidcTokenExchangeCoordinator.call(
          grant_type: "authorization_code",
          code: code_record.code,
          redirect_uri: "http://wrong.host/callback",
          client_id: "core-next-rp",
          client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
          client_assertion: "test-client-assertion",
          token_endpoint_uri: "https://log.umaxica.app/oauth/token",
          code_verifier: @code_verifier,
          expected_resource_type: "client",
        )
      end

    assert_not result.success?
  end

  test "fails for wrong code_verifier (PKCE)" do
    code_record = issue_code!

    result =
      with_authenticated_client do
        OidcTokenExchangeCoordinator.call(
          grant_type: "authorization_code",
          code: code_record.code,
          redirect_uri: @redirect_uri,
          client_id: "core-next-rp",
          client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
          client_assertion: "test-client-assertion",
          token_endpoint_uri: "https://log.umaxica.app/oauth/token",
          code_verifier: "wrong_verifier_value",
          expected_resource_type: "client",
        )
      end

    assert_not result.success?
    assert_equal "invalid_request", result.error
    assert_code_unconsumed(code_record)
  end

  test "fails for blank code_verifier" do
    code_record = issue_code!

    result =
      with_authenticated_client do
        OidcTokenExchangeCoordinator.call(
          grant_type: "authorization_code",
          code: code_record.code,
          redirect_uri: @redirect_uri,
          client_id: "core-next-rp",
          client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
          client_assertion: "test-client-assertion",
          token_endpoint_uri: "https://log.umaxica.app/oauth/token",
          code_verifier: "",
          expected_resource_type: "client",
        )
      end

    assert_not result.success?
    assert_equal "invalid_request", result.error
  end

  test "creates user token record" do
    code_record = issue_code!

    assert_no_difference "ClientToken.count" do
      assert_difference "ClientRpSession.count", 1 do
        with_authenticated_client do
          OidcTokenExchangeCoordinator.call(
            grant_type: "authorization_code",
            code: code_record.code,
            redirect_uri: @redirect_uri,
            client_id: "core-next-rp",
            client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
            client_assertion: "test-client-assertion",
            token_endpoint_uri: "https://log.umaxica.app/oauth/token",
            code_verifier: @code_verifier,
            expected_resource_type: "client",
          )
        end
      end
    end
  end

  test "records user RP connection and stamps issued token" do
    code_record = issue_code!(scope: "openid profile email")

    with_authenticated_client do
      OidcTokenExchangeCoordinator.call(
        grant_type: "authorization_code",
        code: code_record.code,
        redirect_uri: @redirect_uri,
        client_id: "core-next-rp",
        client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
        client_assertion: "test-client-assertion",
        token_endpoint_uri: "https://log.umaxica.app/oauth/token",
        code_verifier: @code_verifier,
        expected_resource_type: "client",
      )
    end

    connection = ClientOidcConnection.find_by!(user_id: @user.id, client_id: "core-next-rp")
    usage = ClientRpSession.order(:created_at).last

    assert_equal "openid profile email", connection.scope
    assert_nil connection.revoked_at
    assert_equal @user_session_token.id, usage.client_token_id
    assert_equal "core-next-rp", usage.oidc_client_id
    assert_equal "openid profile email", usage.oidc_scope
    assert_predicate usage.oidc_jti, :present?
  end

  test "reactivates existing user RP connection on token exchange" do
    connection = ClientOidcConnection.create!(
      user: @user,
      client_id: "core-next-rp",
      scope: "openid",
      last_used_at: 1.day.ago,
      revoked_at: 1.hour.ago,
    )
    code_record = issue_code!(scope: "openid email")

    with_authenticated_client do
      OidcTokenExchangeCoordinator.call(
        grant_type: "authorization_code",
        code: code_record.code,
        redirect_uri: @redirect_uri,
        client_id: "core-next-rp",
        client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
        client_assertion: "test-client-assertion",
        token_endpoint_uri: "https://log.umaxica.app/oauth/token",
        code_verifier: @code_verifier,
        expected_resource_type: "client",
      )
    end

    connection.reload

    assert_equal "openid email", connection.scope
    assert_nil connection.revoked_at
    assert_operator connection.last_used_at, :>, 1.minute.ago
  end

  test "does not reactivate a connection for an authorization code issued before revocation" do
    now = Time.current
    connection = ClientOidcConnection.create!(
      user: @user,
      client_id: "core-next-rp",
      scope: "openid",
      last_used_at: 1.hour.ago,
      revoked_at: now,
    )
    code_record = plant_authorization_code!(
      client_id: "core-next-rp",
      redirect_uri: @redirect_uri,
      code_challenge: @code_challenge,
      code_challenge_method: "S256",
      issued_at: now - 1.second,
    )

    assert_no_difference "ClientRpSession.count" do
      result =
        with_authenticated_client do
          OidcTokenExchangeCoordinator.call(
            grant_type: "authorization_code",
            code: code_record.code,
            redirect_uri: @redirect_uri,
            client_id: "core-next-rp",
            client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
            client_assertion: "test-client-assertion",
            token_endpoint_uri: "https://log.umaxica.app/oauth/token",
            code_verifier: @code_verifier,
            expected_resource_type: "client",
          )
        end

      assert_not result.success?
      assert_equal "invalid_grant", result.error
    end

    assert_equal now.to_i, connection.reload.revoked_at.to_i
    assert_code_unconsumed(code_record)
  end

  test "refresh rotation preserves RP token linkage" do
    code_record = issue_code!(scope: "openid profile")

    result =
      with_authenticated_client do
        OidcTokenExchangeCoordinator.call(
          grant_type: "authorization_code",
          code: code_record.code,
          redirect_uri: @redirect_uri,
          client_id: "core-next-rp",
          client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
          client_assertion: "test-client-assertion",
          token_endpoint_uri: "https://log.umaxica.app/oauth/token",
          code_verifier: @code_verifier,
          expected_resource_type: "client",
        )
      end

    connection = ClientOidcConnection.find_by!(user_id: @user.id, client_id: "core-next-rp")
    previous_last_used_at = connection.last_used_at
    rotated = nil
    travel 1.minute do
      rotated = OidcRefreshTokenIssuer.call(
        refresh_token: result.token_response[:refresh_token],
        resource_type: "client",
      )
    end
    replacement = rotated[:token]

    assert_equal @user_session_token.id, replacement.client_token_id
    assert_equal "core-next-rp", replacement.oidc_client_id
    assert_equal "openid profile", replacement.oidc_scope
    assert_operator connection.reload.last_used_at, :>, previous_last_used_at
  end

  # --- Operator OIDC token exchange tests ---

  test "exchanges valid operator code for tokens with OperatorToken" do
    staff = operators(:one)
    staff_session_token = OperatorToken.create!(staff: staff)
    org_client = OidcClientRegistry.find!("core-org")
    org_redirect_uri = org_client.redirect_uris_by_realm.fetch("operator").first
    staff_secret_credential = "test_secret_credential_for_core_org"

    code_record = issue_code!(
      client_id: "core-org",
      redirect_uri: org_redirect_uri,
      resource: staff,
      session_token: staff_session_token,
    )

    result =
      with_authenticated_org_client(staff_secret_credential, client_id: "core-org") do
        OidcTokenExchangeCoordinator.call(
          grant_type: "authorization_code",
          code: code_record.code,
          redirect_uri: org_redirect_uri,
          client_id: "core-org",
          client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
          client_assertion: "test-staff-client-assertion",
          token_endpoint_uri: "https://log.umaxica.org/oauth/token",
          code_verifier: @code_verifier,
          expected_resource_type: "operator",
        )
      end

    assert_predicate result, :success?
    assert_predicate result.token_response[:access_token], :present?
    assert_predicate result.token_response[:refresh_token], :present?
    assert_equal "Bearer", result.token_response[:token_type]
  end

  test "refreshes an operator RP session without changing auth_time" do
    staff = operators(:one)
    staff_session_token = OperatorToken.create!(staff: staff, authentication_event_at: Time.utc(2026, 1, 2, 3, 4, 5))
    org_client = OidcClientRegistry.find!("core-org")
    org_redirect_uri = org_client.redirect_uris_by_realm.fetch("operator").first
    code_record = issue_code!(
      client_id: "core-org",
      redirect_uri: org_redirect_uri,
      resource: staff,
      session_token: staff_session_token,
    )

    initial_result =
      OidcClientRegistry.stub(
        :authenticate_assertion,
        ->(client_id, assertion, token_url:) { client_id == "core-org" && assertion.present? && token_url.present? },
      ) do
        OidcTokenExchangeCoordinator.call(
          grant_type: "authorization_code",
          code: code_record.code,
          redirect_uri: org_redirect_uri,
          client_id: "core-org",
          client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
          client_assertion: "test-staff-client-assertion",
          token_endpoint_uri: "https://log.umaxica.org/oauth/token",
          code_verifier: @code_verifier,
          expected_resource_type: "operator",
        )
      end

    refreshed_result =
      OidcClientRegistry.stub(
        :authenticate_assertion,
        ->(client_id, assertion, token_url:) { client_id == "core-org" && assertion.present? && token_url.present? },
      ) do
        OidcTokenExchangeCoordinator.call(
          grant_type: "refresh_token",
          refresh_token: initial_result.token_response.fetch(:refresh_token),
          client_id: "core-org",
          client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
          client_assertion: "test-staff-refresh-assertion",
          token_endpoint_uri: "https://log.umaxica.org/oauth/token",
          expected_resource_type: "operator",
        )
      end

    assert_predicate refreshed_result, :success?
    payload = JWT.decode(refreshed_result.token_response.fetch(:id_token), nil, false).first

    assert_equal staff_session_token.authentication_event_at.to_i, payload.fetch("auth_time")
  end

  test "creates staff token record for org client" do
    staff = operators(:one)
    staff_session_token = OperatorToken.create!(staff: staff)
    org_client = OidcClientRegistry.find("core-next-rp")
    org_redirect_uri = org_client.redirect_uris_by_realm.fetch("operator").first
    staff_secret_credential = "test_secret_credential_for_core_org"

    code_record = issue_code!(
      client_id: "core-next-rp",
      redirect_uri: org_redirect_uri,
      resource: staff,
      session_token: staff_session_token,
    )

    assert_no_difference "OperatorToken.count" do
      assert_difference "OperatorRpSession.count", 1 do
        with_authenticated_org_client(staff_secret_credential) do
          OidcTokenExchangeCoordinator.call(
            grant_type: "authorization_code",
            code: code_record.code,
            redirect_uri: org_redirect_uri,
            client_id: "core-next-rp",
            client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
            client_assertion: "test-staff-client-assertion",
            token_endpoint_uri: "https://log.umaxica.org/oauth/token",
            code_verifier: @code_verifier,
            expected_resource_type: "operator",
          )
        end
      end
    end
  end

  test "records staff RP connection" do
    staff = operators(:one)
    staff_session_token = OperatorToken.create!(staff: staff)
    org_client = OidcClientRegistry.find("core-next-rp")
    staff_secret_credential = "test_secret_credential_for_core_org"
    code_record = issue_code!(
      client_id: "core-next-rp",
      redirect_uri: org_client.redirect_uris_by_realm.fetch("operator").first,
      resource: staff,
      session_token: staff_session_token,
    )

    with_authenticated_org_client(staff_secret_credential) do
      OidcTokenExchangeCoordinator.call(
        grant_type: "authorization_code",
        code: code_record.code,
        redirect_uri: org_client.redirect_uris_by_realm.fetch("operator").first,
        client_id: "core-next-rp",
        client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
        client_assertion: "test-staff-client-assertion",
        token_endpoint_uri: "https://log.umaxica.org/oauth/token",
        code_verifier: @code_verifier,
        expected_resource_type: "operator",
      )
    end

    connection = OperatorOidcConnection.find_by!(staff_id: staff.id, client_id: "core-next-rp")
    usage = OperatorRpSession.order(:created_at).last

    assert_equal "openid profile email", connection.scope
    assert_equal staff_session_token.id, usage.operator_token_id
    assert_equal "core-next-rp", usage.oidc_client_id
    assert_equal "openid profile email", usage.oidc_scope
  end

  test "exchanges valid visitor code for tokens with VisitorToken" do
    visitor = create_visitor!
    visitor_session_token = VisitorToken.create!(visitor: visitor, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB)
    com_client = OidcClientRegistry.find!("core-com")
    com_redirect_uri = com_client.redirect_uris_by_realm.fetch("visitor").first
    visitor_secret_credential = "test_secret_credential_for_core_com"

    code_record = issue_code!(
      client_id: "core-com",
      redirect_uri: com_redirect_uri,
      resource: visitor,
      session_token: visitor_session_token,
    )

    result =
      with_authenticated_com_client(visitor_secret_credential, client_id: "core-com") do
        OidcTokenExchangeCoordinator.call(
          grant_type: "authorization_code",
          code: code_record.code,
          redirect_uri: com_redirect_uri,
          client_id: "core-com",
          client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
          client_assertion: "test-visitor-client-assertion",
          token_endpoint_uri: "https://log.umaxica.com/oauth/token",
          code_verifier: @code_verifier,
          expected_resource_type: "visitor",
        )
      end

    assert_predicate result, :success?
    assert_predicate result.token_response[:access_token], :present?
    assert_predicate result.token_response[:refresh_token], :present?
    assert_equal "Bearer", result.token_response[:token_type]
  end

  test "refreshes a visitor RP session without changing auth_time" do
    visitor = visitors(:reserved_visitor)
    visitor_session_token = VisitorToken.create!(
      visitor: visitor,
      authentication_event_at: Time.utc(
        2026, 1, 2, 3, 4, 5,
      ),
    )
    com_client = OidcClientRegistry.find!("core-com")
    com_redirect_uri = com_client.redirect_uris_by_realm.fetch("visitor").first
    code_record = issue_code!(
      client_id: "core-com",
      redirect_uri: com_redirect_uri,
      resource: visitor,
      session_token: visitor_session_token,
    )

    initial_result =
      OidcClientRegistry.stub(
        :authenticate_assertion,
        ->(client_id, assertion, token_url:) { client_id == "core-com" && assertion.present? && token_url.present? },
      ) do
        OidcTokenExchangeCoordinator.call(
          grant_type: "authorization_code",
          code: code_record.code,
          redirect_uri: com_redirect_uri,
          client_id: "core-com",
          client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
          client_assertion: "test-visitor-client-assertion",
          token_endpoint_uri: "https://log.umaxica.com/oauth/token",
          code_verifier: @code_verifier,
          expected_resource_type: "visitor",
        )
      end

    refreshed_result =
      OidcClientRegistry.stub(
        :authenticate_assertion,
        ->(client_id, assertion, token_url:) { client_id == "core-com" && assertion.present? && token_url.present? },
      ) do
        OidcTokenExchangeCoordinator.call(
          grant_type: "refresh_token",
          refresh_token: initial_result.token_response.fetch(:refresh_token),
          client_id: "core-com",
          client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
          client_assertion: "test-visitor-refresh-assertion",
          token_endpoint_uri: "https://log.umaxica.com/oauth/token",
          expected_resource_type: "visitor",
        )
      end

    assert_predicate refreshed_result, :success?
    payload = JWT.decode(refreshed_result.token_response.fetch(:id_token), nil, false).first

    assert_equal visitor_session_token.authentication_event_at.to_i, payload.fetch("auth_time")
  end

  test "creates visitor token record for com client" do
    visitor = create_visitor!
    visitor_session_token = VisitorToken.create!(visitor: visitor, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB)
    com_client = OidcClientRegistry.find("core-next-rp")
    com_redirect_uri = com_client.redirect_uris_by_realm.fetch("visitor").first
    visitor_secret_credential = "test_secret_credential_for_core_com"

    code_record = issue_code!(
      client_id: "core-next-rp",
      redirect_uri: com_redirect_uri,
      resource: visitor,
      session_token: visitor_session_token,
    )

    assert_no_difference "VisitorToken.count" do
      assert_difference "VisitorRpSession.count", 1 do
        with_authenticated_com_client(visitor_secret_credential) do
          OidcTokenExchangeCoordinator.call(
            grant_type: "authorization_code",
            code: code_record.code,
            redirect_uri: com_redirect_uri,
            client_id: "core-next-rp",
            client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
            client_assertion: "test-visitor-client-assertion",
            token_endpoint_uri: "https://log.umaxica.com/oauth/token",
            code_verifier: @code_verifier,
            expected_resource_type: "visitor",
          )
        end
      end
    end
  end

  test "records visitor RP connection" do
    visitor = create_visitor!
    visitor_session_token = VisitorToken.create!(visitor: visitor, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB)
    com_client = OidcClientRegistry.find("core-next-rp")
    visitor_secret_credential = "test_secret_credential_for_core_com"
    code_record = issue_code!(
      client_id: "core-next-rp",
      redirect_uri: com_client.redirect_uris_by_realm.fetch("visitor").first,
      resource: visitor,
      session_token: visitor_session_token,
    )

    with_authenticated_com_client(visitor_secret_credential) do
      OidcTokenExchangeCoordinator.call(
        grant_type: "authorization_code",
        code: code_record.code,
        redirect_uri: com_client.redirect_uris_by_realm.fetch("visitor").first,
        client_id: "core-next-rp",
        client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
        client_assertion: "test-visitor-client-assertion",
        token_endpoint_uri: "https://log.umaxica.com/oauth/token",
        code_verifier: @code_verifier,
        expected_resource_type: "visitor",
      )
    end

    connection = VisitorOidcConnection.find_by!(visitor_id: visitor.id, client_id: "core-next-rp")
    usage = VisitorRpSession.order(:created_at).last

    assert_equal "openid profile email", connection.scope
    assert_equal visitor_session_token.id, usage.visitor_token_id
    assert_equal "core-next-rp", usage.oidc_client_id
    assert_equal "openid profile email", usage.oidc_scope
  end

  # --- DPoP token exchange tests ---

  test "issues DPoP-bound token when valid DPoP proof is provided" do
    code_record = issue_code!
    private_key, jwk = generate_dpop_jwk
    token_endpoint = "http://id.app.localhost/tokens"
    proof = build_dpop_proof(private_key, jwk, method: "POST", uri: token_endpoint)

    result =
      with_authenticated_client do
        OidcTokenExchangeCoordinator.call(
          grant_type: "authorization_code",
          code: code_record.code,
          redirect_uri: @redirect_uri,
          client_id: "core-next-rp",
          client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
          client_assertion: "test-client-assertion",
          code_verifier: @code_verifier,
          dpop_proof: proof,
          token_endpoint_uri: token_endpoint,
          request_method: "POST",
          expected_resource_type: "client",
        )
      end

    assert_predicate result, :success?
    assert_equal "DPoP", result.token_response[:token_type]
    assert_predicate result.token_response[:access_token], :present?

    ClientToken.last

    assert_predicate ClientRpSession.last.dpop_jkt, :present?
  end

  test "issues Bearer token when no DPoP proof is provided" do
    code_record = issue_code!

    result =
      with_authenticated_client do
        OidcTokenExchangeCoordinator.call(
          grant_type: "authorization_code",
          code: code_record.code,
          redirect_uri: @redirect_uri,
          client_id: "core-next-rp",
          client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
          client_assertion: "test-client-assertion",
          token_endpoint_uri: "https://log.umaxica.app/oauth/token",
          code_verifier: @code_verifier,
          expected_resource_type: "client",
        )
      end

    assert_predicate result, :success?
    assert_equal "Bearer", result.token_response[:token_type]
    assert_nil ClientRpSession.last.dpop_jkt
  end

  test "fails when DPoP proof has wrong htm" do
    code_record = issue_code!
    private_key, jwk = generate_dpop_jwk
    token_endpoint = "http://id.app.localhost/tokens"
    proof = build_dpop_proof(private_key, jwk, method: "GET", uri: token_endpoint)

    result =
      with_authenticated_client do
        OidcTokenExchangeCoordinator.call(
          grant_type: "authorization_code",
          code: code_record.code,
          redirect_uri: @redirect_uri,
          client_id: "core-next-rp",
          client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
          client_assertion: "test-client-assertion",
          code_verifier: @code_verifier,
          dpop_proof: proof,
          token_endpoint_uri: token_endpoint,
          request_method: "POST",
          expected_resource_type: "client",
        )
      end

    assert_not result.success?
    assert_equal "invalid_request", result.error
    assert_code_unconsumed(code_record)
  end

  test "fails when DPoP proof has wrong htu" do
    code_record = issue_code!
    private_key, jwk = generate_dpop_jwk
    proof = build_dpop_proof(private_key, jwk, method: "POST", uri: "http://other.host/tokens")

    result =
      with_authenticated_client do
        OidcTokenExchangeCoordinator.call(
          grant_type: "authorization_code",
          code: code_record.code,
          redirect_uri: @redirect_uri,
          client_id: "core-next-rp",
          client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
          client_assertion: "test-client-assertion",
          code_verifier: @code_verifier,
          dpop_proof: proof,
          token_endpoint_uri: "http://id.app.localhost/tokens",
          request_method: "POST",
          expected_resource_type: "client",
        )
      end

    assert_not result.success?
    assert_equal "invalid_request", result.error
    assert_code_unconsumed(code_record)
  end

  test "does not fall back to Bearer after a failed established DPoP constraint on refresh" do
    code_record = issue_code!
    private_key, jwk = generate_dpop_jwk
    token_endpoint = "https://log.umaxica.app/oauth/token"
    proof = build_dpop_proof(private_key, jwk, method: "POST", uri: token_endpoint)

    initial_result =
      with_authenticated_client do
        OidcTokenExchangeCoordinator.call(
          grant_type: "authorization_code",
          code: code_record.code,
          redirect_uri: @redirect_uri,
          client_id: "core-next-rp",
          client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
          client_assertion: "test-client-assertion",
          code_verifier: @code_verifier,
          dpop_proof: proof,
          token_endpoint_uri: token_endpoint,
          request_method: "POST",
          expected_resource_type: "client",
        )
      end

    assert_predicate initial_result, :success?
    assert_equal "DPoP", initial_result.token_response[:token_type]
    usage = ClientRpSession.order(:created_at).last
    refresh_digest = usage.refresh_token_digest

    result =
      with_authenticated_client do
        OidcTokenExchangeCoordinator.call(
          grant_type: "refresh_token",
          refresh_token: initial_result.token_response.fetch(:refresh_token),
          client_id: "core-next-rp",
          client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
          client_assertion: "test-client-assertion",
          token_endpoint_uri: token_endpoint,
          expected_resource_type: "client",
        )
      end

    assert_not result.success?
    assert_equal "invalid_request", result.error
    assert_nil result.token_response
    usage.reload

    assert_equal refresh_digest, usage.refresh_token_digest
    assert_predicate usage.dpop_jkt, :present?
    assert_equal "consumed", authorization_code_store.read(code_record.code).fetch("state")
  end

  test "fails closed when family linkage times out after the code is consumed" do
    code_record = issue_code!
    delegate = authorization_code_store
    code_store = Object.new
    code_store.define_singleton_method(:read) { |raw_code| delegate.read(raw_code) }
    code_store.define_singleton_method(:consume!) do |**arguments|
      delegate.consume!(**arguments)
    end
    code_store.define_singleton_method(:link_family!) do |**|
      raise Umaxica::Valkey::OperationError, "authorization code family link timed out"
    end
    rp_session_count = ClientRpSession.count

    result =
      with_authenticated_client do
        OidcTokenExchangeCoordinator.call(
          grant_type: "authorization_code",
          code: code_record.code,
          redirect_uri: @redirect_uri,
          client_id: "core-next-rp",
          client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
          client_assertion: "test-client-assertion",
          token_endpoint_uri: "https://log.umaxica.app/oauth/token",
          code_verifier: @code_verifier,
          code_store: code_store,
          expected_resource_type: "client",
        )
      end

    assert_not result.success?
    assert_equal "server_error", result.error
    assert_nil result.token_response
    assert_equal rp_session_count, ClientRpSession.count
    assert_equal "consumed", delegate.read(code_record.code).fetch("state")
  end

  test "issues OIDC tokens with URL issuer public subject and split audiences" do
    code_record = issue_code!(scope: "openid profile")

    result =
      with_authenticated_client do
        OidcTokenExchangeCoordinator.call(
          grant_type: "authorization_code",
          code: code_record.code,
          redirect_uri: @redirect_uri,
          client_id: "core-next-rp",
          client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
          client_assertion: "test-client-assertion",
          token_endpoint_uri: "https://log.umaxica.app/oauth/token",
          code_verifier: @code_verifier,
          expected_resource_type: "client",
        )
      end

    assert_predicate result, :success?

    id_token = OidcIdTokenVerifier.call(
      id_token: result.token_response.fetch(:id_token),
      client_id: "core-next-rp",
      resource_type: "client",
      expected_nonce: "test_nonce",
      issuer: OidcIssuer.for_client(@client),
      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(@client),
    )
    access_token = AuthenticationTokenService.decode(
      result.token_response.fetch(:access_token),
      host: OidcIssuer.host_for_client(@client),
      resource_type: "client",
      issuer: OidcIssuer.for_client(@client),
      audiences: [@client.aud],
      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(@client),
    )

    assert_predicate id_token, :success?
    assert_equal OidcIssuer.for_client(@client), id_token.payload.fetch("iss")
    assert_equal OidcSubject.for(@user, resource_type: "client"), id_token.payload.fetch("sub")
    assert_equal ["core-next-rp"], id_token.payload.fetch("aud")
    assert_equal OidcIssuer.for_client(@client), access_token.fetch("iss")
    assert_equal OidcSubject.for(@user, resource_type: "client"), access_token.fetch("sub")
    assert_equal [@client.aud], Array(access_token.fetch("aud"))
    assert_equal "core-next-rp", access_token.fetch("client_id")
    assert_equal "openid profile", access_token.fetch("scope")
    assert_predicate access_token.fetch("auth_time"), :present?

    base_kids = JitSecurityJwtRegistry.jwks_for("surface:BASE_APP").fetch(:keys).map { |key| key.fetch("kid") }
    access_header = JitSecurityJwtKeyring.parse_header(result.token_response.fetch(:access_token))
    id_header = JitSecurityJwtKeyring.parse_header(result.token_response.fetch(:id_token))

    assert_includes base_kids, access_header.fetch("kid")
    assert_includes base_kids, id_header.fetch("kid")
  end

  test "issued codes keep T0 through delayed issue T1 and exchange T2" do
    authentication_event_at = Time.utc(2026, 1, 2, 3, 4, 5)
    @user_session_token.update!(authentication_event_at: authentication_event_at)
    code_record = issue_code!(authentication_event_at: authentication_event_at)

    result =
      with_authenticated_client do
        OidcTokenExchangeCoordinator.call(
          grant_type: "authorization_code",
          code: code_record.code,
          redirect_uri: @redirect_uri,
          client_id: "core-next-rp",
          client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
          client_assertion: "test-client-assertion",
          token_endpoint_uri: "https://log.umaxica.app/oauth/token",
          code_verifier: @code_verifier,
          expected_resource_type: "client",
        )
      end

    assert_predicate result, :success?
    access_token = AuthenticationTokenService.decode(
      result.token_response.fetch(:access_token),
      host: OidcIssuer.host_for_client(@client),
      resource_type: "client",
      issuer: OidcIssuer.for_client(@client),
      audiences: [@client.aud],
      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(@client),
    )
    id_token = JWT.decode(result.token_response.fetch(:id_token), nil, false).first

    assert_equal authentication_event_at.to_i, access_token.fetch("auth_time")
    assert_equal authentication_event_at.to_i, id_token.fetch("auth_time")
    assert_operator access_token.fetch("iat"), :>, authentication_event_at.to_i
    assert_operator id_token.fetch("iat"), :>, authentication_event_at.to_i
  end

  test "preserves an authentication event time that predates authorization-code issuance" do
    auth_time = Time.utc(2026, 1, 2, 3, 4, 5)
    issued_at = Time.current
    code_record = plant_authorization_code!(
      client_id: "core-next-rp",
      redirect_uri: @redirect_uri,
      code_challenge: @code_challenge,
      code_challenge_method: "S256",
      auth_time: auth_time,
      issued_at: issued_at,
    )

    result =
      with_authenticated_client do
        OidcTokenExchangeCoordinator.call(
          grant_type: "authorization_code",
          code: code_record.code,
          redirect_uri: @redirect_uri,
          client_id: "core-next-rp",
          client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
          client_assertion: "test-client-assertion",
          token_endpoint_uri: "https://log.umaxica.app/oauth/token",
          code_verifier: @code_verifier,
          expected_resource_type: "client",
        )
      end

    assert_predicate result, :success?
    access_token = AuthenticationTokenService.decode(
      result.token_response.fetch(:access_token),
      host: OidcIssuer.host_for_client(@client),
      resource_type: "client",
      issuer: OidcIssuer.for_client(@client),
      audiences: [@client.aud],
      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(@client),
    )
    id_token = JWT.decode(result.token_response.fetch(:id_token), nil, false).first

    assert_equal auth_time.to_i, access_token.fetch("auth_time")
    assert_equal auth_time.to_i, id_token.fetch("auth_time")
    assert_operator issued_at.to_i, :>, access_token.fetch("auth_time")
  end

  test "rejects an authorization code without an authentication event time before consuming it" do
    code_record = plant_authorization_code!(
      client_id: "core-next-rp",
      redirect_uri: @redirect_uri,
      code_challenge: @code_challenge,
      code_challenge_method: "S256",
      auth_time: nil,
    )

    result =
      with_authenticated_client do
        OidcTokenExchangeCoordinator.call(
          grant_type: "authorization_code",
          code: code_record.code,
          redirect_uri: @redirect_uri,
          client_id: "core-next-rp",
          client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
          client_assertion: "test-client-assertion",
          token_endpoint_uri: "https://log.umaxica.app/oauth/token",
          code_verifier: @code_verifier,
          expected_resource_type: "client",
        )
      end

    assert_not result.success?
    assert_equal "invalid_grant", result.error
    assert_equal "Authorization code authentication time missing", result.error_description
    assert_code_unconsumed(code_record)
  end

  test "token exchange rejects a 42 character PKCE verifier one below the RFC 7636 minimum" do
    assert_exchange_rejects_verifier("a" * 42)
  end

  test "token exchange rejects a 129 character PKCE verifier one above the RFC 7636 maximum" do
    assert_exchange_rejects_verifier("a" * 129)
  end

  test "token exchange rejects a PKCE verifier containing a space character" do
    assert_exchange_rejects_verifier("#{"a" * 42} ")
  end

  test "token exchange rejects a PKCE verifier containing a slash character" do
    assert_exchange_rejects_verifier("#{"a" * 42}/")
  end

  test "token exchange rejects a PKCE verifier containing a plus character" do
    assert_exchange_rejects_verifier("#{"a" * 42}+")
  end

  test "token exchange rejects a PKCE verifier containing an equals character" do
    assert_exchange_rejects_verifier("#{"a" * 42}=")
  end

  test "token exchange rejects a PKCE verifier containing a non ASCII character" do
    assert_exchange_rejects_verifier("#{"a" * 42}é")
  end

  test "token exchange rejects a code_challenge_method of plain even with a matching verifier" do
    code_record = plant_authorization_code!(
      client_id: "core-next-rp",
      redirect_uri: @redirect_uri,
      code_challenge: @code_challenge,
      code_challenge_method: "plain",
      scope: "openid profile",
    )

    result =
      with_authenticated_client do
        OidcTokenExchangeCoordinator.call(
          grant_type: "authorization_code",
          code: code_record.code,
          redirect_uri: @redirect_uri,
          client_id: "core-next-rp",
          client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
          client_assertion: "test-client-assertion",
          token_endpoint_uri: "https://log.umaxica.app/oauth/token",
          code_verifier: @code_verifier,
          expected_resource_type: "client",
        )
      end

    assert_not result.success?
    assert_equal "invalid_request", result.error
    assert_code_unconsumed(code_record)
  end

  test "public palm audience exchange issues access token accepted by palm resource server" do
    public_client = public_visitor_account(
      client_id: "app-ios-rp",
      aud: PalmAccessTokenAuthenticator::AUDIENCE,
      redirect_uris: ["https://palm-jp.umaxica.app/auth/callback"],
      redirect_uris_by_realm: { "client" => ["https://palm-jp.umaxica.app/auth/callback"] },
      domains: ["palm-jp.umaxica.app"],
      allowed_scopes: OidcClientRegistry::PALM_ALLOWED_SCOPES,
    )
    code_record = issue_code!(
      client_id: public_client.client_id,
      redirect_uri: public_client.redirect_uris.first,
      scope: "openid palm.read",
    )

    with_public_client(public_client) do
      result = OidcTokenExchangeCoordinator.call(
        grant_type: "authorization_code",
        code: code_record.code,
        redirect_uri: public_client.redirect_uris.first,
        client_id: public_client.client_id,
        code_verifier: @code_verifier,
        expected_resource_type: "client",
      )

      assert_predicate result, :success?

      palm_result = PalmAccessTokenAuthenticator.call(
        access_token: result.token_response.fetch(:access_token),
        host: "palm-jp.umaxica.app",
        authorization_scheme: "Bearer",
      )

      assert_predicate palm_result, :success?
      assert_equal @user, palm_result.resource
      assert_equal "app-ios-rp", AuthorizationTokenClaims.client_id(palm_result.payload)
      assert_equal [PalmAccessTokenAuthenticator::AUDIENCE], Array(palm_result.payload.fetch("aud"))
      assert_equal %w(openid palm.read), Array(AuthorizationTokenClaims.scopes(palm_result.payload))
    end
  end

  private

  def generate_dpop_jwk
    ec = OpenSSL::PKey::EC.generate("prime256v1")
    jwk = JWT::JWK.new(ec).export
    [ec, jwk]
  end

  def build_dpop_proof(private_key, jwk, method:, uri:)
    payload = { "htm" => method, "htu" => uri, "iat" => Time.current.to_i, "jti" => SecureRandom.uuid }
    JWT.encode(payload, private_key, "ES256", { "typ" => "dpop+jwt", "jwk" => jwk })
  end

  def assert_exchange_rejects_verifier(verifier)
    code_record = issue_code!(scope: "openid profile")

    result =
      with_authenticated_client do
        OidcTokenExchangeCoordinator.call(
          grant_type: "authorization_code",
          code: code_record.code,
          redirect_uri: @redirect_uri,
          client_id: "core-next-rp",
          client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
          client_assertion: "test-client-assertion",
          token_endpoint_uri: "https://log.umaxica.app/oauth/token",
          code_verifier: verifier,
          expected_resource_type: "client",
        )
      end

    assert_not result.success?
    assert_equal "invalid_request", result.error
    assert_code_unconsumed(code_record)
  end

  def issue_code!(client_id: "core-next-rp", redirect_uri: @redirect_uri, scope: "openid profile email",
                  resource: nil, session_token: nil, authentication_event_at: Time.utc(2026, 1, 2, 3, 4, 5))
    resource ||= @user
    session_token ||= @user_session_token
    OidcAuthorizationCodeIssuer.call(
      client: OidcClientRegistry.find(client_id) || visitor_account(
        client_id: client_id,
        redirect_uris: [redirect_uri],
      ),
      params: {
        client_id: client_id,
        redirect_uri: redirect_uri,
        code_challenge: @code_challenge,
        code_challenge_method: "S256",
        nonce: "test_nonce",
        scope: scope,
      },
      resource: resource,
      session_token: session_token,
      authentication_event_at: authentication_event_at,
    )
  end

  def authorization_code_store
    Valkey::AuthState::AuthorizationCodeStore.new
  end

  def consume_issued_code!(code_record)
    authorization_code_store.consume!(
      raw_code: code_record.code,
      expected: {
        client_id: code_record.client_id,
        redirect_uri: code_record.redirect_uri,
      },
    )
  end

  def assert_code_unconsumed(code_record)
    payload = authorization_code_store.read(code_record.code)

    assert_not_nil payload
    assert_equal "issued", payload.fetch("state")
  end

  def plant_authorization_code!(client_id:, redirect_uri:, code_challenge:, code_challenge_method:,
                                scope: "openid profile email", resource: nil, session_token: nil,
                                auth_time: Time.current, issued_at: Time.current)
    resource ||= @user
    session_token ||= @user_session_token
    store = authorization_code_store
    # Bypass issue! S256 guard to plant defense-in-depth exchange cases.
    raw_code = SecureRandom.urlsafe_base64(32, padding: false)
    payload = {
      "version" => 1,
      "state" => "issued",
      "client_id" => client_id.to_s,
      "redirect_uri" => redirect_uri.to_s,
      "subject" => OidcSubject.for(resource, resource_type: "client"),
      "base_session_ref" => session_token.public_id,
      "code_challenge" => code_challenge.to_s,
      "code_challenge_method" => code_challenge_method.to_s,
      "nonce" => "test_nonce",
      "scope" => scope,
      "auth_time" => auth_time&.iso8601,
      "resource_type" => "client",
      "issued_at" => issued_at.iso8601,
      "expires_at" => (issued_at + Valkey::AuthState::AuthorizationCodeStore::CODE_TTL).iso8601,
    }.compact
    key = store.storage_key(raw_code)
    store.instance_variable_get(:@connection).call("SET", key, JSON.generate(payload), "EX", 60)
    OidcIssuedAuthorizationCode.new(
      code: raw_code,
      redirect_uri: redirect_uri,
      state: nil,
      resource_type: "client",
      client_id: client_id,
      nonce: "test_nonce",
      scope: scope,
    )
  end

  def create_visitor!
    VisitorStatus.find_or_create_by!(id: VisitorStatus::NOTHING)
    VisitorVisibility.find_or_create_by!(id: VisitorVisibility::VISITOR)
    VisitorMfaLevel.find_or_create_by!(id: VisitorMfaLevel::NOTHING)
    VisitorTokenBindingMethod.find_or_create_by!(id: VisitorTokenBindingMethod::NOTHING)
    VisitorTokenDbscStatus.find_or_create_by!(id: VisitorTokenDbscStatus::NOTHING)
    VisitorTokenKind.find_or_create_by!(id: VisitorTokenKind::BROWSER_WEB)
    VisitorTokenStatus.find_or_create_by!(id: VisitorTokenStatus::ACTIVE)
    Visitor.create!
  end

  # Stub ClientRegistry.authenticate to bypass secret_credential resolution in tests
  def with_authenticated_client(&block)
    OidcClientRegistry.stub(
      :authenticate_assertion, ->(cid, assertion, token_url:) {
                                 cid == "core-next-rp" && assertion.present? && token_url.present?
                               },
    ) do
      block.call
    end
  end

  def with_authenticated_org_client(_secret_credential, client_id: "core-next-rp", &block)
    OidcClientRegistry.stub(
      :authenticate_assertion, ->(cid, assertion, token_url:) {
                                 cid == client_id && assertion.present? && token_url.present?
                               },
    ) do
      block.call
    end
  end

  def with_authenticated_com_client(_secret_credential, client_id: "core-next-rp", &block)
    OidcClientRegistry.stub(
      :authenticate_assertion, ->(cid, assertion, token_url:) {
                                 cid == client_id && assertion.present? && token_url.present?
                               },
    ) do
      block.call
    end
  end

  def with_oidc_client_secret_credentials(overrides)
    creds = Rails.app.creds
    fetch = ->(key, default: nil) { overrides.fetch(key, default) }

    creds.stub(:option, fetch) do
      yield
    end
  end

  def visitor_account(overrides = {})
    OidcClientRegistry::VisitorAccount.new(
      client_id: "test_client",
      client_secret: "secret",
      redirect_uris: ["https://client.example/auth/callback"],
      redirect_uris_by_realm: { "client" => ["https://client.example/auth/callback"] },
      post_logout_redirect_uris: ["https://client.example/signed-out"],
      backchannel_logout_uris: [],
      backchannel_logout_session_required: false,
      aud: "test-audience",
      resource_type: "client",
      name: "Test Client",
      domains: ["client.example"],
      allowed_scopes: OidcClientRegistry::DEFAULT_ALLOWED_SCOPES,
      registered_token_endpoint_auth_method: "client_secret_post",
      metadata_token_endpoint_auth_method: "client_secret_post",
      jwt_namespace: nil,
      **overrides,
    )
  end

  def public_visitor_account(overrides = {})
    visitor_account(
      client_id: "public_test",
      client_secret: nil,
      registered_token_endpoint_auth_method: "none",
      metadata_token_endpoint_auth_method: "none",
      **overrides,
    )
  end

  def with_public_client(client, &)
    with_public_clients(client, &)
  end

  def with_public_clients(*clients)
    clients_by_id = clients.index_by(&:client_id)

    OidcClientRegistry.stub(:find, ->(client_id) { clients_by_id[client_id] }) do
      OidcClientRegistry.stub(:find!, ->(client_id) { clients_by_id.fetch(client_id) }) do
        yield
      end
    end
  end

  def with_oidc_client_key(namespace)
    key = OpenSSL::PKey::EC.generate("secp384r1")
    kid = "#{namespace.downcase.tr("_", "-")}-oidc-test"
    env = {
      "OIDC_CLIENT_#{namespace}_ACTIVE_KID" => kid,
      "OIDC_CLIENT_#{namespace}_PRIVATE_KEY" => Base64.strict_encode64(key.to_der),
    }
    previous = JitSecurityJwtRegistry.instance_variable_get(:@issuers)

    with_env(env) do
      JitSecurityJwtRegistry.reload!
      yield
    ensure
      JitSecurityJwtRegistry.instance_variable_set(:@issuers, previous)
    end
  end

  def with_env(values)
    previous = {}
    values.each do |key, value|
      previous[key] = ENV[key]
      value.nil? ? ENV.delete(key) : ENV[key] = value
    end
    yield
  ensure
    previous.each do |key, value|
      value.nil? ? ENV.delete(key) : ENV[key] = value
    end
  end
end
