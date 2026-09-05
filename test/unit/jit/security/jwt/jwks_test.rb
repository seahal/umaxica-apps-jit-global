# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"
require "jit_security_jwt_jwks"

module Jit
  module Security
    module Jwt
      class JwksTest < ActiveSupport::TestCase
        self.fixture_table_names = []

        setup do
          @key = OpenSSL::PKey::EC.generate("secp384r1")
          @public_jwk = JitSecurityJwtJwk.export_public(@key, kid: "kid-1")
        end

        test "parses jwk set objects" do
          parsed = JitSecurityJwtJwks.parse_public_collection(JSON.generate(keys: [@public_jwk]))

          assert_equal @public_jwk, parsed.fetch("kid-1")
        end

        test "parses jwk arrays" do
          parsed = JitSecurityJwtJwks.parse_public_collection(JSON.generate([@public_jwk]))

          assert_equal @public_jwk, parsed.fetch("kid-1")
        end

        test "rejects jwk set objects without keys array" do
          error =
            assert_raises(JitSecurityJwtJwks::Error) do
              JitSecurityJwtJwks.parse_public_collection(JSON.generate(keys: {}))
            end

          assert_match(/keys array/, error.message)
        end

        # Valid JSON that is neither of the two shapes a JWK Set may take. Answering with an empty
        # key collection instead of raising would leave a caller verifying signatures against no
        # keys at all, which fails open on the next configuration typo.
        test "rejects json that parses but is neither a jwk set object nor an array" do
          ["123", '"kid-1"', "true", "null"].each do |raw|
            error =
              assert_raises(JitSecurityJwtJwks::Error, "#{raw} must be refused") do
                JitSecurityJwtJwks.parse_public_collection(raw)
              end

            assert_equal "must be a JWK Set JSON object or array", error.message
          end
        end

        test "rejects invalid json" do
          error =
            assert_raises(JitSecurityJwtJwks::Error) do
              JitSecurityJwtJwks.parse_public_collection("{")
            end

          assert_match(/invalid JSON/, error.message)
        end

        test "rejects private material in collection" do
          error =
            assert_raises(JitSecurityJwtJwks::Error) do
              JitSecurityJwtJwks.parse_public_collection(JSON.generate(keys: [@public_jwk.merge("d" => "secret")]))
            end

          assert_match(/private JWK material/, error.message)
        end
      end
    end
  end
end
