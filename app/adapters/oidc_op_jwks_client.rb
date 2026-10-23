# typed: false
# frozen_string_literal: true

require "json"
require "uri"
require "jit_security_jwt_jwk"

class OidcOpJwksClient
  class FetchError < StandardError; end

  class InvalidDocument < FetchError; end

  CacheEntry = Data.define(:keys, :fetched_at)

  CACHE_TTL = 1.hour
  MAX_STALE_TTL = 5.minutes
  MAXIMUM_RESPONSE_BYTES = 65_536
  MAXIMUM_KEYS = 4
  MAXIMUM_KID_LENGTH = 128
  OPEN_TIMEOUT = 2
  READ_TIMEOUT = 5

  # found(key) / invalid(reason) / unavailable(reason) (D-136): callers map invalid to their own
  # 400/401 contract and unavailable to 503, never the reverse.
  Lookup =
    Data.define(:status, :key, :reason) do
      def found? = status == :found

      def invalid? = status == :invalid

      def unavailable? = status == :unavailable
    end

  CLIENTS = Concurrent::Map.new

  class << self
    public

    def for_resource_type(resource_type)
      for_jwks_uri(OidcIssuer.jwks_uri(resource_type))
    end

    # One cached client per JWKS URI and process (BX-6); verifiers never build their own.
    def for_jwks_uri(jwks_uri)
      CLIENTS.compute_if_absent(jwks_uri.to_s) { new(jwks_uri:) }
    end
  end

  def initialize(jwks_uri:, fetcher: nil, clock: -> { Time.current }, limiter: OidcJwksRefetchLimiter.shared)
    @jwks_uri = normalize_jwks_uri(jwks_uri)
    @fetcher = fetcher || method(:fetch_from_network)
    @clock = clock
    @limiter = limiter
    @mutex = Mutex.new
    @cache_entry = nil
  end

  public

  def lookup(kid)
    normalized_kid = normalize_kid(kid)
    return invalid("malformed_kid") unless normalized_kid

    current = cache_entry
    return found(current.keys.fetch(normalized_kid)) if current && fresh?(current) && current.keys.key?(normalized_kid)

    lookup_after_limiter(normalized_kid, current)
  end

  private

  def lookup_after_limiter(kid, current)
    decision = limiter.acquire(OidcJwksRefetchLimiter.issuer_key(jwks_uri))
    if decision.lease?
      entry = fetch_and_store
      limiter.record(
        OidcJwksRefetchLimiter.issuer_key(jwks_uri), outcome: entry ? "ok" : "failed",
                                                     kids: entry ? entry.keys.keys : [],
      )
      return stale_or(current, kid, unavailable("fetch_failed")) unless entry

      return entry.keys.key?(kid) ? found(entry.keys.fetch(kid)) : invalid("unknown_kid")
    end
    return stale_or(current, kid, unavailable("refetch_in_progress")) if decision.busy?
    return stale_or(current, kid, unavailable("recent_fetch_failed")) unless decision.ok?
    return stale_or(current, kid, invalid("unknown_kid")) unless decision.kids.include?(kid)

    # A recent fetch saw this kid, so it is genuine; this process fetches once for itself.
    entry = fetch_and_store
    return stale_or(current, kid, unavailable("fetch_failed")) unless entry

    entry.keys.key?(kid) ? found(entry.keys.fetch(kid)) : invalid("unknown_kid")
  end

  # A known kid inside the stale window keeps verifying while refresh is refused or failing.
  def stale_or(current, kid, result)
    return found(current.keys.fetch(kid)) if current&.keys&.key?(kid) && usable_stale_entry?(current)

    result
  end

  def found(key) = Lookup.new(status: :found, key:, reason: nil)

  def invalid(reason) = Lookup.new(status: :invalid, key: nil, reason:)

  def unavailable(reason) = Lookup.new(status: :unavailable, key: nil, reason:)

  def fetch_and_store
    @mutex.synchronize do
      document = fetch_document
      @cache_entry = CacheEntry.new(keys: document, fetched_at: clock.call).freeze
    rescue FetchError, JSON::ParserError, URI::InvalidURIError, TypeError,
           *OutboundHttp::Connection::NETWORK_ERRORS
      nil
    end
  end

  private

  attr_reader :jwks_uri, :fetcher, :clock, :limiter

  def normalize_jwks_uri(value)
    uri = URI.parse(value.to_s)
    valid = uri.is_a?(URI::HTTPS) && uri.host.present? && uri.userinfo.blank? &&
      uri.query.blank? && uri.fragment.blank? && uri.path.present?
    raise ArgumentError, "OP JWKS URI must be a fixed HTTPS URL" unless valid

    uri.freeze
  rescue URI::InvalidURIError
    raise ArgumentError, "OP JWKS URI must be a fixed HTTPS URL"
  end

  def normalize_kid(value)
    return unless value.is_a?(String) && value.present?
    return if value.bytesize > MAXIMUM_KID_LENGTH
    return if value.each_byte.any? { |byte| byte < 0x20 || byte == 0x7f }

    value
  end

  def cache_entry
    @mutex.synchronize { @cache_entry }
  end

  def fresh?(entry)
    age = clock.call - entry.fetched_at
    age >= 0 && age <= CACHE_TTL
  end

  def usable_stale_entry?(entry)
    age = clock.call - entry.fetched_at
    age > CACHE_TTL && age <= CACHE_TTL + MAX_STALE_TTL
  end

  def fetch_document
    raw = fetcher.call
    parsed = raw.is_a?(String) ? JSON.parse(raw) : raw
    normalize_document(parsed)
  end

  def normalize_document(document)
    raise InvalidDocument, "JWKS document must be an object" unless document.is_a?(Hash)
    raise InvalidDocument, "JWKS document keys must be an array" unless document["keys"].is_a?(Array)

    entries = document.fetch("keys")
    raise InvalidDocument, "JWKS document has too many keys" if entries.empty? || entries.size > MAXIMUM_KEYS

    normalized =
      entries.map do |entry|
        normalized_entry = normalize_entry(entry)
        [normalized_entry.fetch("kid"), JitSecurityJwtJwk.import_public_key(normalized_entry)]
      end
    kids = normalized.map(&:first)
    kids.uniq!
    raise InvalidDocument, "JWKS document contains duplicate kids" unless kids.size == normalized.size

    normalized.to_h.freeze
  rescue JitSecurityJwtJwk::Error => e
    raise InvalidDocument, e.message
  end

  def normalize_entry(entry)
    raise InvalidDocument, "JWKS entry must be an object" unless entry.is_a?(Hash)

    normalized = entry.transform_keys(&:to_s)
    kid = normalize_kid(normalized["kid"])
    raise InvalidDocument, "JWKS entry has an invalid kid" unless kid

    JitSecurityJwtJwk.normalize_public(normalized).merge("kid" => kid)
  end

  def fetch_from_network
    connection = OutboundHttp::Connection.build(
      url: jwks_uri,
      open_timeout: OPEN_TIMEOUT,
      read_timeout: READ_TIMEOUT,
      require_https: true,
    )
    response = connection.get(jwks_uri)
    raise FetchError, "OP JWKS request failed" unless response.success?
    raise FetchError, "OP JWKS response is too large" if response.body.to_s.bytesize > MAXIMUM_RESPONSE_BYTES

    response.body
  rescue JSON::ParserError, URI::InvalidURIError, TypeError, *OutboundHttp::Connection::NETWORK_ERRORS => e
    raise FetchError, "OP JWKS request failed", cause: e
  end
end
