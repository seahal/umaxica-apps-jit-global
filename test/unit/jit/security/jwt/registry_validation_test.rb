# typed: false
# frozen_string_literal: true

require "test_helper"
require "jit_security_jwt_registry"

# The registry refuses malformed configuration by naming what is wrong and where,
# because a JWT issuer that boots with a broken key is a signing outage the first
# request discovers. These pin the validation arms that answer with a
# ConfigurationError rather than letting the bad value through.
module Jit
  module Security
    module Jwt
      class RegistryValidationTest < ActiveSupport::TestCase
        self.fixture_table_names = []

        test "an OIDC client namespace is upcased and an unknown one is refused by name" do
          assert_equal "SIGN_APP", JitSecurityJwtRegistry.send(:normalize_oidc_client_namespace, "sign_app")
          assert_equal "SIGN_APP", JitSecurityJwtRegistry.send(:normalize_oidc_client_namespace, :SIGN_APP)

          error =
            assert_raises(JitSecurityJwtRegistry::ConfigurationError) do
              JitSecurityJwtRegistry.send(:normalize_oidc_client_namespace, "martian_surface")
            end

          assert_match(/martian_surface/, error.message)
        end

        test "an invalid public JWK is refused with the source that produced it" do
          error =
            assert_raises(JitSecurityJwtRegistry::ConfigurationError) do
              JitSecurityJwtRegistry.send(:validate_public_jwk!, { "kty" => "EC" }, source: "auth:auth-kid")
            end

          assert_match(/auth:auth-kid/, error.message)
        end

        test "a surface issuer origin is known for every surface namespace" do
          JitSecurityJwtRegistry::SURFACE_NAMESPACES.each do |namespace|
            origin = JitSecurityJwtRegistry.send(:surface_issuer_origin, namespace)

            assert_match(%r{\Ahttps://}, origin, namespace)
          end

          assert_raises(KeyError) { JitSecurityJwtRegistry.send(:surface_issuer_origin, "MARTIAN_APP") }
        end

        def build_key(kid:, state: "active")
          key = OpenSSL::PKey::EC.generate("secp384r1")
          KeyRecord.new(
            kid: kid,
            private_key: key,
            public_key: key,
            public_jwk: JitSecurityJwtJwk.export_public(key, kid: kid),
            state: state,
          )
        end

        def build_record(current_kid:, keys: nil, revoked_kids: [])
          keys ||= { current_kid => build_key(kid: current_kid) }
          JitSecurityJwtIssuerRecord.new(
            id: "surface:AUTH_APP",
            namespace: "AUTH_APP",
            issuer: "https://auth.umaxica.app",
            audiences: ["umaxica-api"],
            current_kid: current_kid,
            keys: keys,
            revoked_kids: revoked_kids,
          )
        end

        test "the placeholder kid is refused so a fixture key cannot be signed with" do
          error =
            assert_raises(JitSecurityJwtRegistry::ConfigurationError) do
              JitSecurityJwtRegistry.send(:validate_record!, build_record(current_kid: "default"))
            end

          assert_match(/must not be "default"/, error.message)
        end

        test "an active kid with no key behind it is refused by name" do
          record = build_record(current_kid: "auth-2026", keys: { "auth-2025" => build_key(kid: "auth-2025") })

          error =
            assert_raises(JitSecurityJwtRegistry::ConfigurationError) do
              JitSecurityJwtRegistry.send(:validate_record!, record)
            end

          assert_match(/active key "auth-2026" is missing/, error.message)
        end

        # Outside a local environment a kid carrying a dev/test/fixture marker means
        # throwaway signing material is about to be published as deployable, so it is
        # refused whether it is the active kid or merely present in the keyset.
        test "a kid carrying a reserved environment marker is refused away from local" do
          deployed = ActiveSupport::StringInquirer.new("production")

          Rails.stub(:env, deployed) do
            active_marked =
              assert_raises(JitSecurityJwtRegistry::ConfigurationError) do
                JitSecurityJwtRegistry.send(:validate_record!, build_record(current_kid: "auth-test-key"))
              end

            assert_match(/active kid must not contain reserved environment markers/, active_marked.message)

            record =
              build_record(
                current_kid: "auth-2026",
                keys: {
                  "auth-2026" => build_key(kid: "auth-2026"),
                  "auth-test-key" => build_key(kid: "auth-test-key", state: "grace"),
                },
              )
            keyset_marked =
              assert_raises(JitSecurityJwtRegistry::ConfigurationError) do
                JitSecurityJwtRegistry.send(:validate_record!, record)
              end

            assert_match(/auth-test-key must not contain reserved environment markers/, keyset_marked.message)
          end
        end

        # A keyring without audiences must fail validation rather than sign tokens
        # for a guessed localhost audience.
        test "a configured keyring with no audiences is rejected" do
          record = build_record(current_kid: "auth-2026").with(audiences: [])

          error =
            assert_raises(JitSecurityJwtRegistry::ConfigurationError) do
              JitSecurityJwtRegistry.send(:validate_record_metadata!, record)
            end

          assert_match(/audiences are missing/, error.message)
        end

        test "jump gateway audience is required outside local environments" do
          source = Object.new
          source.define_singleton_method(:fetch) { |_key, default = nil| default }

          Rails.stub(:env, ActiveSupport::StringInquirer.new("production")) do
            error =
              assert_raises(JitSecurityJwtRegistry::ConfigurationError) do
                JitSecurityJwtRegistry.send(:jump_gateway_audience, source)
              end

            assert_match(/PUBLIC_JUMP_GATEWAY_URL is required/, error.message)
          end

          assert_equal JitSecurityJwtRegistry::LOCAL_JUMP_GATEWAY_AUDIENCE,
                       JitSecurityJwtRegistry.send(:jump_gateway_audience, source)
        end

        test "auth keyring audiences are the union of the per-resource-type audiences" do
          audiences = JitSecurityJwtRegistry.issuer("auth").audiences

          assert_equal %w(umaxica-api-client umaxica-api-visitor umaxica-api-operator).sort, audiences.sort
        end
      end
    end
  end
end
