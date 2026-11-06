# typed: false
# frozen_string_literal: true

require "test_helper"

class PreferenceTokenAudienceMismatchTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "wrong realm audience is refused and strict writers receive an audience error" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    preferences = {
      "theme" => "dark",
      "language" => "ja",
      "timezone" => "Asia/Tokyo",
      "currency" => "jpy",
      "date_format" => "iso",
      "time_format" => "24",
      "motion" => "standard",
      "density" => "standard",
      "page_size" => "infinity",
    }
    token = PreferenceToken.encode(
      preferences, host: host, preference_type: "AppPreference", public_id: "app-row-id",
                   jti: "app-generation", jwt_issuer_id: "preference_app", issued_at: Time.current,
    )
    claims, header = JWT.decode(token, nil, false)
    private_key = JitSecurityJwtRegistry.private_key_for("preference_app", header.fetch("kid"))
    wrong_audience = JWT.encode(claims.merge("aud" => "org"), private_key, header.fetch("alg"), header.except("alg"))
    reported_reasons = []

    JitSecurityJwtAnomalyReporter.stub(:report_preference, ->(**event) { reported_reasons << event.fetch(:reason) }) do
      assert_nil PreferenceToken.decode(wrong_audience, host: host, jwt_issuer_id: "preference_app")
      assert_raises(PreferenceToken::AudienceMismatchError) do
        PreferenceToken.decode(
          wrong_audience, host: host, jwt_issuer_id: "preference_app", raise_on_audience_mismatch: true,
        )
      end
    end

    assert_equal %w(AUD_MISMATCH AUD_MISMATCH), reported_reasons
  end
end
