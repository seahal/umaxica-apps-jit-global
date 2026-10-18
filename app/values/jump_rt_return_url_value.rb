# typed: false
# frozen_string_literal: true

# A Jump return URL as an ordered list of decoded query pairs.
#
# The signed `url` claim binds the exact navigation target, including query order and duplicates
# (docs/receiver-contract.md in the Jump repository). Rack's Hash-based parsers drop that
# information, so the query is held as a UrlSearchParamsValue, which follows the same WHATWG rules
# as Jump's URLSearchParams. `parse` returns nil for
# any URL the receiver contract rejects; the caller maps that to a rejected return.
class JumpRtReturnUrlValue
  RETURN_TOKEN_KEY = "rt"
  NESTED_RETURN_TOKEN_PREFIX = "rt["
  SINGLE_VALUED_KEYS = %w(redirect_uri state nonce code next return_to).freeze

  class << self
    public

    def parse(url)
      uri = URI.parse(url.to_s)
      return nil unless uri.is_a?(URI::HTTPS)
      return nil if uri.host.blank? || uri.userinfo.present? || !uri.fragment.nil?

      params = UrlSearchParamsValue.parse(uri.query)
      return nil unless valid_keys?(params.keys)

      new(
        origin: origin_of(uri),
        path: uri.path.presence || "/",
        params: params,
      )
    rescue URI::InvalidURIError
      nil
    end

    # True when the raw query names rt in any form, valid or not, so the request must go through
    # return verification instead of reaching the normal flow.
    def carries_return_token?(raw_query)
      UrlSearchParamsValue.parse(raw_query).keys.any? do |key|
        key == RETURN_TOKEN_KEY || key.start_with?(NESTED_RETURN_TOKEN_PREFIX)
      end
    end

    private

    def valid_keys?(keys)
      return false if keys.any? { |key| key.start_with?(NESTED_RETURN_TOKEN_PREFIX) }
      return false if keys.count(RETURN_TOKEN_KEY) > 1

      SINGLE_VALUED_KEYS.all? { |key| keys.count(key) <= 1 }
    end

    def origin_of(uri)
      port = (uri.port == uri.default_port) ? "" : ":#{uri.port}"
      "https://#{uri.host.downcase}#{port}"
    end
  end

  def initialize(origin:, path:, params:)
    @origin = origin
    @path = path
    @params = params
    freeze
  end

  public

  def return_token
    params.pairs.find { |key, _value| key == RETURN_TOKEN_KEY }&.last
  end

  def canonical_without_return_token
    "#{origin}#{request_uri_without_return_token}"
  end

  def request_uri_without_return_token
    query = params.reject_keys { |key| key == RETURN_TOKEN_KEY }
    query.empty? ? path : "#{path}?#{query}"
  end

  private

  attr_reader :origin, :path, :params
end
