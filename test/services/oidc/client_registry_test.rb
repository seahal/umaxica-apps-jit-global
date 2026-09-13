# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class OidcClientRegistryTest < ActiveSupport::TestCase
  def post_logout_uris_for_realm(client, resource_type)
    hosts = Rails.configuration.x.boot_config.fetch(:hosts)
    realm_hosts =
      case resource_type
      when "operator"
        [hosts.sign_staff.host, hosts.auth_staff.host,
         ENV.fetch("PRIVATE_AUTH_STAFF_URL", nil), ENV.fetch("PUBLIC_AUTH_STAFF_URL", nil),]
      when "visitor"
        [hosts.sign_corporate.host, hosts.auth_corporate.host,
         ENV.fetch("PRIVATE_AUTH_CORPORATE_URL", nil), ENV.fetch("PUBLIC_AUTH_CORPORATE_URL", nil),]
      else
        [hosts.sign_service.host, hosts.auth_service.host,
         ENV.fetch("PRIVATE_AUTH_SERVICE_URL", nil), ENV.fetch("PUBLIC_AUTH_SERVICE_URL", nil),]
      end.compact_blank
    client.post_logout_redirect_uris.select { |uri| realm_hosts.include?(URI.parse(uri).host) }
  end

  def with_oidc_client_secret_credentials(overrides)
    creds = Rails.app.creds
    fetch = ->(key, default: nil) { overrides.fetch(key, default) }

    creds.stub(:option, fetch) do
      yield
    end
  end

  test "find returns client for known client_id" do
    client = OidcClientRegistry.find("core-next-rp")

    assert_not_nil client
    assert_equal "core-next-rp", client.client_id
    assert_equal "core-next-rp", client.aud
    assert_equal "client", client.resource_type
    assert_equal "Core Next RP", client.name
    assert_includes client.domains,
                    ENV.fetch("PUBLIC_CORE_SERVICE_URL", ENV.fetch("PUBLIC_CORE_SERVICE_URL", "jpx.umaxica.app"))
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

  test "valid_redirect_uri? returns true for registered URI" do
    client = OidcClientRegistry.find("core-next-rp")
    uri = client.redirect_uris.first

    assert OidcClientRegistry.valid_redirect_uri?("core-next-rp", uri)
  end

  test "valid_redirect_uri? returns false for unregistered URI" do
    assert_not OidcClientRegistry.valid_redirect_uri?("core-next-rp", "https://evil.com/callback")
  end

  test "valid_redirect_uri? returns false for unknown client" do
    assert_not OidcClientRegistry.valid_redirect_uri?("unknown", "http://localhost/callback")
  end

  test "valid_post_logout_redirect_uri? uses exact registered uri match" do
    client = OidcClientRegistry.find!("sign-rp")
    uri = post_logout_uris_for_realm(client, "client").first

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
    client = OidcClientRegistry.find!("sign-rp")
    uris_by_realm = {
      "client" => post_logout_uris_for_realm(client, "client"),
      "operator" => post_logout_uris_for_realm(client, "operator"),
      "visitor" => post_logout_uris_for_realm(client, "visitor"),
    }

    uris_by_realm.each do |realm, uris|
      assert_not_empty uris, "sign-rp should register post_logout uris for #{realm}"
    end

    uris_by_realm.each do |realm, uris|
      uris.each do |uri|
        assert OidcClientRegistry.valid_post_logout_redirect_uri?(
          client_id: client.client_id, uri: uri, resource_type: realm,
        ), "#{realm} realm should accept its own uri #{uri}"

        (uris_by_realm.keys - [realm]).each do |other_realm|
          assert_not OidcClientRegistry.valid_post_logout_redirect_uri?(
            client_id: client.client_id, uri: uri, resource_type: other_realm,
          ), "#{other_realm} realm must reject #{realm} uri #{uri}"
        end
      end
    end
  end

  test "client cache follows configured host changes" do
    original_client = OidcClientRegistry.find!("sign-rp")
    original_env = ENV["PUBLIC_AUTH_SERVICE_URL"]

    begin
      ENV["PUBLIC_AUTH_SERVICE_URL"] = "temporary-sign.example.test"

      assert_includes OidcClientRegistry.find!("sign-rp").redirect_uris,
                      "https://temporary-sign.example.test/oidc/callback"
    ensure
      if original_env.nil?
        ENV.delete("PUBLIC_AUTH_SERVICE_URL")
      else
        ENV["PUBLIC_AUTH_SERVICE_URL"] = original_env
      end
    end

    restored_client = OidcClientRegistry.find!("sign-rp")

    assert_equal original_client.redirect_uris, restored_client.redirect_uris
  end

  test "sign and core post logout redirect uris end at sign out completion" do
    %w(sign-rp core-next-rp).each do |client_id|
      client = OidcClientRegistry.find!(client_id)

      assert client.post_logout_redirect_uris.all? { |uri| URI.parse(uri).path == "/sign/out/complete" },
             "#{client_id} should complete at /sign/out/complete"
    end
  end

  test "base rails rp completes on the base lobby and keeps side completion" do
    client = OidcClientRegistry.find!("base-rails-rp")
    paths = client.post_logout_redirect_uris.map { |uri| URI.parse(uri).path }.uniq.sort

    assert_equal %w(/lobby /sign/out/complete), paths
  end

  test "sign and core clients expose registered logout receiver uris" do
    sign = OidcClientRegistry.find!("sign-rp")
    core = OidcClientRegistry.find!("core-next-rp")

    assert sign.backchannel_logout_uris.all? { |uri| URI.parse(uri).path == "/oidc/backchannel/logout" }
    assert core.backchannel_logout_uris.all? { |uri| URI.parse(uri).path == "/oidc/backchannel/logout" }
  end

  test "logout receiver uris can be filtered by acme resource type" do
    app_uris = OidcClientRegistry.backchannel_logout_uris_for(client_id: "sign-rp", resource_type: "client")
    com_uris = OidcClientRegistry.backchannel_logout_uris_for(client_id: "sign-rp", resource_type: "visitor")
    org_uris = OidcClientRegistry.backchannel_logout_uris_for(client_id: "sign-rp", resource_type: "operator")

    hosts = Rails.configuration.x.boot_config.fetch(:hosts)

    assert_equal [
      hosts.sign_service.host,
      hosts.auth_service.host,
      ENV.fetch("PRIVATE_AUTH_SERVICE_URL", nil),
      ENV.fetch("PUBLIC_AUTH_SERVICE_URL", nil),
    ].compact_blank.uniq.sort, app_uris.map { |uri| URI.parse(uri).host }.sort
    assert_equal [
      hosts.sign_corporate.host,
      hosts.auth_corporate.host,
      ENV.fetch("PRIVATE_AUTH_CORPORATE_URL", nil),
      ENV.fetch("PUBLIC_AUTH_CORPORATE_URL", nil),
    ].compact_blank.uniq.sort, com_uris.map { |uri| URI.parse(uri).host }.sort
    assert_equal [
      hosts.sign_staff.host,
      hosts.auth_staff.host,
      ENV.fetch("PRIVATE_AUTH_STAFF_URL", nil),
      ENV.fetch("PUBLIC_AUTH_STAFF_URL", nil),
    ].compact_blank.uniq.sort, org_uris.map { |uri| URI.parse(uri).host }.sort
  end

  test "native and content clients do not expose logout receiver uris" do
    %w(app-ios-rp app-android-rp docs_app docs_org docs_com news_app news_org news_com help_app help_org
       help_com).each do |client_id|
      client = OidcClientRegistry.find!(client_id)

      assert_empty client.backchannel_logout_uris, "#{client_id} should not have back-channel logout URIs"
    end
  end

  test "sign and core clients require back-channel session logout while docs app defaults false" do
    assert OidcClientRegistry.find!("sign-rp").backchannel_logout_session_required
    assert OidcClientRegistry.find!("core-next-rp").backchannel_logout_session_required
    assert_not OidcClientRegistry.find!("docs_app").backchannel_logout_session_required
  end

  test "all expected clients are registered" do
    expected = %w(
      sign-rp base-rails-rp core-next-rp app-ios-rp app-android-rp
      docs_app docs_org docs_com
      news_app news_org news_com
      help_app help_org help_com
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
      "sign-rp" => OidcClientRegistry::DEFAULT_ALLOWED_SCOPES,
      "base-rails-rp" => OidcClientRegistry::DEFAULT_ALLOWED_SCOPES,
      "core-next-rp" => OidcClientRegistry::DEFAULT_ALLOWED_SCOPES,
      "app-ios-rp" => OidcClientRegistry::PALM_ALLOWED_SCOPES,
      "app-android-rp" => OidcClientRegistry::PALM_ALLOWED_SCOPES,
      "docs_app" => OidcClientRegistry::DEFAULT_ALLOWED_SCOPES,
      "docs_org" => OidcClientRegistry::DEFAULT_ALLOWED_SCOPES,
      "docs_com" => OidcClientRegistry::DEFAULT_ALLOWED_SCOPES,
      "news_app" => OidcClientRegistry::DEFAULT_ALLOWED_SCOPES,
      "news_org" => OidcClientRegistry::DEFAULT_ALLOWED_SCOPES,
      "news_com" => OidcClientRegistry::DEFAULT_ALLOWED_SCOPES,
      "help_app" => OidcClientRegistry::DEFAULT_ALLOWED_SCOPES,
      "help_org" => OidcClientRegistry::DEFAULT_ALLOWED_SCOPES,
      "help_com" => OidcClientRegistry::DEFAULT_ALLOWED_SCOPES,
    }

    expectations.each do |client_id, allowed_scopes|
      client = OidcClientRegistry.find!(client_id)

      assert_equal allowed_scopes, client.allowed_scopes, client_id
    end
  end

  test "org clients have operator resource_type" do
    %w(docs_org news_org help_org).each do |client_id|
      client = OidcClientRegistry.find(client_id)

      assert_equal "operator", client.resource_type, "#{client_id} should be operator type"
    end
  end

  test "app clients have client resource_type" do
    %w(sign-rp base-rails-rp core-next-rp app-ios-rp app-android-rp docs_app news_app help_app).each do |client_id|
      client = OidcClientRegistry.find(client_id)

      assert_equal "client", client.resource_type, "#{client_id} should be client type"
    end
  end

  test "com clients have visitor resource_type" do
    %w(docs_com news_com help_com).each do |client_id|
      client = OidcClientRegistry.find(client_id)

      assert_equal "visitor", client.resource_type, "#{client_id} should be visitor type"
    end
  end

  test "authenticate returns false when secret_credentials are not configured" do
    assert_not OidcClientRegistry.authenticate("core-next-rp", "any_secret_credential")
  end

  test "find resolves secret_credential from flat credential key" do
    with_oidc_client_secret_credentials("OIDC_CLIENT_SECRETS_CORE-NEXT-RP": "core-app-secret_credential") do
      client = OidcClientRegistry.find("core-next-rp")

      assert_equal "core-app-secret_credential", client.client_secret
    end
  end

  test "authenticate uses flat credential key" do
    with_oidc_client_secret_credentials("OIDC_CLIENT_SECRETS_BASE-RAILS-RP": "acme-org-secret_credential") do
      assert OidcClientRegistry.authenticate("base-rails-rp", "acme-org-secret_credential")
      assert_not OidcClientRegistry.authenticate("base-rails-rp", "wrong-secret_credential")
    end
  end

  test "authenticate returns false for blank secret_credential" do
    assert_not OidcClientRegistry.authenticate("core-next-rp", "")
    assert_not OidcClientRegistry.authenticate("core-next-rp", nil)
  end

  test "client_ids returns all registered client IDs" do
    ids = OidcClientRegistry.client_ids

    assert_includes ids, "core-next-rp"
    assert_includes ids, "base-rails-rp"
    assert_includes ids, "app-ios-rp"
    assert_includes ids, "app-android-rp"
    assert_equal 15, ids.size
  end

  test "visitor account does not expose ambiguous token endpoint auth method" do
    client = OidcClientRegistry.find!("core-next-rp")

    assert_not_respond_to client, :token_endpoint_auth_method
  end

  test "acme and core clients expose registered private_key_jwt namespaces" do
    expectations = {
      "base-rails-rp" => "BASE_APP",
      "core-next-rp" => "CORE_APP",
      "sign-rp" => "SIGN_APP",
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

      assert_includes error.message, "base-rails-rp(BASE_APP)"
      assert_includes error.message, "sign-rp(SIGN_APP)"
      assert_includes error.message, "core-next-rp(CORE_APP)"
    end
  end

  test "private_key_jwt configuration validation passes when signing keys exist" do
    JitSecurityJwtRegistry.stub(:private_key_for, OpenSSL::PKey::EC.generate("secp384r1")) do
      assert OidcClientRegistry.validate_private_key_jwt_configuration!
    end
  end

  test "docs app has no registered auth method and remains confidential" do
    client = OidcClientRegistry.find!("docs_app")

    assert_predicate client.client_secret, :blank?
    assert_nil client.registered_token_endpoint_auth_method
    assert_not_predicate client, :public_client?
    assert_predicate client, :confidential_client?
    assert_equal "client_secret_post", client.metadata_token_endpoint_auth_method
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
      "core-next-rp" => {
        host: ENV.fetch("PUBLIC_CORE_SERVICE_URL", ENV.fetch("PUBLIC_CORE_SERVICE_URL", "jpx.umaxica.app")),
        aud: "core-next-rp",
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

  test "base rails client is registered to base and side redirect hosts" do
    client = OidcClientRegistry.find!("base-rails-rp")
    redirect_hosts = client.redirect_uris.map { |uri| URI.parse(uri).host }

    [
      ENV.fetch("PUBLIC_BASE_SERVICE_URL", ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost")),
      ENV.fetch("PUBLIC_SIDE_SERVICE_URL", ENV.fetch("SIDE_SERVICE_URL", "wide.app.localhost")),
    ].each do |host|
      assert_includes redirect_hosts, host
      assert_includes client.domains, host
    end

    assert client.redirect_uris.all? { |uri| URI.parse(uri).path == "/oidc/callback" }
    assert_equal "base-rails-rp", client.aud
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
