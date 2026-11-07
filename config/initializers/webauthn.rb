# typed: false
# frozen_string_literal: true

# WebAuthn configuration boot check.
#
# Relying-party configuration is per surface and fully explicit:
# - production injects WEBAUTHN_<APP|ORG>_RP_ID / _ORIGIN via the
#   deployment environment; a missing value aborts boot (KeyError). There is
#   no request-derived, shared-key, or credentials fallback in production.
# - non-production reads Rails encrypted credentials (webauthn.<surface>.*),
#   overridable per surface via the same env keys for test harnesses.
#
# Ceremonies always use an explicit WebAuthn::RelyingParty built by
# Webauthn::RelyingPartyConfig -- the gem's global configuration is never used,
# so nothing else is configured here.
Rails.application.config.after_initialize do
  next unless Rails.env.production?

  Webauthn::Surface::REGISTRY.each_value do |surface|
    config = Webauthn::RelyingPartyConfigResolver.resolve(surface)

    unless config.origin.start_with?("https://")
      raise Webauthn::RelyingPartyConfig::InvalidConfigError,
            "Production WebAuthn origin for #{surface.key} must be HTTPS: #{config.origin}"
    end
  end
end
