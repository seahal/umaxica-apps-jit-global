# frozen_string_literal: true

require "test_helper"

class JwtRegistryPublicKeyBoundaryTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "public key lookup returns verification-only keys for active private keysets" do
    %w(auth preference_app preference_com preference_org).each do |issuer_id|
      issuer = JitSecurityJwtRegistry.issuer(issuer_id)
      signing_key = JitSecurityJwtRegistry.private_key_for(issuer_id, issuer.current_kid)
      verification_key = JitSecurityJwtRegistry.public_key_for(issuer_id, issuer.current_kid)

      assert_predicate signing_key, :private?, issuer_id
      assert_not_predicate verification_key, :private?, issuer_id
      token = JWT.encode({ "value" => "boundary" }, signing_key, JitSecurityJwtRegistry::ALGORITHM)
      claims, = JWT.decode(token, verification_key, true, algorithms: [JitSecurityJwtRegistry::ALGORITHM])

      assert_equal "boundary", claims.fetch("value"), issuer_id
    end
  end
end
