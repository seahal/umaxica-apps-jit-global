# typed: false
# frozen_string_literal: true

require "jwt"
require "ipaddr"

class JumpRtIssuer
  ALGORITHM = SecurityJwtJumpRtTokenCodec::ALGORITHM
  DEFAULT_TTL = SecurityTokenLifetimes::JUMP_RT_TTL
  MAX_TTL = SecurityTokenLifetimes::JUMP_RT_TTL
  MAX_TOKEN_LENGTH = 4_096
  MAX_URL_LENGTH = 2_048
  MAX_JTI_LENGTH = 128
  JTI_PATTERN = /\A[\x21-\x7E]{1,#{MAX_JTI_LENGTH}}\z/o
  TOKEN_SUBJECT = SecurityJwtJumpRtTokenCodec::TOKEN_SUBJECT
  VALID_DESTINATIONS = %w(internal).freeze
  # Defense in depth: strip redirect-target query keys from the signed URL so
  # the gateway cannot return a request that re-enters a `pt`/`nt`/`xt`/`rt`
  # processing path. Same list as RedirectsExternalTargetResolver.
  DANGEROUS_QUERY_KEYS = %w(redirect_uri return_to rt pt nt xt redirect_to next continue url).freeze

  def self.call(...)
    new(...).call
  end

  def initialize(namespace:, url:, dst:, preserve_query_keys: [], ttl: nil, now: Time.current,
                 jti: SecureRandom.uuid)
    @namespace = JumpRtSurface.normalize_namespace(namespace)
    @url = url
    @dst = dst
    @preserve_query_keys = Array(preserve_query_keys).map(&:to_s)
    @ttl = ttl.nil? ? default_ttl : ttl
    @now = now
    @jti = jti
  end

  def call
    return nil unless valid_destination?
    return nil unless valid_ttl?
    return nil unless valid_jti?

    normalized_url = normalize_url(url)
    return nil if normalized_url.blank?
    return nil if utf16_code_units(normalized_url) > MAX_URL_LENGTH

    issuer = JumpRtSurface.issuer_origin(namespace)
    kid = JumpRtKeyring.active_kid(namespace)
    private_key = JumpRtKeyring.private_key(namespace)
    if kid.blank? || private_key.blank?
      raise JumpRtConfigurationError, "Jump RT signing key configuration is incomplete for #{namespace}"
    end

    token = SecurityJwtJumpRtTokenCodec.encode(payload(issuer, normalized_url), private_key: private_key, kid: kid)
    return nil unless token.ascii_only?
    return nil if token.bytesize > MAX_TOKEN_LENGTH

    token
  end

  private

  attr_reader :namespace, :url, :dst, :preserve_query_keys, :ttl, :now, :jti

  def payload(issuer, normalized_url)
    issued_at = now.to_i
    SecurityJwtJumpRtTokenCodec.build_issue_payload(
      issuer: issuer,
      normalized_url: normalized_url,
      dst: dst,
      ttl: ttl,
      now: Time.zone.at(issued_at),
      jti: jti,
      audience: jump_audience,
    )
  end

  def normalize_url(value)
    raw = value.to_s
    return nil if raw.blank?
    return nil unless raw.valid_encoding?
    return nil if raw.match?(/[\x00-\x1F\x7F]/)

    # URL APIs percent-encode Unicode path and query bytes during serialization. URI.parse accepts
    # ASCII only, so encode non-ASCII UTF-8 bytes first while rejecting a percent-escaped host.
    ascii_url = raw.b.gsub(/[^\x00-\x7F]/n) { |byte| format("%%%02X", byte.ord) }
    uri = URI.parse(ascii_url)
    return nil unless uri.is_a?(URI::HTTP)
    return nil unless uri.scheme == "https"
    return nil if uri.host.blank?
    return nil if uri.host.include?("%")
    return nil if private_destination?(uri)
    return nil if uri.userinfo.present?
    return nil if uri.fragment.present?

    uri.scheme = uri.scheme.downcase
    uri.host = uri.host.downcase
    uri.path = "/" if uri.path.blank?
    uri.query = strip_dangerous_query(uri.query)
    uri.to_s
  rescue URI::InvalidURIError
    nil
  end

  # Keeps the remaining pairs in order, repeats included, because the signed url binds them. A key
  # is blocked in its bare and bracketed forms (rt, rt[], rt[x]) after percent-decoding.
  def strip_dangerous_query(raw_query)
    return nil if raw_query.blank?

    blocked_keys = DANGEROUS_QUERY_KEYS - preserve_query_keys
    params =
      UrlSearchParamsValue.parse(raw_query).reject_keys do |key|
        blocked_keys.any? { |blocked| key == blocked || key.start_with?("#{blocked}[") }
      end
    params.empty? ? nil : params.to_s
  end

  def valid_destination?
    dst.is_a?(String) && VALID_DESTINATIONS.include?(dst)
  end

  def valid_ttl?
    ttl.is_a?(Integer) && ttl.positive? && ttl <= MAX_TTL.to_i
  end

  def valid_jti?
    jti.is_a?(String) && jti.match?(JTI_PATTERN)
  end

  def utf16_code_units(value)
    value.encode(Encoding::UTF_16LE).bytesize / 2
  rescue EncodingError
    Float::INFINITY
  end

  def default_ttl
    boot_jump_config.ttl_seconds.seconds
  end

  def jump_audience
    boot_jump_config.audience
  end

  def private_destination?(uri)
    host = uri.hostname.downcase.delete_suffix(".")
    return true unless host.include?(".") || host.include?(":")
    return true if host.end_with?(".localhost", ".local", ".internal")

    address = IPAddr.new(host).native
    address.private? || address.loopback? || address.link_local? || address.to_i.zero?
  rescue IPAddr::InvalidAddressError
    false
  end

  def boot_jump_config
    Rails.configuration.x.boot_config.fetch(:jump)
  end
end
