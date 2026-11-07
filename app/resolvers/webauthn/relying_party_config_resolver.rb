# typed: false
# frozen_string_literal: true

module Webauthn
  # Resolves the RelyingPartyConfig for a surface.
  #
  # production: values MUST be injected per surface by the deployment
  # environment (WEBAUTHN_<APP|ORG>_RP_ID / _ORIGIN). One-argument
  # ENV.fetch makes a missing value a boot/request failure -- there is no
  # request-derived, shared-key, or credentials fallback in production.
  #
  # non-production: per-surface env values take precedence (test harnesses set
  # them explicitly); otherwise Rails encrypted credentials
  # (webauthn.<surface>.rp_id / origin) supply them. A missing value raises --
  # never silently defaults.
  class RelyingPartyConfigResolver
    class MissingConfigurationError < StandardError; end

    def self.resolve(surface)
      new(Surface.for(surface)).resolve
    end

    def initialize(surface)
      @surface = surface
    end

    def resolve
      RelyingPartyConfig.new(rp_id: value_for("RP_ID", :rp_id), origin: value_for("ORIGIN", :origin))
    end

    private

    attr_reader :surface

    def value_for(env_suffix, credentials_key)
      env_key = "WEBAUTHN_#{surface.env_prefix}_#{env_suffix}"
      return ENV.fetch(env_key) if Rails.env.production?

      value = ENV[env_key].presence ||
        Rails.application.credentials.dig(:webauthn, surface.key, credentials_key)
      return value if value.present?

      raise MissingConfigurationError,
            "WebAuthn #{credentials_key} for surface #{surface.key} is not configured. " \
            "Set #{env_key} or credentials webauthn.#{surface.key}.#{credentials_key}."
    end
  end
end
