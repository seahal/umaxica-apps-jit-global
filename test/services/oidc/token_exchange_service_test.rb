# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class OidcTokenExchangeCoordinatorTest < ActiveSupport::TestCase
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
        )
      end

    assert_predicate result, :success?
    assert_predicate result.token_response[:access_token], :present?
    assert_predicate result.token_response[:refresh_token], :present?
    assert_predicate result.token_response[:id_token], :present?
    assert_equal "Bearer", result.token_response[:token_type]
    assert_kind_of Integer, result.token_response[:expires_in]
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
      )
    end

    code_record.reload

    assert_predicate code_record, :consumed?
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
      )

      assert_not result.success?
      assert_equal "invalid_request", result.error
      assert_equal "PKCE verification failed", result.error_description
    end
  end

  test "explicit public client rejects plain pkce code" do
    public_client = public_visitor_account
    code_record = issue_code!(client_id: public_client.client_id, redirect_uri: public_client.redirect_uris.first)
    code_record.update_columns(code_challenge: @code_verifier, code_challenge_method: "plain")

    with_public_client(public_client) do
      result = OidcTokenExchangeCoordinator.call(
        grant_type: "authorization_code",
        code: code_record.code,
        redirect_uri: public_client.redirect_uris.first,
        client_id: public_client.client_id,
        code_verifier: @code_verifier,
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
    )

    assert_not result.success?
    assert_equal "invalid_request", result.error
    assert_equal "client_id mismatch", result.error_description
    assert_not_predicate code_record.reload, :consumed?
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
        )
      end

    assert_not result.success?
    assert_equal "invalid_grant", result.error
    assert_equal "Authorization code scope is invalid", result.error_description
    assert_not_predicate code_record.reload, :consumed?
  end

  test "explicit public client fails with expired code" do
    public_client = public_visitor_account
    code_record = issue_code!(client_id: public_client.client_id, redirect_uri: public_client.redirect_uris.first)

    travel ClientAuthorizationCode::CODE_TTL + 1.second do
      with_public_client(public_client) do
        result = OidcTokenExchangeCoordinator.call(
          grant_type: "authorization_code",
          code: code_record.code,
          redirect_uri: public_client.redirect_uris.first,
          client_id: public_client.client_id,
          code_verifier: @code_verifier,
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
    code_record.consume!

    with_public_client(public_client) do
      result = OidcTokenExchangeCoordinator.call(
        grant_type: "authorization_code",
        code: code_record.code,
        redirect_uri: public_client.redirect_uris.first,
        client_id: public_client.client_id,
        code_verifier: @code_verifier,
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
        )
      end

    assert_not result.success?
    assert_equal "invalid_grant", result.error
  end

  test "fails for expired code" do
    code_record = issue_code!

    travel ClientAuthorizationCode::CODE_TTL + 1.second do
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
          )
        end

      assert_not result.success?
      assert_equal "invalid_grant", result.error
    end
  end

  test "fails for already consumed code" do
    code_record = issue_code!
    code_record.consume!

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
        )
      end

    assert_not result.success?
    assert_equal "invalid_grant", result.error
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
        )
      end

    assert_not result.success?
    assert_equal "invalid_request", result.error
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
        )
      end

    assert_not result.success?
    assert_equal "invalid_request", result.error
  end

  test "creates user token record" do
    code_record = issue_code!

    assert_no_difference "ClientToken.count" do
      assert_difference "ClientTokenUsage.count", 1 do
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
      )
    end

    connection = ClientOidcConnection.find_by!(user_id: @user.id, client_id: "core-next-rp")
    usage = ClientTokenUsage.order(:created_at).last

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
      )
    end

    connection.reload

    assert_equal "openid email", connection.scope
    assert_nil connection.revoked_at
    assert_operator connection.last_used_at, :>, 1.minute.ago
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
        )
      end

    connection = ClientOidcConnection.find_by!(user_id: @user.id, client_id: "core-next-rp")
    previous_last_used_at = connection.last_used_at
    rotated = nil
    travel 1.minute do
      rotated = OidcRefreshTokenIssuer.call(refresh_token: result.token_response[:refresh_token])
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
    org_client = OidcClientRegistry.find("core-next-rp")
    org_redirect_uri = org_client.redirect_uris_by_realm.fetch("operator").first
    staff_secret_credential = "test_secret_credential_for_core_org"

    code_record = OperatorAuthorizationCode.issue!(
      staff: staff,
      operator_token: staff_session_token,
      client_id: "core-next-rp",
      redirect_uri: org_redirect_uri,
      code_challenge: @code_challenge,
      code_challenge_method: "S256",
      nonce: "staff_nonce",
      scope: "openid profile email",
    )

    result =
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
        )
      end

    assert_predicate result, :success?
    assert_predicate result.token_response[:access_token], :present?
    assert_predicate result.token_response[:refresh_token], :present?
    assert_equal "Bearer", result.token_response[:token_type]
  end

  test "creates staff token record for org client" do
    staff = operators(:one)
    staff_session_token = OperatorToken.create!(staff: staff)
    org_client = OidcClientRegistry.find("core-next-rp")
    org_redirect_uri = org_client.redirect_uris_by_realm.fetch("operator").first
    staff_secret_credential = "test_secret_credential_for_core_org"

    code_record = OperatorAuthorizationCode.issue!(
      staff: staff,
      operator_token: staff_session_token,
      client_id: "core-next-rp",
      redirect_uri: org_redirect_uri,
      code_challenge: @code_challenge,
      code_challenge_method: "S256",
      nonce: "staff_nonce",
      scope: "openid profile email",
    )

    assert_no_difference "OperatorToken.count" do
      assert_difference "OperatorTokenUsage.count", 1 do
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
    code_record = OperatorAuthorizationCode.issue!(
      staff: staff,
      operator_token: staff_session_token,
      client_id: "core-next-rp",
      redirect_uri: org_client.redirect_uris_by_realm.fetch("operator").first,
      code_challenge: @code_challenge,
      code_challenge_method: "S256",
      nonce: "staff_nonce",
      scope: "openid profile email",
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
      )
    end

    connection = OperatorOidcConnection.find_by!(staff_id: staff.id, client_id: "core-next-rp")
    usage = OperatorTokenUsage.order(:created_at).last

    assert_equal "openid profile email", connection.scope
    assert_equal staff_session_token.id, usage.operator_token_id
    assert_equal "core-next-rp", usage.oidc_client_id
    assert_equal "openid profile email", usage.oidc_scope
  end

  test "exchanges valid visitor code for tokens with VisitorToken" do
    visitor = create_visitor!
    visitor_session_token = VisitorToken.create!(visitor: visitor, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB)
    com_client = OidcClientRegistry.find("core-next-rp")
    com_redirect_uri = com_client.redirect_uris_by_realm.fetch("visitor").first
    visitor_secret_credential = "test_secret_credential_for_core_com"

    code_record = VisitorAuthorizationCode.issue!(
      visitor: visitor,
      visitor_token: visitor_session_token,
      client_id: "core-next-rp",
      redirect_uri: com_redirect_uri,
      code_challenge: @code_challenge,
      code_challenge_method: "S256",
      nonce: "visitor_nonce",
      scope: "openid profile email",
    )

    result =
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
        )
      end

    assert_predicate result, :success?
    assert_predicate result.token_response[:access_token], :present?
    assert_predicate result.token_response[:refresh_token], :present?
    assert_equal "Bearer", result.token_response[:token_type]
  end

  test "creates visitor token record for com client" do
    visitor = create_visitor!
    visitor_session_token = VisitorToken.create!(visitor: visitor, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB)
    com_client = OidcClientRegistry.find("core-next-rp")
    com_redirect_uri = com_client.redirect_uris_by_realm.fetch("visitor").first
    visitor_secret_credential = "test_secret_credential_for_core_com"

    code_record = VisitorAuthorizationCode.issue!(
      visitor: visitor,
      visitor_token: visitor_session_token,
      client_id: "core-next-rp",
      redirect_uri: com_redirect_uri,
      code_challenge: @code_challenge,
      code_challenge_method: "S256",
      nonce: "visitor_nonce",
      scope: "openid profile email",
    )

    assert_no_difference "VisitorToken.count" do
      assert_difference "VisitorTokenUsage.count", 1 do
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
    code_record = VisitorAuthorizationCode.issue!(
      visitor: visitor,
      visitor_token: visitor_session_token,
      client_id: "core-next-rp",
      redirect_uri: com_client.redirect_uris_by_realm.fetch("visitor").first,
      code_challenge: @code_challenge,
      code_challenge_method: "S256",
      nonce: "visitor_nonce",
      scope: "openid profile email",
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
      )
    end

    connection = VisitorOidcConnection.find_by!(visitor_id: visitor.id, client_id: "core-next-rp")
    usage = VisitorTokenUsage.order(:created_at).last

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
        )
      end

    assert_predicate result, :success?
    assert_equal "DPoP", result.token_response[:token_type]
    assert_predicate result.token_response[:access_token], :present?

    ClientToken.last

    assert_predicate ClientTokenUsage.last.dpop_jkt, :present?
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
        )
      end

    assert_predicate result, :success?
    assert_equal "Bearer", result.token_response[:token_type]
    assert_nil ClientTokenUsage.last.dpop_jkt
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
        )
      end

    assert_not result.success?
    assert_equal "invalid_request", result.error
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
        )
      end

    assert_not result.success?
    assert_equal "invalid_request", result.error
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
    assert_equal %w(openid profile), access_token.fetch("scp")
    assert_predicate access_token.fetch("auth_time"), :present?

    base_kids = JitSecurityJwtRegistry.jwks_for("surface:BASE_APP").fetch(:keys).map { |key| key.fetch("kid") }
    access_header = JitSecurityJwtKeyring.parse_header(result.token_response.fetch(:access_token))
    id_header = JitSecurityJwtKeyring.parse_header(result.token_response.fetch(:id_token))

    assert_includes base_kids, access_header.fetch("kid")
    assert_includes base_kids, id_header.fetch("kid")
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
    code_record = issue_code!(scope: "openid profile")
    code_record.update_columns(code_challenge_method: "plain")

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
        )
      end

    assert_not result.success?
    assert_equal "invalid_request", result.error
    assert_not_predicate code_record.reload, :consumed?
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
        )
      end

    assert_not result.success?
    assert_equal "invalid_request", result.error
    assert_not_predicate code_record.reload, :consumed?
  end

  def issue_code!(client_id: "core-next-rp", redirect_uri: @redirect_uri, scope: "openid profile email")
    ClientAuthorizationCode.issue!(
      user: @user,
      client_token: @user_session_token,
      client_id: client_id,
      redirect_uri: redirect_uri,
      code_challenge: @code_challenge,
      code_challenge_method: "S256",
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

  def with_authenticated_org_client(_secret_credential, &block)
    OidcClientRegistry.stub(
      :authenticate_assertion, ->(cid, assertion, token_url:) {
                                 cid == "core-next-rp" && assertion.present? && token_url.present?
                               },
    ) do
      block.call
    end
  end

  def with_authenticated_com_client(_secret_credential, &block)
    OidcClientRegistry.stub(
      :authenticate_assertion, ->(cid, assertion, token_url:) {
                                 cid == "core-next-rp" && assertion.present? && token_url.present?
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
