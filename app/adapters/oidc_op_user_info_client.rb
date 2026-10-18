# typed: false
# frozen_string_literal: true

class OidcOpUserInfoClient
  OPEN_TIMEOUT = 2
  READ_TIMEOUT = 5

  Result =
    Data.define(:success, :claims, :error, :dependency_failure) do
      def success? = success

      def dependency_failure? = dependency_failure
    end

  class << self
    public

    def call(...) = new(...).call
  end

  def initialize(access_token:, userinfo_url:, require_https:)
    @access_token = access_token
    @userinfo_url = userinfo_url
    @require_https = require_https
  end

  public

  def call
    return failure("missing_access_token") if access_token.blank?

    uri = URI.parse(userinfo_url)
    connection = OutboundHttp::Connection.build(
      url: uri,
      open_timeout: OPEN_TIMEOUT,
      read_timeout: READ_TIMEOUT,
      require_https: require_https,
    )
    response = connection.get(
      uri,
      nil,
      { "Authorization" => "Bearer #{access_token}", "Accept" => "application/json" },
    )
    status = response.status.to_i
    return failure("dependency_unavailable", dependency_failure: true) if status >= 500 || status == 429

    body = JSON.parse(response.body.to_s)
    if status == 200 && body.is_a?(Hash) && body["sub"].is_a?(String) && body["sub"].present?
      return success(body)
    end
    if [400, 401, 403].include?(status) && body.is_a?(Hash) &&
        body["error"].is_a?(String) && body["error"].present?
      return failure(body["error"])
    end

    failure("invalid_remote_response", dependency_failure: true)
  rescue JSON::ParserError
    failure("invalid_remote_response", dependency_failure: true)
  rescue URI::InvalidURIError, OutboundHttp::Connection::InsecureEndpointError,
         *OutboundHttp::Connection::NETWORK_ERRORS
    failure("dependency_unavailable", dependency_failure: true)
  end

  private

  attr_reader :access_token, :userinfo_url, :require_https

  def success(claims)
    Result.new(success: true, claims: claims, error: nil, dependency_failure: false)
  end

  def failure(error, dependency_failure: false)
    Result.new(success: false, claims: nil, error: error, dependency_failure: dependency_failure)
  end
end
