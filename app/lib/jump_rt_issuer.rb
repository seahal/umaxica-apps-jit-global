# typed: false
# frozen_string_literal: true

require "jwt"
require "ipaddr"

class JumpRtIssuer
  ALGORITHM = SecurityJwtJumpRtTokenCodec::ALGORITHM
  DEFAULT_TTL = SecurityTokenLifetimes::JUMP_RT_TTL
  MAX_TTL = SecurityTokenLifetimes::JUMP_RT_TTL
  TOKEN_SUBJECT = SecurityJwtJumpRtTokenCodec::TOKEN_SUBJECT
  VALID_DESTINATIONS = %w(internal external).freeze
  # Defense in depth: strip redirect-target query keys from the signed URL so
  # the gateway cannot return a request that re-enters a `pt`/`nt`/`xt`/`rt`
  # processing path. Same list as RedirectsExternalTargetResolver.
  DANGEROUS_QUERY_KEYS = %w(redirect_uri return_to rt pt nt xt redirect_to next continue url).freeze

  def self.call(...)
    new(...).call
  end

  def initialize(namespace:, url:, dst: "internal", preserve_query_keys: [], ttl: nil, now: Time.current,
                 jti: SecureRandom.uuid)
    @namespace = JumpRtSurface.normalize_namespace(namespace)
    @url = url
    @dst = dst.to_s
    @preserve_query_keys = Array(preserve_query_keys).map(&:to_s)
    @ttl = ttl || default_ttl
    @now = now
    @jti = jti
  end

  def call
    return nil unless valid_destination?
    return nil unless valid_ttl?

    normalized_url = normalize_url(url)
    return nil if normalized_url.blank?

    issuer = JumpRtSurface.issuer_origin(namespace)
    kid = JumpRtKeyring.active_kid(namespace)
    private_key = JumpRtKeyring.private_key(namespace)
    if kid.blank? || private_key.blank?
      raise JumpRtConfigurationError, "Jump RT signing key configuration is incomplete for #{namespace}"
    end

    SecurityJwtJumpRtTokenCodec.encode(payload(issuer, normalized_url), private_key: private_key, kid: kid)
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
    return nil if raw.match?(/[\x00-\x1F\x7F]/)

    uri = URI.parse(raw)
    return nil unless uri.is_a?(URI::HTTP)
    return nil unless uri.scheme == "https"
    return nil if uri.host.blank?
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
    VALID_DESTINATIONS.include?(dst)
  end

  def valid_ttl?
    ttl.to_i.positive? && ttl.to_i <= MAX_TTL.to_i
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
