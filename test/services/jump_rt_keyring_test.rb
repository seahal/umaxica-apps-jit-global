# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class JumpRtKeyringTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  setup do
    @private_key = OpenSSL::PKey::EC.generate("secp384r1")
  end

  test "delegates active kid and private key lookup to the registry" do
    issuer = Struct.new(:id, :current_kid).new("issuer-id", "kid-123")

    JitSecurityJwtRegistry.stub(:surface, issuer) do
      JitSecurityJwtRegistry.stub(:private_key_for, @private_key) do
        assert_equal "kid-123", JumpRtKeyring.active_kid("AUTH_APP")
        assert_equal @private_key, JumpRtKeyring.private_key("AUTH_APP")
      end
    end
  end

  test "decode_private_key accepts PEM and DER encoded EC keys and rejects invalid input" do
    pem = @private_key.to_pem
    der = Base64.strict_encode64(@private_key.to_der)

    assert_instance_of OpenSSL::PKey::EC, JumpRtKeyring.decode_private_key(pem)
    assert_instance_of OpenSSL::PKey::EC, JumpRtKeyring.decode_private_key(der)
    assert_nil JumpRtKeyring.decode_private_key(nil)
    assert_nil JumpRtKeyring.decode_private_key("")
    assert_nil JumpRtKeyring.decode_private_key("not-a-key")
  end
end
