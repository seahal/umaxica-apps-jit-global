# typed: false
# frozen_string_literal: true

class RedirectsJumpGatewayUrl
  MIN_TOKEN_LENGTH = 64
  TOKEN_PATTERN = /\A[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\z/

  def self.call(token, source: :jump_rt)
    new(token, source: source).call
  end

  def initialize(token, source:)
    @token = token
    @source = source
  end

  def call
    return failure(:blank_token) if token.blank?
    return failure(:control_char) if token.match?(/[\x00-\x1F\x7F]/)
    return failure(:token_too_short) if token.bytesize < MIN_TOKEN_LENGTH
    return failure(:malformed_token) unless token.match?(TOKEN_PATTERN)

    uri = URI.parse(gateway_origin)
    return failure(:invalid_origin) if uri.scheme.blank? || uri.host.blank?
    return failure(:https_required) unless uri.scheme == "https"

    uri.path = "/"
    uri.query = URI.encode_www_form("rt" => token)
    uri.fragment = nil
    uri.user = nil
    uri.password = nil

    RedirectsTargetResult.ok(kind: :external, source: source, value: uri.to_s)
  rescue ArgumentError, URI::InvalidURIError
    failure(:invalid_uri)
  end

  private

  attr_reader :token, :source

  # The boot-validated PUBLIC_JUMP_GATEWAY_URL origin; never re-read from ENV here.
  def gateway_origin
    Rails.configuration.x.boot_config.fetch(:jump).origin
  end

  def failure(reason)
    RedirectsTargetResult.failure(kind: :external, source: source, reason: reason, unsafe_value: token)
  end
end
