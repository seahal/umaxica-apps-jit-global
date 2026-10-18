# typed: false
# frozen_string_literal: true

# Centralized key resolution for Cloudflare Turnstile.
# Uses Rails.app.creds (ENV -> credentials) for unified lookup.
class JitSecurityTurnstileConfig
  KEYS = {
    visible_site_key: "CLOUDFLARE_TURNSTILE_VISIBLE_SITE_KEY",
    visible_secret_key: "CLOUDFLARE_TURNSTILE_VISIBLE_SECRET_KEY",
    stealth_site_key: "CLOUDFLARE_TURNSTILE_SITE_STEALTH_KEY",
    stealth_secret_key: "CLOUDFLARE_TURNSTILE_SECRET_STEALTH_KEY",
  }.freeze

  class << self
    def visible_site_key
      fetch(:CLOUDFLARE_TURNSTILE_VISIBLE_SITE_KEY)
    end

    def visible_secret_key
      fetch(:CLOUDFLARE_TURNSTILE_VISIBLE_SECRET_KEY)
    end

    def stealth_site_key
      fetch(:CLOUDFLARE_TURNSTILE_SITE_STEALTH_KEY)
    end

    def stealth_secret_key
      fetch(:CLOUDFLARE_TURNSTILE_SECRET_STEALTH_KEY)
    end

    private

    def fetch(key)
      return unless defined?(Rails)

      Rails.app.creds.option(key)
    end
  end

  private_class_method :visible_site_key
end
