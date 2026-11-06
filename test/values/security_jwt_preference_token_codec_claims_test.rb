# typed: false
# frozen_string_literal: true

require "test_helper"
require "openssl"

class SecurityJwtPreferenceTokenCodecClaimsTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  PREFERENCES = {
    "theme" => "dark",
    "language" => "ja",
    "timezone" => "Asia/Tokyo",
    "currency" => "jpy",
    "date_format" => "iso",
    "time_format" => "24",
    "motion" => "standard",
    "density" => "standard",
    "page_size" => "infinity",
  }.freeze

  test "a genuine app realm token carries only the current closed claims" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    public_id = PublicId.generate
    token = PreferenceToken.encode(
      PREFERENCES, host: host, preference_type: "AppPreference", public_id: public_id,
                   jti: SecureRandom.uuid, jwt_issuer_id: "preference_app", issued_at: Time.current,
    )
    claims, header = JWT.decode(token, nil, false)

    assert_equal "JWT", header.fetch("typ")
    assert_equal "ES384", header.fetch("alg")
    assert_equal %w(aud exp iat iss jti preferences sub), claims.keys.sort
    assert_equal "app", claims.fetch("aud")
    assert_equal public_id, claims.fetch("sub")
    assert_equal PREFERENCES, claims.fetch("preferences")
    assert_operator token.bytesize, :<=, SecurityJwtPreferenceTokenCodec::ANONYMOUS_REALM_TOKEN_MAX_BYTES
    assert_equal claims, PreferenceToken.decode(token, host: host, jwt_issuer_id: "preference_app")
    assert_equal public_id, PreferenceToken.extract_public_id(claims)
    assert_nil PreferenceToken.extract_public_id({ "public_id" => "retired-row-id" })
  end

  test "legacy app and org claim shapes have no reader" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    token = PreferenceToken.encode(
      PREFERENCES, host: host, preference_type: "AppPreference", public_id: "app-row-id",
                   jti: "app-generation", jwt_issuer_id: "preference_app", issued_at: Time.current,
    )
    claims, header = JWT.decode(token, nil, false)
    key = JitSecurityJwtRegistry.private_key_for("preference_app", header.fetch("kid"))
    old_claim_shapes = [
      claims.merge("preference_type" => "AppPreference"),
      claims.merge("client_id" => "legacy-client"),
      claims.merge("scope" => "preference"),
      claims.merge("public_id" => "legacy-row-id"),
    ]

    old_claim_shapes.each do |old_claims|
      legacy_token = JWT.encode(old_claims, key, header.fetch("alg"), header.except("alg"))

      assert_nil PreferenceToken.decode(legacy_token, host: host, jwt_issuer_id: "preference_app")
    end
  end

  test "a token signed by another realm key is reported as a signature failure" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    token = PreferenceToken.encode(
      PREFERENCES, host: host, preference_type: "AppPreference", public_id: "app-row-id",
                   jti: "app-generation", jwt_issuer_id: "preference_app", issued_at: Time.current,
    )
    claims, header = JWT.decode(token, nil, false)
    forged = JWT.encode(
      claims, OpenSSL::PKey::EC.generate("secp384r1"), header.fetch("alg"), header.except("alg"),
    )
    reported_reasons = []

    JitSecurityJwtAnomalyReporter.stub(:report_preference, ->(**event) { reported_reasons << event.fetch(:reason) }) do
      assert_nil PreferenceToken.decode(forged, host: host, jwt_issuer_id: "preference_app")
    end

    assert_includes reported_reasons, "SIGNATURE_INVALID"
  end
end
