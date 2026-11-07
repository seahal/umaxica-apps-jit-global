# typed: false
# frozen_string_literal: true

require "test_helper"
require "openssl"

class PreferenceTokenModelTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  setup do
    @host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    @issued_at = Time.current.change(usec: 0)
    @public_id = PublicId.generate
    @jti = SecureRandom.uuid
    @private_key = OpenSSL::PKey::EC.generate("secp384r1")
    @preferences = {
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
  end

  test "realm token encodes and decodes the closed current claim shape across same-realm readers" do
    issuer = "https://www.umaxica.app"
    public_key_for = ->(_kid, **_options) { @private_key }

    PreferenceJwtConfiguration.stub(:private_key_for_active, @private_key) do
      PreferenceJwtConfiguration.stub(:public_key_for, public_key_for) do
        PreferenceJwtConfiguration.stub(:active_kid, "test-key") do
          PreferenceJwtConfiguration.stub(:issuer_for, issuer) do
            token = PreferenceToken.encode(
              @preferences, host: @host, preference_type: "AppPreference", public_id: @public_id,
                            jti: @jti, jwt_issuer_id: "preference_app", issued_at: @issued_at,
            )

            assert_kind_of String, token
            claims, header = JWT.decode(token, nil, false)

            assert_equal "ES384", header.fetch("alg")
            assert_equal "test-key", header.fetch("kid")
            assert_equal "JWT", header.fetch("typ")
            assert_equal issuer, claims.fetch("iss")
            assert_equal "app", claims.fetch("aud")
            assert_equal @public_id, claims.fetch("sub")
            assert_equal @issued_at.to_i, claims.fetch("iat")
            assert_equal @issued_at.to_i + 400.days.to_i, claims.fetch("exp")
            assert_equal @jti, claims.fetch("jti")
            assert_equal @preferences, claims.fetch("preferences")
            %w(client_id host nbf preference_type public_id scope).each do |retired_claim|
              assert_not_includes claims, retired_claim
            end

            decoded = PreferenceToken.decode(token, host: @host, jwt_issuer_id: "preference_app")

            assert_equal claims, decoded
            assert_equal claims, PreferenceToken.decode(
              token, host: ENV.fetch("PUBLIC_CORE_SERVICE_URL"), jwt_issuer_id: "preference_app",
            )
            assert_nil PreferenceToken.decode(
              token, host: ENV.fetch("PUBLIC_BASE_STAFF_URL"), jwt_issuer_id: "preference_org",
            )
            assert_equal @preferences, PreferenceToken.extract_preferences(decoded)
            assert_equal @public_id, PreferenceToken.extract_public_id(decoded)
            assert_equal @jti, PreferenceToken.extract_jti(decoded)

            travel_to(Time.at(claims.fetch("exp")).utc) do
              assert_nil PreferenceToken.decode(token, host: @host, jwt_issuer_id: "preference_app")
            end
          end
        end
      end
    end
  end

  test "encoder refuses missing inputs and snapshots outside the closed option contract" do
    PreferenceJwtConfiguration.stub(:private_key_for_active, @private_key) do
      PreferenceJwtConfiguration.stub(:active_kid, "test-key") do
        PreferenceJwtConfiguration.stub(:issuer_for, "https://www.umaxica.app") do
          assert_nil PreferenceToken.encode(
            {}, host: @host, preference_type: "AppPreference", public_id: @public_id,
                jti: @jti, jwt_issuer_id: "preference_app", issued_at: @issued_at,
          )
          assert_nil PreferenceToken.encode(
            @preferences, host: nil, preference_type: "AppPreference", public_id: @public_id,
                          jti: @jti, jwt_issuer_id: "preference_app", issued_at: @issued_at,
          )
          assert_nil PreferenceToken.encode(
            @preferences.merge("legacy_cookie" => "dark"), host: @host,
                                                           preference_type: "AppPreference", public_id: @public_id,
                                                           jti: @jti, jwt_issuer_id: "preference_app",
                                                           issued_at: @issued_at,
          )
          assert_nil PreferenceToken.encode(
            @preferences.merge("theme" => "sepia"), host: @host,
                                                    preference_type: "AppPreference", public_id: @public_id,
                                                    jti: @jti, jwt_issuer_id: "preference_app", issued_at: @issued_at,
          )
          assert_nil PreferenceToken.encode(
            @preferences, host: @host, preference_type: "AppPreference", public_id: @public_id,
                          jti: @jti, jwt_issuer_id: "preference_app",
          )
          assert_nil PreferenceToken.encode(
            @preferences, host: @host, preference_type: "AppPreference", public_id: @public_id,
                          jti: "", jwt_issuer_id: "preference_app", issued_at: @issued_at,
          )
        end
      end
    end
  end

  test "decoder rejects invalid cryptography headers and retired claim shapes" do
    public_key_for = ->(_kid, **_options) { @private_key }
    issuer = "https://www.umaxica.app"

    PreferenceJwtConfiguration.stub(:private_key_for_active, @private_key) do
      PreferenceJwtConfiguration.stub(:public_key_for, public_key_for) do
        PreferenceJwtConfiguration.stub(:active_kid, "test-key") do
          PreferenceJwtConfiguration.stub(:issuer_for, issuer) do
            token = PreferenceToken.encode(
              @preferences, host: @host, preference_type: "AppPreference", public_id: @public_id,
                            jti: @jti, jwt_issuer_id: "preference_app", issued_at: @issued_at,
            )
            claims, header = JWT.decode(token, nil, false)
            invalid_tokens = [
              token.reverse,
              JWT.encode(claims, "wrong-secret", "HS256", { "typ" => PreferenceToken::TOKEN_TYPE }),
              JWT.encode(claims, nil, "none", { "kid" => "test-key", "typ" => PreferenceToken::TOKEN_TYPE }),
            ]

            missing_typ = header.except("typ")
            invalid_tokens << JWT.encode(claims, @private_key, "ES384", missing_typ)
            invalid_tokens << JWT.encode(claims, @private_key, "ES384", header.merge("typ" => "wrong"))

            %w(iss aud sub iat exp jti preferences).each do |claim|
              invalid_tokens << JWT.encode(claims.except(claim), @private_key, "ES384", header)
            end
            invalid_tokens << JWT.encode(claims.merge("iss" => "https://wrong.example"), @private_key, "ES384", header)
            invalid_tokens << JWT.encode(claims.merge("exp" => claims.fetch("iat")), @private_key, "ES384", header)
            invalid_tokens << JWT.encode(claims.merge("client_id" => "retired"), @private_key, "ES384", header)
            invalid_tokens << JWT.encode(
              claims.merge("preferences" => @preferences.merge("theme" => "sepia")),
              @private_key, "ES384", header,
            )

            invalid_tokens.each do |invalid_token|
              assert_nil PreferenceToken.decode(
                invalid_token, host: @host, jwt_issuer_id: "preference_app",
              ), invalid_token
            end
            assert_nil PreferenceToken.decode("invalid.token", host: @host, jwt_issuer_id: "preference_app")
            assert_nil PreferenceToken.decode(token, host: nil, jwt_issuer_id: "preference_app")
            assert_nil PreferenceToken.decode(nil, host: @host, jwt_issuer_id: "preference_app")
            assert_not_respond_to PreferenceToken, :build_payload
            assert_not_respond_to PreferenceToken, :decode_options
            assert_not_respond_to PreferenceToken, :valid_header?
            assert_not_respond_to PreferenceToken, :resolve_public_key
            assert_not_respond_to PreferenceToken, :extract_preference_type
          end
        end
      end
    end
  end

  test "encoder and decoder return nil when their realm key operation fails" do
    PreferenceJwtConfiguration.stub(:private_key_for_active, ->(*) { raise JWT::EncodeError, "forced key failure" }) do
      PreferenceJwtConfiguration.stub(:active_kid, "test-key") do
        PreferenceJwtConfiguration.stub(:issuer_for, "https://www.umaxica.app") do
          assert_nil PreferenceToken.encode(
            @preferences, host: @host, preference_type: "AppPreference", public_id: @public_id,
                          jti: @jti, jwt_issuer_id: "preference_app", issued_at: @issued_at,
          )
        end
      end
    end

    PreferenceJwtConfiguration.stub(:private_key_for_active, @private_key) do
      PreferenceJwtConfiguration.stub(
        :public_key_for, ->(*) {
                           raise OpenSSL::PKey::PKeyError, "forced key failure"
                         },
      ) do
        PreferenceJwtConfiguration.stub(:active_kid, "test-key") do
          PreferenceJwtConfiguration.stub(:issuer_for, "https://www.umaxica.app") do
            token = PreferenceToken.encode(
              @preferences, host: @host, preference_type: "AppPreference", public_id: @public_id,
                            jti: @jti, jwt_issuer_id: "preference_app", issued_at: @issued_at,
            )

            assert_nil PreferenceToken.decode(token, host: @host, jwt_issuer_id: "preference_app")
          end
        end
      end
    end
  end

  test "extractors return empty values for non-hash input" do
    assert_empty PreferenceToken.extract_preferences(nil)
    assert_nil PreferenceToken.extract_public_id(nil)
    assert_nil PreferenceToken.extract_jti(nil)
  end
end
