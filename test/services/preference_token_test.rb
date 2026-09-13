# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"
require "openssl"
require_relative "../../app/controllers/concerns/preference_jwt_configuration"
require_relative "../../app/controllers/concerns/preference_token"

class PreferenceTokenTest < ActiveSupport::TestCase
  setup do
    @prefs = { "ct" => "dr" }.freeze
    @host = "example.com".freeze
    @preference_type = "AppPreference".freeze
    @public_id = "pref_public_id".freeze
    @jti = "test-jti-#{SecureRandom.uuid}".freeze
    @private_key = OpenSSL::PKey::EC.generate("secp384r1")
    @public_key = @private_key
    @issuer = "jit-preference".freeze
    @audiences = ["example.com"].freeze
  end

  test "encodes and decodes token" do
    with_jwt_keys do
      token = PreferenceToken.encode(
        @prefs,
        host: @host,
        preference_type: @preference_type,
        public_id: @public_id,
        jti: @jti,
      )

      assert_not_nil token

      _payload, header = JWT.decode(token, nil, false)

      assert_predicate header["kid"], :present?
      assert_equal PreferenceToken::TOKEN_TYPE, header["typ"]

      decoded = PreferenceToken.decode(token, host: @host)

      assert_not_nil decoded
      assert_equal "dr", decoded.dig("preferences", "ct")
      assert_equal @jti, decoded["jti"]
      assert_nil decoded["typ"]
      assert_equal @public_id, decoded["sub"]
    end
  end

  test "encodes and decodes with a sign surface issuer without using legacy preference issuer" do
    audiences = ["log.umaxica.app", "log.umaxica.com"].freeze
    key_for = ->(kid, **_options) { (kid == "default") ? @public_key : nil }
    PreferenceJwtConfiguration.stub(:audiences, audiences) do
      PreferenceJwtConfiguration.stub(:host_scope_for, "log.umaxica.app") do
        PreferenceJwtConfiguration.stub(:private_key_for_active, @private_key) do
          PreferenceJwtConfiguration.stub(:public_key_for, key_for) do
            PreferenceJwtConfiguration.stub(:active_kid, "default") do
              token = PreferenceToken.encode(
                @prefs,
                host: "log.umaxica.app",
                preference_type: @preference_type,
                public_id: @public_id,
                jti: @jti,
                jwt_issuer_id: "surface:SIGN_APP",
              )

              assert_not_nil token

              decoded = PreferenceToken.decode(
                token,
                host: "log.umaxica.app",
                jwt_issuer_id: "surface:SIGN_APP",
              )

              assert_equal "dr", decoded.dig("preferences", "ct")
              assert_equal @jti, decoded["jti"]
            end
          end
        end
      end
    end
  end

  test "returns nil for invalid token" do
    with_jwt_keys do
      assert_nil PreferenceToken.decode("invalid", host: @host)
    end
  end

  test "returns nil for wrong host" do
    with_jwt_keys do
      token = PreferenceToken.encode(
        @prefs,
        host: @host,
        preference_type: @preference_type,
        public_id: @public_id,
        jti: @jti,
      )

      assert_nil PreferenceToken.decode(token, host: "wrong.com")
    end
  end

  test "returns nil for alg none token" do
    with_jwt_keys do
      token = PreferenceToken.encode(
        @prefs,
        host: @host,
        preference_type: @preference_type,
        public_id: @public_id,
        jti: @jti,
      )
      payload, _header = JWT.decode(token, nil, false)
      tampered = JWT.encode(payload, nil, "none", { typ: PreferenceToken::TOKEN_TYPE })

      assert_nil PreferenceToken.decode(tampered, host: @host)
    end
  end

  test "returns nil for a case-variant algorithm token" do
    with_jwt_keys do
      token = PreferenceToken.encode(
        @prefs,
        host: @host,
        preference_type: @preference_type,
        public_id: @public_id,
        jti: @jti,
      )
      payload, header = JWT.decode(token, nil, false)
      tampered = JWT.encode(payload, @private_key, "ES384", header.merge("alg" => "eS384"))

      assert_nil PreferenceToken.decode(tampered, host: @host)
    end
  end

  test "returns nil for a token missing iat" do
    with_jwt_keys do
      token = PreferenceToken.encode(
        @prefs,
        host: @host,
        preference_type: @preference_type,
        public_id: @public_id,
        jti: @jti,
      )
      payload, header = JWT.decode(token, nil, false)
      payload.delete("iat")
      tampered = JWT.encode(payload, @private_key, "ES384", header)

      assert_nil PreferenceToken.decode(tampered, host: @host)
    end
  end

  test "returns nil for unknown kid" do
    with_jwt_keys do
      token = PreferenceToken.encode(
        @prefs,
        host: @host,
        preference_type: @preference_type,
        public_id: @public_id,
        jti: @jti,
      )
      payload, header = JWT.decode(token, nil, false)
      tampered = JWT.encode(payload, @private_key, "ES384", header.merge("kid" => "unknown-kid"))

      assert_nil PreferenceToken.decode(tampered, host: @host)
    end
  end

  test ".app token cannot be replayed against the .com surface" do
    audiences = ["log.umaxica.app", "log.umaxica.com"].freeze
    key_for = ->(kid) { (kid == "default") ? @public_key : nil }

    PreferenceJwtConfiguration.stub(:private_key, @private_key) do
      PreferenceJwtConfiguration.stub(:public_key, @public_key) do
        PreferenceJwtConfiguration.stub(:private_key_for_active, @private_key) do
          PreferenceJwtConfiguration.stub(:public_key_for, key_for) do
            PreferenceJwtConfiguration.stub(:active_kid, "default") do
              PreferenceJwtConfiguration.stub(:issuer, @issuer) do
                PreferenceJwtConfiguration.stub(:audiences, audiences) do
                  app_token = PreferenceToken.encode(
                    @prefs,
                    host: "log.umaxica.app",
                    preference_type: "AppPreference",
                    public_id: @public_id,
                    jti: @jti,
                  )

                  assert_not_nil app_token
                  assert_nil PreferenceToken.decode(app_token, host: "log.umaxica.com"),
                             "audience scoped to .app TLD must not validate on a .com host"
                end
              end
            end
          end
        end
      end
    end
  end

  test "token issued for a public www host can be decoded by the same host" do
    # Regression: if the JWT audience list does not include the request host,
    # validate_payload returns nil, clear_preference_auth_cookies! fires, and
    # both cookies disappear immediately after being written.
    %w(www.umaxica.app www.umaxica.com www.umaxica.org).each do |host|
      audiences = [host]
      key_for = ->(kid) { (kid == "default") ? @public_key : nil }

      PreferenceJwtConfiguration.stub(:private_key_for_active, @private_key) do
        PreferenceJwtConfiguration.stub(:public_key_for, key_for) do
          PreferenceJwtConfiguration.stub(:active_kid, "default") do
            PreferenceJwtConfiguration.stub(:issuer, @issuer) do
              PreferenceJwtConfiguration.stub(:audiences, audiences) do
                token = PreferenceToken.encode(
                  @prefs,
                  host: host,
                  preference_type: @preference_type,
                  public_id: @public_id,
                  jti: @jti,
                )

                assert_not_nil token, "encode must succeed for #{host}"
                decoded = PreferenceToken.decode(token, host: host)

                assert_not_nil decoded,
                               "self-verification must pass for #{host} — audience_matches? would fail if host " \
                               "is missing from audiences"
              end
            end
          end
        end
      end
    end
  end

  test "wrong audience logs preference aud mismatch and returns nil by default" do
    with_audience_mismatch_jwt_config do
      token = preference_token_for_audience_test
      logged_payload = nil

      Rails.logger.stub(:info, ->(message) { logged_payload = JSON.parse(message) }) do
        assert_nil PreferenceToken.decode(token, host: "www.app.umaxica.com")
      end

      assert_equal "jwt.anomaly.detected", logged_payload.fetch("event")
      assert_equal "APP_PREFERENCE_AUD_MISMATCH", logged_payload.dig("data", "reason_code")
      assert_equal "www.app.umaxica.com", logged_payload.dig("data", "request_host")
      assert_equal ["app.umaxica.app"], logged_payload.dig("data", "aud")
      assert_equal "JWT::InvalidAudError", logged_payload.dig("data", "error_class")
    end
  end

  test "wrong audience raises in strict write mode after logging" do
    with_audience_mismatch_jwt_config do
      token = preference_token_for_audience_test
      logged_payload = nil

      Rails.logger.stub(:info, ->(message) { logged_payload = JSON.parse(message) }) do
        assert_raises(PreferenceToken::AudienceMismatchError) do
          PreferenceToken.decode(token, host: "www.app.umaxica.com", raise_on_audience_mismatch: true)
        end
      end

      assert_equal "APP_PREFERENCE_AUD_MISMATCH", logged_payload.dig("data", "reason_code")
    end
  end

  test "JwtConfiguration.audiences derives host names from boot config" do
    expected = Rails.configuration.x.boot_config.fetch(:hosts).base_origins.map(&:host)
    expected.concat(%w(app.localhost org.localhost com.localhost localhost))
    expected.uniq!

    assert_equal expected, PreferenceJwtConfiguration.audiences
  end

  test "audience_for requires a host" do
    PreferenceJwtConfiguration.stub(:audiences, ["example.com"]) do
      assert_raises(ArgumentError) { PreferenceJwtConfiguration.audience_for(nil) }
      assert_raises(ArgumentError) { PreferenceJwtConfiguration.audience_for("") }
    end
  end

  private

  def preference_token_for_audience_test
    PreferenceToken.encode(
      @prefs,
      host: "app.umaxica.app",
      preference_type: @preference_type,
      public_id: @public_id,
      jti: @jti,
    )
  end

  def with_audience_mismatch_jwt_config
    audiences = ["app.umaxica.app", "www.app.umaxica.com"].freeze
    key_for = ->(kid) { (kid == "default") ? @public_key : nil }

    PreferenceJwtConfiguration.stub(:private_key, @private_key) do
      PreferenceJwtConfiguration.stub(:public_key, @public_key) do
        PreferenceJwtConfiguration.stub(:private_key_for_active, @private_key) do
          PreferenceJwtConfiguration.stub(:public_key_for, key_for) do
            PreferenceJwtConfiguration.stub(:active_kid, "default") do
              PreferenceJwtConfiguration.stub(:issuer, @issuer) do
                PreferenceJwtConfiguration.stub(:audiences, audiences) do
                  yield
                end
              end
            end
          end
        end
      end
    end
  end

  def with_jwt_keys
    key_for = ->(kid) { (kid == "default") ? @public_key : nil }

    PreferenceJwtConfiguration.stub(:private_key, @private_key) do
      PreferenceJwtConfiguration.stub(:public_key, @public_key) do
        PreferenceJwtConfiguration.stub(:private_key_for_active, @private_key) do
          PreferenceJwtConfiguration.stub(:public_key_for, key_for) do
            PreferenceJwtConfiguration.stub(:active_kid, "default") do
              PreferenceJwtConfiguration.stub(:issuer, @issuer) do
                PreferenceJwtConfiguration.stub(:audiences, @audiences) do
                  yield
                end
              end
            end
          end
        end
      end
    end
  end
end
