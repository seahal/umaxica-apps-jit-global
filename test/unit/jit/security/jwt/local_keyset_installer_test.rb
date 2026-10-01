# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"
require "jit_security_jwt_local_keyset_installer"

module Jit
  module Security
    module Jwt
      class LocalKeysetInstallerTest < ActiveSupport::TestCase
        self.fixture_table_names = []

        setup do
          @store_path = Rails.root.join("tmp/tests/local_jwt_keysets_#{SecureRandom.hex(8)}.json")
          @env_keys = local_jwt_env_keys
          @previous = @env_keys.index_with { |key| ENV[key] }
          @original_issuers = JitSecurityJwtRegistry.instance_variable_get(:@issuers)
          clear_local_jwt_env!
          ENV["PREFERENCE_JWT_AUDIENCES"] = "log.umaxica.app"
        end

        teardown do
          JitSecurityJwtRegistry.instance_variable_set(:@issuers, @original_issuers)
          @previous.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
          FileUtils.rm_f(@store_path)
        end

        test "reinstalling from the same local store keeps preference jwt signatures valid" do
          JitSecurityJwtLocalKeysetInstaller.install!(store_path: @store_path)
          JitSecurityJwtRegistry.reload!

          token = PreferenceToken.encode(
            { "ct" => "dr" },
            host: "log.umaxica.app",
            preference_type: "AppPreference",
            public_id: "pref-public",
            jti: "pref-jti",
          )

          assert_not_nil PreferenceToken.decode(token, host: "log.umaxica.app")

          clear_local_jwt_env!
          ENV["PREFERENCE_JWT_AUDIENCES"] = "log.umaxica.app"
          JitSecurityJwtLocalKeysetInstaller.install!(store_path: @store_path)
          JitSecurityJwtRegistry.reload!

          decoded = PreferenceToken.decode(token, host: "log.umaxica.app")

          assert_not_nil decoded
          assert_equal "pref-public", decoded["public_id"]
          assert_equal "pref-jti", decoded["jti"]
        end

        test "reinstalling keeps surface-scoped preference jwt signatures valid" do
          ENV["PREFERENCE_JWT_AUDIENCES"] = "log.umaxica.org"
          JitSecurityJwtLocalKeysetInstaller.install!(store_path: @store_path)
          JitSecurityJwtRegistry.reload!

          token = PreferenceToken.encode(
            { "ct" => "dr" },
            host: "log.umaxica.org",
            preference_type: "OrgPreference",
            public_id: "org-pref-public",
            jti: "org-pref-jti",
            jwt_issuer_id: "surface:AUTH_ORG",
          )

          assert_not_nil PreferenceToken.decode(
            token,
            host: "log.umaxica.org",
            jwt_issuer_id: "surface:AUTH_ORG",
          )

          clear_local_jwt_env!
          ENV["PREFERENCE_JWT_AUDIENCES"] = "log.umaxica.org"
          JitSecurityJwtLocalKeysetInstaller.install!(store_path: @store_path)
          JitSecurityJwtRegistry.reload!

          decoded = PreferenceToken.decode(
            token,
            host: "log.umaxica.org",
            jwt_issuer_id: "surface:AUTH_ORG",
          )

          assert_not_nil decoded
          assert_equal "org-pref-public", decoded["public_id"]
          assert_equal "org-pref-jti", decoded["jti"]
        end

        test "partial keyset env is repaired from local store as one matching set" do
          JitSecurityJwtLocalKeysetInstaller.install!(store_path: @store_path)
          original_private_keyset = ENV.fetch("PREFERENCE_JWT_PRIVATE_KEYSET")
          original_public_keyset = ENV.fetch("PREFERENCE_JWT_PUBLIC_KEYSET")

          ENV["PREFERENCE_JWT_PRIVATE_KEYSET"] = nil

          JitSecurityJwtLocalKeysetInstaller.install!(store_path: @store_path)

          assert_equal original_private_keyset, ENV["PREFERENCE_JWT_PRIVATE_KEYSET"]
          assert_equal original_public_keyset, ENV["PREFERENCE_JWT_PUBLIC_KEYSET"]
        end

        test "partial surface env is repaired from local store as one matching set" do
          JitSecurityJwtLocalKeysetInstaller.install!(store_path: @store_path)
          original_private_key = ENV.fetch("JWT_AUTH_APP_PRIVATE_KEY")
          original_public_keyset = ENV.fetch("JWT_AUTH_APP_PUBLIC_KEYSET")

          ENV["JWT_AUTH_APP_PRIVATE_KEY"] = nil

          JitSecurityJwtLocalKeysetInstaller.install!(store_path: @store_path)

          assert_equal original_private_key, ENV["JWT_AUTH_APP_PRIVATE_KEY"]
          assert_equal original_public_keyset, ENV["JWT_AUTH_APP_PUBLIC_KEYSET"]
          JitSecurityJwtRegistry.reload!

          assert JitSecurityJwtRegistry.private_key_for("surface:AUTH_APP")
          assert JitSecurityJwtRegistry.public_key_for("surface:AUTH_APP", ENV.fetch("JWT_AUTH_APP_ACTIVE_KID"))
        end

        test "partial oidc client env is repaired from local store as one matching set" do
          JitSecurityJwtLocalKeysetInstaller.install!(store_path: @store_path)
          original_private_key = ENV.fetch("OIDC_CLIENT_ACME_APP_PRIVATE_KEY")
          original_public_keyset = ENV.fetch("OIDC_CLIENT_ACME_APP_PUBLIC_KEYSET")

          ENV["OIDC_CLIENT_ACME_APP_PRIVATE_KEY"] = nil

          JitSecurityJwtLocalKeysetInstaller.install!(store_path: @store_path)

          assert_equal original_private_key, ENV["OIDC_CLIENT_ACME_APP_PRIVATE_KEY"]
          assert_equal original_public_keyset, ENV["OIDC_CLIENT_ACME_APP_PUBLIC_KEYSET"]
          JitSecurityJwtRegistry.reload!

          assert JitSecurityJwtRegistry.private_key_for("oidc_client:ACME_APP")
          assert JitSecurityJwtRegistry.public_key_for(
            "oidc_client:ACME_APP",
            ENV.fetch("OIDC_CLIENT_ACME_APP_ACTIVE_KID"),
          )
        end

        test "install writes all local issuers to ignored tmp store" do
          JitSecurityJwtLocalKeysetInstaller.install!(store_path: @store_path)

          store = JSON.parse(File.read(@store_path))
          expected_keys =
            %w(AUTH PREFERENCE) +
            JitSecurityJwtRegistry::SURFACE_NAMESPACES.map { |namespace| "JWT_#{namespace}" } +
            JitSecurityJwtRegistry::OIDC_CLIENT_NAMESPACES.map { |namespace| "OIDC_CLIENT_#{namespace}" }

          assert_equal expected_keys.sort, store.keys.sort
          assert_equal 0o600, File.stat(@store_path).mode & 0o777
        end

        test "install writes only public jwk material to local public keysets" do
          JitSecurityJwtLocalKeysetInstaller.install!(store_path: @store_path)

          store = JSON.parse(File.read(@store_path))
          public_keysets = [
            JSON.parse(store.fetch("AUTH").fetch("public_keyset")),
            JSON.parse(store.fetch("PREFERENCE").fetch("public_keyset")),
          ]
          JitSecurityJwtRegistry::SURFACE_NAMESPACES.each do |namespace|
            public_keysets << JSON.parse(store.fetch("JWT_#{namespace}").fetch("public_keyset"))
          end
          JitSecurityJwtRegistry::OIDC_CLIENT_NAMESPACES.each do |namespace|
            public_keysets << JSON.parse(store.fetch("OIDC_CLIENT_#{namespace}").fetch("public_keyset"))
          end

          public_keysets.each do |keyset|
            keyset.fetch("keys").each do |jwk|
              assert_empty JitSecurityJwtJwk::PRIVATE_FIELDS & jwk.keys
              assert_equal "ES384", jwk.fetch("alg")
              assert_equal "sig", jwk.fetch("use")
            end
          end
        end

        test "malformed local store is regenerated into usable keys" do
          FileUtils.mkdir_p(File.dirname(@store_path))
          File.write(@store_path, "not-json")

          logged = []
          Rails.logger.stub(:warn, ->(message) { logged << message }) do
            JitSecurityJwtLocalKeysetInstaller.install!(store_path: @store_path)
          end
          JitSecurityJwtRegistry.reload!

          assert(logged.any? { |message| message.include?("jwt.local_keyset_store.malformed") })
          assert JitSecurityJwtRegistry.private_key_for("preference")
          assert JitSecurityJwtRegistry.public_key_for("preference", ENV.fetch("PREFERENCE_JWT_ACTIVE_KID"))
        end

        test "generating fresh local keys warns that prior tokens will fail verification" do
          warnings = []
          Rails.logger.stub(:warn, ->(message) { warnings << message }) do
            JitSecurityJwtLocalKeysetInstaller.install!(store_path: @store_path)
          end

          regenerated = warnings.select { |message| message.include?("jwt.local_keyset.regenerated") }

          assert_predicate regenerated, :present?,
                           "first install with no store should warn that local keys were minted"
          assert(regenerated.any? { |message| message.include?("PREFERENCE") })
          assert(regenerated.all? { |message| message.include?("will fail verification") })
        end

        test "reinstalling from an existing store does not warn about regeneration" do
          JitSecurityJwtLocalKeysetInstaller.install!(store_path: @store_path)

          clear_local_jwt_env!
          ENV["PREFERENCE_JWT_AUDIENCES"] = "log.umaxica.app"

          warnings = []
          Rails.logger.stub(:warn, ->(message) { warnings << message }) do
            JitSecurityJwtLocalKeysetInstaller.install!(store_path: @store_path)
          end

          assert_empty warnings.select { |message| message.include?("jwt.local_keyset.regenerated") },
                       "reusing persisted keys must not look like a key rotation"
        end

        test "explicit local jwt env values are not replaced" do
          ENV["PREFERENCE_JWT_ACTIVE_KID"] = "explicit-pref-kid"
          ENV["PREFERENCE_JWT_PRIVATE_KEYSET"] = '{"explicit-pref-kid":"private"}'
          ENV["PREFERENCE_JWT_PUBLIC_KEYSET"] = '{"keys":[]}'

          JitSecurityJwtLocalKeysetInstaller.install!(store_path: @store_path)

          assert_equal "explicit-pref-kid", ENV["PREFERENCE_JWT_ACTIVE_KID"]
          assert_equal '{"explicit-pref-kid":"private"}', ENV["PREFERENCE_JWT_PRIVATE_KEYSET"]
          assert_equal '{"keys":[]}', ENV["PREFERENCE_JWT_PUBLIC_KEYSET"]
        end

        private

        def clear_local_jwt_env!
          @env_keys.each { |key| ENV.delete(key) }
        end

        def local_jwt_env_keys
          keys = %w(
            AUTH_JWT_ACTIVE_KID AUTH_JWT_PRIVATE_KEYSET AUTH_JWT_PUBLIC_KEYSET
            PREFERENCE_JWT_ACTIVE_KID PREFERENCE_JWT_PRIVATE_KEYSET PREFERENCE_JWT_PUBLIC_KEYSET
            PREFERENCE_JWT_AUDIENCES
          )
          JitSecurityJwtRegistry::SURFACE_NAMESPACES.each do |namespace|
            keys << "JWT_#{namespace}_ACTIVE_KID"
            keys << "JWT_#{namespace}_PRIVATE_KEY"
            keys << "JWT_#{namespace}_PUBLIC_KEYSET"
          end
          JitSecurityJwtRegistry::OIDC_CLIENT_NAMESPACES.each do |namespace|
            keys << "OIDC_CLIENT_#{namespace}_ACTIVE_KID"
            keys << "OIDC_CLIENT_#{namespace}_PRIVATE_KEY"
            keys << "OIDC_CLIENT_#{namespace}_PUBLIC_KEYSET"
          end
          keys
        end
      end
    end
  end
end
