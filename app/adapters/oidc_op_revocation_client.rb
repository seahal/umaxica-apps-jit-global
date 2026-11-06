# typed: false
# frozen_string_literal: true

require "timeout"

# Sends an RP's current Refresh Token to the registered OP revocation endpoint. The RP process
# never reads the OP grant database; only the existing Visa endpoint can stop that grant.
class OidcOpRevocationClient
  Result =
    Data.define(:outcome) do
      def success? = outcome == :success
    end

  TOTAL_REQUEST_BUDGET = 2.0
  MAX_ATTEMPTS = 2

  class RequestDeadlineExceeded < StandardError; end

  class << self
    public

    def revoke(client_id:, resource_type:, token:)
      new(client_id:, resource_type:, token:).call
    end
  end

  def initialize(client_id:, resource_type:, token:)
    @client_id = client_id
    @resource_type = resource_type.to_s
    @token = token
  end

  public

  def call
    return result(:missing_token) if token.blank?

    client = OidcClientRegistry.find(client_id)
    return result(:client_unavailable) unless client
    return result(:resource_mismatch) unless OidcIssuer.resource_type_for_client(client) == resource_type

    endpoint = OidcIssuer.revocation_endpoint(resource_type)
    revoke_registered_token(client:, endpoint:)
  rescue OidcClientRegistry::ClientNotFound, URI::InvalidURIError,
         OutboundHttp::Connection::InsecureEndpointError
    result(:endpoint_unavailable)
  end

  private

  attr_reader :client_id, :resource_type, :token

  def revoke_registered_token(client:, endpoint:)
    # The assertion audience stays the public endpoint; only the transport goes to the local port in
    # development, where the tunnel and not this host serves the public HTTPS origin.
    endpoint_uri = URI.parse(OutboundHttp::LocalBackChannel.url(endpoint.to_s))
    deadline = monotonic_now + TOTAL_REQUEST_BUDGET

    1.upto(MAX_ATTEMPTS) do |attempt|
      attempt_result = revoke_attempt(client:, endpoint:, endpoint_uri:, deadline:, attempt:)
      return attempt_result if attempt_result
    end

    result(:network_unavailable)
  end

  def revoke_attempt(client:, endpoint:, endpoint_uri:, deadline:, attempt:)
    remaining = deadline - monotonic_now
    return result(:timeout) unless remaining.positive?

    attempt_budget = remaining / (MAX_ATTEMPTS - attempt + 1)
    auth_params = revocation_parameters(client, endpoint)
    return result(:client_authentication_unavailable) unless auth_params

    remaining = deadline - monotonic_now
    return result(:timeout) unless remaining.positive?

    body = auth_params.merge(
      client_id: client_id,
      token: token,
      token_type_hint: "refresh_token",
    )
    response = post_revocation(endpoint_uri:, body:, deadline:, timeout: [attempt_budget, remaining].min)
    return result(:timeout) if monotonic_now >= deadline

    classify(response)
  rescue Faraday::Error, RequestDeadlineExceeded
    return if attempt < MAX_ATTEMPTS && monotonic_now < deadline

    result(:network_unavailable)
  end

  def post_revocation(endpoint_uri:, body:, deadline:, timeout:)
    connection = OutboundHttp::Connection.build(
      url: endpoint_uri,
      open_timeout: timeout,
      read_timeout: timeout,
      write_timeout: timeout,
      require_https: Rails.env.production?,
    )
    remaining = deadline - monotonic_now
    raise RequestDeadlineExceeded unless remaining.positive?

    Timeout.timeout([timeout, remaining].min, RequestDeadlineExceeded) do
      connection.post(endpoint_uri, body)
    end
  end

  def revocation_parameters(client, endpoint)
    case client.registered_token_endpoint_auth_method
    when "private_key_jwt"
      assertion = OidcClientAssertionJwt.issue(client_id:, token_url: endpoint)
      return if assertion.blank?

      {
        client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
        client_assertion: assertion,
      }
    when "client_secret_post"
      return if client.client_secret.blank?

      { client_secret: client.client_secret }
    when "none"
      {}
    end
  end

  def classify(response)
    status = response.status.to_i
    return result(:success) if status == 200
    return result(:unexpected_redirect) if status.between?(300, 399)
    return result(:rejected) if status.between?(400, 499)
    return result(:endpoint_failure) if status >= 500

    result(:unexpected_response)
  end

  def monotonic_now
    Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end

  def result(outcome)
    Result.new(outcome:)
  end
end
