# typed: false
# frozen_string_literal: true

require "test_helper"

class JumpRtDevelopmentIssuerTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "explicit public development identity issues with its dedicated key and published JWKS" do
    saved = ENV.to_h
    key = OpenSSL::PKey::EC.generate("secp384r1")
    production_key = OpenSSL::PKey::EC.generate("secp384r1")
    ENV.update(
      "PUBLIC_JUMP_GATEWAY_URL" => "https://jump.umaxica.net",
      "JUMP_DEVELOPMENT_AUTH_APP_ISSUER_ORIGIN" => "https://auth-development.umaxica.app",
      "JUMP_DEVELOPMENT_AUTH_APP_JWKS_URI" => "https://auth-development.umaxica.app/.well-known/jwks.json",
      "JUMP_DEVELOPMENT_AUTH_APP_RETURN_ORIGIN" => "https://auth-development.umaxica.app",
      "JWT_DEVELOPMENT_AUTH_APP_ACTIVE_KID" => "development-auth-app-es384-a",
      "JWT_DEVELOPMENT_AUTH_APP_PRIVATE_KEY" => key.to_pem,
      "JWT_DEVELOPMENT_AUTH_APP_PUBLIC_KEYSET" => JSON.generate(keys: [
        JitSecurityJwtJwk.export_public(key, kid: "development-auth-app-es384-a"),
      ]),
      "JUMP_DEVELOPMENT_AUTH_APP_PRODUCTION_PUBLIC_KEYSET" => JSON.generate(keys: [
        JitSecurityJwtJwk.export_public(production_key, kid: "auth-app-es384-prod-a"),
      ]),
    )
    Rails.stub(:env, ActiveSupport::EnvironmentInquirer.new("development")) do
      JitSecurityJwtRegistry.reload!
      token = JumpRtIssuer.call(namespace: "AUTH_APP", url: "https://www.umaxica.app/sign/in")
      record = JitSecurityJwtRegistry.surface("AUTH_APP")
      payload, header = JWT.decode(token, nil, true, algorithms: ["ES384"],
                                 jwks: JWT::JWK::Set.new(record.jwks))
      assert_equal "https://auth-development.umaxica.app", payload.fetch("iss")
      assert_equal "development-auth-app-es384-a", header.fetch("kid")
      assert_equal "https://jump.umaxica.net", payload.fetch("aud")
      assert_equal "https://www.umaxica.app/sign/in", payload.fetch("url")
      assert JumpRtReturnPolicy.allowed_source?(destination_origin: "https://www.umaxica.app",
                                               source: "https://auth-development.umaxica.app")
      assert JumpRtReturnPolicy.allowed_source?(destination_origin: "https://auth-development.umaxica.app",
                                               source: "https://www.umaxica.app")
      assert_not JumpRtReturnPolicy.allowed_source?(destination_origin: "https://jp.umaxica.app",
                                                   source: "https://auth-development.umaxica.app")
      assert_not JumpRtReturnPolicy.allowed_source?(destination_origin: "https://auth-development.umaxica.app",
                                                   source: "https://auth-development.umaxica.app")
      boot = Rails.configuration.x.boot_config
      gateway = boot.fetch(:jump)
      [gateway.with(audience: "https://other.umaxica.net"),
       gateway.with(jwks_uri: "https://other.umaxica.net/.well-known/jwks.json")].each do |invalid|
        Rails.configuration.x.stub(:boot_config, boot.merge(jump: invalid)) do
          assert_raises(JumpRtConfigurationError) do
            JumpRtIssuer.call(namespace: "AUTH_APP", url: "https://www.umaxica.app/sign/in")
          end
        end
      end
      assert_nil JumpRtIssuer.call(namespace: "AUTH_APP", url: "https://base.app.localhost/sign/in")
    end
  ensure
    ENV.replace(saved)
    JitSecurityJwtRegistry.reload!
  end

  test "development issuance rejects each missing or empty required setting" do
    saved = ENV.to_h
    key = OpenSSL::PKey::EC.generate("secp384r1")
    production_key = OpenSSL::PKey::EC.generate("secp384r1")
    ENV.update(
      "PUBLIC_JUMP_GATEWAY_URL" => "https://jump.umaxica.net",
      "JUMP_DEVELOPMENT_AUTH_APP_ISSUER_ORIGIN" => "https://auth-development.umaxica.app",
      "JUMP_DEVELOPMENT_AUTH_APP_JWKS_URI" => "https://auth-development.umaxica.app/.well-known/jwks.json",
      "JUMP_DEVELOPMENT_AUTH_APP_RETURN_ORIGIN" => "https://auth-development.umaxica.app",
      "JWT_DEVELOPMENT_AUTH_APP_ACTIVE_KID" => "development-auth-app-es384-a",
      "JWT_DEVELOPMENT_AUTH_APP_PRIVATE_KEY" => key.to_pem,
      "JWT_DEVELOPMENT_AUTH_APP_PUBLIC_KEYSET" => JSON.generate(keys: [
        JitSecurityJwtJwk.export_public(key, kid: "development-auth-app-es384-a"),
      ]),
      "JUMP_DEVELOPMENT_AUTH_APP_PRODUCTION_PUBLIC_KEYSET" => JSON.generate(keys: [
        JitSecurityJwtJwk.export_public(production_key, kid: "auth-app-es384-prod-a"),
      ]),
    )
    names = %w(
      PUBLIC_JUMP_GATEWAY_URL
      JUMP_DEVELOPMENT_AUTH_APP_ISSUER_ORIGIN JUMP_DEVELOPMENT_AUTH_APP_JWKS_URI
      JUMP_DEVELOPMENT_AUTH_APP_RETURN_ORIGIN JWT_DEVELOPMENT_AUTH_APP_ACTIVE_KID
      JWT_DEVELOPMENT_AUTH_APP_PRIVATE_KEY JWT_DEVELOPMENT_AUTH_APP_PUBLIC_KEYSET
      JUMP_DEVELOPMENT_AUTH_APP_PRODUCTION_PUBLIC_KEYSET
    )
    Rails.stub(:env, ActiveSupport::EnvironmentInquirer.new("development")) do
      names.each do |name|
        configured = ENV.fetch(name)
        [nil, ""].each do |missing|
          missing.nil? ? ENV.delete(name) : ENV[name] = missing
          assert_raises(JitSecurityJwtRegistry::ConfigurationError, name) do
            JitSecurityJwtRegistry.reload!
          end
        end
        ENV[name] = configured
      end
    end
  ensure
    ENV.replace(saved)
    JitSecurityJwtRegistry.reload!
  end

  test "development cannot claim production stale or private origins" do
    saved = ENV.to_h
    key = OpenSSL::PKey::EC.generate("secp384r1")
    production_key = OpenSSL::PKey::EC.generate("secp384r1")
    ENV.update(
      "PUBLIC_JUMP_GATEWAY_URL" => "https://jump.umaxica.net",
      "JUMP_DEVELOPMENT_AUTH_APP_ISSUER_ORIGIN" => "https://auth-development.umaxica.app",
      "JUMP_DEVELOPMENT_AUTH_APP_JWKS_URI" => "https://auth-development.umaxica.app/.well-known/jwks.json",
      "JUMP_DEVELOPMENT_AUTH_APP_RETURN_ORIGIN" => "https://auth-development.umaxica.app",
      "JWT_DEVELOPMENT_AUTH_APP_ACTIVE_KID" => "development-auth-app-es384-a",
      "JWT_DEVELOPMENT_AUTH_APP_PRIVATE_KEY" => key.to_pem,
      "JWT_DEVELOPMENT_AUTH_APP_PUBLIC_KEYSET" => JSON.generate(keys: [
        JitSecurityJwtJwk.export_public(key, kid: "development-auth-app-es384-a"),
      ]),
      "JUMP_DEVELOPMENT_AUTH_APP_PRODUCTION_PUBLIC_KEYSET" => JSON.generate(keys: [
        JitSecurityJwtJwk.export_public(production_key, kid: "auth-app-es384-prod-a"),
      ]),
    )
    Rails.stub(:env, ActiveSupport::EnvironmentInquirer.new("development")) do
      %w(
        https://auth.umaxica.app https://www.umaxica.app https://jp.umaxica.app
        https://www-jp.umaxica.app https://palm-jp.umaxica.app https://www.jp.umaxica.app
        https://jpx.umaxica.app https://palm.jp.umaxica.app http://auth-development.umaxica.app
        https://localhost https://auth.app.localhost https://auth.internal https://127.0.0.1
        https://10.0.0.1 https://169.254.1.1 https://[::1] https://[fd00::1]
        https://user:password@auth-development.umaxica.app https://auth-development.umaxica.app/path
        https://auth-development.umaxica.app?query=1 https://auth-development.umaxica.app#fragment
        https://auth-development.umaxica.org https://edit.umaxica.org
      ).each do |origin|
        ENV["JUMP_DEVELOPMENT_AUTH_APP_ISSUER_ORIGIN"] = origin
        ENV["JUMP_DEVELOPMENT_AUTH_APP_JWKS_URI"] = "#{origin}/.well-known/jwks.json"
        ENV["JUMP_DEVELOPMENT_AUTH_APP_RETURN_ORIGIN"] = origin
        assert_raises(JitSecurityJwtRegistry::ConfigurationError, origin) do
          JitSecurityJwtRegistry.reload!
        end
      end
    end
  ensure
    ENV.replace(saved)
    JitSecurityJwtRegistry.reload!
  end

  test "development rejects JWKS return gateway and production key identity mismatches" do
    saved = ENV.to_h
    key = OpenSSL::PKey::EC.generate("secp384r1")
    production_key = OpenSSL::PKey::EC.generate("secp384r1")
    ENV.update(
      "PUBLIC_JUMP_GATEWAY_URL" => "https://jump.umaxica.net",
      "JUMP_DEVELOPMENT_AUTH_APP_ISSUER_ORIGIN" => "https://auth-development.umaxica.app",
      "JUMP_DEVELOPMENT_AUTH_APP_JWKS_URI" => "https://auth-development.umaxica.app/.well-known/jwks.json",
      "JUMP_DEVELOPMENT_AUTH_APP_RETURN_ORIGIN" => "https://auth-development.umaxica.app",
      "JWT_DEVELOPMENT_AUTH_APP_ACTIVE_KID" => "development-auth-app-es384-a",
      "JWT_DEVELOPMENT_AUTH_APP_PRIVATE_KEY" => key.to_pem,
      "JWT_DEVELOPMENT_AUTH_APP_PUBLIC_KEYSET" => JSON.generate(keys: [
        JitSecurityJwtJwk.export_public(key, kid: "development-auth-app-es384-a"),
      ]),
      "JUMP_DEVELOPMENT_AUTH_APP_PRODUCTION_PUBLIC_KEYSET" => JSON.generate(keys: [
        JitSecurityJwtJwk.export_public(production_key, kid: "auth-app-es384-prod-a"),
      ]),
    )
    Rails.stub(:env, ActiveSupport::EnvironmentInquirer.new("development")) do
      {
        "JUMP_DEVELOPMENT_AUTH_APP_JWKS_URI" => "https://other.umaxica.app/.well-known/jwks.json",
        "JUMP_DEVELOPMENT_AUTH_APP_RETURN_ORIGIN" => "https://other.umaxica.app",
        "PUBLIC_JUMP_GATEWAY_URL" => "https://other.umaxica.net",
        "JWT_DEVELOPMENT_AUTH_APP_ACTIVE_KID" => "auth-app-es384-prod-a",
        "JUMP_DEVELOPMENT_AUTH_APP_PRODUCTION_PUBLIC_KEYSET" => JSON.generate(keys: [
          JitSecurityJwtJwk.export_public(key, kid: "auth-app-es384-prod-a"),
        ]),
        "JWT_DEVELOPMENT_AUTH_APP_PUBLIC_KEYSET" => JSON.generate(keys: []),
      }.each do |name, invalid|
        configured = ENV.fetch(name)
        ENV[name] = invalid
        assert_raises(JitSecurityJwtRegistry::ConfigurationError, name) do
          JitSecurityJwtRegistry.reload!
        end
        ENV[name] = configured
      end
    end
  ensure
    ENV.replace(saved)
    JitSecurityJwtRegistry.reload!
  end
end
