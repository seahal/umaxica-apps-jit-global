# typed: false
# frozen_string_literal: true

require "test_helper"

module Webauthn
  class RelyingPartyConfigTest < ActiveSupport::TestCase
    SURFACE_ENV_KEYS = %w(
      WEBAUTHN_APP_RP_ID WEBAUTHN_APP_ORIGIN
      WEBAUTHN_COM_RP_ID WEBAUTHN_COM_ORIGIN
      WEBAUTHN_ORG_RP_ID WEBAUTHN_ORG_ORIGIN
      WEBAUTHN_RP_ID WEBAUTHN_ORIGIN
    ).freeze

    test "surface enumeration is closed and rejects unknown surfaces" do
      assert_equal %i(app com org), Webauthn::Surface.all.map(&:key)
      assert_raises(Webauthn::Surface::UnknownSurfaceError) { Webauthn::Surface.for(:preview) }
    end

    test "resolver returns per-surface config in test environment" do
      config = Webauthn::RelyingPartyConfigResolver.resolve(:app)

      assert_equal "auth.umaxica.app", config.rp_id
      assert_equal "https://auth.umaxica.app", config.origin
    end

    test "resolver keeps surfaces separate" do
      assert_equal "auth.umaxica.com", Webauthn::RelyingPartyConfigResolver.resolve(:com).rp_id
      assert_equal "auth.umaxica.org", Webauthn::RelyingPartyConfigResolver.resolve(:org).rp_id
    end

    test "production resolution requires per-surface env and fails fast when missing" do
      with_env(SURFACE_ENV_KEYS.index_with { nil }) do
        Rails.stub(:env, ActiveSupport::StringInquirer.new("production")) do
          assert_raises(KeyError) { Webauthn::RelyingPartyConfigResolver.resolve(:app) }
        end
      end
    end

    test "production resolution ignores shared WEBAUTHN_RP_ID and WEBAUTHN_ORIGIN" do
      overrides = SURFACE_ENV_KEYS.index_with { nil }
      overrides["WEBAUTHN_RP_ID"] = "shared.example"
      overrides["WEBAUTHN_ORIGIN"] = "https://shared.example"

      with_env(overrides) do
        Rails.stub(:env, ActiveSupport::StringInquirer.new("production")) do
          assert_raises(KeyError) { Webauthn::RelyingPartyConfigResolver.resolve(:app) }
        end
      end
    end

    test "production resolution uses injected per-surface env values" do
      overrides = SURFACE_ENV_KEYS.index_with { nil }
      overrides["WEBAUTHN_APP_RP_ID"] = "auth.umaxica.app"
      overrides["WEBAUTHN_APP_ORIGIN"] = "https://auth.umaxica.app"

      with_env(overrides) do
        Rails.stub(:env, ActiveSupport::StringInquirer.new("production")) do
          config = Webauthn::RelyingPartyConfigResolver.resolve(:app)

          assert_equal "auth.umaxica.app", config.rp_id
          assert_equal "https://auth.umaxica.app", config.origin
        end
      end
    end

    test "trusted_origin? requires exact scheme host and effective port match" do
      config = Webauthn::RelyingPartyConfig.new(rp_id: "auth.umaxica.app", origin: "https://auth.umaxica.app")

      assert config.trusted_origin?("https://auth.umaxica.app")
      assert config.trusted_origin?("https://auth.umaxica.app:443")

      assert_not config.trusted_origin?("http://auth.umaxica.app")
      assert_not config.trusted_origin?("https://auth.umaxica.app:8443")
      assert_not config.trusted_origin?("https://preview.umaxica.app")
      assert_not config.trusted_origin?("https://evil.umaxica.app")
      assert_not config.trusted_origin?("https://auth.umaxica.com")
      assert_not config.trusted_origin?("https://auth.umaxica.org")
      assert_not config.trusted_origin?("https://auth.umaxica.app.evil.example")
      assert_not config.trusted_origin?("not a uri")
    end

    test "relying_party is built from the config and never from request state" do
      config = Webauthn::RelyingPartyConfig.new(rp_id: "auth.umaxica.app", origin: "https://auth.umaxica.app")
      relying_party = config.relying_party

      assert_kind_of WebAuthn::RelyingParty, relying_party
      assert_equal "auth.umaxica.app", relying_party.id
      assert_equal ["https://auth.umaxica.app"], relying_party.allowed_origins
    end

    test "rp_id must not be a parent domain of the origin host" do
      assert_raises(Webauthn::RelyingPartyConfig::InvalidConfigError) do
        Webauthn::RelyingPartyConfig.new(rp_id: "umaxica.app", origin: "https://auth.umaxica.app")
      end
    end

    test "origin must be an absolute http(s) origin without path" do
      assert_raises(Webauthn::RelyingPartyConfig::InvalidConfigError) do
        Webauthn::RelyingPartyConfig.new(rp_id: "auth.umaxica.app", origin: "auth.umaxica.app")
      end
      assert_raises(Webauthn::RelyingPartyConfig::InvalidConfigError) do
        Webauthn::RelyingPartyConfig.new(rp_id: "auth.umaxica.app", origin: "https://auth.umaxica.app/callback")
      end
    end

    test "configs compare by relying party id and origin, not by identity" do
      config = Webauthn::RelyingPartyConfig.new(rp_id: "auth.umaxica.app", origin: "https://auth.umaxica.app")
      same = Webauthn::RelyingPartyConfig.new(rp_id: "auth.umaxica.app", origin: "https://auth.umaxica.app")
      other_origin = Webauthn::RelyingPartyConfig.new(rp_id: "auth.umaxica.com", origin: "https://auth.umaxica.com")

      assert_equal config, same
      assert_not_equal config, other_origin
      assert_not_equal config, "auth.umaxica.app"
      assert_equal config.hash, same.hash
    end

    private

    def with_env(overrides)
      saved = overrides.keys.index_with { |key| ENV[key] }
      overrides.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
      yield
    ensure
      saved.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
    end
  end
end
