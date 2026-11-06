# frozen_string_literal: true

# Base Self-RP client for Visa-owned O-9 admission state. A failed cancellation is never treated as
# success because Base must not revoke its local RP session until Visa serializes pending admissions.
class VisaSensitiveAdmissionClient
  Result =
    Data.define(:status) do
      def ok? = status == :ok
    end
  IssuanceResult =
    Data.define(:status, :admission_ref, :authorization_url) do
      def ok? = status == :ok
    end

  CLIENTS = {
    "app" => %w(base-app-ww client sensitive_admissions),
    "org" => %w(base-org-ww operator sensitive_admissions),
  }.freeze
  OPEN_TIMEOUT = 2
  READ_TIMEOUT = 5

  def initialize(surface:, access_token:)
    @client_id, resource_type, admissions_path = CLIENTS.fetch(surface.to_s)
    @url = OutboundHttp::LocalBackChannel.url(
      "#{OidcIssuer.for_resource_type(resource_type)}/api/v0/sensitive_admission_session",
    )
    @issuance_url = OutboundHttp::LocalBackChannel.url(
      "#{OidcIssuer.for_resource_type(resource_type)}/api/v0/#{admissions_path}",
    )
    @confirmation_url = OutboundHttp::LocalBackChannel.url(
      "#{OidcIssuer.for_resource_type(resource_type)}/api/v0/sensitive_admission_confirmation",
    )
    @access_token = access_token.to_s
  end

  public

  def issue_admission!(attributes:)
    return IssuanceResult.new(status: :unauthorized, admission_ref: nil, authorization_url: nil) if
      access_token.blank?

    assertion = OidcClientAssertionJwt.issue(client_id:, token_url: issuance_url)
    return IssuanceResult.new(status: :dependency, admission_ref: nil, authorization_url: nil) if
      assertion.blank?

    uri = URI.parse(issuance_url)
    connection = OutboundHttp::Connection.build(
      url: uri, open_timeout: OPEN_TIMEOUT, read_timeout: READ_TIMEOUT,
      require_https: OutboundHttp::LocalBackChannel.require_https?(issuance_url),
    )
    response = connection.post(
      uri,
      Faraday::Utils.build_nested_query(attributes),
      {
        "Authorization" => "Bearer #{access_token}",
        "X-Client-Assertion" => assertion,
        "Accept" => "application/json",
        "Content-Type" => "application/x-www-form-urlencoded",
      },
    )
    return issuance_result_from(response) if response.status.to_i == 201
    return IssuanceResult.new(status: :refused, admission_ref: nil, authorization_url: nil) if
      [400, 404].include?(response.status.to_i)
    return IssuanceResult.new(status: :unauthorized, admission_ref: nil, authorization_url: nil) if
      response.status.to_i == 401

    IssuanceResult.new(status: :dependency, admission_ref: nil, authorization_url: nil)
  rescue Faraday::Error, URI::InvalidURIError, OutboundHttp::Connection::InsecureEndpointError,
         JSON::ParserError, KeyError, ArgumentError
    IssuanceResult.new(status: :dependency, admission_ref: nil, authorization_url: nil)
  end

  def revoke_rp_session(rp_session_ref:)
    return Result.new(status: :unauthorized) if access_token.blank?

    assertion = OidcClientAssertionJwt.issue(client_id:, token_url: url)
    return Result.new(status: :dependency) if assertion.blank?

    uri = URI.parse(url)
    connection = OutboundHttp::Connection.build(
      url: uri, open_timeout: OPEN_TIMEOUT, read_timeout: READ_TIMEOUT,
      require_https: OutboundHttp::LocalBackChannel.require_https?(url),
    )
    response = connection.patch(
      uri,
      Faraday::Utils.build_nested_query(rp_session_ref: rp_session_ref.to_s),
      {
        "Authorization" => "Bearer #{access_token}",
        "X-Client-Assertion" => assertion,
        "Accept" => "application/json",
        "Content-Type" => "application/x-www-form-urlencoded",
      },
    )
    Result.new(status: (response.status.to_i == 204) ? :ok : :dependency)
  rescue Faraday::Error, URI::InvalidURIError, OutboundHttp::Connection::InsecureEndpointError
    Result.new(status: :dependency)
  end

  def confirm_browser!(admission_ref:, rp_session_ref:, browser_binding_digest:)
    return Result.new(status: :unauthorized) if access_token.blank?

    assertion = OidcClientAssertionJwt.issue(client_id:, token_url: confirmation_url)
    return Result.new(status: :dependency) if assertion.blank?

    uri = URI.parse(confirmation_url)
    connection = OutboundHttp::Connection.build(
      url: uri, open_timeout: OPEN_TIMEOUT, read_timeout: READ_TIMEOUT,
      require_https: OutboundHttp::LocalBackChannel.require_https?(confirmation_url),
    )
    response = connection.post(
      uri,
      Faraday::Utils.build_nested_query(
        admission_ref: admission_ref.to_s,
        rp_session_ref: rp_session_ref.to_s,
        browser_binding_digest: browser_binding_digest.to_s,
      ),
      {
        "Authorization" => "Bearer #{access_token}",
        "X-Client-Assertion" => assertion,
        "Accept" => "application/json",
        "Content-Type" => "application/x-www-form-urlencoded",
      },
    )
    return Result.new(status: :ok) if response.status.to_i == 204
    return Result.new(status: :refused) if [400, 404].include?(response.status.to_i)

    Result.new(status: :dependency)
  rescue Faraday::Error, URI::InvalidURIError, OutboundHttp::Connection::InsecureEndpointError
    Result.new(status: :dependency)
  end

  private

  attr_reader :client_id, :url, :issuance_url, :confirmation_url, :access_token

  def issuance_result_from(response)
    body = JSON.parse(response.body)
    admission_ref = body.fetch("admission_ref")
    authorization_url = body.fetch("authorization_url")
    uri = URI.parse(authorization_url)
    expected_uri = URI.parse(
      OidcIssuer.authorization_endpoint(
        CLIENTS.fetch(surface_for_client).fetch(1),
      ),
    )
    unless admission_ref.match?(ClientVisaSensitiveAdmission::PUBLIC_REF_PATTERN) &&
        uri.scheme == expected_uri.scheme && uri.host == expected_uri.host &&
        uri.port == expected_uri.port && uri.path == expected_uri.path && uri.query.present?
      raise ArgumentError
    end

    IssuanceResult.new(status: :ok, admission_ref:, authorization_url:)
  end

  def surface_for_client
    CLIENTS.find { |_surface, (configured_client_id, _resource_type, _path)|
      configured_client_id == client_id
    }&.first ||
      (raise ArgumentError)
  end
end
