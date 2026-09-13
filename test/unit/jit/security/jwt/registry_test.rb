# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"
require "jit_security_jwt_registry"

module Jit
  module Security
    module Jwt
      class RegistryTest < ActiveSupport::TestCase
        self.fixture_table_names = []

        setup do
          @original_issuers = JitSecurityJwtRegistry.instance_variable_get(:@issuers)
          @auth_key = OpenSSL::PKey::EC.generate("secp384r1")
          @auth_legacy_key = OpenSSL::PKey::EC.generate("secp384r1")
          @preference_key = OpenSSL::PKey::EC.generate("secp384r1")
          @preference_legacy_key = OpenSSL::PKey::EC.generate("secp384r1")
          @surface_key = OpenSSL::PKey::EC.generate("secp384r1")
        end

        teardown do
          JitSecurityJwtRegistry.instance_variable_set(:@issuers, @original_issuers)
        end

        test "loads configured keys once into immutable issuer records" do
          with_registry_inputs do
            issuers = JitSecurityJwtRegistry.reload!

            assert_equal "auth-kid", issuers.fetch("auth").current_kid
            assert_equal %w(umaxica-api-client umaxica-api-visitor umaxica-api-operator),
                         issuers.fetch("auth").audiences
            assert_equal "pref-kid", issuers.fetch("preference").current_kid
            assert_equal(
              Rails.configuration.x.boot_config.fetch(:hosts).base_origins.map(&:to_s),
              issuers.fetch("preference").audiences,
            )
            assert_equal "sign-app-kid", issuers.fetch("surface:SIGN_APP").current_kid
            assert_predicate issuers.fetch("surface:SIGN_APP").jwks.fetch(:keys), :present?
            assert_equal 12, issuers.keys.grep(/\Aoidc_client:/).size
            assert JitSecurityJwtRegistry.public_key_for("auth", "auth-legacy-kid")
            assert JitSecurityJwtRegistry.public_key_for("preference", "pref-legacy-kid")
          end
        end

        test "loads configured Base OIDC client assertion issuer" do
          with_registry_inputs(
            "OIDC_CLIENT_BASE_APP_ACTIVE_KID" => "oidc-base-app-kid",
            "OIDC_CLIENT_BASE_APP_PRIVATE_KEY" => base64_der(@surface_key),
          ) do
            issuers = JitSecurityJwtRegistry.reload!
            issuer = issuers.fetch("oidc_client:BASE_APP")

            assert_equal "oidc-base-app-kid", issuer.current_kid
            assert_equal "oidc_client:base_app", issuer.issuer
            assert_predicate issuer.jwks.fetch(:keys), :present?
          end
        end

        test "namespace-less jwks includes auth active and grace public keys" do
          with_registry_inputs do
            JitSecurityJwtRegistry.reload!

            kids = JitSecurityJwtJwksService.jwk_set.fetch(:keys).map { |jwk| jwk.fetch("kid") }

            assert_includes kids, "auth-kid"
            assert_includes kids, "auth-legacy-kid"
          end
        end

        test "grace public key verifies old tokens without retaining old private key" do
          with_registry_inputs do
            JitSecurityJwtRegistry.reload!

            token = JWT.encode(
              {
                "iss" => "issuer",
                "aud" => "audience",
                "sub" => "subject",
                "exp" => 5.minutes.from_now.to_i,
                "iat" => Time.current.to_i,
              },
              @auth_legacy_key,
              JitSecurityJwtRegistry::ALGORITHM,
              { kid: "auth-legacy-kid", typ: "auth-access-token;client" },
            )

            public_key = JitSecurityJwtRegistry.public_key_for("auth", "auth-legacy-kid")

            assert_nil JitSecurityJwtRegistry.private_key_for("auth", "auth-legacy-kid")
            assert_not_nil public_key
            assert_nothing_raised do
              JWT.decode(token, public_key, true, algorithms: [JitSecurityJwtRegistry::ALGORITHM])
            end
          end
        end

        test "jwks never exposes private key material" do
          with_registry_inputs do
            JitSecurityJwtRegistry.reload!

            JitSecurityJwtRegistry.jwks_for("auth").fetch(:keys).each do |jwk|
              assert_empty JitSecurityJwtRegistry::PRIVATE_JWK_FIELDS & jwk.keys
              assert_equal JitSecurityJwtRegistry::ALGORITHM, jwk.fetch("alg")
              assert_equal "sig", jwk.fetch("use")
              assert_equal "EC", jwk.fetch("kty")
              assert_equal JitSecurityJwtRegistry::CURVE, jwk.fetch("crv")
            end
          end
        end

        test "rejects malformed public jwk json at registry load" do
          with_registry_inputs("JWT_SIGN_APP_PUBLIC_KEYSET" => "not-json") do
            error = assert_raises(JitSecurityJwtRegistry::ConfigurationError) { JitSecurityJwtRegistry.reload! }

            assert_match(/JWT_SIGN_APP_PUBLIC_KEYSET contains invalid JSON/, error.message)
          end
        end

        test "rejects current public jwk that does not match current private key" do
          wrong_key = OpenSSL::PKey::EC.generate("secp384r1")
          wrong_jwk = JitSecurityJwtRegistry.export_public_jwk(wrong_key, kid: "sign-app-kid")

          with_registry_inputs("JWT_SIGN_APP_PUBLIC_KEYSET" => JSON.generate([wrong_jwk])) do
            error = assert_raises(JitSecurityJwtRegistry::ConfigurationError) { JitSecurityJwtRegistry.reload! }

            assert_match(/active public JWK does not match active private key/, error.message)
          end
        end

        test "does not expose revoked kids in jwks and refuses their public keys" do
          with_registry_inputs("JWT_SIGN_APP_REVOKED_KIDS" => "legacy-kid") do
            JitSecurityJwtRegistry.reload!

            assert_nil JitSecurityJwtRegistry.public_key_for("surface:SIGN_APP", "legacy-kid")
            kids = JitSecurityJwtRegistry.jwks_for("surface:SIGN_APP").fetch(:keys).map { |jwk| jwk.fetch("kid") }

            assert_not_includes kids, "legacy-kid"
          end
        end

        test "rejects duplicate non-default kids across issuers" do
          with_registry_inputs("PREFERENCE_JWT_ACTIVE_KID" => "auth-kid") do
            error = assert_raises(JitSecurityJwtRegistry::ConfigurationError) { JitSecurityJwtRegistry.reload! }

            assert_match(/duplicate JWT kid/, error.message)
          end
        end

        test "rejects default active kid unless explicitly allowed" do
          with_registry_inputs(
            "AUTH_JWT_ACTIVE_KID" => "default",
            "JWT_ALLOW_INSECURE_DEFAULT_KID" => nil,
          ) do
            error = assert_raises(JitSecurityJwtRegistry::ConfigurationError) { JitSecurityJwtRegistry.reload! }

            assert_match(/active kid must not be "default"/, error.message)
          end
        end

        test "rejects reserved environment kid markers outside local environments" do
          Rails.env.stub(:local?, false) do
            with_registry_inputs("AUTH_JWT_ACTIVE_KID" => "development-auth-es384-a") do
              error = assert_raises(JitSecurityJwtRegistry::ConfigurationError) { JitSecurityJwtRegistry.reload! }

              assert_match(/reserved environment markers/, error.message)
            end
          end
        end

        test "allows reserved environment kid markers in local environments" do
          with_registry_inputs("AUTH_JWT_ACTIVE_KID" => "development-auth-es384-a") do
            assert_nothing_raised { JitSecurityJwtRegistry.reload! }
          end
        end

        test "rejects unknown issuer and namespace identifiers" do
          with_registry_inputs do
            JitSecurityJwtRegistry.reload!

            unknown_issuer =
              assert_raises(JitSecurityJwtRegistry::ConfigurationError) do
                JitSecurityJwtRegistry.issuer("missing")
              end
            assert_match(/unknown JWT issuer registry id/, unknown_issuer.message)

            unsupported_surface =
              assert_raises(JitSecurityJwtRegistry::ConfigurationError) do
                JitSecurityJwtRegistry.surface("missing")
              end
            assert_match(/unsupported JWT issuer namespace/, unsupported_surface.message)

            unsupported_client =
              assert_raises(JitSecurityJwtRegistry::ConfigurationError) do
                JitSecurityJwtRegistry.oidc_client("missing")
              end
            assert_match(/unsupported OIDC client JWT namespace/, unsupported_client.message)
          end
        end

        test "does not allow insecure default kid outside local environments" do
          with_registry_inputs(
            "AUTH_JWT_ACTIVE_KID" => "default",
            "JWT_ALLOW_INSECURE_DEFAULT_KID" => "1",
          ) do
            Rails.env.stub(:local?, false) do
              error = assert_raises(JitSecurityJwtRegistry::ConfigurationError) { JitSecurityJwtRegistry.reload! }

              assert_match(/active kid must not be "default"/, error.message)
            end
          end
        end

        test "rejects non-empty records without issuer" do
          record = issuer_record(issuer: nil)

          error = assert_raises(JitSecurityJwtRegistry::ConfigurationError) { JitSecurityJwtRegistry.validate_record!(record) }

          assert_match(/auth issuer is missing/, error.message)
        end

        test "rejects non-empty records without audiences" do
          record = issuer_record(audiences: [])

          error = assert_raises(JitSecurityJwtRegistry::ConfigurationError) { JitSecurityJwtRegistry.validate_record!(record) }

          assert_match(/auth audiences are missing/, error.message)
        end

        test "allows empty optional surface records without issuer or audiences" do
          record = JitSecurityJwtIssuerRecord.new(
            id: "surface:BASE_APP",
            namespace: "BASE_APP",
            issuer: nil,
            audiences: [],
            current_kid: nil,
            keys: {},
            revoked_kids: Set.new,
          )

          assert_nothing_raised { JitSecurityJwtRegistry.validate_record!(record) }
        end

        test "rejects records whose active key is not published in jwks" do
          record = issuer_record(
            key_state: "retired",
          )

          error = assert_raises(JitSecurityJwtRegistry::ConfigurationError) { JitSecurityJwtRegistry.validate_record!(record) }

          assert_match(/active key "auth-kid" is missing from JWKS/, error.message)
        end

        test "does not retain invalid registry after failed reload" do
          with_registry_inputs do
            valid_records = JitSecurityJwtRegistry.reload!

            with_env("JWT_SIGN_APP_PUBLIC_KEYSET" => "not-json") do
              assert_raises(JitSecurityJwtRegistry::ConfigurationError) { JitSecurityJwtRegistry.reload! }
            end

            assert_same valid_records, JitSecurityJwtRegistry.instance_variable_get(:@issuers)
          end
        end

        private

        def issuer_record(issuer: "issuer", audiences: ["audience"], key_state: "active")
          JitSecurityJwtIssuerRecord.new(
            id: "auth",
            namespace: "AUTH",
            issuer: issuer,
            audiences: audiences,
            current_kid: "auth-kid",
            keys: {
              "auth-kid" => KeyRecord.new(
                kid: "auth-kid",
                private_key: @auth_key,
                public_key: @auth_key,
                public_jwk: JitSecurityJwtRegistry.export_public_jwk(@auth_key, kid: "auth-kid"),
                state: key_state,
              ),
            },
            revoked_kids: Set.new,
          )
        end

        def with_registry_inputs(extra_env = {})
          env = registry_input_env(extra_env)
          creds = registry_input_creds(env)
          with_env(env) do
            Rails.app.creds.stub(:option, ->(key, default: nil) { creds.fetch(key, default) }) do
              yield
            end
          end
        end

        def registry_input_env(extra_env)
          legacy_jwk = JitSecurityJwtRegistry.export_public_jwk(
            OpenSSL::PKey::EC.generate("secp384r1"),
            kid: "legacy-kid",
          )
          env = {
            "AUTH_JWT_ACTIVE_KID" => "auth-kid",
            "AUTH_JWT_ISSUER" => "auth-test-issuer",
            "PREFERENCE_JWT_ACTIVE_KID" => "pref-kid",
            "PREFERENCE_JWT_ISSUER" => "preference-test-issuer",
            "JWT_SIGN_APP_ACTIVE_KID" => "sign-app-kid",
            "JWT_SIGN_APP_PUBLIC_KEYSET" => JSON.generate([legacy_jwk]),
          }.merge(extra_env)
          clear_unused_registry_namespace_env(env)
          env["AUTH_JWT_PRIVATE_KEYSET"] =
            JSON.generate((env["AUTH_JWT_ACTIVE_KID"] || "auth-kid") => base64_der(@auth_key))
          env["AUTH_JWT_PUBLIC_KEYSET"] =
            JSON.generate(keys: [JitSecurityJwtRegistry.export_public_jwk(@auth_legacy_key, kid: "auth-legacy-kid")])
          env["PREFERENCE_JWT_PRIVATE_KEYSET"] =
            JSON.generate((env["PREFERENCE_JWT_ACTIVE_KID"] || "pref-kid") => base64_der(@preference_key))
          env["PREFERENCE_JWT_PUBLIC_KEYSET"] =
            JSON.generate(
              keys: [JitSecurityJwtRegistry.export_public_jwk(@preference_legacy_key, kid: "pref-legacy-kid")],
            )
          env
        end

        def clear_unused_registry_namespace_env(env)
          JitSecurityJwtRegistry::SURFACE_NAMESPACES.each do |namespace|
            next if namespace == "SIGN_APP"

            env["JWT_#{namespace}_ACTIVE_KID"] = nil
            env["JWT_#{namespace}_PUBLIC_KEYSET"] = nil
            env["JWT_#{namespace}_REVOKED_KIDS"] = nil
          end
          JitSecurityJwtRegistry::OIDC_CLIENT_NAMESPACES.each do |namespace|
            next if env.key?("OIDC_CLIENT_#{namespace}_ACTIVE_KID")

            env["OIDC_CLIENT_#{namespace}_ACTIVE_KID"] = nil
            env["OIDC_CLIENT_#{namespace}_PUBLIC_KEYSET"] = nil
            env["OIDC_CLIENT_#{namespace}_REVOKED_KIDS"] = nil
          end
        end

        def registry_input_creds(env)
          {
            :AUTH_JWT_PRIVATE_KEYSET => JSON.generate(
              (env["AUTH_JWT_ACTIVE_KID"] || "auth-kid") => base64_der(@auth_key),
            ),
            :AUTH_JWT_PUBLIC_KEYSET => JSON.generate(
              keys: [JitSecurityJwtRegistry.export_public_jwk(@auth_legacy_key, kid: "auth-legacy-kid")],
            ),
            :PREFERENCE_JWT_PRIVATE_KEYSET => JSON.generate(
              (env["PREFERENCE_JWT_ACTIVE_KID"] || "pref-kid") => base64_der(@preference_key),
            ),
            :PREFERENCE_JWT_PUBLIC_KEYSET => JSON.generate(
              keys: [JitSecurityJwtRegistry.export_public_jwk(@preference_legacy_key, kid: "pref-legacy-kid")],
            ),
            "JWT_SIGN_APP_PRIVATE_KEY" => base64_der(@surface_key),
          }
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

        def base64_der(key)
          Base64.strict_encode64(key.to_der)
        end
      end
    end
  end
end
