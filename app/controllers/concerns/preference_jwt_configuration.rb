# typed: false
# frozen_string_literal: true

require "base64"
require "json"
require "jwt"
require "openssl"
require "jit_security_jwt_registry"

# Resolves keysets, issuer, leeway and audience scoping for preference JWTs.
# Audience hosts are derived from the configured boot hosts instead of a
# standalone PREFERENCE_JWT_AUDIENCES env var.
module PreferenceJwtConfiguration
  class MissingAudienceError < StandardError; end

  def self.active_kid(issuer_id = "preference")
    JitSecurityJwtRegistry.issuer(issuer_id).current_kid ||
      raise(JitSecurityJwtRegistry::ConfigurationError, "#{issuer_id} active kid is not configured")
  end

  def self.leeway_seconds
    SecurityJwtRfc9068AccessTokenProfile::CLOCK_SKEW_LEEWAY_SECONDS
  end

  def self.issuer
    ENV.fetch("PREFERENCE_JWT_ISSUER")
  end

  def self.client_id
    ENV.fetch("PREFERENCE_JWT_CLIENT_ID")
  end

  # Audiences are the base surface hosts from boot config. Local environments
  # additionally accept the `*.localhost` development hosts; no environment
  # falls back to a default list when the boot hosts are missing.
  def self.audiences
    configured = audiences_from_boot_config
    if configured.empty?
      raise MissingAudienceError,
            "preference JWT audiences are not configured: boot hosts " \
            "base_service, base_corporate and base_staff are blank"
    end

    configured = with_local_development_audiences(configured) if Rails.env.local?
    SecurityJwtRfc9068AccessTokenProfile.assert_production_identifiers!(configured, label: "preference JWT audiences")
    configured
  end

  # Boot-time check so a production process with an incomplete or
  # non-production preference token configuration refuses to start.
  def self.validate!
    SecurityJwtRfc9068AccessTokenProfile.assert_production_identifiers!([issuer], label: "PREFERENCE_JWT_ISSUER")
    audiences
    client_id
    true
  end

  # Returns the audiences that may legitimately accept a token issued for
  # the given host. Selects entries sharing the host's TLD so a .app token
  # cannot validate against the .com surface. In non-production the
  # configured "localhost"/"*.localhost" entry is always retained so local
  # development can move across surfaces.
  def self.audience_for(host)
    raise ArgumentError, "host is required" if host.blank?

    all = audiences
    host_tld = host.split(".").last
    matched = all.select { |aud| aud.split(".").last == host_tld }

    unless Rails.env.production?
      localhost_aud = all.find { |aud| aud == "localhost" || aud.end_with?(".localhost") }
      matched << localhost_aud if localhost_aud && matched.exclude?(localhost_aud)
    end

    raise MissingAudienceError, "No audience configured for host #{host.inspect}" if matched.empty?

    matched
  end

  def self.host_scope_for(host)
    raise ArgumentError, "host is required" if host.blank?

    exact_or_nested =
      audience_for(host).sort_by { |aud| -aud.to_s.length }.find do |aud|
        host == aud || host.end_with?(".#{aud}")
      end
    return exact_or_nested if exact_or_nested.present?

    same_tld =
      audiences.sort_by { |aud| -aud.to_s.length }.find do |aud|
        aud.split(".").last == host.split(".").last
      end

    same_tld || (Rails.env.local? ? "localhost" : host)
  end

  def self.private_key_for_active(issuer_id = "preference")
    private_key_for(active_kid(issuer_id), issuer_id: issuer_id)
  end

  def self.private_key_for(kid, issuer_id: "preference")
    JitSecurityJwtRegistry.private_key_for(issuer_id, kid)
  end

  def self.public_key_for(kid, issuer_id: "preference")
    JitSecurityJwtRegistry.public_key_for(issuer_id, kid)
  end

  def self.private_key
    private_key_for(active_kid)
  end

  def self.public_key
    public_key_for(active_kid)
  end

  def self.parse_header(token)
    JitSecurityJwtRegistry.parse_header(token)
  end

  public_class_method :active_kid, :leeway_seconds, :issuer, :client_id, :audiences, :validate!,
                      :audience_for, :host_scope_for, :private_key_for_active, :private_key_for,
                      :public_key_for, :private_key, :public_key, :parse_header

  def self.parse_keyset(raw)
    return {} if raw.blank?

    parsed = JSON.parse(raw)
    return parsed if parsed.is_a?(Hash)

    {}
  rescue JSON::ParserError
    {}
  end

  def self.decode_key(base64_der)
    return nil if base64_der.blank?

    OpenSSL::PKey::EC.new(Base64.decode64(base64_der))
  rescue OpenSSL::PKey::PKeyError
    nil
  end
  private_class_method :parse_keyset, :decode_key

  def self.audiences_from_boot_config
    hosts = Rails.configuration.x.boot_config.fetch(:hosts)

    values =
      %i(base_service base_corporate base_staff).filter_map do |key|
        host = hosts.public_send(key)&.host
        host.presence
      end
    values.freeze
  end
  private_class_method :audiences_from_boot_config

  def self.with_local_development_audiences(values)
    audiences = values.dup
    audiences.concat(%w(app.localhost org.localhost com.localhost localhost))
    audiences.uniq.freeze
  end
  private_class_method :with_local_development_audiences
end
