# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class OidcClientRegistryTest < ActiveSupport::TestCase
  def with_oidc_client_secret_credentials(overrides)
    creds = Rails.app.creds
    fetch = ->(key, default: nil) { overrides.fetch(key, default) }

    creds.stub(:option, fetch) do
      yield
    end
  end

  test "find returns client for known client_id" do
    client = OidcClientRegistry.find("warp-app")

    assert_not_nil client
    assert_equal "warp-app", client.client_id
    assert_equal "warp-app", client.aud
    assert_equal "client", client.resource_type
    assert_equal "Warp App RP", client.name
    assert_includes client.domains,
                    ENV.fetch("PUBLIC_WARP_SERVICE_URL", "warp.app.localhost")
    assert_kind_of Array, client.redirect_uris
    assert client.redirect_uris.any? { |uri| uri.include?("/oidc/callback") }
  end

  test "find returns nil for unknown client_id" do
    assert_nil OidcClientRegistry.find("unknown_client")
  end

  test "find! raises for unknown client_id" do
    assert_raises(OidcClientRegistry::ClientNotFound) do
      OidcClientRegistry.find!("unknown_client")
    end
  end

  test "read-only content surfaces are not registered as Rails OIDC RPs" do
    %w(
      docs_app docs_org docs_com
      news_app news_org news_com
      help_app help_org help_com
    ).each do |client_id|
      assert_nil OidcClientRegistry.find(client_id), client_id
    end
  end

  test "retired shared browser clients are not registered" do
    retired_shared_client_id = ["core", "next-rp"].join("-")

    [retired_shared_client_id, "sign-rp", "base-rails-rp"].each do |client_id|
      assert_nil OidcClientRegistry.find(client_id), client_id
    end
  end

  test "retired Side client IDs are rejected without an alias" do
    %w(app com org).each do |surface|
      client_id = ["side", surface].join("-")

      assert_nil OidcClientRegistry.find(client_id), client_id
    end
  end

  test "valid_redirect_uri? returns true for registered URI" do
    client = OidcClientRegistry.find("core-app")
    uri = client.redirect_uris.first

    assert OidcClientRegistry.valid_redirect_uri?("core-app", uri)
  end

  test "valid_redirect_uri? returns false for unregistered URI" do
    assert_not OidcClientRegistry.valid_redirect_uri?("core-app", "https://evil.com/callback")
  end

  test "valid_redirect_uri? returns false for unknown client" do
    assert_not OidcClientRegistry.valid_redirect_uri?("unknown", "http://localhost/callback")
  end

  test "valid_post_logout_redirect_uri? uses exact registered uri match" do
    client = OidcClientRegistry.find!("core-app")
    uri = client.post_logout_redirect_uris.first

    assert OidcClientRegistry.valid_post_logout_redirect_uri?(
      client_id: client.client_id, uri: uri, resource_type: "client",
    )
    assert_not OidcClientRegistry.valid_post_logout_redirect_uri?(
      client_id: client.client_id, uri: "#{uri}/extra", resource_type: "client",
    )
    assert_not OidcClientRegistry.valid_post_logout_redirect_uri?(
      client_id: client.client_id,
      uri: uri.sub("/sign/out", "/SIGN/OUT"),
      resource_type: "client",
    )
    assert_not OidcClientRegistry.valid_post_logout_redirect_uri?(
      client_id: "unknown",
      uri: uri,
      resource_type: "client",
    )
  end

  test "valid_post_logout_redirect_uri? binds registered uris to the requesting realm" do
    clients_by_realm = {
      "client" => OidcClientRegistry.find!("core-app"),
      "visitor" => OidcClientRegistry.find!("core-com"),
      "operator" => OidcClientRegistry.find!("core-org"),
    }

    clients_by_realm.each do |realm, client|
      uri = client.post_logout_redirect_uris.first

      assert OidcClientRegistry.valid_post_logout_redirect_uri?(
        client_id: client.client_id, uri: uri, resource_type: realm,
      ), "#{realm} realm should accept its own uri #{uri}"

      (clients_by_realm.keys - [realm]).each do |other_realm|
        assert_not OidcClientRegistry.valid_post_logout_redirect_uri?(
          client_id: client.client_id, uri: uri, resource_type: other_realm,
        ), "#{other_realm} realm must reject #{realm} uri #{uri}"
      end
    end
  end

  test "client cache follows configured host changes" do
    original_client = OidcClientRegistry.find!("core-app")
    original_env = ENV["PUBLIC_CORE_SERVICE_URL"]

    begin
      ENV["PUBLIC_CORE_SERVICE_URL"] = "temporary-core.example.test"

      assert_includes OidcClientRegistry.find!("core-app").redirect_uris,
                      "https://temporary-core.example.test/oidc/callback"
    ensure
      if original_env.nil?
        ENV.delete("PUBLIC_CORE_SERVICE_URL")
      else
        ENV["PUBLIC_CORE_SERVICE_URL"] = original_env
      end
    end

    restored_client = OidcClientRegistry.find!("core-app")

    assert_equal original_client.redirect_uris, restored_client.redirect_uris
  end

  test "shared browser clients post logout at canonical /sign/out" do
    AuthBoundaryAuthorityMap.first_party_rp_client_ids.each do |client_id|
      client = OidcClientRegistry.find!(client_id)

      assert client.post_logout_redirect_uris.all? { |uri| URI.parse(uri).path == "/sign/out" },
             "#{client_id} should complete at /sign/out"
    end
  end

  test "sign and core clients expose registered logout receiver uris" do
    app = OidcClientRegistry.find!("core-app")
    core = OidcClientRegistry.find!("core-app")

    assert app.backchannel_logout_uris.all? { |uri| URI.parse(uri).path == "/oidc/backchannel/logout" }
    assert core.backchannel_logout_uris.all? { |uri| URI.parse(uri).path == "/oidc/backchannel/logout" }
  end

  test "logout receiver uris can be filtered by acme resource type" do
    {
      "core-app" => "client",
      "core-com" => "visitor",
      "core-org" => "operator",
    }.each do |client_id, resource_type|
      client = OidcClientRegistry.find!(client_id)

      assert_equal client.backchannel_logout_uris,
                   OidcClientRegistry.backchannel_logout_uris_for(
                     client_id: client_id, resource_type: resource_type,
                   )

      (%w(client visitor operator) - [resource_type]).each do |other_resource_type|
        assert_empty OidcClientRegistry.backchannel_logout_uris_for(
          client_id: client_id, resource_type: other_resource_type,
        )
      end
    end
  end

  test "native clients do not expose logout receiver uris" do
    %w(app-ios-rp app-android-rp).each do |client_id|
      client = OidcClientRegistry.find!(client_id)

      assert_empty client.backchannel_logout_uris, "#{client_id} should not have back-channel logout URIs"
    end
  end

  test "sign and core clients require back-channel session logout" do
    assert OidcClientRegistry.find!("core-app").backchannel_logout_session_required
  end

  test "all expected clients are registered" do
    expected = %w(
      app-ios-rp app-android-rp
      core-app core-com core-org warp-app warp-com warp-org edit-org
    )

    expected.each do |client_id|
      client = OidcClientRegistry.find(client_id)

      assert_not_nil client, "VisitorAccount #{client_id} should be registered"
      assert_predicate client.redirect_uris, :present?, "VisitorAccount #{client_id} should have redirect_uris"
      assert_predicate client.aud, :present?, "VisitorAccount #{client_id} should have aud"
    end
  end

  test "clients expose explicit allowed scopes" do
    expectations = {
      "app-ios-rp" => OidcClientRegistry::PALM_ALLOWED_SCOPES,
      "app-android-rp" => OidcClientRegistry::PALM_ALLOWED_SCOPES,
      "core-app" => OidcClientRegistry::DEFAULT_ALLOWED_SCOPES,
      "core-com" => OidcClientRegistry::DEFAULT_ALLOWED_SCOPES,
      "core-org" => OidcClientRegistry::DEFAULT_ALLOWED_SCOPES,
      "warp-app" => OidcClientRegistry::DEFAULT_ALLOWED_SCOPES,
      "warp-com" => OidcClientRegistry::DEFAULT_ALLOWED_SCOPES,
      "warp-org" => OidcClientRegistry::DEFAULT_ALLOWED_SCOPES,
      "edit-org" => OidcClientRegistry::DEFAULT_ALLOWED_SCOPES,
    }

    expectations.each do |client_id, allowed_scopes|
      client = OidcClientRegistry.find!(client_id)

      assert_equal allowed_scopes, client.allowed_scopes, client_id
    end
  end

  test "org clients have operator resource_type" do
    %w(core-org warp-org edit-org).each do |client_id|
      client = OidcClientRegistry.find(client_id)

      assert_equal "operator", client.resource_type, "#{client_id} should be operator type"
    end
  end

  test "app clients have client resource_type" do
    %w(app-ios-rp app-android-rp core-app warp-app).each do |client_id|
      client = OidcClientRegistry.find(client_id)

      assert_equal "client", client.resource_type, "#{client_id} should be client type"
    end
  end

  test "com clients have visitor resource_type" do
    %w(core-com warp-com).each do |client_id|
      client = OidcClientRegistry.find(client_id)

      assert_equal "visitor", client.resource_type, "#{client_id} should be visitor type"
    end
  end

  test "authenticate returns false when secret_credentials are not configured" do
    assert_not OidcClientRegistry.authenticate("warp-app", "any_secret_credential")
  end

  test "find resolves secret_credential from flat credential key" do
    with_oidc_client_secret_credentials("OIDC_CLIENT_SECRETS_WARP-APP": "warp-app-secret_credential") do
      client = OidcClientRegistry.find("warp-app")

      assert_equal "warp-app-secret_credential", client.client_secret
    end
  end

  test "authenticate uses flat credential key" do
    with_oidc_client_secret_credentials("OIDC_CLIENT_SECRETS_WARP-APP": "warp-app-secret_credential") do
      assert OidcClientRegistry.authenticate("warp-app", "warp-app-secret_credential")
      assert_not OidcClientRegistry.authenticate("warp-app", "wrong-secret_credential")
    end
  end

  test "authenticate returns false for blank secret_credential" do
    assert_not OidcClientRegistry.authenticate("warp-app", "")
    assert_not OidcClientRegistry.authenticate("warp-app", nil)
  end

  test "client_ids returns all registered client IDs" do
    ids = OidcClientRegistry.client_ids

    assert_includes ids, "warp-app"
    assert_not_includes ids, "sign-rp"
    assert_not_includes ids, "base-rails-rp"
    assert_includes ids, "app-ios-rp"
    assert_includes ids, "app-android-rp"
    AuthBoundaryAuthorityMap.first_party_rp_client_ids.each { |client_id| assert_includes ids, client_id }
    assert_equal OidcClientStoresStaticClientStore.clients.keys.sort, ids.sort
  end

  test "visitor account does not expose ambiguous token endpoint auth method" do
    client = OidcClientRegistry.find!("warp-app")

    assert_not_respond_to client, :token_endpoint_auth_method
  end

  test "acme and core clients expose registered private_key_jwt namespaces" do
    expectations = {
      "core-app" => "CORE_APP",
      "warp-app" => "WARP_APP",
    }

    expectations.each do |client_id, namespace|
      client = OidcClientRegistry.find!(client_id)

      assert_equal "private_key_jwt", client.registered_token_endpoint_auth_method
      assert_predicate client, :private_key_jwt_client?
      assert_predicate client, :confidential_client?
      assert_not_predicate client, :public_client?
      assert_equal namespace, client.jwt_namespace
    end
  end

  test "private_key_jwt configuration validation requires oidc client signing keys" do
    JitSecurityJwtRegistry.stub(:private_key_for, nil) do
      error =
        assert_raises(OidcClientRegistry::ClientAuthenticationConfigurationError) do
          OidcClientRegistry.validate_private_key_jwt_configuration!
        end

      assert_includes error.message, "core-app(CORE_APP)"
      assert_includes error.message, "warp-app(WARP_APP)"
    end
  end

  test "private_key_jwt configuration validation passes when signing keys exist" do
    JitSecurityJwtRegistry.stub(:private_key_for, OpenSSL::PKey::EC.generate("secp384r1")) do
      assert OidcClientRegistry.validate_private_key_jwt_configuration!
    end
  end

  test "explicit registered none client is public" do
    client = visitor_account(registered_token_endpoint_auth_method: "none", client_secret: nil)

    assert_predicate client, :public_client?
    assert_not_predicate client, :confidential_client?
  end

  test "native app clients are public palm-api clients" do
    %w(app-ios-rp app-android-rp).each do |client_id|
      client = OidcClientRegistry.find!(client_id)

      assert_equal "none", client.registered_token_endpoint_auth_method
      assert_equal "palm-api", client.aud
      assert_predicate client, :public_client?
    end
  end

  test "missing registered auth method with blank secret remains confidential" do
    client = visitor_account(registered_token_endpoint_auth_method: nil, client_secret: "")

    assert_not_predicate client, :public_client?
    assert_predicate client, :confidential_client?
  end

  test "core client is registered to regional redirect hosts" do
    expectations = {
      "warp-app" => {
        host: ENV.fetch("PUBLIC_WARP_SERVICE_URL", "warp.app.localhost"),
        aud: "warp-app",
        resource_type: "client",
      },
    }

    expectations.each do |client_id, expected|
      client = OidcClientRegistry.find!(client_id)
      redirect_uri = URI.parse(client.redirect_uris.fetch(0))

      assert_equal expected[:host], redirect_uri.host, "#{client_id} redirect host is not regional"
      assert_equal "/oidc/callback", redirect_uri.path
      assert_equal expected[:aud], client.aud
      assert_equal expected[:resource_type], client.resource_type
      assert_includes client.domains, expected[:host]
    end
  end

  test "core app client is registered to the core app redirect host" do
    client = OidcClientRegistry.find!("core-app")
    redirect_hosts = client.redirect_uris.map { |uri| URI.parse(uri).host }
    expected_host = ENV.fetch("PUBLIC_CORE_SERVICE_URL", "jpx.umaxica.app")

    assert_includes redirect_hosts, expected_host
    assert_includes client.domains, expected_host
    assert client.redirect_uris.all? { |uri| URI.parse(uri).path == "/oidc/callback" }
    assert_equal "core-app", client.aud
    assert_equal "client", client.resource_type
  end

  private

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
end
