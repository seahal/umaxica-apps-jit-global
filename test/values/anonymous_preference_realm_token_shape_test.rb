# frozen_string_literal: true

require "test_helper"

class AnonymousPreferenceRealmTokenShapeTest < ActiveSupport::TestCase
  PREFERENCES = {
    "theme" => "system",
    "language" => "ja",
    "timezone" => "Asia/Tokyo",
    "currency" => "jpy",
    "date_format" => "iso",
    "time_format" => "24",
    "motion" => "standard",
    "density" => "standard",
    "page_size" => "infinity",
  }.freeze

  test "app and org anonymous tokens use isolated realm claims and a 400-day expiry" do
    issued_at = Time.utc(2026, 10, 31, 12)
    app_token = PreferenceToken.encode(
      PREFERENCES, host: "app.localhost", preference_type: "AppPreference",
                   public_id: "app-preference-1", jti: "app-generation-1", jwt_issuer_id: "preference_app",
                   issued_at: issued_at,
    )
    org_token = PreferenceToken.encode(
      PREFERENCES, host: "org.localhost", preference_type: "OrgPreference",
                   public_id: "org-preference-1", jti: "org-generation-1", jwt_issuer_id: "preference_org",
                   issued_at: issued_at,
    )

    assert_predicate app_token, :present?
    assert_predicate org_token, :present?
    app_claims, = JWT.decode(app_token, nil, false)
    org_claims, = JWT.decode(org_token, nil, false)

    assert_equal %w(aud exp iat iss jti preferences sub), app_claims.keys.sort
    assert_equal %w(aud exp iat iss jti preferences sub), org_claims.keys.sort
    assert_equal "app", app_claims.fetch("aud")
    assert_equal "org", org_claims.fetch("aud")
    assert_equal "app-preference-1", app_claims.fetch("sub")
    assert_equal "org-preference-1", org_claims.fetch("sub")
    assert_equal 400.days.to_i, app_claims.fetch("exp") - app_claims.fetch("iat")
    assert_equal 400.days.to_i, org_claims.fetch("exp") - org_claims.fetch("iat")
    assert_equal PREFERENCES, PreferenceToken.extract_preferences(
      PreferenceToken.decode(
        app_token, host: "app.localhost", jwt_issuer_id: "preference_app",
      ),
    )
    assert_equal PREFERENCES, PreferenceToken.extract_preferences(
      PreferenceToken.decode(
        org_token, host: "org.localhost", jwt_issuer_id: "preference_org",
      ),
    )
    assert_nil PreferenceToken.decode(app_token, host: "org.localhost", jwt_issuer_id: "preference_org")
    assert_nil PreferenceToken.decode(org_token, host: "app.localhost", jwt_issuer_id: "preference_app")
  end

  test "anonymous preference signing keys are distinct for app org and com" do
    app_key =
      JitSecurityJwtRegistry.issuer("preference_app").keys.values.map do |key|
        key.public_key.public_to_der
      end
    com_key =
      JitSecurityJwtRegistry.issuer("preference_com").keys.values.map do |key|
        key.public_key.public_to_der
      end
    org_key =
      JitSecurityJwtRegistry.issuer("preference_org").keys.values.map do |key|
        key.public_key.public_to_der
      end

    assert_empty app_key & com_key
    assert_empty app_key & org_key
    assert_empty com_key & org_key
  end
end
