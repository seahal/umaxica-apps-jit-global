# typed: false
# frozen_string_literal: true

require "test_helper"

# The preference token's signature proves only that this service issued it. The claims then bind it
# to one host scope, audience, preference row and subject. Each case re-signs a genuine token with
# one claim changed, so a refusal can only come from the claim check itself, and the anomaly
# report names the reason an operator would see.
class SecurityJwtPreferenceTokenCodecClaimsTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "a genuine token decodes" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    token = SecurityJwtPreferenceTokenCodec.encode(
      { "lx" => "ja" },
      host: host, preference_type: "AppPreference", public_id: "pref-public-id", jti: SecureRandom.uuid,
    )

    payload = SecurityJwtPreferenceTokenCodec.decode(token, host: host)

    assert_equal "pref-public-id", SecurityJwtPreferenceTokenCodec.extract_public_id(payload)
    assert_equal "AppPreference", SecurityJwtPreferenceTokenCodec.extract_preference_type(payload)
  end

  test "a re-signed token with one binding claim changed is refused" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    genuine = SecurityJwtPreferenceTokenCodec.encode(
      { "lx" => "ja" },
      host: host, preference_type: "AppPreference", public_id: "pref-public-id", jti: SecureRandom.uuid,
    )
    claims, header = JWT.decode(genuine, nil, false)
    key = PreferenceJwtConfiguration.private_key_for_active
    changes = {
      "audience naming another host scope" => [{ "aud" => ["other.example.test"] }, "AUD_MISMATCH"],
      "audience given as a non-string, non-list value" => [{ "aud" => 42 }, nil],
      "missing preference row id" => [{ "public_id" => "" }, "OTHER"],
      "non-string preference row id" => [{ "public_id" => 7 }, nil],
      "missing preference type" => [{ "preference_type" => nil }, "OTHER"],
      "subject naming another preference row" => [{ "sub" => "someone-else" }, "OTHER"],
      "host claim of another scope" => [{ "host" => "evil.example.test" }, "HOST_MISMATCH"],
      "non-string host claim" => [{ "host" => 1 }, nil],
    }

    changes.each do |label, (change, expected_reason)|
      tampered = JWT.encode(claims.merge(change), key, header.fetch("alg"), header.except("alg"))
      reasons = []

      JitSecurityJwtAnomalyReporter.stub(:report_preference, ->(**kwargs) { reasons << kwargs[:reason] }) do
        assert_nil SecurityJwtPreferenceTokenCodec.decode(tampered, host: host), label
      end
      assert_includes reasons, expected_reason, label if expected_reason
    end
  end

  test "a token signed by another key is reported as a signature failure" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    genuine = SecurityJwtPreferenceTokenCodec.encode(
      { "lx" => "ja" },
      host: host, preference_type: "AppPreference", public_id: "pref-public-id", jti: SecureRandom.uuid,
    )
    claims, header = JWT.decode(genuine, nil, false)
    forged = JWT.encode(claims, OpenSSL::PKey::EC.generate("secp384r1"), header.fetch("alg"), header.except("alg"))
    reasons = []

    JitSecurityJwtAnomalyReporter.stub(:report_preference, ->(**kwargs) { reasons << kwargs[:reason] }) do
      assert_nil SecurityJwtPreferenceTokenCodec.decode(forged, host: host)
      assert_nil SecurityJwtPreferenceTokenCodec.decode("#{genuine.split(".").first(2).join(".")}.%%%", host: host)
    end

    assert_includes reasons, "SIGNATURE_INVALID"
  end
end
