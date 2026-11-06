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

  # Installs a valid owner-issued step-up event on the grant used by the real RP callback path.
  # Credential signature verification is covered by the passkey ceremony tests; this helper keeps
  # HTTP tests focused on the RP controller's evidence and write-boundary behavior.
  def sign_in_rp_cell_with_step_up_evidence(client_id, actor:, root_token:)
    token_response, payload, session = sign_in_rp_cell(client_id, actor:, root_token:)
    client = OidcClientRegistry.find!(client_id)
    surface = (OidcIssuer.resource_type_for_client(client) == "operator") ? "org" : "app"
    record_class, grant_class, commit_class =
      case surface
      when "app" then [OpBaseAppRecord, OpAppGrant, ClientStepUpCommit]
      when "org" then [OpBaseOrgRecord, OpOrgGrant, OperatorStepUpCommit]
      else raise ArgumentError, "unsupported Base RP surface: #{surface.inspect}"
      end
    grant = grant_class.find_by!(public_id: payload.fetch("sid"))
    now = record_class.database_now
    auth_time = now.to_i - 1
    grant.update!(
      oidc_auth_time: Time.at(auth_time).utc,
      oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR,
      oidc_amr: JSON.generate(["passkey"]),
    )
    commit_class.create!(
      grant: grant,
      root_token: root_token,
      context_ref: PublicId.generate,
      verified_method: "passkey",
      committed_at: Time.at(auth_time).utc,
    )
    access_token = AuthenticationTokenService.encode(
      actor,
      host: URI.parse(client.redirect_uris.first).host,
      resource_type: OidcIssuer.resource_type_for_client(client),
      session_public_id: root_token.public_id,
      base_session_public_id: root_token.public_id,
      oidc_sid: grant.public_id,
      oidc_jti: grant.oidc_jti,
      expires_at: now + 10.minutes,
      scopes: %w(openid profile),
      acr: StepUpEvidenceResolver::STEP_UP_ACR,
      amr: ["passkey"],
      auth_time: auth_time,
      authentication_context: root_token.strict_authentication_context_value.to_s,
      issuer: OidcIssuer.for_client(client),
      audiences: [client.aud],
      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(client),
      subject: OidcSubject.for(actor, resource_type: OidcIssuer.resource_type_for_client(client)),
      client_id: client.client_id,
    )
    cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] = access_token
    [token_response, payload, session]
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
      OidcClientRegistry.stub(
        :verify_client_assertion,
        ->(authenticated_client_id, *, **) {
          OidcClientRegistry::AssertionAuthenticationResult.new(
            authenticated: true, client: OidcClientRegistry.find(authenticated_client_id),
            step_up_claims_state: :none, step_up_expectation: nil,
          )
        },
      ) do
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
