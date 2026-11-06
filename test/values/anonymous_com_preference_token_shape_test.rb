# typed: false
# frozen_string_literal: true

require "test_helper"
require "jwt"

require "base64"

# WU-7 section 4.2: the anonymous com writer carries the D-54 claims shape. Signed envelope format
# stays ES384 with the realm kid/keyset; the rejected legacy claims (client_id, host,
# preference_type, nbf, scope, public_id) are gone; unknown preference keys are refused.
class AnonymousComPreferenceTokenShapeTest < ActiveSupport::TestCase
  DISPLAY_SNAPSHOT = {
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

  self.fixture_table_names = []

  test "com issuance requires an explicit time" do
    options = { host: "www.umaxica.com", preference_type: "ComPreference", public_id: "row", jti: "generation" }

    assert_nil SecurityJwtPreferenceTokenCodec.encode(DISPLAY_SNAPSHOT, **options)
    assert_nil SecurityJwtPreferenceTokenCodec.encode(DISPLAY_SNAPSHOT, **options, issued_at: "invalid")
    token = SecurityJwtPreferenceTokenCodec.encode(DISPLAY_SNAPSHOT, **options, issued_at: Time.at(0).utc)
    claims, = JWT.decode(token, nil, false)

    assert_equal 0, claims.fetch("iat")
  end

  test "oversized and non-string input is rejected" do
    limit = SecurityJwtPreferenceTokenCodec::ANONYMOUS_REALM_TOKEN_MAX_BYTES

    assert_nil SecurityJwtPreferenceTokenCodec.decode("x" * (limit + 1), host: "www.umaxica.com")
    assert_nil SecurityJwtPreferenceTokenCodec.decode(123, host: "www.umaxica.com")
    assert_nil SecurityJwtPreferenceTokenCodec.decode(nil, host: "www.umaxica.com")
  end

  test "signed tokens with duplicate header, claim, or nested preference keys are rejected" do
    token = SecurityJwtPreferenceTokenCodec.encode(
      DISPLAY_SNAPSHOT.merge({ "theme" => "dark" }), host: "www.umaxica.com", preference_type: "ComPreference",
                                                     issued_at: Time.current,
                                                     public_id: "AiM4xUN1G", jti: "generation",
    )
    header_segment, payload_segment, = token.split(".")
    header = Base64.urlsafe_decode64(header_segment)
    payload = Base64.urlsafe_decode64(payload_segment)
    key = PreferenceJwtConfiguration.private_key_for_active("preference_com")

    [
      [header.sub('"alg":', '"alg":"ES384","alg":'), payload],
      [header, payload.sub('"jti":', '"jti":"other","jti":')],
      [header, payload.sub('"theme":', '"theme":"light","theme":')],
    ].each do |header_json, payload_json|
      input = [header_json, payload_json].map { |json| Base64.urlsafe_encode64(json, padding: false) }.join(".")
      signature = JWT::JWA.resolve("ES384").sign(data: input, signing_key: key)
      duplicate_token = "#{input}.#{Base64.urlsafe_encode64(signature, padding: false)}"

      assert_nil SecurityJwtPreferenceTokenCodec.decode(duplicate_token, host: "www.umaxica.com")
    end

    assert_predicate SecurityJwtPreferenceTokenCodec.decode(token, host: "www.umaxica.com"), :present?
  end

  test "a genuine com token decodes with the legacy com claims removed" do
    token = SecurityJwtPreferenceTokenCodec.encode(
      DISPLAY_SNAPSHOT.merge({ "theme" => "dark", "language" => "ja", "page_size" => "20" }),
      host: "www.umaxica.com", preference_type: "ComPreference",
      issued_at: Time.current,
      public_id: "AiM4xUN1G blasted-lure", jti: SecureRandom.uuid,
    )

    assert_predicate token, :present?
    payload, = JWT.decode(token, nil, false)

    assert_match "AiM4xUN1G blasted-lure", payload.fetch("sub")
    assert_equal "com", payload.fetch("aud")
    assert_not_includes payload.keys, "client_id"
    assert_not_includes payload.keys, "preference_type"
    assert_not_includes payload.keys, "nbf"
    assert_not_includes payload.keys, "scope"
    assert_not_includes payload.keys, "host"
    assert_not_includes payload.keys, "public_id"
    assert_equal(
      DISPLAY_SNAPSHOT.merge("theme" => "dark", "language" => "ja", "page_size" => "20"),
      payload.fetch("preferences"),
    )

    decoded = SecurityJwtPreferenceTokenCodec.decode(token, host: "www.umaxica.com")

    assert_equal "AiM4xUN1G blasted-lure", decoded.fetch("sub")
    assert_equal(
      DISPLAY_SNAPSHOT.merge("theme" => "dark", "language" => "ja", "page_size" => "20"),
      decoded.fetch("preferences"),
    )
  end

  test "a signed legacy com preference token is rejected" do
    host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL")
    now = Time.current.to_i
    claims = {
      "iss" => PreferenceJwtConfiguration.issuer_for("preference_com"),
      "aud" => "com",
      "exp" => now + 60,
      "iat" => now,
      "nbf" => now,
      "sub" => "legacy-com-row",
      "client_id" => "retired-preference-client",
      "jti" => SecureRandom.uuid,
      "scope" => "preference",
      "preferences" => { "lx" => "ja" },
      "host" => host,
      "preference_type" => "ComPreference",
      "public_id" => "legacy-com-row",
    }
    legacy_com = JWT.encode(
      claims,
      PreferenceJwtConfiguration.private_key_for_active("preference_com"),
      SecurityJwtPreferenceTokenCodec::JWT_ALGORITHM,
      {
        kid: PreferenceJwtConfiguration.active_kid("preference_com"),
        typ: SecurityJwtPreferenceTokenCodec::TOKEN_TYPE,
      },
    )

    assert_nil SecurityJwtPreferenceTokenCodec.decode(legacy_com, host: host)
  end

  test "an unknown preferences key encodes to nothing" do
    assert_nil SecurityJwtPreferenceTokenCodec.encode(
      DISPLAY_SNAPSHOT.merge({ "theme" => "dark", "web_push" => "on" }),
      host: "www.umaxica.com", preference_type: "ComPreference",
      issued_at: Time.current,
      public_id: "AiM4xUN1G blasted-lure", jti: SecureRandom.uuid,
    )
  end

  test "each missing display key is rejected on issue and on signed read" do
    token = SecurityJwtPreferenceTokenCodec.encode(
      DISPLAY_SNAPSHOT, host: "www.umaxica.com", preference_type: "ComPreference",
                        issued_at: Time.current,
                        public_id: "AiM4xUN1G", jti: SecureRandom.uuid,
    )
    claims, header = JWT.decode(token, nil, false)
    key = PreferenceJwtConfiguration.private_key_for_active("preference_com")

    (DISPLAY_SNAPSHOT.keys + [nil]).each do |missing|
      partial = missing ? DISPLAY_SNAPSHOT.except(missing) : {}

      assert_nil SecurityJwtPreferenceTokenCodec.encode(
        partial, host: "www.umaxica.com", preference_type: "ComPreference",
                 issued_at: Time.current,
                 public_id: "AiM4xUN1G", jti: SecureRandom.uuid,
      ), missing.inspect
      altered = JWT.encode(claims.merge("preferences" => partial), key, header.fetch("alg"), header.except("alg"))

      assert_nil SecurityJwtPreferenceTokenCodec.decode(altered, host: "www.umaxica.com"), missing.inspect
    end
  end

  test "a non-string preferences value encodes to nothing" do
    assert_nil SecurityJwtPreferenceTokenCodec.encode(
      DISPLAY_SNAPSHOT.merge({ "theme" => 7 }),
      host: "www.umaxica.com", preference_type: "ComPreference",
      issued_at: Time.current,
      public_id: "AiM4xUN1G blasted-lure", jti: SecureRandom.uuid,
    )
  end

  test "unknown display values are rejected on encoding and on signed decoding" do
    token = SecurityJwtPreferenceTokenCodec.encode(
      DISPLAY_SNAPSHOT.merge({ "theme" => "dark" }), host: "www.umaxica.com", preference_type: "ComPreference",
                                                     issued_at: Time.current,
                                                     public_id: "AiM4xUN1G", jti: SecureRandom.uuid,
    )
    claims, header = JWT.decode(token, nil, false)
    key = PreferenceJwtConfiguration.private_key_for_active("preference_com")

    %w(theme language timezone currency date_format time_format motion density page_size).each do |field|
      assert_nil SecurityJwtPreferenceTokenCodec.encode(
        DISPLAY_SNAPSHOT.merge({ field => "invalid" }), host: "www.umaxica.com", preference_type: "ComPreference",
                                                        issued_at: Time.current,
                                                        public_id: "AiM4xUN1G", jti: SecureRandom.uuid,
      )
      altered = JWT.encode(
        claims.merge("preferences" => DISPLAY_SNAPSHOT.merge(field => "invalid")),
        key, header.fetch("alg"), header.except("alg"),
      )

      assert_nil SecurityJwtPreferenceTokenCodec.decode(altered, host: "www.umaxica.com"), field
    end
  end

  test "the com option names all round-trip through the signed display payload" do
    {
      "theme" => ComPreferenceThemeOption,
      "language" => ComPreferenceLanguageOption,
      "timezone" => ComPreferenceTimezoneOption,
      "currency" => ComPreferenceCurrencyOption,
      "date_format" => ComPreferenceDateFormatOption,
      "time_format" => ComPreferenceTimeFormatOption,
      "motion" => ComPreferenceMotionOption,
      "density" => ComPreferenceDensityOption,
      "page_size" => ComPreferencePageSizeOption,
    }.each do |field, option_class|
      option_class::DEFAULTS.each do |id|
        name = option_class.new(id: id).name
        next if name.nil?

        token = SecurityJwtPreferenceTokenCodec.encode(
          DISPLAY_SNAPSHOT.merge({ field => name }), host: "www.umaxica.com", preference_type: "ComPreference",
                                                     issued_at: Time.current,
                                                     public_id: "AiM4xUN1G", jti: SecureRandom.uuid,
        )

        assert_predicate token, :present?, "#{field}=#{name}"
        payload = SecurityJwtPreferenceTokenCodec.decode(token, host: "www.umaxica.com")

        assert_equal name, payload.fetch("preferences").fetch(field)
      end
    end
  end

  test "com JWTs at the reachable size boundary are accepted and larger ones rejected" do
    issued_at = Time.current.change(usec: 0)
    seed = SecurityJwtPreferenceTokenCodec.encode(
      DISPLAY_SNAPSHOT.merge({ "theme" => "dark" }), host: "www.umaxica.com", preference_type: "ComPreference",
                                                     public_id: "x", jti: "generation", issued_at: issued_at,
    )
    claims, header = JWT.decode(seed, nil, false)
    header_length, _, signature_length = seed.split(".").map(&:bytesize)
    candidates =
      (1700..2400).to_h do |length|
        encoded = Base64.urlsafe_encode64(claims.merge("sub" => "x" * length).to_json, padding: false)
        [header_length + encoded.bytesize + signature_length + 2, length]
      end
    limit = SecurityJwtPreferenceTokenCodec::ANONYMOUS_REALM_TOKEN_MAX_BYTES
    # Base64url cannot represent every adjacent length; use the nearest reachable size on each side.
    sizes = [candidates.keys.select { |size| size < limit }.max,
             candidates.keys.select { |size| size <= limit }.max,
             candidates.keys.select { |size| size > limit }.min,]
    key = PreferenceJwtConfiguration.private_key_for_active("preference_com")

    sizes.each do |size|
      subject = "x" * candidates.fetch(size)
      raw = JWT.encode(claims.merge("sub" => subject), key, header.fetch("alg"), header.except("alg"))
      issued = SecurityJwtPreferenceTokenCodec.encode(
        DISPLAY_SNAPSHOT.merge({ "theme" => "dark" }), host: "www.umaxica.com", preference_type: "ComPreference",
                                                       public_id: subject, jti: "generation", issued_at: issued_at,
      )

      assert_equal size, raw.bytesize
      if size <= limit
        assert_predicate issued, :present?
        assert_predicate SecurityJwtPreferenceTokenCodec.decode(raw, host: "www.umaxica.com"), :present?
      else
        assert_nil issued
        assert_nil SecurityJwtPreferenceTokenCodec.decode(raw, host: "www.umaxica.com")
      end
    end
  end

  test "a com token is valid before its 400-day expiry and invalid at and after expiry" do
    token = SecurityJwtPreferenceTokenCodec.encode(
      DISPLAY_SNAPSHOT.merge({ "theme" => "dark" }), host: "www.umaxica.com", preference_type: "ComPreference",
                                                     issued_at: Time.current,
                                                     public_id: "AiM4xUN1G", jti: SecureRandom.uuid,
    )
    claims, = JWT.decode(token, nil, false)

    assert_equal 400.days.to_i, claims.fetch("exp") - claims.fetch("iat")
    travel_to Time.at(claims.fetch("exp") - 1).utc do
      assert_predicate SecurityJwtPreferenceTokenCodec.decode(token, host: "www.umaxica.com"), :present?
    end
    travel_to Time.at(claims.fetch("exp")).utc do
      assert_nil SecurityJwtPreferenceTokenCodec.decode(token, host: "www.umaxica.com")
    end
    travel_to Time.at(claims.fetch("exp") + 1).utc do
      assert_nil SecurityJwtPreferenceTokenCodec.decode(token, host: "www.umaxica.com")
    end
  end

  test "signed com tokens reject lifetimes longer than 400 days" do
    token = SecurityJwtPreferenceTokenCodec.encode(
      DISPLAY_SNAPSHOT.merge({ "theme" => "dark" }), host: "www.umaxica.com", preference_type: "ComPreference",
                                                     issued_at: Time.current,
                                                     public_id: "AiM4xUN1G", jti: SecureRandom.uuid,
    )
    claims, header = JWT.decode(token, nil, false)
    key = PreferenceJwtConfiguration.private_key_for_active("preference_com")
    maximum = 400.days.to_i

    [maximum - 1, maximum, maximum + 1].each do |lifetime|
      altered = JWT.encode(
        claims.merge("exp" => claims.fetch("iat") + lifetime), key, header.fetch("alg"), header.except("alg"),
      )
      decoded = SecurityJwtPreferenceTokenCodec.decode(altered, host: "www.umaxica.com")

      if lifetime <= maximum
        assert_predicate decoded, :present?
      else
        assert_nil decoded
      end
    end
  end

  test "an audience token of another realm refuses to decode" do
    token = SecurityJwtPreferenceTokenCodec.encode(
      DISPLAY_SNAPSHOT.merge({ "theme" => "dark" }),
      host: "www.umaxica.com", preference_type: "ComPreference",
      issued_at: Time.current,
      public_id: "AiM4xUN1G", jti: SecureRandom.uuid,
    )
    key = PreferenceJwtConfiguration.private_key_for_active("preference_com")
    claims, header = JWT.decode(token, nil, false)
    tampered = JWT.encode(claims.merge("aud" => "app"), key, header.fetch("alg"), header.except("alg"))

    assert_nil SecurityJwtPreferenceTokenCodec.decode(tampered, host: "www.umaxica.com")
  end

  test "a com token is accepted on a com sibling and rejected on app and org hosts" do
    token = SecurityJwtPreferenceTokenCodec.encode(
      DISPLAY_SNAPSHOT.merge({ "theme" => "dark" }), host: "www.umaxica.com", preference_type: "ComPreference",
                                                     issued_at: Time.current,
                                                     public_id: "AiM4xUN1G", jti: SecureRandom.uuid,
    )

    assert_predicate SecurityJwtPreferenceTokenCodec.decode(token, host: "www-jp.umaxica.com"), :present?
    assert_nil SecurityJwtPreferenceTokenCodec.decode(token, host: "www.umaxica.app")
    assert_nil SecurityJwtPreferenceTokenCodec.decode(token, host: "www.umaxica.org")
    assert_nil SecurityJwtPreferenceTokenCodec.decode(token, host: "other.example.com")
  end

  test "com app and org anonymous issuers reject each other's signing keys" do
    com_token = SecurityJwtPreferenceTokenCodec.encode(
      DISPLAY_SNAPSHOT, host: "www.umaxica.com", preference_type: "ComPreference", issued_at: Time.current,
                        public_id: "com-row", jti: SecureRandom.uuid,
    )
    com_claims, com_header = JWT.decode(com_token, nil, false)
    forged_com = JWT.encode(
      com_claims, PreferenceJwtConfiguration.private_key_for_active("preference_app"),
      com_header.fetch("alg"), com_header.except("alg"),
    )

    assert_nil SecurityJwtPreferenceTokenCodec.decode(forged_com, host: "www.umaxica.com")

    %w(app org).each do |realm|
      host = "www.umaxica.#{realm}"
      preference_type = (realm == "app") ? "AppPreference" : "OrgPreference"
      issuer_id = "preference_#{realm}"
      token = SecurityJwtPreferenceTokenCodec.encode(
        DISPLAY_SNAPSHOT, host: host, preference_type: preference_type, issued_at: Time.current,
                          public_id: "#{realm}-row", jti: SecureRandom.uuid,
      )
      claims, header = JWT.decode(token, nil, false)
      forged_token = JWT.encode(
        claims,
        PreferenceJwtConfiguration.private_key_for_active("preference_com"),
        header.fetch("alg"),
        header.except("alg"),
      )

      assert_predicate SecurityJwtPreferenceTokenCodec.decode(token, host: host, jwt_issuer_id: issuer_id), :present?
      assert_nil SecurityJwtPreferenceTokenCodec.decode(forged_token, host: host, jwt_issuer_id: issuer_id)
      assert_nil SecurityJwtPreferenceTokenCodec.decode(token, host: "www.umaxica.com")
    end
  end

  test "registry rejects reuse of another issuer's key under a com kid" do
    records = JitSecurityJwtRegistry.issuers.dup
    com = records.fetch("preference_com")
    other = records.fetch("preference_app").current_key
    com_key = com.current_key.with(
      private_key: other.private_key,
      public_key: other.public_key,
      public_jwk: JitSecurityJwtRegistry.export_public_jwk(other.public_key, kid: com.current_kid),
    )
    records["preference_com"] = com.with(keys: { com.current_kid => com_key })

    error = assert_raises(JitSecurityJwtRegistry::ConfigurationError) { JitSecurityJwtRegistry.validate!(records) }
    assert_match "key material is shared", error.message
  end

  test "com token issuance rejects app org and unrelated hosts" do
    %w(www.umaxica.app www.umaxica.org other.example.com).each do |host|
      assert_nil SecurityJwtPreferenceTokenCodec.encode(
        DISPLAY_SNAPSHOT.merge({ "theme" => "dark" }), host: host, preference_type: "ComPreference",
                                                       issued_at: Time.current,
                                                       public_id: "AiM4xUN1G", jti: SecureRandom.uuid,
      ), host
    end
  end

  test "com issuance refuses an issuer namespace that it cannot use" do
    assert_nil SecurityJwtPreferenceTokenCodec.encode(
      DISPLAY_SNAPSHOT.merge({ "theme" => "dark" }), host: "www.umaxica.com", preference_type: "ComPreference",
                                                     issued_at: Time.current,
                                                     public_id: "AiM4xUN1G", jti: SecureRandom.uuid,
                                                     jwt_issuer_id: "surface:AUTH_APP",
    )
  end

  test "com verification refuses an unrelated issuer namespace" do
    token = SecurityJwtPreferenceTokenCodec.encode(
      DISPLAY_SNAPSHOT.merge({ "theme" => "dark" }), host: "www.umaxica.com", preference_type: "ComPreference",
                                                     issued_at: Time.current,
                                                     public_id: "AiM4xUN1G", jti: SecureRandom.uuid,
    )

    claims, header = JWT.decode(token, nil, false)
    issuer = JitSecurityJwtRegistry.issuer("surface:AUTH_APP")
    unrelated = JWT.encode(
      claims, JitSecurityJwtRegistry.private_key_for("surface:AUTH_APP"), header.fetch("alg"),
      header.merge("kid" => issuer.current_kid).except("alg"),
    )

    assert_predicate SecurityJwtPreferenceTokenCodec.decode(token, host: "www.umaxica.com"), :present?
    assert_nil SecurityJwtPreferenceTokenCodec.decode(
      unrelated, host: "www.umaxica.com", jwt_issuer_id: "surface:AUTH_APP",
    )
  end

  test "a signed token with an unknown key identifier is rejected" do
    token = SecurityJwtPreferenceTokenCodec.encode(
      DISPLAY_SNAPSHOT.merge({ "theme" => "dark" }), host: "www.umaxica.com", preference_type: "ComPreference",
                                                     issued_at: Time.current,
                                                     public_id: "AiM4xUN1G", jti: SecureRandom.uuid,
    )
    claims, header = JWT.decode(token, nil, false)
    key = PreferenceJwtConfiguration.private_key_for_active("preference_com")
    altered = JWT.encode(claims, key, header.fetch("alg"), header.merge("kid" => "unknown-key"))

    assert_nil SecurityJwtPreferenceTokenCodec.decode(altered, host: "www.umaxica.com")
  end

  test "com key rotation accepts the grace key and rejects it when revoked or retired" do
    host = "www.umaxica.com"
    issued_at = Time.current
    original_records = JitSecurityJwtRegistry.issuers
    original = original_records.fetch("preference_com")
    old_kid = original.current_kid
    old_token = SecurityJwtPreferenceTokenCodec.encode(
      DISPLAY_SNAPSHOT, host: host, preference_type: "ComPreference", issued_at: issued_at,
                        public_id: "old-preference", jti: "old-generation",
    )
    new_key = OpenSSL::PKey::EC.generate("secp384r1")
    new_kid = "com-rotation-new"
    new_record = KeyRecord.new(
      kid: new_kid, private_key: new_key, public_key: new_key,
      public_jwk: JitSecurityJwtRegistry.export_public_jwk(new_key, kid: new_kid), state: "active",
    )
    grace_record = original.current_key.with(state: "grace", private_key: nil)
    rotated = original.with(current_kid: new_kid, keys: { old_kid => grace_record, new_kid => new_record })
    records = original_records.merge("preference_com" => rotated)
    new_token = nil

    JitSecurityJwtRegistry.stub(:issuers, records) do
      assert_predicate SecurityJwtPreferenceTokenCodec.decode(old_token, host: host), :present?
      new_token = SecurityJwtPreferenceTokenCodec.encode(
        DISPLAY_SNAPSHOT, host: host, preference_type: "ComPreference", issued_at: issued_at,
                          public_id: "new-preference", jti: "new-generation",
      )

      assert_equal new_kid, JWT.decode(new_token, nil, false).last.fetch("kid")
      assert_predicate SecurityJwtPreferenceTokenCodec.decode(new_token, host: host), :present?
    end

    revoked = rotated.with(revoked_kids: Set[old_kid])
    JitSecurityJwtRegistry.stub(:issuers, records.merge("preference_com" => revoked)) do
      assert_nil SecurityJwtPreferenceTokenCodec.decode(old_token, host: host)
      assert_predicate SecurityJwtPreferenceTokenCodec.decode(new_token, host: host), :present?
    end

    retired = rotated.with(keys: rotated.keys.merge(old_kid => grace_record.with(state: "retired")))
    JitSecurityJwtRegistry.stub(:issuers, records.merge("preference_com" => retired)) do
      assert_nil SecurityJwtPreferenceTokenCodec.decode(old_token, host: host)
      assert_predicate SecurityJwtPreferenceTokenCodec.decode(new_token, host: host), :present?
    end
  end

  test "a signed token with an invalid type header is rejected" do
    token = SecurityJwtPreferenceTokenCodec.encode(
      DISPLAY_SNAPSHOT.merge({ "theme" => "dark" }), host: "www.umaxica.com", preference_type: "ComPreference",
                                                     issued_at: Time.current,
                                                     public_id: "AiM4xUN1G", jti: SecureRandom.uuid,
    )
    claims, header = JWT.decode(token, nil, false)
    key = PreferenceJwtConfiguration.private_key_for_active("preference_com")
    altered = JWT.encode(claims, key, header.fetch("alg"), header.merge("typ" => "invalid"))

    assert_nil SecurityJwtPreferenceTokenCodec.decode(altered, host: "www.umaxica.com")
  end

  test "signed tokens with extra claims or invalid subject and generation are rejected" do
    token = SecurityJwtPreferenceTokenCodec.encode(
      DISPLAY_SNAPSHOT.merge({ "theme" => "dark" }), host: "www.umaxica.com", preference_type: "ComPreference",
                                                     issued_at: Time.current,
                                                     public_id: "AiM4xUN1G", jti: SecureRandom.uuid,
    )
    claims, header = JWT.decode(token, nil, false)
    key = PreferenceJwtConfiguration.private_key_for_active("preference_com")

    [{ "extra" => "value" }, { "sub" => "" }, { "sub" => 1 }, { "jti" => "" }, { "jti" => 0 }].each do |change|
      altered = JWT.encode(claims.merge(change), key, header.fetch("alg"), header.except("alg"))

      assert_nil SecurityJwtPreferenceTokenCodec.decode(altered, host: "www.umaxica.com"), change.inspect
    end
  end
end
