# frozen_string_literal: true

require "uri"

module ObservabilityRedactor
  module_function

  REDACTED = "[FILTERED]"
  SENSITIVE_KEY_PATTERN =
    /
      \A
      (?:.*)
      (?:
        email|uid|token|rt|jwt|authorization|cookie|set-cookie|session(?:_id)?|
        code|state|nonce|verifier|challenge|dpop|otp|totp|hotp|password|secret|private_key|client_secret|
        refresh_token|access_token|id_token|query_string|request_uri|original_url|
        url|redirect_uri|return_to|return_url
      )
      (?:.*)
      \z
    /ix.freeze
  SENSITIVE_HEADER_KEYS = %w(
    authorization cookie set-cookie x-csrf-token x-request-id x-forwarded-for
    dpop dpop-proof
  ).freeze
  NON_SENSITIVE_KEYS = %w(event_uuid reason_code).freeze
  SENSITIVE_STRING_PATTERNS = [
    /\bBearer\s+[a-z0-9._~+\-\/=]+/i,
    /\beyJ[a-zA-Z0-9_-]+\.[a-zA-Z0-9_-]+\.[a-zA-Z0-9_-]+\b/,
    /\b(?:access_token|refresh_token|id_token|token|secret|password|otp|totp|recovery_code)\s*[:=]\s*[^\s,;]+/i,
  ].freeze
  SAFE_OBSERVABILITY_KEY_PATTERN = /
    \A
    (?:.*_)?
    (?:digest(?:12)?|length|parts)
    \z
  /ix.freeze

  def scrub(value)
    case value
    when Hash
      value.each_with_object({}) do |(key, inner), result|
        result[key] = scrub_entry(key, inner)
      end
    when Array
      value.map { |inner| scrub(inner) }
    when String
      scrub_string(value)
    else
      value
    end
  end

  def scrub_entry(key, value)
    if url_like_key?(key)
      scrub_url(value)
    elsif sensitive_key?(key)
      REDACTED
    else
      scrub(value)
    end
  end

  def sensitive_key?(key)
    normalized = key.to_s.tr("-", "_").downcase
    return false if NON_SENSITIVE_KEYS.include?(normalized)
    return false if SAFE_OBSERVABILITY_KEY_PATTERN.match?(normalized)

    SENSITIVE_KEY_PATTERN.match?(normalized) || SENSITIVE_HEADER_KEYS.include?(normalized)
  end

  def url_like_key?(key)
    %w(url uri request_uri original_url redirect_uri return_to return_url).include?(key.to_s.downcase)
  end

  def scrub_url(value)
    return REDACTED if value.nil?

    uri = URI.parse(value.to_s)
    return REDACTED unless uri.is_a?(URI::HTTP)

    port = uri.port
    default_port = (uri.scheme == "https") ? 443 : 80
    host = uri.host.to_s.downcase
    base = "#{uri.scheme.downcase}://#{host}"
    base += ":#{port}" if port && port != default_port
    base += uri.path.to_s.presence || "/"
    base
  rescue URI::InvalidURIError
    REDACTED
  end

  def scrub_string(value)
    return scrub_url(value) if value.match?(/\Ahttps?:\/\//i)

    SENSITIVE_STRING_PATTERNS.reduce(value) do |scrubbed, pattern|
      scrubbed.gsub(pattern, REDACTED)
    end
  end
end
