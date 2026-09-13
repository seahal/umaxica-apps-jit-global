# typed: false
# frozen_string_literal: true

class OidcRpTokenClient < ApplicationService
  # RFC 7523 client assertion type. Held here rather than borrowed from an
  # Entra-specific class: this client is the generic OIDC RP token exchange and
  # must not depend on a provider-specific one.
  CLIENT_ASSERTION_TYPE = "urn:ietf:params:oauth:client-assertion-type:jwt-bearer"

  # No connection-level retry: an authorization code is single-use, so a retried
  # exchange burns the code and turns a recoverable timeout into a hard sign-in
  # failure. A timeout here must surface as one failed exchange.
  OPEN_TIMEOUT = 2
  READ_TIMEOUT = 5

  Result =
    Data.define(:success, :token_response, :error) do
      def success? = success
    end

  def initialize(token_url:, client_id:, client_secret:, code:, redirect_uri:, code_verifier:, client_assertion: nil,
                 require_https: true)
    super()
    @token_url = token_url
    @client_id = client_id
    @client_secret = client_secret
    @client_assertion = client_assertion
    @code = code
    @redirect_uri = redirect_uri
    @code_verifier = code_verifier
    @require_https = require_https
  end

  def call
    uri = URI.parse(token_url)
    params = request_params
    return params if params.is_a?(Result)

    connection = OutboundHttp::Connection.build(
      url: uri,
      open_timeout: OPEN_TIMEOUT,
      read_timeout: READ_TIMEOUT,
      require_https: require_https,
    )
    response = connection.post(uri, params)
    body = JSON.parse(response.body.presence || "{}").with_indifferent_access
    return Result.new(success: true, token_response: body, error: nil) if response.success?

    log_token_exchange_failure(uri: uri, response: response, oauth_error: body[:error].presence)
    Result.new(success: false, token_response: nil, error: body[:error].presence || "token_exchange_failed")
  rescue JSON::ParserError, URI::InvalidURIError, OutboundHttp::Connection::InsecureEndpointError,
         *OutboundHttp::Connection::NETWORK_ERRORS => e
    log_token_exchange_failure(uri: safe_token_uri, error_class: e.class.name)
    Result.new(success: false, token_response: nil, error: "token_exchange_failed")
  end

  private

  attr_reader :token_url, :client_id, :client_secret, :client_assertion, :code, :redirect_uri, :code_verifier,
              :require_https

  def request_params
    params = {
      grant_type: "authorization_code",
      code: code,
      redirect_uri: redirect_uri,
      client_id: client_id,
      code_verifier: code_verifier,
    }
    if client_assertion.present?
      return params.merge(
        client_assertion_type: CLIENT_ASSERTION_TYPE,
        client_assertion: client_assertion,
      )
    end
    client = OidcClientRegistry.find(client_id)
    if client&.private_key_jwt_client?
      assertion = OidcClientAssertionJwt.issue(client_id: client_id, token_url: token_url)
      return Result.new(success: false, token_response: nil, error: "client_assertion_unavailable") if assertion.blank?

      return params.merge(
        client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
        client_assertion: assertion,
      )
    end

    params.merge(client_secret: client_secret)
  end

  def log_token_exchange_failure(uri:, response: nil, oauth_error: nil, error_class: nil)
    Rails.logger.info(
      JitLogEvent.format(
        "oidc.rp.token_exchange.failed",
        client_id: client_id,
        endpoint_host: uri&.host,
        endpoint_path: uri&.path,
        http_status: response&.status,
        oauth_error: oauth_error,
        error_class: error_class,
      ),
    )
  end

  def safe_token_uri
    URI.parse(token_url)
  rescue URI::InvalidURIError
    nil
  end
end
