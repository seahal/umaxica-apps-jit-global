# frozen_string_literal: true

# R5-WU17 cell-process sign-in for integration tests.
#
# The OP side (code issue and exchange) runs as the real OP code; the RP side commits the verified
# ID Token into the cell store exactly as the callback does (RpCallbackCommitter) and the browser
# then holds the same three cookies a callback installs: Access, Refresh and the local session.
module RpCellSessionHelper
  # The process role and its deployed contract epoch are process configuration.
  def as_rp_cell(client_id)
    cell = RpCellBinding.for_client(client_id)
    names = %w(UMAXICA_RUNTIME_ROLE UMAXICA_RP_BROWSER_ADMISSION)
    previous = names.index_with { |name| ENV[name] }
    ENV["UMAXICA_RUNTIME_ROLE"] = "#{cell.connection.tr("_", "-")}-#{cell.region}"
    ENV["UMAXICA_RP_BROWSER_ADMISSION"] = "open"
    OidcOpJwksClient::CLIENTS.clear
    yield
  ensure
    previous&.each { |name, value| value.nil? ? ENV.delete(name) : ENV[name] = value }
  end

  # Returns [token_response, id_token_payload, local session].
  def sign_in_rp_cell(client_id, actor:, root_token:)
    cell = RpCellBinding.for_client(client_id)
    token_response = rp_cell_test_token_response(client_id, actor:, root_token:)
    payload, = JWT.decode(token_response.fetch(:id_token), nil, false)
    enrollment = RpCallbackCommitter.call(
      cell:, issuer: payload.fetch("iss"), subject: payload.fetch("sub"), sid: payload.fetch("sid"),
      absolute_expires_at: 1.hour.from_now,
    )
    raise ArgumentError, "cell enrollment failed: #{enrollment.outcome}" unless enrollment.success?

    cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] = token_response.fetch(:access_token)
    cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE] = token_response.fetch(:refresh_token)
    cookies[OidcRpBrowserCredentialContract::SESSION_COOKIE] = enrollment.session.public_id
    [token_response, payload, enrollment.session]
  end

  private

  def rp_cell_test_token_response(client_id, actor:, root_token:)
    client = OidcClientRegistry.find!(client_id)
    verifier = SecureRandom.urlsafe_base64(48)
    params = {
      client_id:,
      redirect_uri: client.redirect_uris.first,
      response_type: "code",
      scope: "openid",
      state: SecureRandom.hex(16),
      nonce: SecureRandom.hex(16),
      code_challenge_method: "S256",
      code_challenge: Base64.urlsafe_encode64(Digest::SHA256.digest(verifier), padding: false),
    }
    authentication_event_at = 1.minute.ago
    code = OidcAuthorizationCodeIssuer.call(
      client:, params:, resource: actor, session_token: root_token, authentication_event_at:,
    )
    resource_type = OidcIssuer.resource_type_for_client(client)
    token_url = OidcIssuer.token_endpoint(resource_type)
    result =
      OidcClientRegistry.stub(:authenticate_assertion, ->(*, **) { true }) do
        OidcTokenExchangeCoordinator.call(
          grant_type: "authorization_code", code: code.code, redirect_uri: code.redirect_uri, client_id:,
          client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE, client_assertion: "cell-test-assertion",
          token_endpoint_uri: token_url, code_verifier: verifier, expected_resource_type: resource_type,
        )
      end
    raise ArgumentError, "OP code exchange failed: #{result.inspect}" unless result.success?

    result.token_response
  end
end
