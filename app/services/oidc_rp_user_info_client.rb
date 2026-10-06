# typed: false
# frozen_string_literal: true

class OidcRpUserInfoClient < ApplicationService
  OPEN_TIMEOUT = 2
  READ_TIMEOUT = 5

  Result =
    Data.define(:success, :claims, :error, :dependency_failure) do
      def success? = success

      def dependency_failure? = dependency_failure
    end

  def initialize(access_token:, userinfo_url:, require_https:)
    super()
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
    body = JSON.parse(response.body.presence || "{}")
    return failure("dependency_unavailable", dependency_failure: true) if response.status.to_i >= 500

    return success(body) if response.success? && body.is_a?(Hash) && body["sub"].present?

    failure(body.is_a?(Hash) ? body["error"].presence || "userinfo_failed" : "userinfo_failed")
  rescue JSON::ParserError
    failure("userinfo_failed")
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
