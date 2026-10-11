# typed: false
# frozen_string_literal: true

class JumpRtReturnVerifier
  ALGORITHM = SecurityJwtJumpRtTokenCodec::ALGORITHM
  TOKEN_TYPE = SecurityJwtJumpRtTokenCodec::TOKEN_TYPE
  TOKEN_SUBJECT = SecurityJwtJumpRtTokenCodec::TOKEN_SUBJECT
  DEFAULT_MAX_TTL = SecurityTokenLifetimes::JUMP_RT_TTL
  LEEWAY = 5
  MAX_TOKEN_LENGTH = 8_192
  CACHE_TTL = 30.seconds
  NEGATIVE_CACHE_TTL = 5.seconds
  HTTP_OPEN_TIMEOUT = 1
  HTTP_READ_TIMEOUT = 2
  MAX_JWKS_BYTES = 64.kilobytes
  REQUIRED_JWK_FIELDS = SecurityJwtJumpRtTokenCodec::REQUIRED_JWK_FIELDS
  PRIVATE_JWK_FIELDS = SecurityJwtJumpRtTokenCodec::PRIVATE_JWK_FIELDS

  class JwksUnavailable < StandardError; end

  class UnknownKid < StandardError; end

  Result =
    Data.define(:success, :payload, :error) do
      def success? = success
    end

  def self.call(...)
    new(...).call
  end

  def initialize(token:, request_url:, request_base_url:, fetcher: nil, now: Time.current)
    @token = token.to_s
    @request_url = request_url.to_s
    @request_base_url = request_base_url.to_s
    @fetcher = fetcher || method(:fetch_jwks)
    @now = now
  end

  def call
    return failure("missing_token") if token.blank?
    return failure("malformed") if token.bytesize > MAX_TOKEN_LENGTH
    return failure("malformed") unless compact_jwt?(token)

    header = parse_header
    return failure("invalid_header") unless valid_header?(header)
    return failure("revoked_kid") if revoked_kid?(header.fetch("kid"))

    payload = decode_with_jwks(header.fetch("kid"))
    return failure("invalid_claim") unless valid_payload?(payload)
    return failure("invalid_url") unless same_request_without_rt?(payload["url"])
    return failure("invalid_claim") unless JumpRtReturnPolicy.allowed_source?(
      destination_origin: request_base_url,
      source: payload["src"],
    )
    return failure("replayed") if one_time_return?(payload) && !consume_jti!(payload)

    Result.new(success: true, payload: payload, error: nil)
  rescue JwksUnavailable
    failure("jwks_unavailable")
  rescue UnknownKid
    failure("unknown_kid")
  rescue JWT::InvalidIssuerError
    failure("issuer_mismatch")
  rescue JWT::InvalidAudError
    failure("audience_mismatch")
  rescue JWT::ExpiredSignature, JWT::ImmatureSignature, JWT::InvalidIatError, JWT::MissingRequiredClaim
    failure("invalid_claim")
  rescue JWT::DecodeError, JWT::VerificationError, OpenSSL::PKey::PKeyError, ArgumentError, TypeError
    failure("invalid_signature")
  end

  private

  attr_reader :token, :request_url, :request_base_url, :fetcher, :now

  def compact_jwt?(value)
    parts = value.split(".")
    parts.size == 3 && parts.all? { |part| part.match?(/\A[A-Za-z0-9_-]+\z/) }
  end

  def parse_header
    _payload, header = JWT.decode(token, nil, false)
    header
  end

  def valid_header?(header)
    SecurityJwtJumpRtTokenCodec.valid_header?(header)
  end

  def decode_with_jwks(kid)
    key = public_key_for(kid)

    SecurityJwtJumpRtTokenCodec.decode_with_key(
      token: token,
      key: key,
      issuer: jump_origin,
      audience: request_base_url,
      leeway: LEEWAY,
    )
  end

  def public_key_for(kid)
    raise UnknownKid, "kid negative cached" if negative_kid_cached?(kid)

    jwk = jwks_keys(force: false).find { |entry| entry["kid"] == kid && entry["alg"] == ALGORITHM }
    jwk ||= jwks_keys(force: true).find { |entry| entry["kid"] == kid && entry["alg"] == ALGORITHM }
    unless jwk
      Rails.cache.write(negative_cache_key(kid), true, expires_in: NEGATIVE_CACHE_TTL)
      raise UnknownKid, "unknown kid"
    end

    JWT::JWK.import(jwk).public_key
  end

  def jwks_keys(force:)
    cached_jwks(force: force).fetch("keys", []).filter_map { |entry| normalized_public_jwk(entry) }
  end

  def cached_jwks(force:)
    Rails.cache.delete(cache_key) if force
    cached = Rails.cache.read(cache_key)
    return cached if cached && !force

    fresh = fetcher.call
    raise JwksUnavailable, "jwks fetch failed" unless fresh.is_a?(Hash)

    Rails.cache.write(cache_key, fresh, expires_in: CACHE_TTL)
    fresh
  rescue JwksUnavailable
    raise
  rescue JWT::DecodeError, JSON::ParserError, SocketError, SystemCallError, Net::OpenTimeout, Net::ReadTimeout
    raise JwksUnavailable, "jwks fetch failed"
  end

  def cache_key
    "jump_rt:return_jwks:#{Digest::SHA256.hexdigest(jwks_url)}"
  end

  def negative_cache_key(kid)
    "jump_rt:return_jwks:negative:#{Digest::SHA256.hexdigest("#{jwks_url}:#{kid}")}"
  end

  def negative_kid_cached?(kid)
    Rails.cache.read(negative_cache_key(kid)).present?
  end

  def fetch_jwks
    uri = URI.parse(jwks_url)
    raise JWT::DecodeError, "jwks fetch failed" unless uri.is_a?(URI::HTTPS)

    connection =
      OutboundHttp::Connection.build(
        url: uri,
        open_timeout: HTTP_OPEN_TIMEOUT,
        read_timeout: HTTP_READ_TIMEOUT,
        require_https: true,
      )
    response = connection.get(uri)
    raise JWT::DecodeError, "jwks fetch failed" unless response.success?
    raise JWT::DecodeError, "jwks response too large" if response.body.to_s.bytesize > MAX_JWKS_BYTES

    JSON.parse(response.body.presence || "{}")
  rescue JSON::ParserError, URI::InvalidURIError, *OutboundHttp::Connection::NETWORK_ERRORS
    raise JWT::DecodeError, "jwks fetch failed"
  end

  def normalized_public_jwk(entry)
    SecurityJwtJumpRtTokenCodec.normalized_public_jwk(entry)
  end

  def valid_payload?(payload)
    return false unless payload["schema"] == 1
    return false unless payload["sub"] == TOKEN_SUBJECT
    return false unless payload["dst"] == "internal"
    return false if payload["jti"].blank?
    return false if payload["src"].blank?
    return false if payload["url"].blank?
    return false unless valid_replay_policy?(payload["rpl"])

    iat = payload["iat"].to_i
    exp = payload["exp"].to_i
    nbf = payload["nbf"].to_i
    current = now.to_i
    return false if iat > current + LEEWAY
    return false if nbf > exp
    return false if exp - iat > max_ttl_seconds

    true
  end

  def valid_replay_policy?(value)
    value.blank? || JumpRtIssuer::VALID_REPLAY_POLICIES.include?(value.to_s)
  end

  def same_request_without_rt?(claimed_url)
    claimed = normalize_url_without_rt(claimed_url)
    current = normalize_url_without_rt(request_url)
    !claimed.nil? && !current.nil? && claimed == current
  end

  def consume_jti!(payload)
    expires_at = Time.zone.at(payload["exp"].to_i + LEEWAY)
    return false unless expires_at.future?

    SecurityConsumedJti.consume!(
      purpose: SecurityConsumedJti::PURPOSES.fetch(:jump_rt_return),
      issuer: payload["iss"],
      jti: payload["jti"],
      expires_at: expires_at,
    )
  rescue ActiveRecord::ActiveRecordError
    false
  end

  def one_time_return?(payload)
    payload["rpl"].to_s == "once"
  end

  # Returns a comparable tuple [scheme, host, port, path, query_hash] so the
  # caller can match the request URL against the signed claim regardless of
  # query parameter ordering. Returns nil for unparsable or unsafe URLs.
  def normalize_url_without_rt(value)
    uri = URI.parse(value.to_s)
    return nil unless uri.is_a?(URI::HTTP)
    return nil unless https_url_allowed?(uri)
    return nil if uri.userinfo.present?
    return nil if uri.fragment.present?

    query = Rack::Utils.parse_nested_query(uri.query.to_s)
    query.delete("rt")
    [
      uri.scheme.downcase,
      uri.host.to_s.downcase,
      uri.port,
      uri.path.presence || "/",
      query,
    ]
  rescue URI::InvalidURIError
    nil
  end

  def https_url_allowed?(uri)
    return true if uri.scheme == "https"
    return false unless Rails.env.local?

    uri.scheme == "http"
  end

  def jump_origin
    JumpRtReturnPolicy.normalize_origin(jump_gateway_url)
  end

  def jwks_url
    current_jump_config.jwks_uri
  end

  def jump_gateway_url
    current_jump_config.origin.to_s
  end

  def revoked_kid?(kid)
    current_jump_config.revoked_kids.include?(kid.to_s)
  end

  def max_ttl_seconds
    current_jump_config.ttl_seconds
  end

  def current_jump_config
    ConfigValues::JumpGatewayValues.build(env: ENV, production: Rails.env.production?)
  end

  def failure(error)
    Result.new(success: false, payload: nil, error: error)
  end
end
