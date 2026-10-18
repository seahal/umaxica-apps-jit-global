# typed: false
# frozen_string_literal: true

require "test_helper"

class PreferenceJwtTest < ActiveSupport::TestCase
  test "parse_header rescues DecodeError" do
    assert_equal({}, PreferenceJwtConfiguration.parse_header("invalid.token.format"))
  end

  test "private_key returns nil if not active" do
    PreferenceJwtConfiguration.stub(:active_kid, "non_existent") do
      assert_nil PreferenceJwtConfiguration.private_key
    end
  end

  test "Token.encode returns nil on error" do
    PreferenceJwtConfiguration.stub(:private_key_for_active, nil) do
      assert_nil PreferenceToken.encode({}, host: "host", preference_type: "type", public_id: "id", jti: "jti")
    end
  end

  test "Token.decode returns nil for expired token" do
    payload = {
      preferences: {},
      host: "host",
      preference_type: "type",
      public_id: "id",
      jti: "jti",
      typ: PreferenceToken::TOKEN_TYPE,
      iss: PreferenceJwtConfiguration.issuer,
      aud: PreferenceJwtConfiguration.audience_for("host"),
      iat: 1.day.ago.to_i,
      exp: 1.hour.ago.to_i,
    }
    key = OpenSSL::PKey::EC.generate("secp384r1")
    token = JWT.encode(
      payload, key, PreferenceToken::JWT_ALGORITHM,
      { kid: "default", typ: PreferenceToken::TOKEN_TYPE },
    )

    PreferenceJwtConfiguration.stub(:public_key_for, key) do
      assert_nil PreferenceToken.decode(token, host: "host")
    end
  end
end
